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
 * Abschnitt „Plan 06.6-03“: Zugangs-Fassade (Keychain) — ACCESS_KEYS, Wahrheitstafel, Gate „kein Direktzugriff“.
 * Spätere Pläne der Phase ergänzen eigene Abschnitte in dieser Datei. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { ROOT, app, readFileText, extractVarLiteral, extractFunction, evalFunction, evalFunctions, evalInScope, hasFunction } = require('./_extract.cjs');

const script = app().script;
const html = app().html;
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

/* ── Plan 06.6-02 — App-Brücke I ─────────────────────────────────────────────
 * Hüllen-Erkennung (reine Funktion), PWA-Mechaniken gegatet (Install-Screen,
 * Service Worker, Update-Banner, Hilfe, Fußzeile), Safe-Area nur unter
 * html.native-shell, Export-Hinweis statt wirkungslosem Download.
 * Leitgedanke (T-06.6-14): außerhalb der Hülle bleibt alles byte-identisch. */

function stripComments(src){
  return src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
}
function fnBody(name){
  const src = extractFunction(script, name);
  return stripComments(src.slice(src.indexOf('{') + 1)).trim();
}
function firstStyleBlock(){
  const m = html.match(/<style>([\s\S]*?)<\/style>/);
  assert.ok(m, 'kein <style>-Block in index.html');
  return m[1];
}

test('bridge: isNativeShell ist pur — false ohne Capacitor, true mit isNativePlatform, false bei Exception', () => {
  const src = extractFunction(script, 'isNativeShell');
  assert.equal(evalInScope(src, { window: {} }).value(), false);
  assert.equal(evalInScope(src, { window: { Capacitor: { isNativePlatform: function(){ return true; } } } }).value(), true);
  assert.equal(evalInScope(src, { window: { Capacitor: { isNativePlatform: function(){ throw new Error('x'); } } } }).value(), false);
  assert.equal(evalInScope(src, { window: { Capacitor: {} } }).value(), false, 'Capacitor ohne isNativePlatform → false');
});

test('bridge: isStandalone fragt zuerst isNativeShell(), dann navigator.standalone (Pitfall 4)', () => {
  const src = extractFunction(script, 'isStandalone');
  const a = src.indexOf('isNativeShell()'), b = src.indexOf('navigator.standalone');
  assert.ok(a >= 0, 'isStandalone ruft isNativeShell() nicht');
  assert.ok(b >= 0, 'navigator.standalone-Prüfung fehlt (PWA-Pfad)');
  assert.ok(a < b, 'isNativeShell() muss VOR navigator.standalone stehen');
  assert.ok(src.includes("matchMedia('(display-mode: standalone)')"), 'display-mode-Prüfung fehlt (PWA-Pfad)');
});

test('bridge: capPlugin liefert null ohne Capacitor und das Plugin-Objekt mit Capacitor.Plugins', () => {
  const src = extractFunction(script, 'capPlugin');
  assert.equal(evalInScope(src, { window: {} }).value('App'), null);
  assert.equal(evalInScope(src, { window: { Capacitor: {} } }).value('App'), null);
  assert.equal(evalInScope(src, { window: { Capacitor: { Plugins: { App: { x: 1 } } } } }).value('App').x, 1);
  assert.equal(evalInScope(src, { window: { Capacitor: { Plugins: { App: { x: 1 } } } } }).value('Share'), null);
});

test('bridge: withTimeout — Wert bei Auflösung, null bei Zeitüberschreitung (Local-first, T-06.6-13)', async () => {
  const withTimeout = evalFunction(extractFunction(script, 'withTimeout'));
  assert.equal(await withTimeout(Promise.resolve(7), 50), 7);
  assert.equal(await withTimeout(new Promise(function(){}), 20), null);
});

test('bridge: Service Worker wird nur außerhalb der Hülle registriert (SW-Guard genau einmal)', () => {
  const guard = "'serviceWorker' in navigator && !isNativeShell()";
  assert.equal(script.split(guard).length - 1, 1, 'SW-Guard muss genau einmal vorkommen');
  assert.equal(script.split('serviceWorker.register').length - 1, 1, 'genau eine serviceWorker.register-Stelle');
  assert.ok(script.indexOf(guard) < script.indexOf('serviceWorker.register'), 'Registrierung muss innerhalb des Guards liegen');
});

