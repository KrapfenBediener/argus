/* Test-Helfer: macht die Single-File-App (index.html) testbar, OHNE sie zu ändern.
 * Extrahiert Inline-Script, einzelne Funktionen und var-Literale per
 * String-Scanner (kennt Strings/Kommentare/Escapes) und wertet sie isoliert aus.
 * Zero-dependency — läuft mit node:test (Node >= 20). */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');

function readFileText(rel){ return fs.readFileSync(path.join(ROOT, rel), 'utf8'); }

/* Alle Inline-<script>-Blöcke (ohne src=) einer HTML-Datei zusammenkleben. */
function extractInlineScript(html){
  const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;
  let m, out = [];
  while ((m = re.exec(html))) out.push(m[1]);
  return out.join('\n;\n');
}

/* Scanner: findet das Ende eines balancierten Blocks ab openIdx (Zeichen '{' oder '[').
 * Überspringt '…', "…", `…`, //-Zeilen- und Block-Kommentare, Escapes. */
function balancedEnd(src, openIdx){
  let depth = 0, inStr = null, inLine = false, inBlock = false;
  let inRe = false, inReClass = false, prevSig = '';
  /* prevSig entscheidet Regex vs. Division: nach diesen Tokens beginnt ein
   * Regex-Literal, nicht eine Division. */
  const reAllowed = new Set(['(', ',', '=', ':', '[', '!', '&', '|', '?', '{', ';', '<', '>', '+', '-', '*', '%', '^', '~', '', '\n', 'return', 'typeof']);
  for (let i = openIdx; i < src.length; i++){
    const c = src[i], p = src[i-1];
    if (inLine){ if (c === '\n') inLine = false; continue; }
    if (inBlock){ if (p === '*' && c === '/') inBlock = false; continue; }
    if (inStr){ if (c === '\\'){ i++; continue; } if (c === inStr) inStr = null; continue; }
    if (inRe){
      if (c === '\\'){ i++; continue; }
      if (c === '[') inReClass = true;
      else if (c === ']') inReClass = false;
      else if (c === '/' && !inReClass) inRe = false;
      continue;
    }
    if (c === '"' || c === "'" || c === '`'){ inStr = c; prevSig = c; continue; }
    if (c === '/' && src[i+1] === '/'){ inLine = true; continue; }
    if (c === '/' && src[i+1] === '*'){ inBlock = true; continue; }
    if (c === '/' && reAllowed.has(prevSig)){ inRe = true; inReClass = false; continue; }
    if (c === '{' || c === '['){ depth++; }
    else if (c === '}' || c === ']'){ depth--; if (depth === 0) return i; }
    if (!/\s/.test(c)) prevSig = c;
  }
  throw new Error('Unbalancierter Block ab Index ' + openIdx);
}

/* function NAME(...){...} als Quelltext extrahieren. */
function extractFunction(script, name){
  const sig = new RegExp('function\\s+' + name + '\\s*\\(');
  const m = sig.exec(script);
  if (!m) throw new Error('Funktion nicht gefunden: ' + name);
  const braceIdx = script.indexOf('{', m.index);
  const end = balancedEnd(script, braceIdx);
  return script.slice(m.index, end + 1);
}

/* var NAME = {…} / [...] als Quelltext extrahieren. */
function extractVarLiteral(script, name){
  const sig = new RegExp('var\\s+' + name + '\\s*=\\s*');
  const m = sig.exec(script);
  if (!m) throw new Error('Variable nicht gefunden: ' + name);
  let i = m.index + m[0].length;
  while (i < script.length && /\s/.test(script[i])) i++;
  if (script[i] !== '{' && script[i] !== '[') throw new Error(name + ' ist kein Objekt/Array-Literal');
  const end = balancedEnd(script, i);
  return script.slice(i, end + 1);
}

/* Funktions-Quelltext isoliert auswerten (für pure Funktionen ohne Globals). */
function evalFunction(src){
  return new Function('return (' + src + ');')();
}

/* Literal in einem kontrollierten Scope auswerten: with(Proxy) fängt ALLE freien
 * Bezeichner ab — unbekannte liefern undefined statt ReferenceError. Closures
 * (sel/adv/ctx in TRAIN_LESSONS) lesen den Scope bei AUFRUF → Tests können
 * scope.state zwischen Aufrufen umschalten. */
function evalInScope(src, scope){
  const target = Object.assign({}, scope);
  const proxy = new Proxy(target, {
    has(){ return true; },
    get(t, k){ if (k === Symbol.unscopables) return undefined; return t[k]; },
    set(t, k, v){ t[k] = v; return true; }
  });
  const fn = new Function('__scope__', 'with(__scope__){ return (' + src + '); }');
  return { value: fn(proxy), scope: target };
}

/* Bequemer Einstieg: index.html laden + Script extrahieren (einmal pro Testlauf). */
let _cache = null;
function app(){
  if (!_cache){
    const html = readFileText('index.html');
    _cache = { html, script: extractInlineScript(html) };
  }
  return _cache;
}

module.exports = { ROOT, readFileText, extractInlineScript, balancedEnd,
  extractFunction, extractVarLiteral, evalFunction, evalInScope, app };
