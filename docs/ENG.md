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

# MDXport 工程文档（以当前仓库实现为准）

## 0. 强约束（红线）

- **全站静态**：SvelteKit + `@sveltejs/adapter-static`，构建产物可直接部署到静态托管（`svelte.config.js`）。
- **禁止服务端能力**：不新增 `+server.ts`、不使用 form actions。
- **prerender/SSR 边界**：prerender 会在构建期执行路由渲染；任何浏览器 API（`window/document/indexedDB/caches` 等）只能在 `onMount` 或 `browser` 分支内使用。
- **重计算放 Worker**：Typst 编译必须在 Web Worker 内完成，避免阻塞 UI。
- **离线目标 vs 当前现状**：当前字体通过网络 URL 加载、并注入了 Vercel Analytics（`src/hooks.client.ts`），因此“默认离线”并未达成；如需严格离线需改造（见 §6.3）。

---

## 1. 开发命令

- 安装：`npm install`
- 开发：`npm run dev`
- 类型检查：`npm run check`
- 构建：`npm run build`
- 预览构建：`npm run preview`

---

## 2. 当前目录结构（关键路径）

```
src/
  routes/
    +layout.ts                       # 全站 prerender + trailingSlash
    +layout.svelte
    +page.svelte                     # /：客户端按语言偏好跳转到 /{lang}/
    [lang]/
      +layout.ts                     # 校验 lang 参数 + trailingSlash
      +layout.svelte
      +page.svelte                   # 编辑器页（引用 MainEditor）
      +page.ts                       # entries：为 prerender 枚举语言
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
    components/MainEditor.svelte     # 核心 UI：编辑/预览/导出/Mermaid 预处理
    pipeline/markdownToTypst.ts      # Markdown(mdast) → Typst 源码
    pipeline/plugins/remark-simple-supersub.ts
    workers/typstClient.ts           # Worker client（compilePdf）
    workers/typst.worker.ts          # Typst(WASM) 编译（fonts + VFS + diagnostics）
    typst/styles/*.typ               # Typst 风格模板（modern-tech / classic-editorial）
    pdf/pdfjs.ts                     # PDF.js 动态加载与 worker 配置
    mermaid/render.ts                # Mermaid → SVG bytes
    i18n/lang.ts                     # SUPPORTED_LANGS / isUILang
  hooks.client.ts                    # Analytics 注入（可选）
static/                              # 静态资源（logo/favicon/robots）
docs/                                # 设计/工程/计划文档
```

---

## 3. 路由与 prerender 约定

### 3.1 全站 prerender 与 trailingSlash

- `src/routes/+layout.ts`：
  - `export const prerender = true`
  - `export const trailingSlash = 'always'`
- `src/routes/[lang]/+layout.ts`：
  - 校验 `params.lang` 必须是 `SUPPORTED_LANGS`
  - `load()` 返回 `{ lang }` 给页面组件使用

### 3.2 动态参数路由必须提供 `entries`

由于存在 `[lang]` 动态段，所有需要 prerender 的页面必须导出 `entries`（`EntryGenerator`）来枚举语言：

- `src/routes/[lang]/+page.ts`
- `src/routes/[lang]/resources/+page.ts`
- `src/routes/[lang]/convert-chatgpt-table-to-pdf/+page.ts`
- `src/routes/[lang]/notion-export-pdf-layout-fix/+page.ts`
- `src/routes/[lang]/secure-offline-markdown-to-pdf-converter/+page.ts`
- `src/routes/[lang]/typst-online-editor-alternative/+page.ts`

约定写法：

```ts
import { SUPPORTED_LANGS } from '$lib/i18n/lang';
import type { EntryGenerator } from './$types';

export const entries: EntryGenerator = () => SUPPORTED_LANGS.map((lang) => ({ lang }));
```

### 3.3 根路径跳转的实现方式

`src/routes/+page.svelte` 使用 `onMount()` + `goto()` 做客户端跳转，避免构建期 prerender 发生“不可预期重定向”。

---

## 4. Markdown → Typst → PDF 的实现

### 4.1 Markdown→Typst（主线程纯函数）

