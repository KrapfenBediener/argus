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

Die gesamte Datenbank entsteht aus sieben Migrationsdateien, die in Reihenfolge
angewendet werden (Abschnitt 5):

```
supabase/migrations/0000_base_schema.sql          Tabellen, Grants, RLS-Grundlage
supabase/migrations/0001_phase4_jwt_rls.sql        Code→JWT-Exchange-RPC, RLS-Policies
supabase/migrations/0002_phase48_datenschutz.sql   Lösch-Lebenszyklus, Logs, Purge, pg_cron-Job
supabase/migrations/0003_phase49_einsatzprotokoll.sql  Einsatzprotokoll-RPCs, Code-Sperre
supabase/migrations/0004_phase410_log_retention.sql    Log-Aufbewahrung 12 Monate
supabase/migrations/0005_phase412_lageansicht.sql      Beobachter-Token, Observer-JWT, Aggregat-RPC argus_lage
supabase/migrations/0006_token_hygiene.sql             24-h-Codes abgeschafft, verbrauchte Einmal-Codes 6 Monate
```

Audit über alle Dateien — jede Server-Abhängigkeit, wo sie vorkommt,
wofür sie gebraucht wird, und wie sie geprüft wird (0005 nutzt dieselben
Abhängigkeiten wie 0001/0003: pgjwt + Vault-Secret für den Observer-Exchange;
0006 hat keine neuen Abhängigkeiten):

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

---

## 5. Migrationen anwenden (Ein-Schritt-Apply)

Alle Dateien in Reihenfolge anwenden — die alphabetische Reihenfolge der
Dateinamen IST die korrekte Reihenfolge:

```bash
for f in supabase/migrations/*.sql; do
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```

Alternativ jede Datei einzeln im SQL-Editor (Supabase Studio) ausführen —
gleiche Reihenfolge: `0000 → 0001 → 0002 → 0003 → 0004 → 0005 → 0006`.

Hinweise:

- `0002` richtet am Ende den `pg_cron`-Job ein. Der Block ist fehlertolerant:
  fehlt `pg_cron`, läuft die Migration trotzdem durch und meldet nur eine
  `NOTICE`. Danach prüfen: `select jobname, schedule from cron.job;` —
  erwartet wird `argus_purge` mit `17 * * * *`. Fehlt der Eintrag, gilt der
  Ersatzweg aus Abschnitt 3 (App-Start-Purge bzw. externer Scheduler).
- Die Skripte sind weitgehend idempotent; ein versehentliches zweites Anwenden
  ist gefahrlos. Trotzdem gilt: frische, leere Datenbank ist der vorgesehene
  und getestete Pfad.

## 6. Realtime-Publikation einrichten (steht NICHT in den Migrationen)

Der Mehrgeräte-Live-Sync der Feld-App abonniert `postgres_changes` auf
`public.patients` und `public.ccps`. Dafür müssen beide Tabellen Mitglied der
Publikation `supabase_realtime` sein — dieser Schritt ist **bewusst nicht**
Teil der Migrationsdateien und muss einmalig ausgeführt werden:

```sql
alter publication supabase_realtime add table public.patients;
alter publication supabase_realtime add table public.ccps;
```

(Alternativ im Supabase Studio: Database → Publications → `supabase_realtime`
→ beide Tabellen aktivieren.)

Funktionsprüfung:

```sql
select * from pg_publication_tables where pubname = 'supabase_realtime';
```

Erwartung: zwei Zeilen (`public.patients`, `public.ccps`). Der Live-Beweis
folgt im Smoke-Test (Abschnitt 10, Schritt 4).

## 7. Vault-Secret `argus_jwt_secret` anlegen — **kritischster Schritt**

Der Code-Exchange-RPC signiert Geräte-JWTs mit dem Secret, das er zur
Laufzeit aus `vault.decrypted_secrets` unter dem Namen `argus_jwt_secret`
liest. **Dieses Secret MUSS exakt dem JWT-Secret entsprechen, mit dem
PostgREST (bzw. der Supabase-Stack) der Ziel-Instanz Tokens verifiziert** —
beim Docker-Compose-Stack ist das der Wert `JWT_SECRET` aus der `.env`.

Stimmen die Werte nicht überein, lehnt die API **alle** vom RPC ausgestellten
JWTs ab (HTTP 401) — kein Code lässt sich einlösen, obwohl der RPC selbst
fehlerfrei antwortet. Das ist der mit Abstand häufigste Aufbaufehler.

Anlegen (SQL, einmalig):

