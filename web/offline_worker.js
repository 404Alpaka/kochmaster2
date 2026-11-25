'use strict';

const VERSION = 'MISE_BUILD_VERSION';
const ASSETS = []; // MISE_BUILD_ASSETS
const CACHE = `mise-shell-${VERSION}`;
const base = new URL('./', self.location.href);
const allowed = new Set(ASSETS.map(path => new URL(path, base).href));

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    if (!ASSETS.length) return;
    const cache = await caches.open(CACHE);
    try {
      await cache.addAll(ASSETS.map(path => new Request(new URL(path, base), {cache: 'reload'})));
    } catch (error) {
      await caches.delete(CACHE);
      throw error;
    }
    // Updates wait for existing tabs to close; never mix two running builds.
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    if (!ASSETS.length) return;
    for (const key of await caches.keys()) {
      if (key.startsWith('mise-shell-') && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  if (!ASSETS.length || event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== base.origin || event.request.headers.has('Authorization')) return;
  url.search = '';
  url.hash = '';
  const navigation = event.request.mode === 'navigate' && url.pathname.startsWith(base.pathname);
  const resource = navigation ? new URL('index.html', base).href : url.href;
  // Only build artifacts are cached. Supabase/Auth/API responses never enter it.
  if (!allowed.has(resource)) return;
  event.respondWith((async () => {
    const cached = await (await caches.open(CACHE)).match(resource);
    return cached || fetch(event.request);
  })());
});
