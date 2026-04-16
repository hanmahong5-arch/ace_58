// vite.config.ts — Vite configuration for the Shiguang Launcher React frontend.
// Integrates with Tauri 2 dev server and build pipeline.

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vitejs.dev/config/
export default defineConfig(async () => ({
  plugins: [react()],

  // Vite options tailored for Tauri dev/build
  clearScreen: false,

  server: {
    // Tauri expects a fixed port; fail rather than trying another port
    port: 5173,
    strictPort: true,
    // Hot module reload for the Tauri app window
    watch: {
      // Let Tauri's watch handle Rust changes
      ignored: ["**/src-tauri/**"],
    },
  },

  // Env variables exposed to the frontend must be prefixed with VITE_
  envPrefix: ["VITE_", "TAURI_ENV_*"],

  build: {
    // Output to dist/ where tauri.conf.json points frontendDist
    outDir: "dist",
    // Tauri uses Chromium internally; no need for legacy ES5 transforms
    target: process.env.TAURI_ENV_PLATFORM === "windows" ? "chrome105" : "chrome105",
    // Inline small assets
    assetsInlineLimit: 4096,
    // Do not minify source maps in debug builds
    minify: !process.env.TAURI_ENV_DEBUG ? "esbuild" : false,
    sourcemap: !!process.env.TAURI_ENV_DEBUG,
  },
}));
