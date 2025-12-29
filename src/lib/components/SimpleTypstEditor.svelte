<script lang="ts">
  import { browser } from '$app/environment'
  import { onMount, untrack } from 'svelte'
  import { getPdfjs } from '$lib/pdf/pdfjs'
  import { TypstWorkerClient } from '$lib/workers/typstClient'

  // CodeMirror 6
  import { EditorView, basicSetup } from 'codemirror'
  import { EditorState } from '@codemirror/state'
  import { oneDark } from '@codemirror/theme-one-dark'

  import 'pdfjs-dist/web/pdf_viewer.css'
  import type { PDFDocumentLoadingTask, PDFDocumentProxy } from 'pdfjs-dist'
  import type { PDFLinkService, PDFViewer } from 'pdfjs-dist/web/pdf_viewer.mjs'

  // Props
  interface Props {
    initialCode?: string
  }

  let { initialCode = '' }: Props = $props()

  // Default Typst template
  const DEFAULT_TEMPLATE = `#import "styles/modern-tech.typ": article

#show: article.with(
  title: "Typst Online Editor",
  authors: ("MDXport",),
  lang: "en",
)

= Welcome to Typst Editor

This is a simple online Typst editor. Edit the code on the left to see the PDF preview on the right.

== Features

- Real-time PDF compilation
- Professional typesetting with Typst
- Runs 100% in your browser
- Offline capable

== Example Code

=== Text Formatting

Regular text with *bold*, _italic_, and \`monospace\` formatting.

=== Lists

- Item 1
- Item 2
  - Nested item
  + Numbered nested

=== Math

Inline math: $ E = m c^2 $

Display math:
$ integral_0^oo e^(-x^2) d x = sqrt(pi) / 2 $

=== Code

#raw(lang: "python", block: true, "def hello():
    print('Hello, Typst!')
")

=== Table

#table(
  columns: 3,
  [Name], [Value], [Unit],
  [Speed], [299792], [km/s],
  [Mass], [5.972], [10^24 kg],
)
`

  // State
  let typstCode = $state('')
  let hasInitialized = false
  let style = $state<'modern-tech' | 'classic-editorial'>('modern-tech')
  let status = $state<'idle' | 'compiling' | 'done' | 'error'>('idle')
  let errorMessage = $state<string | null>(null)
  let isLoading = $state(true)
  let leftPaneWidth = $state(50)
  let isResizing = $state(false)

  // PDF state
  let pdfBytes = $state<Uint8Array<ArrayBuffer> | null>(null)
  let pdfUrl = $state<string | null>(null)
  let pdfDoc = $state<PDFDocumentProxy | null>(null)
  let pdfPages = $state(0)
  let pdfPage = $state(1)
  let pdfScale = $state(1)
  let pdfLoadTask = $state<PDFDocumentLoadingTask | null>(null)
  let pdfLoadSeq = 0  // Regular variable - no reactivity needed for sequencing
  let pdfViewer = $state<PDFViewer | null>(null)
  let pdfLinkService = $state<PDFLinkService | null>(null)

  // Editor
  let editorView = $state<EditorView | null>(null)
  let editorContainerEl = $state<HTMLDivElement | null>(null)
  let pdfContainerEl = $state<HTMLDivElement | null>(null)
  let suppressEditorUpdate = false

  // Worker
  let client = $state<TypstWorkerClient | null>(null)
  let compileSeq = 0  // Regular variable - no reactivity needed for sequencing
  let autoPreviewTimer: number | null = null
  let hasEverCompiled = false

  // Initialize - use untrack to avoid triggering auto-compile effect
  $effect(() => {
    if (!hasInitialized) {
      untrack(() => {
        typstCode = initialCode || DEFAULT_TEMPLATE
      })
      hasInitialized = true
    }
  })

  onMount(() => {
    let aborted = false

    ;(async () => {
      // Initialize Typst worker
      client = new TypstWorkerClient()

      if (aborted) return

      // Initialize PDF.js
      const pdfjs = await getPdfjs()
      const { PDFViewer, PDFLinkService, EventBus } = await import(
        'pdfjs-dist/web/pdf_viewer.mjs'
      )

      if (aborted || !pdfContainerEl) return

      const eventBus = new EventBus()
      const linkService = new PDFLinkService({ eventBus })
      pdfLinkService = linkService

      const viewer = new PDFViewer({
        container: pdfContainerEl,
        eventBus,
        linkService,
      })
      pdfViewer = viewer
      linkService.setViewer(viewer)

      eventBus.on('pagesinit', () => {
        viewer.currentScaleValue = 'page-width'
      })

      eventBus.on('pagechanging', (evt: any) => {
        pdfPage = evt.pageNumber
      })

      eventBus.on('scalechanging', (evt: any) => {
        pdfScale = evt.scale
      })

      // Initialize CodeMirror
      if (editorContainerEl) {
        const startState = EditorState.create({
          doc: typstCode,
          extensions: [
            basicSetup,
            oneDark,
            EditorView.lineWrapping,
            EditorView.updateListener.of((update) => {
              if (update.docChanged && !suppressEditorUpdate) {
                typstCode = update.state.doc.toString()
              }
            }),
            EditorView.theme({
              '&': {
                height: '100%',
                fontSize: '14px',
              },
              '.cm-scroller': {
                fontFamily: 'monospace',
              },
            }),
          ],
        })

        editorView = new EditorView({
          state: startState,
          parent: editorContainerEl,
        })
      }

      isLoading = false

      // Trigger first compile
      void compile(typstCode, style)
    })().catch((error) => {
      console.error(error)
      isLoading = false
    })

    return () => {
      aborted = true
      client?.dispose()
      pdfLoadTask?.destroy()
      pdfDoc?.destroy()
      if (pdfUrl) URL.revokeObjectURL(pdfUrl)
      editorView?.destroy()
    }
  })

  // Auto-compile on code changes
  $effect(() => {
    if (!browser) return
    if (!client) return
    if (isLoading) return

    const code = typstCode
    const currentStyle = style

    if (autoPreviewTimer) window.clearTimeout(autoPreviewTimer)

    const delay = hasEverCompiled ? 500 : 0
    autoPreviewTimer = window.setTimeout(() => {
      void compile(code, currentStyle)
    }, delay)

    return () => {
      if (autoPreviewTimer) window.clearTimeout(autoPreviewTimer)
    }
  })

  // Sync editor view with state changes
  $effect(() => {
    if (editorView && typstCode !== editorView.state.doc.toString()) {
      suppressEditorUpdate = true
      editorView.dispatch({
        changes: {
          from: 0,
          to: editorView.state.doc.length,
          insert: typstCode,
        },
      })
      suppressEditorUpdate = false
    }
  })

  // PDF loading effect
  $effect(() => {
    if (!browser) return
    const bytes = pdfBytes
    if (!bytes) {
      pdfLoadTask?.destroy()
      pdfDoc?.destroy()
      pdfDoc = null
      pdfPages = 0
      pdfPage = 1
      pdfScale = 1
      return
    }

    const seq = ++pdfLoadSeq

    void (async () => {
      pdfLoadTask?.destroy()

      const pdfjs = await getPdfjs()
      const task: PDFDocumentLoadingTask = pdfjs.getDocument({ data: bytes })
      pdfLoadTask = task

      const doc: PDFDocumentProxy = await task.promise
      if (seq !== pdfLoadSeq) {
        void doc.destroy()
        return
      }

      void pdfDoc?.destroy()
      pdfDoc = doc
      pdfPages = doc.numPages
      pdfPage = 1

      pdfLinkService?.setDocument(doc)
      pdfViewer?.setDocument(doc)
    })().catch((error) => {
      console.error(error)
    })
  })

  // Functions
  async function compile(code: string, currentStyle: typeof style) {
    if (!client) {
      console.log('[Typst] Compile skipped: client not ready')
      return
    }
    
    // Prevent concurrent compilations
    if (status === 'compiling') {
      console.log('[Typst] Compile skipped: already compiling')
      return
    }
    
    hasEverCompiled = true

    const seq = ++compileSeq
    console.log(`[Typst] Starting compilation #${seq}`)
    status = 'compiling'
    errorMessage = null

    try {
      const pdfData = await client.compilePdf(code, {})
      if (seq !== compileSeq) {
        console.log(`[Typst] Compile #${seq} cancelled (newer compile started)`)
        return
      }
      console.log(`[Typst] Compile #${seq} succeeded`)
      setPdfPreview(pdfData.pdf)
      status = 'done'
    } catch (error) {
      if (seq !== compileSeq) {
        console.log(`[Typst] Compile #${seq} error cancelled (newer compile started)`)
        return
      }
      console.error(`[Typst] Compile #${seq} failed:`, error)
      status = 'error'
      errorMessage = error instanceof Error ? error.message : String(error)
    }
  }

  function setPdfPreview(bytes: Uint8Array<ArrayBuffer>) {
    pdfBytes = bytes
    if (pdfUrl) URL.revokeObjectURL(pdfUrl)
    const blob = new Blob([bytes], { type: 'application/pdf' })
    pdfUrl = URL.createObjectURL(blob)
  }

  function downloadPdf() {
    if (!pdfUrl) return
    const a = document.createElement('a')
    a.href = pdfUrl
    a.download = 'document.pdf'
    a.click()
  }

  function openPdfNewTab() {
    if (!pdfUrl) return
    window.open(pdfUrl, '_blank')
  }

  function goToPage(nextPage: number) {
    if (!pdfDoc || !pdfViewer) return
    const clamped = Math.max(1, Math.min(nextPage, pdfPages || 1))
    if (clamped === pdfPage) return
    pdfPage = clamped
    pdfViewer.currentPageNumber = clamped
  }

  function zoomIn() {
    if (!pdfViewer) return
    pdfViewer.currentScale = Math.min(pdfViewer.currentScale * 1.2, 3)
  }

  function zoomOut() {
    if (!pdfViewer) return
    pdfViewer.currentScale = Math.max(pdfViewer.currentScale / 1.2, 0.5)
  }

  function fitWidth() {
    if (!pdfViewer) return
    pdfViewer.currentScaleValue = 'page-width'
  }

  function resetToDefault() {
    if (confirm('Reset to default template? This will erase your current code.')) {
      typstCode = DEFAULT_TEMPLATE
    }
  }

  // Resizer
  function startResize(e: MouseEvent) {
    e.preventDefault()
    isResizing = true
    document.addEventListener('mousemove', onResize)
    document.addEventListener('mouseup', stopResize)
  }

  function onResize(e: MouseEvent) {
    if (!isResizing) return
    const newWidth = (e.clientX / window.innerWidth) * 100
    leftPaneWidth = Math.min(Math.max(newWidth, 20), 80)
  }

  function stopResize() {
    isResizing = false
    document.removeEventListener('mousemove', onResize)
    document.removeEventListener('mouseup', stopResize)
  }
