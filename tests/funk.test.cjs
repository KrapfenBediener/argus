/* Test-Vertrag Funkspruch-Modus (Phase 6.5, S8) — reine Funktionen aus index.html.
 * Traceability: D6.5-10/S8 (Funkspruch-Text + SDS-Zeile, KEINE Patientendaten)
 * ← Plan 06.5-07. Wave 0: Tests stehen vor der Implementierung; fehlt eine
 * Funktion, wird mit Begründung übersprungen (Plan 08: 0 Skips beim Release).
 * Vertrag: Hilfsfunktionen liegen INNERHALB der Vertragsfunktion (oder werden hier
 * ausdrücklich in die Namensliste von evalFunctions aufgenommen) — extrahiert wird
 * nur, was die Tests benennen. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { app, hasFunction, evalFunctions, extractFunction } = require('./_extract.cjs');

const script = app().script;
function skipUnless(planId, ...names){
  const missing = names.filter(function(n){ return !hasFunction(script, n); });
  return missing.length ? 'kommt mit Plan ' + planId + ' (' + missing.join(', ') + ')' : false;
}
function load(names){ return evalFunctions(script, names.filter(function(n){ return hasFunction(script, n); })); }

test('funkText: Wortlaut mit Ort, Zahlwörter, Singular/Plural', { skip: skipUnless('06.5-07', 'funkText') }, () => {
  const f = load(['funkText']);
  assert.equal(f.funkText({kennung: 'A', ort: 'Marktplatz', hhmm: '14:32', t1: 3, t2: 5, t3: 7, t5: 1, prio: 2, gpa: 4, tq: 1}),
    'CCP Anton, Marktplatz, 14:32 — drei Rot, fünf Gelb, sieben Grün, ein Schwarz, zwei Prio, vier abtransportiert.');
});

test('funkText: führendes „CCP“ im Ort entfällt (Demo-Orte, Tippvarianten)', { skip: skipUnless('06.5-10', 'funkText') }, () => {
  const f = load(['funkText']);
  const base = {kennung: 'A', hhmm: '14:32', t1: 3, t2: 5, t3: 7, t5: 1, prio: 2, gpa: 4, tq: 1};
  const rest = ' — drei Rot, fünf Gelb, sieben Grün, ein Schwarz, zwei Prio, vier abtransportiert.';
  assert.equal(f.funkText(Object.assign({}, base, {ort: 'CCP Marktplatz'})), 'CCP Anton, Marktplatz, 14:32' + rest);
  assert.equal(f.funkText(Object.assign({}, base, {ort: 'ccp: Bahnhof'})), 'CCP Anton, Bahnhof, 14:32' + rest);
  assert.equal(f.funkText(Object.assign({}, base, {ort: 'CCP'})), 'CCP Anton, 14:32' + rest);
  assert.equal(f.funkText(Object.assign({}, base, {ort: 'CCP - Schulhof'})), 'CCP Anton, Schulhof, 14:32' + rest);
  /* Wörter, die nur mit „ccp“ beginnen, bleiben unverändert */
  assert.equal(f.funkText(Object.assign({}, base, {ort: 'Ccpark'})), 'CCP Anton, Ccpark, 14:32' + rest);
});

test('funkText: ohne Ort, Nullen, große Zahlen als Ziffern, keine Tourniquets', { skip: skipUnless('06.5-07', 'funkText') }, () => {
  const f = load(['funkText']);
  const base = {kennung: 'B', ort: '', hhmm: '09:05', t1: 0, t2: 1, t3: 12, t5: 0, prio: 0, gpa: 13, tq: 0};
  assert.equal(f.funkText(base),
    'CCP Berta, 09:05 — null Rot, ein Gelb, zwölf Grün, null Schwarz, null Prio, 13 abtransportiert.');
  assert.ok(!/Tourniquet/.test(f.funkText(Object.assign({}, base, {tq: 2}))), 'Tourniquets gehören nicht in die Funkmeldung');
});

test('funkText: Kennungen in Buchstabiertafel, Verbund A/B', { skip: skipUnless('06.5-07', 'funkText') }, () => {
  const f = load(['funkText']);
  const base = {ort: '', hhmm: '09:05', t1: 0, t2: 0, t3: 0, t5: 0, prio: 0, gpa: 0, tq: 0};
  assert.ok(f.funkText(Object.assign({}, base, {kennung: 'A/B'})).startsWith('CCP Anton/Berta, '));
  const names = {C: 'Cäsar', D: 'Dora', E: 'Emil', F: 'Friedrich', K: 'Kaufmann', N: 'Nordpol'};
  Object.keys(names).forEach(function(k){
    assert.ok(f.funkText(Object.assign({}, base, {kennung: k})).startsWith('CCP ' + names[k] + ', '), k);
  });
});

test('funkSds: kompakte Zeile, Verbund mit +', { skip: skipUnless('06.5-07', 'funkSds') }, () => {
  const f = load(['funkSds']);
  const c = {kennung: 'A', hhmm: '14:32', nr: 3, t1: 3, t2: 5, t3: 7, t5: 1, prio: 2, gpa: 4, tq: 1};
  assert.equal(f.funkSds(c), 'ARG1|A|1432|3|T1=3,T2=5,T3=7,T5=1,P=2,G=4');
  assert.ok(f.funkSds(Object.assign({}, c, {kennung: 'A/B'})).startsWith('ARG1|A+B|'));
});

test('Datenschutz (D6.5-10): funkText/funkSds lesen keine Patientendaten', { skip: skipUnless('06.5-07', 'funkText', 'funkSds') }, () => {
  ['funkText', 'funkSds'].forEach(function(n){
    const src = extractFunction(script, n);
    assert.ok(!/\.(name|notes|photo|moi|injury|allergies)\b/.test(src), n + ' greift auf Patientenfelder zu');
    assert.ok(!/patients/.test(src), n + ' greift auf die Patientenliste zu');
  });
});
