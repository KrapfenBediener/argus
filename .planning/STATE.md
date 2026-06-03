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

## Phase 3 — Stand
- ✅ Patienten-Sperre (45 s + MasterMedic-Override)
- ✅ **Echtes CCP-Zusammenführen gebaut** (2026-06-03): Supabase-Schema erweitert
  (`merge_group_id`, `merge_request_from`, `merge_request_at` auf `ccps`, via Management API),
  gruppen-bewusstes Laden, Kennung-Threading, Anfrage/Bestätigung-Handshake, A bleibt MasterMedic,
  Un-Merge durch jeden MasterMedic, Demo-Pfad nur noch Schulungsumgebung. DB-Modell live verifiziert.
- → **Offen: Gerätetest** (zwei iPhones, zwei CCPs zusammenführen) + ggf. Feinschliff.
- Danach Phase 3 abgeschlossen → weiter mit Phase 4/5.

## CCP-Verwaltung (2026-06-03)
- **CCP abschließen** (MasterMedic): `closed_at` gesetzt → aus Beitritts-/Merge-Auswahl ausgeblendet,
  Daten bleiben. **CCP endgültig löschen** (nur MasterToken/`is_master`): löscht CCP + Patienten
  (FK CASCADE, DB-verifiziert). Schema: `ccps.closed_at` ergänzt.
- **Schulung zurücksetzen** (MasterMedic, nur Schulungsumgebung): löscht aktuelle Patienten und
  spielt das Demo-Szenario (DEMO_CCPS B, 8 Patienten) als **echte synchronisierte** Patienten ein.
- Bekannte Grenze: bereits abgeschlossene CCPs sind aus der App nicht mehr erreichbar (nur per DB)
  → späterer Admin-Toggle „abgeschlossene anzeigen" denkbar.

## Bekannte Grenzen Merge (v1)
- Patienten des *anderen* CCP kommen über den 3,5-s-Sync (≤3,5 s Latenz), nicht live übers Echtzeit-Abo.
- Eigenständige CCPs tragen alle Kennung „A" (Kennung wird erst beim Merge vergeben) → im Auswahl-
  Dialog unterscheidbar nur über Ort/Erstellzeit. Distinkte Kennung-Vergabe bei Erstellung = Follow-up.

## Roadmap-Änderungen (2026-06-03)
- Phase 5 umbenannt: „Closed Beta vorbereiten" → **„Closed-Beta-Härtung + Open-Beta-Vorbereitung"**
  (Closed Beta läuft bereits; Open Beta = nächstes Milestone).
- **Governance vorgezogen:** war Phase 8 → jetzt Phase 6 (vor Native App). Dashboard → Phase 7,
  Native App → Phase 8 (bleibt letztes, an Polizei-BW-Entscheidung gekoppelt).
- Billige Entzugs-Hälfte (`revoked`-Flag) in Phase 5 vorgezogen.

## Zugriffsmodell (2026-06-03, Phase 6 Stufe 1 – client-seitig)
- **Gefilterte Landingpage:** Nicht-Master sehen nur freigeschaltete Präsidien (Master: alle).
  Geräte-Freischaltliste lokal (`argus_unlocked`), temporär mit Ablauf (24 h) oder dauerhaft.
- **Freischalten** per 8-stelligem Code (Button auf Landing + Einstieg via `#code=`-Link).
- **Teilen-Link rollenabhängig:** Master teilt dauerhaften Code des Präsidiums, Nicht-Master den
  24-h-Code. `access_tokens.temporary`/`ttl_hours` ergänzt; Codes je Präsidium generiert.
- **Strikt-neu-Umstieg:** bestehende Nicht-Master-Geräte müssen ihren Präsidiums-Code 1× neu eingeben.
- **Schulungsumgebung:** Merge läuft direkt (ohne Bestätigung), da Ziel-CCPs fiktive MasterMedics haben.
- ⚠️ **Stufe 2 offen:** echte serverseitige Trennung (RLS an Identität/Präsidium) — aktuell `anon_all`
  (anon-Key darf per API alles). Braucht echte Auth. Vor Open Beta / Echtbetrieb zwingend.

## Freischaltcodes (Stand 2026-06-03)
- MasterToken (alle): `3GNN-HMEV`
- Schulungsumgebung: dauerhaft `LBYN-SFL6` · 24 h `CBFR-UFD2`
- PP Karlsruhe: dauerhaft `MTEC-9PF7` · 24 h `THY2-EP6D`

## Offene Entscheidungen / Hinweise
- **Link-Sperre unvollständig:** bereits verifizierte Geräte (`argus_verified`) bleiben drin; echter
  Entzug braucht `revoked`-Flag / DB-Eingriff → vorgezogen in Phase 5.
- **Production-Repo-Schnitt** später auf Zuruf (Details in ROADMAP „Notizen").
- **GSD-CLI nicht lauffähig** (`node` fehlt) → `.planning/` wird manuell gepflegt.
- **Tracking-Divergenz:** Phasen 0–2 wurden direkt am Code gebaut (nicht über GSD-execute);
  daher keine PLAN/SUMMARY-Artefakte. Phase 01-Verzeichnis enthält Alt-Pläne ohne SUMMARY.
