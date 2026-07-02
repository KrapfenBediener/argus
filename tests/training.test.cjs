/* Geführtes Training (TRAIN_LESSONS): Drehbuch-Integrität.
 * Traceability: Selektor-Existenz ← Lektion-19/20-Highlighting-Bugs (v0.32.3/0.33.2)
 * · ctxBack ← „Zurück verhakt"-Bug (v0.32.4) · DAUERREGEL: Drehbuch ↔ UI synchron. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { app, extractVarLiteral, evalInScope } = require('./_extract.cjs');

const { html, script } = app();

/* Lektionen in kontrolliertem Scope auswerten — sel/adv/ctx-Closures lesen
 * scope.state bei Aufruf, Tests schalten die Ansicht um. */
const stubs = {
  state: { view: 'overview', capDirect: false, capMode: 'menu', edit: null },
  patients: [], _ccpId: null, _mergeGroupId: null, _training: true,
  trainCount: () => 0, trainSome: () => false
};
const { value: LESSONS, scope } = evalInScope(extractVarLiteral(script, 'TRAIN_LESSONS'), stubs);

test('Drehbuch: Lektionszahl ist 40 (bei bewusster Änderung Test aktualisieren — DAUERREGEL)', () => {
  assert.equal(LESSONS.length, 40);
});

test('Drehbuch: jede Lektion hat Titel, Text und gültigen Modus', () => {
  for (const L of LESSONS){
    assert.ok(L.t && typeof L.t === 'string', 'Titel fehlt');
    assert.ok(L.x && L.x.length > 20, L.t + ': Text fehlt/zu kurz');
    assert.ok(['explain', 'do', 'choice'].includes(L.mode), L.t + ': Modus ' + L.mode);
    if (L.mode === 'do') assert.ok(L.adv, L.t + ': do-Lektion ohne adv-Bedingung');
  }
});

test('Drehbuch: ctxBack zeigt auf die Einstiegs-Lektion „Jetzt: Checkliste öffnen" (Regression v0.32.1)', () => {
  const entryIdx = LESSONS.findIndex(L => L.t === 'Jetzt: Checkliste öffnen');
  assert.ok(entryIdx >= 0, 'Einstiegs-Lektion fehlt');
  for (const L of LESSONS){
    if (L.ctx && L.ctxBack !== undefined){
      assert.equal(L.ctxBack, entryIdx,
        L.t + ': ctxBack=' + L.ctxBack + ' zeigt nicht auf Index ' + entryIdx +
        ' — beim Einfügen/Entfernen von Lektionen VOR der Checkliste nachziehen!');
    }
  }
});

/* Selektor-Ziele müssen im App-Markup existieren — fängt umbenannte Buttons,
 * die Lektionen stumm brechen würden (Ursache der Lektion-19/20-Bugs). */
function needlesFor(sel){
  const needles = [];
  for (const part of sel.split(',')){
    for (const m of part.matchAll(/\[data-([a-z-]+)="([^"]+)"\]/g)) needles.push('data-' + m[1] + '="' + m[2] + '"');
    for (const m of part.matchAll(/#([A-Za-z0-9_-]+)/g)) needles.push('id="' + m[1] + '"');
    for (const m of part.matchAll(/\.([A-Za-z0-9_-]+)/g)) needles.push(m[1]);
  }
  return needles;
}

function collectSels(){
  const views = [
    { view: 'start' }, { view: 'home' }, { view: 'overview' }, { view: 'catlist' },
    { view: 'capture', capDirect: false }, { view: 'capture', capDirect: true },
    { view: 'patient', edit: {} }, { view: 'checklist' }
  ];
  const sels = new Set();
  for (const L of LESSONS){
    if (typeof L.sel === 'string'){ sels.add(L.sel); continue; }
    if (typeof L.sel === 'function'){
      for (const v of views){
        Object.assign(scope.state, { capDirect: false, edit: null }, v);
        let s = null;
        try { s = L.sel(); } catch (e) { assert.fail(L.t + ': sel() wirft in Ansicht ' + v.view + ': ' + e); }
        if (typeof s === 'string' && s) sels.add(s);
      }
    }
  }
  return [...sels];
}

test('Drehbuch: jedes Spotlight-Ziel existiert im App-Markup', () => {
  for (const sel of collectSels()){
    for (const needle of needlesFor(sel)){
      assert.ok(html.includes(needle),
        'Spotlight-Ziel fehlt im Markup: "' + needle + '" (Selektor: ' + sel + ') — ' +
        'Button umbenannt/entfernt? Drehbuch nachziehen (DAUERREGEL).');
    }
  }
});

test('Drehbuch: doit/ctx/adv-Funktionen werfen in keiner Ansicht', () => {
  const views = ['start', 'home', 'overview', 'catlist', 'capture', 'patient', 'checklist'];
  for (const L of LESSONS){
    for (const fn of ['doit', 'ctx', 'adv']){
      if (typeof L[fn] !== 'function') continue;
      for (const v of views){
        scope.state.view = v; scope.state.edit = v === 'patient' ? {} : null;
        assert.doesNotThrow(() => L[fn](), L.t + '.' + fn + '() wirft in Ansicht ' + v);
      }
    }
  }
});
