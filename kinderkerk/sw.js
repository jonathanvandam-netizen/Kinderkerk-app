// Bewaart de app op het toestel, zodat hij ook zonder (goed) internet opent.
// Eerst het netwerk proberen, anders de bewaarde versie.
const CACHE = 'kinderkerk-v1';
const FILES = ['./', 'index.html', 'manifest.webmanifest', 'logo-192.png', 'logo-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)));
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(fetch(e.request).then(res => {
    if (res.ok){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
    return res;
  }).catch(() => caches.match(e.request, { ignoreSearch:true }).then(r => r || caches.match('index.html'))));
});
