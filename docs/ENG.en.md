---
status: draft
owner: formula
version: 0.2
last_reviewed: 2025-12-18
product_name: MDXport
scope: engineering
stack: sveltekit_adapter_static_prerender
tags: [sveltekit, adapter-static, prerender, typst, wasm, worker, pdfjs, svelte5]
---

# MDXport Engineering Document (Based on Current Repository Implementation)

## 0. Hard Constraints (Red Lines)

- **Fully Static Site**: SvelteKit + `@sveltejs/adapter-static`, build output can be directly deployed to static hosting (`svelte.config.js`).
- **No Server-side Capabilities**: Do not add `+server.ts`, do not use form actions.
- **prerender/SSR Boundary**: prerender executes route rendering at build time; any browser APIs (`window/document/indexedDB/caches`, etc.) can only be used within `onMount` or `browser` branches.
- **Heavy Computation in Workers**: Typst compilation must be completed in Web Workers to avoid blocking UI.
- **Offline Goal vs Current Status**: Currently fonts are loaded from network URLs, and Vercel Analytics is injected (`src/hooks.client.ts`), so "offline-first" has not been achieved; strict offline requires refactoring (see §6.3).

---

## 1. Development Commands

- Install: `npm install`
- Develop: `npm run dev`
- Type check: `npm run check`
- Build: `npm run build`
- Preview build: `npm run preview`

---

## 2. Current Directory Structure (Key Paths)

```
src/
  routes/
    +layout.ts                       # Site-wide prerender + trailingSlash
    +layout.svelte
    +page.svelte                     # /: client-side redirect to /{lang}/ based on language preference
    [lang]/
      +layout.ts                     # Validate lang parameter + trailingSlash
      +layout.svelte
      +page.svelte                   # Editor page (uses MainEditor)
      +page.ts                       # entries: enumerate languages for prerender
      resources/
        +page.svelte
        +page.ts
      convert-chatgpt-table-to-pdf/
        +page.svelte
        +page.ts
      notion-export-pdf-layout-fix/
        +page.svelte
        +page.ts
      secure-offline-markdown-to-pdf-converter/
        +page.svelte
        +page.ts
      typst-online-editor-alternative/
        +page.svelte
        +page.ts
  lib/
    components/MainEditor.svelte     # Core UI: edit/preview/export/Mermaid preprocessing
    pipeline/markdownToTypst.ts      # Markdown(mdast) → Typst source
    pipeline/plugins/remark-simple-supersub.ts
    workers/typstClient.ts           # Worker client (compilePdf)
    workers/typst.worker.ts          # Typst(WASM) compilation (fonts + VFS + diagnostics)
    typst/styles/*.typ               # Typst style templates (modern-tech / classic-editorial)
    pdf/pdfjs.ts                     # PDF.js dynamic loading and worker configuration
    mermaid/render.ts                # Mermaid → SVG bytes
    i18n/lang.ts                     # SUPPORTED_LANGS / isUILang
  hooks.client.ts                    # Analytics injection (optional)
static/                              # Static assets (logo/favicon/robots)
docs/                                # Design/engineering/plan documents
```

---

## 3. Routing and prerender Conventions

### 3.1 Site-wide prerender and trailingSlash

- `src/routes/+layout.ts`:
  - `export const prerender = true`
  - `export const trailingSlash = 'always'`
- `src/routes/[lang]/+layout.ts`:
  - Validates `params.lang` must be in `SUPPORTED_LANGS`
  - `load()` returns `{ lang }` for page components

### 3.2 Dynamic Parameter Routes Must Provide `entries`

Due to the `[lang]` dynamic segment, all pages that need prerender must export `entries` (`EntryGenerator`) to enumerate languages:

- `src/routes/[lang]/+page.ts`
- `src/routes/[lang]/resources/+page.ts`
- `src/routes/[lang]/convert-chatgpt-table-to-pdf/+page.ts`
- `src/routes/[lang]/notion-export-pdf-layout-fix/+page.ts`
- `src/routes/[lang]/secure-offline-markdown-to-pdf-converter/+page.ts`
- `src/routes/[lang]/typst-online-editor-alternative/+page.ts`

Conventional pattern:

```ts
import { SUPPORTED_LANGS } from '$lib/i18n/lang';
import type { EntryGenerator } from './$types';

export const entries: EntryGenerator = () => SUPPORTED_LANGS.map((lang) => ({ lang }));
```

