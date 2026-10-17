/* Test-Vertrag Phase 6.5 (Gerätestatus & Sync-Fundament) — reine Funktionen aus index.html.
 * Traceability: D6.5-05 Feldweiser Merge · D6.5-06 Änderungsgruppen (FGROUPS) ·
 * D6.5-07 Uhrversatz · D6.5-12 Gerätestatus/Abschluss · D6.5-14 lokale Fristen
 * ← Plan 06.5-03 (Sync-Kern), 06.5-04 (Grabstein), 06.5-05 (Gerätestatus),
 *   06.5-06 (Abschluss/Fristen).
 * Die Tests stehen VOR der Implementierung (Wave 0): fehlt eine Vertragsfunktion,
 * wird der Test mit Begründung übersprungen (nicht rot). Sobald die Funktion
 * existiert, ist der Test scharf — Plan 08 verlangt 0 Skips beim Release.
 * Vertrag: Hilfsfunktionen liegen INNERHALB der Vertragsfunktion (oder werden hier
 * ausdrücklich in die Namensliste von evalFunctions aufgenommen) — extrahiert wird
 * nur, was die Tests benennen. */
'use strict';
const fs = require('fs');
const path = require('path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { app, hasFunction, evalFunctions, extractFunction, ROOT } = require('./_extract.cjs');

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
    const f = load(['groupSig', 'mergeGroups'], true);
    const res = f.mergeGroups(toClient(v.new), toClient(v.old), f.FGROUPS);
    Object.keys(v.expect).forEach(function(path){
      const segs = path.split('.');
      segs[0] = S2C[segs[0]] || segs[0];
      assert.deepEqual(getPath(res, segs.join('.')), v.expect[path], v.id + ': ' + path);
    });
  });
});

test('mergeGroups: Eingabe-Objekte bleiben unverändert (reine Funktion)', { skip: skipUnless('06.5-03', 'FGROUPS', 'groupSig', 'mergeGroups') }, () => {
  const f = load(['groupSig', 'mergeGroups'], true);
  const v = vectors[0];
  const L = toClient(v.new), C = toClient(v.old);
  const l0 = JSON.stringify(L), c0 = JSON.stringify(C);
  f.mergeGroups(L, C, f.FGROUPS);
  assert.equal(JSON.stringify(L), l0);
  assert.equal(JSON.stringify(C), c0);
});

/* jüngste vorhandene Probe: 0027 (Grabstein behält Inhalt, D6.5-19), sonst 0025 */
const PROBE_REL = ['supabase/probes/0027_sync_probe.sql', 'supabase/probes/0025_sync_probe.sql']
  .find(function(rel){ return fs.existsSync(path.join(ROOT, rel)); });

test('Probe-Konsistenz: jede Vektor-ID kommt in der jüngsten SQL-Probe vor, die Vektoren sind eingebettet', {
  skip: !PROBE_REL && 'kommt mit Plan 06.5-01'
}, () => {
  const sql = fs.readFileSync(path.join(ROOT, PROBE_REL), 'utf8');
  vectors.forEach(function(v){
    assert.ok(sql.includes(v.id), 'SQL-Probe ' + PROBE_REL + ' kennt ' + v.id + ' nicht (Vektoren 1:1 einbetten)');
  });
});

const MIG27 = 'supabase/migrations/0027_grabstein_behaelt_inhalt.sql';

test('Migration 0027: Merge-Funktion ohne Grabstein-Hülle, mit search_path, argus_server_time v:27', {
  skip: !fs.existsSync(path.join(ROOT, MIG27)) && 'kommt mit Plan 06.5-09'
}, () => {
  const sql = fs.readFileSync(path.join(ROOT, MIG27), 'utf8');
  assert.ok(sql.includes('create or replace function public.argus_patients_merge()'));
  assert.ok(/set search_path to 'public'/.test(sql), 'search_path fehlt');
  assert.ok(!/v_hull|jsonb_populate_record\(NEW, v_hull\)/.test(sql), 'Grabstein-Hülle darf nicht mehr vorkommen');
  assert.ok(!/NEW\.photo\s*:=\s*null/.test(sql), 'Grabstein darf das Foto nicht leeren');
  assert.ok(/'v',\s+27/.test(sql), "argus_server_time muss v:27 liefern");
  assert.ok(!/alter table|create policy|drop policy/i.test(sql), 'keine Schema-/RLS-Änderung');
});

