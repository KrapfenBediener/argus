/* Syntax-Gate: extrahiert die Inline-Scripts aller App-Seiten (Feld, Leitung,
 * Lage) und prüft sie mit `node --check`. Fängt die Fehlerklasse „ASCII-Quote
 * bricht String" (siehe v0.33.0-Entwicklung), bevor sie deployt wird. */
import { readFileSync, readdirSync, writeFileSync, mkdtempSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

function inlineScript(html){
  const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;
  let m, out = [];
  while ((m = re.exec(html))) out.push(m[1]);
  return out.join('\n;\n');
}

const pages = ['index.html', 'sw.js'];
for (const f of readdirSync(join(ROOT, 'docs'))){
  if (/^(leitung|lage)-[0-9a-f]+\.html$/.test(f)) pages.push('docs/' + f);
}

const tmp = mkdtempSync(join(tmpdir(), 'argus-syntax-'));
let failed = false;
for (const page of pages){
  const src = readFileSync(join(ROOT, page), 'utf8');
  const js = page.endsWith('.js') ? src : inlineScript(src);
  const out = join(tmp, basename(page).replace(/[^A-Za-z0-9._-]/g, '_') + '.js');
  writeFileSync(out, js);
  const r = spawnSync(process.execPath, ['--check', out], { encoding: 'utf8' });
  if (r.status === 0){
    console.log('OK   ' + page + ' (' + js.length + ' bytes JS)');
  } else {
    failed = true;
    console.error('FAIL ' + page + '\n' + (r.stderr || r.stdout));
  }
}
process.exit(failed ? 1 : 0);
