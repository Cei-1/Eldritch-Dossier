const CACHE_NAME = 'eldritch-shell-v25';
const RUNTIME_CACHE = 'eldritch-runtime-v25';

const APP_SHELL = [
  './',
  './index.html',
  './supabaseClient.js',
  './manifest.json',
  './logo.png',
  './icon-192x192.png',
  './icon-512x512.png',
  './assets/icons/icon-maskable-192x192.png',
  './assets/icons/icon-maskable-512x512.png',
  './assets/screenshots/explorador-desktop.png',
  './assets/screenshots/explorador-mobile.png',
  './assets/audio/VHS.mp3',
  './assets/audio/Glitch.mp3',
  './assets/audio/Tormenta.mp3',
  './assets/audio/Interferencia.mp3'
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(
        names
          .filter((name) => name !== CACHE_NAME && name !== RUNTIME_CACHE)
          .map((name) => caches.delete(name))
      ))
      .then(() => self.clients.claim())
  );
});

function isSupabaseRequest(url) {
  return url.hostname.endsWith('.supabase.co');
}

async function networkFirst(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(RUNTIME_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch (_error) {
    return (await caches.match(request)) ||
      (request.mode === 'navigate' ? caches.match('./index.html') : undefined) ||
      new Response('Offline - recurso no disponible', {
        status: 503,
        headers: { 'Content-Type': 'text/plain; charset=utf-8' }
      });
  }
}

async function staleWhileRevalidate(request) {
  const cached = await caches.match(request);
  const update = fetch(request).then(async (response) => {
    if (response.ok || response.type === 'opaque') {
      const cache = await caches.open(RUNTIME_CACHE);
      await cache.put(request, response.clone());
    }
    return response;
  }).catch(() => cached);
  return cached || update;
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (isSupabaseRequest(url)) {
    event.respondWith(fetch(request));
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request));
    return;
  }

  event.respondWith(staleWhileRevalidate(request));
});
