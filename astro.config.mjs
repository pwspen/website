import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import tailwind from '@astrojs/tailwind';

import react from "@astrojs/react";

import { remarkReadingTime } from './src/utils/remarkReadingTime.mjs';

import removeTagWhitespace from 'astro-remove-whitespace';

// https://astro.build/config
export default defineConfig({
  site: 'https://synapsomorphy.com',
  integrations: [mdx(), sitemap(), tailwind(), react(), removeTagWhitespace()],
  vite: {
    resolve: {
      alias: {
        '@src/': 'src/',
        '@components': 'src/components',
        '@layouts': 'src/layouts',
        '@utils': 'src/utils',
        '@consts': 'src/consts',
        '@imgs': 'src/content/imgs'
      }
    }
  },
  markdown: {
    shikiConfig: {
      // Choose from Shiki's built-in themes (or add your own)
      // https://shiki.style/themes
      // Alternatively, provide multiple themes
      // See note below for using dual light/dark themes
      themes: {
        light: 'poimandres',
        dark: 'catppuccin-latte'
      }
    },
    remarkPlugins: [remarkReadingTime]
  },
  redirects: {
    '/portfolio/': '/'
  }
});