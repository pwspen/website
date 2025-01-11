// src/middleware.ts
import { defineMiddleware } from 'astro:middleware';

export const onRequest = defineMiddleware((context, next) => {
  if (context.url.pathname === '/portfolio/') {
    return context.redirect('/');
  }
  return next();
});