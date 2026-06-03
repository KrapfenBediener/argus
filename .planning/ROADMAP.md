# CCP-App (Argus) — Roadmap

> **Stand: 2026-06-03** — vollständig überarbeitet nach kritischer Bewertung
> der Planung gegen das Endziel (operative Nutzung in MANV-Lagen, potenziell
> Polizei BW / PTLS Pol).
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

## Phase 4 — Serverseitige Absicherung (RLS + Auth-Fundament) ⬜
**Ziel:** Die App ist gegen direkten API-Zugriff abgesichert. Der öffentliche
Anon-Key darf nur das lesen/schreiben, wozu das Gerät berechtigt ist.
Voraussetzung für jeden Einsatz mit echten Patientendaten.

- **Edge Function / Token-Exchange:** 8-stelliger Code → kurzlebiges
  signiertes Sitzungs-Ticket mit `praesidium_id` + Ablaufzeit. Kein Klarname,
  kein Konto — Pseudonymität bleibt gewahrt.
- **RLS-Policies** pro Tabelle: `patients`, `ccps`, `checklists`,
  `access_tokens` — Zugriff an Ticket / Präsidium gebunden.
- **Feld-UX unangetastet:** Der Sichter am CCP merkt nichts, kein Login,
  kein Passwort.
- **Testen:** Direkter API-Zugriff mit Anon-Key wird nach Umsetzung geblockt.

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

| Thema | Ursprung | Wann angehen |
|---|---|---|
| Fotos → Supabase Storage | alt Phase 4 | Bei >50 Fotos spürbar oder vor großem Rollout |
| `revoked`-Flag UI | Phase 3 | In Phase 7 integriert |
| Offline-Queue für Writes | Phase 1 | Falls Funkloch-Szenarien zum Standard werden |
| SW Cache-Versionierung automatisch | aktuell manuell | Bei nächstem Infra-Review |

---

## Definition of Done (gilt für alle Phasen)
- Bestehende Bedienung unverändert oder einfacher.
- Funktioniert offline mindestens lesend/erfassend weiter.
- Keine nativen `alert/confirm/prompt`.
- Auf einem echten iPhone als Homescreen-App getestet.
- Commit auf `main`, gepusht.
