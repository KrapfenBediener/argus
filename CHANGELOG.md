# ARGUS — Änderungsverlauf

Sichtbare App-Version (`APP_VERSION` in `index.html`, in der Fußzeile angezeigt).
Schema: semantisch (`MAJOR.MINOR.PATCH`). Solange Beta: `0.x`.
Frühere Stände vor Einführung der sichtbaren Version liegen in der Git-Historie.

---

## v0.4.0 — 2026-06-04
**Paket A: Erreichbarkeit & Mehrgeräte-Sicherheit (Tester-Feedback)**
- **Neu:** „Alle Patienten" — flache, anklickbare Gesamtliste (Startseite + Übersicht).
- **Neu:** PRIO- und gPA-Zähler sind jetzt anklickbar und öffnen die jeweilige Liste.
- **Neu:** Abtransportierte Patienten (gPA) lassen sich wieder aufrufen und per
  „↩ Zurückholen → aktiv" in den aktiven Bestand zurückholen (Korrektur von
  Fehl-Auscheckungen).
- **Behoben:** Soft-Lock-Übernahme durch MasterMedic — der bisherige Bearbeiter
  wird jetzt sofort (Echtzeit) bzw. binnen ~5 s schreibgeschützt und kann die
  Sperre nicht mehr durch Weitertippen zurückerobern (Sperr-Spalten getrennt von
  der Datenspeicherung).
- **Neu:** sichtbare App-Version in der Fußzeile; dieses CHANGELOG.

## v0.3.x — 2026-06-04 (vor sichtbarer Versionierung)
- Offline-Robustheit: offline erfasste/bearbeitete Patienten gehen beim Reconnect
  nicht mehr verloren (lokale Markierung + Merge per Zeitstempel + Nachsync).
- Doppelnummer-Warnung bei parallel vergebenen Laufnummern.
- Schreibweise „Argus" → „ARGUS".

## v0.2.x — 2026-06-03 (vor sichtbarer Versionierung)
- Phase 4: serverseitige Absicherung — Token-Tausch (Code → JWT via RPC,
  pgjwt+Vault), RLS pro Präsidium, Lockdown der `access_tokens`-Tabelle.

## v0.1.0 — 2026-06-03 (vor sichtbarer Versionierung)
- Proprietäre Lizenz/Copyright; Phasen 0–3 (PWA-Hülle, Supabase-Backend,
  Join-Flow, Mehrgeräte-Features) — siehe Git-Historie / `.planning/ROADMAP.md`.
