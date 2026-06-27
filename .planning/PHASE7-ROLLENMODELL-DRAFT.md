# Phase 7 — Rollenmodell · Entscheidungsvorlage (Vordenken)

> **Status:** ENTWURF zur Ratifizierung — autonom erstellt 2026-06-21, während Owner offline.
> Dies ist KEIN GSD-`CONTEXT.md` (bewusst außerhalb `.planning/phases/`, damit es
> die GSD-Phasenerkennung nicht stört). Es ist die inhaltliche Vorarbeit, die in
> die spätere `/gsd-discuss-phase` einfließt — der Owner entscheidet final.
>
> **Korrekter nächster GSD-Weg (frisch, nicht heute):**
> `/gsd-complete-milestone` (Closed Beta V1 abschließen) → `/gsd-new-milestone`
> (Governance & Übergabe, neu sortiert) → `/gsd-discuss-phase` (dieses Dokument
> als Input) → `/gsd-plan-phase`.

## Ausgangslage
Heute gibt es genau **zwei Zugangsebenen**, dazwischen nichts:
- **MasterToken** (`is_master`-JWT, global): volle Governance, alle Präsidien, Leitungs-Seite.
- **Feld-Codes** (pro Präsidium, pseudonym, kein Login): Dauerhaft / Einmal / Gast-24h.
- **Beobachter** (`is_observer` + `observer_praesidium_id`): read-only Lage, ein Präsidium.

Der „Kurs-Host"-Wunsch (Trainer gibt selbst Codes/QR fürs eigene Präsidium aus,
ohne globalen Zugriff) fällt genau in die Lücke → erstes Inkrement von Phase 7.

**Unverrückbares Prinzip:** Der **Feld-Zugang bleibt IMMER pseudonym** (Code, kein
Login). Nur die Admin-/Delegations-Ebene bekommt Rollen.

---

## Entscheidung 1 — Token-Rollen vs. echte Konten
**Empfehlung: Token-gebundene Rollen JETZT.** Echte Konten (Supabase Auth) als
separate, spätere Phase (offizieller Echtbetrieb, ohnehin PTLS-gated).

**Warum:**
- Token-Rollen passen zur Pseudonymität und nutzen die **bestehende** Mechanik:
  `access_tokens` + `jti`-Sofortsperre (`argus_token_active`) + JWT-Claims
  (`argus_praesidium_id`/`argus_is_master`/`argus_is_observer`). Minimaler
  Architektur-Eintrag: eine neue Token-Art + ein Claim.
- Echte Konten = E-Mail, Account-/Reset-Flows, Identitätsdaten (DSGVO),
  Auth-Umbau → großer Schritt, erst für den echten Polizei-Betrieb sinnvoll.
- Token-Rollen sind **sofort lieferbar** (Kurs-Host für den laufenden PPF-Kurs)
  und konsistent zu allem Bestehenden.

---

## Entscheidung 2 — Rollenliste (für JETZT)
1. **MasterUser** (global) — bleibt (`is_master`), Leitungs-Seite, volle Governance. *(existiert)*
2. **Präsidiums-Admin / „Kurs-Host"** (NEU, präsidiums-begrenzt) — darf NUR fürs
   **eigene** Präsidium nicht-privilegierte Codes ausgeben/sperren + die eigene
   Zugänge-Liste sehen. KEIN globaler Zugriff, keine anderen Präsidien, KEINE
   Einsatzprotokolle/Foto-Abrufe, KEINE Präsidiums-Anlage.
3. **Beobachter (FLZ)** — bleibt (`is_observer` + `observer_praesidium_id`). *(existiert)*

*(Landes-Observer = Phase 8, hier raus.)*

---

## Entscheidung 3 — Capability-Matrix (Entwurf)
| Fähigkeit | MasterUser | Präsidiums-Admin | Beobachter | Feld-Code |
|---|---|---|---|---|
| Gast-/Einmal-Code ausgeben | alle Präsidien | **nur eigenes** | – | – |
| Code sperren | alle | **nur eigene** | – | – |
| Zugänge-Liste sehen | alle | **nur eigene** | – | – |
| Einsatzprotokolle (abgeschlossen) | ✓ | – | – | – |
| Foto-Einzelabruf (protokolliert) | ✓ | – | – | – |
| Präsidium anlegen/provisionieren | ✓ | – | – | – |
| Lage (anonym) sehen | ✓ | optional? (offen) | eigenes | – |
| Patienten erfassen/verwalten | – | – | – | eigenes Präsidium |
| **master/admin/observer-Token erzeugen** | ✓ | **NIE** | – | – |

---

