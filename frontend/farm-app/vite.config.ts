import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

const uiRoot = fileURLToPath(new URL("../packages/ui/src", import.meta.url));
const apiRoot = fileURLToPath(new URL("../packages/api/src", import.meta.url));

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icon.svg", "icon-192.png", "icon-512.png"],
      manifest: {
        name: "LivestokOS Farm",
        short_name: "Farm",
        description: "Field operations for livestock farms — offline-capable PWA",
        theme_color: "#0B5E2E",
        background_color: "#FFFFFF",
        display: "standalone",
        scope: "/",
        start_url: "/",
        icons: [
          {
            src: "icon-192.png",
            sizes: "192x192",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "icon-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any",
          },
          {
            src: "icon-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,ico,png,svg,woff2}"],
        navigateFallback: "index.html",
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/localhost:4000\/api\/health/,
            handler: "NetworkFirst",
            options: {
              cacheName: "api-health",
              networkTimeoutSeconds: 5,
            },
          },
        ],
      },
    }),
  ],
  server: {
    port: 5173,
    strictPort: true,
  },
  preview: {
    port: 4173,
    strictPort: true,
  },
  resolve: {
    alias: {
      "@livestok/ui": uiRoot,
      "@livestok/api": apiRoot,
    },
  },
});
