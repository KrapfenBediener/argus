# Projekt-Status — Argus (CCP-App)

- **Milestone:** Closed Beta V1
- **Aktuelle Phase:** 3 — Mehrgeräte-Features verdrahten *(in Arbeit)*
- **Deploy:** GitHub Pages — Repo `KrapfenBediener/argus`, Branch `main`
- **Backend:** Supabase EU (`sehuosjyjmrpzcqrelej`)

## Letzte Arbeit (2026-06-03)
- Login-Fokusverlust + kaputter `Präsidium:`-Präfix gefixt (commit `19fe26b`, gepusht)
- Legacy-`ccps.join_token`-Auth deaktiviert → alte Links ohne Freischaltung ungültig *(uncommitted)*
- **Patienten-Sperre gebaut:** Soft-Lock, 45 s Ablauf, Heartbeat ~15 s, 🔒-Indikator,
  MasterMedic-Override per Button *(uncommitted)*

## Nächster offener Punkt
- Phase 3: **echtes CCP-Zusammenführen** — Demo-Mechanismus (`DEMO_CCPS`, `demo:true`) entfernen,
  echte geräteübergreifende Merge-Logik bauen.

## Offene Entscheidungen / Hinweise
- **Deploy der aktuellen Änderungen** (Link-Deaktivierung + Sperre) noch nicht gepusht — bewusst,
  weil die Auth-Änderung live wirkt und das Sperr-Feature auf echten Geräten getestet werden sollte.
- **Link-Sperre unvollständig:** bereits verifizierte Geräte (`argus_verified`) bleiben drin; echter
  Entzug braucht `revoked`-Flag / DB-Eingriff → Phase 8.
- **GSD-CLI nicht lauffähig** (`node` fehlt) → `.planning/` wird manuell gepflegt.
- **Tracking-Divergenz:** Phasen 0–2 wurden direkt am Code gebaut (nicht über GSD-execute);
  daher keine PLAN/SUMMARY-Artefakte. Phase 01-Verzeichnis enthält Alt-Pläne ohne SUMMARY.
