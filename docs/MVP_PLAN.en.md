# MDXport MVP Plan (Status as of 2025-12-18)

## Goals and Scope

**Goal**: Under a pure frontend (static deployment) architecture, achieve the closed loop of "input Markdown → generate PDF preview → download/open PDF".

**Engineering Constraints** (see `docs/ENG.md`):

- Full-site static prerender (SvelteKit + adapter-static)
- No `+server.ts` and form actions
- Typst/WASM must be initialized in the browser runtime and compiled in Worker

---

## Completed (v0.0.1 Status)

### Core Pipeline

- Markdown (mdast) → Typst source: `src/lib/pipeline/markdownToTypst.ts`
- Typst(WASM) compilation (Worker): `src/lib/workers/typst.worker.ts`
- Main thread wrapper: `src/lib/workers/typstClient.ts`
- PDF preview (PDF.js viewer): `src/lib/pdf/pdfjs.ts` + `src/lib/components/MainEditor.svelte`

### Routing and Static Deployment

- Site-wide `prerender = true` + `trailingSlash = 'always'`: `src/routes/+layout.ts`
- `/zh/`, `/en/` two entry points, dynamic segments enumerated via `entries`: `src/routes/[lang]/*`

### MVP-level Markdown Support (Implementation Completed)

Covers the most common AI document delivery syntax (see `docs/DESIGN.md` for details):

- Headings, paragraphs, bold/italic/strikethrough, links (including reference-style)
- Lists (supports nesting)
- Fenced code blocks, inline code
- GFM tables
- Math formulas (`$...$` / `$$...$$`)
- Footnotes
- `[toc]` → Typst `#outline(...)`
- Mermaid: ```mermaid → SVG → injected into VFS (compiled as image)

---

## Next Steps (Suggested for v0.0.2 / v0.1)

Sorted by risk priority:

1) **Offline and Resource Strategy Alignment**: Font and wasm resource localization + caching; Analytics toggle (currently has network dependencies).
2) **Image Pipeline**: Drag-and-drop/paste/upload images → inject into VFS → reference management (currently lacks generic entry point aside from Mermaid).
3) **Preflight (Diagnostics + Fixes)**: Turn issues that "cause compilation failures/layout accidents" into explainable, one-click fixable rule sets.
4) **Rendering Enhancements**: Task list checkboxes, table column width strategy, image caption/size control.

---

## Acceptance Recommendations (Regression-ready)

When the project has not introduced a testing framework, it's still recommended to prepare a minimal set for export regression:

- `tests/fixtures/*.md`: tables, long documents, math, emoji, Mermaid, extremely long URL/Token, mixed Chinese-English
- Batch export verification: PDF bytes non-empty, `diagnostics` acceptable, page count/size within reasonable thresholds
