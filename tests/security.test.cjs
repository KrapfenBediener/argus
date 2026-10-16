/* Security-Regressions-Gates: kodieren behobene Vorfälle als Dauerprüfung.
 * Traceability: Foto-innerHTML ← Stored-XSS v0.32.2 · native Dialoge ← CLAUDE.md
 * (iOS-PWA deaktiviert alert/confirm/prompt) · D-06 ← Leitungs-/Lage-Namensschutz
 * · Secrets ← Repo ist öffentlich erreichbar (Pages). */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { ROOT, readFileText, extractInlineScript } = require('./_extract.cjs');

function trackedFiles(){
  return execFileSync('git', ['ls-files'], { cwd: ROOT, encoding: 'utf8' })
    .split('\n').filter(Boolean);
}

function stripComments(js){
  return js
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/([^:'"\\])\/\/[^\n]*/g, '$1');
}

const APP_PAGES = () => {
  const pages = ['index.html'];
  for (const f of fs.readdirSync(path.join(ROOT, 'docs'))){
    if (/^(leitung|lage)-[0-9a-f]+\.html$/.test(f)) pages.push('docs/' + f);
  }
  return pages;
};

test('Keine nativen alert/confirm/prompt (iOS-PWA-Regel, CLAUDE.md)', () => {
  for (const page of APP_PAGES()){
    const js = stripComments(extractInlineScript(readFileText(page)));
    const m = js.match(/(^|[^.\w])(alert|confirm|prompt)\s*\(/);
    assert.ok(!m, page + ': nativer Dialog gefunden: „' + (m && m[0].trim()) + '" — confirmModal/promptModal nutzen');
  }
});

test('Foto-XSS-Regression: kein rohes photo/pzsrc in innerHTML-img (v0.32.2)', () => {
  for (const page of APP_PAGES()){
    const src = readFileText(page);
    const bad = src.match(/src="'\s*\+\s*(p\.photo|photo|pzsrc)\b/);
    assert.ok(!bad, page + ': ungeprüfter Foto-Wert in <img src> — safePhoto() + DOM-Aufbau nutzen');
  }
});

test('safePhoto wird in der Feld-App tatsächlich verwendet', () => {
  const src = readFileText('index.html');
  const uses = (src.match(/safePhoto\(/g) || []).length;
  assert.ok(uses >= 3, 'safePhoto()-Nutzung geschrumpft (' + uses + ' < 3) — Foto-Render-Stelle ungeschützt?');
});

test('D-06: konkrete Leitungs-/Lage-Dateinamen nur als die Dateien selbst', () => {
  const re = new RegExp('(leitung|lage)-[0-9a-f]{6,}');
  for (const f of trackedFiles()){
    if (/^docs\/(leitung|lage)-[0-9a-f]+\.html$/.test(f)) continue;   // die Seiten selbst
    const buf = fs.readFileSync(path.join(ROOT, f));
    if (buf.length > 2_000_000) continue;                              // Binär/riesig: skip
    const text = buf.toString('utf8');
    assert.ok(!re.test(text), 'D-06-LEAK in ' + f + ' — Dateiname gehört nicht in committete Texte');
  }
});

test('Keine Secrets im Repo (PAT / private key / service_role-JWT)', () => {
  const patRe = /sbp_[A-Za-z0-9]{20,}/;
  const keyRe = /-----BEGIN [A-Z ]*PRIVATE KEY-----/;
  const roleRe = /"role"\s*:\s*"service_role"/;
  for (const f of trackedFiles()){
    const buf = fs.readFileSync(path.join(ROOT, f));
    if (buf.length > 2_000_000) continue;
    const text = buf.toString('utf8');
    assert.ok(!patRe.test(text), 'Supabase-PAT in ' + f);
    assert.ok(!keyRe.test(text), 'Private Key in ' + f);
    assert.ok(!roleRe.test(text), 'service_role-Credential in ' + f);
  }
});

test('Migrationen: jede SECURITY-DEFINER-Tabellenfunktion neueren Datums setzt search_path', () => {
  /* Bestandsaufnahme 2026-06-28: 9 Claim-Reader (0001/0005/0007/0013) ohne
   * search_path sind bekannt+dokumentiert (Low; Härtung geplant). Dieses Gate
   * friert den Zustand ein: KEINE NEUE Definer-Funktion ohne search_path. */
  const KNOWN = new Set(['argus_praesidium_id', 'argus_is_master', 'argus_is_observer',
    'argus_observer_praesidium_id', 'argus_is_admin', 'argus_admin_praesidium_id']);
  const dir = path.join(ROOT, 'supabase/migrations');
  for (const f of fs.readdirSync(dir).filter(x => x.endsWith('.sql')).sort()){
    const sql = fs.readFileSync(path.join(dir, f), 'utf8');
    const re = /create or replace function\s+([a-z0-9_.]+)\s*\(/gi;
    let m;
    while ((m = re.exec(sql))){
      const name = m[1].replace(/^public\./, '');
      const next = sql.indexOf('create or replace function', m.index + 10);
      const body = sql.slice(m.index, next === -1 ? sql.length : next);
      if (!/security\s+definer/i.test(body)) continue;
      if (KNOWN.has(name)) continue;
      assert.ok(/set\s+search_path/i.test(body),
        f + ': SECURITY DEFINER ohne set search_path: ' + name);
    }
  }
});

/* ---------- Phase 6.5: Gates für Migrationen ab 0025 (Plan 06.5-00) ---------- */

function migrationsFrom(n){
  const dir = path.join(ROOT, 'supabase/migrations');
  return fs.readdirSync(dir).filter(x => x.endsWith('.sql')).sort()
    .filter(x => parseInt(x.slice(0, 4), 10) >= n)
    .map(x => ({ file: x, sql: fs.readFileSync(path.join(dir, x), 'utf8') }));
}
function stripSqlComments(sql){
  return sql.replace(/\/\*[\s\S]*?\*\//g, '').replace(/--[^\n]*/g, '');
}

test('Migrationen ab 0025: JEDE Funktion setzt search_path (auch Trigger-Funktionen)', () => {
  /* Vakuum-wahr, solange keine Migration >= 0025 existiert. */
  for (const { file, sql } of migrationsFrom(25)){
    const clean = stripSqlComments(sql);
    const re = /create\s+(?:or\s+replace\s+)?function\s+([a-z0-9_."]+)\s*\(/gi;
    let m;
    while ((m = re.exec(clean))){
      const next = clean.slice(m.index + 10).search(/create\s+(?:or\s+replace\s+)?function\s/i);
      const body = clean.slice(m.index, next === -1 ? clean.length : m.index + 10 + next);
      assert.ok(/set\s+search_path/i.test(body), file + ': Funktion ohne set search_path: ' + m[1]);
    }
  }
});

test('Migrationen ab 0025: Patienten-Policies unverändert, kein Schreib-Grant auf ccp_devices (D6.5-13, Pitfall 1)', () => {
  /* argus_patients_write ist FOR ALL: eine Erweiterung würde auch SELECT öffnen.
   * Nachfrist läuft deshalb über die SECURITY-DEFINER-RPC argus_late_push. */
  for (const { file, sql } of migrationsFrom(25)){
    const clean = stripSqlComments(sql);
    assert.ok(!/(create|alter|drop)\s+policy\b[^;]*argus_patients_/i.test(clean),
      file + ': ändert eine argus_patients_*-Policy (D6.5-13)');
    assert.ok(!/grant\s+(insert|update|delete|all)\b[^;]*\bccp_devices\b[^;]*\bto\b[^;]*\banon\b/i.test(clean),
      file + ': Schreib-Grant auf ccp_devices an anon — Schreiben nur über RPCs');
  }
});

test('Jüngste argus_run_purge-Fassung ist vollständig (Pitfall 3)', (t) => {
  /* 0016 baute auf 0004 statt 0006 auf und verlor den Token-Hygiene-Schritt.
   * Jede neue Fassung muss ALLE Schritte der Vorgänger enthalten. */
  const dir = path.join(ROOT, 'supabase/migrations');
  let latest = null;
  for (const f of fs.readdirSync(dir).filter(x => x.endsWith('.sql')).sort()){
    const sql = fs.readFileSync(path.join(dir, f), 'utf8');
    const m = /create\s+or\s+replace\s+function\s+public\.argus_run_purge\s*\(/i.exec(sql);
    if (m) latest = { file: f, n: parseInt(f.slice(0, 4), 10), sql, idx: m.index };
  }
  if (!latest || latest.n < 26){
    return t.skip('aktiv ab Migration 0026 (Plan 06.5-02)');
  }
  const rest = latest.sql.slice(latest.idx + 10);
  const next = rest.search(/create\s+(?:or\s+replace\s+)?function\s/i);
  const body = stripSqlComments(next === -1 ? latest.sql.slice(latest.idx) : latest.sql.slice(latest.idx, latest.idx + 10 + next));
  for (const kw of ['single_use', 'audit_log', 'governance_log', 'ccp_devices', 'photo_purge_after']){
    assert.ok(body.includes(kw), latest.file + ': argus_run_purge ohne Schritt "' + kw + '"');
  }
});
