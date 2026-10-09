import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// خادم التطوير يعمل على 5173 ويوجه /api إلى الخادم المحلي 8000
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        ws: true,
      },
    },
  },
});
