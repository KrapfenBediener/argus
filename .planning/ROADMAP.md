# CCP-App (ARGUS) — Roadmap

> **Stand: 2026-06-11** — Phase 4 abgeschlossen; danach Beta-Härtung aus Tester-
> Feedback (v0.4.0–v0.15.0, siehe Phase 4.5), Feature-/Schulungs-Arbeit im
> Test-/Härtungsfenster (v0.16–v0.19.5), Datenschutz-Härtung (Phase 4.8,
> v0.19.9–v0.22.0), Governance-Oberfläche (Phase 4.9, v0.23.0) und
> Datenschutz-Schlusspaket (Phase 4.10, v0.23.1 — Log-Frist 12 Monate,
> T5-Datenschutzhinweis, T6 Backup-Hygiene, interne Doku synchron).
> App live auf **v0.23.1** (Phase-4.9-/4.10-Commits gepusht/deployt 2026-06-11).
> Nächster realer Schritt: **DSB-Gespräch** (`docs/DSB-BRIEFING.md`, intern;
> aktualisiert 2026-06-11) → es bestimmt, was Phase 5/6 konkret brauchen.
>
> **Milestone:** Closed Beta V1 — *läuft* (kleiner autorisierter Testkreis).
> Nächstes Milestone: **Open Beta** (nach Phase 6).
>
> **Legende:** ✅ fertig · 🔄 in Arbeit · ⬜ offen · 🔒 conditional

---

## Phase 0 — Repo-Struktur & Offline-Hülle ✅

Single-File `index.html`, `sw.js`, `manifest.json`, PWA installierbar,
Licensing (`LICENSE`, Copyright-Header, `RECHTLICHE_HINWEISE.md`).

## Phase 1 — Supabase-Backend & Speicherschicht-Tausch ✅

`loadPatients/savePatient/addPatient/loadMeta` auf Supabase, localStorage
als Offline-Puffer, Echtzeit-Abo aktiv.

## Phase 2 — Join-Flow & Authentifizierung ✅

Präsidiumsauswahl, 8-stelliger Kurzcode, Install-Seite, `access_tokens`
(dauerhaft / 24 h / einmalig). Legacy-`ccps.join_token`-Pfad deaktiviert.
Client-seitige Freischaltliste mit Ablauflogik.

## Phase 3 — Mehrgeräte-Features verdrahten ✅

- ✅ Echtzeit-Sync (Patienten + CCP-Status)
- ✅ Patienten-Sperre — Soft-Lock, 45 s Ablauf, Heartbeat, MasterMedic-Override
- ✅ MasterMedic-Rolle — Status, sofortige Übernahme, Transparenz
- ✅ Echtes CCP-Zusammenführen — geräteübergreifend, beidseitige Bestätigung,
  kein Demo-Mechanismus mehr für reguläre Präsidien

- ✅ CCP-Verwaltung — abschließen / löschen (MasterToken) / Schulungs-Reset
- ✅ Admin-Panel — Zugangs-Links erstellen (dauerhaft / 24 h / einmalig)

---

> **Hinweis zu Phase 4 (alt) — Fotos & Supabase Storage:**
> Gestrichen aus der aktiven Roadmap. Fotos funktionieren (Base64 inline),
> die Performance-Schwelle ist bei der aktuellen Nutzerzahl nicht erreicht.
> Wird als **technische Schuld** behandelt und bei Bedarf nachgezogen.
> Tracking: `docs/TECH_DEBT.md` (anzulegen wenn relevant).

---

## Phase 4 — Serverseitige Absicherung (RLS + Auth-Fundament) ✅ 2026-06-03

**Ziel:** Die App ist gegen direkten API-Zugriff abgesichert. Der öffentliche
Anon-Key darf nur das lesen/schreiben, wozu das Gerät berechtigt ist.
Voraussetzung für jeden Einsatz mit echten Patientendaten.

- ✅ **Token-Exchange via Postgres-RPC** `argus_exchange_code` (pgjwt + Vault,
  statt Edge Function): 8-stelliger Code → signiertes JWT mit `praesidium_id`,
  `is_master`, `exp`. Kein Klarname, kein Konto — Pseudonymität gewahrt.

- ✅ **App-JWT-Integration:** `exchangeCode()`, `sb()` mit Bearer-Header +
  `realtime.setAuth()`, stille Verlängerung (`refreshJwtIfNeeded`), Migration
  für Altgeräte (einmalige Code-Neueingabe).

- ✅ **RLS-Policies** `argus_patients_rw` / `argus_ccps_rw` / `argus_checklists_rw`
  (ersetzen `anon_all`), gebunden an `argus_praesidium_id()` / `argus_is_master()`.
  `praesidien` + `access_tokens` bleiben anon-lesbar (Freischalt-Screen / Fallback).

- ✅ **Feld-UX unangetastet:** kein Login, kein Passwort.
- ✅ **Verifiziert (API-E2E):** Anon ohne JWT → `[]` auf `patients`/`ccps`;
  Schulungs-JWT → nur 6 Schulungs-CCPs; Master-JWT → alle 9.
  DB-Stand versioniert in `supabase/migrations/0001_phase4_jwt_rls.sql`.

- ✅ **Praxistest (echte Geräte):** Master-Login, Präsidiums-Trennung und
  Einmal-Link bestätigt.

- ✅ **Bugfix:** `used_at` im RPC als bigint/ms (war `now()` → Fehler 42804,
  brach Einmal-Code-Einlösung ab). Rein serverseitig behoben, kein App-Update nötig.