const MIG28 = 'supabase/migrations/0028_nummer_reservierung_je_geraet.sql';
const PROBE28 = 'supabase/probes/0028_nummer_probe.sql';

test('Migration 0028: idempotente Nummern-Reservierung (D6.5-21), search_path, Row-Lock, v:28, keine RLS-Änderung', () => {
  const sql = fs.readFileSync(path.join(ROOT, MIG28), 'utf8');
  const code = sql.replace(/--[^\n]*/g, '');
  assert.ok(code.includes('create or replace function public.argus_reserve_num('));
  assert.ok(/security definer/i.test(code) && /set search_path to 'public'/.test(code), 'search_path/definer fehlt');
  assert.ok(/for update/i.test(code), 'Row-Lock (for update) fehlt');
  assert.ok(/add column if not exists reserved_num int/i.test(code), 'Spalte reserved_num fehlt');
  assert.ok(/grant execute on function public\.argus_reserve_num\(uuid, int\) to anon/.test(code));
  assert.ok(/'reused',\s*true/.test(code) && /'reused',\s*false/.test(code), 'reused-Kennzeichen fehlt');
  assert.ok(/first_seen, last_seen/.test(code), 'Gerätezeile braucht first_seen/last_seen (NOT NULL)');
  assert.ok(/'v',\s+28/.test(code), 'argus_server_time muss v:28 liefern');
  assert.ok(!/create policy|drop policy|grant\s+(insert|update|delete|all)/i.test(code), 'keine RLS-/Schreib-Grant-Änderung');
  assert.ok(!/create or replace function public\.argus_claim_nums/.test(code), 'argus_claim_nums bleibt unverändert');
});

test('Probe 0028 deckt R1-R8 ab und rollt sich selbst zurück', () => {
  const sql = fs.readFileSync(path.join(ROOT, PROBE28), 'utf8');
  assert.ok(sql.includes('PROBE 0028 ERGEBNIS'));
  ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8'].forEach(function(r){
    assert.ok(sql.includes('-- ── ' + r + ':'), 'Prüfung ' + r + ' fehlt');
  });
  assert.ok(/raise exception 'PROBE 0028 ERGEBNIS/.test(sql));
});

test('Probe 0027 bettet merge-vectors.json 1:1 ein', {
  skip: !fs.existsSync(path.join(ROOT, 'supabase/probes/0027_sync_probe.sql')) && 'kommt mit Plan 06.5-09'
}, () => {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase/probes/0027_sync_probe.sql'), 'utf8');
  const raw = fs.readFileSync(path.join(ROOT, 'tests/fixtures/merge-vectors.json'), 'utf8').trim();
  assert.ok(sql.includes(raw), 'Vektoren in der Probe weichen von tests/fixtures/merge-vectors.json ab');
  assert.ok(sql.includes('PROBE 0027 ERGEBNIS'));
});

/* ---------- Grabstein (Plan 06.5-04) ---------- */

test('tombstoneMark setzt nur deleted_*, Inhalt/Foto/TQ/Status bleiben (D6.5-19)', { skip: skipUnless('06.5-09', 'tombstoneMark') }, () => {
  const f = load(['tombstoneMark']);
  const p = Object.assign(samplePatient(), {
    id: 'p7', num: 7, ccp: 'A', created: 111, by: 'MUE', ccpId: 'c1',
    name: 'Testname', photo: 'data:image/png;base64,AAAA', tqStart: 5, tqSite: 'Arm', prio: true, ready: true,
    notes: 'x', inj: ['a'], tx: {tq: true}, fts: {cat: {t: 9, d: 1}}
  });
  p.vit.hf = '80';
  const before = JSON.parse(JSON.stringify(p));
  const r = f.tombstoneMark(p, 'KLA', 3, 4242);
  assert.equal(r, p);
  assert.equal(r.deletedAt, 4242);
  assert.equal(r.deletedBy, 'KLA');
  assert.equal(r.deletedDev, 3);
  assert.equal(r.tqStart, 5);
  assert.equal(r.tqSite, 'Arm');
  assert.equal(r.photo, 'data:image/png;base64,AAAA');
  assert.equal(r.name, 'Testname');
  assert.equal(r.vit.hf, '80');
  assert.equal(r.prio, true);
  assert.equal(r.ready, true);
  assert.equal(r.status, before.status);
  // alles außer deleted_* unverändert
  ['deletedAt', 'deletedBy', 'deletedDev'].forEach(function(k){ delete r[k]; delete before[k]; });
  assert.deepEqual(r, before);
});

