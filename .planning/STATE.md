# Projekt-Status — Argus (CCP-App)

- **Milestone:** Closed Beta V1 — läuft
- **Aktuelle Phase:** 4 — Serverseitige Absicherung *(geplant, noch nicht gestartet)*
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

---

## Letzter Stand (2026-06-03)

- Roadmap vollständig überarbeitet (6 aktive Phasen 4–9, technische Schuld
  ausgelagert, Phase 9 als Conditional markiert)
- `validateInviteToken` auf `.maybeSingle()` umgestellt — stille PGRST116-Fehler
  behoben, alle Codes (dauerhaft / 24h / einmalig) funktionieren
- GRANT INSERT/UPDATE auf `access_tokens` für `anon` (war vergessen)
- Einmal-Links vollständig funktionsfähig (insert + consume + RLS-Policies)
- Code-Eingabefeld direkt in `vPraesidium` (kein `promptModal` mehr)
- SW Cache v4 — Update erzwungen
- Licensing gemergt (`chore/licensing` → `main`, Tag `v0.1.0-rights` gepusht)

---

## Nächste Phase: 4 — Serverseitige Absicherung

**Kern-Problem:** Anon-Key steckt im Quelltext (öffentlich). Aktuelle RLS-Policy
= `anon_all: true` auf allen Tabellen. Wer den Key kennt, kann alles lesen/schreiben.
Das ist der kritische Blocker vor echtem Patienteneinsatz.

**Ansatz:** Edge Function → Token-Exchange (Code → signiertes Sitzungs-Ticket mit
`praesidium_id` + TTL) → RLS-Policies binden Zugriff an Ticket. Pseudonymität bleibt.

---

## Offene Entscheidungen / Hinweise

- **Repo ist public** auf GitHub — Widerspruch zur proprietären Lizenz.
  Bereinigung beim geplanten Production-Repo-Schnitt (Phase 5).
- **E-Mail-Platzhalter** in `LICENSE` + `README.md` → vor Open Beta ersetzen.
- **GSD-CLI nicht lauffähig** (`node` fehlt) → `.planning/` wird manuell gepflegt.
- **TECH_DEBT.md** noch nicht angelegt — bei Bedarf erstellen.
