/// <reference types="vitest/config" />
// The browser app's build (vite build), development server (vite) and unit tests (vitest).
// In development the server's API, the reader's pages and its host script come from the Swift
// server at FRUS_API_ORIGIN, so the reader's page is same-origin with the app, as it is when the
// server serves both.
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

const api = process.env.FRUS_API_ORIGIN ?? 'http://127.0.0.1:8080';
const proxy = Object.fromEntries(['/api', '/reader', '/healthz', '/readyz'].map((path) => [path, { target: api }]));

export default defineConfig({
  plugins: [react()],
  build: {
    // No inline data URIs: the app's policy allows them for images only, and nothing needs them.
    assetsInlineLimit: 0,
  },
  server: {
    host: process.env.FRUS_WEB_HOST ?? '127.0.0.1',
    port: 5173,
    strictPort: true,
    proxy,
  },
  // vite preview serves the build on the same address, so scripts/npm publishes one port for both.
  preview: {
    host: process.env.FRUS_WEB_HOST ?? '127.0.0.1',
    port: 5173,
    strictPort: true,
    proxy,
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    restoreMocks: true,
  },
});