```sql
select vault.create_secret('<JWT-Secret-der-Instanz>', 'argus_jwt_secret');
```

(Alternativ im Studio: Settings → Vault → New Secret.)

Prüfen:

```sql
select name from vault.decrypted_secrets where name = 'argus_jwt_secret';
```

Erwartung: genau eine Zeile. Den Klartext-Wert nirgends versionieren oder
notieren — er ist ein echtes Geheimnis (anders als der öffentliche anon-Key).

## 8. Frische Zugangsdaten erzeugen — NIEMALS alte übernehmen

Auf der neuen Instanz werden **ausschließlich neue** Präsidien, Einsatz-Codes
und ein **neuer** MasterToken angelegt. Codes oder Tokens aus anderen
Umgebungen (Schulung, Demo, frühere Instanzen) dürfen **nicht** übernommen
werden — sie gelten als kompromittiert.

Code-Konvention: 8 Zeichen im Format `XXXX-XXXX`, Großbuchstaben/Ziffern;
empfohlen ist ein verwechslungssicheres Alphabet ohne `0/O/1/I`
(z. B. `A–Z ohne I,O` plus `2–9`). Die Spalte `short_code` trägt den Code,
`token` ist ein interner Zufallswert (Primärschlüssel).

```sql
-- 1) Präsidium anlegen — die zurückgegebene UUID unten einsetzen
insert into public.praesidien (name)
values ('<Name des Präsidiums>')
returning id;

-- 2) Dauerhafter Einsatz-Code (beliebig oft einlösbar, JWT-Laufzeit 30 Tage)
insert into public.access_tokens (token, short_code, praesidium_id, label)
values (encode(extensions.gen_random_bytes(16), 'hex'),
        '<XXXX-XXXX>', '<praesidium-uuid>', 'Dauercode <Bezeichnung>');

-- 3) 24-h-Code (JWT verfällt nach 24 Stunden)
insert into public.access_tokens (token, short_code, praesidium_id, label, temporary, ttl_hours)
values (encode(extensions.gen_random_bytes(16), 'hex'),
        '<XXXX-XXXX>', '<praesidium-uuid>', '24h-Code <Bezeichnung>', true, 24);

-- 4) Einmal-Code (nach der ersten Einlösung verbraucht)
insert into public.access_tokens (token, short_code, praesidium_id, label, single_use)
values (encode(extensions.gen_random_bytes(16), 'hex'),
        '<XXXX-XXXX>', '<praesidium-uuid>', 'Einmal-Code <Bezeichnung>', true);

-- 5) NEUER MasterToken (volle Sicht über alle Präsidien + Leitungs-Zugang)
insert into public.access_tokens (token, short_code, is_master, label)
values (encode(extensions.gen_random_bytes(16), 'hex'),
        '<XXXX-XXXX>', true, 'MasterToken');
```

Codes können später jederzeit über die Leitungs-Oberfläche gesperrt werden
(`revoked`-Flag); gesperrte Geräte melden sich beim nächsten Start/Reconnect
selbst ab.

## 9. App auf die neue Instanz zeigen (config.js) + Hosting

Der **einzige Eingriff in die App** ist das Editieren von `config.js` im
Projektroot — keine Änderung an `index.html`, `sw.js` oder anderen Dateien:

```js
window.ARGUS_CONFIG = {
  url: 'https://<api-host>',            // Basis-URL der eigenen Instanz
  anonKey: '<anon-key-der-instanz>'     // öffentlicher anon-Key der Instanz
};
```

Beide Werte sind öffentlich (sie werden an jeden Browser ausgeliefert) —
**niemals** Service-Keys oder das JWT-Secret hier eintragen.

Hosting:

- Alle App-Dateien (`index.html`, `sw.js`, `config.js`, `version.json`,
  `manifest.webmanifest`, `vendor/`, `fonts/`, `docs/` …) über einen
  beliebigen **statischen HTTPS-Webserver/CDN** ausliefern — kein Build,
  kein Application-Server.
- Getrennte Origins für App und API beachten (Abschnitt 4).
- **Leitungs-Seite:** liegt unter `docs/leitung-<zufallssuffix>.html`. Der
  Betreiber vergibt einen **eigenen, zufälligen** Dateinamen (z. B. 12+
  zufällige Hex-Zeichen) und teilt die URL nur dem Leitungs-Personenkreis
  mit. Der Name ist eine Auffindbarkeits-Hürde — die eigentliche
  Zugangskontrolle ist der MasterToken-Login der Seite.

## 10. Smoke-Test-Drehbuch (Abnahme der Instanz)