实现：`src/lib/pipeline/markdownToTypst.ts`

- 解析：`unified + remark-parse + remark-frontmatter + remark-gfm + remark-math + remark-simple-supersub`
- 功能点：
  - 支持 frontmatter（title/authors/lang）
  - 支持 `[toc]` → Typst `#outline(...)`
  - 支持表格、脚注、数学、引用、列表、代码块等（详见 `docs/DESIGN.md`）
- 产物：返回一个可编译的 `main.typ` 字符串（含 `#import` 与 `#show`）

### 4.2 Typst 编译（Worker）

实现：

- 客户端封装：`src/lib/workers/typstClient.ts`
- Worker 入口：`src/lib/workers/typst.worker.ts`

消息协议（精简）：

- request：`{ type: 'compile', id, mainTypst, images }`
- response：`{ type: 'compile-result', id, ok, pdf?, diagnostics, error? }`

关键工程点：

- Worker 内用 `compileQueue` 串行化编译，避免 Typst compiler 状态并发冲突。
- Typst 样式通过 `?raw` 导入为字符串，并通过 `compiler.addSource('/styles/xxx.typ', ...)` 写入 VFS。
- 图片通过 `compiler.mapShadow('/' + path, bytes)` 注入 VFS（当前主要用于 Mermaid SVG）。

### 4.3 Vite Worker 打包约定

- Worker 创建写法（已封装在 `TypstWorkerClient`）：

```ts
new Worker(new URL('./typst.worker.ts', import.meta.url), { type: 'module' });
```

- `vite.config.ts` 明确 `worker.format = 'es'`。

---

## 5. PDF 预览（PDF.js）

实现：`src/lib/pdf/pdfjs.ts` + `MainEditor`

- `getPdfjs()` 动态 import `pdfjs-dist`，并设置 `GlobalWorkerOptions.workerSrc`
- viewer 侧使用 `pdfjs-dist/web/pdf_viewer.mjs` 的 `PDFViewer / PDFLinkService / EventBus`
- 事件：
  - `pagesinit`：默认 `page-width`
  - `pagechanging/scalechanging`：同步 UI 状态

---

## 6. 字体、联网与离线

### 6.1 当前字体策略（会联网）

实现：`src/lib/workers/typst.worker.ts`

- 默认加载一组 core fonts（含数学字体）
- 当检测到文档包含 CJK/Emoji 时，升级编译器并额外加载字体
- 字体来源目前是外部 URL（CDN / Google Fonts），首次渲染需要网络

### 6.2 Analytics（会联网）

`src/hooks.client.ts` 通过 `@vercel/analytics/sveltekit` 注入分析脚本，会产生网络请求；若需要“严格离线”，应提供开关或移除。

### 6.3 若要达成“默认离线”的改造清单（建议）

- 字体本地化：将所需字体放入 `static/fonts/` 或使用 Vite asset import，替换 `loadFonts([...urls])` 为本地资源加载
- 缓存：对 wasm/font 做 CacheStorage 缓存（或用 IDB 管理版本）
- 资源策略：远程图片/字体改为显式 opt-in（UI 开关 + 安全提示）

---

## 7. Mermaid 支持（实现方式）

实现：`src/lib/mermaid/render.ts` + `MainEditor` 预处理

- `renderMermaidToSvg(code, id)` 返回 SVG bytes（`TextEncoder`）
- `MainEditor` 扫描 fenced `mermaid` 代码块：
  - 渲染 SVG 并写入 `images["mermaid-<n>.svg"]`
  - 替换 Markdown 块为 `![Mermaid Diagram](mermaid-<n>.svg)`
  - 后续 `markdownToTypst` 会输出 `#image("mermaid-<n>.svg")`，Worker 把同名 bytes 注入 VFS

---

## 8. 已知缺口（与设计目标的差距）

- Preflight/一键修复：尚未实现
- 普通图片导入：除 Mermaid 外没有通用入口（导致 `#image("...")` 大概率找不到文件）
- 任务列表 checkbox：目前会退化为普通列表
- “默认离线”：字体与 analytics 仍依赖网络
