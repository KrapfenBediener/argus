# CCP-App (Argus) — Roadmap

> **Stand: 2026-06-03** — re-baselined gegen den realen Code-/Deploy-Stand.
> Hinweis: Das GSD-CLI ist in dieser Umgebung nicht lauffähig (`node` fehlt), daher
> wird `.planning/` manuell gepflegt. Der Status ist **code-verifiziert**, nicht über
> den GSD-execute-Loop erfasst — es gibt bewusst keine nachträglich erfundenen
> SUMMARY.md-Artefakte für Phasen 0–2 (die wurden direkt am Code gebaut).
>
> **Legende:** ✅ fertig · 🔄 in Arbeit · ◑ teilweise · ⬜ offen

## Phase 0 — Repo-Struktur & Offline-Hülle ✅
**Ziel:** Saubere Projektstruktur, HTML als Single-File mit Service Worker, offline startbar.
**Stand:** `index.html` (Single-File), `sw.js`, `manifest.json`, PWA installierbar. Fertig.

## Phase 1 — Supabase-Backend & Speicherschicht-Tausch ✅
**Ziel:** Alle Daten laufen über Supabase statt localStorage. Echtzeit-Sync. Offline-Puffer.
**Stand:** `loadPatients/savePatient/addPatient/loadMeta` zeigen auf Supabase (`patients`, `ccps`),
localStorage als Offline-Puffer. Echtzeit-Abo (`channel().subscribe()`) aktiv.

## Phase 2 — Join-Flow & Authentifizierung ✅
**Ziel:** Kürzel → Präsidiumsauswahl → Code-Beitritt. Device-Token. MasterMedic bei Eröffnung.
**Stand:** Präsidiumsauswahl, 8-stelliger Kurzcode, Install-Seite, `access_tokens` (token/short_code/
is_master/praesidium). **2026-06: Legacy-`ccps.join_token`-Pfad deaktiviert** — alte Links ohne
Freischaltung sind ungültig; gültig nur noch provisionierte access_tokens.

## Phase 3 — Mehrgeräte-Features verdrahten 🔄  ← AKTUELLE PHASE
**Ziel:** Echte Patienten-Sperre, echte MasterMedic-Rolle, echtes CCP-Zusammenführen (kein Demo).
- ✅ Echtzeit-Sync (Patienten + CCP-Status)
- ✅ **Patienten-Sperre** — Soft-Lock, **45 s** Ablauf, Heartbeat (~15 s), 🔒-Indikator in der Liste,
  **MasterMedic-Override** per Button in der Patientenansicht *(2026-06 gebaut)*
- ◑ MasterMedic-Rolle — Status + Übernahme-UX vorhanden; Feinschliff offen
- ⬜ **Echtes CCP-Zusammenführen** — Demo-Mechanismus (`DEMO_CCPS`, `demo:true`) durch echte
  geräteübergreifende Logik ersetzen *(nächster offener Punkt)*

## Phase 4 — Fotos & Storage ◑
**Ziel:** Fotos in Supabase Storage, CCP-scoped, Offline-Queue für Upload.
**Stand:** Foto-Aufnahme + Verkleinerung vorhanden, aber lokal/im Datensatz — Supabase-Storage offen.

## Phase 5 — Closed Beta vorbereiten ⬜
**Ziel:** Datenschutz-Checkliste, HTTPS-Deployment, Kurzanleitung, Feldtest.
**Stand:** Deploy via GitHub Pages läuft bereits; Compliance/Kurzanleitung/Feldtest offen.

## Phase 6 — Lageübersicht für FLZ / ILS (read-only Dashboard) ⬜
**Ziel:** Browserbasierte Leseansicht für FLZ/ILS: aktive CCPs, Patientenzahlen je Kategorie,
ohne personenbezogene Daten. Anonymisierte Echtzeit-Zahlen.
**Voraussetzungen:** Zuständige Leitstelle klären (FLZ vs. ILS), DSFA für Übermittlung.

## Phase 7 — Native App für PTLS Pol (nach Polizei-BW-Entscheidung) ⬜
> *(war im alten Stand fälschlich als zweite „Phase 5" nummeriert)*
**Ziel:** PWA via Capacitor in native iOS-App (.ipa), verteilt über den dienstlichen App-Store
von PTLS Pol (MDM, kein öffentlicher App Store). Setzt offizielle Übernahme durch Polizei BW voraus.
**Voraussetzungen:** Träger-Buy-in, IT-Sicherheitsfreigabe, DSB-Abstimmung, Apple Developer
Enterprise Account (PTLS Pol).

## Phase 8 — Governance & Nutzerverzeichnis ⬜
> *(NEU — aus der Registrierungs-/Nutzerverwaltungs-Diskussion, 2026-06)*
**Ziel:** Administrative Verwaltung ohne die pseudonyme Feld-UX zu kompromittieren.
- **Zwei-Ebenen-Modell:** Feld-Zugang bleibt pseudonym (Code, kein Login); Admin/Rollen erhalten
  echte Konten (Supabase Auth, E-Mail/Magic-Link).
- **Nutzerverzeichnis:** Nutzer sperren, Präsidien zuweisen/aufschalten, Codes ausgeben/widerrufen.
- **`revoked`-Flag** auf `access_tokens` + Re-Check → echte Link-/Konto-Sperre (löst die heutige
  Lücke: bereits freigeschaltete Geräte können aktuell nicht entzogen werden).
- **RLS-Policies** pro Tabelle härten (sicherheitskritisch).