- ✅ **Sicherheitsfix `access_tokens`:** offene `anon_read`-Policy machte alle Codes
  (inkl. MasterToken) per Anon-Key lesbar → RLS umgehbar. Ersetzt durch JWT-gebundene
  Policies (Lesen nur eigenes Präsidium/Master, Schreiben nur Master). Anon ohne JWT
  liest jetzt 0 Codes. Verifiziert. Install-Screen liest nicht mehr aus der DB (SW v6).

## Phase 4.5 — Beta-Härtung & Tester-Feedback ✅ 2026-06-04

**Ziel:** Stabilität, Robustheit und Bedienung anhand echten Tester-Feedbacks
(3 Nutzer) und eines Selbst-Audits verbessern — ohne neue Großfeatures.
Ausgeliefert als nachvollziehbare Point-Releases **v0.4.0 – v0.15.0** (`CHANGELOG.md`).
Dazu u. a.: Update-Mechanik + visuelle Update-Sheets, Foto-Vollbild, Doppeltipp-/
Zoom-Schutz, „Verwerfen"/TQ beim Erfassen, Code-Einfügen, Schulungs-Reset nur bei
Veränderung, Hilfestellungen/Kurzanleitung.

- ✅ **Offline-Robustheit:** offline erfasste/bearbeitete Patienten gehen beim
  Reconnect nicht mehr verloren (`_dirty` / `flushPendingPatients`, Merge per
  Zeitstempel, „nicht synchronisiert"-Hinweis). → löst Tech-Schuld „Offline-Queue".

- ✅ **Sichtbare Versionierung + Update-Mechanik:** App-Version in der Fußzeile,
  `version.json`, „Jetzt aktualisieren"-Banner (iOS-SW-Update zuverlässig),
  „Was ist neu"-Hinweis (kumulativ), `CHANGELOG.md`.

- ✅ **Erst-Einführung:** überspringbar, nur bei echter Neuinstallation, aus den
  Hilfestellungen erneut aufrufbar.

- ✅ **Patienten-Navigation:** gPA/Prio/„Alle Patienten" anklickbar, gPA
  zurückholbar; Erfassungs-Kontext (nächste Nr. + zuletzt angelegt) + Prio-
  Schnellaktion. [Zobel, Braunbeck]

- ✅ **Sperre robuster:** gibt nach Verlassen / 45 s zuverlässig frei, Wartende
  übernehmen automatisch. [Braunbeck]

- ✅ **Vitalwerte-Verlauf:** „Messung protokollieren" für längere Versorgung/PFC. [Schill]
- ✅ **CCP-Verbund:** „Ganzen Verbund löschen" (MasterToken); Verbund als ein
  Eintrag in „CCP beitreten"; korrekte Zähler nach Löschen.

- ➖ **Bewusst verworfen (Owner-Entscheid):** Neuro-Feld, Funktions-/Rollenanzeige
  am CCP, Rufname-Hinweis.

## UI-/Plattform-Strategie (Architektur-Entscheidung 2026-06-05)

**Eine** Codebasis, **ein** Backend, **eine** Veröffentlichung — **keine** separate „PC-App".
ARGUS passt sich **responsiv** an (CSS-Breakpoints; **capability-basiert**: Bildschirm­größe +
Eingabeart `pointer`, NICHT Geräte-Sniffing):

- **Feld-Oberfläche:** bleibt **mobile-first/responsive** (Telefon, Tablet); auf Desktop
  höchstens luftiger/zentriert. Bewusst schlicht (Stress/Handschuhe) — kein eigenes
  „Desktop-Feld-UI".

- **Admin (Phase 7) & FLZ-Dashboard (Phase 8):** zusätzliche, desktop-taugliche
  **Ansichten im selben Projekt** (Tabellen, Mehrspalten, Karten-Raster), die die Breite
  nutzen. Das Dashboard kann einen **eigenen Einstieg/URL** (Beobachter-Token) haben,
  bleibt aber dieselbe Codebasis/Backend.

- Native App (Phase 9) ist hierfür **nicht** nötig — Responsive Web deckt alle Schirme
  aus einem Code ab. Mockup-Ausblick: `docs/UI-AUSBLICK.html`.

## Härtungsfenster nach Phase 4.5 (2026-06-05 … 06-08) — v0.16 → v0.19.5

Iterative Feature-/Schulungsarbeit im Test-/Härtungsfenster (keine geplante Phase —
Phase 5 bleibt aufgeschoben). Details: `.planning/STATE.md`.

- ✅ **AT-MIST-Übergabekarte (v0.17):** gesperrte Vorlese-Karte beim Auschecken → gPA
  (strukturierte Übergabe). Abgrenzung: ARGUS bleibt Polizei/CCP-fokussiert
  (IVENA-Integration geprüft & verworfen).

- ✅ **Geführtes interaktives Training (v0.18 → v0.19.5):** 36-Lektionen-Durchlauf
  über die Schulungsumgebung; geräte-lokaler Sandbox (nie Cloud, lokaler Ephemer-CCP),
  3-Modus-Spotlight, Onboarding-Intro verweist darauf. DAUERREGEL: Drehbuch bei jeder
  UI-Änderung mitpflegen.

- ✅ **Produkt-Website** im ARGUS-Design (Demo, `noindex`/unauffindbar auf Pages).
- ✅ **IP-/Doc-Hygiene:** interne Docs/Decks entöffentlicht (`.gitignore`);
  Design-Sprache fixiert (`docs/UI-AUSBLICK.html` verbindlich).

## Phase 4.8 — Datenschutz-Härtung ✅ 2026-06-10

**Ziel:** Die DSB-unabhängigen P1-Tasks aus `docs/datenschutz/DATENSCHUTZ-SPEC.md`
umsetzen — laut DSFA Bedingung für jeden Echtbetrieb. Läuft im Test-/Härtungsfenster,
**vor** Phase 5; das DSB-Gespräch wird dadurch nicht entwertet, sondern vorbereitet.

- **T2 — „Einsatz abschließen" + automatische Löschung** (Fundament: Einsatz-
  Lebenszyklus, Übergabe-Export, Lösch-Timer, Cloud-Purge, lokale Bereinigung).

