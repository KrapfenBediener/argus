# Projekt-Status — Argus (CCP-App)

- **Milestone:** Closed Beta V1 — läuft
- **Aktuelle Phase:** Test-/Härtungsfenster — Phase 5 bewusst aufgeschoben,
  bis die App ausgiebiger getestet ist
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

## Nächste Phase: 5 — Produktionsinfrastruktur

Pro-Tier, separates Produktionsprojekt, Production-Repo-Schnitt, Backup-/Löschkonzept.
Siehe `.planning/ROADMAP.md`.

---

## Offene Entscheidungen / Hinweise

- **Repo ist public** auf GitHub — Widerspruch zur proprietären Lizenz.
  Bereinigung beim geplanten Production-Repo-Schnitt (Phase 5).
- **E-Mail-Platzhalter** in `LICENSE` + `README.md` → vor Open Beta ersetzen.
- **GSD-CLI nicht lauffähig** (`node` fehlt) → `.planning/` wird manuell gepflegt.
- **TECH_DEBT.md** noch nicht angelegt — bei Bedarf erstellen.