</script>

<svelte:head>
  <title>Typst Online Editor - MDXport</title>
  <meta name="description" content="Online Typst editor with real-time PDF preview" />
</svelte:head>

<div class="app">
  <!-- Navbar -->
  <div class="navbar">
    <div class="navbar-left">
      <h1 class="title">Typst Editor</h1>
    </div>
    <div class="navbar-center">
      <select bind:value={style} class="style-select">
        <option value="modern-tech">Modern</option>
        <option value="classic-editorial">Classic</option>
      </select>
    </div>
    <div class="navbar-right">
      <button onclick={resetToDefault} class="btn" title="Reset to default template">
        🔄 Reset
      </button>
      <button
        onclick={downloadPdf}
        disabled={!pdfUrl || status === 'compiling'}
        class="btn btn-primary"
        title="Download PDF"
      >
        ⬇️ Download
      </button>
      <button
        onclick={openPdfNewTab}
        disabled={!pdfUrl || status === 'compiling'}
        class="btn"
        title="Open in new tab"
      >
        🗗 Open
      </button>
    </div>
  </div>

  <!-- Main Content -->
  <div class="main-content">
    <!-- Editor Pane -->
    <div class="editor-pane" style="width: {leftPaneWidth}%">
      {#if isLoading}
        <div class="loading">Loading editor...</div>
      {:else}
        <div class="editor-container" bind:this={editorContainerEl}></div>
      {/if}
    </div>

    <!-- Resizer -->
    <div
      class="resizer"
      class:active={isResizing}
      onmousedown={startResize}
      role="separator"
      aria-orientation="vertical"
      tabindex="0"
    ></div>

    <!-- Preview Pane -->
    <div class="preview-pane" style="width: {100 - leftPaneWidth}%">
      <div class="preview-toolbar">
        <div class="preview-toolbar-left">
          {#if status === 'compiling'}
            <span class="status-badge compiling">⏳ Compiling...</span>
          {:else if status === 'error'}
            <span class="status-badge error">❌ Error</span>
          {:else if status === 'done'}
            <span class="status-badge success">✓ Ready</span>
          {/if}
        </div>
        <div class="preview-toolbar-center">
          {#if pdfPages > 0}
            <button onclick={() => goToPage(pdfPage - 1)} disabled={pdfPage <= 1} class="btn-icon">
              ‹
            </button>
            <span class="page-info">{pdfPage} / {pdfPages}</span>
            <button
              onclick={() => goToPage(pdfPage + 1)}
              disabled={pdfPage >= pdfPages}
              class="btn-icon"
            >
              ›
            </button>
          {/if}
        </div>
        <div class="preview-toolbar-right">
          <button onclick={zoomOut} class="btn-icon" title="Zoom out">−</button>
          <span class="zoom-info">{Math.round(pdfScale * 100)}%</span>
          <button onclick={zoomIn} class="btn-icon" title="Zoom in">+</button>
          <button onclick={fitWidth} class="btn-icon" title="Fit width">⬌</button>
        </div>
      </div>

      {#if errorMessage}
        <div class="error-message">
          <h3>Compilation Error</h3>
          <pre>{errorMessage}</pre>
        </div>
      {:else}
        <div class="pdf-container" bind:this={pdfContainerEl}>
          <div class="pdfViewer"></div>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, -apple-system, sans-serif;
    overflow: hidden;
  }

  .app {
    display: flex;
    flex-direction: column;
    height: 100vh;
    background: #1e1e1e;
    color: #fff;
  }

  .navbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.75rem 1rem;
    background: #252525;
    border-bottom: 1px solid #333;
    flex-shrink: 0;
  }

  .navbar-left, .navbar-center, .navbar-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .title {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
  }

  .style-select {
    padding: 0.5rem;
    background: #1e1e1e;
    color: #fff;
    border: 1px solid #444;
    border-radius: 4px;
    font-size: 0.875rem;
  }

  .btn {
    padding: 0.5rem 1rem;
    background: #333;
    color: #fff;
    border: 1px solid #444;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.875rem;
    transition: background 0.2s;
  }

  .btn:hover:not(:disabled) {
    background: #444;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-primary {
    background: #0066cc;
    border-color: #0066cc;
  }

  .btn-primary:hover:not(:disabled) {
    background: #0052a3;
  }

  .main-content {
    display: flex;
    flex: 1;
    overflow: hidden;
  }

  .editor-pane, .preview-pane {
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .editor-container {
    flex: 1;
    overflow: auto;
  }

  .loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    font-size: 1.125rem;
    color: #888;
  }

  .resizer {
    width: 5px;
    background: #333;
    cursor: col-resize;
    flex-shrink: 0;
    transition: background 0.2s;
  }

  .resizer:hover, .resizer.active {
    background: #0066cc;
  }

  .preview-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.5rem 1rem;
    background: #252525;
    border-bottom: 1px solid #333;
    flex-shrink: 0;
  }

  .preview-toolbar-left, .preview-toolbar-center, .preview-toolbar-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .status-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 4px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .status-badge.compiling {
    background: #ff9800;
    color: #000;
  }

  .status-badge.error {
    background: #f44336;
  }

  .status-badge.success {
    background: #4caf50;
  }

  .page-info, .zoom-info {
    font-size: 0.875rem;
    color: #ccc;
  }

  .btn-icon {
    width: 2rem;
    height: 2rem;
    padding: 0;
    background: #333;
    color: #fff;
    border: 1px solid #444;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }

  .btn-icon:hover:not(:disabled) {
    background: #444;
  }

  .btn-icon:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .pdf-container {
    position: relative;
    flex: 1;
    overflow: auto;
    background: #2a2a2a;
  }

  .error-message {
    padding: 2rem;
    color: #f44336;
  }

  .error-message h3 {
    margin-top: 0;
  }

  .error-message pre {
    background: #1e1e1e;
    padding: 1rem;
    border-radius: 4px;
    overflow: auto;
    white-space: pre-wrap;
    word-wrap: break-word;
  }
</style>
