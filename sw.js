/* CCP Service Worker — App-Shell-Strategie
 *
 * Routing-Prioritäten (Reihenfolge ist entscheidend):
 *   1. *.supabase.co          → Network-only  (API-Calls nie cachen)
 *   2. Shell-Assets (/)       → Cache-first   (offline verfügbar)
 *   3. Alles andere           → Network-first (aktuelle Daten bevorzugen)
 */

const CACHE_NAME = 'ccp-shell-v1';

const PRECACHE_URLS = [
  './',
  './index.html',
  'https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@500;600&display=swap'
];

/* Install — App-Shell atomar vorcachen
 * skipWaiting() sorgt dafür, dass ein neuer SW sofort übernimmt
 * (kein Warten auf Tabs-Schliessen). Sinnvoll für eine PWA.
 */
self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.addAll(PRECACHE_URLS);
    }).then(function() {
      return self.skipWaiting();
    })
  );
});

/* Activate — alte Cache-Versionen aufräumen */
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames
          .filter(function(name) { return name !== CACHE_NAME; })
          .map(function(name) { return caches.delete(name); })
      );
    }).then(function() {
      return self.clients.claim();
    })
  );
});

/* Fetch — Routing-Logik
 *
 * REGEL 1: Supabase-API-Anfragen → IMMER Network-only
 *   *.supabase.co deckt Datenbank, Auth, Storage, Realtime ab.
 *   Keine Ausnahme — gecachte API-Antworten würden veraltete
 *   Patientendaten zurückliefern (sicherheitskritisch).
 *
 * REGEL 2: Shell-Assets (Origin + /) → Cache-first
 *   index.html und die App-Hülle kommen aus dem Cache.
 *   Bei Netzwerkfehler wird die gecachte Version geliefert.
 *   Ermöglicht Start vom Home-Bildschirm ohne Netz.
 *
 * REGEL 3: Alles andere → Network-first
 *   CDN-Ressourcen, externe Skripte etc. — Netz bevorzugen,
 *   Fallback auf Cache falls offline.
 */
self.addEventListener('fetch', function(event) {
  var url = new URL(event.request.url);

  /* REGEL 1: Supabase → Network-only */
  if (url.hostname.endsWith('.supabase.co')) {
    /* Keine event.respondWith — Browser holt direkt vom Netz */
    return;
  }

  /* REGEL 2: Shell-Assets (gleicher Origin) → Cache-first */
  if (url.origin === self.location.origin) {
    event.respondWith(
      caches.match(event.request).then(function(cached) {
        if (cached) {
          return cached;
        }
        return fetch(event.request).then(function(response) {
          /* Nur gültige Antworten cachen */
          if (response && response.status === 200 && response.type === 'basic') {
            var toCache = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              cache.put(event.request, toCache);
            });
          }
          return response;
        }).catch(function() {
          /* Offline und nicht im Cache → für index.html Fallback */
          if (url.pathname.endsWith('/') || url.pathname.endsWith('/index.html')) {
            return caches.match('./index.html');
          }
        });
      })
    );
    return;
  }

  /* REGEL 3: Alles andere (CDN, externe Ressourcen) → Network-first */
  event.respondWith(
    fetch(event.request).then(function(response) {
      /* Google Fonts im Cache ablegen */
      if (
        response && response.status === 200 &&
        (url.hostname === 'fonts.googleapis.com' ||
         url.hostname === 'fonts.gstatic.com')
      ) {
        var toCache = response.clone();
        caches.open(CACHE_NAME).then(function(cache) {
          cache.put(event.request, toCache);
        });
      }
      return response;
    }).catch(function() {
      /* Netz nicht verfügbar → Cache-Fallback */
      return caches.match(event.request);
    })
  );
});
