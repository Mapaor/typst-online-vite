<script lang="ts">
  import { onMount } from 'svelte'
  import { TypstWorkerClient } from '$lib/workers/typstClient'
  import { getPdfjs } from '$lib/pdf/pdfjs'
  import type { PDFDocumentProxy } from 'pdfjs-dist'
  
  console.log('[Debug] Component loaded')
  
  let typstCode = $state(`= Hello Typst

This is a test.`)
  let status = $state<'idle' | 'compiling' | 'done' | 'error'>('idle')
  let client = $state<TypstWorkerClient | null>(null)
  let pdfBytes = $state<Uint8Array<ArrayBuffer> | null>(null)
  let pdfUrl = $state<string | null>(null)
  let errorMsg = $state<string | null>(null)
  let compileCount = $state(0)
  let autoCompileTimer: number | null = null
  
  console.log('[Debug] Initial state set')
  
  // Auto-compile on code changes (debounced)
  $effect(() => {
    const code = typstCode
    
    if (autoCompileTimer) window.clearTimeout(autoCompileTimer)
    
    autoCompileTimer = window.setTimeout(() => {
      if (client) {
        console.log('[Debug] Auto-compile triggered')
        void compile()
      }
    }, 1000) // 1 second debounce
    
    return () => {
      if (autoCompileTimer) window.clearTimeout(autoCompileTimer)
    }
  })
  
  onMount(() => {
    console.log('[Debug] onMount called')
    client = new TypstWorkerClient()
    console.log('[Debug] Worker client created')
    
    return () => {
      if (pdfUrl) URL.revokeObjectURL(pdfUrl)
    }
  })
  
  async function compile() {
    if (!client) {
      console.log('[Debug] Compile skipped: no client')
      return
    }
    
    compileCount++
    const currentCompile = compileCount
    console.log(`[Debug] Starting compile #${currentCompile}`)
    status = 'compiling'
    errorMsg = null
    
    try {
      const result = await client.compilePdf(typstCode, {})
      if (currentCompile !== compileCount) {
        console.log(`[Debug] Compile #${currentCompile} cancelled`)
        return
      }
      console.log(`[Debug] Compile #${currentCompile} succeeded, PDF size: ${result.pdf.length} bytes`)
      
      // Create blob URL for PDF
      if (pdfUrl) URL.revokeObjectURL(pdfUrl)
      const blob = new Blob([result.pdf], { type: 'application/pdf' })
      pdfUrl = URL.createObjectURL(blob)
      pdfBytes = result.pdf
      
      status = 'done'
    } catch (error) {
      if (currentCompile !== compileCount) {
        console.log(`[Debug] Compile #${currentCompile} error cancelled`)
        return
      }
      console.error(`[Debug] Compile #${currentCompile} failed:`, error)
      status = 'error'
      errorMsg = error instanceof Error ? error.message : String(error)
    }
  }
  
  function downloadPdf() {
    if (!pdfUrl) return
    const a = document.createElement('a')
    a.href = pdfUrl
    a.download = 'document.pdf'
    a.click()
  }
</script>

<div class="editor-container">
  <div class="navbar">
    <h1 class="title">Typst Editor (Debug Mode)</h1>
    <div class="status">
      Status: {status}
      {#if client}✓ Worker Ready{:else}⏳ Loading...{/if}
    </div>
    <button class="btn" onclick={compile} disabled={!client || status === 'compiling'}>
      Compile Now
    </button>
    {#if pdfUrl}
      <button class="btn" onclick={downloadPdf}>Download PDF</button>
    {/if}
  </div>
  
  <div class="content">
    <div class="editor-pane">
      <textarea 
        bind:value={typstCode}
        placeholder="Type Typst code here..."
      ></textarea>
    </div>
    
    <div class="preview-pane">
      {#if pdfUrl}
        <iframe src={pdfUrl} title="PDF Preview" class="pdf-iframe"></iframe>
      {:else}
        <div class="preview-placeholder">
          {#if status === 'compiling'}
            <p>⏳ Compiling...</p>
          {:else if status === 'error'}
            <p style="color: #f44336">❌ Error</p>
            <pre>{errorMsg}</pre>
          {:else}
            <p>Click "Compile Now" to generate PDF</p>
          {/if}
          <p style="margin-top: 1rem; font-size: 0.875rem;">Code: {typstCode.length} chars | Compiles: {compileCount}</p>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .editor-container {
    display: flex;
    flex-direction: column;
    height: 100vh;
    background: #1e1e1e;
    color: #fff;
  }

  .navbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: #252525;
    border-bottom: 1px solid #333;
  }

  .title {
    margin: 0;
    font-size: 1.25rem;
  }

  .btn {
    padding: 0.5rem 1rem;
    background: #0066cc;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .content {
    display: flex;
    flex: 1;
    overflow: hidden;
  }

  .editor-pane {
    flex: 1;
    display: flex;
    flex-direction: column;
    border-right: 1px solid #333;
  }

  textarea {
    flex: 1;
    background: #1e1e1e;
    color: #fff;
    border: none;
    padding: 1rem;
    font-family: monospace;
    font-size: 14px;
    resize: none;
  }

  .preview-pane {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #2a2a2a;
    position: relative;
  }

  .pdf-iframe {
    width: 100%;
    height: 100%;
    border: none;
  }

  .preview-placeholder {
    text-align: center;
    color: #888;
  }
</style>
