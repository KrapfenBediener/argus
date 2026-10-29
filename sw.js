/* © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung. */
/* CCP Service Worker — App-Shell-Strategie (Nachprüfung Sicherheit 26.10.2026, Punkt 11)
 *
 * Gecacht wird AUSSCHLIESSLICH die Positivliste PRECACHE_URLS (Feld-App-Shell + ihre Laufzeit-Assets: Schriften,
 * Icons, Manifest, config.js, Supabase-Client). Nichts anderes wird je abgefangen oder abgelegt — keine Desktopseiten,
 * keine Update-Sheets, keine Fremdressourcen, keine Query-Varianten (Cache-Schlüssel ist immer die URL ohne Query).
 *
 * Routing:
 *   1. *.supabase.co, version.json           → nicht abgefangen (Browser holt direkt; API nie cachen, Update-Erkennung)
 *   2. Navigation zur Feld-App (./, index.html) → Network-first mit Zeitlimit NAV_TIMEOUT_MS; danach bzw. bei Fehler
 *      die gecachte Shell (Offline-Start MUSS funktionieren). Die Netzantwort aktualisiert den Cache im Hintergrund.
 *   3. übrige Positivlisten-Assets           → Stale-while-revalidate (sofort aus dem Cache, im Hintergrund aktualisieren)
 *   4. alles andere                          → nicht abgefangen
 *
 * CACHE_NAME wird je Release vom Release-Skript erhöht (consistency.test.cjs). Keine Log-Ausgaben.
 */

const CACHE_NAME = 'ccp-shell-v105';

const PRECACHE_URLS = [
  './',
  './index.html',
  './vendor/supabase.js',
  './config.js',
  './manifest.json',
  './icon-180.png',
  './icon-192.png',
  './fonts/ibm-plex-sans-400.woff2',
  './fonts/ibm-plex-sans-500.woff2',
  './fonts/ibm-plex-sans-600.woff2',
  './fonts/ibm-plex-mono-500.woff2',
  './fonts/ibm-plex-mono-600.woff2'
];

/* Navigation: so lange wird auf das Netz gewartet, bevor die gecachte Shell geliefert wird (halbtotes Netz im Feld
 * darf den Start nicht blockieren; bei bekanntem Offline scheitert fetch sofort → Cache ohne Wartezeit). */
const NAV_TIMEOUT_MS = 3000;

const SCOPE = new URL('./', self.location.href);
const SHELL_KEYS = {};
PRECACHE_URLS.forEach(function(u){ var a = new URL(u, SCOPE); SHELL_KEYS[a.pathname] = a.origin + a.pathname; });
const INDEX_KEY = SHELL_KEYS[new URL('./index.html', SCOPE).pathname];
const ROOT_KEY = SHELL_KEYS[SCOPE.pathname];

/* Cache-Schlüssel (URL ohne Query/Fragment) für Positivlisten-Ressourcen desselben Origins, sonst null. */
function shellKey(url){
  if (url.origin !== SCOPE.origin) return null;
  return Object.prototype.hasOwnProperty.call(SHELL_KEYS, url.pathname) ? SHELL_KEYS[url.pathname] : null;
}
function isShellNavigation(request, key){
  return request.mode === 'navigate' && (key === ROOT_KEY || key === INDEX_KEY);
}
function cacheable(response){
  return !!response && response.status === 200 && response.type === 'basic';
}

/* Install — App-Shell atomar vorcachen; skipWaiting: neuer SW übernimmt sofort (PWA). */
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

/* Network-first für die Navigation: Netz (mit Zeitlimit), sonst Cache (Shell-Schlüssel, Rückfall index.html).
 * Die Netzanfrage läuft weiter und aktualisiert den Cache — event.waitUntil hält den SW dafür am Leben (iOS beendet ihn
 * sonst direkt nach der Antwort und der Cache würde nie aktualisiert). */
function networkFirst(event, key) {
  return caches.open(CACHE_NAME).then(function(cache) {
    var network = fetch(event.request).then(function(response) {
      if (cacheable(response)) cache.put(key, response.clone());
      return response;
    });
    event.waitUntil(network.catch(function(){}));
    var timer = new Promise(function(resolve) { setTimeout(function() { resolve(null); }, NAV_TIMEOUT_MS); });
    return Promise.race([network.catch(function() { return null; }), timer]).then(function(response) {
      if (response) return response;
      return cache.match(key).then(function(cached) {
        return cached || cache.match(INDEX_KEY);
      }).then(function(cached) {
        return cached || network;   /* nichts im Cache (Erststart ohne Vorcache) → auf das Netz warten */
      });
    });
  });
}

/* Stale-while-revalidate für die übrigen Shell-Assets: Cache sofort, Netz aktualisiert im Hintergrund. */
function staleWhileRevalidate(event, key) {
  return caches.open(CACHE_NAME).then(function(cache) {
    return cache.match(key).then(function(cached) {
      var network = fetch(event.request).then(function(response) {
        if (cacheable(response)) cache.put(key, response.clone());
        return response;
      });
      event.waitUntil(network.catch(function(){}));
      return cached || network;
    });
  });
}

self.addEventListener('fetch', function(event) {
  var url = new URL(event.request.url);

  /* 1. Supabase-API und version.json → nie abfangen, nie cachen */
  if (url.hostname.endsWith('.supabase.co')) return;
  if (url.origin === SCOPE.origin && url.pathname.endsWith('/version.json')) return;

  /* 4. nicht in der Positivliste (Desktopseiten, Update-Sheets, Fremdes) → nicht abfangen, nie cachen */
  var key = shellKey(url);
  if (!key) return;

  /* 2. Navigation zur Feld-App → Network-first, Cache als Offline-Rückfall */
  if (isShellNavigation(event.request, key)) {
    event.respondWith(networkFirst(event, key));
    return;
  }

  /* 3. Shell-Asset → Stale-while-revalidate */
  event.respondWith(staleWhileRevalidate(event, key));
});
