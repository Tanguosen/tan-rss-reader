import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import electron from 'vite-plugin-electron'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  plugins: [
    vue({
      template: {
        compilerOptions: {
          isCustomElement: (tag) => tag === 'webview'
        }
      }
    }),
    ...(mode === 'electron'
      ? [
          electron([
            {
              entry: 'electron/main.ts',
            },
            {
              entry: 'electron/preload.ts',
              onstart(options) {
                options.reload()
              },
              vite: {
                build: {
                  outDir: 'dist-electron',
                  rollupOptions: {
                    external: ['electron'],
                    output: {
                      format: 'cjs',
                      entryFileNames: '[name].cjs'
                    }
                  }
                }
              }
            },
          ])
        ]
      : []),
  ],
  server: {
    port: 5174,
    host: true,
    proxy: {
      '/api': {
        target: 'http://localhost:27496',
        changeOrigin: true,
        secure: false,
      }
    }
  },
}))