test('bridge: checkForUpdate kehrt in der Hülle sofort zurück (Pitfall 5)', () => {
  assert.ok(fnBody('checkForUpdate').startsWith('if(isNativeShell()) return;'),
    'checkForUpdate muss mit `if(isNativeShell()) return;` beginnen');
  /* PWA-Pfad bleibt: version.json-Abfrage und Banner */
  const src = extractFunction(script, 'checkForUpdate');
  assert.ok(src.includes("fetch('./version.json?ts='") && src.includes('showUpdateBanner('));
});

test('bridge: updateHintText — PWA-Text exakt wie bisher, Hüllen-Text nennt TestFlight; vHelp nutzt die Funktion', () => {
  const updateHintText = evalFunction(extractFunction(script, 'updateHintText'));
  const pwa = updateHintText(false), nat = updateHintText(true);
  assert.equal(pwa, 'Offline läuft alles weiter und gleicht später ab („⏳ nicht synchronisiert" zeigt Offenes). Bei neuer Version „<b>Jetzt aktualisieren</b>" tippen. Version steht unten auf der Startseite.',
    'PWA-Hilfetext muss zeichengleich zum Stand 0.34.5 bleiben (T-06.6-14)');
  assert.ok(pwa.includes('Jetzt aktualisieren') && !pwa.includes('TestFlight'));
  assert.ok(nat.includes('TestFlight') && !nat.includes('Jetzt aktualisieren'));
  assert.ok(nat.includes('App Store') && nat.includes('Build'));
  assert.ok(extractFunction(script, 'vHelp').includes('updateHintText(isNativeShell())'), 'vHelp muss updateHintText(isNativeShell()) aufrufen');
});

test('bridge: appFooter zeigt die Build-Nummer nur in der Hülle (_nativeBuild gegatet)', () => {
  const src = extractFunction(script, 'appFooter');
  assert.ok(src.includes('_nativeBuild') && src.includes('isNativeShell()'));
  assert.ok(src.indexOf('isNativeShell()') < src.indexOf('_nativeBuild'), 'Gate muss vor dem Build-Zugriff stehen');
  assert.ok(src.includes("ARGUS Beta v'+APP_VERSION+"), 'Fußzeilen-Grundtext unverändert');
});

test('bridge: exportEinsatzJson meldet in der Hülle statt <a download>-Fallback (RESEARCH Frage 2)', () => {
  const src = extractFunction(script, 'exportEinsatzJson');
  const g = src.indexOf('isNativeShell()'), d = src.indexOf('a.download');
  assert.ok(g >= 0 && d >= 0, 'Gate oder Download-Fallback fehlt');
  assert.ok(g < d, 'Hüllen-Hinweis muss vor dem Download-Fallback stehen');
  assert.ok(src.indexOf('navigator.share(') < g, 'Web-Share-Zweig bleibt vor dem Gate (unverändert)');
  assert.ok(src.includes('toast('), 'Hinweis nur per toast (D6.6-06)');
});

