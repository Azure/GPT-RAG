/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ORCHESTRATOR_ENDPOINT: string
  readonly VITE_ENABLE_USER_FEEDBACK: string
  readonly VITE_USER_FEEDBACK_RATING: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

