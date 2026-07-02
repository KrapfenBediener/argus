/* Release-Konsistenz-Gates: fangen die Fehlerklasse „Version an einer Stelle
 * vergessen" (APP_VERSION / version.json / CHANGELOG / sw-Cache / Update-Sheets). */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { ROOT, app, readFileText, extractVarLiteral, extractFunction, evalFunction } = require('./_extract.cjs');

const script = app().script;
const APP_VERSION = (script.match(/var APP_VERSION = '([^']+)'/) || [])[1];

test('Version: APP_VERSION ist gesetzt und wohlgeformt', () => {
  assert.match(APP_VERSION || '', /^\d+\.\d+\.\d+$/);
});

test('Version: version.json == APP_VERSION', () => {
  const vj = JSON.parse(readFileText('version.json'));
  assert.equal(vj.version, APP_VERSION, 'version.json hinkt hinterher — Update-Banner bricht');
});

test('Version: CHANGELOG-Topeintrag == APP_VERSION', () => {
  const top = (readFileText('CHANGELOG.md').match(/^## v(\d+\.\d+\.\d+)/m) || [])[1];
  assert.equal(top, APP_VERSION, 'CHANGELOG.md hat keinen Eintrag für v' + APP_VERSION);
});

test('Version: sw.js CACHE_NAME wohlgeformt (ccp-shell-vN)', () => {
  const sw = readFileText('sw.js');
  assert.match(sw, /const CACHE_NAME = 'ccp-shell-v\d+';/);
});

test('Version: WHATS_NEW enthält keine Zukunfts-Versionen > APP_VERSION', () => {
  const cmpVer = evalFunction(extractFunction(script, 'cmpVer'));
  const WHATS_NEW = new Function('return (' + extractVarLiteral(script, 'WHATS_NEW') + ');')();
  for (const k of Object.keys(WHATS_NEW)){
    assert.match(k, /^\d+\.\d+(\.\d+)?$/, 'WHATS_NEW-Schlüssel kaputt: ' + k);
    assert.ok(cmpVer(k, APP_VERSION) <= 0, 'WHATS_NEW hat Zukunfts-Eintrag ' + k + ' > ' + APP_VERSION);
  }
});

test('UPDATE_SHEETS: jede referenzierte Datei existiert', () => {
  const SHEETS = new Function('return (' + extractVarLiteral(script, 'UPDATE_SHEETS') + ');')();
  for (const [ver, rel] of Object.entries(SHEETS)){
    assert.ok(fs.existsSync(path.join(ROOT, rel)), 'Update-Sheet fehlt: ' + rel + ' (v' + ver + ')');
  }
});

test('sw.js: alle PRECACHE_URLS existieren im Repo', () => {
  const sw = readFileText('sw.js');
  const m = sw.match(/const PRECACHE_URLS = \[([\s\S]*?)\];/);
  assert.ok(m, 'PRECACHE_URLS nicht gefunden');
  const urls = [...m[1].matchAll(/'([^']+)'/g)].map(x => x[1]);
  for (const u of urls){
    if (u === './') continue;
    const rel = u.replace(/^\.\//, '').split('?')[0];
    assert.ok(fs.existsSync(path.join(ROOT, rel)), 'Precache-Datei fehlt: ' + u + ' — Offline-Hülle bricht');
  }
});
