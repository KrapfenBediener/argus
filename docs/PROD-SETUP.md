# ARGUS — Produktiv-Setup (Runbook für Phase 5)

> Schritt-für-Schritt-Anleitung, um ein **separates, sauberes Produktiv-Projekt**
> aufzusetzen und vom Beta zu trennen. Reihenfolge einhalten — jeder Schritt baut
> auf dem vorigen auf.

## Voraussetzungen
- Supabase-Konto, neues Projekt auf **Pro-Tier**, **EU-Region** (Frankfurt).
- Ein **Personal Access Token (PAT)** für die Management-API (nach Setup widerrufen).
- Die beiden Migrationsdateien aus dem Repo:
  `supabase/migrations/0000_base_schema.sql` und `0001_phase4_jwt_rls.sql`.

## Schritte

**1. Neues Projekt anlegen**
- Supabase → New Project → Region EU (Frankfurt), Plan **Pro**.
- Notieren: **Project Ref**, **Project URL**, **anon public key**, **JWT-Secret**
  (Settings → API). Das JWT-Secret wird in Schritt 3 gebraucht.

**2. Schema einspielen** (SQL Editor oder Management-API `/database/query`)
- Erst `0000_base_schema.sql`, dann `0001_phase4_jwt_rls.sql`.
- Damit existieren Tabellen, Constraints, Indizes, Grants, RLS, JWT-Funktionen,
  Token-Exchange-RPC und alle Policies.

**3. JWT-Secret in den Vault legen** (kritisch!)
- Vault → New Secret: Name **`argus_jwt_secret`**, Wert = **das JWT-Secret dieses
  neuen Projekts** (aus Schritt 1). Muss übereinstimmen, sonst lehnt PostgREST die
  vom RPC signierten JWTs ab.

**4. Präsidien + Codes anlegen** (frisch — KEINE alten Codes übernehmen)
- `insert into praesidien (name) values ('PP …');`
- Pro Präsidium Codes erzeugen (dauerhaft / 24 h / einmalig) + **einen neuen
  MasterToken**. (Der alte MasterToken war im Beta zeitweise per Anon-Key lesbar.)

**5. App auf das neue Projekt zeigen**
- In `index.html`: `SUPA_URL` und `SUPA_KEY` (anon) auf das neue Projekt setzen.
- `APP_VERSION` + `version.json` hochsetzen, `sw.js` `CACHE_NAME` bumpen.

**6. Deployen & alte Welt einfrieren**
- (Empfohlen) **privates** GitHub-Repo, Git-History übernehmen; altes öffentliches
  Repo archivieren.
- Altes Beta-Supabase pausieren, alte URL stilllegen.
- Tester informieren: **PWA neu installieren** (neue URL), Code **neu** eingeben.

**7. Backup & Löschen (DSGVO)**
- Pro-Tier: tägliche Backups aktiv (prüfen). Restore einmal testen.
- Löschkonzept dokumentieren (z. B. Patientendaten X h/Tage nach Übung löschen)
  und einen Lösch-Durchlauf testen. Siehe `docs/DSB-BRIEFING.md`.

## Verifikation (nach Setup)
- Anon-Key **ohne** JWT → `patients`/`ccps` liefern `[]`.
- Code → RPC `argus_exchange_code` → gültiges JWT.
- JWT eines Präsidiums → nur dessen Daten; MasterToken → alles.
- `access_tokens` ohne JWT → `[]` (Codes nicht abgreifbar).
- App auf echtem iPhone: Code-Eingabe, CCP eröffnen, Patient erfassen, Mehrgeräte.

## Danach
- PAT widerrufen.
- `.planning/STATE.md` + `ROADMAP.md` (Phase 5) auf abgeschlossen setzen.
