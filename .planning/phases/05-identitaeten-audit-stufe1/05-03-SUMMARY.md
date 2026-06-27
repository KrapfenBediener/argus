---
phase: 05-identitaeten-audit-stufe1
plan: "03"
subsystem: ui
tags: [leitungs-seite, identitaeten, audit-log, usbnk, person-token, supabase-rpc, sessionStorage]

# Dependency graph
requires:
  - phase: 05-01
    provides: "argus_exchange_person_code, argus_master_issue_person/revoke_person/search_usbnk, audit_log-Tabelle (RLS argus_is_master), is_person/usbnk/role-Claims"
  - phase: 05-02
    provides: "audit_log-Retention (12-Monats-Purge, § 73 PolG BW)"
provides:
  - "Leitungs-Seite Master-Sektion „Identitäten“ (entsperrt): Einzel-Ausgabe Pro-Person-Token (USBNK+Rolle), USBNK-Suche ohne Token-Secret, Rollenwechsel (revoke+issue), Sperre (jti-Sofortsperre)"
  - "Leitungs-Seite Master-Sektion „Audit-Log“ (entsperrt): personenscharfe T4-Anzeige mit USBNK-Spalte, deutsche Aktions-Labels, Aktions-/USBNK-Filter"
  - "Pro-Person-Login (argus_exchange_person_code) in doLogin + Rollen-Mapping (master/admin/flz/normal) → personenscharfe Leitungs-Seiten-Sessions (D-08)"
affects: [phase-5.1-feld-app, phase-7-sso, audit, identitaeten]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Master-Sektion nach bestehendem sec*/load*-Paar + data-action-Delegation + cl.rpc/cl.from"
    - "Rollenwechsel ohne dedizierten RPC = revoke(alt)+issue(neu, gleiche USBNK) mit confirmModal (audit-dokumentiert)"
    - "Person-Exchange als dritter doLogin-Versuch NACH Master/Admin (CR-02-Härtung lässt Person-Codes am Master-Exchange korrekt scheitern)"
    - "Graceful noview-Ansicht für gültige, aber (noch) ansichtslose Rollen statt kaputter Master-Ansicht"

key-files:
  created: []
  modified:
    - "docs/leitung-*.html — zwei entsperrte Master-Sektionen + Pro-Person-Login-Verdrahtung"

key-decisions:
  - "Rollenwechsel = revoke+issue (Plan 01 hat keinen dedizierten Rollen-Change-RPC); kein direkter access_tokens-Update aus dem Client (RLS master-only + serverseitiges Logging)"
  - "Kein „Entsperren“ angeboten — Widerruf ist der dokumentierte Kill-Switch (D-11)"
  - "flz/normal-Person-Token: Login akzeptiert, aber secNoView()-Hinweis (FLZ-Lage/Feld-App folgen in Folgephase) — keine privilegierten Bereiche"

patterns-established:
  - "USBNK aus Person-JWT als argusl_kuerzel (Actor) → personenscharfe Governance-/Audit-Protokollierung"
  - "sideNav() liefert für nicht-privilegierte Rollen [] (keine Bereiche)"

requirements-completed: []

# Metrics
duration: ~35min
completed: 2026-06-27
---

# Phase 5 Plan 03: Identitäten & Audit-Log (Leitungs-Seite) Summary

**Zwei entsperrte Master-Sektionen auf der Leitungs-Seite — „Identitäten“ (Einzel-Ausgabe/USBNK-Suche/Rollenwechsel/Sperre über die Plan-01-RPCs, ohne Token-Secrets) und „Audit-Log“ (personenscharfe T4-Anzeige mit USBNK-Filter) — plus Pro-Person-Login in doLogin, das die Leitungs-Seiten-Sessions erst personenscharf macht (D-08).**

## Performance

- **Duration:** ~35 min (inkl. orchestrator-getriebener Browser-Verifikation)
- **Completed:** 2026-06-27
- **Tasks:** 2 ausführende Tasks + 1 human-verify-Checkpoint (browser, bestanden) + 1 nachträglicher Gap-Fix
- **Files modified:** 1 (`docs/leitung-*.html`)

## Accomplishments

