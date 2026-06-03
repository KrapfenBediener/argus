# Phase 4 — Serverseitige Absicherung: Kontext & Entscheidungen

**Datum:** 2026-06-03  
**Status:** Diskussion abgeschlossen — bereit für Planning

---

## Domain

Supabase kennt serverseitig, welches Gerät welche Daten sehen darf.  
Ein direkter API-Aufruf mit dem öffentlichen Anon-Key liefert **keine** nutzbaren Daten zurück.  
Die Feld-UX bleibt unverändert — kein Login, keine Passwörter.

---

## Entscheidungen (gesperrt für Planner)

### AUTH-1 — Mechanismus: Edge Function → custom JWT

**Entscheidung:** Edge Function (Supabase Deno) validiert den 8-stelligen Code und gibt ein  
signiertes JWT zurück. Kein Anonymous-Auth, keine User-Datensätze in der DB.

**JWT-Inhalt:** `{ praesidium_id, is_master, exp, iss: "argus" }`  
**Pseudonymität:** vollständig gewahrt — kein Name, keine Email, keine UID.  
**Rationale:** Anonymous Auth würde echte User-Records erzeugen (DSGVO Art. 9 / Pseudonymitätsprinzip aus PROJECT.md verletzt).

### AUTH-2 — JWT-Laufzeiten

| Code-Typ | JWT-Laufzeit | Begründung |
|---|---|---|
| Dauerhaft | **30 Tage** | Reicht für jeden Übungszyklus; stille Verlängerung verhindert Unterbrechung |
| Temporär (24 h) | **24 Stunden** | Entspricht dem Code-TTL |
| Einmalig | **24 Stunden** | Code einmal einlösen → 24 h JWT |
| MasterToken | **30 Tage** | Wie dauerhaft |

**Stille Verlängerung:** Wenn JWT-Restlaufzeit < 7 Tage und App online → Edge Function  
im Hintergrund aufrufen (mit gespeichertem Code/Token) → neues JWT → Nutzer merkt nichts.  
→ Dauerhafter Code kann unbegrenzt oft neu eingelöst werden.

### AUTH-3 — Offline-Verhalten

**Entscheidung:** Offline ändert sich funktional nichts.  
- JWT läuft serverseitig ab, aber offline gibt es keine Server-Calls → RLS greift nicht
- Lokale Daten bleiben voll zugreifbar und bearbeitbar
- Bei Wiederverbindung: wenn JWT noch gültig → weiterarbeiten; wenn abgelaufen → Code-Eingabe
- **Kritisch:** Dauerhafter Code kann jederzeit neu eingelöst werden → kein Aussperr-Risiko

### RLS-1 — Granularität: Präsidiums-Ebene

**Entscheidung:** Server trennt Daten auf **Präsidiums-Ebene**.  
Ein JWT mit `praesidium_id = X` sieht alle CCPs und Patienten dieses Präsidiums.  
MasterToken (`is_master = true`) sieht alles.  
**Rationale:** CCP-Ebene würde Beitreten/Zusammenführen ohne Zusatzlogik unmöglich machen.

### RLS-2 — Betroffene Tabellen

Alle fünf Tabellen erhalten neue Policies (bestehende `anon_all: true` wird entfernt):
- `patients` — nur CCPs des eigenen Präsidiums
- `ccps` — nur CCPs des eigenen Präsidiums
- `checklists` — nur CCPs des eigenen Präsidiums
- `access_tokens` — Lesen: eigener Code; Schreiben: nur single_use-Insert/Update (bestehende Policies bleiben)
- `praesidien` — alle lesen (für Landingpage); kein Write

### ROLLOUT-1 — Einmaliger Schnitt

**Entscheidung:** Sauberer Schnitt — kein Parallelbetrieb alter und neuer Auth.  
- Nach Deploy: App prüft beim Start ob JWT vorhanden
- Kein JWT → Code-Eingabe-Bildschirm (wie beim Präsidium-Umstieg, der reibungslos funktioniert hat)
- Nutzer geben ihren dauerhaften Code einmal neu ein → 30-Tage-JWT → 30 Tage Ruhe
- **Kommunikation:** Tester vorab informieren (1 Nachricht: „nach Update einmal Code neu eingeben")

---

## Architektur (für Planner)

```
Heute:
  Gerät → Anon-Key (öffentlich) → Supabase (alles offen)

Nach Phase 4:
  Gerät → Code → Edge Function (secret service role key) → JWT
  Gerät → JWT als Bearer → Supabase → RLS prüft praesidium_id → nur eigene Daten
```

**App-seitige Änderungen:**
1. `validateInviteToken()` → ruft Edge Function auf statt DB direkt
2. JWT in localStorage speichern (`argus_jwt`)
3. Supabase-Client mit JWT als Authorization-Header initialisieren
4. Stille Verlängerungslogik beim App-Start
5. Fallback bei abgelaufenem JWT → Code-Eingabe

**Supabase-seitige Änderungen:**
1. Edge Function `exchange-code` deployen (Deno/TypeScript)
2. JWT-Hilfsfunktion in DB (extrahiert `praesidium_id` aus JWT-Claims)
3. Alle RLS-Policies neu schreiben (5 Tabellen)
4. Alte `anon_all: true` Policies entfernen

---

## Randbedingungen aus PROJECT.md (für Planner beachten)

- **Kein Build-System** — Edge Function muss über Supabase-Dashboard oder Management API deployt werden
- **Supabase Free Tier** — Edge Functions sind verfügbar, kein Limit-Problem für Beta
- **Offline-first** — JWT darf nie den Offline-Betrieb blockieren
- **Stressbedienung** — kein sichtbarer Login-Schritt; Code-Neueingabe ist die einzige Ausnahme
- **Polizei BW / dienstliche iPhones** — CDN-Verfügbarkeit wichtig; Edge Function ist eigener Supabase-Endpunkt (kein externer CDN)

---

## Abgegrenzt (nicht Phase 4)

- Nutzerverzeichnis / Admin-UI → Phase 7
- `revoked`-Flag mit UI → Phase 7
- Produktions-Supabase-Projekt → Phase 5
- Datenlöschkonzept (24h auto-delete) → Phase 5 / Compliance

---

## Canonical Refs

- `.planning/ROADMAP.md` — Phase-4-Ziel
- `.planning/PROJECT.md` — Pseudonymität, Offline-Anforderung, DSGVO, Kosten-Constraint
- `index.html` — `sb()`, `validateInviteToken()`, `addUnlock()`, `extractInviteCode()`
- `docs/COMPLIANCE.md` — DSGVO Art. 9, LDSG BW (für RLS-Policy-Begründung)
- Supabase Docs: Edge Functions / JWT / RLS custom claims (extern)
