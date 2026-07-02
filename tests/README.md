# Tests & CI

Qualitäts-Gates für ARGUS. **Die App bleibt buildfrei** (Single-File `index.html`) —
diese Suite testet sie, ohne sie umzubauen: `_extract.cjs` zieht Funktionen und
`var`-Literale per String-Scanner aus dem Inline-Script und wertet sie isoliert aus.

## Lokal ausführen

```bash
npm run check:syntax   # node --check auf dem Inline-JS aller App-Seiten
npm test               # Logik-, tacSTART-, Drehbuch-, Security-, Konsistenz-Tests
npm run ci             # check:syntax + test (= was die CI fährt)
npm run check:rls      # LIVE-Probe gegen das echte Backend (anon ⇒ 0 Zeilen); SKIP ohne Netz
```

Voraussetzung: Node ≥ 20 (nur Bordmittel, keine Dependencies, kein `npm install`).

## Was abgedeckt ist

| Datei | Deckt ab | Warum (Traceability) |
|---|---|---|
| `logic.test.cjs` | `safePhoto`, `revokedDecision`, `esc`, `cmpVer` | Stored-XSS v0.32.2 · D-20-Sperrschutz · Versionssortierung |
| `tac.test.cjs` | tacSTART-Baum (`FLOW`): Übergänge, Erreichbarkeit, Kategorien | Vorsichtungs-Standardweg darf nie brechen (mdr-tacstart-accepted) |
| `training.test.cjs` | `TRAIN_LESSONS`: Zahl, Modi, `ctxBack`, **Selektor-Existenz** | Highlighting-/Verhak-Bugs v0.32.3–0.33.2 · DAUERREGEL Drehbuch↔UI |
| `consistency.test.cjs` | APP_VERSION ↔ version.json ↔ CHANGELOG ↔ sw-Cache, Update-Sheets, Precache | „Version irgendwo vergessen" |
| `security.test.cjs` | native Dialoge, Foto-innerHTML, D-06, Secrets, migration search_path | Behobene Vorfälle als Dauerprüfung |

Die CI (`.github/workflows/ci.yml`) fährt `check:syntax` + `test` + D-06-Gate bei
jedem Push/PR auf `main`. Der Live-RLS-Check läuft **nicht** in der CI (braucht
Backend-Erreichbarkeit) — lokal/manuell vor Releases fahren.

## DAUERREGEL

Ändert sich die UI oder das Drehbuch, **Tests mitziehen** — insb. `training.test.cjs`
(Lektionszahl, Selektoren) ist bewusst streng, damit umbenannte Buttons Lektionen
nicht stumm brechen.
