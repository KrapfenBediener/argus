/* sync-web.mjs — kopiert die Web-App aus dem Repo-Stamm nach native/www (Bundle der iOS-Hülle).
 *
 * Quelle der Wahrheit (Positivliste, nichts anderes landet im Bundle):
 *   1. sw.js            → PRECACHE_URLS (index.html, vendor/supabase.js, config.js, fonts/*.woff2)
 *   2. index.html       → UPDATE_SHEETS (docs/UPDATE_*.html, relativ aus der App verlinkt)
 *   3. jedes Update-Sheet → url(fonts/…)-Referenzen (liegen relativ zum Sheet, also docs/fonts/)
 *   4. feste Extras     → icon-180.png, icon-192.png, manifest.json, version.json
 *   5. zusätzlich geschrieben: www/native-version.json = { version: APP_VERSION, build } — ohne Zeitstempel
 *
 * Nie dabei: sw.js (kein Service Worker im WKWebView), legacy/, .planning/, assets/,
 * Leitungs-/Lage-Seiten (docs/leitung-*.html, docs/lage-*.html — D-06), Beta-Altdateien.
 *
 * Aufruf:  node scripts/sync-web.mjs [--out <dir>] [--quiet]
 * Exit:    0 ok · 1 gelistete Quelldatei fehlt · 2 Sicherheitsnetz (Pfad unzulässig; wird nicht ausgegeben)
 * Idempotent: zweimal ausführen ergibt byteidentische Bäume (keine Zeitstempel, keine Zufallswerte).
 * Nur Node-Bordmittel; braucht weder Xcode noch native/node_modules.
 */
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const NATIVE = fileURLToPath(new URL('../', import.meta.url));
const require = createRequire(import.meta.url);
const { readFileText, extractVarLiteral, app } = require(path.join(ROOT, 'tests', '_extract.cjs'));

/* ── Argumente ─────────────────────────────────────────────────────────────── */
const argv = process.argv.slice(2);
let outDir = path.join(NATIVE, 'www');
let quiet = false;
for (let i = 0; i < argv.length; i++){
  if (argv[i] === '--out'){
    if (!argv[i + 1]){ console.error('sync-web: --out braucht einen Pfad'); process.exit(1); }
    outDir = path.resolve(argv[++i]);
  } else if (argv[i] === '--quiet'){
    quiet = true;
  } else {
    console.error('sync-web: unbekanntes Argument ' + argv[i]);
    process.exit(1);
  }
}

/* ── Sicherheitsnetz: nur relative Pfade ohne .. und nie Leitungs-/Lage-Seiten (D-06) ── */
const FORBIDDEN = /(leitung|lage)-[0-9a-f]+\.html$/;
function assertSafe(rel){
  const bad = typeof rel !== 'string' || rel === '' || path.isAbsolute(rel) || rel.startsWith('/')
    || rel.split(/[\\/]/).includes('..') || FORBIDDEN.test(rel);
  if (bad){
    console.error('sync-web: unzulässiger Pfad in der Dateiliste — Abbruch (Sicherheitsnetz)');
    process.exit(2);
  }
}

/* ── Allowlist aufbauen ────────────────────────────────────────────────────── */
function normalize(u){ return u.replace(/^\.\//, '').split('?')[0]; }

const files = new Set();

/* 1. PRECACHE_URLS aus sw.js (Regex wie tests/consistency.test.cjs) */
const sw = readFileText('sw.js');
const pre = sw.match(/const PRECACHE_URLS = \[([\s\S]*?)\];/);
if (!pre){ console.error('sync-web: PRECACHE_URLS in sw.js nicht gefunden'); process.exit(1); }
for (const m of pre[1].matchAll(/'([^']+)'/g)){
  if (m[1] === './') continue;
  files.add(normalize(m[1]));
}

/* 2. UPDATE_SHEETS aus index.html (reines Objekt-Literal) */
const script = app().script;
const SHEETS = new Function('return (' + extractVarLiteral(script, 'UPDATE_SHEETS') + ');')();
const sheetPaths = Object.values(SHEETS).map(normalize);
for (const s of sheetPaths) files.add(s);

/* 3. Font-Referenzen der Update-Sheets (relativ zum Sheet → docs/fonts/…) */
const FONT_RE = /url\(\s*['"]?((?:\.\/)?fonts\/[^)'"\s]+)/g;
for (const s of sheetPaths){
  assertSafe(s);
  const src = path.join(ROOT, s);
  if (!fs.existsSync(src)){ console.error('sync-web: Quelldatei fehlt: ' + s); process.exit(1); }
  const html = fs.readFileSync(src, 'utf8');
  for (const m of html.matchAll(FONT_RE)){
    files.add(path.posix.join(path.posix.dirname(s), normalize(m[1])));
  }
}

/* 4. feste Extras */
for (const x of ['icon-180.png', 'icon-192.png', 'manifest.json', 'version.json']) files.add(x);

const list = [...files].sort();
for (const rel of list) assertSafe(rel);

/* ── Versionsdaten (ohne Zeitstempel) ──────────────────────────────────────── */
const APP_VERSION = (script.match(/var APP_VERSION = '([^']+)'/) || [])[1];
if (!APP_VERSION || !/^\d+\.\d+\.\d+$/.test(APP_VERSION)){
  console.error('sync-web: APP_VERSION in index.html nicht gefunden oder unwohlgeformt');
  process.exit(1);
}
const build = JSON.parse(fs.readFileSync(path.join(NATIVE, 'version.json'), 'utf8')).build;
if (!Number.isInteger(build) || build < 1){
  console.error('sync-web: native/version.json.build muss eine Ganzzahl >= 1 sein');
  process.exit(1);
}

/* ── Quellen prüfen, Ziel leeren, kopieren ─────────────────────────────────── */
for (const rel of list){
  if (!fs.existsSync(path.join(ROOT, rel))){
    console.error('sync-web: Quelldatei fehlt: ' + rel);
    process.exit(1);
  }
}

fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });
for (const rel of list){
  const dst = path.join(outDir, rel);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.copyFileSync(path.join(ROOT, rel), dst);
}
fs.writeFileSync(path.join(outDir, 'native-version.json'),
  JSON.stringify({ version: APP_VERSION, build }, null, 2) + '\n');

if (!quiet) console.log('sync-web: ' + (list.length + 1) + ' Dateien → ' + outDir);
process.exit(0);
