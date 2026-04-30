import adapter from "@sveltejs/adapter-static";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      fallback: "index.html",
      pages: "build",
      assets: "build",
      strict: false,
    }),
    prerender: { entries: [] },
  },
};

export default config;
