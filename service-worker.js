// Candy Crunch service worker
// VERSION is auto-bumped by deploy.ps1 — do not edit by hand
const VERSION = '2026-05-20-024608';
const CACHE_NAME = `candy-crunch-${VERSION}`;

const STATIC_ASSETS = [
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-192.png',
  './icon-maskable-512.png',
  './favicon-32.png'
];

// Install: pre-cache static assets and take over immediately
self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.allSettled(STATIC_ASSETS.map((u) => cache.add(u)));
    await self.skipWaiting();
  })());
});

// Activate: purge old caches and claim open clients so the new SW controls them
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== location.origin) return;

  // Network-first for HTML so gameplay updates land as soon as users are online.
  const accept = req.headers.get('accept') || '';
  const isHTML = req.mode === 'navigate'
              || accept.includes('text/html')
              || url.pathname.endsWith('/')
              || url.pathname.endsWith('.html');

  if (isHTML) {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(req);
        const cache = await caches.open(CACHE_NAME);
        cache.put(req, fresh.clone());
        return fresh;
      } catch {
        const cached = await caches.match(req);
        return cached || caches.match('./index.html');
      }
    })());
    return;
  }

  // Stale-while-revalidate for static assets — instant load, fresh on next visit.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(req);
    const fetchPromise = fetch(req).then((response) => {
      if (response && response.status === 200 && response.type === 'basic') {
        cache.put(req, response.clone());
      }
      return response;
    }).catch(() => cached);
    return cached || fetchPromise;
  })());
});