- **„Identitäten“ entsperrt** und in `SECTIONS_MASTER` (nur Master, Admin sieht sie nicht): Einzel-Ausgabe eines Pro-Person-Tokens (USBNK + Rolle Master/FLZ/Admin, Admin-Rolle verlangt Präsidiums-Select) via `argus_master_issue_person`; USBNK-Suche via `argus_master_search_usbnk` (USBNK/Rolle-Pill/short_code/Status/Präsidium — **kein Token-Secret**); Rollenwechsel als revoke+issue mit confirmModal; Sperre via `argus_master_revoke_person` (jti-Sofortsperre).
- **„Audit-Log“ entsperrt**: `cl.from('audit_log').select(...).order('at',desc).limit(200)` mit USBNK-Spalte, `auditActionLabel()` (deutsche Labels für alle 13 Katalog-Aktionen aus Plan 01), Aktions-Select + USBNK-Freitext-Filter (live) + Reset.
- **Phase-7-Sperrzone entfernt**: die seit 4.9 sichtbaren 🔒-Locked-Sidebar-Einträge sind raus (nur die CSS-Klassen `.lockedsec`/`.locked` bleiben im Stylesheet — sie sind generische Bausteine, keine sichtbaren Einträge).
- **Pro-Person-Login verdrahtet** (Gap-Fix, siehe Deviations): dritter doLogin-Versuch `argus_exchange_person_code` mit Rollen-Mapping; macht die in dieser Phase neu gebauten Master-Aktionen erst personenscharf.

## Task Commits

1. **Task 1+2: „Identitäten“ + „Audit-Log“ Sektionen** — `d163ae6` (feat)
   - SECTIONS_MASTER erweitert, Sperrzone entfernt, render()/loadSection()-Zweige, secIdentitaeten/loadIdentitaeten, secAudit/loadAudit/auditActionLabel, data-actions mkperson/usbnksearch/personrole/personrevoke/auditreload/auditfilter/auditfilterreset.
2. **Gap-Fix: Pro-Person-Login in doLogin + Rollen-Mapping** — `598e208` (feat)
   - argus_exchange_person_code als dritter Versuch; USBNK→argusl_kuerzel; master/admin/flz-normal-Mapping; secNoView() + sideNav-[]-Fallback.

_(Beide Sektionen in einem Commit, weil dieselbe Datei; Task 1 und Task 2 sind im selben sec*/load*-Block.)_

## Files Created/Modified

- `docs/leitung-*.html` — zwei neue Master-Sektionen (Identitäten + Audit-Log), Phase-7-Sperrzone entfernt, Pro-Person-Login-Strecke in doLogin, secNoView() für ansichtslose Rollen, neue State-Variablen (`_persResults/_persErr`, `_audit/_auditErr/_auditFilter`), Audit-Filter change/input-Listener.

## Decisions Made

- **Rollenwechsel = revoke+issue**: Plan 01 liefert keinen dedizierten Rollen-Change-RPC. Statt eines direkten `access_tokens`-Updates aus dem Client (RLS master-only + serverseitiges Logging erforderlich) wird der alte Token via `argus_master_revoke_person` gesperrt und ein neuer via `argus_master_issue_person` (gleiche USBNK, neue Rolle) ausgegeben — der person_revoke+person_issue-Doppeleintrag im audit_log dokumentiert den Wechsel.
- **Kein „Entsperren“**: Widerruf ist der dokumentierte Kill-Switch (D-11, „Lebenszyklus = Widerruf“). Nur „Sperren“ wird angeboten.
- **flz/normal-Login akzeptiert, aber ansichtslos**: gültige Person-Token dieser Rollen melden sich an (personenscharf protokolliert), bekommen aber `secNoView()` statt einer kaputten/leeren Master-Ansicht; `sideNav()` zeigt keine privilegierten Bereiche. FLZ-Lage/Feld-App folgen in einer Folgephase.
- **D-02 (USBNK-only)**: durchgängig „USBNK“ beschriftet, keine Klarnamen-Felder; Suchergebnisse zeigen niemals ein Token-Secret (RPC liefert keins).
- **Kein App-Release**: `index.html`/`sw.js` unverändert; die Leitungs-Seite ist nicht app-versioniert → kein Version-Bump, kein WHATS_NEW, kein Trainings-Drehbuch-Update in dieser Phase.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Pro-Person-Login (argus_exchange_person_code) in doLogin ergänzt**
- **Found during:** vor dem Browser-Checkpoint (vom Orchestrator gemeldete Lücke)
- **Issue:** `doLogin` versuchte nur `argus_exchange_code` (Legacy-Master) und `argus_exchange_admin_code` (Admin) — **nicht** `argus_exchange_person_code`. Folge: ein Master-PERSON-Token (USBNK-gebunden) konnte sich nicht anmelden; Master-Aktionen auf den neuen Sektionen wären mit `usbnk=null` protokolliert worden (Legacy-MasterToken trägt keine USBNK). Das bricht das Phasenziel / D-08 („Phase 5 erfasst die Stufe-1 Leitungs-Seiten-Sessions“) — das Audit wäre für genau die hier neu gebauten Aktionen nicht personenscharf.
- **Fix:** dritter doLogin-Versuch `POST /rest/v1/rpc/argus_exchange_person_code` NACH dem Master- und Admin-Versuch (Reihenfolge korrekt: die CR-02-Härtung aus Plan 01 lässt einen Person-Code am `argus_exchange_code` bereits mit Fehler scheitern, der Master-Versuch fällt also korrekt zuerst durch). Bei jwt: JWT+exp in sessionStorage (gleiche Keys), `data.usbnk` als `argusl_kuerzel` (Actor). Rollen-Mapping `data.argus_role`: master→volle Master-Ansicht, admin→reduzierte Admin-Ansicht (padmin/padmin_name), flz/normal→Login akzeptiert + secNoView()-Hinweis. Abweisungstext erwähnt jetzt auch Pro-Person-Token.
- **Files modified:** `docs/leitung-*.html`
- **Verification:** Browser-Roundtrip gegen das Live-Backend (siehe „Issues Encountered“) — person_login/person_issue/person_revoke alle mit `usbnk=UITESTMASTER` (Actor); Plan-Greps + `node --check` + D-06-Gate erneut bestanden.
- **Committed in:** `598e208`

