// Bewaart de app op het toestel, zodat hij ook zonder (goed) internet opent.
// Eerst het netwerk proberen, anders de bewaarde versie.
const CACHE = 'kinderkerk-v4';
const FILES = ['./', 'index.html', 'config.js', 'vendor/supabase.js', 'manifest.webmanifest', 'logo-192.png', 'logo-512.png', 'apple-touch-icon.png', 'icon-maskable-192.png', 'icon-maskable-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES.map(f => new Request(f, { cache:'reload' })))));
  self.skipWaiting();
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  // Gegevens uit de database nooit bewaren, alleen de app zelf en de lettertypes
  const url = new URL(e.request.url);
  if (url.origin !== location.origin && !url.host.startsWith('fonts.')) return;
  // Eigen bestanden altijd vers ophalen (niet uit het browsergeheugen), anders zie je soms een oude versie
  const req = url.origin === location.origin ? new Request(url.href, { cache:'no-cache' }) : e.request;
  e.respondWith(fetch(req).then(res => {
    if (res.ok){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); }
    return res;
  }).catch(() => caches.match(e.request, { ignoreSearch:true }).then(r => r || caches.match('index.html'))));
});

// Meldingen (alleen als iemand ze in Mijn account heeft aangezet)
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch(err){ d = { body:e.data ? e.data.text() : '' }; }
  e.waitUntil(self.registration.showNotification(d.title || 'Kinderkerk', { body:d.body || '', icon:'logo-192.png', badge:'logo-192.png', data:{ url:d.url || './' } }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = e.notification.data && e.notification.data.url || './';
  e.waitUntil(clients.matchAll({ type:'window', includeUncontrolled:true }).then(list => {
    const w = list.find(c => 'focus' in c);
    if (w){ if ('navigate' in w) w.navigate(url).catch(() => {}); return w.focus(); }
    return clients.openWindow(url);
  }));
});
