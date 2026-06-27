---
phase: 05-identitaeten-audit-stufe1
plan: "01"
subsystem: database
tags: [supabase, postgres, jwt, rls, rpc, audit, identity, pgjwt, vault]

# Dependency graph
requires:
  - phase: 04.14-governance-panel
    provides: "Migration 0013 (is_admin, Admin-Exchange, argus_lage Admin-Zweig), Migration 0014 (CR-02 is_admin-Guard, expires_at-Erzwingung), argus_is_master/argus_token_active Basis"
provides:
  - "Migration 0015 live angewendet (idempotent, 2x HTTP 201)"
  - "Spalten is_person/usbnk/role auf access_tokens; schulungs_zwilling_id auf praesidien"
  - "append-only audit_log-Tabelle (anon nur SELECT via argus_is_master RLS)"
  - "Claim-Helfer argus_is_flz(), argus_usbnk(), argus_argus_role() — jti-gated"
  - "CR-02-Härtung: argus_exchange_code weist is_person-Codes ab"
  - "argus_exchange_person_code: Person-Exchange (usbnk+role-Claims, kein Klarname, 30-Tage-exp, jti, person_login-Log)"
  - "argus_master_issue_person: Master gibt Pro-Person-Token aus (alle Flags explizit, kein expires_at, person_issue-Log mit actor-USBNK)"
  - "argus_master_revoke_person: revoked=true → jti-Sofortsperre, person_revoke-Log"
  - "argus_master_search_usbnk: USBNK-Suche ohne token-Secret-Spalte"
  - "argus_lage FLZ-Zweig (präsidienübergreifend, kein Präsidiums-Filter)"
  - "SELF-HOSTING.md aktualisiert: 0015 in Dateiliste + Reihenfolge + Audit-Prosa + Stufe-1-Master-Bootstrap"
affects:
  - "05-02-audit-retention"
  - "05-03-leitungsseite-ui"
  - "phase-6-flz-lage-stufe-b"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pro-Person-Token-Muster: is_person=true + usbnk + role; analog zu is_admin-Muster aus 0013"
    - "CR-02-Härtung: jeder Exchange weist die jeweils fremde Token-Art ab (is_admin in 0014, is_person in 0015)"
    - "Zwangs-Log VOR Rückgabe: audit_log-INSERT in security-definer-RPC, kein anon-Write-Grant"
    - "Alle Boolean-Flags bei INSERT explizit false: verhindert versehentliche Privilegien"
    - "jti-Sofortsperre per argus_token_active() gating in allen neuen Claim-Helfern"

key-files:
  created:
    - "supabase/migrations/0015_phase5_identitaeten.sql"
  modified:
    - "docs/SELF-HOSTING.md"

key-decisions:
  - "Pro-Person-Token trägt kein expires_at (D-11): Widerruf via revoked+jti, technisches 30-Tage-exp im JWT als Bearer-Hygiene"
  - "FLZ-Scope präsidienübergreifend (D-12): praesidium_id-Claim null → bestehende RLS verweigert Roh-Zugriff; FLZ nur via argus_lage"
  - "Master darf weitere Master ausgeben (D-13): role='master' ist erlaubte Rolle in argus_master_issue_person; detail im audit_log explizit"
  - "audit_log ist eigene Tabelle (nicht governance_log erweitern): klare Trennung T4-Audit vs. Governance-Log"
  - "Ephemerer PAT nach Apply-Gate widerrufen: Owner-Punkt offen (deferred)"

patterns-established:
  - "Person-Exchange-Muster: eigener RPC argus_exchange_person_code analog argus_exchange_admin_code; CR-02-Spiegel in beiden Richtungen"
  - "append-only via deliberate omission: kein anon INSERT/UPDATE/DELETE-Grant; INSERT nur über security-definer-RPCs"
  - "Stufe-1-Bootstrap: erster Master-Token via direkten Dashboard-/Management-API-Insert (is_person=true, usbnk, role='master', alle Flags explizit false)"

requirements-completed: []

# Metrics
duration: ~2h (Tasks 1+2 in Wave 1, Checkpoint-Apply durch Orchestrator, Task 3 Continuation)
completed: 2026-06-27
---

