import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    proxy: {
      '/api': { target: 'http://127.0.0.1:8765', xfwd: true },
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (/node_modules\/(?:@codemirror|@lezer|codemirror)\//.test(id)) return 'editor'
          if (/web\/src\/functions\.js$/.test(id)) return 'function-index'
        },
      },
    },
  },
})
