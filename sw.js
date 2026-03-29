const CACHE_NAME = 'eldritch-retro-v2';

// Recursos locales + CDN externos que la app necesita para funcionar
const urlsToCache = [
  './index.html',
  './logo.png',
  './manifest.json',
  './icon-192x192.png',
  './icon-512x512.png',
  // Librerías CDN críticas
  'https://unpkg.com/react@18/umd/react.production.min.js',
  'https://unpkg.com/react-dom@18/umd/react-dom.production.min.js',
  'https://unpkg.com/@babel/standalone/babel.min.js',
  'https://cdn.tailwindcss.com',
];

// Install - precachear todos los recursos (locales + CDN)
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Cacheando recursos...');
      return Promise.all(
        urlsToCache.map((url) => {
          // Para CDN usamos mode: 'cors' / no-cors según el servidor
          const request = url.startsWith('http')
            ? new Request(url, { mode: 'cors' })
            : url;
          return cache.add(request).catch((err) => {
            // Si cors falla, intentar con no-cors (respuesta opaque)
            if (url.startsWith('http')) {
              return fetch(new Request(url, { mode: 'no-cors' }))
                .then((response) => cache.put(url, response))
                .catch((e) => console.warn(`[SW] No se pudo cachear ${url}:`, e));
            }
            console.warn(`[SW] No se pudo cachear ${url}:`, err);
          });
        })
      );
    })
  );
  self.skipWaiting();
});

// Activate - limpiar caches viejos
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Eliminando cache viejo:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// Fetch - Estrategia: Network First con fallback a Cache
self.addEventListener('fetch', (event) => {
  const { request } = event;

  // Para solicitudes de API (GitHub Gist), siempre ir a red
  if (request.url.includes('api.github.com')) {
    event.respondWith(fetch(request));
    return;
  }

  // Para todo lo demás: intentar red primero, si falla usar cache
  event.respondWith(
    fetch(request)
      .then((response) => {
        // Guardar copia en cache (tanto basic como opaque)
        if (response && (response.status === 200 || response.type === 'opaque')) {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Sin red: buscar en cache
        return caches.match(request).then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          // Si es navegación (HTML), devolver index.html cacheado
          if (request.mode === 'navigate') {
            return caches.match('./index.html');
          }
          // Si no hay nada en cache, devolver error genérico
          return new Response('Offline - recurso no disponible', {
            status: 503,
            statusText: 'Service Unavailable',
          });
        });
      })
  );
});