# Phase 05 Plan 01: Stufe-1-Identitäts-Schicht Summary

**Migration 0015 live (idempotent): is_person/usbnk/role + audit_log + Person-Exchange/Master-RPCs/FLZ-Zweig + CR-02-Härtung beidseitig, vollständig durch 21+Positiv-/Negativ-/jti-Tests belegt**

## Performance

- **Duration:** ~2h (Tasks 1+2 geschrieben, Checkpoint-Apply durch Orchestrator, Task 3 Continuation)
- **Started:** 2026-06-27T~19:00Z
- **Completed:** 2026-06-27T~21:00Z
- **Tasks:** 3 (Task 1+2 als Block committed; Task 3 Continuation)
- **Files modified:** 2

## Accomplishments

- Migration 0015 geschrieben (696 Zeilen) und zweimal via Management API live angewendet (beide HTTP 201, Idempotenz belegt); alle 6 neuen Funktionen im Schema vorhanden
- Vollständige 21-Test-Batterie (21/21 Positiv + audit_log + jti) durch Orchestrator gegen Projekt `sehuosjyjmrpzcqrelej` verifiziert; alle Privilege-Escalation-Vektoren (CR-02 beidseitig, Master-RPCs ohne Master-JWT, FLZ-Roh-Zugriff, audit_log direkt schreiben) hart verweigert
- SELF-HOSTING.md nachgeführt: 0015 in Dateiliste und Reihenfolge, Audit-Prosa (keine neuen Server-Abhängigkeiten), Stufe-1-Master-Bootstrap in Abschnitt 8; D-02 und D-06 durchgängig gewahrt

## Task Commits

1. **Task 1+2: Migration 0015 — Identitäts-Schicht komplett** - `a0b50a8` (feat)
2. **Task 3: SELF-HOSTING.md nachführen** - `1593fbb` (docs)

**Plan metadata:** *(folgt nach SUMMARY-Commit)*

## Files Created/Modified

- `supabase/migrations/0015_phase5_identitaeten.sql` — 696-Zeilen-Migration: is_person/usbnk/role auf access_tokens, schulungs_zwilling_id auf praesidien, Claim-Helfer argus_is_flz/argus_usbnk/argus_argus_role (jti-gated), CR-02-Guard is_person in argus_exchange_code, audit_log-Tabelle append-only (RLS argus_is_master), argus_exchange_person_code, argus_master_issue_person, argus_master_revoke_person, argus_master_search_usbnk, argus_lage FLZ-Zweig, action-Katalog-Kommentar
- `docs/SELF-HOSTING.md` — 0015 in Dateiliste Abschnitt 3, Reihenfolge Abschnitt 5 auf → 0015 erweitert, Audit-Prosa (keine neuen Abhängigkeiten), Stufe-1-Master-Bootstrap in Abschnitt 8

## Decisions Made

- **Pro-Person-Token kein expires_at (D-11):** Widerruf läuft ausschließlich über revoked+jti-Sofortsperre; das JWT trägt ein technisches 30-Tage-exp als Bearer-Hygiene, aber keine ablaufgetriebene Logik
- **FLZ präsidienübergreifend (D-12):** praesidium_id-Claim null für FLZ/Master — bestehende RLS verweigert Roh-Patientenzugriff; FLZ erhält aggregierte Lage nur über argus_lage (STRIDE T-05-07 mitigiert)
- **Master darf weitere Master ausgeben (D-13):** role='master' explizit erlaubt in argus_master_issue_person; im audit_log-detail explizit protokolliert
- **audit_log eigenständige Tabelle:** governance_log bleibt unberührt; klare Trennung T4-Audit (person_*) vs. operativer Log
- **Ephemerer PAT nach Apply:** nach dem Orchestrator-Apply noch aktiv; Owner-Punkt (widerrufen im Dashboard) — deferred

## Deviations from Plan

None — Plan 05-01 exakt wie geplant ausgeführt. Checkpoint-Gate durch Orchestrator gecleart (Apply + Testbatterie extern durchgeführt).

## Checkpoint outcome (durch Orchestrator, nach Tasks 1+2)

