---
status: draft
owner: formula
version: 0.4
last_reviewed: 2025-12-18
product_name: MDXport
tech_route: typst_wasm_client_only
tags: [prd, markdown, export, pdf, client-only, typst, wasm, sveltekit, ai-doc]
---

# MDXport Design Document (Based on Current Implementation)

## 0. One-Liner

MDXport is a pure frontend static site: it converts Markdown to Typst in the browser, then compiles to PDF using Typst WASM in a Web Worker, and finally previews and downloads using PDF.js.

> This document separates "implemented features" from "roadmap": **defaults to current codebase status**.

---

## 1. Current Version Scope (v0.0.1)

### 1.1 Implemented Capabilities

- **Edit & Export**: Left-side Markdown editor, right-side real-time PDF preview; supports download and opening in new tab (`src/lib/components/MainEditor.svelte`).
- **Multi-language Routing**: `/zh/` and `/en/` entry points; root path redirects based on locale preference (`src/routes/+page.svelte`, `src/routes/[lang]/*`).
- **Templates/Styles**: Two Typst styles `modern-tech` / `classic-editorial` (`src/lib/typst/styles/*`).
- **Mermaid**: Supports ```mermaid fenced blocks; preprocessed to SVG and injected into Typst VFS (`src/lib/mermaid/render.ts` + `MainEditor` preprocessing).
- **Conversion Pipeline**: Markdown (mdast) → Typst source → Typst(WASM) compilation → PDF bytes (`src/lib/pipeline/markdownToTypst.ts`, `src/lib/workers/*`).

### 1.2 Not Yet Implemented (but may have been mentioned in docs/marketing)

- Preflight (diagnostics and one-click fixes)
- Stable Document IR (currently mdast directly renders to Typst)
- "Offline-first" and font/resource localization (fonts currently loaded from network URLs)
- Generic image/attachment import (currently only Mermaid-generated resources can reliably enter VFS)

---

## 2. Markdown Profile (Current Support Range)

### 2.1 YAML Frontmatter (for template metadata)

Parsing implementation: `src/lib/pipeline/markdownToTypst.ts` (`parseFrontmatter*`).

- `title`: string
- `author`: string
- `authors`: string[] (also supports `authors: [a, b]` or YAML list)
- `lang` / `language`: `zh` / `en`

Title priority: `options.title` → `frontmatter.title` → "first H1 at the beginning".

### 2.2 Block-level Syntax

- Headings: H1~H6
- Paragraphs
- Ordered/unordered lists (supports nesting)
- Blockquotes
- Fenced code blocks
- Horizontal rules (`---`)
- GFM tables
- Math blocks (`$$...$$`)

### 2.3 Inline Syntax

- Bold, italic, strikethrough (GFM)
- Inline code
- Links (inline / reference-style)
- Inline math (`$...$`)
- Footnote references (GFM footnote)
- Superscript/subscript (`^sup^` / `~sub~`, custom plugin)

### 2.4 Special Conventions

- `[toc]`: When a paragraph content **exactly equals** `[toc]` (case-insensitive, trimmed whitespace), generates Typst `#outline(...)`.
- Mermaid: `MainEditor` renders ```mermaid blocks to SVG, then replaces with Markdown image reference `![](<id>.svg)`, and injects SVG bytes into compilation VFS.

### 2.5 Known Limitations/Incomplete Support (Important)

- **Task Lists** (`- [x]` / `- [ ]`): checkbox state currently lost, degrades to normal lists.
- **Regular Images**: `![](path-or-url)` renders to Typst `#image("...")`, but aside from Mermaid there's currently no generic entry point to inject image bytes into VFS; remote URLs are not automatically downloaded, which may cause Typst compilation failures.
- **Embedded HTML**: mdast's `html` nodes are currently not rendered (equivalent to ignored/discarded), not recommended to rely on.
- **Highlighting**: Code has `mark` branch, but `remark-mark` is currently not enabled, so `==highlight==` is not guaranteed to work.

---

## 3. System Architecture (Current Implementation)

### 3.1 Data Flow (from Input to PDF)

```
Markdown (string)
  ├─ Mermaid preprocessing: ```mermaid → SVG bytes → ![](id.svg)
  ├─ markdownToTypst: mdast → main.typ
  └─ TypstWorkerClient.compilePdf(main.typ, images)
        └─ typst.worker:
            - Initialize/upgrade Typst compiler (WASM)
            - Font loading (on-demand CJK/Emoji)
            - Inject /main.typ and image bytes (VFS)
            - compile → PDF bytes + diagnostics

PDF bytes
  ├─ Blob URL (download/new tab)
  └─ PDF.js viewer (page number/zoom/links)
```

### 3.2 Modules and Responsibilities (Code Locations)

- UI:
  - `src/lib/components/MainEditor.svelte`: Editor, compilation trigger (debounce + cancellation sequence), Mermaid preprocessing, PDF.js viewer initialization
- Pipeline:
  - `src/lib/pipeline/markdownToTypst.ts`: Unified parsing and rendering (`remark-parse` / `remark-gfm` / `remark-math` / custom supersub)
- Worker:
  - `src/lib/workers/typstClient.ts`: Main thread call wrapper (request/response + pending map)
  - `src/lib/workers/typst.worker.ts`: WASM initialization, font loading, typst source and resource injection, compilation queue
- Preview:
  - `src/lib/pdf/pdfjs.ts`: PDF.js dynamic loading and worker configuration
- Typst Styles:
  - `src/lib/typst/styles/*`: Stylized template entry `article(...)`

---

## 4. Typst Template System (Current Form)

### 4.1 Constraint: Styles in Templates, Body Only Generates Content

Current `markdownToTypst` is only responsible for:

1) Select and `#import "styles/<style>.typ": article`
2) `#show: article.with(title/authors/lang)`
3) Render Markdown content nodes to Typst markup (heading/list/table/raw/...)

All typesetting rules (font stack, paragraphs, headings, quotes, code block styles, etc.) are centralized in `src/lib/typst/styles/*`.

### 4.2 Adding New Styles (Agreed Process)

1) Create `src/lib/typst/styles/<new-style>.typ`, and expose `#let article(...) = { ... }`
2) Extend `src/lib/pipeline/markdownToTypst.ts`:
   - Add new enum to `TypstStyleId`
   - Register `{ path, entry }` in `STYLE_TO_TEMPLATE`
3) Extend `src/lib/workers/typst.worker.ts`:
   - `import ...?raw`
   - `compiler.addSource('/styles/<new-style>.typ', ...)`

> Note: `src/lib/typst/lib.typ` is still in the repository, but is not currently used by the converter, can be viewed as historical/backup template.

---

## 5. Font and Network Strategy (Current Status and Goals)

### 5.1 Current Status (Code's Actual Behavior)

- Typst Worker loads font resources from network URLs (`src/lib/workers/typst.worker.ts`).
- Uses regex to detect document content, if it contains **CJK or Emoji**, upgrades the compiler and loads additional fonts.

This means:

- **First render may require network** (especially for documents containing Chinese/emoji)
- Offline scenarios may experience "missing fonts/compilation failures/rendering degradation"

### 5.2 Goals (Consistent with "Offline-first" Direction)

- Localize fonts and WASM resources (place in `static/` or use Vite assets), with persistent caching (CacheStorage/IDB)
- Remote resource loading must be explicitly opt-in (e.g., switch or "online font provider" option)

---

## 6. Roadmap (Moving Forward from Current Status)

- Preflight: Turn common AI draft issues (tables, lists, code fences, overly long tokens, external image links, etc.) into diagnostics + fixes
- Resource Pipeline: Image/attachment import → VFS mapping → reference management
- Offline Font Package: Basic/Full, caching, optional subsetting (mobile memory peak control)
- Typst Mapping Enhancements: Task list checkboxes, table column width strategy, image caption and size control

---

## 7. Quality and Regression (Recommended to Complete)

Currently no testing framework configured; suggest preparing export regression fixtures early:

- `tests/fixtures/*.md`: Cover tables, long documents, math, emoji, Mermaid, extremely long URL/Token, mixed Chinese-English
- Batch compilation verification: `diagnostics` acceptable, PDF bytes non-empty, page count/size within reasonable thresholds
