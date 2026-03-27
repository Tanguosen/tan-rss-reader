/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

declare global {
  interface Window {
    electron?: {
      shell?: {
        openExternal: (url: string) => void
      }
    }
  }
}

export {}
