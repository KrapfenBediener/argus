# Projekt-Status — Argus (CCP-App)

- **Milestone:** Closed Beta V1 — läuft
- **Aktuelle Phase:** 4.11 Self-Hosting (T7) — **ABGESCHLOSSEN 2026-06-11,
  v0.24.0 / SW v43**: Config-Auslagerung (zentrale config.js, Plan 01) +
  Kompatibilitäts-Audit 0000–0004 und öffentliche Aufbau-Anleitung
  `docs/SELF-HOSTING.md` (Plan 02). Akzeptanz „läuft gegen zweite Instanz"
  ersatzweise belegt (Config-Isolation + extern nachvollziehbare Anleitung);
  echte Zweitinstanz-Erprobung deferred. Betriebsmodell-Entscheid M1: Polizei
  BW hostet selbst; Eigentümer-Instanz bleibt Dev/Schulung.
  **Nächster Schritt: Phase 4.12 (FLZ-Lageansicht Stufe a).**
  App live: **v0.24.0** (nach Push dieses Plans).
  **Datenschutz: technisch vollständig, offen ist nur Organisatorisches
  (+ T4/T7 nach DSB-Votum).** Nächster realer Schritt: **DSB-Gespräch**
  (Briefing aktualisiert, intern) → bestimmt Phase 5/6/7.
- **Deploy:** GitHub Pages · Repo `KrapfenBediener/argus` · Branch `main`
- **Backend:** Supabase EU (`sehuosjyjmrpzcqrelej`) · Free Tier

---

## Phase-Abschlüsse

| Phase | Name | Abgeschlossen |
|---|---|---|
| 0 | Repo-Struktur & Offline-Hülle | ✅ |
| 1 | Supabase-Backend & Speicherschicht | ✅ |
| 2 | Join-Flow & Authentifizierung | ✅ |
| 3 | Mehrgeräte-Features verdrahten | ✅ 2026-06-03 |
| 4 | Serverseitige Absicherung (JWT + RLS) | ✅ 2026-06-03 |
| 4.8 | Datenschutz-Härtung (T8, T2, T1, T3) | ✅ 2026-06-10 |
| 4.9 | Governance-Oberfläche (Einsatzprotokoll-Modell, Leitungs-Seite, Code-Sperre) | ✅ 2026-06-11 |
| 4.10 | Datenschutz-Schlusspaket (Log-Frist 12 Monate, T5 Transparenz, T6 Backup-Hygiene, Doku-Sync) | ✅ 2026-06-11 |
| 4.11 | Self-Hosting-Fähigkeit (T7: config.js, Kompatibilitäts-Audit, SELF-HOSTING.md) | ✅ 2026-06-11 |

---

## Letzter Stand (2026-06-03)

**Phase 4 abgeschlossen — serverseitige Absicherung steht:**
- Token-Exchange als Postgres-RPC `argus_exchange_code` (pgjwt + Vault) —
  abgewichen von der geplanten Edge Function (Management-API kann kein raw-TS
  deployen; Edge-Function-Datei als überholt markiert, RPC ist der echte Pfad).
- App: `exchangeCode()` ruft den RPC, `sb()` hängt JWT als Bearer + `realtime.setAuth()`,
  `refreshJwtIfNeeded()` stille Verlängerung (<7 Tage), Migration für Altgeräte.
  Neue localStorage-Keys: `argus_jwt`, `argus_jwt_exp`, `argus_code`.
- RLS: `anon_all` auf `patients`/`ccps`/`checklists` ersetzt durch `argus_*_rw`
  (gebunden an `argus_praesidium_id()` / `argus_is_master()`).
- API-E2E verifiziert: Anon ohne JWT → `[]`; Schulungs-JWT → nur 6 Schulungs-CCPs;
  Master → alle 9; `praesidien` ohne JWT lesbar.
- DB-Stand versioniert: `supabase/migrations/0001_phase4_jwt_rls.sql`.
- SW Cache v5 — Update + Migration erzwungen.
- **Praxistest auf echten Geräten bestanden:** Master-Login, Präsidiums-Trennung,
  Einmal-Link.
- **Bugfix Einmal-Codes:** RPC schrieb `used_at = now()` (timestamptz) in eine
  bigint-Spalte → Fehler 42804, Einlösung schlug fehl. Auf `(extract(epoch from
  now())*1000)::bigint` geändert (ms, konsistent mit `nowMs()`). Rein serverseitig,
  kein App-Update nötig. Verifiziert: Einlösung→JWT, danach verbraucht.

- **Sicherheitsfix `access_tokens` (kritisch):** Die offene `anon_read`-Policy
  machte alle Codes inkl. MasterToken `3GNN-HMEV` per öffentlichem Anon-Key
  abrufbar → ganze RLS umgehbar. Ersetzt durch JWT-gebundene Policies
  (`argus_tokens_select/insert/update`): Lesen nur eigenes Präsidium / Master,
  Schreiben nur Master. Anon ohne JWT → 0 Codes. Install-Screen liest nicht mehr
  aus der DB (Code steht im Link). SW Cache v6. Verifiziert.

**Phase 4 vollständig abgeschlossen.**

### Nach Phase 4 (2026-06-04)
- **Offline-Robustheit (wichtigster Fund aus dem Audit):** Offline erfasste/
  bearbeitete Patienten gingen beim Reconnect verloren (loadPatients überschrieb
  mit Cloud). Jetzt `_dirty`-Markierung + `ccpId`-Tag + `flushPendingPatients()`
  (Merge per `updated`-Zeitstempel, Nachsync per `online`-Event), Banner-Hinweis
  „⏳ n nicht synchronisiert". Merge-Logik per JSC-Unit-Test (5 Szenarien) belegt.
- **Branding:** „Argus" → „ARGUS" (UI, manifest, iOS-Titel). SW v8.
- **Entscheidung:** Phase 5 (Produktionsinfra) aufgeschoben bis nach ausgiebigerem
  Test der Beta.

