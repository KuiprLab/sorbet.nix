import { sveltekit } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    proxy: {
      "/api": "http://127.0.0.1:9765",
    },
  },
});
