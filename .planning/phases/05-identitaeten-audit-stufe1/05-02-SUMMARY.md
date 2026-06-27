---
phase: 05-identitaeten-audit-stufe1
plan: "02"
subsystem: database
tags: [postgres, supabase, audit-log, purge, retention, pg_cron, plpgsql]

# Dependency graph
requires:
  - phase: 05-01
    provides: audit_log append-only Tabelle (angelegt in 0015); argus_run_purge mit Schritten a–d (angelegt in 0004, live)
provides:
  - argus_run_purge() mit neuem Schritt (e): audit_log-Einträge > 365 Tage löschen (D-07, § 73 PolG BW)
  - Migration 0016 live angewendet (idempotent, zweimal HTTP 201)
  - Return-JSON additiv um audit_log_retention-Schlüssel erweitert
  - SELF-HOSTING.md: 0016 in Dateiliste + Reihenfolge + Audit-Prosa nachgeführt
affects: [05-03, phase 6, self-hosting, purge-run, audit-log-retention]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive argus_run_purge-Erweiterung: neuer Schritt per create or replace, bestehende Schritte byte-gleich übernehmen"
    - "audit_log.at = bigint-ms (identisch zu governance_log, Cutoff: N Tage × 86400000 ms)"
    - "Kein zweiter Cron-Job: bestehender argus_purge-Job (0002, 17 * * * *) deckt neuen Schritt automatisch"

key-files:
  created:
    - supabase/migrations/0016_phase5_t4_audit.sql
  modified:
    - docs/SELF-HOSTING.md

key-decisions:
  - "0016 erweitert ausschließlich argus_run_purge (create or replace, Schritt e) — keine zweite Cron-Infrastruktur (D-07)"
  - "Schritt (e) schreibt KEINEN audit_log-/purge_log-Eintrag (keine Rekursion, kein Log-Spam)"
  - "Return-JSON additiv: neuer Schlüssel audit_log_retention, bestehende Schlüssel unverändert"
  - "D-06 durchgängig gewahrt: kein konkreter Leitungs-Dateiname in committeten Texten"

patterns-established:
  - "Security-definer-Purge als einziger Löschpfad für audit_log (append-only beibehalten)"
  - "Bigint-ms-Cutoff: v_now - 365::bigint * 86400000 (analog governance_log Schritt d)"

requirements-completed: []

# Metrics
duration: 5min
completed: 2026-06-27
---

# Phase 05 Plan 02: T4-Audit-Retention Summary

**argus_run_purge() um Schritt (e) ergänzt — audit_log-Einträge älter als 12 Monate werden über den bestehenden stündlichen Cron-Job gelöscht (D-07, § 73 PolG BW), idempotent live angewendet und mit synthetischen Rows getestet**

## Performance

- **Duration:** ~5 min (Continuation-Session nach Checkpoint)
- **Started:** 2026-06-27T20:17:20Z (Task 1 Commit e92bfbe)
- **Completed:** 2026-06-27T20:19:40Z (Task 2 Commit 904fa37)
- **Tasks:** 2 (+ 1 blocking-human-Checkpoint zwischen Task 1 und 2)
- **Files modified:** 2

## Accomplishments

- Migration 0016 geschrieben: argus_run_purge() per create or replace neu gefasst mit Schritten a–d byte-gleich aus 0004 + neuem Schritt (e) audit_log-Retention (365 Tage, bigint-ms-Cutoff). Return-JSON additiv um `audit_log_retention: {audit_log: N}` erweitert. Funktions-Kommentar nachgezogen. Grant erneut gesetzt (Idempotenz-Netz).
- 0016 ZWEIMAL live über Supabase Management API angewendet (beide HTTP 201) — Idempotenz-Beleg.
- Retention-Funktionstest mit synthetischen Rows bestanden: Alt-Row (>366 Tage, usbnk='RETENTION-ALT') wurde gelöscht, Frisch-Row blieb erhalten; bestehende Purge-Schritte a–d intakt; Return-JSON enthält neuen Schlüssel `audit_log_retention: {audit_log: 1}`. Test-Rows restlos aufgeräumt.
- SELF-HOSTING.md nachgeführt: 0016 in Dateiliste (Abschnitt 3), Reihenfolge auf → 0016 erweitert (Abschnitt 5), Audit-Prosa und Smoke-Test-Schritt 7 aktualisiert.

