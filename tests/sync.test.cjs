/* Test-Vertrag Phase 6.5 (Gerätestatus & Sync-Fundament) — reine Funktionen aus index.html.
 * Traceability: D6.5-05 Feldweiser Merge · D6.5-06 Änderungsgruppen (FGROUPS) ·
 * D6.5-07 Uhrversatz · D6.5-12 Gerätestatus/Abschluss · D6.5-14 lokale Fristen
 * ← Plan 06.5-03 (Sync-Kern), 06.5-04 (Grabstein), 06.5-05 (Gerätestatus),
 *   06.5-06 (Abschluss/Fristen).
 * Die Tests stehen VOR der Implementierung (Wave 0): fehlt eine Vertragsfunktion,
 * wird der Test mit Begründung übersprungen (nicht rot). Sobald die Funktion
 * existiert, ist der Test scharf — Plan 08 verlangt 0 Skips beim Release. */
'use strict';
const fs = require('fs');
const path = require('path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { app, hasFunction, evalFunctions, ROOT } = require('./_extract.cjs');

const script = app().script;
const vectors = require('./fixtures/merge-vectors.json');

/* false = Test läuft; String = Skip-Begründung (Funktion fehlt noch). */
function skipUnless(planId, ...names){
  const missing = names.filter(function(n){
    return n === 'FGROUPS' ? !/var\s+FGROUPS\s*=/.test(script) : !hasFunction(script, n);
  });
  return missing.length ? 'kommt mit Plan ' + planId + ' (' + missing.join(', ') + ')' : false;
}
/* Funktionen (+ optional FGROUPS) im gemeinsamen Scope laden; nur vorhandene Namen. */
function load(names, withGroups){
  return evalFunctions(script, names.filter(function(n){ return hasFunction(script, n); }),
    withGroups ? ['FGROUPS'] : []);
}

/* ---------- FGROUPS / Änderungsgruppen (Plan 06.5-03) ---------- */

test('FGROUPS: genau die 7 Gruppen mit den Vertrags-Schlüsseln (D6.5-06)', { skip: skipUnless('06.5-03', 'FGROUPS') }, () => {
  const FG = load([], true).FGROUPS;
  assert.deepEqual(FG, {
    cat: ['cat', 'lastTriage'],
    st: ['status', 'prio', 'ready'],
    vit: ['vit', 'pupRe', 'pupLi'],
    tx: ['tx'],
    tq: ['tqStart', 'tqSite'],
    stamm: ['name', 'age', 'gender', 'allergies', 'moi', 'injury', 'fr', 'notes', 'inj'],
    foto: ['photo']
  });
});

function samplePatient(){
  return {
    id: 'p1', cat: 'T2', lastTriage: 'T2', status: 'active', prio: false, ready: false,
    vit: {hf: '80'}, pupRe: '', pupLi: '', tx: {}, tqStart: null, tqSite: null,
    name: 'Testname', age: '30', gender: 'm', allergies: '', moi: '', injury: '', fr: '', notes: '', inj: [],
    photo: 'data:image/jpeg;base64,' + 'A'.repeat(60) + 'END1'
  };
}

test('changedGroups: ohne _sig sind alle 7 Gruppen geändert', { skip: skipUnless('06.5-03', 'FGROUPS', 'groupSig', 'groupSigs', 'changedGroups') }, () => {
  const f = load(['groupSig', 'groupSigs', 'changedGroups'], true);
  const p = samplePatient();
  assert.deepEqual(f.changedGroups(p, f.FGROUPS).sort(), Object.keys(f.FGROUPS).sort());
});

test('changedGroups: nur die tatsächlich geänderte Gruppe wird gemeldet', { skip: skipUnless('06.5-03', 'FGROUPS', 'groupSig', 'groupSigs', 'changedGroups') }, () => {
  const f = load(['groupSig', 'groupSigs', 'changedGroups'], true);
  const p = samplePatient();
  p._sig = f.groupSigs(p, f.FGROUPS);
  assert.deepEqual(f.changedGroups(p, f.FGROUPS), []);
  p.prio = true;
  assert.deepEqual(f.changedGroups(p, f.FGROUPS), ['st']);
  p._sig = f.groupSigs(p, f.FGROUPS);
  p.photo = 'data:image/jpeg;base64,' + 'A'.repeat(60) + 'END2';   // gleiche Länge, anderes Ende
  assert.deepEqual(f.changedGroups(p, f.FGROUPS), ['foto']);
});

test('groupSig: Foto wird als P<länge>:<letzte 24 Zeichen> signiert, leer → leerer String-Anteil', { skip: skipUnless('06.5-03', 'groupSig') }, () => {
  const f = load(['groupSig']);
  const photo = 'data:image/jpeg;base64,' + 'A'.repeat(60) + 'END1';
  assert.equal(f.groupSig({photo}, ['photo']), 'P' + photo.length + ':' + photo.slice(-24));
  assert.equal(f.groupSig({photo: ''}, ['photo']), '');
  assert.equal(f.groupSig({a: 1, b: 'x'}, ['a', 'b']), '1\u0001"x"');
});

/* ---------- Stempel (Plan 06.5-03) ---------- */

test('nextStamp: streng monoton, auch bei zurückspringender Uhr', { skip: skipUnless('06.5-03', 'nextStamp') }, () => {
  const f = load(['nextStamp']);
  assert.equal(f.nextStamp(100, 0), 100);
  assert.equal(f.nextStamp(100, 100), 101);
  assert.equal(f.nextStamp(90, 100), 101);
});

test('stampGroups: Basis-Logik — erster Stempel b=alter t, zweiter vor Bestätigung behält die Basis', { skip: skipUnless('06.5-03', 'stampGroups') }, () => {
  const f = load(['stampGroups']);
  const p = {};
  f.stampGroups(p, ['st'], 100, 3);
  assert.deepEqual(p.fts.st, {t: 100, d: 3, b: 0, p: 1});
  f.stampGroups(p, ['st'], 200, 3);                       // noch unbestätigt (p:1) → Basis bleibt
  assert.deepEqual(p.fts.st, {t: 200, d: 3, b: 0, p: 1});
  const q = {fts: {vit: {t: 150, d: 2}}};                 // bestätigter Eintrag → Basis = alter t
  assert.equal(f.stampGroups(q, ['vit', 'tx'], 300, 4), q);
  assert.deepEqual(q.fts.vit, {t: 300, d: 4, b: 150, p: 1});
  assert.deepEqual(q.fts.tx, {t: 300, d: 4, b: 0, p: 1});
});

test('ftsForUpload / clearPending: p-Flags nur lokal, Bestätigung nur bis upTo', { skip: skipUnless('06.5-03', 'ftsForUpload', 'clearPending') }, () => {
  const f = load(['ftsForUpload', 'clearPending']);
  const fts = {st: {t: 200, d: 3, b: 100, p: 1}, vit: {t: 100, d: 1, b: 0, p: 1}, ack: {t: 5, d: 1, p: 1}};
  assert.deepEqual(f.ftsForUpload(fts), {st: {t: 200, d: 3, b: 100}, vit: {t: 100, d: 1, b: 0}, ack: {t: 5}});
  assert.ok(fts.st.p, 'ftsForUpload darf das Original nicht verändern');
  f.clearPending(fts, 150);
  assert.equal(fts.st.p, 1);            // t 200 > 150 → noch offen
  assert.equal(fts.vit.p, undefined);   // t 100 <= 150 → bestätigt
});

/* ---------- Merge (Plan 06.5-03, Grabstein 06.5-04) ---------- */

const S2C = {deleted_at: 'deletedAt', deleted_by: 'deletedBy', deleted_dev: 'deletedDev', last_triage: 'lastTriage'};
function toClient(row){
  const o = {};
  Object.keys(row).forEach(function(k){ o[S2C[k] || k] = row[k]; });
  return o;
}
function getPath(obj, p){
  return p.split('.').reduce(function(a, k){ return a == null ? undefined : a[k]; }, obj);
}

vectors.filter(function(v){ return !v.serverOnly; }).forEach(function(v){
  test('mergeGroups ' + v.id, { skip: skipUnless('06.5-03', 'FGROUPS', 'groupSig', 'mergeGroups') }, () => {
    const f = load(['groupSig', 'tombstoneHull', 'mergeGroups'], true);
    const res = f.mergeGroups(toClient(v.new), toClient(v.old), f.FGROUPS);
    Object.keys(v.expect).forEach(function(path){
      const segs = path.split('.');
      segs[0] = S2C[segs[0]] || segs[0];
      assert.deepEqual(getPath(res, segs.join('.')), v.expect[path], v.id + ': ' + path);
    });
  });
});

test('mergeGroups: Eingabe-Objekte bleiben unverändert (reine Funktion)', { skip: skipUnless('06.5-03', 'FGROUPS', 'groupSig', 'mergeGroups') }, () => {
  const f = load(['groupSig', 'tombstoneHull', 'mergeGroups'], true);
  const v = vectors[0];
  const L = toClient(v.new), C = toClient(v.old);
  const l0 = JSON.stringify(L), c0 = JSON.stringify(C);
  f.mergeGroups(L, C, f.FGROUPS);
  assert.equal(JSON.stringify(L), l0);
  assert.equal(JSON.stringify(C), c0);
});

test('Probe-Konsistenz: jede Vektor-ID kommt in supabase/probes/0025_sync_probe.sql vor', {
  skip: !fs.existsSync(path.join(ROOT, 'supabase/probes/0025_sync_probe.sql')) && 'kommt mit Plan 06.5-01'
}, () => {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase/probes/0025_sync_probe.sql'), 'utf8');
  vectors.forEach(function(v){
    assert.ok(sql.includes(v.id.split('-')[0]), 'SQL-Probe kennt ' + v.id + ' nicht');
  });
});

/* ---------- Uhrversatz (Plan 06.5-03) ---------- */

test('clockSample: RTT und Versatz', { skip: skipUnless('06.5-03', 'clockSample') }, () => {
  const f = load(['clockSample']);
  assert.deepEqual(f.clockSample(1000, 1200, 5000), {rtt: 200, offset: 3900});
});

test('pickOffset: Probe mit kleinster RTT unter 1500 ms, gerundet', { skip: skipUnless('06.5-03', 'pickOffset') }, () => {
  const f = load(['pickOffset']);
  assert.equal(f.pickOffset([{rtt: 800, offset: 10}, {rtt: 120, offset: -2400.4}, {rtt: 2000, offset: 99}]), -2400);
  assert.equal(f.pickOffset([{rtt: 1600, offset: 5}]), null);
  assert.equal(f.pickOffset([]), null);
});

test('clockHint: Schwelle 5 s, Richtung, Einheit s/min', { skip: skipUnless('06.5-03', 'clockHint') }, () => {
  const f = load(['clockHint']);
  assert.equal(f.clockHint(4000), '');
  assert.equal(f.clockHint(-5000), '');
  assert.equal(f.clockHint(-12000), 'Geräteuhr geht 12 s vor — wird herausgerechnet');
  assert.equal(f.clockHint(30400), 'Geräteuhr geht 30 s nach — wird herausgerechnet');
  assert.equal(f.clockHint(-119000), 'Geräteuhr geht 119 s vor — wird herausgerechnet');
  assert.equal(f.clockHint(-120000), 'Geräteuhr geht 2 min vor — wird herausgerechnet');
  assert.equal(f.clockHint(-180000), 'Geräteuhr geht 3 min vor — wird herausgerechnet');
});