**Gate-Typ:** blocking-human (PAT-Apply + Privilege-Escalation-Negativtest-Verify)

**Ergebnis (freigegeben):**

- 0015 ZWEIMAL angewendet via Management API → beide HTTP 201 (idempotent). Schema verifiziert: is_person/usbnk/role, audit_log, alle 6 Funktionen vorhanden.

**Positiv-Tests (21/21 + audit + jti, alle bestanden):**
- argus_exchange_person_code → JWT mit usbnk=TESTMASTER, argus_role=master, is_master=true, KEIN Klarname-Claim, jti=short_code, exp ≈ now+30 Tage (D-11)
- audit_log Eintrag person_login mit usbnk=TESTMASTER vorhanden
- Master-JWT → argus_master_issue_person(TESTFLZ, flz, null) → {short_code}; argus_master_search_usbnk('TESTFLZ') zeigt Token (role=flz), KEINE token-Spalte im Ergebnis (D-13)
- audit_log Eintrag person_issue mit actor=TESTMASTER, detail='role=flz target=TESTFLZ'
- FLZ-Exchange → JWT mit is_flz=true, praesidium_id=null (D-12); argus_lage mit FLZ-JWT → 16 CCPs präsidienübergreifend

**Negativ-Tests (alle hart verweigert):**
- CR-02: argus_exchange_code mit Master-Person-Code → Fehler „Pro-Person-Code — nur für die Leitungs-Seite gültig" (kein is_master-JWT)
- CR-02 Spiegel: argus_exchange_person_code mit Nicht-Person-Code → Fehler „Kein Pro-Person-Code"
- Privilege-Escalation: argus_master_issue_person/revoke/search mit Gast-JWT → Exception „Nur mit MasterUser-Token"
- FLZ-RLS: FLZ-JWT auf /patients → [] (praesidium_id null → RLS verweigert)
- append-only: direkter POST /rest/v1/audit_log → HTTP 403 (kein anon INSERT-Grant)
- Search-Disclosure: argus_master_search_usbnk-Ergebnis enthält KEINE token-Spalte

**jti-Sofortsperre:** FLZ-Token via argus_master_revoke_person gesperrt → zuvor ausgestelltes FLZ-JWT sofort verweigert (argus_lage denied); audit_log zeigt person_revoke mit actor-USBNK

**Regression belegt:** master code via argus_exchange_code liefert weiterhin is_master-JWT (Feld-Login intakt)

**Cleanup:** alle Test-Tokens (MSTR-TST1, FLZ-Code) und audit_log-Testzeilen restlos gelöscht (0 Überbleibsel)

## Issues Encountered

- Ephemerer PAT nach dem Checkpoint-Apply noch aktiv (bekanntes Muster, s. o.); Owner-Punkt (widerrufen) deferred — kein Blocker für Plan 05-02/03

## User Setup Required

None — keine externen Service-Konfigurationen in diesem Plan. Der erste Stufe-1-Master-Token wird vom Owner beim Self-Hosting-Bootstrap direkt eingetragen (Abschnitt 8 SELF-HOSTING.md).

## Next Phase Readiness

- Plan 05-02 (Audit-Retention): audit_log-Tabelle und alle schreibenden RPCs stehen bereit; pg_cron-Job kann auf audit_log ausgedehnt werden
- Plan 05-03 (Leitungs-Seite UI): argus_exchange_person_code, argus_master_issue_person/revoke/search und argus_lage-FLZ-Zweig sind serverseitig vollständig nutzbar
- Offener Owner-Punkt: ephemeren PAT widerrufen (Supabase Dashboard → Account → Access Tokens)

---
## Self-Check: PASSED

| Item | Status |
|------|--------|
| `supabase/migrations/0015_phase5_identitaeten.sql` | FOUND |
| `docs/SELF-HOSTING.md` | FOUND |
| `.planning/phases/05-identitaeten-audit-stufe1/05-01-SUMMARY.md` | FOUND |
| Commit a0b50a8 (Tasks 1+2) | FOUND |
| Commit 1593fbb (Task 3) | FOUND |

---
*Phase: 05-identitaeten-audit-stufe1*
*Plan: 01*
*Completed: 2026-06-27*