### Tester-Feedback (3 Nutzer, 2026-06-04) — Pakete
- **Paket A — ✅ erledigt (v0.4.0):** gPA/Prio/„Alle Patienten" anklickbar,
  gPA-Zurückholen, Soft-Lock-Übernahme robust (Realtime + getrennte Sperr-Spalten).
- **Paket B — ✅ erledigt (v0.5.0):** Erfassungs-Screen zeigt nächste Nummer +
  zuletzt angelegten Patienten; Prio-Schnellaktion + „öffnen"-Sprung; „Was ist
  neu"-Hinweis (whatsNewModal/WHATS_NEW). [Zobel #8, Braunbeck #1/#2]
  Noch offen aus B: Rufname-Hinweis gem. REK Sonderlagen am Kürzel-Feld [Zobel #2]
  (klein, ggf. in C mitnehmen).
- **Bearbeitungssperre — ✅ repariert (v0.5.2):** Wartender prüfte die Sperre nie
  erneut → blieb nach 45 s gesperrt; beim Verlassen durch den Bearbeiter musste der
  Wartende ebenfalls raus+neu öffnen. Jetzt: Auto-Übernahme, sobald frei (Realtime
  sofort / Heartbeat ≤5 s). Offene Designfrage Timer-Visualisierung: bewusst NICHT
  umgesetzt (Empfehlung: weglassen). Auto-Übernahme statt Tap-to-Edit gewählt.
- **Update-Auslieferung — ✅ repariert (v0.5.1):** iOS-PWA blieb auf alter Version,
  weil die SW-Revalidierung ohne `event.waitUntil` lief (iOS killt den SW vor dem
  Cache-Update). Behoben + `version.json`-basierte Update-Erkennung mit
  „Jetzt aktualisieren"-Banner (= 3b, jetzt umgesetzt). **Merke:** `version.json`
  bei jedem Release gleich `APP_VERSION` setzen.
- **Paket C — weitgehend erledigt:** C1 Vitalwerte-Verlauf ✅ (v0.7.0,
  „Messung protokollieren" → `vit.log`, eingeklappt). C2 Neuro: Owner-Entscheid
  „bleibt wie es ist" (gestrichen). C3 Funktionsanzeige: Owner-Entscheid gestrichen
  (kleines Team kennt Rollen). [Schill, Zobel #1]
- **C4 Rufname-Hinweis:** Owner-Entscheid „passt wie es ist", keine Änderung. ✅

**→ Tester-Feedback-Runde (3 Nutzer) vollständig abgearbeitet** (Pakete A–C, v0.4.0–v0.7.0).

### Zusätzlich
- **v0.8.0 — Erst-Einführung (Onboarding):** 4-Karten-Intro bei echter
  Neuinstallation (überspringbar, kein Swipe), re-aufrufbar via Hilfestellungen.
  Erkennung über `argus_intro_seen` + leeres localStorage; Re-Unlock für weiteres
  Präsidium löst es nicht aus; bestehende Nutzer bekommen es nicht.
- **Laufend:** Verständlichkeit/Begriffe für Laien [Zobel #6].
- **Organisatorisch:** DSB-Gespräch vor PP-/Landes-Umsetzung [Zobel #5];
  Vertriebs-/Erweiterungsidee PTLS/Personensammelstelle [Schill] — geparkt.

### Härtungsfenster nach Phase 4.5 (2026-06-05 … 06-08) — v0.16 → v0.19.5
Iterative Feature-/Schulungsarbeit im Test-/Härtungsfenster (keine geplante Phase;
Phase 5 bleibt aufgeschoben):

- **AT-MIST-Übergabekarte (v0.17.0):** Beim Auschecken (→ gPA) erscheint eine
  gesperrte Vorlese-Karte (Kopf + A/T/M/I/S/T) für die strukturierte Übergabe an die
  gPA. Bewusste Abgrenzung: ARGUS bleibt Polizei/CCP-fokussiert, Schnittstelle =
  Übergabe (IVENA eHealth recherchiert, Integration verworfen).
- **Geführtes interaktives Training (v0.18.0 → v0.19.5):** kompletter geführter
  36-Lektionen-Durchlauf durch die App, erreichbar über die Schulungsumgebung.
  - Geräte-LOKALER Sandbox: Übungsdaten (`training:true`) werden NIE synchronisiert;
    eigener lokaler Ephemer-CCP (`train-ccp`) → kein Cloud-Leck, **kein manuelles
    Zurücksetzen** der Schulungsumgebung nötig, beliebig oft wiederholbar.
  - 3-Modus-Modell (explain / do / choice), Spotlight mit Verdeckungs-Erkennung,
    Scroll auf sticky-Topbar + Panelhöhe abgestimmt, design-konform (Schiefer statt Lila).
  - Erst-Intro (Onboarding) verweist am Ende auf das Training (5. Slide).
  - **DAUERREGEL:** bei jeder UI-/Funktionsänderung das Trainings-Drehbuch
    (`TRAIN_LESSONS`) mit-anpassen.
- **Produkt-Website** im ARGUS-Design — unauffindbar + `noindex` auf GitHub Pages
  deployt (Demo). Referenz-Optik: `docs/UI-AUSBLICK.html`.
- **IP-/Doc-Hygiene:** interne Planungs-/Compliance-Docs und experimentelle Decks aus
  dem öffentlichen Repo entöffentlicht (`.gitignore`); `UPDATE_*.html` bleiben öffentlich
  (aus der App verlinkt). Royal-Stil-Logos verworfen. Marken-/Domain-Schritte bis nach
  DSB / Pol-BW zurückgestellt.
- **Design-Sprache fixiert:** `docs/UI-AUSBLICK.html` = verbindliche Optik (IBM Plex,
  hell, Schiefer `#1f2530` als Chrome, Triage-Farben nur funktional). Kein Apple-/Royal-Stil.

*Testing weiterhin ohne `node` — Logikprüfung via JavaScriptCore (`osascript -l JavaScript`),
kein Browser verfügbar.*

### Offene Audit-Punkte (geparkt, nach Bedarf angehen)
- Laufnummern-Kollision bei parallelem Anlegen: **Doppelnummer-Warnung eingebaut**
  (Banner/Liste/Detail, kein Auto-Umnummerieren — Nummer steht auf der Haut).
  Optionaler Tiefenfix (serverseitige Nummernvergabe) nur bei Bedarf.
- JWT-Ablauf in sehr langer Dauer-Session (Refresh läuft nur bei Start/`online`).
- Fotos als base64 inline → Supabase Storage (vor großem Rollout).
- DSGVO-Löschkonzept, Master-Code-Rotation, Repo-Schnitt, Pro-Tier → Phase 5.
- **PAT widerrufen** (war zuletzt noch aktiv).

**Geparkt (nicht blockierend):**
- Daten-Hygiene: 3 verwaiste CCPs mit `praesidium_id = NULL` (nur Master sichtbar)
  → beim Production-Schnitt (Phase 5) bereinigen.

---

## Phase 4.8 — Datenschutz-Härtung (ABGESCHLOSSEN 2026-06-10, v0.22.0)

**Planung abgeschlossen:** 6 Pläne in 5 Wellen (`.planning/phases/04.8-datenschutz-haertung/`),
Plan-Checker-Durchlauf bestanden (1 MAJOR + 4 MINOR gefunden und eingearbeitet, Commit 54baaf2).
Einziger nicht-autonomer Punkt: Plan 04.8-02 braucht einen ephemeren Supabase-PAT (Checkpoint).

**Ausführungsstand (Welle 1):**
- **04.8-02 ✅ (2026-06-10):** Migration `0002_phase48_datenschutz.sql` geschrieben,
  live angewendet (Management API, idempotent) und verifiziert — Einsatz-Lebenszyklus-
  Spalten, `purge_log`/`governance_log`, 5 `argus_*`-RPCs, RLS-Split (abgeschlossener
  Einsatz für Nicht-Master schreibgesperrt, per REST nicht umkehrbar), pg_cron-Job
  `argus_purge` (stündlich, läuft — Free Tier hat pg_cron). Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-02-SUMMARY.md`. Commit 8fcb675.
  **Noch zu pushen** (Executor-Umgebung ohne GitHub-Credentials).
- **PAT widerrufen:** der für 04.8-02 genutzte ephemere PAT ist noch aktiv →
  im Supabase-Dashboard widerrufen (zusammen mit dem offenen Alt-PAT aus Phase 4).

**Ausführungsstand (Welle 2):**
- **04.8-03 ✅ (2026-06-10, v0.20.0):** T2 in der App nutzbar — „Einsatz
  abschließen" (MasterMedic, Typ Übung 14 / Einsatz 30 Tage, Frist 1–365
  anpassbar), Übergabe-Export (JSON via iOS-Teilen/Download + druckbare
  AT-MIST-Gesamtansicht; Name nur wenn erfasst, **nie** Fotos), lokale
  Bereinigung auf allen Geräten (Realtime-Pfad in `applyMeta`, init,
  online-Handler), Offline-Queue `argus_pending_close` + `flushPendingClose`,
  opportunistischer `argus_run_purge`. Legacy „CCP abschließen" (Home) führt
  jetzt in den neuen Workflow (Abweichung, dokumentiert). Drehbuch + Release
  v0.20.0 (SW v37, UPDATE_v0.20.html). JSC-Tests 23/23 PASS. Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-03-SUMMARY.md`.
  Commits 5a7b03c · 0454595 · 378ccab. **Gepusht** (c291e6f..9d5a362, Credentials
  waren wieder gültig) — GitHub Pages deployt v0.20.0; damit ist auch der noch
  offene 04.8-02-Stand (8fcb675) mit hochgegangen.

**Ausführungsstand (Welle 3):**
- **04.8-04 ✅ (2026-06-10, v0.21.0):** T1 App-Teil 1 — einsatzweiter Schalter
  „Fotos erlauben" (Default AUS, nur MasterMedic/Eröffner, synct über
  `ccps.photos_allowed` via Realtime/`loadMeta`; im Verbund Update aller Rows
  der merge_group), Kamera-Gating in `vPatient` (Aufnahme-Elemente nur bei
  Schalter an, bestehende Fotos bleiben sichtbar, defensiver Upload-Abbruch),
  Zweck-Hinweis (Wiedererkennung statt Name, 72 Std, automatische Löschung).
  Foto ab Auscheckung (gPA) komplett aus der Normalansicht (zentrale
  Render-Bedingung `photoVisible(p)` für Listen-Pill/Detail/Zoom); „Zurückholen"
  reaktiviert ohne Neufoto, `p.photo` bleibt unangetastet (Governance-Fenster
  04.8-05 bleibt möglich). Training: Foto-Lektion angepasst + Schalter-Lektion
  neu; `_photosAllowed` im Trainings-Sandbox lokal an (train-ccp synct nie).
  Release v0.21.0 (SW v38, UPDATE_v0.21.html). JSC: Syntax OK, photoVisible
  7/7 PASS. Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-04-SUMMARY.md`.
  Commits 121d6db · 0ef87ef · f716d65. **Gepusht** (14d91bc..f716d65) —
  GitHub Pages deployt v0.21.0.

**Ausführungsstand (Welle 4):**
- **04.8-05 ✅ (2026-06-10, v0.21.1):** T1 App-Teil 2 — Foto-Governance-Panel
  (View `governance`, Einstieg in der Administration, nur `_isMaster` =
  MasterUser-Token, getrennt vom MasterMedic): Liste via
  `argus_governance_list` (gruppiert nach CCP, Status abgeschlossen/offen,
  Frist de-DE, **ohne** Bilddaten); Foto-Einzelabruf via
  `argus_governance_photo` (Kürzel-Pflicht, Overlay mit Protokoll-Hinweis —
  jeder Abruf = serverseitiger `governance_log`-Eintrag); Fristverlängerung
  `argus_extend_photo_frist` (+72 h, Pflicht-Begründung mit Leer-Abweisung,
  confirmModal mit Export-Hinweis „zuständige Stelle"); Wiedervorlage-Block
  (Frist abgelaufen / < 24 h, `fristStatus` JSC-getestet 10/10); einklappbare
  Protokoll-Ansicht (letzte 100 `governance_log`-Einträge). Verlängern-Knopf
  nur bei gesetzter Frist (sonst würde der RPC bei offenem Einsatz eine
  Löschfrist ERZEUGEN — dokumentierte Abweichung). Panel nur online (kein
  Einsatz-Werkzeug, Local-first unberührt). Drehbuch geprüft: keine
  Lektionsänderung (reine MasterUser-Funktion). Release v0.21.1 (SW v39,
  kein eigenes Update-Sheet — v0.21-Sheet deckt die Foto-Härtung ab). Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-05-SUMMARY.md`.
  Commits 2e82f03 · a68fc4e · 5b284ff.

**Ausführungsstand (Welle 5 — Phasenabschluss):**
- **04.8-06 ✅ (2026-06-10, v0.22.0):** T3 Namensfeld-Härtung — Hinweis am
  Namensfeld („Nur erfassen, wenn für Versorgung/Übergabe erforderlich."),
  Patientenliste ohne Namens-Spalte (einziger Renderer `vCatlist`, gilt für
  Kategorie/Alle/Prio/gPA — Nummer + Pills identifizieren, Sichtungszeit/TQ als
  Hauptzeile), keine Namens-Suche/-Sortierung/-Filterung (Grep-Beleg + Kommentar
  an der Sortier-Stelle), Freitext-Hinweis „Keine Namen Dritter — nur
  versorgungsrelevante Fakten." („Verlauf / Karte"), Übergabekarte/Export
  unangetastet (Name im Übergabe-Kontext weiterhin, wenn erfasst). Drehbuch:
  neue Lektion „Stammdaten: pseudonym" (Spotlight `#ph-stamm`). Einsatz-Schalter
  fürs Namensfeld bewusst NICHT gebaut (zurückgestellt bis DSB-Votum). Release
  v0.22.0 (SW v40, kein eigenes Update-Sheet — WHATS_NEW genügt). Interne
  Statusführung synchron gezogen (SPEC-Akzeptanzkriterien, Maßnahmenplan —
  lokal, gitignored). Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-06-SUMMARY.md`.

**→ Phase 4.8 abgeschlossen.** Bewusst offen: Namensfeld-Einsatz-Schalter
(nach DSB-Votum), T4 Audit-Log (gesperrt bis DSB-Votum „JI-Regime"),
Live-Verifikationen am echten Gerät (Governance-Panel, 72-h-Foto-Lauf).

DSB-unabhängige P1-Tasks aus `docs/datenschutz/DATENSCHUTZ-SPEC.md` (erstellt
2026-06-10, Dossier 00–08): T2 Einsatz abschließen + Auto-Löschung (Fundament),
T1 Foto-Härtung + Governance-Panel, T3 Namensfeld-Härtung, T8 externe
Laufzeit-Abhängigkeiten entfernen. T4 (Audit-Log) bleibt bis DSB-Votum gesperrt.
Danach: Phase 5 — Produktionsinfrastruktur (Pro-Tier, separates Prod-Projekt,
Repo-Schnitt, Backup-/Löschkonzept). Siehe `.planning/ROADMAP.md`.

*Hinweis 2026-06-10: `docs/datenschutz/` und weitere interne Unterlagen sind
gitignored — Repo ist public.*

---

## Phase 4.9 — Governance-Oberfläche (ABGESCHLOSSEN 2026-06-11, v0.23.0)

**Planung:** 4 Pläne in 3 Wellen (geplant 2026-06-10, Checker bestanden,
Commit 9b804bd). Kern: Einsatzprotokoll-Modell (Owner-Entscheid 2026-06-10) —
einheitliche 72-h-Grundfrist, Fotos hart ohne Verlängerung, jeder
Protokoll-Abruf protokolliert, separate Desktop-Leitungs-Oberfläche,
Code-Sperre (`revoked`), Governance-Rückbau in der Feld-App.

**Ausführungsstand (Welle 1):**
- **04.9-01 ✅ (2026-06-11):** Migration `0003_phase49_einsatzprotokoll.sql`
  geschrieben, live angewendet (Management API, 2× = Idempotenz-Beleg) und
  verifiziert — Einsatzprotokoll-Modell serverseitig komplett:
  `access_tokens.revoked` + Prüfung in `argus_exchange_code` („Code wurde
  gesperrt"); neuer Re-Check-RPC `argus_check_code` (`{found, revoked}`, ohne
  Seiteneffekte); `argus_close_einsatz` setzt einheitlich 72-h-Fristen
  (`p_frist_tage` wird ignoriert — signaturkompatibel zu v0.22.0); neue RPCs
  `argus_governance_einsaetze` (Liste, Filter = Purge-Bedingung (b)) und
  `argus_governance_protokoll` (Zwangs-Log `protokoll_view` VOR Rückgabe,
  Patienten ohne Foto-Daten, nur `has_photo`); `argus_extend_protokoll_frist`
  verlängert NUR `purge_after` (Fotos hart, 72 h); `argus_governance_list` und
  `argus_extend_photo_frist` ENTFERNT; RLS: patients/checklists geschlossener
  Einsätze für Nicht-Master nicht mehr lesbar, ccps-Tombstone bleibt lesbar.
  Funktions- und REST-Negativtests grün, Seed-Daten restlos entfernt. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-01-SUMMARY.md`.
  Commit e4a7909.
- **Bekannte Übergangs-Abweichung (akzeptiert):** v0.22.0-Altgeräte zeigen beim
  Abschluss noch „14/30 Tage", der Server löscht ab jetzt nach **72 h** — Daten
  werden FRÜHER gelöscht als angezeigt. Gilt bis v0.23.0 (Plan 04.9-03);
  das alte Feld-App-Governance-Panel zeigt auf Master-Geräten bis dahin einen
  Fehlertext (argus_governance_list entfernt).
- **PAT widerrufen:** der für 04.9-01 genutzte ephemere PAT ist noch aktiv →
  im Supabase-Dashboard widerrufen (zusammen mit ggf. offenen Alt-PATs).

**Ausführungsstand (Welle 2):**
- **04.9-02 ✅ (2026-06-11):** Leitungs-Oberfläche (Desktop-Governance-Seite)
  gebaut — Single-File unter nicht erratbarem Dateinamen (D-06: Name steht
  AUSSCHLIESSLICH in der untracked, gitignorten `LEITUNG-URL.md`; in keiner
  committeten Datei, keinem Commit-Text — git-grep-Gate grün). MasterToken-Login
  via `argus_exchange_code` mit is_master-Pflicht (Abweisung ohne Speicherung),
  Sitzung flüchtig in sessionStorage (`argusl_jwt`/`argusl_jwt_exp`/
  `argusl_kuerzel`); Direkteinstieg „Zugänge" (D-10), Phase-7-Sektion sichtbar
  gesperrt (D-09). Zugänge: Codes je Präsidium Dauerhaft/24 h/Einmalig +
  Code-Sperre über `revoked` (MasterToken-Zeilen nicht sperrbar, D-11);
  Einsatzprotokolle: Wiedervorlage oben, protokollierter Abruf
  (`argus_governance_protokoll`, Hinweis-Modal + Kürzel-Pflicht, D-01),
  Foto-Lazy-Load, harte Foto-Frist ohne Verlängerungs-UI (D-02),
  Protokoll-Frist +72 h nur mit Pflicht-Begründung (D-03); Protokoll:
  governance_log (200) + purge_log (100, inhaltsfrei, D-13). JSC: Syntax OK,
  fristStatus 10/10, genShortCode/genToken PASS; Smoke-Test (http.server) alle
  Assets 200. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-02-SUMMARY.md`.
  Commits 0f7c61e · 4933231 · 4ed858e. **Noch nicht gepusht** — Seite wird mit
  dem nächsten Deploy via GitHub Pages erreichbar.
- **Offener Owner-Punkt (04.9-02):** Live-Verifikation der Leitungs-Seite im
  Browser (URL siehe lokale `LEITUNG-URL.md`): MasterToken-Login, Code-Sperre-
  Roundtrip, Protokoll-Abruf inkl. governance_log-Eintrag. `LEITUNG-URL.md`
  lokal sichern — sie ist die einzige Fundstelle des Dateinamens.
- **04.9-03 ✅ (2026-06-11, v0.23.0):** Feld-App auf das Einsatzprotokoll-Modell
  umgestellt — Governance-Insel restlos entfernt (View, Einstieg, 4 Handler,
  Zustandsvariablen, `fristStatus`/`govFmt`; D-14 „keine Foto-Insel in der App",
  Leitungs-Funktionen nur noch auf der separaten Leitungs-Oberfläche);
  Abschluss-Workflow auf feste 72-h-Grundfrist (14/30-Wahl + freie Frist-Eingabe
  entfernt, Typ Übung/Einsatz bleibt Merkmal; `argus_close_einsatz` ohne
  Frist-Parameter; Offline-Queue-Payload `{ccpId,typ,ts}`, v0.22.0-Legacy-Einträge
  mit fristTage bleiben gültig); Übergabe-Export im Workflow prominent als
  EINZIGER dauerhafter Weg ausgewiesen (D-04); revoked-Re-Check
  (`checkRevokedCode`/`revokedDecision`, fire-and-forget bei Start + online-Event,
  offline-Guard VOR dem fetch, 6-s-Abort-Timeout — Sperrung NUR bei eindeutigem
  `revoked===true`, found:false/Fehler → ignore; `applyRevokedLock` räumt
  JWT/Code/Freischaltungen/Rollen, kappt Realtime, Hinweis-Modal, Freischalt-Screen;
  Sperr-Klartext „Code wurde gesperrt" erscheint auch beim Freischalten/Re-Exchange);
  Drehbuch auf 72-h-Modell (keine 14/30-Texte mehr). Release v0.23.0 (SW v41,
  CHANGELOG, WHATS_NEW, UPDATE_v0.23.html inkl. „Bitte App aktualisieren"-Hinweis
  wegen v0.22.0-Fristen-Anzeige). JSC: 17+25 Checks PASS, Syntax beider
  Inline-Blöcke OK. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-03-SUMMARY.md`.
  Commits 18cbff6 · 71bc5e7 · 7834610. **Noch nicht gepusht** (Plan: nicht pushen);
  „App live" bleibt v0.22.0 bis zum Deploy.
- **Offener Owner-Punkt (04.9-03):** Live-Verifikation am echten iPhone —
  Update-Banner v0.23.0, Abschluss-Strecke (72-h-Texte), Sperr-Test
  (Code sperren → Gerät meldet sich beim Start/Reconnect ab).

**Ausführungsstand (Welle 3 — Phasenabschluss):**
- **04.9-04 ✅ (2026-06-11):** Doku/Statusführung (D-05) — interne
  Datenschutz-Dokumente (`05-LOESCHKONZEPT.md`, `DATENSCHUTZ-SPEC.md`,
  `08-MASSNAHMENPLAN.md`; alle gitignored, NUR lokal editiert, nicht
  committet) auf das Einsatzprotokoll-Modell nachgezogen: einheitliche
  72-h-Grundfrist statt 14/30 Tage (alte Fristen als „überholt" markiert),
  Fotos 72 h hart ohne Verlängerung, neuer Abschnitt „Einsatzprotokoll-Modell
  (Owner-Entscheid 2026-06-10)" im Löschkonzept, Abschnitt 2a auf
  Protokoll-Frist (`purge_after`, RPC `argus_extend_protokoll_frist`)
  umgeschrieben, Abweichungsvermerke an T1/T2 der SPEC (Datum + „Phase 4.9"),
  Maßnahmenplan synchron (Fristen, Governance/Leitungs-Oberfläche,
  Code-Sperre). ROADMAP/STATE finalisiert. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-04-SUMMARY.md`.
- **D-06-Phasen-Abschluss-Gate bestanden:** `git grep` über alle getrackten
  Dateien (Muster des Leitungs-Seiten-Dateinamens) → 0 Treffer; der konkrete
  Name steht ausschließlich in der untracked, gitignorten `LEITUNG-URL.md`.

**→ Phase 4.9 abgeschlossen. Offene Owner-Punkte (gesammelt):**
1. **Push/Deploy der Phase-4.9-Commits** (macht der Orchestrator nach dem
   finalen Gate) — erst danach sind Leitungs-Seite und v0.23.0 im Feld.
2. **PAT widerrufen** (aus 04.9-01; Supabase-Dashboard → Account → Access
   Tokens) — zusammen mit ggf. noch offenen Alt-PATs (Phase 4 / 04.8-02).
3. **Browser-Live-Test der Leitungs-Seite** (nach Deploy; URL siehe lokale
   `LEITUNG-URL.md` — lokal sichern, einzige Fundstelle des Dateinamens):
   MasterToken-Login, Code-Sperre-Roundtrip, Protokoll-Abruf inkl.
   governance_log-Eintrag, Frist-Verlängerung.
4. **iPhone-Live-Test v0.23.0** (nach Deploy): Update-Banner, Abschluss-Strecke
   (72-h-Texte, Typ-Wahl ohne Fristen), Sperr-Test (Code über die
   Leitungs-Oberfläche sperren → Gerät meldet sich beim Start/Reconnect ab).
5. **Bekannte, AKZEPTIERTE Übergangs-Abweichung:** Geräte auf v0.22.0 zeigen
   beim Einsatz-Abschluss noch „Löschung nach 14/30 Tagen" an, der Server
   löscht aber bereits nach **72 h** (FRÜHER als angezeigt). Erledigt sich,
   sobald alle Geräte auf v0.23.0 aktualisiert sind — das UPDATE-Sheet
   (UPDATE_v0.23.html) bittet ausdrücklich ums Update.
6. **Beobachtung (aus 04.9-03):** die älteren `docs/UPDATE_*.html`-Sheets
   (v0.17–v0.21) haben KEIN noindex-Meta (das neue v0.23-Sheet hat eines).
   Owner-Entscheid offen: nachrüsten oder bewusst öffentlich lassen (sie sind
   aus der App verlinkt).

---

## Phase 4.10 — Datenschutz-Schlusspaket (ABGESCHLOSSEN 2026-06-11, v0.23.1)

**Planung:** 3 Pläne in 3 Wellen (geplant 2026-06-11, Checker PASS ohne Blocker).

**Ausführungsstand (Welle 1):**
- **04.10-01 ✅ (2026-06-11):** Migration `0004_phase410_log_retention.sql` —
  Log-Löschfrist 12 Monate (D-01, Modell § 73 Abs. 5 PolG BW): `argus_run_purge`
  per create or replace um Schritt (d) erweitert — `governance_log` (bigint-ms,
  Cutoff 365 Tage) und `purge_log` (timestamptz, Zwölf-Monats-Intervall) werden
  im bestehenden stündlichen Purge-Lauf gelöscht; Schritte (a)–(c) byte-gleich
  aus 0002, Cron-Job `argus_purge` wörtlich unverändert; Schritt (d) erzeugt
  selbst KEINEN Log-Eintrag (keine Rekursion, kein Spam). Return-JSON additiv
  um `log_retention` erweitert. Live angewendet (Management API, 2× =
  Idempotenz-Beleg), Funktionstest mit synthetischen Alt-/Jung-Logs (alt
  gelöscht, jung erhalten, kein Rekursions-Eintrag, restlos aufgeräumt),
  REST-Probe mit Anon-Key → HTTP 200 inkl. `log_retention`. Details:
  `.planning/phases/04.10-datenschutz-schlusspaket/04.10-01-SUMMARY.md`.
  Commit 2eb27df.
- **PAT widerrufen (Owner-Punkt):** der für 04.10-01 genutzte ephemere PAT ist
  noch aktiv → im Supabase-Dashboard (Account → Access Tokens) widerrufen —
  zusammen mit ggf. noch offenen Alt-PATs (Phase 4 / 04.8-02 / 04.9-01).

**Ausführungsstand (Welle 2):**
- **04.10-02 ✅ (2026-06-11, v0.23.1):** T5 Transparenz & Betroffenenrechte
  (D-02) — In-App-Datenschutzhinweis als statische, offline verfügbare Ansicht
  „Datenschutz" (View `vDatenschutz()`, Einstieg ghost-Button in den
  Hilfestellungen, titles/Dispatch/back() verdrahtet): sechs Art.-13-Abschnitte
  (Verantwortlicher, Zwecke, Datenarten, Fristen [72 h / Fotos hart /
  Logs 12 Monate — seit 04.10-01 serverseitig wahr], Betroffenenrechte inkl.
  Art.-15-Auskunft über den Einzelpatient-/Einsatz-Export, DSB-Kontakt).
  Verantwortlicher/DSB zentral über die Platzhalter-Konstante `DS_KONTAKT`
  pflegbar (Owner-Punkt: vor Echtbetrieb befüllen). Öffentlich-tauglich:
  Negativ-Greps (§ 82 / Auftragsverarbeitung) = 0, kein Klarname im
  View-Körper. Dazu D-05: noindex-Meta in den fünf Alt-UPDATE-Sheets
  (v0.9–v0.21) nachgerüstet (alle 6 Sheets jetzt noindex) und Fußzeilen-Verweis
  auf der Leitungs-Seite („Datenschutzhinweis: in der ARGUS-App unter
  Hilfestellungen → Datenschutz."). Drehbuch: Hilfestellungen-Lektion nennt
  den Datenschutzhinweis. Release v0.23.1 (SW v42, CHANGELOG, WHATS_NEW;
  KEIN eigenes UPDATE-Sheet — Diskretions-Entscheid „klein"). JSC: Syntax OK
  (index.html-Inline-Block + sw.js). D-06-Gate repo-weit grün (0 Treffer).
  Details:
  `.planning/phases/04.10-datenschutz-schlusspaket/04.10-02-SUMMARY.md`.
  Commits d2aa15e · 18031e1 · b75f289. **Gepusht/deployt** (bis 6a1ca2c) —
  App live: v0.23.1.

**Ausführungsstand (Welle 3 — Phasenabschluss):**
- **04.10-03 ✅ (2026-06-11):** T6 Backup-Hygiene + interne Doku-Sync +
  Statusführung (D-03/D-04) — alle docs-Änderungen NUR lokal (gitignored,
  nicht committet):
  - **T6:** `docs/BACKUP.md` neu gefasst — drei verbindliche Regeln (niemals
    Echtdaten [Fiktivdaten-Regel], Aufbewahrung max. 30 Tage, Verschlüsselung
    verpflichtend mit dokumentierten Befehlen `zip -e` / `openssl enc
    -aes-256-cbc -pbkdf2` — alternativ Abschaffung; Empfehlung dokumentiert).
    Befund Bestandsaufnahme `~/ARGUS-Backups/`: 1 unverschlüsselte Backup-JSON
    vom 2026-06-05 (51 KB, Rechte 0600, innerhalb 30 Tage) + README; KEIN
    Workflow erzeugt automatisch Backups (nur manuelles
    `scripts/argus_backup.py`; keine GitHub-Workflows/crontab/LaunchAgents).
    Bestand unangetastet — Bereinigung ist Owner-Punkt (unten).
  - **Doku-Sync:** VVT (Dok. 01) §7 auf 72-h-Einsatzprotokoll-Modell +
    Log-Frist 12 Monate (Migration 0004); DSB-BRIEFING md+html inhaltlich
    identisch auf Ist-Stand v0.23.1 gehoben (72-h-Modell, Leitungs-Oberfläche
    ohne Dateinamen [D-06], Code-Sperre, Logs 12 Monate, T5-Hinweis in der
    App; frühere Fragen 4 [Fristen] und 5 [Foto] → „umgesetzt, Bestätigung
    erbeten"); SPEC: T5/T6 abgehakt (✅ Phase 4.10, 2026-06-11) + Ergänzung
    „Log-Aufbewahrung 12 Monate" mit T4-Abgrenzung (KEIN Audit-Log gebaut);
    Maßnahmenplan synchron (T5/T6/Auskunfts-Export abgehakt, Log-Frist +
    Doku-Sync unter Erledigt).
  - **Commit-Hygiene-Gate (gesamte Phase):** git-log seit 2026-06-11 und
    git-status über docs/datenschutz, DSB-BRIEFING.*, BACKUP.md → leer;
    D-06-Gate (`git grep -cE 'leitung-[0-9a-f]{6,}' -- ':!docs/'`) → 0.
  Details:
  `.planning/phases/04.10-datenschutz-schlusspaket/04.10-03-SUMMARY.md`.

**→ Phase 4.10 abgeschlossen. Datenschutz: technisch vollständig, offen ist
nur Organisatorisches (+ T4/T7 nach DSB-Votum).**

**Offene Owner-Punkte (gesammelt, Stand 2026-06-11):**
1. **PAT widerrufen** (aus 04.10-01; Supabase-Dashboard → Account → Access
   Tokens) — zusammen mit ggf. noch offenen Alt-PATs (Phase 4 / 04.8-02 /
   04.9-01).
2. **Backup-Bestand bereinigen:** `~/ARGUS-Backups/argus-backup-20260605-142432.json`
   (unverschlüsselter DB-Vollexport inkl. Zugangscodes, vom 2026-06-05)
   verschlüsseln (`zip -e` / `openssl enc`, Befehle in docs/BACKUP.md) **oder
   löschen — Empfehlung: löschen** (nur Übungsdaten, Struktur reproduzierbar).
3. **`DS_KONTAKT` befüllen** (aus 04.10-02; Konstante oben in index.html):
   Verantwortlicher + DSB-Kontakt vor Echtbetrieb eintragen — bis dahin
   zeigen beide Abschnitte gekennzeichnete Platzhalter.
4. **Push/Deploy:** Wellen 1–2 der Phase 4.10 sind gepusht/deployt (bis
   6a1ca2c, App live v0.23.1); die Statusführungs-Commits dieses Plans gehen
   mit dem Plan-Abschluss-Push hoch.
5. **Live-Test-Punkte aus 4.9 weiterhin offen:** Browser-Test der
   Leitungs-Seite (URL siehe lokale `LEITUNG-URL.md`): MasterToken-Login,
   Code-Sperre-Roundtrip, Protokoll-Abruf inkl. governance_log-Eintrag,
   Frist-Verlängerung; iPhone-Test v0.23.0/v0.23.1: Update-Banner,
   Abschluss-Strecke (72-h-Texte), Sperr-Test, neu: Datenschutz-Ansicht in
   den Hilfestellungen.
6. **DSB-Gespräch ist der nächste reale Schritt** — Briefing (md+html, intern)
   ist auf dem Stand des Live-Systems (72 h, Logs 12 Monate, v0.23.1) und
   kann unverändert mitgenommen werden.

---

## Phase 4.11 — Self-Hosting-Fähigkeit (ABGESCHLOSSEN 2026-06-11, v0.24.0)

**Planung:** 2 Pläne in 2 Wellen (geplant 2026-06-11, Checker PASS ohne
Blocker, voll autonom — kein PAT nötig).

**Ausführungsstand (Welle 1):**
- **04.11-01 ✅ (2026-06-11, v0.24.0):** Config-Auslagerung (D-01) —
  Supabase-URL + Anon-Key aus index.html und der Leitungs-Seite in die
  zentrale, build-freie `config.js` im Projektroot gezogen
  (`window.ARGUS_CONFIG`, globales Script statt JSON+fetch — synchron,
  offline-tauglich): einzige Stelle für den Instanz-Tausch beim
  Betriebsmodell M1, enthält nur die ohnehin öffentlichen Werte.
  SUPA_URL/SUPA_KEY werden abgeleitet statt definiert — alle Aufrufstellen
  (sb(), fetch-RPCs) und die Speicher-Naht unverändert. Fehlerpfad ohne
  native Dialoge: `_configError` → Statusbanner-Hinweis + Start-Toast
  (Feld-App), roter Hinweis in der Login-Box + Login-Abfang (Leitungs-Seite);
  exchangeCode/checkRevokedCode/doUnlock fangen hart ab (sonst liefen
  fetch-RPCs bei leerer URL relativ gegen den eigenen Origin → kryptischer
  404). sw.js: config.js im Precache, CACHE_NAME v43. Release v0.24.0
  (APP_VERSION, version.json, CHANGELOG, WHATS_NEW knapp; KEIN UPDATE-Sheet —
  für Nutzer unsichtbar). Gates grün: URL/Key-Isolation (git grep über
  *.html/*.js = exakt config.js), config.js NICHT gitignored, Precache-
  Konsistenz, JSC-Syntax (beide Inline-Scripts + sw.js + config.js),
  Smoke-Test HTTP 200, D-06 repo-weit 0 Treffer. Drehbuch geprüft: keine
  Lektionsänderung (keine UI-/Bedienungsänderung). Details:
  `.planning/phases/04.11-self-hosting/04.11-01-SUMMARY.md`.
  Commits d99c048 · 8481428 · 5e9ac55.

**Ausführungsstand (Welle 2 — Phasenabschluss):**
- **04.11-02 ✅ (2026-06-11):** Kompatibilitäts-Audit 0000–0004 (D-03) +
  öffentliche Aufbau-Anleitung `docs/SELF-HOSTING.md` (D-02, committet,
  328 Zeilen) — Zielgruppe fachkundige Admin-Person ohne Projektkenntnis:
  Varianten A (Supabase self-hosted via Docker Compose, empfohlen) / B
  (Postgres + PostgREST, ehrlich: Realtime entfällt → kein Live-Sync,
  Vault-Ersatzweg nötig); Audit-Tabelle pgjwt (Pflicht) / Vault-Secret
  `argus_jwt_secret` (Pflicht, MUSS dem PostgREST-JWT-Secret der Instanz
  entsprechen — kritischster Stolperstein) / pg_cron `argus_purge` (optional,
  Fallback App-Start-Purge aus 0002) / Realtime-Publikation patients+ccps
  (steht in KEINER Migration — expliziter Einrichtungsschritt) / anon-Rolle,
  je mit Prüf-SQL; Ein-Schritt-Apply, frische Codes + neuer MasterToken
  zwingend, config.js-Tausch als einziger App-Eingriff, Smoke-Test-Drehbuch
  (8 Schritte mit Erwartungsergebnissen inkl. Negativ-Prüfungen),
  Betriebsvorgaben (MDM-Dienstgeräte, Kürzel-Liste, Codes nur mündlich/Funk);
  SW-Origin-Befund als Betriebs-Voraussetzung (App-Hosting ≠ API-Origin).
  Keine Code-Änderungen (D-03: Befunde rein dokumentarisch). Negativ-Gates
  grün (keine Secrets/Interna/Leitungs-Name; D-06 repo-weit). Interne
  Statusführung lokal nachgezogen (SPEC T7 abgehakt, Maßnahmenplan,
  internes Runbook verweist auf SELF-HOSTING.md — alle gitignored). Details:
  `.planning/phases/04.11-self-hosting/04.11-02-SUMMARY.md`.

**→ Phase 4.11 abgeschlossen. Offene Owner-Punkte:**
1. **Push/Deploy** der Phase-4.11-Commits — danach ist v0.24.0 live.
2. **iPhone-Live-Test v0.24.0 (nach Deploy):** Update-Banner v0.24.0
   erscheint, App startet danach offline (config.js im SW-Precache v43),
   Code-Einlösung/Sync laufen unverändert — Live-Test der Config-Umstellung.
   Kein neuer PAT-Punkt (keine Migration in dieser Phase).
3. **Echte Zweitinstanz-Erprobung deferred:** sobald eine Zielumgebung
   (Polizei-/BITBW-Instanz oder Test-Stack) existiert, das
   Smoke-Test-Drehbuch aus `docs/SELF-HOSTING.md` einmal vollständig fahren.

---

## Offene Entscheidungen / Hinweise

- **Repo ist public** auf GitHub — Widerspruch zur proprietären Lizenz.
  Bereinigung beim geplanten Production-Repo-Schnitt (Phase 5).
- **E-Mail-Platzhalter** in `LICENSE` + `README.md` → vor Open Beta ersetzen.
- **GSD-CLI nicht lauffähig** (`node` fehlt) → `.planning/` wird manuell gepflegt.
- **TECH_DEBT.md** noch nicht angelegt — bei Bedarf erstellen.
