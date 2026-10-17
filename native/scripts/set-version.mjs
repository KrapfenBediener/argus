/* set-version.mjs — koppelt die native Version an die Web-App (D6.6-07).
 *
 *   MARKETING_VERSION       (= CFBundleShortVersionString) ← APP_VERSION aus index.html
 *   CURRENT_PROJECT_VERSION (= CFBundleVersion)            ← native/version.json.build
 *
 * Schreibt per Regex in ios/App/App.xcodeproj/project.pbxproj (OpenStep-Plist, Text) — beide
 * Build-Konfigurationen (Debug/Release). Kein agvtool (fehlt ohne Xcode), kein PlistBuddy/plutil
 * (würde die Datei in XML umformatieren).
 *
 * Aufruf:  node scripts/set-version.mjs [--bump] [--check] [--strip-team]
 *   --bump        erhöht version.json.build um 1 (vor dem Schreiben)
 *   --check       schreibt nichts; Exit 1, wenn die pbxproj von APP_VERSION/Build abweicht
 *   --strip-team  entfernt alle Zeilen `DEVELOPMENT_TEAM = …;` (von Xcode lokal eingetragen — nie committen)
 * Exit: 0 ok · 1 Fehler (Version unwohlgeformt, Build ungültig, zu wenige Treffer, Abweichung bei --check)
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const NATIVE = fileURLToPath(new URL('../', import.meta.url));
const VERSION_FILE = path.join(NATIVE, 'version.json');
const PBXPROJ = path.join(NATIVE, 'ios', 'App', 'App.xcodeproj', 'project.pbxproj');

const args = new Set(process.argv.slice(2));
for (const a of args){
  if (!['--bump', '--check', '--strip-team'].includes(a)){
    console.error('set-version: unbekanntes Argument ' + a); process.exit(1);
  }
}
const BUMP = args.has('--bump'), CHECK = args.has('--check'), STRIP = args.has('--strip-team');
if (BUMP && CHECK){ console.error('set-version: --bump und --check schließen sich aus'); process.exit(1); }

/* APP_VERSION aus index.html */
const appVersion = (readFileSync(path.join(ROOT, 'index.html'), 'utf8').match(/var APP_VERSION = '([^']+)'/) || [])[1];
if (!appVersion || !/^\d+\.\d+\.\d+$/.test(appVersion)){
  console.error('set-version: APP_VERSION in index.html fehlt oder ist nicht x.y.z'); process.exit(1);
}

/* Build-Zähler */
const v = JSON.parse(readFileSync(VERSION_FILE, 'utf8'));
if (!Number.isInteger(v.build) || v.build < 1){
  console.error('set-version: version.json.build muss eine Ganzzahl >= 1 sein'); process.exit(1);
}
if (BUMP){
  v.build += 1;
  writeFileSync(VERSION_FILE, JSON.stringify(v, null, 2) + '\n');
}
const build = v.build;

/* pbxproj lesen und prüfen */
const src = readFileSync(PBXPROJ, 'utf8');
const RE_MV = /MARKETING_VERSION = ([^;]+);/g;
const RE_CPV = /CURRENT_PROJECT_VERSION = ([^;]+);/g;
const RE_TEAM = /^[ \t]*DEVELOPMENT_TEAM = [^;]*;[ \t]*\r?\n/gm;
const mv = [...src.matchAll(RE_MV)].map(m => m[1]);
const cpv = [...src.matchAll(RE_CPV)].map(m => m[1]);
if (mv.length < 2 || cpv.length < 2){
  console.error('set-version: project.pbxproj hat weniger als 2 Treffer je Schlüssel (MARKETING_VERSION: '
    + mv.length + ', CURRENT_PROJECT_VERSION: ' + cpv.length + ') — Template-Struktur unerwartet');
  process.exit(1);
}

if (CHECK){
  const hasTeam = STRIP && RE_TEAM.test(src);
  const bad = mv.some(x => x !== appVersion) || cpv.some(x => x !== String(build)) || hasTeam;
  if (bad){
    console.error('set-version: project.pbxproj weicht ab — erwartet version ' + appVersion + ' (build ' + build + ')'
      + ', gefunden MARKETING_VERSION ' + [...new Set(mv)].join('/') + ', CURRENT_PROJECT_VERSION ' + [...new Set(cpv)].join('/')
      + (hasTeam ? '; DEVELOPMENT_TEAM ist eingetragen (nicht committen — --strip-team)' : ''));
    process.exit(1);
  }
  console.log('native: version ' + appVersion + ' (build ' + build + ') — pbxproj stimmt überein');
  process.exit(0);
}

/* schreiben (alle Vorkommen, Debug + Release) */
let out = src
  .replace(RE_MV, 'MARKETING_VERSION = ' + appVersion + ';')
  .replace(RE_CPV, 'CURRENT_PROJECT_VERSION = ' + build + ';');
if (STRIP) out = out.replace(RE_TEAM, '');
if (out !== src) writeFileSync(PBXPROJ, out);
console.log('native: version ' + appVersion + ' (build ' + build + ')');