Benötigt: zwei Geräte/Browser, ein Einsatz-Code, der MasterToken, SQL-Zugang.

1. **Code einlösen:** App-URL auf Gerät 1 öffnen, Einsatz-Code eingeben.
   → *Erwartung:* Präsidium wird freigeschaltet, Statusanzeige grün
   (verbunden). Schlägt dies mit „Ungültiger Code" fehl, obwohl der Code
   existiert → Abschnitt 8 prüfen; bei Verbindungs-/401-Fehlern → Abschnitt 7
   (JWT-Secret-Abgleich).
2. **CCP anlegen:** Auf Gerät 1 einen CCP eröffnen (Bediener-Kürzel setzen).
   → *Erwartung:* CCP erscheint mit Kennung `A`.
3. **Patient erfassen:** Patient mit Kategorie (z. B. T1) und Vitalwerten
   anlegen. → *Erwartung:* Patient erscheint in der Übersicht mit laufender
   Nummer 1.
4. **Live-Sync (Realtime-Prüfung):** Auf Gerät 2 denselben Code einlösen und
   dem CCP beitreten. → *Erwartung:* Der Patient von Gerät 1 ist sichtbar;
   eine Änderung auf Gerät 1 (z. B. Kategorie-Wechsel) erscheint auf Gerät 2
   **binnen Sekunden ohne Neuladen**. Erscheint sie erst nach Neuladen →
   Realtime-Publikation fehlt (Abschnitt 6).
5. **Einsatz-Abschluss:** Auf Gerät 1 den Einsatz abschließen (Typ Übung oder
   Einsatz). → *Erwartung:* Hinweis auf die 72-h-Löschfrist; beide Geräte
   bereinigen ihre lokale Ansicht.
6. **Leitungs-Seite:** Die Leitungs-URL öffnen, mit dem MasterToken anmelden,
   unter „Einsatzprotokolle" den abgeschlossenen Einsatz mit Kürzel abrufen.
   → *Erwartung:* Protokoll wird angezeigt; der Abruf selbst erscheint
   anschließend im Bereich „Protokoll" (jeder Abruf wird festgehalten).
7. **Purge-Lauf prüfen:** Per SQL `select public.argus_run_purge();`
   ausführen. → *Erwartung:* JSON mit Zählern (`foto`, `frist`, `inaktiv`,
   `log_retention`) — bei frischer Instanz überall 0. Zusätzlich
   `select jobname, schedule from cron.job;` → Eintrag `argus_purge`
   (`17 * * * *`); fehlt er, Ersatzweg aus Abschnitt 3 dokumentiert betreiben.
8. **Negativ-Prüfungen (Pflicht):** REST-Abfragen mit dem anon-Key **ohne**
   eingelöstes JWT:

   ```bash
   curl -s "https://<api-host>/rest/v1/patients?select=id" \
     -H "apikey: <anon-key>" -H "Authorization: Bearer <anon-key>"
   curl -s "https://<api-host>/rest/v1/access_tokens?select=short_code" \
     -H "apikey: <anon-key>" -H "Authorization: Bearer <anon-key>"
   ```

   → *Erwartung:* beide liefern `[]` (leere Liste) — ohne Geräte-JWT sind
   weder Patientendaten noch Zugangs-Codes lesbar. Liefert die zweite Abfrage
   Codes zurück, ist die Instanz FALSCH aufgebaut (Migration 0001 fehlt) —
   Betrieb stoppen.

Alle acht Schritte bestanden → die Instanz ist abgenommen.

## 11. Betriebsvorgaben für Lizenznehmer (verbindlich)

1. **Nur verwaltete Dienstgeräte.** ARGUS wird ausschließlich auf per **MDM**
   verwalteten Dienstgeräten mit erzwungenem Gerätesperrcode betrieben —
   keine Privatgeräte.
2. **Kürzel-Liste je Einsatz.** Die Bediener-Kürzel sind pseudonym; die
   Zuordnung Kürzel → Person führt der Einsatzleiter je Einsatz als Liste
   (außerhalb von ARGUS). Ohne diese Liste sind Protokoll-Einträge später
   nicht zuordenbar.
3. **Einsatz-Codes nur mündlich/Funk.** Codes werden ausschließlich mündlich
   oder über Funk weitergegeben — niemals schriftlich verteilen, nicht per
   Messenger/E-Mail versenden, nicht aushängen. Bei Verdacht auf
   Kompromittierung: Code über die Leitungs-Oberfläche sperren und neuen
   Code ausgeben.