## Entscheidung 4 — Scope-Mechanik (Bau-Skizze, Planer verfeinert)
- Neue Token-Art in `access_tokens`: **boolean `is_admin`** (Muster wie
  `is_master`/`is_observer`/`gast`) + nutzt das vorhandene `praesidium_id`.
  *(Alternative: `role`-Text-Spalte — Discretion des Planers; boolean ist
  konsistenter zum Bestand.)*
- Neuer Claim `admin_praesidium_id` + Helper `argus_admin_praesidium_id()`
  (analog `argus_observer_praesidium_id()` aus 0005).
- Exchange: `argus_exchange_code` erweitern ODER eigener RPC (wie observer) →
  JWT trägt `is_admin` + `admin_praesidium_id`, **NICHT** `is_master`.
- `jti`-Sofortsperre (`argus_token_active`) gilt automatisch mit.
- Code-Ausgabe/-Sperre als **`security definer`-RPCs**, die intern hart prüfen:
  Ziel-Präsidium == `argus_admin_praesidium_id()` UND die erzeugte/zu sperrende
  Token-Art ist **nicht privilegiert** (nur Gast/Einmal; nie master/admin/observer).

---

## Erstes Inkrement (Kurs-Host, sofort für PPF)
Minimaler Satz: `is_admin`-Token + `admin_praesidium_id` + Exchange + RLS/RPC-Guards,
sodass der Token **nur Gast-Code (24 h) fürs eigene Präsidium** ausgeben/sperren
kann. Dazu **QR-Ausgabe (Deep-Link)** und eine abgespeckte Admin-Ansicht (eigene
Mini-Seite ODER reduzierte Leitungs-Seite — Discretion).

---

## Sicherheits-Leitplanken (NICHT verhandelbar)
- **Privilege-Escalation-Schutz:** Ein Admin darf NIE master/admin/observer-Tokens
  erzeugen oder sperren — ausschließlich nicht-privilegierte Codes des eigenen
  Präsidiums. RLS **und** RPC-Guards müssen das hart erzwingen.
- **REST-Negativtests Pflicht** (Muster wie Observer 4.12): Admin-JWT →
  Fremd-Präsidium = verweigert; Admin-JWT → Protokolle/Fotos = verweigert;
  Admin-JWT → master/admin-Token erzeugen = verweigert.
- Admin sieht **keine** Patientendaten/Protokolle/Fotos (bleibt MasterUser).

---

## Explizit NICHT in Phase 7
- **Audit-Log / T4** — DSB-gated (JI-Regime-Votum offen).
- **Echte Konten / Supabase Auth** — separate spätere Phase (Echtbetrieb).
- **Landes-Observer, FLZ Stufe b** — Phase 8.

---

## Ratifizierte Entscheidungen (Owner, 2026-06-22)
- **Rollenname: „Präsidiums-Admin"** (allgemein, auch über Kurse hinaus tauglich).
- **Code-Umfang: NUR Gast-Code (24 h)** fürs eigene Präsidium (+ QR). Keine Einmal-/Dauerhaft-Codes.
- **Lage-Zugriff: JA** — der Präsidiums-Admin darf die **anonyme Lage seines eigenen Präsidiums** sehen (wie ein Beobachter, auf sein Präsidium begrenzt).
- Token-Art: boolean `is_admin` + `admin_praesidium_id` (Claude's Discretion, bestätigt durch Muster).
- MasterUser gibt die Admin-Tokens aus (über die Leitungs-Seite).

## OFFEN & GRÖSSER ALS GEDACHT → Admin-Surface-Architektur (Owner-Hinweis 2026-06-22)
Die Frage „wo bedient der Admin das?" ist **nicht** eine UI-Detailfrage, sondern die
Spitze der **Admin-Oberflächen-Architektur**, die uns vor dem Echtbetrieb ohnehin
erwartet (mehr Rollen: Master, Präsidiums-Admin, Beobachter, später FLZ-operativ,
Landes-Observer, echte Konten). Owner will das **im großen Ganzen** entscheiden,
nicht ad hoc. → Eigener Diskussionspunkt, siehe Chat 2026-06-22. Backend der Rolle
ist UI-unabhängig und kann unabhängig gebaut werden.

---

*Referenzen: `.planning/ROADMAP.md` Phase 7 · `docs/KONZEPT-POLIZEIBETRIEB.md` ·
Migrationen 0001 (Claims), 0003 (revoked), 0005 (observer-Claim-Muster),
0007 (jti-Sofortsperre), 0009 (gast) · Memories: dsb-gespraech-outcome,
ptls-vibecoding-block, mdr-tacstart-accepted, ppf-kurse-evaluation.*