---

**Total deviations:** 1 auto-fixed (1 missing critical / D-08-Personenschärfe)
**Impact on plan:** Der Fix ist notwendig für die Kern-Phasenleistung (personenscharfe T4-Protokollierung der Leitungs-Seiten-Sessions). Kein Scope-Creep — nur die fehlende Login-Strecke + Rollen-Mapping + freundlicher Hinweis für ansichtslose Rollen.

## Issues Encountered

**Browser-Verifikation (orchestrator-getrieben, Live-Backend, alle PASS):**
- Master-PERSON-Login (Token usbnk=UITESTMASTER über die neue argus_exchange_person_code-Strecke) → role=master, argusl_kuerzel=UITESTMASTER, Sidebar zeigt „Identitäten“ + „Audit-Log“ entsperrt (kein 🔒).
- Identitäten — Ausgabe: USBNK=UITESTFLZ, Rolle=FLZ → promptModal zeigt short_code (X79H-Z4Y9), KEIN Token-Secret.
- Identitäten — Suche: UITESTFLZ-Zeile mit USBNK/Rolle(pill)/Code/Status(aktiv)/Präsidium — KEINE Token-Secret-Spalte. personrole + personrevoke vorhanden.
- Identitäten — Sperren: confirmModal (erklärt jti-Sofortsperre) → revoked=true in DB; Toast „Gesperrt (sofort wirksam) — Audit-Log: person_revoke“.
- **PERSONENSCHARF (der D-08-Fix): audit_log zeigt person_login + person_issue + person_revoke ALLE mit usbnk=UITESTMASTER (Actor)** — detail „role=flz target=UITESTFLZ“ / „target=UITESTFLZ“. Ohne die Person-Login-Verdrahtung wären diese usbnk=null gewesen.
- Audit-Log-Sektion: personenscharf-Hinweis (§ 73, append-only, Master-only RLS), zeigt UITESTMASTER, deutsche Labels (Anmeldung (Pro-Person)/Token ausgegeben/Token gesperrt/Rolle geändert), Aktions- + USBNK-Filter vorhanden.
- noview-Pfad: ein FLZ-only-Person-Token meldet sich an (role=flz, keine privilegierten Bereiche) und zeigt den freundlichen „Für diese Rolle ist auf der Leitungs-Seite noch keine Ansicht verfügbar … Folgephase“-Hinweis — keine kaputte/leere Ansicht.
- Alle Test-Token + audit-Zeilen anschließend bereinigt (0 Rest). index.html/sw.js unverändert; D-06 git grep 0.

## User Setup Required

None — keine externe Service-Konfiguration. Die konsumierten RPCs/Tabellen sind seit Plan 01/02 live.

## Next Phase Readiness

- Die Stufe-1-Identitätsverwaltung ist end-to-end über die Leitungs-Seite bedienbar (Ausgabe/Suche/Rollenwechsel/Sperre) und personenscharf protokolliert.
- **Phase 5.1 (Feld-App):** Pro-Person-Login + FLZ-/Echt/Schulung-Picker; danach wird T4 auch für Feld-Aktionen voll personenscharf. Die secNoView()-Rollen (flz/normal) bekommen dann ihre Ansicht.
- Kein offener Blocker für diese Phase. PTLS-Vibecoding-Block bleibt der bekannte Echtbetrieb-Adoptions-Blocker (außerhalb dieser Phase).

## Self-Check: PASSED

- Commits vorhanden: `d163ae6` (Sektionen), `598e208` (Person-Login) — beide via `git log --grep "05-03"` bestätigt.
- `docs/leitung-*.html` modifiziert und committet.
- Plan-Greps, `node --check` (inline-Script exit 0) und D-06-Gate (0 Treffer außerhalb docs/leitung-*.html) bestanden.
- index.html/sw.js unverändert.

---
*Phase: 05-identitaeten-audit-stufe1*
*Completed: 2026-06-27*
