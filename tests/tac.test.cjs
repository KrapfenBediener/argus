/* tacSTART-Entscheidungsbaum: Graph-Konsistenz.
 * Der geführte tacSTART ist der Standardweg der Vorsichtung (mdr-tacstart-accepted,
 * v0.30.0) — sein Baum darf nie kaputte Übergänge oder unerreichbare Knoten haben. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { app, extractVarLiteral } = require('./_extract.cjs');

const FLOW = new Function('return (' + extractVarLiteral(app().script, 'FLOW') + ');')();
const RESULT_OK = new Set(['T1', 'T2', 'T3', 'T5', 'NOBR']);

test('FLOW: Einstiegsknoten "walk" existiert', () => {
  assert.ok(FLOW.walk, 'Einstieg walk fehlt');
});

test('FLOW: jeder Übergang zeigt auf existierenden Knoten oder gültiges Ergebnis', () => {
  for (const [name, node] of Object.entries(FLOW)){
    assert.ok(node.q && typeof node.q === 'string', name + ': Frage fehlt');
    assert.ok(Array.isArray(node.ans) && node.ans.length >= 2, name + ': braucht >=2 Antworten');
    for (const [label, go] of node.ans){
      assert.ok(label, name + ': Antwort-Label fehlt');
      if (go.startsWith('R:')){
        assert.ok(RESULT_OK.has(go.slice(2)), name + ': unbekanntes Ergebnis ' + go);
      } else {
        assert.ok(FLOW[go], name + ': Übergang auf fehlenden Knoten "' + go + '"');
      }
    }
  }
});

test('FLOW: alle Knoten von "walk" aus erreichbar, keine Endlosschleife', () => {
  const seen = new Set();
  const queue = ['walk'];
  while (queue.length){
    const n = queue.shift();
    if (seen.has(n)) continue;
    seen.add(n);
    for (const [, go] of FLOW[n].ans){
      if (!go.startsWith('R:')) queue.push(go);
    }
  }
  for (const name of Object.keys(FLOW)){
    assert.ok(seen.has(name), 'Knoten unerreichbar: ' + name);
  }
});

test('FLOW: alle Sichtungskategorien T1/T2/T3 sind als Ergebnis erreichbar', () => {
  const results = new Set();
  for (const node of Object.values(FLOW)){
    for (const [, go] of node.ans){
      if (go.startsWith('R:')) results.add(go.slice(2));
    }
  }
  for (const cat of ['T1', 'T2', 'T3']){
    assert.ok(results.has(cat), 'Kategorie nicht erreichbar: ' + cat);
  }
});