test('bridge: Safe-Area-CSS nur unter .native-shell — mindestens topbar/toast/body, nirgends sonst (T-06.6-14)', () => {
  const css = stripComments(firstStyleBlock());
  const rules = css.split('}').filter(r => r.includes('env(safe-area-inset'));
  assert.ok(rules.length >= 3, 'mindestens 3 Safe-Area-Regeln erwartet, gefunden: ' + rules.length);
  const sels = rules.map(r => r.slice(0, r.indexOf('{')).trim());
  for (const s of sels) assert.ok(s.startsWith('.native-shell'), 'Safe-Area-Regel nicht gegatet: ' + s);
  for (const want of ['.native-shell .topbar', '.native-shell .toast', '.native-shell body']){
    assert.ok(sels.includes(want), 'Regel fehlt: ' + want);
  }
  const inStyle = (firstStyleBlock().match(/env\(safe-area-inset/g) || []).length;
  const inHtml = (html.match(/env\(safe-area-inset/g) || []).length;
  assert.equal(inHtml, inStyle, 'env(safe-area-inset) außerhalb des <style>-Blocks (z. B. Inline-Style) gefunden');
  assert.ok(script.includes("classList.add('native-shell')"), 'native-shell-Klasse wird nie gesetzt');
  assert.ok(script.indexOf("classList.add('native-shell')") < script.indexOf('function sb('), 'Klasse muss früh (vor dem Rendern) gesetzt werden');
});

/* ── Plan 06.6-02 — Deep-Link argus://unlock#code=… ──────────────────────────
 * Parser mit optionalem Parameter (Default: window.location.hash), Kaltstart
 * über getLaunchUrl, Warmstart über appUrlOpen → Hash setzen + Reload (EIN
 * Einlösepfad in init(), T-06.6-10), Sitzungs-Guard gegen Reload-Schleifen
 * (T-06.6-12), Install-Screen-Knopf im Browser (D6.6-06: bestehende Klasse). */

const A32 = 'a'.repeat(32), B32 = 'b'.repeat(32);

test('deeplink: extractInviteCode(src) parst argus://-URLs; ohne Argument weiterhin window.location.hash', () => {
  const f = evalFunctions(script, ['extractInviteCode']);
  assert.equal(f.extractInviteCode('argus://unlock#code=abcd-efgh'), 'ABCD-EFGH');
  assert.equal(f.extractInviteCode('argus://unlock#code=ABCDEFGH'), 'ABCDEFGH');
  assert.equal(f.extractInviteCode('argus://unlock'), null);
  assert.equal(f.extractInviteCode('https://x/#inv=' + A32), null);
  const src = extractFunction(script, 'extractInviteCode');
  assert.equal(evalInScope(src, { window: { location: { hash: '#code=ABCD-EFGH' } } }).value(), 'ABCD-EFGH');
  assert.equal(evalInScope(src, { window: { location: { hash: '' } } }).value(), null);
});

test('deeplink: extractInviteToken(src) parst argus://-URLs; ohne Argument weiterhin window.location.hash', () => {
  const f = evalFunctions(script, ['extractInviteToken']);
  assert.equal(f.extractInviteToken('argus://unlock#inv=' + A32), A32);
  assert.equal(f.extractInviteToken('argus://unlock#code=ABCD-EFGH'), null);
  const src = extractFunction(script, 'extractInviteToken');
  assert.equal(evalInScope(src, { window: { location: { hash: '#inv=' + A32 } } }).value(), A32);
  assert.equal(evalInScope(src, { window: { location: { hash: '#x' } } }).value(), null);
});

test('deeplink: launchHashFrom liefert nur validierte Fragmente (#code=/#inv=), sonst leer (T-06.6-10)', () => {
  const f = evalFunctions(script, ['launchHashFrom', 'extractInviteCode', 'extractInviteToken']);
  assert.equal(f.launchHashFrom('argus://unlock#code=ABCD-EFGH'), '#code=ABCD-EFGH');
  assert.equal(f.launchHashFrom('argus://unlock#inv=' + B32), '#inv=' + B32);
  assert.equal(f.launchHashFrom('argus://unlock#foo=1'), '');
  assert.equal(f.launchHashFrom('argus://unlock'), '');
  assert.equal(f.launchHashFrom(''), '');
  assert.equal(f.launchHashFrom(null), '');
  assert.equal(f.launchHashFrom(undefined), '');
  /* Fremdinhalt im Fragment wird nie durchgereicht — nur der validierte Wert */
  const h = f.launchHashFrom('argus://unlock#code=ABCD-EFGH&evil=<img onerror=1>');
  assert.ok(h.startsWith('#code=ABCD-EFGH') && !h.includes('<'), 'Fragment muss auf den validierten Code reduziert werden: ' + h);
});

test('deeplink: consumeLaunchUrl — je Sitzung nur einmal pro URL, auch bei wechselnden URLs (T-06.6-12)', () => {
  const store = new Map();
  const fake = { getItem: k => (store.has(k) ? store.get(k) : null), setItem: (k, v) => { store.set(k, String(v)); } };
  const consume = evalInScope(extractFunction(script, 'consumeLaunchUrl'), { sessionStorage: fake }).value;
  assert.equal(consume(''), false);
  assert.equal(consume(null), false);
  assert.equal(consume('argus://unlock#code=ABCD-EFGH'), true);
  assert.equal(consume('argus://unlock#code=ABCD-EFGH'), false, 'zweiter Aufruf derselben URL → false');
  assert.equal(consume('argus://unlock#code=WXYZ-1234'), true, 'andere URL → true');
  assert.equal(consume('argus://unlock#code=ABCD-EFGH'), false,
    'Kaltstart-URL (getLaunchUrl) darf nach einem Warmstart-Reload nicht erneut greifen');
  assert.ok(store.has('argus_launch_consumed'));
  /* ohne sessionStorage (wirft) → kein Guard, aber kein Absturz */
  const broken = { getItem(){ throw new Error('x'); }, setItem(){ throw new Error('x'); } };
  assert.equal(evalInScope(extractFunction(script, 'consumeLaunchUrl'), { sessionStorage: broken }).value('argus://unlock#code=ABCD-EFGH'), true);
});

test('deeplink: nativeStartup übernimmt die Launch-URL (getLaunchUrl) und bindet appUrlOpen genau einmal', () => {
  const src = extractFunction(script, 'nativeStartup');
  for (const t of ['getLaunchUrl', 'launchHashFrom', 'consumeLaunchUrl', 'history.replaceState', "addListener('appUrlOpen'", '_urlOpenBound', 'withTimeout(']){
    assert.ok(src.includes(t), 'nativeStartup fehlt: ' + t);
  }
  assert.ok(!src.includes('exchangeCode('), 'keine zweite Einlöse-Implementierung in nativeStartup');
  assert.ok(src.indexOf('getInfo') < src.indexOf('getLaunchUrl'), 'getInfo-Block bleibt vor der Launch-URL');
});

test('deeplink: handleIncomingUrl (Warmstart) setzt den Hash und lädt neu — kein zweiter Einlösepfad, kein nativer Dialog', () => {
  const src = extractFunction(script, 'handleIncomingUrl');
  for (const t of ['launchHashFrom', 'consumeLaunchUrl', 'location.reload', 'toast(']){
    assert.ok(src.includes(t), 'handleIncomingUrl fehlt: ' + t);
  }
  assert.ok(!src.includes('exchangeCode('), 'handleIncomingUrl darf nicht selbst einlösen (ein Pfad: init)');
  assert.ok(!/innerHTML|insertAdjacentHTML/.test(src), 'URL darf nie ins DOM (T-06.6-10)');
});

test('deeplink: init() wartet auf nativeStartup(), bevor der Hash gelesen wird (Kaltstart-Pfad)', () => {
  const src = extractFunction(script, 'init');
  const a = src.indexOf('nativeStartup()'), b = src.indexOf('extractInviteCode()');
  assert.ok(a >= 0 && b >= 0, 'nativeStartup()/extractInviteCode() in init nicht gefunden');
  assert.ok(a < b, 'await nativeStartup() muss vor extractInviteCode() stehen');
  assert.ok(src.includes('await nativeStartup()'));
  assert.ok(src.indexOf('await nativeStartup()') < src.indexOf('getOperator()'), 'nativeStartup ist die erste Anweisung in init');
});

test('deeplink: Install-Screen bietet „In der ARGUS-App öffnen“ (Klasse ghost, Dispatcher openapp, D6.6-06)', () => {
  const v = extractFunction(script, 'vInstall');
  assert.ok(v.includes('data-action="openapp"'), 'Knopf fehlt im Install-Screen');
  assert.ok(/class="ghost"[^>]*data-action="openapp"/.test(v), 'Knopf muss die bestehende Klasse ghost nutzen');
  assert.ok(v.includes('bereits installiert'), 'Hinweistext „nur wenn bereits installiert“ fehlt');
  assert.ok(script.includes('a==="openapp"'), 'Dispatcher-Zweig openapp fehlt');
  assert.ok(script.includes("'argus://unlock#code='"), 'Scheme-Link argus://unlock#code= fehlt');
  const i = script.indexOf('a==="openapp"');
  const branch = script.slice(i, script.indexOf('return;', i));
  assert.ok(branch.includes('installTokenFull') && branch.includes('/^[A-Z0-9]{8}$/'), 'openapp muss den Code aus state.installTokenFull validieren');
  assert.ok(!branch.includes('exchangeCode('), 'openapp löst nicht selbst ein');
});

/* ── Plan 06.6-03 — Zugangs-Fassade (Keychain) ───────────────────────────────
 * D6.6-05: Zugangsschlüssel laufen durch accessGet/accessSet/accessDel — in der
 * Hülle Keychain (SecureStore-Plugin) + sessionStorage-Cache, in der PWA
 * unverändert localStorage (gleiche Schlüsselnamen, kein Datenumzug, T-06.6-27).
 * Pitfall 9 (Keychain überlebt die Deinstallation): keychainStartDecision ist pur
 * und per Wahrheitstafel abgedeckt. Pitfall 10 (übersehene Aufrufstelle): Gate
 * „kein Direktzugriff“ über das kommentarfreie Inline-Script (T-06.6-24). */

const ACCESS_KEYS_EXPECTED = ['argus_jwt', 'argus_jwt_exp', 'argus_jwt_by_pid', 'argus_code', 'argus_is_master', 'argus_invite'];
const DIRECT_ACCESS_RE = /localStorage\.(getItem|setItem|removeItem)\(\s*['"](argus_jwt|argus_jwt_exp|argus_jwt_by_pid|argus_code|argus_is_master|argus_invite)['"]/g;

/* Kommentare wie in security.test.cjs entfernen — Zeilenkommentare nur, wenn
 * `//` nicht Teil einer URL/eines Strings ist (sonst würden Treffer versteckt). */
function stripCommentsStrict(js){
  return js
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/([^:'"\\])\/\/[^\n]*/g, '$1');
}
function fakeStorage(init){
  const m = new Map(Object.entries(init || {}));
  return {
    getItem: k => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => { m.set(k, String(v)); },
    removeItem: k => { m.delete(k); },
    _map: m
  };
}
/* Fassade in einem kontrollierten Scope zusammensetzen (window/localStorage/
 * sessionStorage sind Fakes; Promise/String/setTimeout werden durchgereicht). */
const FACADE_FNS = ['isNativeShell', 'capPlugin', 'withTimeout', 'secureStore', 'accessStore', 'accessGet', 'accessSet', 'accessDel', 'secureWrite', 'keychainStartDecision', 'hydrateAccessFromKeychain'];
function facadeIn(scope){
  const src = '(function(){\nvar ACCESS_KEYS=' + extractVarLiteral(script, 'ACCESS_KEYS') + ';\n' +
    FACADE_FNS.map(n => {
      const f = extractFunction(script, n);
      return n === 'hydrateAccessFromKeychain' ? 'async ' + f : f;
    }).join('\n') +
    '\nreturn {' + FACADE_FNS.map(n => n + ':' + n).join(',') + '};\n})()';
  return evalInScope(src, Object.assign({ Promise: Promise, String: String, setTimeout: setTimeout, Object: Object }, scope)).value;
}
function fakeSecureStore(init){
  const kc = new Map(Object.entries(init || {}));
  const calls = [];
  return {
    _kc: kc, _calls: calls,
    get: o => { calls.push(['get', o.key]); return Promise.resolve({ value: kc.has(o.key) ? kc.get(o.key) : null }); },
    set: o => { calls.push(['set', o.key, o.value]); kc.set(o.key, o.value); return Promise.resolve(); },
    remove: o => { calls.push(['remove', o.key]); kc.delete(o.key); return Promise.resolve(); }
  };
}
const NATIVE_WIN = S => ({ Capacitor: { isNativePlatform: () => true, Plugins: { SecureStore: S } } });

test('keychain: ACCESS_KEYS exakt die sechs Zugangsschlüssel (D6.6-05)', () => {
  const keys = new Function('return (' + extractVarLiteral(script, 'ACCESS_KEYS') + ');')();
  assert.deepEqual(keys, ACCESS_KEYS_EXPECTED);
});

test('keychain: Fassade vollständig vorhanden', () => {
  for (const n of ['secureStore', 'accessStore', 'accessGet', 'accessSet', 'accessDel', 'secureWrite', 'keychainStartDecision', 'hydrateAccessFromKeychain']){
    assert.ok(hasFunction(script, n), 'Funktion fehlt: ' + n);
  }
});

test('keychain: keychainStartDecision — Wahrheitstafel 8/8 (Pitfall 9, T-06.6-21)', () => {
  const d = evalFunction(extractFunction(script, 'keychainStartDecision'));
  const table = [
    [true,  false, false, 'discard'],
    [true,  true,  false, 'hydrate'],
    [true,  true,  true,  'hydrate'],
    [true,  false, true,  'hydrate'],
    [false, false, true,  'migrate'],
    [false, true,  true,  'migrate'],
    [false, true,  false, 'none'],
    [false, false, false, 'none']
  ];
  for (const [kc, ver, leg, want] of table){
    assert.equal(d(kc, ver, leg), want, 'keychainStartDecision(' + [kc, ver, leg].join(',') + ') erwartet ' + want);
  }
});

test('keychain: Gate „kein Direktzugriff“ — localStorage auf ACCESS_KEYS nur in hydrateAccessFromKeychain (Pitfall 10, T-06.6-24)', () => {
  const stripped = stripCommentsStrict(script);
  const hyd = extractFunction(stripped, 'hydrateAccessFromKeychain');
  assert.ok(hyd.length > 0);
  const rest = stripped.replace(hyd, '');
  const hits = [...rest.matchAll(DIRECT_ACCESS_RE)].map(m => m[0]);
  assert.deepEqual(hits, [], 'Direkter localStorage-Zugriff auf Zugangsschlüssel außerhalb der Fassade: ' + hits.join(' | '));
  /* Die Fassade wird tatsächlich benutzt (keine stille Umgehung über eine andere Schicht) */
  assert.ok((script.match(/accessGet\('argus_jwt'\)/g) || []).length >= 10, 'accessGet(\'argus_jwt\') zu selten — Aufrufstellen nicht umgestellt?');
  assert.ok(script.includes("accessSet('argus_jwt',") && script.includes("accessDel('argus_jwt')"));
  assert.ok(script.includes("accessGet('argus_invite')") && script.includes("accessGet('argus_is_master')"));
});

test('keychain: accessStore wählt sessionStorage/localStorage; secureWrite nutzt set/remove und loggt nie (T-06.6-23)', () => {
  const st = extractFunction(script, 'accessStore');
  assert.ok(st.includes('sessionStorage') && st.includes('localStorage'));
  const sw = extractFunction(script, 'secureWrite');
  assert.ok(sw.includes('remove(') && sw.includes('set('), 'secureWrite muss S.set/S.remove aufrufen');
  assert.ok(!/console\.(log|warn|error|info|debug)/.test(sw), 'secureWrite darf nie loggen (Werte sind Geheimnisse)');
  assert.ok(!/console\.(log|warn|error|info|debug)/.test(extractFunction(script, 'hydrateAccessFromKeychain')), 'hydrateAccessFromKeychain darf nie loggen');
});

test('keychain: hydrateAccessFromKeychain — argus_verified, Entscheidung, Timeout, parallele get-Aufrufe (T-06.6-22)', () => {
  const src = extractFunction(script, 'hydrateAccessFromKeychain');
  for (const t of ['argus_verified', 'keychainStartDecision(', 'withTimeout(', 'Promise.all(']){
    assert.ok(src.includes(t), 'hydrateAccessFromKeychain fehlt: ' + t);
  }
  assert.ok(/withTimeout\([\s\S]*?,\s*1200\)/.test(src), 'Timeout 1200 ms erwartet (Local-first)');
  assert.ok(script.includes('async function hydrateAccessFromKeychain('), 'hydrateAccessFromKeychain muss async sein');
});

test('keychain: init() — Hydration vor nativeStartup() vor getOperator()', () => {
  const src = extractFunction(script, 'init');
  const a = src.indexOf('hydrateAccessFromKeychain()'), b = src.indexOf('nativeStartup()'), c = src.indexOf('getOperator()');
  assert.ok(a >= 0 && b >= 0 && c >= 0, 'hydrateAccessFromKeychain()/nativeStartup()/getOperator() in init nicht gefunden');
  assert.ok(a < b && b < c, 'Reihenfolge muss hydrateAccessFromKeychain() < nativeStartup() < getOperator() sein');
  assert.ok(src.includes('await hydrateAccessFromKeychain()'), 'Hydration muss awaited werden');
});

test('keychain: PWA-Pfad — accessGet/Set/Del arbeiten auf localStorage, kein Plugin-Aufruf (T-06.6-27)', () => {
  const ls = fakeStorage({ argus_jwt: 'JWT1' });
  const ss = fakeStorage();
  const f = facadeIn({ window: { localStorage: ls, sessionStorage: ss }, localStorage: ls, sessionStorage: ss });
  assert.equal(f.secureStore(), null);
  assert.equal(f.accessGet('argus_jwt'), 'JWT1');
  assert.equal(f.accessGet('argus_code'), null);
  f.accessSet('argus_code', 'ABCDEFGH');
  assert.equal(ls.getItem('argus_code'), 'ABCDEFGH');
  assert.equal(ss.getItem('argus_code'), null, 'PWA darf nie in sessionStorage schreiben');
  f.accessDel('argus_jwt');
  assert.equal(ls.getItem('argus_jwt'), null);
  /* localStorage wirft (Private Mode) → null statt Absturz */
  const broken = { getItem(){ throw new Error('x'); }, setItem(){ throw new Error('x'); }, removeItem(){ throw new Error('x'); } };
  const g = facadeIn({ window: { localStorage: broken }, localStorage: broken });
  assert.equal(g.accessGet('argus_jwt'), null);
  assert.doesNotThrow(() => { g.accessSet('argus_jwt', 'x'); g.accessDel('argus_jwt'); });
});

test('keychain: Hüllen-Pfad — sessionStorage-Cache + SecureStore set/remove; ohne Plugin Rückfall auf localStorage (D6.6-05)', () => {
  const S = fakeSecureStore();
  const ls = fakeStorage({ argus_jwt: 'OLD' }), ss = fakeStorage({ argus_jwt: 'CACHED' });
  const win = Object.assign(NATIVE_WIN(S), { localStorage: ls, sessionStorage: ss });
  const f = facadeIn({ window: win, localStorage: ls, sessionStorage: ss });
  assert.equal(f.secureStore(), S);
  assert.equal(f.accessGet('argus_jwt'), 'CACHED', 'nativ liest der Cache (sessionStorage), nie localStorage');
  f.accessSet('argus_code', 'ABCDEFGH');
  assert.equal(ss.getItem('argus_code'), 'ABCDEFGH');
  assert.equal(ls.getItem('argus_code'), null, 'nativ darf kein Geheimnis in localStorage landen');
  assert.deepEqual(S._calls.pop(), ['set', 'argus_code', 'ABCDEFGH']);
  f.accessDel('argus_jwt');
  assert.equal(ss.getItem('argus_jwt'), null);
  assert.deepEqual(S._calls.pop(), ['remove', 'argus_jwt']);
  /* Hülle ohne SecureStore-Plugin → localStorage (Zugang bleibt persistent) */
  const ls2 = fakeStorage({ argus_jwt: 'LS' }), ss2 = fakeStorage();
  const win2 = { Capacitor: { isNativePlatform: () => true, Plugins: {} }, localStorage: ls2, sessionStorage: ss2 };
  const h = facadeIn({ window: win2, localStorage: ls2, sessionStorage: ss2 });
  assert.equal(h.secureStore(), null);
  assert.equal(h.accessGet('argus_jwt'), 'LS');
});

test('keychain: hydrateAccessFromKeychain — discard bei Neuinstallation, hydrate, migrate, none (Pitfall 9)', async () => {
  /* discard: Keychain hat Reste, localStorage ist leer (frische Installation gewinnt) */
  let S = fakeSecureStore({ argus_jwt: 'GHOST', argus_code: 'GHOSTCODE' });
  let ls = fakeStorage(), ss = fakeStorage();
  let f = facadeIn({ window: Object.assign(NATIVE_WIN(S), { localStorage: ls, sessionStorage: ss }), localStorage: ls, sessionStorage: ss });
  await f.hydrateAccessFromKeychain();
  assert.equal(ss.getItem('argus_jwt'), null, 'Geisterzugang darf nicht in den Cache');
  assert.equal(S._kc.size, 0, 'Keychain-Reste müssen gelöscht werden');
  assert.ok(S._calls.some(c => c[0] === 'remove' && c[1] === 'argus_jwt'));

  /* hydrate: Keychain + argus_verified → Cache gefüllt; Alt-Wert nur für fehlende Schlüssel, danach aus localStorage entfernt */
  S = fakeSecureStore({ argus_jwt: 'KC', argus_jwt_exp: '123' });
  ls = fakeStorage({ argus_verified: 'true', argus_jwt: 'LEGACY', argus_code: 'LEGCODE' }); ss = fakeStorage();
  f = facadeIn({ window: Object.assign(NATIVE_WIN(S), { localStorage: ls, sessionStorage: ss }), localStorage: ls, sessionStorage: ss });
  await f.hydrateAccessFromKeychain();
  assert.equal(ss.getItem('argus_jwt'), 'KC', 'Keychain gewinnt gegen Alt-Wert');
  assert.equal(ss.getItem('argus_jwt_exp'), '123');
  assert.equal(ss.getItem('argus_code'), 'LEGCODE', 'fehlender Schlüssel wird aus dem Alt-Wert ergänzt');
  assert.equal(S._kc.get('argus_code'), 'LEGCODE', '… und in die Keychain geschrieben');
  assert.equal(ls.getItem('argus_jwt'), null, 'Alt-Werte werden aus localStorage entfernt');
  assert.equal(ls.getItem('argus_code'), null);
  assert.equal(ls.getItem('argus_verified'), 'true', 'Marker bleibt in localStorage');

  /* migrate: Keychain leer, Alt-Werte vorhanden → Cache + Keychain, localStorage bereinigt */
  S = fakeSecureStore();
  ls = fakeStorage({ argus_jwt: 'LEGACY', argus_is_master: 'true', argus_praesidium_id: 'P1' }); ss = fakeStorage();
  f = facadeIn({ window: Object.assign(NATIVE_WIN(S), { localStorage: ls, sessionStorage: ss }), localStorage: ls, sessionStorage: ss });
  await f.hydrateAccessFromKeychain();
  assert.equal(ss.getItem('argus_jwt'), 'LEGACY');
  assert.equal(S._kc.get('argus_jwt'), 'LEGACY');
  assert.equal(S._kc.get('argus_is_master'), 'true');
  assert.equal(ls.getItem('argus_jwt'), null);
  assert.equal(ls.getItem('argus_praesidium_id'), 'P1', 'Nicht-Zugangsschlüssel bleiben unberührt');

  /* none: alles leer → nichts passiert, keine Schreibzugriffe */
  S = fakeSecureStore(); ls = fakeStorage({ argus_verified: 'true' }); ss = fakeStorage();
  f = facadeIn({ window: Object.assign(NATIVE_WIN(S), { localStorage: ls, sessionStorage: ss }), localStorage: ls, sessionStorage: ss });
  await f.hydrateAccessFromKeychain();
  assert.equal(ss._map.size, 0);
  assert.ok(S._calls.every(c => c[0] === 'get'), 'bei none nur Lesezugriffe');

  /* PWA: sofort zurück, nichts angefasst */
  ls = fakeStorage({ argus_jwt: 'PWA' }); ss = fakeStorage();
  f = facadeIn({ window: { localStorage: ls, sessionStorage: ss }, localStorage: ls, sessionStorage: ss });
  await f.hydrateAccessFromKeychain();
  assert.equal(ls.getItem('argus_jwt'), 'PWA');
  assert.equal(ss._map.size, 0);
});

test('keychain: hydrateAccessFromKeychain blockiert den Start nicht — hängendes Plugin läuft in den Timeout (T-06.6-22)', async () => {
  const S = { get: () => new Promise(function(){}), set: () => Promise.resolve(), remove: () => Promise.resolve() };
  const ls = fakeStorage({ argus_verified: 'true' }), ss = fakeStorage();
  const f = facadeIn({ window: Object.assign(NATIVE_WIN(S), { localStorage: ls, sessionStorage: ss }), localStorage: ls, sessionStorage: ss });
  const t0 = Date.now();
  await f.hydrateAccessFromKeychain();
  const dt = Date.now() - t0;
  assert.ok(dt >= 1000 && dt < 3000, 'Timeout erwartet (~1200 ms), gemessen ' + dt + ' ms');
  assert.equal(ss._map.size, 0);
});
