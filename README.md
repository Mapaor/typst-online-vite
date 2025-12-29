# Typst Online Editor

**A minimal, fast, and privacy-focused online editor for Typst.**

A lightweight web-based Typst editor that compiles documents directly in your browser using WebAssembly. No servers, no data collection, just pure client-side compilation.

## ✨ Features

- **Pure Client-Side**: Runs entirely in your browser using Typst WASM. Your documents never leave your device.
- **Real-Time Compilation**: Automatic compilation as you type with smart debouncing.
- **Live PDF Preview**: Instant preview of your compiled PDF document.
- **Fast & Lightweight**: Minimal dependencies, optimized for performance.
- **No Setup Required**: No installation, no account, no configuration. Just open and start writing.
- **Offline-Ready**: Works without an internet connection once loaded.

## 🚀 Quick Start

### Online

Visit the hosted version (add your deployment URL here) to start using it immediately.

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/mdxport.git
   cd mdxport
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start the development server**
   ```bash
   npm run dev
   ```

4. **Build for production**
   ```bash
   npm run build
   ```

## 🏗️ Architecture

This project uses a **framework-agnostic architecture** that separates UI from business logic, making it easy to port to other frameworks (React, Vue, Angular, etc.).

### Core Structure
- **Framework-Agnostic Layers**:
  - `TypstCompilerService` - Manages compilation with event-based API
  - `TypstWorkerClient` - Web Worker client for background compilation
  - `typst.worker.ts` - WASM compiler running in worker thread
  - Pure TypeScript, zero framework dependencies

- **UI Layer** (Framework-Specific):
  - `TypstEditor.svelte` - Svelte 5 component (easily replaceable)

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation and migration examples.

## 🛠️ Tech Stack

- **Framework**: [Svelte 5](https://svelte.dev/) + [SvelteKit](https://kit.svelte.dev/)
- **Typesetting**: [Typst](https://typst.app/) via [@myriaddreamin/typst.ts](https://github.com/Myriad-Dreamin/typst.ts)
- **PDF Preview**: [PDF.js](https://mozilla.github.io/pdf.js/)
- **Build Tool**: [Vite](https://vitejs.dev/)

## 📦 Key Dependencies

- `@myriaddreamin/typst.ts` - Typst WASM compiler
- `pdfjs-dist` - PDF rendering
- `svelte` - UI framework
- All compilation logic is framework-agnostic TypeScript

## 🎯 Why This Project?

- **Privacy**: No server-side processing means your documents stay private
- **Speed**: WASM compilation is fast and runs locally
- **Simplicity**: Minimal features, maximum usability
- **Portable**: Framework-agnostic core makes migration easy

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

Built with ❤️ using [Typst](https://typst.app/) and [Svelte](https://svelte.dev/)