## Task Commits

1. **Task 1: Migration 0016 — audit_log-Retention als Schritt (e) in argus_run_purge** — `e92bfbe` (feat)
2. **Task 2: SELF-HOSTING.md nachführen (Migration 0016)** — `904fa37` (docs)

**Plan metadata:** wird im Anschluss committet (docs: complete plan)

## Files Created/Modified

- `supabase/migrations/0016_phase5_t4_audit.sql` — argus_run_purge() Neufassung mit Schritt (e) audit_log-Retention; 168 Zeilen; idempotent (create or replace)
- `docs/SELF-HOSTING.md` — 0016 in Dateiliste + Reihenfolge + Audit-Prosa + Smoke-Test-Schlüssel ergänzt

## Decisions Made

- Schritt (e) nach dem Muster von Schritt (d) aus 0004: `delete from public.audit_log where at is not null and at <= v_now - 365::bigint * 86400000`. Identische Bigint-ms-Konvention wie governance_log — kein zusätzlicher Typ-Casting-Aufwand.
- Kein zweiter pg_cron-Job: der bestehende `argus_purge`-Job (Einrichtung in 0002, `17 * * * *`) ruft die erweiterte Funktion automatisch auf — Infrastruktur-Overhead null.
- Return-JSON additiv erweitert (`audit_log_retention` als separater Schlüssel neben `log_retention`) — keine Breaking Change für bestehende Aufrufer.

## Deviations from Plan

None — Plan executed exactly as written.

## Checkpoint-Outcome (dokumentiert)

Der blocking-human-Checkpoint zwischen Task 1 und 2 wurde vom Orchestrator mit folgendem Ergebnis freigegeben:

- 0016 zweimal über Management API angewendet → beide HTTP 201 (idempotent, reine create or replace).
- argus_run_purge() Return-JSON enthält alle erwarteten Schlüssel: `foto`, `frist`, `inaktiv`, `log_retention` (alle bestehend, intakt) + NEU `audit_log_retention: {audit_log: 1}`.
- Retention-Funktionstest: Alt-Row (>366 Tage) gelöscht, Frisch-Row blieb erhalten; bestehende Schritte a–d erzeugen keinen Fehler.
- Test-Rows restlos aufgeräumt.

## Threat Surface Scan

Keine neuen sicherheitsrelevanten Flächen eingeführt — 0016 erweitert ausschließlich eine bestehende security-definer-Funktion (argus_run_purge). Löschpfad für audit_log bleibt exklusiv auf dem kontrollierten Purge-Job (T-0502-01 mitigiert). Keine neuen Netzwerk-Endpunkte, keine neuen Auth-Pfade, keine Schema-Erweiterungen an Trust-Boundaries.

## Known Stubs

Keine — reine SQL-Migration + Doku-Nachführung, kein UI-Code.

## Issues Encountered

None.

## User Setup Required

None — 0016 ist live angewendet. Einziger Owner-Punkt: ephemeren PAT widerrufen (Supabase Dashboard → Account → Access Tokens), sofern noch nicht nach Plan 05-01 erledigt.

## Next Phase Readiness

- audit_log-12-Monats-Retention ist live und getestet. Append-only gewahrt.
- Plan 05-03 (Leitungs-Seite UI für Audit-Ansicht) kann beginnen — serverseitige Grundlage komplett.

## Self-Check: PASSED

- `supabase/migrations/0016_phase5_t4_audit.sql` existiert: FOUND
- Commit e92bfbe existiert: FOUND (feat(05-02): Migration 0016)
- Commit 904fa37 existiert: FOUND (docs(05-02): SELF-HOSTING.md)
- `docs/SELF-HOSTING.md` enthält "0016_phase5_t4_audit.sql": FOUND
- D-06 (kein leitung-<hex> in committeten Dateien): PASSED

---
*Phase: 05-identitaeten-audit-stufe1*
*Completed: 2026-06-27*
