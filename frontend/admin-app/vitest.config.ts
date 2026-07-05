import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath } from "node:url";

const uiRoot = fileURLToPath(new URL("../packages/ui/src", import.meta.url));
const apiRoot = fileURLToPath(new URL("../packages/api/src", import.meta.url));

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@livestok/ui": uiRoot,
      "@livestok/api": apiRoot,
    },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    include: ["src/**/*.test.{ts,tsx}"],
  },
});