test('restoreTombstone: stellt alles wieder her, nur del-Stempel (D6.5-19)', { skip: skipUnless('06.5-09', 'tombstoneMark', 'restoreTombstone', 'stampGroups') }, () => {
  const f = load(['tombstoneMark', 'restoreTombstone', 'stampGroups']);
  const p = Object.assign(samplePatient(), {name: 'Testname', photo: 'data:image/png;base64,AAAA', tqStart: 5, tqSite: 'Arm', prio: true, notes: 'x'});
  f.tombstoneMark(p, 'KLA', 3, 100);
  f.stampGroups(p, ['del'], 100, 3);
  const st0 = p.status;
  f.restoreTombstone(p, 200, 4);
  assert.equal(p.status, st0);
  assert.equal(p.deletedAt, null);
  assert.equal(p.deletedBy, '');
  assert.equal(p.deletedDev, null);
  assert.equal(p.name, 'Testname');
  assert.equal(p.photo, 'data:image/png;base64,AAAA');
  assert.equal(p.tqStart, 5);
  assert.equal(p.tqSite, 'Arm');
  assert.equal(p.prio, true);
  assert.equal(p.notes, 'x');
  assert.equal(p.cat, 'T2');
  assert.deepEqual(p.fts.del, {t: 200, d: 4, b: 0, p: 1});   // erster del-Stempel noch unbestätigt → Basis bleibt 0
  assert.equal(p.fts.st, undefined, 'st wird nur beim Alt-Grabstein mitgestempelt');
});

test('restoreTombstone: Alt-Grabstein (status verworfen) wird active, st mitgestempelt', { skip: skipUnless('06.5-09', 'restoreTombstone', 'stampGroups') }, () => {
  const f = load(['restoreTombstone', 'stampGroups']);
  const p = Object.assign(samplePatient(), {status: 'verworfen', name: '', deletedAt: 100, deletedBy: 'KLA', deletedDev: 3, fts: {del: {t: 100, d: 3}}});
  f.restoreTombstone(p, 200, 4);
  assert.equal(p.status, 'active');
  assert.equal(p.deletedAt, null);
  assert.deepEqual(p.fts.del, {t: 200, d: 4, b: 100, p: 1});
  assert.deepEqual(p.fts.st, {t: 200, d: 4, b: 0, p: 1});
});

/* ---------- Konflikt-Hinweis (Plan 06.5-04) ---------- */

test('conflictText: Gruppe, Geräte und Zeiten; unbekannte Gruppe; fehlendes Gerät', { skip: skipUnless('06.5-04', 'conflictText') }, () => {
  const f = load(['conflictText']);
  const hh = function(){ return '14:31'; };
  assert.equal(
    f.conflictText({g: 'vit', at: 0, win: {t: 2, d: 5}, lose: {t: 1, d: 2}}, hh),
    'Vitalwerte: Stand von Gerät 2 (14:31) wurde durch Gerät 5 (14:31) ersetzt');
  assert.ok(f.conflictText({g: 'xyz', win: {t: 2, d: 5}, lose: {t: 1, d: 2}}, hh).startsWith('xyz: '));
  assert.equal(
    f.conflictText({g: 'foto', win: {t: 2, d: null}, lose: {t: 1}}, hh),
    'Foto: Stand von Gerät ? (14:31) wurde durch Gerät ? (14:31) ersetzt');
});

