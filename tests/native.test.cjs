/* Native-Hülle-Gates (Phase 6.6): reine Dateiprüfungen für das Capacitor-Unterprojekt `native/`.
 * Läuft ohne Xcode, ohne `cap`-Aufruf, ohne native/node_modules — auch in CI (Ubuntu).
 *
 * Traceability:
 *   D6.6-01  eigene Bundle-ID (Eigentumslinie), nie das Template-Default com.getcapacitor.App
 *   D6.6-03  Web-App bleibt unverändert ausgeliefert: webDir www, kein server.url (Local-first)
 *   D6.6-07  Versionskopplung: MARKETING_VERSION == APP_VERSION, CURRENT_PROJECT_VERSION == build
 *   D-06     keine Leitungs-/Lage-Seiten im Bundle (nur als Muster geprüft, nie konkret)
 *   Pitfall 3 (public/ + capacitor.config.json im iOS-Ordner sind cap-sync-Artefakte → gitignored)
 *   Pitfall 6 (Update-Sheets + deren Fonts müssen im Bundle liegen)
 *   Pitfall 10 / T-06.6-SC (genau vier exakt gepinnte Pakete, kein stilles Nachinstallieren)
 *
 * Abschnitt „Plan 06.6-01“: Config, Pins, Kopierskript (Allowlist + Idempotenz), Versionen, gitignore.
 * Spätere Pläne der Phase ergänzen eigene Abschnitte in dieser Datei. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { ROOT, app, readFileText, extractVarLiteral } = require('./_extract.cjs');

const script = app().script;
const APP_VERSION = (script.match(/var APP_VERSION = '([^']+)'/) || [])[1];
const NATIVE = path.join(ROOT, 'native');
const SYNC_SCRIPT = path.join(NATIVE, 'scripts', 'sync-web.mjs');
const PBXPROJ = path.join(NATIVE, 'ios', 'App', 'App.xcodeproj', 'project.pbxproj');
const PACKAGE_SWIFT = path.join(NATIVE, 'ios', 'App', 'CapApp-SPM', 'Package.swift');
const FORBIDDEN = /(leitung|lage)-[0-9a-f]+\.html$/;

function readJson(rel){ return JSON.parse(readFileText(rel)); }
function lines(rel){ return readFileText(rel).split(/\r?\n/).map(l => l.trim()); }

/* rekursive, sortierte Liste relativer Pfade (POSIX-Trenner) */
function walk(dir, base){
  base = base || dir;
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })){
    const full = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(walk(full, base));
    else out.push(path.relative(base, full).split(path.sep).join('/'));
  }
  return out.sort();
}
function sha256(file){
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}
function precacheUrls(){
  const m = readFileText('sw.js').match(/const PRECACHE_URLS = \[([\s\S]*?)\];/);
  assert.ok(m, 'PRECACHE_URLS in sw.js nicht gefunden');
  return [...m[1].matchAll(/'([^']+)'/g)].map(x => x[1]).filter(u => u !== './')
    .map(u => u.replace(/^\.\//, '').split('?')[0]);
}
function updateSheets(){
  return Object.values(new Function('return (' + extractVarLiteral(script, 'UPDATE_SHEETS') + ');')());
}

/* ── Plan 06.6-01: Config & Pins ─────────────────────────────────────────── */

test('native: capacitor.config.json — webDir www, eigene Bundle-ID, kein server.url (D6.6-03)', () => {
  const c = readJson('native/capacitor.config.json');
  assert.match(c.appId || '', /^[a-z][a-z0-9]*(\.[a-z][a-z0-9-]*)+$/, 'appId ist keine gültige Reverse-DNS-ID');
  assert.notEqual(c.appId, 'com.getcapacitor.App', 'Template-Bundle-ID darf nie signiert werden (D6.6-01)');
  assert.equal(c.webDir, 'www');
  assert.ok(!('server' in c), 'server-Block verletzt Local-first (D6.6-03) — kein server.url auf die Pages-Domain');
  assert.equal(c.appName, 'ARGUS');
});

test('native: package.json — genau vier exakt gepinnte Capacitor-Pakete', () => {
  const p = readJson('native/package.json');
  const deps = p.dependencies || {};
  assert.deepEqual(Object.keys(deps).sort(),
    ['@capacitor/app', '@capacitor/cli', '@capacitor/core', '@capacitor/ios'],
    'dependencies müssen genau core/cli/ios/app sein — nichts stilles nachinstallieren (T-06.6-SC)');
  for (const [k, v] of Object.entries(deps)){
    assert.match(v, /^\d+\.\d+\.\d+$/, k + ' ist nicht exakt gepinnt (kein ^/~): ' + v);
  }
  assert.equal(deps['@capacitor/core'], deps['@capacitor/cli'], 'core und cli müssen dieselbe Version haben');
  assert.equal(deps['@capacitor/core'], deps['@capacitor/ios'], 'core und ios müssen dieselbe Version haben');
  assert.equal(Object.keys(p.devDependencies || {}).length, 0, 'keine devDependencies im nativen Unterprojekt');
  assert.equal(p.private, true);
  assert.ok(fs.existsSync(path.join(NATIVE, 'package-lock.json')), 'package-lock.json muss committet sein');
});

/* ── Plan 06.6-01: Kopierskript ──────────────────────────────────────────── */

test('native: sync-web.mjs — Allowlist vollständig, Fremddateien fehlen, idempotent', () => {
  const tmp1 = fs.mkdtempSync(path.join(os.tmpdir(), 'argus-native-'));
  const tmp2 = fs.mkdtempSync(path.join(os.tmpdir(), 'argus-native-'));
  try {
    execFileSync(process.execPath, [SYNC_SCRIPT, '--out', tmp1, '--quiet'], { stdio: 'pipe' });
    execFileSync(process.execPath, [SYNC_SCRIPT, '--out', tmp2, '--quiet'], { stdio: 'pipe' });
    const list1 = walk(tmp1), list2 = walk(tmp2);
    const set = new Set(list1);

    /* Pflichtinhalt */
    const must = ['index.html', 'config.js', 'vendor/supabase.js',
      'docs/fonts/ibm-plex-sans-400.woff2',
      'icon-180.png', 'icon-192.png', 'manifest.json', 'version.json', 'native-version.json']
      .concat(precacheUrls()).concat(updateSheets());
    for (const f of must) assert.ok(set.has(f), 'fehlt im Bundle: ' + f + ' (Pitfall 6)');

    /* Fremdinhalt — kein Service Worker, keine Altlasten, keine Leitungs-/Lage-Seiten (D-06) */
    assert.ok(!set.has('sw.js'), 'sw.js gehört nicht ins Bundle (kein Service Worker im WKWebView)');
    for (const f of list1){
      assert.ok(!/^(legacy|\.planning|assets)\//.test(f), 'Fremddatei im Bundle: ' + f);
      assert.ok(!FORBIDDEN.test(f), 'Leitungs-/Lage-Seite im Bundle (D-06-Muster getroffen)');
      assert.ok(!f.split('/').includes('..'), 'Pfad verlässt das Bundle');
    }

    /* Idempotenz: identische Dateiliste und identische Bytes */
    assert.deepEqual(list1, list2, 'zwei Läufe liefern verschiedene Dateilisten');
    for (const f of list1){
      assert.equal(sha256(path.join(tmp1, f)), sha256(path.join(tmp2, f)), 'Inhalt weicht zwischen zwei Läufen ab: ' + f);
    }

    /* native-version.json spiegelt APP_VERSION und Build (ohne Zeitstempel) */
    const nv = JSON.parse(fs.readFileSync(path.join(tmp1, 'native-version.json'), 'utf8'));
    assert.equal(nv.version, APP_VERSION, 'native-version.json.version != APP_VERSION');
    assert.equal(nv.build, readJson('native/version.json').build);
    assert.deepEqual(Object.keys(nv).sort(), ['build', 'version'], 'native-version.json darf nur version/build enthalten (Idempotenz)');
  } finally {
    fs.rmSync(tmp1, { recursive: true, force: true });
    fs.rmSync(tmp2, { recursive: true, force: true });
  }
});

/* ── Plan 06.6-01: Versionen ─────────────────────────────────────────────── */

test('native: version.json — build ist Ganzzahl ≥ 1', () => {
  const v = readJson('native/version.json');
  assert.ok(Number.isInteger(v.build) && v.build >= 1, 'build muss eine Ganzzahl >= 1 sein (monotoner Zähler, D6.6-07)');
});

test('native: project.pbxproj — MARKETING_VERSION == APP_VERSION, CURRENT_PROJECT_VERSION == build (D6.6-07)', () => {
  assert.match(APP_VERSION || '', /^\d+\.\d+\.\d+$/);
  const build = readJson('native/version.json').build;
  const pbx = fs.readFileSync(PBXPROJ, 'utf8');
  const mv = [...pbx.matchAll(/MARKETING_VERSION = ([^;]+);/g)].map(m => m[1]);
  const cpv = [...pbx.matchAll(/CURRENT_PROJECT_VERSION = ([^;]+);/g)].map(m => m[1]);
  assert.ok(mv.length >= 2, 'MARKETING_VERSION fehlt für Debug/Release');
  assert.ok(cpv.length >= 2, 'CURRENT_PROJECT_VERSION fehlt für Debug/Release');
  for (const x of mv) assert.equal(x, APP_VERSION, 'MARKETING_VERSION hinkt APP_VERSION hinterher — `node native/scripts/set-version.mjs` ausführen');
  for (const x of cpv) assert.equal(x, String(build), 'CURRENT_PROJECT_VERSION != native/version.json.build');
  const bid = (pbx.match(/PRODUCT_BUNDLE_IDENTIFIER = de\.gaborszeman\.argus;/g) || []).length;
  assert.ok(bid >= 2, 'Bundle-ID de.gaborszeman.argus muss für Debug und Release gesetzt sein (D6.6-01)');
  assert.equal(readJson('native/capacitor.config.json').appId, 'de.gaborszeman.argus', 'appId in capacitor.config.json und pbxproj laufen auseinander');
  assert.ok(!/DEVELOPMENT_TEAM = /.test(pbx), 'DEVELOPMENT_TEAM darf nicht committet werden (öffentliches Repo) — `set-version.mjs --strip-team`');
});

/* ── Plan 06.6-01: Hygiene ───────────────────────────────────────────────── */

test('native: gitignore-Hygiene — www/, .cache/, ios public/ bleiben ungetrackt (Pitfall 3)', () => {
  const gi = lines('native/.gitignore');
  for (const l of ['node_modules/', 'www/', '.cache/']) assert.ok(gi.includes(l), 'native/.gitignore fehlt Zeile ' + l);
  const ios = lines('native/ios/.gitignore');
  assert.ok(ios.includes('App/App/public'), 'native/ios/.gitignore muss App/App/public ausschließen (cap-sync-Artefakt)');
  assert.ok(ios.includes('App/App/capacitor.config.json'), 'native/ios/.gitignore muss App/App/capacitor.config.json ausschließen');
});

test('native: Package.swift nicht von Hand geändert — CLI-Marker und @capacitor/app-Plugin', () => {
  const sw = fs.readFileSync(PACKAGE_SWIFT, 'utf8');
  assert.ok(sw.includes('DO NOT MODIFY'), 'Package.swift ohne CLI-Marker — wurde die Datei von Hand ersetzt?');
  assert.ok(sw.includes('capacitor-swift-pm'), 'Capacitor-Runtime fehlt in Package.swift');
  assert.ok(sw.includes('CapacitorApp') && sw.includes('@capacitor/app'),
    '@capacitor/app fehlt in Package.swift — `cap sync ios` nicht gelaufen?');
  assert.ok(!fs.existsSync(path.join(NATIVE, 'ios', 'App', 'App', 'public', 'sw.js')),
    'sw.js darf nicht in ios/App/App/public liegen (Kopierskript umgangen?)');
});
