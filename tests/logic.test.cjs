/* Unit-Tests für pure Logik-Funktionen der Feld-App (extrahiert aus index.html).
 * Traceability: safePhoto ← Stored-XSS-Fix v0.32.2 · revokedDecision ← D-20
 * Fehlaussperrungs-Schutz · cmpVer ← „Was ist neu"-Sortierung · esc ← XSS-Basis. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { app, extractFunction, evalFunction } = require('./_extract.cjs');

const script = app().script;

test('safePhoto: gültige data:image-URIs passieren', () => {
  const safePhoto = evalFunction(extractFunction(script, 'safePhoto'));
  const good = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBD';
  assert.equal(safePhoto(good), good);
  assert.equal(safePhoto('data:image/png;base64,iVBORw0KGgo='), 'data:image/png;base64,iVBORw0KGgo=');
  assert.equal(safePhoto('data:image/webp;base64,UklGRg=='), 'data:image/webp;base64,UklGRg==');
});

test('safePhoto: Angriffsvektoren werden abgewiesen (Regression v0.32.2)', () => {
  const safePhoto = evalFunction(extractFunction(script, 'safePhoto'));
  assert.equal(safePhoto('"><img src=x onerror=alert(1)>'), '');          // Attribut-Breakout
  assert.equal(safePhoto('data:text/html;base64,PHNjcmlwdD4='), '');      // HTML-Payload
  assert.equal(safePhoto('javascript:alert(1)'), '');                     // js-URI
  assert.equal(safePhoto('data:image/svg+xml;base64,PHN2Zz4='), '');      // SVG (kann Script tragen)
  assert.equal(safePhoto(null), '');
  assert.equal(safePhoto(42), '');
  assert.equal(safePhoto('data:image/png;base64,abc"def'), '');           // Quote im Payload
});

test('revokedDecision: sperrt NUR bei eindeutigem revoked===true (D-20)', () => {
  const revokedDecision = evalFunction(extractFunction(script, 'revokedDecision'));
  assert.equal(revokedDecision({ revoked: true }), 'lock');
  assert.equal(revokedDecision({ revoked: false }), 'ok');
  assert.equal(revokedDecision({ found: false }), 'ignore');   // gelöschter Code ≠ Sperr-Signal
  assert.equal(revokedDecision(null), 'ignore');               // Transportfehler
  assert.equal(revokedDecision('kaputt'), 'ignore');           // unerwartetes Format
  assert.equal(revokedDecision({}), 'ignore');
  assert.equal(revokedDecision({ revoked: 'true' }), 'ignore'); // String ≠ boolean → konservativ
});

test('esc: HTML-Metazeichen werden escaped', () => {
  const esc = evalFunction(extractFunction(script, 'esc'));
  assert.equal(esc('<img src=x>'), '&lt;img src=x&gt;');
  assert.equal(esc('a"b&c'), 'a&quot;b&amp;c');
  assert.equal(esc(null), '');
  assert.equal(esc(0), '0');
});

test('cmpVer: semantische Versionssortierung', () => {
  const cmpVer = evalFunction(extractFunction(script, 'cmpVer'));
  assert.ok(cmpVer('0.9.0', '0.12.0') < 0, '0.9 < 0.12 (numerisch, nicht lexikalisch)');
  assert.ok(cmpVer('0.33.2', '0.33.10') < 0);
  assert.equal(cmpVer('1.2.3', '1.2.3'), 0);
  assert.ok(cmpVer('0.33.1', '0.33.0') > 0);
});
