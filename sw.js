/* © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung. */
/* CCP Service Worker — App-Shell-Strategie
 *
 * Routing-Prioritäten (Reihenfolge ist entscheidend):
 *   1. *.supabase.co          → Network-only  (API-Calls nie cachen)
 *   2. Shell-Assets (/)       → Cache-first   (offline verfügbar)
 *   3. Alles andere           → Network-first (aktuelle Daten bevorzugen)
 */

const CACHE_NAME = 'ccp-shell-v58';

const PRECACHE_URLS = [
  './',
  './index.html',
  './vendor/supabase.js',
  './config.js',
  './fonts/ibm-plex-sans-400.woff2',
  './fonts/ibm-plex-sans-500.woff2',
  './fonts/ibm-plex-sans-600.woff2',
  './fonts/ibm-plex-mono-500.woff2',
  './fonts/ibm-plex-mono-600.woff2'
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
 * REGEL 2: Shell-Assets (Origin + /) → Stale-while-revalidate
 *   index.html wird sofort aus dem Cache geliefert (schnell, offline-fähig),
 *   gleichzeitig im Hintergrund vom Netz aktualisiert. Dadurch ist eine neu
 *   deployte Version beim NÄCHSTEN Start automatisch aktiv — ohne dass die
 *   App vom Home-Bildschirm gelöscht oder der Cache geleert werden muss.
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

  /* version.json NIE cachen → zuverlässige Update-Erkennung (Network-only) */
  if (url.origin === self.location.origin && url.pathname.endsWith('/version.json')) {
    return;
  }

  /* REGEL 2: Shell-Assets (gleicher Origin) → Stale-while-revalidate */
  if (url.origin === self.location.origin) {
    event.respondWith(
      caches.open(CACHE_NAME).then(function(cache) {
        return cache.match(event.request).then(function(cached) {
          /* Im Hintergrund immer vom Netz nachladen und Cache aktualisieren */
          var network = fetch(event.request).then(function(response) {
            if (response && response.status === 200 && response.type === 'basic') {
              cache.put(event.request, response.clone());
            }
            return response;
          }).catch(function() {
            /* Offline → für index.html auf den Cache zurückfallen */
            if (url.pathname.endsWith('/') || url.pathname.endsWith('/index.html')) {
              return caches.match('./index.html');
            }
          });
          /* WICHTIG: Revalidierung am Leben halten, bis sie fertig ist — sonst
           * beendet iOS den SW direkt nach Auslieferung der gecachten Seite und
           * der Cache wird NIE aktualisiert (App bliebe auf alter Version). */
          event.waitUntil(network.catch(function(){}));
          /* Cache sofort liefern (schnell/offline), sonst auf Netz warten */
          return cached || network;
        });
      })
    );
    return;
  }

  /* REGEL 3: Alles andere (externe Ressourcen) → Network-first
   * Hinweis: Schriften und Supabase-JS sind seit T8 self-hosted und laufen
   * über REGEL 2 (gleicher Origin) — kein Sonderfall für Google Fonts mehr. */
  event.respondWith(
    fetch(event.request).then(function(response) {
      return response;
    }).catch(function() {
      /* Netz nicht verfügbar → Cache-Fallback */
      return caches.match(event.request);
    })
  );
});
