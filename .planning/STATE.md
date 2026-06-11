# Projekt-Status — Argus (CCP-App)

- **Milestone:** Closed Beta V1 — läuft
- **Aktuelle Phase:** 4.9 Governance-Oberfläche — **IN AUSFÜHRUNG** (Wave 1
  ✅ 2026-06-11: Migration 0003 live; Wave 2 = Pläne 02+03 bereit).
  4 Pläne in 3 Wellen (geplant 2026-06-10, Checker bestanden, Commit 9b804bd).
  Phase 5 bleibt aufgeschoben. **App live: v0.22.0** (Stand 2026-06-10).
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

## Phase 4.9 — Governance-Oberfläche (IN AUSFÜHRUNG)

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

---

## Offene Entscheidungen / Hinweise

- **Repo ist public** auf GitHub — Widerspruch zur proprietären Lizenz.
  Bereinigung beim geplanten Production-Repo-Schnitt (Phase 5).
- **E-Mail-Platzhalter** in `LICENSE` + `README.md` → vor Open Beta ersetzen.
- **GSD-CLI nicht lauffähig** (`node` fehlt) → `.planning/` wird manuell gepflegt.
- **TECH_DEBT.md** noch nicht angelegt — bei Bedarf erstellen.