- **T1 — Foto-Härtung + Governance-Panel** (Foto-Schalter Default aus, Foto-
  Lebenszyklus mit 72-h-Löschung nach Einsatzabschluss → baut auf T2 auf,
  MasterUser-/Governance-Zugriff protokolliert, Fristverlängerung mit Begründung).

- **T3 — Namensfeld-Härtung** (UI-Hinweise, keine Namens-Suche/-Spalte,
  Freitextfeld-Hinweise, Drehbuch-Lektion).

- **T8 — Externe Laufzeit-Abhängigkeiten entfernen** (Supabase-JS lokal,
  IBM-Plex self-hosted — keine Requests an jsdelivr/Google mehr).

- Begleitend gem. SPEC: Drehbuch/Lektionen bei jeder UI-Änderung mitziehen,
  `08-MASSNAHMENPLAN.md` synchron halten.

- **Explizit NICHT in dieser Phase:** T4 Audit-Log (gesperrt bis DSB-Votum
  „JI-Regime"), T5–T7 (P2, eigene Folgephase oder nach DSB).

**Plans:** 6 Pläne in 5 Wellen (geplant 2026-06-10):

- [x] 04.8-01-PLAN.md — T8: Supabase-JS lokal vendoren, IBM-Plex self-hosten (Wave 1) ✅ 2026-06-10 (v0.19.9)
- [x] 04.8-02-PLAN.md — DB-Fundament: Migration 0002 (Einsatz-Lebenszyklus, Purge, Governance-RPCs, pg_cron) (Wave 1) ✅ 2026-06-10
- [x] 04.8-03-PLAN.md — T2 App: Übergabe-Export, „Einsatz abschließen", lokale Bereinigung (Wave 2) ✅ 2026-06-10 (v0.20.0)
- [x] 04.8-04-PLAN.md — T1 App: Foto-Schalter (Default aus, synct), Foto-Lebenszyklus Normalansicht (Wave 3) ✅ 2026-06-10 (v0.21.0)
- [x] 04.8-05-PLAN.md — T1 App: Governance-Panel (Foto-Zugriff protokolliert, Fristverlängerung) (Wave 4) ✅ 2026-06-10 (v0.21.1)
- [x] 04.8-06-PLAN.md — T3: Namensfeld-Härtung + Statusführung der Phase (Wave 5) ✅ 2026-06-10 (v0.22.0)

**Phase abgeschlossen (2026-06-10, v0.22.0):** Alle 6 Pläne umgesetzt — T8, T2,
T1 (Schalter + Lebenszyklus + Governance-Panel), T3. Bewusst offen: Einsatz-Schalter
fürs Namensfeld (erst nach DSB-Votum), T4 Audit-Log (gesperrt bis DSB-Votum
„JI-Regime"), Live-Verifikationen am echten Gerät (Governance-Panel, 72-h-Lauf).

## Phase 4.9 — Governance-Oberfläche (Konsolidierung) ✅ *(2026-06-11)*

**Ziel:** Eine **eigene desktop-taugliche Admin-/Governance-Webseite** (gleiches
Repo, gleiches Supabase-Backend, MasterToken-geschützt), die die heute verstreuten
Leitungs-Funktionen an EINEM Ort bündelt — statt einer „Foto-Insel" in der Feld-App.
Owner-Entscheid 2026-06-10: konsolidieren jetzt, DSB-abhängige Teile bleiben Phase 7.

**Bewusst vorgezogen** (vor 5/6): reine Verwaltungsoberfläche, keine Abhängigkeit auf
Produktions-Infra; respektiert aber den DSB-Gate (siehe „NICHT in dieser Phase").

**Einsatzprotokoll-Modell (Owner-Entscheid 2026-06-10, ersetzt die Foto-Governance-
Mechanik aus 4.8):**

- CCP-Abschluss schreibt den Einsatz als **Einsatzprotokoll** fest; danach Zugriff
  **nur** über das Governance-Panel, **jeder Protokoll-Aufruf wird protokolliert**
  (nicht mehr nur der Foto-Einzelabruf).

- **Fotos: harte Löschung 72 h nach Abschluss, KEINE Verlängerung.** Beweisbedarf
  → Sicherung durch zuständige Stelle innerhalb der 72 h.

- **Einsatzprotokoll (Daten ohne Fotos): Grundfrist ebenfalls 72 h**, aber mit
  Pflicht-Begründung **verlängerbar** (protokolliert, Wiedervorlage). Ersetzt die
  bisherige 14/30-Tage-Grundfrist aus T2 → Löschkonzept (Dok. 05, intern) nachziehen.
  Der Übergabe-Export beim Abschluss ist damit der einzige dauerhafte Weg in die
  Trägerdoku.

- **Eigene Desktop-Seite** im ARGUS-Design (`docs/UI-AUSBLICK.html` verbindlich),
  eigener Einstieg/URL (nicht erratbar, `noindex` — Muster `docs/demo-*.html`),
  Login = MasterToken → bestehender Code/JWT-Exchange (`argus_exchange_code`),
  Session flüchtig (sessionStorage). Feld-PWA bleibt schlank.

- **Bereiche (Direkteinstieg, keine Zwischenseite):**
  - **Zugänge** — Codes/Links erstellen (dauerhaft/24 h/einmalig) + **Code-Sperre**
    (`revoked`-Flag + Re-Check beim Start; DSB-unabhängiger Sicherheitsgewinn)

  - **Einsatzprotokolle** — abgeschlossene Einsätze einsehen (protokolliert),
    Fotos darin bis zur 72-h-Löschung, Protokoll-Frist verlängern, Wiedervorlage

  - **Protokoll** — `governance_log` + Lösch-Läufe (`purge_log`)
- **Rückbau in der Feld-App:** Governance-View/-Einstieg aus `index.html` entfernen
  (kam erst mit v0.21.1); Foto-Fristverlängerung wird zur **Protokoll**-Frist-
  verlängerung umgewidmet; Abschluss-Workflow: feste 72-h-Grundfrist statt 14/30-Wahl.

- **Explizit NICHT in dieser Phase (bleibt Phase 7, DSB-abhängig):**
  personenscharfes **Audit-/Einsatzprotokoll** (= T4, gesperrt bis DSB-Votum
  „JI-Regime"), **echte Admin-Identitäten** (Supabase Auth/Magic-Link),
  vollständiges Nutzerverzeichnis/Präsidiums-Zuweisung.

**Plans:** 4 Pläne in 3 Wellen (geplant 2026-06-11):

- [x] 04.9-01-PLAN.md — Migration 0003: Einsatzprotokoll-RPCs, 72-h-Fristen, revoked-Flag, RLS-Härtung (Wave 1, PAT-Checkpoint) ✅ 2026-06-11
- [x] 04.9-02-PLAN.md — Desktop-Leitungsseite: Login, Zugänge + Code-Sperre, Einsatzprotokolle, Protokoll, Phase-7-Sperrsektion (Wave 2) ✅ 2026-06-11
- [x] 04.9-03-PLAN.md — Feld-App: Governance-Rückbau, Abschluss auf 72 h, revoked-Re-Check, Drehbuch, Release v0.23.0 + UPDATE-Sheet (Wave 2) ✅ 2026-06-11
- [x] 04.9-04-PLAN.md — Doku/Statusführung: Löschkonzept + SPEC lokal nachgezogen (Owner-Entscheid 2026-06-10, unversioniert), ROADMAP/STATE (Wave 3) ✅ 2026-06-11

## Phase 4.10 — Datenschutz-Schlusspaket (vor DSB-Gespräch) ✅ *(2026-06-11)*

**Ziel:** Die letzten DSB-unabhängigen Datenschutz-Lücken schließen, damit die
Aussage „technisch vollständig" vor dem DSB-Gespräch trägt. Klein und fokussiert.

- **Log-Löschfrist (Fund 2026-06-11):** `governance_log` + `purge_log` wachsen
  bisher unbegrenzt (enthalten Bediener-Kürzel = pseudonyme Daten). Automatische
  Löschung nach **12 Monaten** (Modell § 73 Abs. 5 PolG BW) im bestehenden
  Purge-Lauf → Migration 0004 (PAT-Checkpoint).

- **T5 Transparenz & Betroffenenrechte:** In-App-Datenschutzhinweis (Art. 13:
  Verantwortlicher `[Platzhalter]`, Zwecke, Fristen, Rechte, DSB-Kontakt) als
  statische Ansicht, aus den Hilfestellungen erreichbar; Platzhalter zentral
  pflegbar. Einzelpatient-/Einsatz-Export als Art.-15-Auskunftsweg dokumentieren.

- **T6 Backup-Hygiene:** Regeln für `~/ARGUS-Backups/*.json` festschreiben
  (keine Echtdaten, max. 30 Tage, Verschlüsselung oder Abschaffung) —
  `docs/BACKUP.md` (intern); Bestandsbereinigung als Owner-Punkt.

- **Interne Doku-Sync (lokal, NIE committen):** Dok. 01 (VVT) letzte
  14/30-Tage-Stelle auf 72-h-Modell; `DSB-BRIEFING.md/.html` auf
  Einsatzprotokoll-Modell aktualisieren (sonst veraltete Zahlen im Gespräch).

- **Kleinkram:** Alt-`UPDATE_*.html` bekommen `noindex` (Befund 04.9-03).
- **Explizit NICHT:** T4 (DSB-Votum), T7 Self-Hosting, Phase-5/6/7-Inhalte.

**Pläne:** 3 Pläne in 3 Wellen (geplant 2026-06-11)

- [x] 04.10-01-PLAN.md — Migration 0004: 12-Monats-Log-Löschung in argus_run_purge, live + Idempotenz-Beleg (Wave 1, PAT-Checkpoint) ✅ 2026-06-11
- [x] 04.10-02-PLAN.md — App: T5-Datenschutz-Ansicht (DS_KONTAKT-Platzhalter), noindex Alt-Sheets, Leitungs-Fußzeile, Drehbuch, Release v0.23.1 (Wave 2) ✅ 2026-06-11
- [x] 04.10-03-PLAN.md — T6 BACKUP.md + Bestandsaufnahme, interne Doku-Sync (VVT/DSB-Briefing/SPEC/Maßnahmenplan), ROADMAP/STATE (Wave 3) ✅ 2026-06-11

## Betriebsmodell-Entscheid (Owner, 2026-06-11): M1 — Eigenbetrieb der Polizei

ARGUS wird als **Software lizenziert**; das **Hosting läuft auf Infrastruktur der
Polizei BW/BITBW** (M1), NICHT über den Eigentümer oder dessen Supabase-Instanz.
Die Polizei stellt den Verantwortlichen. Konsequenzen:

- Eigentümer = reiner Lizenzgeber **ohne Datenzugriff** (kein § 82-AV-Vertrag nötig,
  Supabase-Sub-AV/DPA und Drittland-Frage entfallen für den Echtbetrieb).

- Die Eigentümer-Instanz (`sehuosjyjmrpzcqrelej`) bleibt dauerhaft **Entwicklungs-
  und Schulungsumgebung mit Fiktivdaten**.

- **T7 (Self-Hosting-Fähigkeit) wird der Produktweg** → Phase 4.11.
- Phase 5 (alt: „Supabase Pro + Prod-Projekt") ist damit obsolet und wurde zu
  „Übergabe-Paket" umgeschnitten.

## Phase 4.11 — Self-Hosting-Fähigkeit (T7, Übergabefähigkeit) ✅

**Ziel:** Eine Polizei-/BITBW-Instanz kann ARGUS ohne Codeänderung betreiben —
die App läuft gegen eine fremde Supabase-/Postgres-Instanz nur durch Austausch
einer zentralen Konfiguration.

- **Backend-Endpunkt herauslösen:** Supabase-URL + Anon-Key aus `index.html`
  (und der Leitungs-Seite) in eine zentrale, build-freie Konfiguration
  (z. B. `config.js`); PWA-/Offline-Verhalten unverändert (Precache!).

- **`docs/SELF-HOSTING.md`:** Aufbau-Anleitung — Supabase self-hosted (Docker
  Compose) oder verwaltetes Postgres; Migrationen `0000–0004` als
  Ein-Schritt-Apply; JWT-Secret/Vault/pgjwt/pg_cron-Einrichtung;
  Smoke-Test-Drehbuch. Von einer fachkundigen Person ohne Projektkenntnis
  nachvollziehbar.

- **Kompatibilitätsprüfung:** welche Server-Abhängigkeiten (pgjwt, Vault,
  pg_cron, Realtime) die Zielumgebung wie abbildet — dokumentieren.

- **Betriebsvorgaben für Lizenznehmer** in die Anleitung: nur verwaltete
  Dienstgeräte (MDM, Gerätesperrcode), Kürzel-Liste je Einsatz beim
  Einsatzleiter, Einsatz-Codes nur mündlich/Funk.

- **Akzeptanz (aus SPEC T7):** App läuft unverändert gegen eine zweite, frische
  Instanz nur durch Config-Tausch; Anleitung extern nachvollziehbar.

**Plans:** 2 plans (2 Wellen, voll autonom — keine Migration, kein PAT)

Plans:

- [x] 04.11-01-PLAN.md — Config-Auslagerung: config.js (Feld-App + Leitungs-Seite), SW-Precache v43, Fehlerpfad, Release v0.24.0 (Wave 1) ✅ 2026-06-11
- [x] 04.11-02-PLAN.md — Kompatibilitäts-Audit 0000–0004 + docs/SELF-HOSTING.md (Anleitung, Smoke-Test, Betriebsvorgaben) + Statusführung (Wave 2) ✅ 2026-06-11

**Akzeptanz-Vermerk (2026-06-11):** „App läuft gegen zweite Instanz" ist
**ersatzweise belegt** — über die Config-Isolation aus Plan 04.11-01
(Grep-Gate: URL/Anon-Key existieren NUR in config.js; JSC-Konsumtest der
ARGUS_CONFIG-Ableitung) plus die extern nachvollziehbare Anleitung
`docs/SELF-HOSTING.md` (Kompatibilitäts-Audit 0000–0004, Smoke-Test-Drehbuch
mit Erwartungsergebnissen). Eine **echte Zweitinstanz-Erprobung bleibt offen**
(deferred, sobald eine Zielumgebung existiert — kein Zugang zur Polizei-Infra).

## Phase 4.12 — FLZ-Lageansicht Stufe a (separate Beobachter-Seite) ✅ 2026-06-12

**Ziel:** Anonyme Aggregat-Zahlen (Patienten je Kategorie/CCP) für FLZ/ILS als
**eigene** read-only Desktop-Seite (eigener Einstieg, Beobachter-Token,
`is_observer`-JWT gem. Sicherheits-Design in Phase 8) — bewusst getrennt vom
Governance-Panel (anderes Vertrauensniveau, anderer Verteilungsradius).
Stufe b (pro-Patient, pseudonym) bleibt DSB-gated in Phase 8.

**Plans:** 2 plans (2 Wellen)

Plans:

- [x] 04.12-01-PLAN.md — Migration 0005: Beobachter-Token, Observer-JWT-Exchange (eigene Claim-Form), Aggregat-RPC `argus_lage`, `lage_view`-Log; REST-Positiv-/Negativtests (Wave 1) ✅ 2026-06-12
- [x] 04.12-02-PLAN.md — Beobachter-Seite `docs/lage-<suffix>.html` (Login, 20-s-Polling, Kategorie-Kacheln, Summenzeile, Offline-Zustand) + Beobachter-Code-Ausgabe in der Leitungs-Seite + interne Doku/Statusführung (Wave 2) ✅ 2026-06-12

**Abschluss-Vermerk (2026-06-12):** Sicherheits-Design vollständig belegt
(Observer-JWT ohne `praesidium_id` → Roh-Tabellen liefern 0 Zeilen,
Governance-RPCs verweigern; Cross-Exchange beidseitig abgewiesen; revoked
wirkt; `lage_view` genau 1× je Login). KEIN App-Release — Feld-App
(index.html/sw.js/version.json) unangetastet, weiterhin v0.24.0.

## Phase 4.13 — Paket 3 (baubarer Teil): Schulungs-Provisionierung, Tombstone-Reset, AT-MIST-Druck ⬜

**Ziel:** Der extern UNblockierte Teil von Paket 3 (Feedback-Triage
2026-06-13): (1) Schulungs-Reset über Tombstones statt hartem DELETE —
Offline-Geräte bereinigen sich über die vorhandene Abschluss-Mechanik
(behebt „Reset erreicht Offline-Geräte nicht"); (2) Schulungs-Provisionierung
je Präsidium („<Name> — Schulung", Owner-Entscheid) inkl. Leitungs-Knopf;
(3) AT-MIST-Druckansicht im Protokoll-Detail der Leitungs-Seite.
Migration 0011. Release v0.28.0.
**Scope-Zaun (extern blockiert, NICHT hier):** FLZ-operativ + T4 + k-Schwelle
(DSB-Votum), GeoJSON-Endpunkt (PTLS Frage 9).
Details: `.planning/phases/04.13-paket3-schulung/04.13-CONTEXT.md`.
**Plans:** 2/2 plans complete
Plans:

- [x] 04.13-01-PLAN.md — Migration 0011 (argus_schulung_reset + argus_provision_schulung) + REST-Idempotenz/Positiv-/Negativtests + SELF-HOSTING.md [Wave 1]
- [x] 04.13-02-PLAN.md — Feld-App (schulreset→RPC, 4 Flag-Gates) + Leitungs-Seite (Provisionierungs-Knopf, AT-MIST-Druck) + Release v0.28.0/SW v51 [Wave 2]

## Phase 4.14 — Governance-Panel-Vervollständigung (schlank, ohne Stufe 1) ⬜ (INSERTED 2026-06-22)

**Ziel:** Das Governance-Panel (Leitungs-Seite) soweit aktuell möglich
fertigstellen — die jetzt baubaren, nicht DSB-/PTLS-gateten Teile des
Rollenmodells. Erste Rolle unterhalb MasterUser: **Präsidiums-Admin**
(präsidiumsbegrenzt; nur 24h-Gast-Code + QR + eigene Lage).

**Scope:** (1) rollen-adaptive Leitungs-Seite (Weg B, keine Seite je Rolle);
(2) Präsidiums-Admin end-to-end (`is_admin` + `admin_praesidium_id`, Muster 0005,
jti-Sofortsperre); (3) QR-Ausgabe für Gast-Codes (selbst-enthalten, Deep-Link);
(4) Übungspräsidium „leeren" + Demo opt-in; (5) Audit-Ansicht kürzelbasiert.
Pflicht: Privilege-Escalation-Negativtests, SELF-HOSTING.md, D-06.
**Nicht hier:** Stufe-1-Identität (USBNK/T4), Feld-App-Änderungen, SSO (Folgephasen).
Architektur: `.planning/PHASE7-ROLLENMODELL-DRAFT.md` · Context:
`.planning/phases/04.14-governance-panel/04.14-CONTEXT.md`.

**Plans:** 3 plans (3 Wellen — File-Ownership der Leitungs-Seite erzwingt seriell).
Plans:
- [ ] 04.14-01-PLAN.md — Migration 0013: is_admin-Rolle, Admin-Exchange, scoped Gast-Code-RPCs, argus_lage-Admin, Negativtests, SELF-HOSTING (Wave 1)
- [ ] 04.14-02-PLAN.md — Rollen-adaptive Leitungs-Seite: Admin-Login, Master gibt Admin-Token aus, Admin-Gast-Code + eigene Lage (Wave 2)
- [ ] 04.14-03-PLAN.md — QR-Ausgabe (Deep-Link, kein CDN), Übungspräsidium leeren, Audit-Ansicht kürzelbasiert, Doku-Sync (Wave 3)

## Phase 5 — Übergabe-Paket & Betriebsübergabe (M1) ⬜

**Ziel:** Geordnete Übergabe an den Lizenznehmer — neu zugeschnitten nach dem
M1-Entscheid (2026-06-11); Detailplanung NACH dem DSB-Gespräch.

- Übergabe-/Deployment-Paket auf Basis von `docs/SELF-HOSTING.md` (Phase 4.11)
  + `docs/PROD-SETUP.md` (vorhanden, anzupassen).
- **Repo-Schnitt** (privates Repo, Git-History, Lizenz-/IP-Schutz) bleibt
  relevant — unabhängig vom Hosting.

- Daten-Hygiene der Dev-Instanz (verwaiste CCPs, frische Codes inkl. neuem
  MasterToken — der alte war zeitweise per Anon-Key lesbar, siehe Phase 4).

- Backup-/Löschkonzept im **Betrieb der Polizei** = Sache des Verantwortlichen;
  ARGUS liefert die technische Grundlage (Migrationen, Purge-Jobs, Doku).

- ~~Supabase Pro-Tier / separates Prod-Projekt beim Eigentümer~~ — entfallen (M1).

## Phase 6 — Betriebsbereitschaft & Open Beta ⬜

**Ziel:** Die App ist legal, organisatorisch und dokumentarisch bereit für
einen erweiterten Testkreis und perspektivisch echten Einsatz.

- **Compliance-Checkliste** abarbeiten (→ `docs/COMPLIANCE.md`): EU-Hosting
  bestätigen, Verschlüsselung, Zugriffsprotokoll, Löschkonzept, MDR-Einstufung
  mit zuständiger Behörde klären.

- **E-Mail-Adresse** für Lizenzanfragen in `LICENSE` + `README.md` eintragen.
- **Kurzanleitung** für Tester (Installation, Rollen, CCP eröffnen/beitreten,
  Kategorien, Abtransport).

- **Feldtest** (LebEL-Übung oder vergleichbar): echte Geräte, echte Lage,
  Sperre / Rolle / Merge unter realen Netzbedingungen.

- **Open Beta:** breiterer Testkreis, strukturiertes Feedback-Verfahren.
- ✅ **Vorbereitet (2026-06-04):** DSB-Gesprächsvorlage `docs/DSB-BRIEFING.md`
  und `docs/TESTER-ANLEITUNG.md` (nützt schon dem laufenden Testkreis).

## Phase 7 — Governance: Identitäten & Audit-Protokoll ⬜ *(DSB-abhängig)*

**Ziel:** Die **DSB-abhängige** Schicht der Governance, die auf der konsolidierten
Oberfläche aus Phase 4.9 aufsetzt. Erst nach dem DSB-Gespräch umsetzbar — die
Eckpfeiler (Regime, Identitäten, Protokoll-Form) entscheidet der DSB.

> Die Desktop-Leitungs-Oberfläche (Zugänge inkl. Code-Sperre, Einsatzprotokolle
> mit protokolliertem Abruf, Protokoll-Ansicht) ist seit **Phase 4.9** gebaut
> (✅ 2026-06-11, v0.23.0) — inkl. sichtbar gesperrter Sektion „Phase 7 · nach
> DSB". Phase 7 ergänzt dort nur noch die Inhalte, die ohne DSB-Votum nicht
> festgelegt werden können.

- **Zwei-Ebenen-Modell:** Feld-Zugang bleibt pseudonym (Code, kein Login);
  Admin-/Rollen-Konten erhalten echte Identitäten (Supabase Auth,
  E-Mail / Magic-Link).

- **Nutzerverzeichnis (Voll):** Präsidien zuweisen / aufschalten, Rollen verwalten
  (die reine Code-Sperre liegt seit 4.9 in der Leitungs-Oberfläche).

- **RLS-Feinschliff** auf Basis der Phase-4-Grundlage.
- **Audit-/Einsatzprotokoll (= T4 der DATENSCHUTZ-SPEC):** personenscharfes,
  zeitgestempeltes Verlaufsprotokoll (wer/wann/was/welcher CCP), append-only.
  Heute nur „zuletzt geändert von/wann". **Hart gesperrt bis DSB-Votum „JI-Regime"**;
  Umfang + Aufbewahrung (§ 73 PolG BW: 12 Monate) nach DSB/LDSG/Polizeidatenrecht.

## Phase 8 — Lageübersicht für FLZ / ILS (read-only Dashboard) ⬜

**Ziel:** Browserbasierte Leseansicht für Führungs- und Lagezentrum (FLZ)
oder Integrierte Leitstelle (ILS): aktive CCPs, Patientenzahlen je Kategorie
(T1/T2/T3/T5/gPA), ohne Zugriff auf personenbezogene Daten.

> **Stufe a vorgezogen in Phase 4.12 umgesetzt (✅ 2026-06-12):** Beobachter-
> Token + Observer-JWT + Aggregat-RPC + separate Beobachter-Seite live.
> In dieser Phase verbleiben: **Stufe b** (pro-Patient, DSB-gated),
> **Landes-Observer**, **präsidiumsübergreifende Einzel-Freigabe**,
> Realtime statt Polling (falls je nötig), IVENA-Frage.

- Anonymisierte Echtzeit-Zahlen, kein Patientendetail.
- **Scope (festgelegt 2026-06-04):** **präsidiumsgebunden** als Default — ein FLZ ↔ ein
  (Regional-)Präsidium (PP BW haben je ein eigenes FLZ). Optional ein **Landes-Observer**
  (alle/definierte Präsidien, read-only) für eine landesweite Koordinierungsstelle —
  restriktiv ausgeben. Präsidiumsübergreifende Sicht (überörtliche Hilfe) nur per
  **bewusster Einzel-Freigabe**, nicht automatisch.

- **Sicherheits-Design (festgelegt):** Observer-JWT trägt eine **eigene Claim-Form**
  (`is_observer:true` + `observer_praesidium_id`, NICHT `praesidium_id`!), damit
  `argus_praesidium_id()` für ihn `null` liefert und die bestehenden Patienten-/CCP-
  RLS-Policies Roh-Zugriff **verweigern**. Zahlen kommen ausschließlich aus einer
  `security definer`-Aggregat-View/RPC (liest `observer_praesidium_id`). **Keine**
  Bediener-/MasterMedic-Namen anzeigen. Pull/Polling, kein Realtime; reine Desktop-
  Webansicht (nicht die Feld-PWA).

- **Datentiefe per DSB** (siehe `docs/DSB-BRIEFING.md`):
  - Stufe a: **aggregierte Zahlen** je Kategorie/CCP (anonym).
  - Stufe b (falls zulässig): zusätzlich **pro Patient** Kategorie + Alter + Geschlecht
    + Verletzungsblock (pseudonym; **ohne** Name/Foto/Vitalwerte/Notizen).
- **Weiteres:** widerrufbare Tokens (Phase 7); Re-Identifikation bei Kleinstzahlen in
  der DSFA bedenken; ggf. Protokollierung des Observer-Zugriffs (DSB). IVENA wäre ein
  separater Push, getrennt halten.

- ~~Klärung: zuständige Leitstelle (FLZ vs. ILS)~~ — **entschieden (Owner
  2026-06-12): Adressat ist das FLZ.** Offen bleibt die DSFA für die
  Übermittlung. Konzipiert (Bau nach DSB-Votum): **„FLZ-operativ"** —
  Stellen-Token mit genau drei Befugnissen (Gast-Code fürs eigene Präsidium
  erstellen/sperren, Lage-Freigabe an ein anderes FLZ erteilen/widerrufen;
  Richtungs-Regel: freigeben kann nur die abgebende Stelle), KEINE
  Patientendaten/Protokolle/Fotos, jede Aktion protokolliert — damit ist
  die Leitstelle nachts handlungsfähig (einzige 24/7 besetzte Stelle).

## Phase 9 — Native App für PTLS Pol 🔒 *Conditional*

**Ziel:** PWA via Capacitor in native iOS-App (.ipa), verteilt über den
dienstlichen App-Store von PTLS Pol (MDM, kein öffentlicher App Store).

**Mögliche Vorteile nativ (Owner-Notiz 2026-06-04):** Eine native App umgeht die
PWA-Grenzen beim Onboarding — **Deep-Links könnten die App direkt öffnen und den
enthaltenen Code automatisch einlösen** (entfällt die manuelle Kopier-/„Einfügen"-
Brücke); engere Integration mit dem Gerät; ggf. Freischaltung/Verwaltung über das
Governance-/„Systempanel" aus Phase 7. Daher: Onboarding-Feinschliff in der PWA
bewusst minimal halten, die „richtige" Lösung kommt mit nativ.

**Konzeptpapier (2026-06-12, intern/gitignored):** `docs/KONZEPT-POLIZEIBETRIEB.md`
— Stufenmodell Einrichtung/Identität (1: PWA + Einmal-Link · 2: nativ + MDM
Managed App Configuration, Null-Touch · 3: SSO gegen Polizei-IdP, App-Identität
= USBNK, zentrale Sperrwirkung; Code-Pfad bleibt Fallback für Fremdkräfte),
Plattform-Architektur (PC-Seiten bleiben Intranet-Browser, ein Backend, keine
App-zu-App-Schnittstelle) und Fragenkatalog an PTLS Pol/BITBW.

**Bedingungen (alle müssen erfüllt sein):**

- Offizieller Träger-Buy-in durch Polizei BW / PTLS Pol
- IT-Sicherheitsfreigabe
- DSB-Abstimmung abgeschlossen
- Apple Developer Enterprise Account (PTLS Pol) vorhanden

> Diese Phase ist kein regulärer Entwicklungs-Meilenstein, sondern an eine
> organisatorisch-politische Entscheidung gebunden. Keine Planung vor
> Bedingungserfüllung.

---

## Technische Schuld (geparkt, kein aktiver Meilenstein)

| Thema | Ursprung | Status / Wann angehen |
|---|---|---|
| Offline-Queue für Writes | Phase 1 | ✅ erledigt in Phase 4.5 (v0.4.0) |
| Fotos → Supabase Storage | alt Phase 4 | offen — bei >50 Fotos / vor großem Rollout |
| `revoked`-Flag UI | Phase 3 | ✅ erledigt in Phase 4.9 (Code-Sperre in der Leitungs-Oberfläche + Re-Check am Gerät, v0.23.0) |
| SW-Cache-Version automatisch bumpen | aktuell manuell | teilw. adressiert (`version.json`); Auto-Bump offen |
| Laufnummern-Kollision bei gleichzeitigem Anlegen (2 Geräte) | Audit 06-04 | serverseitige Nummernvergabe — offen |
| JWT-Refresh nur bei Start/`online` (lange Dauer-Sessions) | Audit 06-04 | offen, geringe Priorität |
| Verwaiste CCPs `praesidium_id = NULL` | Audit 06-04 | beim Produktiv-Schnitt (Phase 5) bereinigen |
| Master-Code-Rotation vor Echtbetrieb | Audit 06-04 | in Phase 5 (frische Codes im Prod-Projekt) |

---

## Definition of Done (gilt für alle Phasen)

- Bestehende Bedienung unverändert oder einfacher.
- Funktioniert offline mindestens lesend/erfassend weiter.
- Keine nativen `alert/confirm/prompt`.
- Auf einem echten iPhone als Homescreen-App getestet.
- Commit auf `main`, gepusht.
