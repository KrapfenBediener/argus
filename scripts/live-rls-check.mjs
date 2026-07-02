/* Live-RLS-Probe: verifiziert gegen das ECHTE Backend, dass die anon-Rolle
 * (nur apikey, kein JWT) auf sensiblen Tabellen NICHTS lesen kann.
 * Read-only, erzeugt keine Daten. Verhalten:
 *   - Netz/Backend nicht erreichbar → SKIP (Exit 0, CI nicht flaky machen)
 *   - Tabelle liefert Daten        → FAIL (Exit 1) — RLS-Loch!
 * Traceability: Phase-4-Vorfall (offene anon_read-Policy machte alle Codes lesbar). */
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const cfg = readFileSync(join(ROOT, 'config.js'), 'utf8');
const url = (cfg.match(/url:\s*'([^']+)'/) || [])[1];
const key = (cfg.match(/anonKey:\s*'([^']+)'/) || [])[1];

if (!url || !key){ console.error('config.js: url/anonKey nicht gefunden'); process.exit(1); }

const TABLES = [
  ['patients',      'id'],
  ['ccps',          'id'],
  ['checklists',    'id'],
  ['access_tokens', 'short_code'],   // Codes: das Kronjuwel
  ['audit_log',     'id'],           // personenscharfes Audit: master-only
  ['governance_log','id'],
  ['purge_log',     'id']
];

let failed = false;
for (const [table, col] of TABLES){
  let resp, body;
  try {
    resp = await fetch(`${url}/rest/v1/${table}?select=${col}&limit=1`, {
      headers: { apikey: key, Authorization: 'Bearer ' + key },
      signal: AbortSignal.timeout(15000)
    });
    body = await resp.text();
  } catch (e) {
    console.log(`SKIP ${table} — Netz/Backend nicht erreichbar (${e.name || e})`);
    continue;
  }
  let rows = null;
  try { rows = JSON.parse(body); } catch {}
  if (Array.isArray(rows) && rows.length === 0){
    console.log(`OK   ${table} — anon liest 0 Zeilen`);
  } else if (Array.isArray(rows)){
    failed = true;
    console.error(`FAIL ${table} — anon liest ${rows.length} Zeile(n)! RLS-Loch!`);
  } else {
    console.log(`WARN ${table} — HTTP ${resp.status}, unerwartete Antwort (kein Daten-Leak): ${body.slice(0, 120)}`);
  }
}
process.exit(failed ? 1 : 0);
