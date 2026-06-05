# ARGUS — Backup & Wiederherstellung

## Was gesichert ist
| Bestandteil | Sicherung |
|---|---|
| Quellcode, Doku, Planung | Git → GitHub-Remote + lokaler Klon (Historie) |
| DB-**Struktur** (Tabellen, RLS, Funktionen, RPC) | als Code in `supabase/migrations/0000+0001` (reproduzierbar) |
| DB-**Daten** (Präsidien, CCPs, Checklisten, Codes, Patienten) | **manuelles Export-Skript** (siehe unten) → `~/ARGUS-Backups/` |

## Daten-Backup (Sofort-Sicherheitsnetz, bis Supabase Pro / Phase 5)
Free-Tier hat **keine** automatischen Backups. Bis Phase 5 (Pro-Tier mit täglichen
Backups) sichern wir die Daten manuell:

```bash
cd "/Users/gaborszeman/Desktop/Projekt CCP_APP"
python3 scripts/argus_backup.py     # MasterToken-Code eingeben
```

- Authentifizierung über den **MasterToken-Code** (kein Management-PAT nötig); der
  Code wird nicht gespeichert.
- Ergebnis: eine JSON-Datei unter **`~/ARGUS-Backups/`** (Rechte `0600`), enthält
  alle Tabellen. **Außerhalb des Repos** — enthält sensible Daten.
- **Rhythmus:** vor/nach jeder Übung + bei wichtigen Änderungen, mind. wöchentlich.

## Wiederherstellung
1. Frisches Supabase-Projekt: Schema aus `supabase/migrations/` anwenden
   (`0000_base_schema.sql`, dann `0001_phase4_jwt_rls.sql`), Vault-Secret + Extensions
   wie in `docs/PROD-SETUP.md`.
2. Zeilen aus dem JSON je Tabelle einspielen (in FK-Reihenfolge: praesidien → ccps →
   patients/checklists/access_tokens).

## Ab Phase 5
Supabase **Pro-Tier**: tägliche Server-Backups + Point-in-Time-Restore; das manuelle
Skript bleibt als zusätzliches, projektnahes Sicherheitsnetz nutzbar.

## Sicherheitshinweis
Backup-Dateien enthalten Zugangscodes und ggf. Patientendaten → niemals ins
(öffentliche) Repo, nicht unverschlüsselt teilen, sicher aufbewahren.
