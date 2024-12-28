// @ts-check
import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";

import react from "@astrojs/react";

import tailwind from "@astrojs/tailwind";

// https://astro.build/config
export default defineConfig({
  site: "https://synapsomorphy.com",
  //   base: "/website",
  integrations: [mdx(), sitemap(), react(), tailwind()],
  vite: {
    assetsInclude: ["**/*.json"],
  },
});
