---
phase: 5
slug: identitaeten-audit-stufe1
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-27
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Quelle: `05-RESEARCH.md` → „Validation Architecture". Projektkonvention: **kein Test-Runner** —
> REST-Direkttests via `curl` + Logiktests via JavaScriptCore (`osascript -l JavaScript`).
> DB-Anwendung via Supabase Management API + ephemerer PAT (kein CLI).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Kein Runner — REST-Direkttests (`curl` + `jq`) gegen die Live-/Schulungs-Instanz; Logik via JSC |
| **Config file** | none |
| **Quick run command** | `curl -s -X POST "https://<ref>.supabase.co/rest/v1/rpc/<fn>" -H "apikey: <anon>" -H "Authorization: Bearer <jwt>" -d '<body>'` |
| **Full suite command** | Alle REST-Positiv-/Negativtests sequenziell (Muster 4.12/4.14-SUMMARY); Migration via Management API 2× (Idempotenz) |
| **Estimated runtime** | ~1–2 min (REST-Batterie) |

---

## Sampling Rate

- **Nach jeder Migration (0015/0016):** 2× anwenden (Idempotenz-Beleg) + zugehörige REST-Tests.
- **Nach jeder Welle:** vollständige REST-Positiv-/Negativ-Batterie der Welle.
- **Vor `/gsd-verify-work`:** komplette Batterie grün (inkl. Privilege-Escalation-Negativtests).
- **Max feedback latency:** ~120 s.

---

## Per-Task Verification Map

> Task-IDs werden vom Planner vergeben; diese Map wird in den PLAN-`<verify>`-Blöcken konkretisiert.
> Kern-Verhalten → Test (aus RESEARCH):

| Anforderung | Erwartetes Verhalten | Testtyp | Automatisierte Prüfung | Status |
|---|---|---|---|---|
| D-02 USBNK-only | JWT trägt `usbnk`-Claim, KEIN Klarname | REST-Positiv | `curl` + `jq` auf JWT-Payload | ⬜ |
| D-05 / CR-02 | `argus_exchange_code` weist `is_person`-Code ab | REST-Negativ | curl → Fehler | ⬜ |
| D-05 / CR-02 | `argus_exchange_person_code` weist Nicht-Person-Code ab | REST-Negativ | curl → Fehler | ⬜ |
| Privilege-Esc. | Person-Code `role='master'` über `argus_exchange_code` → Fehler | REST-Negativ | curl | ⬜ |
| Privilege-Esc. | FLZ-/Person-JWT auf `patients` → RLS-konform (FLZ: erlaubt lt. Scope; Person ohne Scope: leer) | REST | curl | ⬜ |
| Privilege-Esc. | Master-Issue-RPC mit unprivilegiertem JWT → Exception | REST-Negativ | curl | ⬜ |
| D-07 append-only | `anon`/normaler JWT: kein INSERT/UPDATE/DELETE auf `audit_log` | REST-Negativ | curl → verweigert | ⬜ |
| D-07 Retention | `argus_run_purge()` löscht `audit_log` > 365 Tage | Funktionstest | synthetische Alt-Rows (Muster 04.10-01) | ⬜ |
| jti-Sofortsperre | Person-Token sperren → vorheriges JWT schlägt sofort fehl | REST-Pos+Neg | curl | ⬜ |
| USBNK-Suche | Suchergebnis enthält NICHT die `token`-Secret-Spalte | REST-Positiv | curl + `jq 'has("token")'` == false | ⬜ |
| T4-Login-Audit | Exchange schreibt `person_login` (USBNK) in `audit_log` | REST-Positiv | curl + SELECT | ⬜ |
| Master-Vergabe (D-13) | Master-Issue protokolliert actor-USBNK im audit_log | REST-Positiv | curl + SELECT | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] REST-Test-Skript für Phase 5 (analog `04.14-01-SUMMARY.md` „REST-Negativtests") — als eigene Aufgabe in Plan 01.
- [ ] Synthetische Alt-Row in `audit_log` für den Retention-Test (wie 04.10-01 für governance_log).

---

## Manual-Only Verifications

| Behavior | Anforderung | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Leitungs-Seite: USBNK-Suche + Rollenvergabe/-sperre als Master | D-04, D-13 | Browser-UI gegen Live-Backend | Browser-Roundtrip (Orchestrator-getrieben, Muster 4.14): Master-Login → Person-Token ausgeben (FLZ/Admin) → suchen → sperren → Audit-Eintrag prüfen |
| Audit-Ansicht zeigt USBNK + neue Aktionen | D-06 | visuelle Darstellung | Audit-View öffnen, Filter nach Aktion/USBNK |

---

## Validation Sign-Off

- [ ] Jede sicherheitsrelevante Anforderung hat einen REST-Negativtest (Privilege-Escalation Pflicht)
- [ ] Migration 0015/0016 idempotent (2× HTTP 201)
- [ ] append-only `audit_log` per Negativtest belegt
- [ ] jti-Sofortsperre für Person-Tokens belegt
- [ ] D-06-Gate grün; keine Klarnamen-Spalten (D-02)
- [ ] `nyquist_compliant: true` nach Plan-Abgleich setzen

**Approval:** pending