test('mergeGroups: lokale Quittung (fts.ack) gewinnt und räumt Konflikt-Marker ab', { skip: skipUnless('06.5-04', 'FGROUPS', 'groupSig', 'mergeGroups') }, () => {
  const f = load(['groupSig', 'mergeGroups'], true);
  const cloud = {updated: 500, fts: {vit: {t: 400, d: 2}}, conf: [{g: 'vit', at: 450}, {g: 'st', at: 900}]};
  const local = {updated: 450, fts: {ack: {t: 600}}};
  const m = f.mergeGroups(local, cloud, f.FGROUPS);
  assert.deepEqual(m.fts.ack, {t: 600});
  assert.deepEqual(m.conf, [{g: 'st', at: 900}]);
  const cloud2 = {updated: 500, fts: {vit: {t: 400, d: 2}, ack: {t: 200}}, conf: [{g: 'vit', at: 450}, {g: 'st', at: 900}]};
  const m2 = f.mergeGroups({updated: 450, fts: {ack: {t: 100}}}, cloud2, f.FGROUPS);   // ältere Quittung: Server bleibt
  assert.deepEqual(m2.fts.ack, {t: 200});
  assert.equal(m2.conf.length, 2);
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

/* ---------- Gerätestatus (Plan 06.5-05) ---------- */

const NOW = 1000000;
const HHMM = function(){ return '14:20'; };   // Stub: keine Zeitzonenabhängigkeit

test('devStatus: Grenzen verbunden (< 30 s) / außer Reichweite / abgemeldet / verlassen', { skip: skipUnless('06.5-05', 'devStatus') }, () => {
  const f = load(['devStatus']);
  assert.equal(f.devStatus({last_seen: NOW - 29000}, NOW), 'verbunden');
  assert.equal(f.devStatus({last_seen: NOW - 30000}, NOW), 'ausser_reichweite');
  assert.equal(f.devStatus({last_seen: NOW - 31000}, NOW), 'ausser_reichweite');
  assert.equal(f.devStatus({last_seen: NOW - 1000, left_at: NOW - 500}, NOW), 'verlassen');   // verlassen schlägt frisch
  assert.equal(f.devStatus({last_seen: NOW - 31000, lost_at: NOW - 20000}, NOW), 'abgemeldet');
  assert.equal(f.devStatus({last_seen: NOW - 10000, lost_at: NOW - 20000}, NOW), 'verbunden'); // Gerät meldet sich wieder
});

test('devLabel: Gerätezeile nach ROADMAP-Beispiel (Stern, außer Reichweite, verlassen, abgemeldet, Verbund)', { skip: skipUnless('06.5-05', 'devStatus', 'devLabel') }, () => {
  const f = load(['devStatus', 'devLabel']);
  const o = {mm: 'MUE', merged: false, hhmm: HHMM};
  const l1 = f.devLabel({device_no: 1, operator: 'MUE', last_seen: NOW - 1000, open_n: 0}, NOW, o);
  const l4 = f.devLabel({device_no: 4, operator: '', last_seen: NOW - 185000, open_n: 1}, NOW, o);
  const l5 = f.devLabel({device_no: 5, operator: '', last_seen: NOW - 1000, left_at: NOW - 500, open_n: 0}, NOW, o);
  assert.equal(l1, '1 ★ MUE');
  assert.equal(l4, '4 — außer Reichweite seit 3 min (1 Patient offen)');
  assert.equal(l5, '5 — verlassen 14:20');
  assert.equal([l1, l4, l5].join(' · '), '1 ★ MUE · 4 — außer Reichweite seit 3 min (1 Patient offen) · 5 — verlassen 14:20');
  assert.equal(f.devLabel({device_no: 6, operator: 'KLA', last_seen: NOW - 100000, lost_at: NOW - 60000, open_n: 2}, NOW, o),
    '6 KLA — abgemeldet (2 Patienten möglicherweise verloren)');
  assert.equal(f.devLabel({device_no: 3, kennung: 'B', operator: '', last_seen: NOW - 1000, open_n: 0}, NOW,
    {mm: 'MUE', merged: true, hhmm: HHMM}), 'B·3');
  assert.equal(f.devLabel({device_no: 7, operator: '', last_seen: NOW - 100000, open_n: 2}, NOW, o),
    '7 — außer Reichweite seit 1 min (2 Patienten offen)');
});

test('devLabel: eigenes Gerät trägt „(dieses Gerät)“ (nach MasterMedic-Übernahme erkennbar)', { skip: skipUnless('06.5-10', 'devStatus', 'devLabel') }, () => {
  const f = load(['devStatus', 'devLabel']);
  const d = {device_no: 2, operator: 'MUE', last_seen: NOW - 1000, open_n: 0};
  assert.equal(f.devLabel(d, NOW, {mm: 'MUE', hhmm: HHMM, self: true}), '2 ★ MUE (dieses Gerät)');
  assert.equal(f.devLabel(d, NOW, {mm: 'MUE', hhmm: HHMM}), '2 ★ MUE');
  assert.equal(f.devLabel(Object.assign({}, d, {last_seen: NOW - 100000}), NOW, {mm: 'MUE', hhmm: HHMM, self: true}),
    '2 ★ MUE (dieses Gerät) — außer Reichweite seit 1 min');
});

test('devStale: Gerätestand ab 30 s oder ohne Verbindung unbekannt (B6)', { skip: skipUnless('06.5-10', 'devStale') }, () => {
  const f = load(['devStale']);
  assert.equal(f.devStale(NOW - 29000, NOW, true), false);
  assert.equal(f.devStale(NOW - 30000, NOW, true), false);
  assert.equal(f.devStale(NOW - 31000, NOW, true), true);
  assert.equal(f.devStale(NOW - 1000, NOW, false), true);   // offline: auch ein frischer Stand gilt als unbekannt
  assert.equal(f.devStale(0, NOW, true), true);             // nie geladen
});

test('deviceHeartbeat: MasterToken-Geräte melden sich (kein _isMaster-Abbruch); devicesCard kennt „Gerätestand unbekannt“', () => {
  const hb = extractFunction(script, 'deviceHeartbeat');
  assert.ok(!/_isMaster/.test(hb), 'deviceHeartbeat darf MasterToken-Geräte nicht ausschließen');
  assert.ok(/_schemaV\s*<\s*26/.test(hb), 'Geräte-RPCs bleiben hinter Schema >= 26');
  const card = extractFunction(script, 'devicesCard');
  assert.ok(card.indexOf('Gerätestand unbekannt (keine Verbindung)') >= 0);
  assert.ok(/devStale\(/.test(card));
});

/* ---------- Verbindungs-Härtung (Plan 06.5-10, B3–B7) ---------- */

test('loadPatients: nie zwei Läufe gleichzeitig; Wartende teilen genau einen Folgelauf (B4)', async () => {
  const body = 'var _lpRun=null,_lpNext=null; var running=0, maxRunning=0, starts=0;\n' +
    'async function _loadPatientsRun(){ starts++; running++; maxRunning=Math.max(maxRunning,running); await new Promise(function(r){ setTimeout(r,20); }); running--; }\n' +
    extractFunction(script, 'loadPatients') + '\n' + extractFunction(script, '_lpStart') + '\n' +
    'return {loadPatients:loadPatients, stats:function(){ return {starts:starts,maxRunning:maxRunning,running:running}; }};';
  const m = new Function(body)();
  await Promise.all([m.loadPatients(), m.loadPatients(), m.loadPatients(), m.loadPatients()]);
  assert.equal(m.stats().maxRunning, 1, 'zwei Läufe überlappten');
  assert.equal(m.stats().starts, 2, 'erster Lauf + ein gemeinsamer Folgelauf');
  await m.loadPatients();
  assert.equal(m.stats().starts, 3);
  assert.equal(m.stats().running, 0);
});

test('Verbindungs-Härtung: CCP-Guard, Flush-Prüfung, Start-Timeouts, Schema-Re-Probe (B3–B7)', () => {
  const run = extractFunction(script, '_loadPatientsRun');
  assert.ok(/var ccpAt\s*=\s*_ccpId/.test(run) && /_ccpId\s*!==\s*ccpAt/.test(run), 'B5: _loadPatientsRun merkt sich den CCP zu Beginn und vergleicht');
  assert.ok(!/localStorage\.setItem\('argus_ccp_ids_'\+_ccpId/.test(run), 'B5: argus_ccp_ids_ nur für den gemerkten CCP');
  const fl = extractFunction(script, 'flushPendingPatients');
  assert.ok((fl.match(/localNewerThan\(/g) || []).length >= 3, 'B4: jeder Rückschreibpfad prüft auf neuere lokale Bearbeitung');
  fl.split('delete lp._dirty').slice(0, -1).forEach(function(part){
    assert.ok(part.lastIndexOf('localNewerThan(') > part.lastIndexOf('upsert('), 'B4: vor delete lp._dirty muss die Prüfung nach dem Upsert stehen');
  });
  assert.ok(/qt\(client\.from\('patients'\)\.upsert\(/.test(fl), 'B3: Uploads mit Zeitlimit');
  assert.ok(/qt\(c\.from\('ccps'\)/.test(extractFunction(script, 'loadOpenCcpCount')), 'B3: loadOpenCcpCount mit qt');
  assert.ok(/qt\(client\.from\('ccps'\)/.test(extractFunction(script, 'checkClosedEinsatz')), 'B3: checkClosedEinsatz mit qt');
  assert.ok(/qt\(client\.rpc\('argus_close_einsatz'/.test(extractFunction(script, 'flushPendingClose')), 'B3: flushPendingClose mit qt');
  assert.ok(/qt\(client\.rpc\('argus_claim_device'/.test(extractFunction(script, 'ensureDeviceNo')), 'B3: Geräte-Claim mit qt');
  assert.ok(/qt\(client\.rpc\('argus_late_push'/.test(extractFunction(script, 'flushLatePatients')), 'B3: Nachzügler-RPC mit qt');
  assert.ok(/setInterval\(function\(\)\{[^]*?_schemaV<29[^]*?probeSchema\(1\)[^]*?\},\s*180000\)/.test(script), 'B7: Schema-Re-Probe alle 3 min bis v>=29 (0029)');
});

test('leaveText: Dialogtext mit Gerätenummer, offenen Patienten und MasterMedic-Hinweis', { skip: skipUnless('06.5-05', 'leaveText') }, () => {
  const f = load(['leaveText']);
  assert.equal(f.leaveText('A', 3, 2, false), 'CCP A verlassen?\n\nDu bist Gerät 3 · 2 Patienten noch nicht synchronisiert');
  assert.ok(f.leaveText('A', 3, 1, false).endsWith('· 1 Patient noch nicht synchronisiert'));
  assert.equal(f.leaveText('B', 2, 0, false), 'CCP B verlassen?\n\nDu bist Gerät 2 · alles synchronisiert');
  assert.equal(f.leaveText('A', 0, 0, false), 'CCP A verlassen?\n\nAlles synchronisiert');
  assert.equal(f.leaveText('A', 1, 0, true),
    'CCP A verlassen?\n\nDu bist Gerät 1 · alles synchronisiert\n\nDu bist MasterMedic — die Rolle bleibt bei dir, bis jemand sie übernimmt.');
});

/* ---------- Abschluss-Vollständigkeit + Fristen (Plan 06.5-06) ---------- */

function fiveDevices(){
  return [
    {device_no: 1, kennung: 'A', last_seen: NOW - 500000, open_n: 5},   // eigenes Gerät: own überschreibt
    {device_no: 2, kennung: 'A', last_seen: NOW - 1000, open_n: 0},
    {device_no: 3, kennung: 'B', last_seen: NOW - 100000, open_n: 2},   // außer Reichweite
    {device_no: 4, kennung: 'A', last_seen: NOW - 5000, left_at: NOW - 4000, open_n: 0},   // verlassen
    {device_no: 5, kennung: 'A', last_seen: NOW - 2000, open_n: 0}
  ];
}

test('closeCompleteness: Zählung, Problemtext, eigenes Gerät, Verbund-Label, unbekannter Stand', { skip: skipUnless('06.5-06', 'devStatus', 'closeCompleteness') }, () => {
  const f = load(['devStatus', 'closeCompleteness']);
  assert.deepEqual(f.closeCompleteness(fiveDevices(), NOW, {dev: 1, dirty: 0}, false), {
    total: 5, ok: 4, text: '4 von 5 Geräten haben alles bestätigt — Gerät 3 außer Reichweite, 2 Patienten offen'
  });
  const allOk = fiveDevices(); allOk[2].last_seen = NOW - 1000; allOk[2].open_n = 0;
  assert.deepEqual(f.closeCompleteness(allOk, NOW, {dev: 1, dirty: 0}, false), {total: 5, ok: 5, text: ''});
  assert.equal(f.closeCompleteness(allOk, NOW, {dev: 1, dirty: 1}, false).text,
    '4 von 5 Geräten haben alles bestätigt — Gerät 1, 1 Patient offen');
  assert.equal(f.closeCompleteness(fiveDevices(), NOW, {dev: 1, dirty: 0}, true).text,
    '4 von 5 Geräten haben alles bestätigt — Gerät B·3 außer Reichweite, 2 Patienten offen');
  const lost = fiveDevices(); lost[1].last_seen = NOW - 100000; lost[1].lost_at = NOW - 60000; lost[1].open_n = 1;
  assert.equal(f.closeCompleteness(lost, NOW, {dev: 1, dirty: 0}, false).text,
    '3 von 5 Geräten haben alles bestätigt — Gerät 2 abgemeldet, 1 Patient offen; Gerät 3 außer Reichweite, 2 Patienten offen');
  assert.deepEqual(f.closeCompleteness(null, NOW, {dev: 1, dirty: 0}, false),
    {total: 0, ok: 0, text: 'Gerätestand unbekannt (keine Verbindung)'});
  assert.deepEqual(f.closeCompleteness([], NOW, {dev: 1, dirty: 0}, false),
    {total: 0, ok: 0, text: 'Gerätestand unbekannt (keine Verbindung)'});
});

test('nachfristOk: 24-h-Nachfrist, durch purge_after begrenzt', { skip: skipUnless('06.5-06', 'nachfristOk') }, () => {
  const f = load(['nachfristOk']);
  assert.equal(f.nachfristOk(1000, 1000 + 86340000, null), true);
  assert.equal(f.nachfristOk(1000, 1000 + 86400000, null), false);
  assert.equal(f.nachfristOk(1000, 1000 + 86460000, null), false);
  assert.equal(f.nachfristOk(1000, 1000 + 3600000, 1000 + 1800000), false);
  assert.equal(f.nachfristOk(null, 5, null), false);
});

test('localPurgeDecision: Matrix aus Abschluss-/Kontaktzeit, Foto und ausstehenden Änderungen', { skip: skipUnless('06.5-06', 'localPurgeDecision') }, () => {
  const f = load(['localPurgeDecision']);
  const H = 3600000, c = 1000000000, D = 24 * H;
  const d = function(ctx, dt){ return f.localPurgeDecision(ctx, c + dt); };
  const R = function(dropPhoto, dropRecord, dropLate){ return {dropPhoto, dropRecord, dropLate}; };
  // Einsatz abgeschlossen, alles synchronisiert
  assert.deepEqual(d({closedAt: c, dirty: false, hasPhoto: true}, 1 * H), R(false, true, false));
  assert.deepEqual(d({closedAt: c, dirty: false, hasPhoto: true}, 73 * H), R(true, true, false));
  // Einsatz abgeschlossen, Änderungen noch nicht hochgeladen (Nachzügler)
  assert.deepEqual(d({closedAt: c, dirty: true, hasPhoto: true}, 23 * H), R(false, false, false));
  assert.deepEqual(d({closedAt: c, dirty: true, hasPhoto: false}, 25 * H), R(false, false, true));
  assert.deepEqual(d({closedAt: c, dirty: true, hasPhoto: true}, 73 * H), R(true, false, true));
  // Einsatz nie abgeschlossen gemeldet: Frist ab letztem Serverkontakt
  assert.deepEqual(d({closedAt: null, dirty: false, hasPhoto: true, lastContact: c}, 71 * H), R(false, false, false));
  assert.deepEqual(d({closedAt: null, dirty: false, hasPhoto: true, lastContact: c}, 73 * H), R(false, true, false));
  assert.deepEqual(d({closedAt: null, dirty: true, hasPhoto: true, lastContact: c}, 59 * D), R(false, false, false));
  assert.deepEqual(d({closedAt: null, dirty: true, hasPhoto: true, lastContact: c}, 61 * D), R(false, false, true));
  // weder Abschluss noch Kontakt bekannt: nichts löschen
  assert.deepEqual(d({closedAt: null, dirty: true, hasPhoto: true, lastContact: null}, 1000 * D), R(false, false, false));
});

/* ---------- Phasen-Gate (Plan 06.5-08): keine Vertragsfunktion darf beim Release fehlen ---------- */

test('Phase 6.5: alle Vertragsfunktionen vorhanden (keine Skips beim Release)', () => {
  const FUNKTIONEN = ['groupSig', 'groupSigs', 'changedGroups', 'nextStamp', 'stampGroups', 'ftsForUpload',
    'clearPending', 'mergeGroups', 'clockSample', 'pickOffset', 'clockHint', 'tombstoneMark', 'restoreTombstone',
    'conflictText', 'devStatus', 'devLabel', 'devStale', 'leaveText', 'closeCompleteness', 'nachfristOk', 'localPurgeDecision',
    'funkText', 'funkSds', 'probeSchema', 'deviceHeartbeat', 'leaveCcpState', 'flushLatePatients', 'runLocalPurge',
    'flushHerkunft'];
  const fehlend = FUNKTIONEN.filter(function(n){ return !hasFunction(script, n); });
  if (!/var\s+FGROUPS\s*=/.test(script)) fehlend.push('FGROUPS');
  assert.deepEqual(fehlend, [], 'Vertragsfunktionen fehlen in index.html: ' + fehlend.join(', '));
});

/* ---------- Nummern-Reservierung je Gerät (Plan 06.5-11, D6.5-21) ---------- */

test('prefetchAllowed: Backoff und Hänger-Schutz (Grenzfälle)', () => {
  const f = load(['prefetchAllowed']);
  assert.equal(typeof f.prefetchAllowed, 'function');
  assert.equal(f.prefetchAllowed(1000, 0, 0), true, 'ohne Backoff und ohne laufenden Versuch erlaubt');
  assert.equal(f.prefetchAllowed(1000, 16000, 0), false, 'Backoff aktiv');
  assert.equal(f.prefetchAllowed(15999, 16000, 0), false, 'knapp vor Ablauf');
  assert.equal(f.prefetchAllowed(16000, 16000, 0), true, 'genau am Ablauf erlaubt');
  assert.equal(f.prefetchAllowed(20000, 16000, 0), true, 'nach Ablauf erlaubt');
  assert.equal(f.prefetchAllowed(1000, 0, 500), false, 'laufender Versuch (500 ms alt)');
  assert.equal(f.prefetchAllowed(6499, 0, 500), false, 'laufender Versuch knapp unter 6 s');
  assert.equal(f.prefetchAllowed(6500, 0, 500), true, 'laufender Versuch gilt nach 6 s als tot');
  assert.equal(f.prefetchAllowed(1000, 16000, 500), false, 'beides aktiv');
  assert.equal(f.prefetchAllowed(20000, 16000, 19000), false, 'Backoff vorbei, aber Versuch läuft');
});

test('prefetchNum: argus_reserve_num nur hinter _schemaV>=28 und bekannter Gerätenummer, sonst argus_claim_nums', () => {
  const src = extractFunction(script, 'prefetchNum');
  const iRes = src.indexOf("argus_reserve_num");
  assert.ok(iRes > 0, 'argus_reserve_num fehlt');
  assert.ok(/_schemaV\s*>=\s*28\s*&&\s*devAt\s*>=\s*1[^]*argus_reserve_num/.test(src), 'argus_reserve_num muss hinter _schemaV>=28 und Gerätenummer stehen');
  assert.ok(src.lastIndexOf("argus_claim_nums") > iRes, 'argus_claim_nums bleibt als Rückfall für Schema < 28');
  assert.ok(/prefetchAllowed\(/.test(src), 'Backoff-Entscheid muss genutzt werden');
  assert.ok(/PREFETCH_BACKOFF_MS/.test(src) && /var PREFETCH_BACKOFF_MS = 15000;/.test(script), '15-s-Backoff');
});

test('Reservierungs-Spiegel argus_resnum_<ccpId>: gespeichert, beim Anlegen gelöscht', () => {
  assert.ok(/argus_resnum_/.test(script));
  const add = extractFunction(script, 'addPatient');
  assert.ok(/resNumClear\(/.test(add), 'addPatient muss den Spiegel löschen');
  assert.ok(/_schemaV\s*<\s*28/.test(add) && /prefetchNum\(true\)/.test(add), 'ab Schema 28: nächste Nummer erst nach dem Upload');
});

/* ---------- 0.34.5: Nummern-Reservierung mit verbrauchter Nummer (Migration 0029) ---------- */
test('Migration 0029: argus_reserve_num mit p_used, search_path, Row-Lock, v:29', () => {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase/migrations/0029_nummer_reservierung_verbraucht.sql'), 'utf8');
  assert.ok(/create or replace function public\.argus_reserve_num\(p_ccp_id uuid, p_dev int, p_used int default null\)/.test(sql));
  assert.ok(/set search_path to 'public'/.test(sql));
  assert.ok(/for update/.test(sql));
  assert.ok(/p_used is null or p_used <> v_res/.test(sql), 'verbrauchte Reservierung wird nicht wiederverwendet');
  assert.ok(/'v',\s*29/.test(sql));
  assert.ok(!/create policy|alter policy|drop policy/i.test(sql), 'keine RLS-Änderung');
});
test('Client 0.34.5: Reservierung sofort mit verbrauchter Nummer, echter Neuversuch, kein Render bei offener Kamera', () => {
  assert.ok(/rargs\.p_used=used/.test(script), 'p_used wird ab Schema 29 gesendet');
  assert.ok(/function prefetchRetryLater\(/.test(script), 'Neuversuch per Timer');
  assert.ok(/prefetchNum\(true, \(typeof _usedNum!=='undefined'\)\?_usedNum:0\)/.test(script), 'addPatient lädt sofort nach');
  assert.ok(/a==="capnext"\)\{ state\.capPopup=false; try\{ prefetchNum\(true\); \}/.test(script), 'Schließen des Schnellmenüs lädt nach');
});
