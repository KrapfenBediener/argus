# ARGUS — Self-Hosting-Anleitung

> Aufbau einer eigenen ARGUS-Backend-Instanz auf eigener Supabase-/Postgres-
> Infrastruktur. Zielgruppe: fachkundige Administrator:in (Postgres/Docker)
> **ohne** Projektkenntnis. Die Anleitung ist vollständig — es wird kein
> weiteres internes Wissen benötigt.

---

## 1. Zielbild & Geltungsbereich

ARGUS wird als Software lizenziert; der **Lizenznehmer betreibt das Backend
selbst** auf eigener Infrastruktur und stellt damit den datenschutzrechtlich
Verantwortlichen (Betriebsmodell „Eigenbetrieb"). Die Instanz des Eigentümers
bleibt reine Entwicklungs- und Schulungsumgebung mit Fiktivdaten — sie ist
**nicht** Teil des Echtbetriebs.

Was diese Anleitung liefert:

1. Ehrliche Einordnung der zwei Aufbau-Varianten (Abschnitt 2)
2. Vollständige Liste der Server-Abhängigkeiten mit Prüfschritten (Abschnitt 3)
3. Betriebs-Voraussetzungen (Abschnitt 4)
4. Schritt-für-Schritt-Aufbau: Migrationen, Realtime, Secrets, Zugangsdaten,
   App-Konfiguration (Abschnitte 5–9)
5. Smoke-Test-Drehbuch zur Abnahme (Abschnitt 10)
6. Verbindliche Betriebsvorgaben für den Lizenznehmer (Abschnitt 11)

Lizenz-/Vertragsfragen sind nicht Teil dieser Anleitung; es gilt der
Lizenzrahmen zwischen Eigentümer und Lizenznehmer.

---

## 2. Varianten (ehrliche Einordnung)

### Variante A — Supabase self-hosted (Docker Compose) · **Empfohlen**

Der komplette Supabase-Stack (Postgres, PostgREST, Realtime, Vault, GoTrue,
Studio) als Docker-Compose-Deployment auf eigener Hardware/VM
(siehe offizielle Supabase-Self-Hosting-Dokumentation).

- **Voller Funktionsumfang:** Vault, Realtime und die PostgREST-Konventionen
  sind vorhanden; `pg_cron` ist im Supabase-Postgres-Image enthalten
  (Verfügbarkeit je nach Image-Version prüfen, siehe Abschnitt 3).
- ARGUS läuft dann **ohne jede Code-Änderung** — nur `config.js` wird
  ausgetauscht (Abschnitt 9).

### Variante B — Verwaltetes Postgres + PostgREST-kompatible Schicht

Eigenes Postgres (z. B. Landes-Rechenzentrum) plus selbst betriebener
PostgREST. Das ist möglich, hat aber **ehrliche Einschränkungen**:

| Baustein | Status in Variante B |
|---|---|
| PostgREST + Rolle `anon` | Selbst aufzusetzen: Rolle `anon` (nologin) anlegen, PostgREST mit `db-anon-role = anon` und dem JWT-Secret der Instanz konfigurieren. Die RLS-Policies lesen Claims über `request.jwt.claims` — das stellt PostgREST automatisch bereit. |
| `pgjwt` | Selbst zu installieren (kleine SQL-Extension, benötigt `pgcrypto`). **Pflicht**, kein Ersatzweg. |
| Vault (`vault.decrypted_secrets`) | Existiert außerhalb von Supabase nicht. Ersatzweg nötig: ein Schema `vault` mit einer kompatiblen Relation `decrypted_secrets` (Spalten `name`, `decrypted_secret`) bereitstellen, die das JWT-Secret liefert — oder die zwei Code-Exchange-Funktionen beim Deployment auf die eigene Secret-Quelle anpassen. Die ARGUS-Migrationen selbst werden dafür **nicht** verändert. |
| Realtime | Entfällt. **Konsequenz:** Der Live-Sync zwischen Geräten entfällt — Änderungen anderer Geräte erscheinen erst beim Neuladen/Neustart der App. Die App bleibt funktionsfähig (local-first), aber die Mehrgeräte-Erfahrung ist deutlich eingeschränkt. |
| `pg_cron` | Falls nicht verfügbar: externer Scheduler (z. B. systemd-Timer mit `psql -c "select public.argus_run_purge();"`) **oder** der eingebaute Fallback — die App stößt den Purge-Lauf bei jedem Start opportunistisch an (in Migration 0002 so vorgesehen). |

**Empfehlung: Variante A.** Sie liefert den vollen Funktionsumfang ohne
Anpassungen und ist der getestete Pfad. Variante B nur wählen, wenn
organisatorische Vorgaben den Supabase-Stack ausschließen — die
Realtime-Einschränkung vorher bewusst abnehmen.

---

## 3. Server-Abhängigkeiten (Kompatibilitäts-Audit)

Die gesamte Datenbank entsteht aus fünf Migrationsdateien, die in Reihenfolge
angewendet werden (Abschnitt 5):

```
supabase/migrations/0000_base_schema.sql          Tabellen, Grants, RLS-Grundlage
supabase/migrations/0001_phase4_jwt_rls.sql        Code→JWT-Exchange-RPC, RLS-Policies
supabase/migrations/0002_phase48_datenschutz.sql   Lösch-Lebenszyklus, Logs, Purge, pg_cron-Job
supabase/migrations/0003_phase49_einsatzprotokoll.sql  Einsatzprotokoll-RPCs, Code-Sperre
supabase/migrations/0004_phase410_log_retention.sql    Log-Aufbewahrung 12 Monate
```

Audit über alle fünf Dateien — jede Server-Abhängigkeit, wo sie vorkommt,
wofür sie gebraucht wird, und wie sie geprüft wird:

| Abhängigkeit | Vorkommen | Wofür | Einstufung | Prüfung |
|---|---|---|---|---|
| `uuid-ossp`, `pgcrypto` (Schema `extensions`) | 0000 | UUID-Defaults, Zufallswerte | **Pflicht** (Standard-Extensions, überall verfügbar) | `select extensions.uuid_generate_v4();` |
| `pgjwt` (Schema `extensions`) | 0000 (Installation), 0001 + 0003 (`extensions.sign(...)`) | Signiert die Geräte-JWTs im Code-Exchange-RPC `argus_exchange_code` | **Pflicht** — ohne pgjwt keine Code-Einlösung | `select extensions.sign('{"sub":"test"}'::json, 'geheim');` → liefert ein JWT |
| `vault.decrypted_secrets` mit Secret **`argus_jwt_secret`** | 0001 + 0003 (jeweils im Exchange-RPC) | Liefert dem RPC das JWT-Signatur-Secret zur Laufzeit | **Pflicht in Variante A** (Secret anlegen! Abschnitt 7); Variante B: Ersatzweg (Abschnitt 2) | `select name from vault.decrypted_secrets where name = 'argus_jwt_secret';` → 1 Zeile |
| `pg_cron` / Job `argus_purge` | 0002 (Einrichtung, fehlertolerant gekapselt), 0004 (nutzt denselben Job unverändert) | Stündlicher automatischer Lösch-Lauf (`17 * * * *` → `public.argus_run_purge()`) | **Optional mit Ersatzweg** — Migration 0002 bricht ohne pg_cron NICHT ab; Fallback: App-Start-Aufruf des Purge (eingebaut) und/oder externer Scheduler | `select jobname, schedule from cron.job;` → Zeile `argus_purge` / `17 * * * *` |
| **Realtime-Publikation** für `public.patients` + `public.ccps` | In KEINER Migration enthalten — **separater Einrichtungsschritt** (Abschnitt 6) | Mehrgeräte-Live-Sync der Feld-App (`postgres_changes`-Subscriptions) | **Pflicht für Live-Sync** (Variante A); in Variante B entfällt Realtime ganz | `select * from pg_publication_tables where pubname = 'supabase_realtime';` → beide Tabellen gelistet |
| Rolle `anon` + PostgREST-Konventionen (`request.jwt.claims`) | 0000 (Grants Z. „Grants"-Block), alle RLS-Policies in 0001–0003 | API-Rolle der App; RLS bindet Zugriff an JWT-Claims (`praesidium_id`, `is_master`) | **Pflicht** — bei Supabase vorhanden; in Variante B selbst anzulegen | Ohne JWT: `patients`-Abfrage liefert `[]` (siehe Smoke-Test Schritt 8) |

**Wichtigster Stolperstein vorweg:** Das Vault-Secret `argus_jwt_secret` MUSS
exakt dem JWT-Secret entsprechen, mit dem PostgREST der Ziel-Instanz Tokens
verifiziert — sonst lehnt die API **alle** vom RPC signierten JWTs ab und kein
einziger Code lässt sich einlösen. Details in Abschnitt 7.

---

## 4. Betriebs-Voraussetzungen (Befunde ohne Code-Änderung)

1. **App-Hosting und API auf getrennten Origins betreiben.** Der Service
   Worker der App behandelt nur `*.supabase.co`-Hostnamen explizit als
   Network-only. Läuft die API unter eigener Domain, greifen die
   Network-first-Regeln — funktional unkritisch (API-Antworten werden dort
   nie in den Shell-Cache geschrieben), **aber:** lägen App und API auf
   demselben Origin, würde die Shell-Cache-Regel auf API-Pfade greifen.
   Deshalb verbindlich: statisches App-Hosting (z. B. `app.example.org`) und
   API-Endpunkt (z. B. `api.example.org`) auf **verschiedenen Origins**.
2. **HTTPS ist Pflicht** — für die PWA-Installation, den Service Worker und
   die Kamera-Funktion. Selbstsignierte Zertifikate funktionieren auf
   iOS-Dienstgeräten nur mit per MDM verteilter CA.
3. **Frische Instanz empfohlen.** Die Migrationen sind weitgehend idempotent
   (zweifaches Anwenden ist gefahrlos), aber als Aufbau-Pfad ist eine leere,
   frische Datenbank vorgesehen — keine Übernahme von Bestandsdaten.
