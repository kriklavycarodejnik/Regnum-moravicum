import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ command }) => ({
  // GitHub Pages serves this project from /Regnum-moravicum/, not the domain root.
  base: command === 'build' ? '/Regnum-moravicum/' : '/',
  plugins: [react()],
}))