### 3.3 Root Path Redirect Implementation

`src/routes/+page.svelte` uses `onMount()` + `goto()` for client-side redirect, avoiding "unpredictable redirects" during build-time prerender.

---

## 4. Markdown → Typst → PDF Implementation

### 4.1 Markdown→Typst (Main Thread Pure Function)

Implementation: `src/lib/pipeline/markdownToTypst.ts`

- Parsing: `unified + remark-parse + remark-frontmatter + remark-gfm + remark-math + remark-simple-supersub`
- Features:
  - Supports frontmatter (title/authors/lang)
  - Supports `[toc]` → Typst `#outline(...)`
  - Supports tables, footnotes, math, quotes, lists, code blocks, etc. (see `docs/DESIGN.md` for details)
- Output: Returns a compilable `main.typ` string (includes `#import` and `#show`)

### 4.2 Typst Compilation (Worker)

Implementation:

- Client wrapper: `src/lib/workers/typstClient.ts`
- Worker entry: `src/lib/workers/typst.worker.ts`

Message protocol (simplified):

- request: `{ type: 'compile', id, mainTypst, images }`
- response: `{ type: 'compile-result', id, ok, pdf?, diagnostics, error? }`

Key engineering points:

- Worker uses `compileQueue` to serialize compilation, avoiding Typst compiler state concurrency conflicts.
- Typst styles are imported as strings via `?raw` and written to VFS via `compiler.addSource('/styles/xxx.typ', ...)`.
- Images are injected into VFS via `compiler.mapShadow('/' + path, bytes)` (currently mainly for Mermaid SVG).

### 4.3 Vite Worker Bundling Conventions

- Worker creation pattern (wrapped in `TypstWorkerClient`):

```ts
new Worker(new URL('./typst.worker.ts', import.meta.url), { type: 'module' });
```

- `vite.config.ts` explicitly sets `worker.format = 'es'`.

---

## 5. PDF Preview (PDF.js)

Implementation: `src/lib/pdf/pdfjs.ts` + `MainEditor`

- `getPdfjs()` dynamically imports `pdfjs-dist` and sets `GlobalWorkerOptions.workerSrc`
- Viewer uses `PDFViewer / PDFLinkService / EventBus` from `pdfjs-dist/web/pdf_viewer.mjs`
- Events:
  - `pagesinit`: defaults to `page-width`
  - `pagechanging/scalechanging`: syncs UI state

---

## 6. Fonts, Network, and Offline

### 6.1 Current Font Strategy (Requires Network)

Implementation: `src/lib/workers/typst.worker.ts`

- Loads a core set of fonts by default (including math fonts)
- When document contains CJK/Emoji detected, upgrades compiler and loads additional fonts
- Font sources are currently external URLs (CDN / Google Fonts), first render requires network

### 6.2 Analytics (Requires Network)

`src/hooks.client.ts` injects analytics script via `@vercel/analytics/sveltekit`, which generates network requests; for "strict offline", should provide a switch or remove.

### 6.3 Refactoring Checklist for "Offline-first" Goal (Recommended)

- Font localization: Place required fonts in `static/fonts/` or use Vite asset imports, replace `loadFonts([...urls])` with local resource loading
- Caching: Implement CacheStorage caching for wasm/fonts (or use IDB for version management)
- Resource Strategy: Remote images/fonts should be explicitly opt-in (UI switch + security notice)

---

## 7. Mermaid Support (Implementation)

Implementation: `src/lib/mermaid/render.ts` + `MainEditor` preprocessing

- `renderMermaidToSvg(code, id)` returns SVG bytes (`TextEncoder`)
- `MainEditor` scans fenced `mermaid` code blocks:
  - Renders SVG and writes to `images["mermaid-<n>.svg"]`
  - Replaces Markdown block with `![Mermaid Diagram](mermaid-<n>.svg)`
  - Later `markdownToTypst` outputs `#image("mermaid-<n>.svg")`, Worker injects corresponding bytes into VFS

---

## 8. Known Gaps (vs Design Goals)

- Preflight/one-click fixes: Not yet implemented
- Generic image import: No generic entry point aside from Mermaid (causes `#image("...")` to likely not find file)
- Task list checkboxes: Currently degrades to normal lists
- "Offline-first": Fonts and analytics still depend on network
