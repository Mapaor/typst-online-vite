# Typst Editor - Framework-Agnostic Architecture

## Overview
This project is structured to separate framework-agnostic logic from UI framework code, making it easy to port to different frameworks (React, Vue, Angular, etc.).

## Framework-Agnostic Core (Ready for Next.js/React)

### 1. **Typst Compilation Layer**
- `src/lib/typst/TypstCompilerService.ts` - Main compiler service with event-based API
  - Uses observer pattern with listeners
  - Manages PDF blob URLs
  - Handles compile sequencing
  - Pure TypeScript, no framework dependencies

- `src/lib/workers/typstClient.ts` - Web Worker client
  - Standard Web Workers API
  - Promise-based compilation
  - Worker lifecycle management
  - Pure TypeScript, no framework dependencies

- `src/lib/workers/typst.worker.ts` - Worker implementation
  - Runs Typst WASM compiler in background thread
  - Handles font loading (Core, CJK, Emoji)
  - Message-based communication
  - Pure TypeScript, no framework dependencies

### 2. **PDF.js Layer**
- `src/lib/pdf/pdfjs.ts` - PDF.js loader and configuration
  - Dynamic import of PDF.js
  - Worker configuration
  - Global setup for PDF.js viewer
  - Pure TypeScript, no framework dependencies

### 3. **Utilities**
- `src/lib/utils/helpers.ts` - Helper functions
  - `debounce()` - Generic debouncing utility
  - `downloadBlob()` - File download helper
  - `downloadPdfFromUrl()` - PDF download helper
  - Pure TypeScript, no framework dependencies

## Framework-Specific Layer (Svelte)

### UI Component
- `src/lib/components/TypstEditor.svelte` - Svelte UI component
  - Uses TypstCompilerService for compilation
  - Manages UI state with Svelte 5 runes
  - Debounced auto-compilation
  - PDF preview with iframe

## Usage Pattern

### In Svelte (Current)
```svelte
<script lang="ts">
  import { onMount } from 'svelte'
  import { TypstCompilerService } from '$lib/typst/TypstCompilerService'
  import { debounce } from '$lib/utils/helpers'
  
  let compilerService: TypstCompilerService | null = null
  
  onMount(() => {
    compilerService = new TypstCompilerService()
    
    const unsubscribe = compilerService.addListener({
      onStatusChange: (status) => { /* update UI */ },
      onSuccess: (pdf, url) => { /* show PDF */ },
      onError: (error) => { /* show error */ }
    })
    
    return () => {
      unsubscribe()
      compilerService?.dispose()
    }
  })
</script>
```

### In React/Next.js (Future)
```tsx
import { useEffect, useState } from 'react'
import { TypstCompilerService } from '@/lib/typst/TypstCompilerService'
import { debounce } from '@/lib/utils/helpers'

function TypstEditor() {
  const [compilerService] = useState(() => new TypstCompilerService())
  const [status, setStatus] = useState('idle')
  const [pdfUrl, setPdfUrl] = useState<string | null>(null)
  
  useEffect(() => {
    const unsubscribe = compilerService.addListener({
      onStatusChange: setStatus,
      onSuccess: (pdf, url) => setPdfUrl(url),
      onError: (error) => console.error(error)
    })
    
    return () => {
      unsubscribe()
      compilerService.dispose()
    }
  }, [compilerService])
  
  return (
    <div>
      <textarea onChange={debounce((e) => 
        compilerService.compile(e.target.value), 1000
      )} />
      {pdfUrl && <iframe src={pdfUrl} />}
    </div>
  )
}
```

## Migration Checklist for Next.js

1. **Copy framework-agnostic files as-is:**
   - ✅ `src/lib/typst/TypstCompilerService.ts`
   - ✅ `src/lib/workers/typstClient.ts`
   - ✅ `src/lib/workers/typst.worker.ts`
   - ✅ `src/lib/pdf/pdfjs.ts`
   - ✅ `src/lib/utils/helpers.ts`

2. **Replace UI component:**
   - ❌ Delete `src/lib/components/TypstEditor.svelte`
   - ✅ Create React component using same service APIs

3. **Update imports:**
   - Change `$lib/` aliases to Next.js `@/` aliases
   - Or use relative paths (already done in core files)

## Dependencies
- `@myriaddreamin/typst.ts` - Typst WASM compiler
- `pdfjs-dist` - PDF.js library
- Standard Web APIs only (no framework dependencies in core)

## Key Design Decisions

1. **Observer Pattern**: Used in TypstCompilerService for framework-agnostic reactivity
2. **Web Workers**: Keeps heavy compilation off main thread
3. **Relative Imports**: Core files use relative paths, not framework aliases
4. **Event-Based API**: Listeners instead of framework-specific reactivity
5. **Promise-Based**: All async operations return Promises
6. **URL Management**: Service manages blob URLs to prevent memory leaks

## File Structure
```
src/lib/
├── typst/
│   └── TypstCompilerService.ts    (Framework-agnostic)
├── workers/
│   ├── typstClient.ts             (Framework-agnostic)
│   └── typst.worker.ts            (Framework-agnostic)
├── pdf/
│   └── pdfjs.ts                   (Framework-agnostic)
├── utils/
│   └── helpers.ts                 (Framework-agnostic)
└── components/
    └── TypstEditor.svelte         (Framework-specific)
```

## Testing
All framework-agnostic files can be unit tested without any framework:
- No Svelte/React/Vue imports
- No framework-specific APIs
- Standard JavaScript/TypeScript only
- Can be tested in Node.js or browser environment
