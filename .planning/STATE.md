---
gsd_state_version: 1.0
milestone: v0.19.5
milestone_name: Iterative Feature-/Schulungsarbeit im Test-/Härtungsfenster
status: Phase 5.1 — 05.1-01/02/03 fertig (05.1-03 inkl. Twin-Scope-Gap-Closure via Migration 0019 LIVE); nur noch 05.1-04 Release (Version-/SW-Bump, CHANGELOG/WHATS_NEW/UPDATE-Sheet, Drehbuch, SELF-HOSTING-Nachzug 0019) ausstehend
last_updated: "2026-06-28T00:20:00.000Z"
progress:
  total_phases: 11
  completed_phases: 8
  total_plans: 35
  completed_plans: 28
  percent: 80
---

# Projekt-Status — Argus (CCP-App)

> ## Stand 2026-06-27 (Roadmap-Neuordnung + Sicherheits-Nachzug, aktuell)
> **Phase 04.14 abgeschlossen & gepusht** (origin/main, GitHub Pages live).
> Beim Phasen-Code-Review + projektweitem Review zwei echte Funde behoben:
> (1) **CR-02 Privilege-Escalation** — `argus_exchange_code` akzeptierte
> `is_admin`-Codes → **Migration 0014** weist sie ab + erzwingt `expires_at`
> im Admin-Exchange (CR-01); live verifiziert. (2) **Tote, aber deployte Edge
> Function `exchange-code`** (alte schwache Exchange-Logik, BOOT_ERROR) **undeployt
> + Quelle entfernt** (Endpunkt 404) — latente Bypass-Fläche beseitigt. QR-Encoder
> (Plan 03) war nicht lauffähig → durch MIT-Lib ersetzt, per jsQR als scanbar belegt.
> Offener Follow-up-Task: pre-existing Foto-`src`-XSS (Leitungs-Protokollansicht).
>
> **Roadmap-Neuordnung (Owner-Entscheid 2026-06-27)** — ersetzt die Ordnung vom
> 2026-06-21. Neue Nummern = Ausführungsreihenfolge:
> **Phase 5 Identitäten & Audit-Protokoll (Stufe 1)** ← **DSB-Abhängigkeit entfällt**
> (Owner-Entscheid; löst den „JI-Regime"-Vorbehalt ab) · **Phase 6 FLZ-Lage Stufe b** ·
> **Phase 7 Betriebsbereitschaft & Open Beta** (danach PPF-Nutzungsfreigabe) ·
> **Phase 8 Übergabe-Paket** · **Phase 9 Native App PTLS** (conditional).
> **Nächster Schritt:** Phase 5 — `/gsd-discuss-phase 5` (oder direkt planen).
> Architektur-Grundlage Stufe 1: `.planning/PHASE7-ROLLENMODELL-DRAFT.md`.
> Hinweis: Schulungsumgebung-Leeren („Übungs-Präsidium leeren") ist seit 4.14 live.

> ## Stand 2026-06-21 (Vorgänger — manuell nachgezogen)
> **App feature-complete; Releases bis v0.31.0 live.** Seit dem letzten STATE-Update (13.06.):
> - **Phase 4.13** (Schulungs-Provisionierung, Tombstone-Reset, AT-MIST-Druck) abgeschlossen.
> - **tacSTART:** kurz zum statischen Schaubild de-qualifiziert (v0.29.x, MDR-Grund), dann auf **Owner-Entscheid zurück zum geführten Walk** (v0.30.0). MDR-Einstufung bewusst akzeptiert → Memory [[mdr-tacstart-accepted]] · `docs/MDR-EINSTUFUNG.md`. NICHT eigenmächtig rückbauen.
> - **Fotos dauerhaft an** (v0.31.0, DSB-Freigabe) — MasterMedic-Schalter entfernt, 72-h-Löschung bleibt.
> - **DSB-Gespräch geführt (2026-06-21):** freigegeben; Supabase-Sorge via Self-Hosting beantwortet; Bedenken überschätzt. T4-Audit-Log (JI-Regime) NICHT explizit votiert → bleibt konditional.
> - **PTLS-Blocker:** PTLS Pol sperrt KI-generierte Apps bis zur kommenden Richtlinie → **offizieller Echtbetrieb extern blockiert** (Adoptions-, kein Technik-Blocker).
> - **PPF-Kurs:** Präsidium 'PPF-Kurse' (Rename von 'PP Karlsruhe — Schulung'), anonymer Evaluationsbogen `docs/evaluation.html` + Migration 0012 live; frische Daten-Sicherung gezogen.
>
> **Roadmap-Neuordnung (Owner-Entscheid 2026-06-21):** Übergabe-Paket (Phase 5/6) ans **Ende**; **Phase 7 (Identitäten & Rollen) vorgezogen**, um die PTLS-Wartezeit produktiv zu nutzen. Audit-Log/T4 bleibt in Phase 7 ausgeklammert (DSB-gated). Erstes Inkrement: präsidiums-begrenzte **„Kurs-Host"-Rolle**.
> **Phase 04.14 ist ABGESCHLOSSEN** (2026-06-27) — „Governance-Panel-
> Vervollständigung (schlank, ohne Stufe 1)". Alle 3 Pläne / 3 Wellen ausgeführt
> & per Browser-Checkpoint freigegeben. Ordner `.planning/phases/04.14-governance-panel/`
> (CONTEXT + 01/02/03-PLAN + 01/02/03-SUMMARY).
> - **Plan 01** (Migration 0013, Admin-Rolle is_admin + scoped RPCs + REST-Negativtests),
>   **Plan 02** (rollen-adaptive Leitungs-Seite: Admin-Login, Gast-Code, eigene Lage),
>   **Plan 03** (Gast-Code-QR via Inline-`qrcode-generator` MIT + Deep-Link,
>   Master-Aktion „Übungs-Präsidium leeren" schulung-gated → `argus_schulung_reset`,
>   Audit-Ansicht kürzelbasiert ausgebaut + interner Datenschutz-Doku-Sync local-only).
> - **Plan-03-Notiz:** hand-gerollter QR-Encoder war nicht lauffähig → durch erprobte
>   MIT-Library ersetzt, im Browser per jsQR dekodiert (scannbar). `APP_INSTALL_URL`
>   = kanonische Feld-App-Adresse (GitHub Pages). Live-Leeren per Owner-Entscheid
>   NICHT ausgeführt (RPC bereits in 4.13 bewiesen). „Demo-Befüllung opt-in" Befund:
>   bereits benutzerausgelöst, nichts zu entfernen.
> **Nächster Schritt:** nächste Phase wählen — Phase 7 (Identitäten & Rollen, Stufe 1/
>   USBNK/T4) bleibt DSB-gated; Übergabe-Paket (Phase 5/6) ans Ende der Roadmap.
> **Architektur-Grundlage:** `.planning/PHASE7-ROLLENMODELL-DRAFT.md` (Stufenmodell;
> Stufe 1/USBNK/T4, Feld-App-Änderungen, SSO sind spätere Folgephasen).
> **GSD-Hinweis:** Phasen werden über ihr Verzeichnis getrackt; 5–9 bleiben ROADMAP-
> Skizzen ohne Ordner. Formaler Milestone-Schnitt (complete/new-milestone) bleibt
> optional/später (Buchführungs-Drift, kein Mehrwert für die Arbeit).

- **Milestone:** Closed Beta V1 — läuft
- **Aktuelle Phase:** 4.12 FLZ-Lageansicht Stufe a — **ABGESCHLOSSEN
  2026-06-12, KEIN App-Release (Feld-App weiter v0.24.0 / SW v43)**:
  Migration 0005 (Beobachter-Token in access_tokens, eigener Exchange-RPC
  `argus_exchange_observer_code` mit Observer-Claim-Form `is_observer` +
  `observer_praesidium_id` — bewusst KEIN `praesidium_id`, dadurch verweigern
  alle bestehenden RLS-Policies Roh-Zugriff; `security definer`-Aggregat-RPC
  `argus_lage`; `lage_view`-Log je Login; per REST-Positiv-/Negativtests
  belegt, Plan 01) + separate Beobachter-Seite `docs/lage-<suffix>.html`
  (Name nur in untracked LAGE-URL.md, D-06 analog; Login per Beobachter-Code,
  20-s-Polling, Kategorie-Kacheln in Triage-Farben, Summenzeile,
  Offline-Zustand) + Beobachter-Code-Ausgabe im Zugänge-Bereich der
  Leitungs-Seite (nur Code, keine URL) + interne Datenschutz-Doku
  nachgezogen (Plan 02). Stufe b bleibt DSB-gated (Phase 8).
  Vorphase 4.11 (Self-Hosting T7): Akzeptanz „zweite Instanz" ersatzweise
  belegt, echte Zweitinstanz-Erprobung deferred; M1: Polizei BW hostet selbst.
  **Nachschliff 2026-06-12 (Owner-Feedback):** Lage-Seite 1:1 ans Mockup
  (UI-AUSBLICK) angeglichen; Leitungs-Seite: Karten/Blöcke einklappbar,
  Filter/Sortierung für Zugänge; **Migration 0006 Token-Hygiene** (Code-Art
  „24 h" abgeschafft + Altbestand gelöscht; verbrauchte Einmal-Codes werden
  6 Monate nach Einlösung automatisch gelöscht — Löschkonzept ergänzt);
  SELF-HOSTING.md um 0005/0006 nachgeführt.
  **Migration 0007 (2026-06-12): jti-Claim + Sofort-Sperrung** — jedes JWT
  trägt den ausstellenden short_code als jti; argus_praesidium_id/is_master/
  is_observer gaten auf argus_token_active() → Code-Sperrung wirkt SOFORT
  serverseitig für alle Policies/RPCs (vorher: erst Re-Check/JWT-Ablauf,
  bis 30 Tage). Alt-JWTs ohne jti: Übergangsgnade bis exp. Leitungs-Seite:
  Zuteilungs-Abfrage bei Einmal-/Beobachter-Code-Ausgabe (Label), Hinweise
  aktualisiert. REST-belegt (Legacy ok, Sperrung/Entsperrung sofort, auch
  argus_lage). Kein App-Release (index.html unangetastet).
  Intern erstellt (gitignored): DSB-Schreiben Dok. 09 (Fassung 2, M1) +
  Sprechzettel Dok. 10 + docs/KONZEPT-POLIZEIBETRIEB.md (Stufenmodell
  MDM/SSO/USBNK, Fragenkatalog PTLS/BITBW) — DSB-Gespräch ist terminiert
  (KW nach 2026-06-12).
  **Feldtest-Feedback 2026-06-13 (30 Punkte, triagiert) — Paket 1
  umgesetzt (v0.25.0 / SW v44):** (1a) serverseitige Nummernvergabe
  (Migration 0008: ccps.next_num + argus_claim_nums, selbstheilend;
  App: claimNum mit persistiertem Offline-Fallback ccp_lastnum_<id> —
  Duplikat-Bug nach Verlassen/Wiederbetreten behoben); (1b) Realtime-
  Selbstheilung healRealtime() bei visibilitychange+online (toter
  iOS-WebSocket blockierte Neuaufbau → „lokaler Modus bis CCP-Wechsel");
  (1c) Training: joinccp im Training gesperrt (Lektion 3 zerschoss
  Intro), Kontext-Wächter ctx/ctxBack (Lektion 12 → zurück auf 11).
  **Owner-Entscheide:** Adressat Lage = FLZ; „CCP-Verbund abschließen"
  als Wording; Gast-Code (Mehrfach, 24 h, expires_at) geplant Paket 2;
  FLZ-operativ-Rolle konzipiert (nach DSB-Votum); Kennung+Nummer (A-12)
  überall (Paket 2); Übung/Einsatz-Frage entfällt via schulung-Flag je
  Präsidium (Paket 2); Export-Verlagerung ins Governance-Panel nur mit
  „nicht exportiert"-Badge. Paket 2/3 offen (siehe Chat 2026-06-13).
  **Nachtrag: v0.25.1 Westenfarben (Hilfestellung); Paket 2 umgesetzt
  (v0.26.0 / SW v46, Migration 0009):** Gast-Code (24 h Mehrfach, echtes
  expires_at über jti-Prüfung, gast_join-Log), schulung-Flag je Präsidium
  (Übung/Einsatz-Frage entfällt, Schulungs-Banner), A-12-Nummern überall,
  TQ-Dialog (tq_site + rückwirkender Zeitpunkt), „CCP/CCP-Verbund
  abschließen", Export-Schritt der Feld-App entfällt → Übergabe-Export über
  Leitungs-Seite (argus_mark_export, protokoll_export-Log, „noch nicht
  exportiert"-Badge), Eröffnung mit Ort+GPS (geo_lat/lng), Lageansicht mit
  VERBUND-Chip + Koordinaten-Kopier-Klick, Sortier-Toggle, Checklisten-
  Autofill. UPDATE-Sheet v0.26.
  **Feedback-Runde 3 (v0.27.0 / SW v48, 2026-06-13):** tacSTART als
  STANDARD (Primärknopf, Direkt = gekennzeichnete Ausnahme), <C>-Vorschalt-
  Schritt aus tacSTART entfernt (FLOW.start weg, Einstieg „gehfähig?"),
  Foto-Schnellaktion im cap-last (capphoto, gleiche Pipeline), Einsatzort
  beidseitig synchron (applyMeta/_ccpOrt → Checklisten-hdr nur wenn leer;
  hdr-Edit → ccps.ort), Lage: Verbünde OPTISCH gruppiert (vgroup-Rahmen,
  „VERBUND n — CCP A + CCP E", Gesamtzahl); Drehbuch-Lektionen angepasst;
  UPDATE-Sheet v0.27.
  **Review-Runde 4 (v0.27.1 / SW v49, 2026-06-13):** Direktzuordnung hinter
  Aufklapper „Direkt kategorisieren (Ausnahme)" (capDirect, Lektion mit
  dynamischem sel/doit), Sofort-Optionen als POP-UP nach jeder Erfassung
  (capPopup; Option/„Nächster Patient" schließt; Block unten bleibt; im
  Training kein Pop-up), .modalbx scrollbar (max-height 86vh — WhatsNew-Fix),
  Lage: Verbund als EINE kompakte Summen-Karte (verbundCard) mit Standort-
  Zeile je Mitglied, „Einladungslink teilen" + buildShareLink/copyInviteLink
  entfernt (redundant zu Leitungs-Ausgabe/Gast-Code).
  **Paket 3 (baubarer Teil) code-komplett (Phase 4.13, v0.28.0 — Push
  ausstehend):** Schulungs-Provisionierung je PP + Reset über Tombstones +
  AT-MIST-Druck in der Leitung; extern blockiert bleiben FLZ-operativ
  (DSB-Votum) und GeoJSON-Endpunkt (PTLS-Antwort).
  **Datenschutz: technisch vollständig, offen ist nur Organisatorisches
  (+ T4 nach DSB-Votum; k-Schwelle Lageansicht = DSB-Frage).**
  Nächster realer Schritt: **DSB-Gespräch** (Briefing aktualisiert, intern)
  → bestimmt Phase 5/6/7.

- **Deploy:** GitHub Pages · Repo `KrapfenBediener/argus` · Branch `main`
- **Backend:** Supabase EU (`sehuosjyjmrpzcqrelej`) · Free Tier

---

## Phase 5 — Identitäten & Audit-Protokoll Stufe 1 (in Arbeit 2026-06-27)

**Plan 05-01 ✅ (2026-06-27):** Migration 0015 — Stufe-1-Identitäts-Schicht serverseitig
komplett. is_person/usbnk/role auf access_tokens, schulungs_zwilling_id auf praesidien,
Claim-Helfer argus_is_flz/argus_usbnk/argus_argus_role (jti-gated), CR-02-Guard is_person
in argus_exchange_code, audit_log append-only (RLS argus_is_master, kein anon-Write-Grant),
argus_exchange_person_code (usbnk+role-Claims, kein Klarname D-02, 30-Tage-exp D-11,
person_login-Log, CR-02-Spiegel), argus_master_issue_person (alle Flags explizit, kein
expires_at, person_issue-Log mit actor-USBNK, Master darf weitere Master ausgeben D-13),
argus_master_revoke_person (revoked+jti-Sofortsperre, person_revoke-Log),
argus_master_search_usbnk (ohne token-Spalte), argus_lage FLZ-Zweig (präsidienübergreifend
D-12). 0015 zweimal live angewendet (beide HTTP 201, idempotent). Vollständige
21+Positiv-/Negativ-/jti-Testbatterie bestanden; alle Privilege-Escalation-Vektoren verweigert.
SELF-HOSTING.md nachgeführt (0015 in Dateiliste/Reihenfolge + Audit-Prosa + Stufe-1-Bootstrap).
D-02 + D-06 durchgängig gewahrt. Commits a0b50a8 (Tasks 1+2), 1593fbb (Task 3).
SUMMARY: `.planning/phases/05-identitaeten-audit-stufe1/05-01-SUMMARY.md`.
Offener Owner-Punkt: ephemeren PAT widerrufen (Supabase Dashboard → Account → Access Tokens).

**Plan 05-02 ✅ (2026-06-27):** Migration 0016 — argus_run_purge() um Schritt (e) audit_log-Retention (365 Tage, bigint-ms-Cutoff) erweitert. 0016 zweimal live angewendet (beide HTTP 201, idempotent). Retention-Funktionstest: Alt-Row (>366 Tage) gelöscht, Frisch-Row blieb, bestehende Schritte a–d intakt, Return-JSON additiv um audit_log_retention-Schlüssel. Kein zweiter Cron-Job (argus_purge greift automatisch). SELF-HOSTING.md nachgeführt (0016 Dateiliste/Reihenfolge/Prosa). D-06 gewahrt. Commits e92bfbe (Task 1), 904fa37 (Task 2).
SUMMARY: `.planning/phases/05-identitaeten-audit-stufe1/05-02-SUMMARY.md`.
Offener Owner-Punkt: ephemeren PAT widerrufen (Supabase Dashboard → Account → Access Tokens), sofern nach Plan 05-01 noch nicht erledigt.

**Plan 05-03 ✅ (2026-06-27):** Leitungs-Seite — zwei entsperrte Master-Sektionen „Identitäten“ (Einzel-Ausgabe Pro-Person-Token via argus_master_issue_person, USBNK-Suche via argus_master_search_usbnk ohne Token-Secret, Rollenwechsel = revoke+issue, Sperre via argus_master_revoke_person/jti-Sofortsperre) + „Audit-Log“ (T4-Anzeige cl.from('audit_log') mit USBNK-Spalte/Filter, deutsche Aktions-Labels); Phase-7-Sperrzone entfernt. Gap-Fix (vom Orchestrator gefunden): doLogin um dritten Versuch argus_exchange_person_code + Rollen-Mapping (master/admin/flz-normal) erweitert — macht Leitungs-Seiten-Sessions personenscharf (D-08); flz/normal → graceful secNoView() statt kaputter Master-Ansicht. Browser-Roundtrip gegen Live-Backend bestanden (person_login/issue/revoke alle mit Actor-USBNK; keine Token-Secrets; noview-Pfad ok; Testdaten bereinigt). Nur In-App-Modals; D-02/D-06 gewahrt; index.html/sw.js unverändert (kein App-Release). Commits d163ae6 (Sektionen), 598e208 (Person-Login), 7670c52 (SUMMARY).
SUMMARY: `.planning/phases/05-identitaeten-audit-stufe1/05-03-SUMMARY.md`.

**Phase 05 abgeschlossen** (3/3 Pläne): serverseitige Identitäts-/Audit-Schicht (Stufe 1) + Audit-Retention + Leitungs-Seiten-Bedienung end-to-end personenscharf.

---

## Phase 5.1 — Feld-App: Pro-Person-Login & Echt/Schulung-Picker (in Arbeit 2026-06-27)

**Plan 05.1-01 ✅ (2026-06-27):** Migration 0018 — Feld-Audit-Trigger (patients/ccps → audit_log via argus_usbnk()) + 'normal'-Entsperrung. Zwei security-definer AFTER-Trigger-Funktionen (argus_audit_patients_aiu, argus_audit_ccps_aiu) leiten die 8 D-06-Lebenszyklus-Aktionen aus NEW/OLD-Spaltendiff ab (photo > checkout > ready > cat_change; ccp_close > ccp_merge); schreiben genau 1 Eintrag pro DML; reine Vitalwert-Updates = kein Eintrag (D-06). argus_usbnk() liest USBNK aus dem signierten JWT — Client kann nicht fälschen; usbnk=null bei Stufe-0-Sessions wird trotzdem protokolliert (§73-Vollständigkeit). praesidium_id für patients über ccps JOIN aufgelöst. argus_master_issue_person + argus_master_role_change_person byte-nah zu 0017 neu erstellt, nur Whitelist + Fehlertext geändert: 'normal' wieder enthalten (5.1-Freigabe). 0018 zweimal live angewendet (beide HTTP 201, idempotent). Alle 8 Trigger-Aktionen live verifiziert; vital-only → 0 Einträge bestätigt; CR-02 intakt; append-only (anon INSERT → HTTP 401); Testdaten bereinigt. SELF-HOSTING.md nachgeführt (0018 Dateiliste/Reihenfolge/Prosa). Kein App-Release (index.html/sw.js unverändert). Commits 68d2a80 (Tasks 1+2), 1b0f7c0 (SUMMARY).
SUMMARY: `.planning/phases/05.1-feldapp-login-picker/05.1-01-SUMMARY.md`.
Offener Owner-Punkt: ephemeren PAT widerrufen (Supabase Dashboard → Account → Access Tokens).

**Plan 05.1-02 ✅ (2026-06-27):** Leitungs-Seite — 'normal'-Rolle im Ausgabe-Dropdown + Präsidiums-Pflicht + Rollenwechsel-Annahme. pers-rolle-Select um `<option value="normal">Normal</option>` erweitert (nach Admin; FLZ bleibt Default). doMkPerson(): Präsidiums-Pflicht auf admin||normal ausgeweitet (Toast: „Für diese Rolle ist ein Präsidium erforderlich."); pers-praes-wrap-Sichtbarkeits-Listener auf admin||normal erweitert; Label „Präsidium (für Admin-/Normal-Rolle)" angepasst. doPersonRole(): Prompt-Text auf master/flz/admin/normal; Whitelist um 'normal' ergänzt; kein clientseitiges Abweisen. rolleLabel('normal')='Normal'/rolleColor bereits aus Phase 5 vorhanden — kein Tweak. Hinweistext: „Einzel-Ausgabe (Master/FLZ/Admin/Normal) — pro Präsidium, geringe Menge. Massen-Provisionierung normaler Nutzer bleibt SSO-gated (D-10)." D-06-Gate: 0 Treffer. Nur In-App-Modals; D-02/D-06 gewahrt; index.html/sw.js unverändert (kein App-Release). Commits 099b5bf (Tasks 1), 2bbaaf4 (Task 2).
SUMMARY: `.planning/phases/05.1-feldapp-login-picker/05.1-02-SUMMARY.md`.

**Plan 05.1-03 ✅ (2026-06-28):** Feld-App (index.html) — Pro-Person-Login + Echt/Schulung-Picker + twin-scope Re-Exchange. (1) Ein-Feld-Auto-Erkennung: `exchangeCode()` zuerst (CR-02 weist Person-Codes ab), `exchangePersonCode()`-Fallback NUR bei Nicht-„gesperrt"-Fehler (Muster der Leitungs-Seiten-doLogin). USBNK-Sitzung lokal persistiert (neue Keys `argus_usbnk`/`argus_role`/`argus_person_praesidium`, Globale `_usbnk`/`_argusRole`); `applyRevokedLock()` räumt sie; `refreshJwtIfNeeded()` verlängert Person-Sitzungen scope-bewusst über `exchangePersonCode()`. master/flz-Person-Token (`praesidium_id=null`) im Feld höflich abgewiesen („für die Leitungs-Seite"), kein `_isMaster` aus Person-Token (T-053-04). (2) Zwei-Reiter Echt/Schulung (`argus_picker_mode`, Default Echt), `pickerList()` löst je Sitzungstyp auf (Person: Echt=eigenes Präsidium, Schulung=`schulungs_zwilling_id`-Twin; Sammel/Master=heutiges Modell), verstärkter vollbreiter permanenter SCHULUNG-Banner (#F2B600), bewusste `confirmModal`-Bestätigung beim Echt↔Schulung-Wechsel (kein Mischen, T-053-02). **Gap-Closure (Browser-Checkpoint, Rule 2):** Person-JWT trug nur Echt-`praesidium_id` → Twin im Picker sichtbar aber RLS-denied (live: Twin-CCPs=0). Owner-Entscheid = RE-EXCHANGE → **Migration 0019 (LIVE)**: `argus_exchange_person_code(code, p_scope default 'echt')` löst bei `p_scope='schulung'` die `schulungs_zwilling_id` server-seitig auf und stellt ein twin-scoped JWT aus (`praesidium_id`=Twin; `usbnk`/`role`/`jti` unverändert; kein Twin→Fehler); Feld-App re-exchanged beim bewussten Wechsel (offline-guarded); stilles Refresh behält den aktiven Scope. **RLS UNVERÄNDERT.** Live+Browser+REST verifiziert: Sammelcode-Koexistenz intakt; Person-Login → Toast „Angemeldet als USBNK <usbnk>" (kein Klarname, D-02); Person-JWT-Patienteninsert → `audit_log{usbnk, patient_create}` (Wave-1-Trigger); nach Schulungs-Wechsel JWT-`praesidium_id`=Twin, Twin-CCPs lesbar (5, war 0); Backward-Compat + master-person + no-twin-Fehler ok; Testdaten bereinigt. CR-02/Offline/tacSTART unberührt; kein Version-/SW-Bump (Plan 04). Commits 5181735 (Task 1), 09e1f58 (Task 2), 584e606 (Gap-Closure/Migration 0019), 5b002b9 (SUMMARY).
SUMMARY: `.planning/phases/05.1-feldapp-login-picker/05.1-03-SUMMARY.md`.

---

## Phase-Abschlüsse

| Phase | Name | Abgeschlossen |
|---|---|---|
| 0 | Repo-Struktur & Offline-Hülle | ✅ |
| 1 | Supabase-Backend & Speicherschicht | ✅ |
| 2 | Join-Flow & Authentifizierung | ✅ |
| 3 | Mehrgeräte-Features verdrahten | ✅ 2026-06-03 |
| 4 | Serverseitige Absicherung (JWT + RLS) | ✅ 2026-06-03 |
| 4.8 | Datenschutz-Härtung (T8, T2, T1, T3) | ✅ 2026-06-10 |
| 4.9 | Governance-Oberfläche (Einsatzprotokoll-Modell, Leitungs-Seite, Code-Sperre) | ✅ 2026-06-11 |
| 4.10 | Datenschutz-Schlusspaket (Log-Frist 12 Monate, T5 Transparenz, T6 Backup-Hygiene, Doku-Sync) | ✅ 2026-06-11 |
| 4.11 | Self-Hosting-Fähigkeit (T7: config.js, Kompatibilitäts-Audit, SELF-HOSTING.md) | ✅ 2026-06-11 |
| 4.12 | FLZ-Lageansicht Stufe a (Migration 0005, Beobachter-Seite, Code-Ausgabe Leitung) | ✅ 2026-06-12 |

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

### Härtungsfenster nach Phase 4.5 (2026-06-05 … 06-08) — v0.16 → v0.19.5

Iterative Feature-/Schulungsarbeit im Test-/Härtungsfenster (keine geplante Phase;
Phase 5 bleibt aufgeschoben):

- **AT-MIST-Übergabekarte (v0.17.0):** Beim Auschecken (→ gPA) erscheint eine
  gesperrte Vorlese-Karte (Kopf + A/T/M/I/S/T) für die strukturierte Übergabe an die
  gPA. Bewusste Abgrenzung: ARGUS bleibt Polizei/CCP-fokussiert, Schnittstelle =
  Übergabe (IVENA eHealth recherchiert, Integration verworfen).

- **Geführtes interaktives Training (v0.18.0 → v0.19.5):** kompletter geführter
  36-Lektionen-Durchlauf durch die App, erreichbar über die Schulungsumgebung.

  - Geräte-LOKALER Sandbox: Übungsdaten (`training:true`) werden NIE synchronisiert;
    eigener lokaler Ephemer-CCP (`train-ccp`) → kein Cloud-Leck, **kein manuelles
    Zurücksetzen** der Schulungsumgebung nötig, beliebig oft wiederholbar.

  - 3-Modus-Modell (explain / do / choice), Spotlight mit Verdeckungs-Erkennung,
    Scroll auf sticky-Topbar + Panelhöhe abgestimmt, design-konform (Schiefer statt Lila).

  - Erst-Intro (Onboarding) verweist am Ende auf das Training (5. Slide).
  - **DAUERREGEL:** bei jeder UI-/Funktionsänderung das Trainings-Drehbuch
    (`TRAIN_LESSONS`) mit-anpassen.

- **Produkt-Website** im ARGUS-Design — unauffindbar + `noindex` auf GitHub Pages
  deployt (Demo). Referenz-Optik: `docs/UI-AUSBLICK.html`.

- **IP-/Doc-Hygiene:** interne Planungs-/Compliance-Docs und experimentelle Decks aus
  dem öffentlichen Repo entöffentlicht (`.gitignore`); `UPDATE_*.html` bleiben öffentlich
  (aus der App verlinkt). Royal-Stil-Logos verworfen. Marken-/Domain-Schritte bis nach
  DSB / Pol-BW zurückgestellt.

- **Design-Sprache fixiert:** `docs/UI-AUSBLICK.html` = verbindliche Optik (IBM Plex,
  hell, Schiefer `#1f2530` als Chrome, Triage-Farben nur funktional). Kein Apple-/Royal-Stil.

*Testing weiterhin ohne `node` — Logikprüfung via JavaScriptCore (`osascript -l JavaScript`),
kein Browser verfügbar.*

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

## Phase 4.8 — Datenschutz-Härtung (ABGESCHLOSSEN 2026-06-10, v0.22.0)

**Planung abgeschlossen:** 6 Pläne in 5 Wellen (`.planning/phases/04.8-datenschutz-haertung/`),
Plan-Checker-Durchlauf bestanden (1 MAJOR + 4 MINOR gefunden und eingearbeitet, Commit 54baaf2).
Einziger nicht-autonomer Punkt: Plan 04.8-02 braucht einen ephemeren Supabase-PAT (Checkpoint).

**Ausführungsstand (Welle 1):**

- **04.8-02 ✅ (2026-06-10):** Migration `0002_phase48_datenschutz.sql` geschrieben,
  live angewendet (Management API, idempotent) und verifiziert — Einsatz-Lebenszyklus-
  Spalten, `purge_log`/`governance_log`, 5 `argus_*`-RPCs, RLS-Split (abgeschlossener
  Einsatz für Nicht-Master schreibgesperrt, per REST nicht umkehrbar), pg_cron-Job
  `argus_purge` (stündlich, läuft — Free Tier hat pg_cron). Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-02-SUMMARY.md`. Commit 8fcb675.
  **Noch zu pushen** (Executor-Umgebung ohne GitHub-Credentials).

- **PAT widerrufen:** der für 04.8-02 genutzte ephemere PAT ist noch aktiv →
  im Supabase-Dashboard widerrufen (zusammen mit dem offenen Alt-PAT aus Phase 4).

**Ausführungsstand (Welle 2):**

- **04.8-03 ✅ (2026-06-10, v0.20.0):** T2 in der App nutzbar — „Einsatz
  abschließen" (MasterMedic, Typ Übung 14 / Einsatz 30 Tage, Frist 1–365
  anpassbar), Übergabe-Export (JSON via iOS-Teilen/Download + druckbare
  AT-MIST-Gesamtansicht; Name nur wenn erfasst, **nie** Fotos), lokale
  Bereinigung auf allen Geräten (Realtime-Pfad in `applyMeta`, init,
  online-Handler), Offline-Queue `argus_pending_close` + `flushPendingClose`,
  opportunistischer `argus_run_purge`. Legacy „CCP abschließen" (Home) führt
  jetzt in den neuen Workflow (Abweichung, dokumentiert). Drehbuch + Release
  v0.20.0 (SW v37, UPDATE_v0.20.html). JSC-Tests 23/23 PASS. Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-03-SUMMARY.md`.
  Commits 5a7b03c · 0454595 · 378ccab. **Gepusht** (c291e6f..9d5a362, Credentials
  waren wieder gültig) — GitHub Pages deployt v0.20.0; damit ist auch der noch
  offene 04.8-02-Stand (8fcb675) mit hochgegangen.

**Ausführungsstand (Welle 3):**

- **04.8-04 ✅ (2026-06-10, v0.21.0):** T1 App-Teil 1 — einsatzweiter Schalter
  „Fotos erlauben" (Default AUS, nur MasterMedic/Eröffner, synct über
  `ccps.photos_allowed` via Realtime/`loadMeta`; im Verbund Update aller Rows
  der merge_group), Kamera-Gating in `vPatient` (Aufnahme-Elemente nur bei
  Schalter an, bestehende Fotos bleiben sichtbar, defensiver Upload-Abbruch),
  Zweck-Hinweis (Wiedererkennung statt Name, 72 Std, automatische Löschung).
  Foto ab Auscheckung (gPA) komplett aus der Normalansicht (zentrale
  Render-Bedingung `photoVisible(p)` für Listen-Pill/Detail/Zoom); „Zurückholen"
  reaktiviert ohne Neufoto, `p.photo` bleibt unangetastet (Governance-Fenster
  04.8-05 bleibt möglich). Training: Foto-Lektion angepasst + Schalter-Lektion
  neu; `_photosAllowed` im Trainings-Sandbox lokal an (train-ccp synct nie).
  Release v0.21.0 (SW v38, UPDATE_v0.21.html). JSC: Syntax OK, photoVisible
  7/7 PASS. Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-04-SUMMARY.md`.
  Commits 121d6db · 0ef87ef · f716d65. **Gepusht** (14d91bc..f716d65) —
  GitHub Pages deployt v0.21.0.

**Ausführungsstand (Welle 4):**

- **04.8-05 ✅ (2026-06-10, v0.21.1):** T1 App-Teil 2 — Foto-Governance-Panel
  (View `governance`, Einstieg in der Administration, nur `_isMaster` =
  MasterUser-Token, getrennt vom MasterMedic): Liste via
  `argus_governance_list` (gruppiert nach CCP, Status abgeschlossen/offen,
  Frist de-DE, **ohne** Bilddaten); Foto-Einzelabruf via
  `argus_governance_photo` (Kürzel-Pflicht, Overlay mit Protokoll-Hinweis —
  jeder Abruf = serverseitiger `governance_log`-Eintrag); Fristverlängerung
  `argus_extend_photo_frist` (+72 h, Pflicht-Begründung mit Leer-Abweisung,
  confirmModal mit Export-Hinweis „zuständige Stelle"); Wiedervorlage-Block
  (Frist abgelaufen / < 24 h, `fristStatus` JSC-getestet 10/10); einklappbare
  Protokoll-Ansicht (letzte 100 `governance_log`-Einträge). Verlängern-Knopf
  nur bei gesetzter Frist (sonst würde der RPC bei offenem Einsatz eine
  Löschfrist ERZEUGEN — dokumentierte Abweichung). Panel nur online (kein
  Einsatz-Werkzeug, Local-first unberührt). Drehbuch geprüft: keine
  Lektionsänderung (reine MasterUser-Funktion). Release v0.21.1 (SW v39,
  kein eigenes Update-Sheet — v0.21-Sheet deckt die Foto-Härtung ab). Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-05-SUMMARY.md`.
  Commits 2e82f03 · a68fc4e · 5b284ff.

**Ausführungsstand (Welle 5 — Phasenabschluss):**

- **04.8-06 ✅ (2026-06-10, v0.22.0):** T3 Namensfeld-Härtung — Hinweis am
  Namensfeld („Nur erfassen, wenn für Versorgung/Übergabe erforderlich."),
  Patientenliste ohne Namens-Spalte (einziger Renderer `vCatlist`, gilt für
  Kategorie/Alle/Prio/gPA — Nummer + Pills identifizieren, Sichtungszeit/TQ als
  Hauptzeile), keine Namens-Suche/-Sortierung/-Filterung (Grep-Beleg + Kommentar
  an der Sortier-Stelle), Freitext-Hinweis „Keine Namen Dritter — nur
  versorgungsrelevante Fakten." („Verlauf / Karte"), Übergabekarte/Export
  unangetastet (Name im Übergabe-Kontext weiterhin, wenn erfasst). Drehbuch:
  neue Lektion „Stammdaten: pseudonym" (Spotlight `#ph-stamm`). Einsatz-Schalter
  fürs Namensfeld bewusst NICHT gebaut (zurückgestellt bis DSB-Votum). Release
  v0.22.0 (SW v40, kein eigenes Update-Sheet — WHATS_NEW genügt). Interne
  Statusführung synchron gezogen (SPEC-Akzeptanzkriterien, Maßnahmenplan —
  lokal, gitignored). Details:
  `.planning/phases/04.8-datenschutz-haertung/04.8-06-SUMMARY.md`.

**→ Phase 4.8 abgeschlossen.** Bewusst offen: Namensfeld-Einsatz-Schalter
(nach DSB-Votum), T4 Audit-Log (gesperrt bis DSB-Votum „JI-Regime"),
Live-Verifikationen am echten Gerät (Governance-Panel, 72-h-Foto-Lauf).

DSB-unabhängige P1-Tasks aus `docs/datenschutz/DATENSCHUTZ-SPEC.md` (erstellt
2026-06-10, Dossier 00–08): T2 Einsatz abschließen + Auto-Löschung (Fundament),
T1 Foto-Härtung + Governance-Panel, T3 Namensfeld-Härtung, T8 externe
Laufzeit-Abhängigkeiten entfernen. T4 (Audit-Log) bleibt bis DSB-Votum gesperrt.
Danach: Phase 5 — Produktionsinfrastruktur (Pro-Tier, separates Prod-Projekt,
Repo-Schnitt, Backup-/Löschkonzept). Siehe `.planning/ROADMAP.md`.

*Hinweis 2026-06-10: `docs/datenschutz/` und weitere interne Unterlagen sind
gitignored — Repo ist public.*

---

## Phase 4.9 — Governance-Oberfläche (ABGESCHLOSSEN 2026-06-11, v0.23.0)

**Planung:** 4 Pläne in 3 Wellen (geplant 2026-06-10, Checker bestanden,
Commit 9b804bd). Kern: Einsatzprotokoll-Modell (Owner-Entscheid 2026-06-10) —
einheitliche 72-h-Grundfrist, Fotos hart ohne Verlängerung, jeder
Protokoll-Abruf protokolliert, separate Desktop-Leitungs-Oberfläche,
Code-Sperre (`revoked`), Governance-Rückbau in der Feld-App.

**Ausführungsstand (Welle 1):**

- **04.9-01 ✅ (2026-06-11):** Migration `0003_phase49_einsatzprotokoll.sql`
  geschrieben, live angewendet (Management API, 2× = Idempotenz-Beleg) und
  verifiziert — Einsatzprotokoll-Modell serverseitig komplett:
  `access_tokens.revoked` + Prüfung in `argus_exchange_code` („Code wurde
  gesperrt"); neuer Re-Check-RPC `argus_check_code` (`{found, revoked}`, ohne
  Seiteneffekte); `argus_close_einsatz` setzt einheitlich 72-h-Fristen
  (`p_frist_tage` wird ignoriert — signaturkompatibel zu v0.22.0); neue RPCs
  `argus_governance_einsaetze` (Liste, Filter = Purge-Bedingung (b)) und
  `argus_governance_protokoll` (Zwangs-Log `protokoll_view` VOR Rückgabe,
  Patienten ohne Foto-Daten, nur `has_photo`); `argus_extend_protokoll_frist`
  verlängert NUR `purge_after` (Fotos hart, 72 h); `argus_governance_list` und
  `argus_extend_photo_frist` ENTFERNT; RLS: patients/checklists geschlossener
  Einsätze für Nicht-Master nicht mehr lesbar, ccps-Tombstone bleibt lesbar.
  Funktions- und REST-Negativtests grün, Seed-Daten restlos entfernt. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-01-SUMMARY.md`.
  Commit e4a7909.

- **Bekannte Übergangs-Abweichung (akzeptiert):** v0.22.0-Altgeräte zeigen beim
  Abschluss noch „14/30 Tage", der Server löscht ab jetzt nach **72 h** — Daten
  werden FRÜHER gelöscht als angezeigt. Gilt bis v0.23.0 (Plan 04.9-03);
  das alte Feld-App-Governance-Panel zeigt auf Master-Geräten bis dahin einen
  Fehlertext (argus_governance_list entfernt).

- **PAT widerrufen:** der für 04.9-01 genutzte ephemere PAT ist noch aktiv →
  im Supabase-Dashboard widerrufen (zusammen mit ggf. offenen Alt-PATs).

**Ausführungsstand (Welle 2):**

- **04.9-02 ✅ (2026-06-11):** Leitungs-Oberfläche (Desktop-Governance-Seite)
  gebaut — Single-File unter nicht erratbarem Dateinamen (D-06: Name steht
  AUSSCHLIESSLICH in der untracked, gitignorten `LEITUNG-URL.md`; in keiner
  committeten Datei, keinem Commit-Text — git-grep-Gate grün). MasterToken-Login
  via `argus_exchange_code` mit is_master-Pflicht (Abweisung ohne Speicherung),
  Sitzung flüchtig in sessionStorage (`argusl_jwt`/`argusl_jwt_exp`/
  `argusl_kuerzel`); Direkteinstieg „Zugänge" (D-10), Phase-7-Sektion sichtbar
  gesperrt (D-09). Zugänge: Codes je Präsidium Dauerhaft/24 h/Einmalig +
  Code-Sperre über `revoked` (MasterToken-Zeilen nicht sperrbar, D-11);
  Einsatzprotokolle: Wiedervorlage oben, protokollierter Abruf
  (`argus_governance_protokoll`, Hinweis-Modal + Kürzel-Pflicht, D-01),
  Foto-Lazy-Load, harte Foto-Frist ohne Verlängerungs-UI (D-02),
  Protokoll-Frist +72 h nur mit Pflicht-Begründung (D-03); Protokoll:
  governance_log (200) + purge_log (100, inhaltsfrei, D-13). JSC: Syntax OK,
  fristStatus 10/10, genShortCode/genToken PASS; Smoke-Test (http.server) alle
  Assets 200. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-02-SUMMARY.md`.
  Commits 0f7c61e · 4933231 · 4ed858e. **Noch nicht gepusht** — Seite wird mit
  dem nächsten Deploy via GitHub Pages erreichbar.

- **Offener Owner-Punkt (04.9-02):** Live-Verifikation der Leitungs-Seite im
  Browser (URL siehe lokale `LEITUNG-URL.md`): MasterToken-Login, Code-Sperre-
  Roundtrip, Protokoll-Abruf inkl. governance_log-Eintrag. `LEITUNG-URL.md`
  lokal sichern — sie ist die einzige Fundstelle des Dateinamens.

- **04.9-03 ✅ (2026-06-11, v0.23.0):** Feld-App auf das Einsatzprotokoll-Modell
  umgestellt — Governance-Insel restlos entfernt (View, Einstieg, 4 Handler,
  Zustandsvariablen, `fristStatus`/`govFmt`; D-14 „keine Foto-Insel in der App",
  Leitungs-Funktionen nur noch auf der separaten Leitungs-Oberfläche);
  Abschluss-Workflow auf feste 72-h-Grundfrist (14/30-Wahl + freie Frist-Eingabe
  entfernt, Typ Übung/Einsatz bleibt Merkmal; `argus_close_einsatz` ohne
  Frist-Parameter; Offline-Queue-Payload `{ccpId,typ,ts}`, v0.22.0-Legacy-Einträge
  mit fristTage bleiben gültig); Übergabe-Export im Workflow prominent als
  EINZIGER dauerhafter Weg ausgewiesen (D-04); revoked-Re-Check
  (`checkRevokedCode`/`revokedDecision`, fire-and-forget bei Start + online-Event,
  offline-Guard VOR dem fetch, 6-s-Abort-Timeout — Sperrung NUR bei eindeutigem
  `revoked===true`, found:false/Fehler → ignore; `applyRevokedLock` räumt
  JWT/Code/Freischaltungen/Rollen, kappt Realtime, Hinweis-Modal, Freischalt-Screen;
  Sperr-Klartext „Code wurde gesperrt" erscheint auch beim Freischalten/Re-Exchange);
  Drehbuch auf 72-h-Modell (keine 14/30-Texte mehr). Release v0.23.0 (SW v41,
  CHANGELOG, WHATS_NEW, UPDATE_v0.23.html inkl. „Bitte App aktualisieren"-Hinweis
  wegen v0.22.0-Fristen-Anzeige). JSC: 17+25 Checks PASS, Syntax beider
  Inline-Blöcke OK. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-03-SUMMARY.md`.
  Commits 18cbff6 · 71bc5e7 · 7834610. **Noch nicht gepusht** (Plan: nicht pushen);
  „App live" bleibt v0.22.0 bis zum Deploy.

- **Offener Owner-Punkt (04.9-03):** Live-Verifikation am echten iPhone —
  Update-Banner v0.23.0, Abschluss-Strecke (72-h-Texte), Sperr-Test
  (Code sperren → Gerät meldet sich beim Start/Reconnect ab).

**Ausführungsstand (Welle 3 — Phasenabschluss):**

- **04.9-04 ✅ (2026-06-11):** Doku/Statusführung (D-05) — interne
  Datenschutz-Dokumente (`05-LOESCHKONZEPT.md`, `DATENSCHUTZ-SPEC.md`,
  `08-MASSNAHMENPLAN.md`; alle gitignored, NUR lokal editiert, nicht
  committet) auf das Einsatzprotokoll-Modell nachgezogen: einheitliche
  72-h-Grundfrist statt 14/30 Tage (alte Fristen als „überholt" markiert),
  Fotos 72 h hart ohne Verlängerung, neuer Abschnitt „Einsatzprotokoll-Modell
  (Owner-Entscheid 2026-06-10)" im Löschkonzept, Abschnitt 2a auf
  Protokoll-Frist (`purge_after`, RPC `argus_extend_protokoll_frist`)
  umgeschrieben, Abweichungsvermerke an T1/T2 der SPEC (Datum + „Phase 4.9"),
  Maßnahmenplan synchron (Fristen, Governance/Leitungs-Oberfläche,
  Code-Sperre). ROADMAP/STATE finalisiert. Details:
  `.planning/phases/04.9-governance-oberflaeche/04.9-04-SUMMARY.md`.

- **D-06-Phasen-Abschluss-Gate bestanden:** `git grep` über alle getrackten
  Dateien (Muster des Leitungs-Seiten-Dateinamens) → 0 Treffer; der konkrete
  Name steht ausschließlich in der untracked, gitignorten `LEITUNG-URL.md`.

**→ Phase 4.9 abgeschlossen. Offene Owner-Punkte (gesammelt):**

1. **Push/Deploy der Phase-4.9-Commits** (macht der Orchestrator nach dem
   finalen Gate) — erst danach sind Leitungs-Seite und v0.23.0 im Feld.

2. **PAT widerrufen** (aus 04.9-01; Supabase-Dashboard → Account → Access
   Tokens) — zusammen mit ggf. noch offenen Alt-PATs (Phase 4 / 04.8-02).

3. **Browser-Live-Test der Leitungs-Seite** (nach Deploy; URL siehe lokale
   `LEITUNG-URL.md` — lokal sichern, einzige Fundstelle des Dateinamens):
   MasterToken-Login, Code-Sperre-Roundtrip, Protokoll-Abruf inkl.
   governance_log-Eintrag, Frist-Verlängerung.

4. **iPhone-Live-Test v0.23.0** (nach Deploy): Update-Banner, Abschluss-Strecke
   (72-h-Texte, Typ-Wahl ohne Fristen), Sperr-Test (Code über die
   Leitungs-Oberfläche sperren → Gerät meldet sich beim Start/Reconnect ab).

5. **Bekannte, AKZEPTIERTE Übergangs-Abweichung:** Geräte auf v0.22.0 zeigen
   beim Einsatz-Abschluss noch „Löschung nach 14/30 Tagen" an, der Server
   löscht aber bereits nach **72 h** (FRÜHER als angezeigt). Erledigt sich,
   sobald alle Geräte auf v0.23.0 aktualisiert sind — das UPDATE-Sheet
   (UPDATE_v0.23.html) bittet ausdrücklich ums Update.

6. **Beobachtung (aus 04.9-03):** die älteren `docs/UPDATE_*.html`-Sheets
   (v0.17–v0.21) haben KEIN noindex-Meta (das neue v0.23-Sheet hat eines).
   Owner-Entscheid offen: nachrüsten oder bewusst öffentlich lassen (sie sind
   aus der App verlinkt).

---

## Phase 4.10 — Datenschutz-Schlusspaket (ABGESCHLOSSEN 2026-06-11, v0.23.1)

**Planung:** 3 Pläne in 3 Wellen (geplant 2026-06-11, Checker PASS ohne Blocker).

**Ausführungsstand (Welle 1):**

- **04.10-01 ✅ (2026-06-11):** Migration `0004_phase410_log_retention.sql` —
  Log-Löschfrist 12 Monate (D-01, Modell § 73 Abs. 5 PolG BW): `argus_run_purge`
  per create or replace um Schritt (d) erweitert — `governance_log` (bigint-ms,
  Cutoff 365 Tage) und `purge_log` (timestamptz, Zwölf-Monats-Intervall) werden
  im bestehenden stündlichen Purge-Lauf gelöscht; Schritte (a)–(c) byte-gleich
  aus 0002, Cron-Job `argus_purge` wörtlich unverändert; Schritt (d) erzeugt
  selbst KEINEN Log-Eintrag (keine Rekursion, kein Spam). Return-JSON additiv
  um `log_retention` erweitert. Live angewendet (Management API, 2× =
  Idempotenz-Beleg), Funktionstest mit synthetischen Alt-/Jung-Logs (alt
  gelöscht, jung erhalten, kein Rekursions-Eintrag, restlos aufgeräumt),
  REST-Probe mit Anon-Key → HTTP 200 inkl. `log_retention`. Details:
  `.planning/phases/04.10-datenschutz-schlusspaket/04.10-01-SUMMARY.md`.
  Commit 2eb27df.

- **PAT widerrufen (Owner-Punkt):** der für 04.10-01 genutzte ephemere PAT ist
  noch aktiv → im Supabase-Dashboard (Account → Access Tokens) widerrufen —
  zusammen mit ggf. noch offenen Alt-PATs (Phase 4 / 04.8-02 / 04.9-01).

**Ausführungsstand (Welle 2):**

- **04.10-02 ✅ (2026-06-11, v0.23.1):** T5 Transparenz & Betroffenenrechte
  (D-02) — In-App-Datenschutzhinweis als statische, offline verfügbare Ansicht
  „Datenschutz" (View `vDatenschutz()`, Einstieg ghost-Button in den
  Hilfestellungen, titles/Dispatch/back() verdrahtet): sechs Art.-13-Abschnitte
  (Verantwortlicher, Zwecke, Datenarten, Fristen [72 h / Fotos hart /
  Logs 12 Monate — seit 04.10-01 serverseitig wahr], Betroffenenrechte inkl.
  Art.-15-Auskunft über den Einzelpatient-/Einsatz-Export, DSB-Kontakt).
  Verantwortlicher/DSB zentral über die Platzhalter-Konstante `DS_KONTAKT`
  pflegbar (Owner-Punkt: vor Echtbetrieb befüllen). Öffentlich-tauglich:
  Negativ-Greps (§ 82 / Auftragsverarbeitung) = 0, kein Klarname im
  View-Körper. Dazu D-05: noindex-Meta in den fünf Alt-UPDATE-Sheets
  (v0.9–v0.21) nachgerüstet (alle 6 Sheets jetzt noindex) und Fußzeilen-Verweis
  auf der Leitungs-Seite („Datenschutzhinweis: in der ARGUS-App unter
  Hilfestellungen → Datenschutz."). Drehbuch: Hilfestellungen-Lektion nennt
  den Datenschutzhinweis. Release v0.23.1 (SW v42, CHANGELOG, WHATS_NEW;
  KEIN eigenes UPDATE-Sheet — Diskretions-Entscheid „klein"). JSC: Syntax OK
  (index.html-Inline-Block + sw.js). D-06-Gate repo-weit grün (0 Treffer).
  Details:
  `.planning/phases/04.10-datenschutz-schlusspaket/04.10-02-SUMMARY.md`.
  Commits d2aa15e · 18031e1 · b75f289. **Gepusht/deployt** (bis 6a1ca2c) —
  App live: v0.23.1.

**Ausführungsstand (Welle 3 — Phasenabschluss):**

- **04.10-03 ✅ (2026-06-11):** T6 Backup-Hygiene + interne Doku-Sync +
  Statusführung (D-03/D-04) — alle docs-Änderungen NUR lokal (gitignored,
  nicht committet):

  - **T6:** `docs/BACKUP.md` neu gefasst — drei verbindliche Regeln (niemals
    Echtdaten [Fiktivdaten-Regel], Aufbewahrung max. 30 Tage, Verschlüsselung
    verpflichtend mit dokumentierten Befehlen `zip -e` / `openssl enc
    -aes-256-cbc -pbkdf2` — alternativ Abschaffung; Empfehlung dokumentiert).
    Befund Bestandsaufnahme `~/ARGUS-Backups/`: 1 unverschlüsselte Backup-JSON
    vom 2026-06-05 (51 KB, Rechte 0600, innerhalb 30 Tage) + README; KEIN
    Workflow erzeugt automatisch Backups (nur manuelles
    `scripts/argus_backup.py`; keine GitHub-Workflows/crontab/LaunchAgents).
    Bestand unangetastet — Bereinigung ist Owner-Punkt (unten).

  - **Doku-Sync:** VVT (Dok. 01) §7 auf 72-h-Einsatzprotokoll-Modell +
    Log-Frist 12 Monate (Migration 0004); DSB-BRIEFING md+html inhaltlich
    identisch auf Ist-Stand v0.23.1 gehoben (72-h-Modell, Leitungs-Oberfläche
    ohne Dateinamen [D-06], Code-Sperre, Logs 12 Monate, T5-Hinweis in der
    App; frühere Fragen 4 [Fristen] und 5 [Foto] → „umgesetzt, Bestätigung
    erbeten"); SPEC: T5/T6 abgehakt (✅ Phase 4.10, 2026-06-11) + Ergänzung
    „Log-Aufbewahrung 12 Monate" mit T4-Abgrenzung (KEIN Audit-Log gebaut);
    Maßnahmenplan synchron (T5/T6/Auskunfts-Export abgehakt, Log-Frist +
    Doku-Sync unter Erledigt).

  - **Commit-Hygiene-Gate (gesamte Phase):** git-log seit 2026-06-11 und
    git-status über docs/datenschutz, DSB-BRIEFING.*, BACKUP.md → leer;
    D-06-Gate (`git grep -cE 'leitung-[0-9a-f]{6,}' -- ':!docs/'`) → 0.
  Details:
  `.planning/phases/04.10-datenschutz-schlusspaket/04.10-03-SUMMARY.md`.

**→ Phase 4.10 abgeschlossen. Datenschutz: technisch vollständig, offen ist
nur Organisatorisches (+ T4/T7 nach DSB-Votum).**

**Offene Owner-Punkte (gesammelt, Stand 2026-06-11):**

1. **PAT widerrufen** (aus 04.10-01; Supabase-Dashboard → Account → Access
   Tokens) — zusammen mit ggf. noch offenen Alt-PATs (Phase 4 / 04.8-02 /
   04.9-01).

2. **Backup-Bestand bereinigen:** `~/ARGUS-Backups/argus-backup-20260605-142432.json`
   (unverschlüsselter DB-Vollexport inkl. Zugangscodes, vom 2026-06-05)
   verschlüsseln (`zip -e` / `openssl enc`, Befehle in docs/BACKUP.md) **oder
   löschen — Empfehlung: löschen** (nur Übungsdaten, Struktur reproduzierbar).

3. **`DS_KONTAKT` befüllen** (aus 04.10-02; Konstante oben in index.html):
   Verantwortlicher + DSB-Kontakt vor Echtbetrieb eintragen — bis dahin
   zeigen beide Abschnitte gekennzeichnete Platzhalter.

4. **Push/Deploy:** Wellen 1–2 der Phase 4.10 sind gepusht/deployt (bis
   6a1ca2c, App live v0.23.1); die Statusführungs-Commits dieses Plans gehen
   mit dem Plan-Abschluss-Push hoch.

5. **Live-Test-Punkte aus 4.9 weiterhin offen:** Browser-Test der
   Leitungs-Seite (URL siehe lokale `LEITUNG-URL.md`): MasterToken-Login,
   Code-Sperre-Roundtrip, Protokoll-Abruf inkl. governance_log-Eintrag,
   Frist-Verlängerung; iPhone-Test v0.23.0/v0.23.1: Update-Banner,
   Abschluss-Strecke (72-h-Texte), Sperr-Test, neu: Datenschutz-Ansicht in
   den Hilfestellungen.

6. **DSB-Gespräch ist der nächste reale Schritt** — Briefing (md+html, intern)
   ist auf dem Stand des Live-Systems (72 h, Logs 12 Monate, v0.23.1) und
   kann unverändert mitgenommen werden.

---

## Phase 4.11 — Self-Hosting-Fähigkeit (ABGESCHLOSSEN 2026-06-11, v0.24.0)

**Planung:** 2 Pläne in 2 Wellen (geplant 2026-06-11, Checker PASS ohne
Blocker, voll autonom — kein PAT nötig).

**Ausführungsstand (Welle 1):**

- **04.11-01 ✅ (2026-06-11, v0.24.0):** Config-Auslagerung (D-01) —
  Supabase-URL + Anon-Key aus index.html und der Leitungs-Seite in die
  zentrale, build-freie `config.js` im Projektroot gezogen
  (`window.ARGUS_CONFIG`, globales Script statt JSON+fetch — synchron,
  offline-tauglich): einzige Stelle für den Instanz-Tausch beim
  Betriebsmodell M1, enthält nur die ohnehin öffentlichen Werte.
  SUPA_URL/SUPA_KEY werden abgeleitet statt definiert — alle Aufrufstellen
  (sb(), fetch-RPCs) und die Speicher-Naht unverändert. Fehlerpfad ohne
  native Dialoge: `_configError` → Statusbanner-Hinweis + Start-Toast
  (Feld-App), roter Hinweis in der Login-Box + Login-Abfang (Leitungs-Seite);
  exchangeCode/checkRevokedCode/doUnlock fangen hart ab (sonst liefen
  fetch-RPCs bei leerer URL relativ gegen den eigenen Origin → kryptischer
  404). sw.js: config.js im Precache, CACHE_NAME v43. Release v0.24.0
  (APP_VERSION, version.json, CHANGELOG, WHATS_NEW knapp; KEIN UPDATE-Sheet —
  für Nutzer unsichtbar). Gates grün: URL/Key-Isolation (git grep über
  *.html/*.js = exakt config.js), config.js NICHT gitignored, Precache-
  Konsistenz, JSC-Syntax (beide Inline-Scripts + sw.js + config.js),
  Smoke-Test HTTP 200, D-06 repo-weit 0 Treffer. Drehbuch geprüft: keine
  Lektionsänderung (keine UI-/Bedienungsänderung). Details:
  `.planning/phases/04.11-self-hosting/04.11-01-SUMMARY.md`.
  Commits d99c048 · 8481428 · 5e9ac55.

**Ausführungsstand (Welle 2 — Phasenabschluss):**

- **04.11-02 ✅ (2026-06-11):** Kompatibilitäts-Audit 0000–0004 (D-03) +
  öffentliche Aufbau-Anleitung `docs/SELF-HOSTING.md` (D-02, committet,
  328 Zeilen) — Zielgruppe fachkundige Admin-Person ohne Projektkenntnis:
  Varianten A (Supabase self-hosted via Docker Compose, empfohlen) / B
  (Postgres + PostgREST, ehrlich: Realtime entfällt → kein Live-Sync,
  Vault-Ersatzweg nötig); Audit-Tabelle pgjwt (Pflicht) / Vault-Secret
  `argus_jwt_secret` (Pflicht, MUSS dem PostgREST-JWT-Secret der Instanz
  entsprechen — kritischster Stolperstein) / pg_cron `argus_purge` (optional,
  Fallback App-Start-Purge aus 0002) / Realtime-Publikation patients+ccps
  (steht in KEINER Migration — expliziter Einrichtungsschritt) / anon-Rolle,
  je mit Prüf-SQL; Ein-Schritt-Apply, frische Codes + neuer MasterToken
  zwingend, config.js-Tausch als einziger App-Eingriff, Smoke-Test-Drehbuch
  (8 Schritte mit Erwartungsergebnissen inkl. Negativ-Prüfungen),
  Betriebsvorgaben (MDM-Dienstgeräte, Kürzel-Liste, Codes nur mündlich/Funk);
  SW-Origin-Befund als Betriebs-Voraussetzung (App-Hosting ≠ API-Origin).
  Keine Code-Änderungen (D-03: Befunde rein dokumentarisch). Negativ-Gates
  grün (keine Secrets/Interna/Leitungs-Name; D-06 repo-weit). Interne
  Statusführung lokal nachgezogen (SPEC T7 abgehakt, Maßnahmenplan,
  internes Runbook verweist auf SELF-HOSTING.md — alle gitignored). Details:
  `.planning/phases/04.11-self-hosting/04.11-02-SUMMARY.md`.

**→ Phase 4.11 abgeschlossen. Offene Owner-Punkte:**

1. **Push/Deploy** der Phase-4.11-Commits — danach ist v0.24.0 live.
2. **iPhone-Live-Test v0.24.0 (nach Deploy):** Update-Banner v0.24.0
   erscheint, App startet danach offline (config.js im SW-Precache v43),
   Code-Einlösung/Sync laufen unverändert — Live-Test der Config-Umstellung.
   Kein neuer PAT-Punkt (keine Migration in dieser Phase).

3. **Echte Zweitinstanz-Erprobung deferred:** sobald eine Zielumgebung
   (Polizei-/BITBW-Instanz oder Test-Stack) existiert, das
   Smoke-Test-Drehbuch aus `docs/SELF-HOSTING.md` einmal vollständig fahren.

---

## Phase 04.14 — Governance-Panel-Vervollständigung (IN ARBEIT)

**Planung:** 3 Pläne in 3 Wellen. Phase läuft.

**Ausführungsstand (Welle 1):**

- **04.14-01 ✅ (2026-06-27):** Migration `0013_phase414_admin_rolle.sql` (388 Zeilen)
  geschrieben, zweimal live angewendet (Management API, HTTP 201 × 2 = Idempotenz-Beleg).
  Alle 16 REST-Positiv-/Negativ-Tests + Sofortsperre-Test grün:
  `argus_exchange_admin_code` (JWT mit is_admin+admin_praesidium_id+jti, KEIN is_master/praesidium_id),
  `argus_admin_issue_gast`/`argus_admin_revoke_gast` (scoped security-definer-RPCs,
  harte Scope-Prüfung), `argus_lage`-Admin-Zweig; jti-Sofortsperre wirkt.
  Alle Privilege-Escalation-Vektoren (Fremd-Präsidium, Master-Code-Sperre, Roh-Patientenzugriff,
  Token-Insert) VERWEIGERT. `docs/SELF-HOSTING.md` auf 0012+0013 nachgeführt.
  D-06 gewahrt (kein konkreter Leitungs-Dateiname in committeten Texten).
  Testdaten aufgeräumt. **Offener Owner-Punkt: PAT widerrufen.**
  Details: `.planning/phases/04.14-governance-panel/04.14-01-SUMMARY.md`.
  Commits da103c7 · b4e4219.

- **PAT widerrufen (Owner-Punkt):** der für 04.14-01 genutzte ephemere PAT
  im Supabase-Dashboard widerrufen (zusammen mit ggf. offenen Alt-PATs).

**Ausführungsstand (Welle 2):**

- **04.14-02 ✅ (2026-06-27):** Leitungs-Seite rollen-adaptiv:
  `doLogin()` dual-exchange (Master-RPC zuerst; Admin-RPC nur als Fallback —
  verhindert Doppel-Log); `sessionRole()` liefert 'master'|'admin' (Default
  'master', abwärtskompatibel); Router/SECTIONS/sideNav rollen-adaptiv —
  Admin sieht nur „Gast-Code" + „Lage" (eigenes Präsidium, keine Phase-7-Zone);
  Master: neuer Button „Admin-Token" je Präsidiums-Karte (direkter
  access_tokens-Insert, is_admin=true), tokenArt-Zweig „Admin",
  zugSel-Filter „Admin"; Admin: secAdminZugang (argus_admin_issue_gast,
  argus_admin_revoke_gast, sitzungsbasierte Gast-Code-Liste — RLS-Grenze:
  Admin-JWT kein access_tokens-Select); secAdminLage (argus_lage, ~20s
  Auto-Refresh, Offline-Hinweis). Kein index.html/sw.js berührt — kein
  App-Release.
  Browser-Roundtrip alle 8 Checks PASS (freigegeben 2026-06-27): Master-
  Regression, Admin-Token-Ausgabe+Sperre, Admin-Login, Gast-Code-Ausgabe+Sperre,
  Lage, Instant-Revoke via jti-Gate. D-06 gewahrt (0 Treffer). Testdaten
  aufgeräumt.
  Key-Decision: Admin-JWT kann access_tokens nicht lesen (kein praesidium_id-
  Claim) → sitzungsbasierte Gast-Code-Liste als korrekte Architektur-Antwort.
  Details: `.planning/phases/04.14-governance-panel/04.14-02-SUMMARY.md`.
  Commits eb636b6 · 4c0cb33.

---

## Phase 4.13 — Paket 3: Schulungs-Provisionierung, Tombstone-Reset, AT-MIST-Druck (IN ARBEIT)

**Planung:** 2 Pläne in 2 Wellen (Backend vor Frontend), geplant 2026-06-13.

**Ausführungsstand (Welle 1):**

- **04.13-01 ✅ (2026-06-13):** Migration `0011_paket3_schulung.sql` geschrieben,
  live angewendet (Management API, 2× = Idempotenz-Beleg) und per REST
  verifiziert — `argus_schulung_reset(uuid)` (schulung=true-Pflicht-Check
  zuerst, Gate Master ODER eigenes Präsidium, DELETE patients/checklists VOR
  Tombstone-UPDATE mit exakter Abschluss-Signatur, 7-Tage-Tombstone-Hygiene
  nur im eigenen Präsidium, bewusst kein Lösch-/Governance-Log) und
  `argus_provision_schulung()` (master-only, idempotent, Namenskonvention
  „<Name> — Schulung"). Alle Positiv-/Negativ-/Hygiene-/Idempotenz-Tests grün
  (Tombstone-Signatur matcht isCcpClosedRow; Governance-Filter 0 Treffer);
  Testdaten restlos aufgeräumt. Diskretionsentscheid: provisioniertes
  „PP Karlsruhe — Schulung" bleibt auf der Instanz (gewollter Endzustand).
  SELF-HOSTING.md führt 0011 + Provisionierungs-Betriebs-Absatz inkl.
  7-Tage-Restrisiko. Details:
  `.planning/phases/04.13-paket3-schulung/04.13-01-SUMMARY.md`.
  Commits c0db693 · 65286ce.

- **PAT widerrufen (Owner-Punkt):** der für 04.13-01 genutzte ephemere PAT
  im Supabase-Dashboard widerrufen (zusammen mit ggf. offenen Alt-PATs).

**Ausführungsstand (Welle 2 — Phasenabschluss Code):**

- **04.13-02 ✅ (2026-06-13, v0.28.0):** Feld-App: `schulreset` ruft
  `argus_schulung_reset` per RPC (kein Client-Hard-DELETE; Fehlerpfad per
  Toast für Transport- UND jsonb-Fehler; confirmModal, Speicher-Bereinigung
  und genDemoRows-Loop unverändert — Offline-Geräte bereinigen sich über die
  vorhandene checkClosedEinsatz/handleRemoteClose-Mechanik). Alle 4
  Pflicht-Gates (loadSchulDirty, Training-Knopf, Reset-Knopf, Handler-Guard)
  plus 5. Stelle (Demo-Direkt-Merge, Discretion: Demo-MasterMedics können
  Merge-Anfragen nie bestätigen) auf `_praesidiumSchulung`; Rule-1-Fix:
  loadSchulDirty zählt nur offene CCPs (Reset-Tombstones blockierten sonst
  den „sauber"-Zustand dauerhaft). Leitungs-Seite: `makeProvision()`
  (Knopf „Schulungs-Präsidien anlegen/prüfen" im Zugänge-Kopf,
  `argus_provision_schulung` + Zugänge-Reload) und `vAtmistPrint()`
  (zweiter Druckknopf im Protokoll-Detail, AT-MIST-Karten aus
  `_detail.data.patients`, kein API-Call/kein Foto/kein img;
  body[data-atmist-print]-Print-CSS, Render-Beleg
  `04.13-02-atmist-preview.html`). Release v0.28.0 / SW ccp-shell-v51
  (v50 war durch v0.27.2 verbraucht), WHATS_NEW befüllt, KEIN UPDATE-Sheet
  (Trainer-/Leitungs-Thema); Drehbuch geprüft: Reset-Knopf in keiner Lektion.
  JSC-Syntax + lokaler Precache-Smoke (alle Assets 200) + D-06-Gate grün.
  Details: `.planning/phases/04.13-paket3-schulung/04.13-02-SUMMARY.md`.
  Commits bdc10de · e7c37d4 · 1dd4a0f. **Noch nicht gepusht** (Projektregel:
  Push macht der Orchestrator am Phasenende).

**Nächster Schritt (Orchestrator):** Push/Deploy der Phase-4.13-Commits,
danach Live-Smoke (ausgeliefertes version.json = 0.28.0, Marker
ccp-shell-v51 / argus_schulung_reset / argus_provision_schulung) und
Erst-Klick „Schulungs-Präsidien anlegen/prüfen" (erwartet idempotent:
„Keine neuen Schulungs-Präsidien nötig.", da „PP Karlsruhe — Schulung"
bereits existiert).

---

## Offene Entscheidungen / Hinweise

- **Repo ist public** auf GitHub — Widerspruch zur proprietären Lizenz.
  Bereinigung beim geplanten Production-Repo-Schnitt (Phase 5).

- **E-Mail-Platzhalter** in `LICENSE` + `README.md` → vor Open Beta ersetzen.
- **GSD-CLI lauffähig** seit 2026-06-13 (Node v22 unter `~/.local/node`,
  Runtime `~/.claude/gsd-core`) — der alte Hinweis „node fehlt" ist überholt.

- **TECH_DEBT.md** noch nicht angelegt — bei Bedarf erstellen.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 04.13 P01 | 25min | 2 tasks | 2 files |
| Phase 04.13 P02 | 12min | 3 tasks | 6 files |
| Phase 04.14 P01 | multi-session | 3 tasks | 2 files |
| Phase 04.14 P02 | 90min | 3 tasks | 1 file |
| Phase 05-01 | multi-session | 3 tasks | 2 files |
| Phase 05-02 | 5min | 2 tasks | 2 files |
| Phase 05-03 | ~35min | 2 tasks + checkpoint | 1 file |

## Decisions

- [Phase 04.13]: 04.13-01: Provisioniertes Schwester-Praesidium 'PP Karlsruhe — Schulung' bleibt auf der Instanz (gewollter Endzustand der Provisionierung, idempotent; ZZTEST-Artefakte aufgeraeumt)
- [Phase 04.13]: 04.13-02: Demo-Direkt-Merge (5. Gate-Stelle) ebenfalls auf _praesidiumSchulung umgestellt; loadSchulDirty zaehlt nur offene CCPs (Rule-1-Fix gegen Tombstone-Blockade); kein UPDATE-Sheet fuer v0.28.0; Push+Live-Smoke an Orchestrator delegiert
- [Phase 04.14]: 04.14-01: Admin-JWT traegt bewusst KEIN praesidium_id/is_master — alle bestehenden RLS-Policies liefern [] ohne Extra-Policies; argus_is_admin() gated auf argus_token_active() fuer jti-Sofortsperre; Gast-Code-Ausgabe/-Sperre als security-definer-RPCs (direkte Writes master-only per RLS 0001); 0013 nutzt dieselben Server-Abhaengigkeiten wie 0005/0007
- [Phase 04.14]: 04.14-02: Admin-JWT kein access_tokens-Select (kein praesidium_id-Claim) → sitzungsbasierte Gast-Code-Liste als Architektur-Loesung; dual-exchange doLogin (Master-RPC zuerst, Admin-Fallback) vermeidet Doppel-Log; kein App-Release (Leitungs-Seite Desktop-Begleitseite)
- [Phase 05-02]: 05-02-01: audit_log-Retention als Schritt (e) in argus_run_purge (create or replace) — kein zweiter Cron-Job; bigint-ms-Cutoff analog governance_log; Return-JSON additiv (audit_log_retention-Schluessel); 0016 live angewendet + idempotent + Funktionstest bestanden
- [Phase 05-03]: 05-03: Rollenwechsel = revoke(alt)+issue(neu, gleiche USBNK) statt direktem access_tokens-Update (Plan 01 hat keinen dedizierten Rollen-Change-RPC; RLS master-only + serverseitiges Logging); kein "Entsperren" (Widerruf = Kill-Switch, D-11); flz/normal-Person-Login akzeptiert aber ansichtslos (secNoView statt kaputter Master-Ansicht)
- [Phase 05-03]: 05-03 Gap-Fix: doLogin um dritten Versuch argus_exchange_person_code NACH Master/Admin erweitert (CR-02-Haertung laesst Person-Codes am Master-Exchange korrekt scheitern); USBNK→argusl_kuerzel als Actor → personenscharfe Leitungs-Seiten-Sessions (D-08, sonst usbnk=null)
