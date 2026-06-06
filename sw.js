const CACHE_NAME = 'containers-v1';
const ASSETS = [
  '/',
  '/index.html',
  '/css/style.css',
  '/js/app.js',
  '/js/firebase-config.js',
  '/js/auth.js',
  '/js/store.js',
  '/js/router.js',
  '/js/utils.js',
  '/js/pages/login.js',
  '/js/pages/dashboard.js',
  '/js/pages/entrada.js',
  '/js/pages/deadline.js',
  '/js/pages/historico.js',
  '/js/pages/mapa.js',
  '/js/pages/ia.js',
  '/js/pages/usuarios.js',
  '/js/components/containerCard.js'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE_NAME).then(c => c.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.url.includes('firebaseio.com') ||
      e.request.url.includes('googleapis.com') ||
      e.request.url.includes('firebase')) {
    return;
  }
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request))
  );
});
