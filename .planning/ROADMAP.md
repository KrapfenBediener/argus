# CCP-App (ARGUS) — Roadmap

> **Stand: 2026-06-04** — Phase 4 abgeschlossen; danach Beta-Härtung aus
> Tester-Feedback (v0.4.0–v0.9.1, siehe Phase 4.5). App live auf **v0.9.1**.
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
Ausgeliefert als nachvollziehbare Point-Releases **v0.4.0 – v0.9.1** (`CHANGELOG.md`).

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

## Phase 5 — Produktionsinfrastruktur ⬜
**Ziel:** Die App läuft auf einer stabilen, gesicherten Infrastruktur —
kein Free-Tier, kein Auto-Pause, kein geteiltes Supabase-Projekt für Beta
und Produktion.

- **Supabase Pro-Tier** für das Produktionsprojekt (~25 $/Monat):
  kein Auto-Pause, höhere Limits, tägliches Backup.
- **Separates Supabase-Produktionsprojekt** mit sauberer Datenbasis,
  frischen Tokens, Prod-RLS. Beta-Projekt bleibt für Tests.
- **Production-Repo-Schnitt:** Neues GitHub-Repo (privat), Git-History
  erhalten, alte URL + altes Supabase einfrieren. Tester installieren
  PWA neu.
- **Daten-Hygiene beim Schnitt:** verwaiste CCPs (`praesidium_id = NULL`)
  bereinigen; alte Codes nicht übernehmen → frische Codes inkl. neuem MasterToken
  (der alte war zeitweise per Anon-Key lesbar, siehe Phase 4).
- **Backup-/Löschkonzept** dokumentieren und testen (DSGVO).

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

## Phase 7 — Governance & Nutzerverzeichnis ⬜
**Ziel:** Administrative Verwaltung ohne die pseudonyme Feld-UX zu
kompromittieren. Löst die verbleibende Zugriffskontroll-Lücke sauber.

- **Zwei-Ebenen-Modell:** Feld-Zugang bleibt pseudonym (Code, kein Login);
  Admin-/Rollen-Konten erhalten echte Identitäten (Supabase Auth,
  E-Mail / Magic-Link).
- **Nutzerverzeichnis:** Nutzer sperren (`revoked`-Flag + Re-Check beim Start),
  Präsidien zuweisen / aufschalten, Codes ausgeben / widerrufen.
- **Desktop-optimierte Admin-Webseite** (nicht Phone-App) für Verwaltungsaufgaben.
- **RLS-Feinschliff** auf Basis der Phase-4-Grundlage; Audit-Log.

## Phase 8 — Lageübersicht für FLZ / ILS (read-only Dashboard) ⬜
**Ziel:** Browserbasierte Leseansicht für Führungs- und Lagezentrum (FLZ)
oder Integrierte Leitstelle (ILS): aktive CCPs, Patientenzahlen je Kategorie
(T1/T2/T3/T5/gPA), ohne Zugriff auf personenbezogene Daten.

- Anonymisierte Echtzeit-Zahlen, kein Patientendetail.
- Klärung vor Umsetzung: zuständige Leitstelle (FLZ vs. ILS),
  Datenschutz-Folgenabschätzung für Übermittlung, Anbindung IVENA (optional).

## Phase 9 — Native App für PTLS Pol 🔒 *Conditional*
**Ziel:** PWA via Capacitor in native iOS-App (.ipa), verteilt über den
dienstlichen App-Store von PTLS Pol (MDM, kein öffentlicher App Store).

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
| `revoked`-Flag UI | Phase 3 | in Phase 7 integriert |
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
