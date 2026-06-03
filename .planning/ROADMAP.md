# CCP-App (Argus) — Roadmap

> **Stand: 2026-06-03** — re-baselined gegen den realen Code-/Deploy-Stand.
> Hinweis: Das GSD-CLI ist in dieser Umgebung nicht lauffähig (`node` fehlt), daher
> wird `.planning/` manuell gepflegt. Status ist **code-verifiziert**, nicht über den
> GSD-execute-Loop erfasst (keine nachträglich erfundenen SUMMARY.md-Artefakte).
>
> **Milestone:** Closed Beta V1 — *läuft bereits* (kleiner autorisierter Testkreis nutzt die Live-App).
> Nächstes Milestone danach: **Open Beta**.
>
> **Legende:** ✅ fertig · 🔄 in Arbeit · ◑ teilweise · ⬜ offen

## Phase 0 — Repo-Struktur & Offline-Hülle ✅
Single-File `index.html`, `sw.js`, `manifest.json`, PWA installierbar.

## Phase 1 — Supabase-Backend & Speicherschicht-Tausch ✅
`loadPatients/savePatient/addPatient/loadMeta` auf Supabase (`patients`, `ccps`), localStorage als
Offline-Puffer, Echtzeit-Abo aktiv.

## Phase 2 — Join-Flow & Authentifizierung ✅
Präsidiumsauswahl, 8-stelliger Kurzcode, Install-Seite, `access_tokens`. **2026-06:** Legacy-
`ccps.join_token`-Pfad deaktiviert — alte Links ohne Freischaltung ungültig.

## Phase 3 — Mehrgeräte-Features verdrahten 🔄  ← AKTUELLE PHASE
- ✅ Echtzeit-Sync (Patienten + CCP-Status)
- ✅ **Patienten-Sperre** — Soft-Lock, 45 s Ablauf, Heartbeat ~15 s, 🔒-Indikator,
  MasterMedic-Override *(2026-06 gebaut)*
- ◑ MasterMedic-Rolle — Status + Übernahme-UX vorhanden; Feinschliff offen
- ⬜ **Echtes CCP-Zusammenführen** — Demo-Mechanismus nur als *Merge-Simulation* durch echte
  geräteübergreifende Logik ersetzen. **Wichtig:** Die Demo-CCPs im Präsidium „Schulungsumgebung"
  BLEIBEN als Trainingsinhalt erhalten (bis auf Widerruf) — nicht löschen.

## Phase 4 — Fotos & Storage ◑
Foto-Aufnahme + Verkleinerung vorhanden (lokal/im Datensatz). Offen: Fotos in Supabase Storage,
CCP-scoped, Offline-Queue.

## Phase 5 — Closed-Beta-Härtung & Open-Beta-Vorbereitung ⬜
> *(vorher „Closed Beta vorbereiten" — umbenannt: die Closed Beta läuft bereits)*
- Datenschutz/Compliance abarbeiten (siehe `docs/COMPLIANCE.md`): EU-Hosting bestätigen,
  Verschlüsselung, Zugriffe, Löschkonzept, MDR-Einstufung klären — **vor** echtem Patienteneinsatz.
- **Zugriffskontrolle (vorgezogene Governance-Hälfte):** `revoked`-Flag auf `access_tokens` +
  Re-Check beim Start → echter Geräte-/Link-Entzug (verlorenes iPhone, Tester entfernen). Billig,
  hoher Betriebsnutzen für die laufende Beta.
- Kurzanleitung für Tester, strukturierter Feldtest (LebEL-Übung).
- Open-Beta-Vorbereitung (breiterer Testkreis).

## Phase 6 — Governance & Nutzerverzeichnis ⬜
> *(vorgezogen — war Phase 8; jetzt vor Native App)*
**Zwei-Ebenen-Modell:** Feld-Zugang bleibt pseudonym (Code, kein Login); Admin/Rollen erhalten
echte Konten (Supabase Auth, E-Mail/Magic-Link).
- Nutzerverzeichnis: Nutzer sperren, Präsidien zuweisen/aufschalten, Codes ausgeben/widerrufen.
- RLS-Policies pro Tabelle härten (sicherheitskritisch).
- *(Die billige Entzugs-Hälfte — `revoked`-Flag — ist bereits in Phase 5 vorgezogen.)*

## Phase 7 — Lageübersicht für FLZ / ILS (read-only Dashboard) ⬜
> *(war Phase 6)*
Browserbasierte Leseansicht für FLZ/ILS: aktive CCPs, Patientenzahlen je Kategorie, ohne
personenbezogene Daten. Anonymisierte Echtzeit-Zahlen.
**Voraussetzungen:** Zuständige Leitstelle klären (FLZ vs. ILS), DSFA für Übermittlung.

## Phase 8 — Native App für PTLS Pol (nach Polizei-BW-Entscheidung) ⬜
> *(war Phase 7; bleibt das letzte, da an offizielle Übernahme gekoppelt)*
PWA via Capacitor in native iOS-App (.ipa), verteilt über den dienstlichen App-Store von PTLS Pol
(MDM, kein öffentlicher App Store).
**Voraussetzungen:** Träger-Buy-in, IT-Sicherheitsfreigabe, DSB-Abstimmung, Apple Developer
Enterprise Account (PTLS Pol).

---

## Notizen / spätere Entscheidungen
- **Production-Repo-Schnitt (später, auf Zuruf):** Beim Übergang Beta → echte Veröffentlichung die
  App in ein neues GitHub-Repo überführen und das alte deaktivieren. Dabei beachten: Git-History
  erhalten (push/transfer statt roher Kopie); **separates Supabase-Prod-Projekt** mit sauberen
  Daten + Prod-RLS + frischen Tokens; neue Pages-URL ⇒ Tester installieren PWA neu; altes Repo
  archivieren + alte URL + altes Supabase einfrieren.
- **Demo-CCPs:** bleiben im Präsidium „Schulungsumgebung" als Trainingsinhalt erhalten (bis Widerruf).
