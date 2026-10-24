/// <reference types="vitest/config" />
// The browser app's build (vite build), development server (vite) and unit tests (vitest).
// In development the server's API, the reader's pages and its host script come from the Swift
// server at FRUS_API_ORIGIN, so the reader's page is same-origin with the app, as it is when the
// server serves both. The build names its files by relative paths under the page's <base>, into
// which the server writes the path it serves the app under, so one build serves at the root or
// under a path.
import react from '@vitejs/plugin-react';
import { defineConfig, type ProxyOptions } from 'vite';

const api = process.env.FRUS_API_ORIGIN ?? 'http://127.0.0.1:8080';
const webHost = process.env.FRUS_WEB_HOST ?? '127.0.0.1';
// The development server's own pages, by each name this machine goes by.
const ownOrigins = new Set([webHost, '127.0.0.1', 'localhost'].map((host) => `http://${host}:5173`));
// The server takes a change only from a page at its own address and sent to its host (PLAN's
// S14c), so the proxy presents the development server's requests as the server's own: its host,
// and, for a request from the development server's own page, its origin. A request from any other
// page keeps its origin, which the server refuses.
const proxy = Object.fromEntries(
  ['/api', '/reader', '/healthz', '/readyz'].map((path) => {
    const options: ProxyOptions = {
      target: api,
      changeOrigin: true,
      configure: (server) =>
        server.on('proxyReq', (request) => {
          const origin = request.getHeader('origin');
          if (typeof origin === 'string' && ownOrigins.has(origin)) request.setHeader('origin', new URL(api).origin);
        }),
    };
    return [path, options];
  }),
);

export default defineConfig({
  plugins: [react()],
  base: './',
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
    setupFiles: ['src/test/setup.ts'],
    restoreMocks: true,
  },
});
