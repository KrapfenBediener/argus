# Phase 5: Identitäten & Audit-Protokoll (Stufe 1) — Context

**Gathered:** 2026-06-27
**Status:** Ready for planning
**Source:** Owner-Diskussion 2026-06-27 (discuss-phase). Architektur-Grundlage:
`.planning/PHASE7-ROLLENMODELL-DRAFT.md` (Stufenmodell, MUST READ). Roadmap-Neuordnung
2026-06-27: diese Arbeit ist jetzt Phase 5; DSB-Abhängigkeit entfällt vollständig.

<domain>
## Phase Boundary

Die **server-seitige Identitäts- & Audit-Schicht (Stufe 1)** bauen — auf
`access_tokens` + `jti`-Sofortsperre aufsetzend, mit Bedienung über die
**Leitungs-Seite** (Desktop-Begleitseite). **Kein App-Release, keine Feld-App-
Änderung** in dieser Phase (Muster wie 4.14).

**Kern:** Eine Sitzung trägt `(USBNK, Rolle, Präsidiums-Scope)`. Stufe 1 =
Pro-Person-USBNK-Token (batch provisioniert, Pro-Person-Widerruf, personenscharfes
T4-Audit). Master kann Rollen je USBNK vergeben/sperren und per USBNK suchen.

**IN SCOPE (Phase 5, Backend + Leitungs-Seite):**
- Datenmodell: `access_tokens` um `usbnk` + `role` (+ Scope via `praesidium_id`) erweitern → das
  **(USBNK→Rolle/Scope)-Register** (der dauerhafte Kern).
- **Einzel-Ausgabe** von Pro-Person-Tokens (security-definer-RPC, 4.14-Muster) für die privilegierten
  Leitungs-Seiten-Rollen (Master/FLZ/Admin) — **keine Massen-Provisionierung** (D-03/D-10).
- Stufe-1-Exchange-RPC → JWT mit `usbnk` + rollen-abgeleiteten Claims + Präsidiums-Scope + `jti`.
- Rollen: Normaler User, Master-User, FLZ-User, Präsidiums-Admin (im Register; vor SSO aktiv = die
  Leitungs-Seiten-Rollen).
- Master: USBNK-Suche + Rollen erteilen/widerrufen (jti-Sofortsperre), auf der Leitungs-Seite.
- **T4-Audit:** personenscharfes, append-only Verlaufsprotokoll (USBNK/Zeit/Aktion/CCP/Patient),
  12-Monats-Frist (§ 73 PolG BW), Anzeige in der ausgebauten Audit-Ansicht (4.14).
- Schema-Link Präsidium ↔ Schulungs-Zwilling (Datenmodell; normaler Token = beide Scopes).
- Privilege-Escalation-Schutz + REST-Positiv-/Negativtests (Muster 4.12/4.14).

**NICHT in dieser Phase (eigene Folgephasen):**
- **Phase 5.1 (Feld-App):** Pro-Person-Login (Token-Eingabe statt Sammelcode), FLZ-/Präsidiums-
  Picker mit zwei Reitern Echtbetrieb/Schulung. **Eigenes App-Release + Trainings-Drehbuch-Update.**
- **Stufe 2 (SSO):** IdP-Federation (PoliPhone-Profil / PC-Login) → Deployment/Echtbetrieb (PTLS/BITBW).
- **Stufe-1-Token-Missbrauchsschutz** (passwort-artig bei Diebstahl/Weitergabe) — bewusst vertagt.
</domain>

<decisions>
## Implementation Decisions (locked)

### D — Phasen-Zuschnitt
- **D-01:** Phase 5 = **nur Backend** (Identitäts-/Audit-Schicht) + Leitungs-Seite, **kein App-Release**.
  Die Feld-App-Umstellung (Pro-Person-Login + Echt/Schulung-Picker) ist **Phase 5.1** (eigenes Release +
  Drehbuch-Update). Hält die im Feld bewährte App stabil; Backend ist per REST + Leitungs-Seite testbar.

### A — Identität & Datenschutz
- **D-02:** **Nur USBNK** wird gespeichert (JWT-Claim + T4-Audit). **KEINE Klarnamen in ARGUS.**
  Klarname-Auflösung passiert extern im Polizei-Personalsystem. „Namenssuche" der Vorlage wird zur
  **USBNK-Suche**. Bewahrt die Pseudonymitäts-Leitlinie; USBNK ist personenbeziehbar (genau der Zweck
  von Stufe 1/T4), aber ARGUS hält kein zusätzliches PII.

### B — Identitäts-Register & Token-Modell (REVIDIERT 2026-06-27, D-10)
- **D-03 (REVIDIERT):** **KEINE Massen-Provisionierung.** Der dauerhafte Wert ist das
  **(USBNK→Rolle/Scope)-Register + Master-Verwaltung**, nicht das Ausrollen von ~30.000 Pro-Person-Tokens.
  Stattdessen: **Einzel-Ausgabe** von Pro-Person-Tokens durch den Master, NUR für die privilegierten
  Leitungs-Seiten-Rollen (Master/FLZ/Admin) — geringe Stückzahl, exakt das **4.14-Muster** („Master gibt
  Token aus", `security definer`-RPC, ein Geheim-Token, `jti`-Sofortsperre). Batch-Paste/CSV gestrichen.
- **D-04:** **Rollen im Register:** Normaler User · Master-User · FLZ-User · Präsidiums-Admin.
  Vor SSO **aktiv nutzbar** sind die Leitungs-Seiten-Rollen (Master existiert; Admin aus 4.14; FLZ neu,
  jetzt baubar). Die Rolle „Normaler User" wird im Register **vorgemerkt**, aktiviert sich aber erst mit
  der USBNK-Quelle (SSO / Phase 5.1) — bis dahin bleiben normale Feldnutzer Stufe 0 (pseudonym).
- **D-05:** **Koexistenz mit Stufe 0:** die bestehenden Sammel-/Gast-Codes (`argus_exchange_code`)
  bleiben gültig (Fremdkräfte-/Gäste-/Normalfeld-Fallback bis SSO). Privilegierte Pro-Person-Tokens
  laufen über einen eigenen/erweiterten Exchange. Privilege-Escalation-Leitplanken aus 4.14 (CR-02!)
  beachten: jede Exchange-Funktion weist fremde Token-Arten ab.

### C — T4-Audit-Protokoll
- **D-06:** **Umfang = mittel:** Patienten-Lebenszyklus (anlegen, Kategorie-Wechsel, transportfertig,
  auschecken, Foto), CCP-Lifecycle (eröffnen/schließen/zusammenführen), Login und Governance-Abrufe —
  jeweils **aktions-/zustandsbezogen** (USBNK, Zeit, CCP/Patient). **KEINE Einzelfeld-Diffs**
  (Vitalwerte/Maßnahmen/Notizen werden nicht je Feld protokolliert).
- **D-07 (locked defaults):** **append-only**; personenscharf über **USBNK**; **12-Monats-Frist**
  (§ 73 PolG BW; bestehender stündlicher Purge greift, vgl. Migration 0004). Anzeige in der
  4.14-Audit-Ansicht, erweitert um USBNK-Spalte/-Filter.
- **D-08 (Abhängigkeit):** Voll personenscharf wird das Protokoll erst, wenn **Feld-Sessions die USBNK
  mitsenden (Phase 5.1)**. In Phase 5 wird die Infrastruktur gebaut und erfasst bereits alle Stufe-1-
  Sessions (Master/FLZ/Admin auf der Leitungs-Seite). Vor 5.1 bleibt das kürzelbasierte `governance_log`
  (4.14) für Feld-Aktionen die Brücke.

### Scope-Revision (Owner 2026-06-27)
- **D-10:** **Massen-Provisionierung gestrichen.** Begründung: Das Ausrollen von ~30.000 Pro-Person-Tokens
  hängt am Personaldatenbank-Anschluss und wird durch **Stufe 2 (SSO)** ohnehin abgelöst — reine
  Übergangsbrücke, doppelte Arbeit. Stufe 2 liefert die USBNK transparent → normale Nutzer brauchen
  dann kein ARGUS-Token. **Identität ≠ Berechtigung:** die Personaldatenbank/SSO kennt nur die Identität
  (USBNK), NICHT die ARGUS-Rolle/-Scope — deshalb bleibt das Rollen-Register + die Master-Verwaltung der
  dauerhafte, jetzt zu bauende Wert (unabhängig von der USBNK-Quelle; „kein Re-Architecting zwischen den
  Stufen"). Massen-/Personaldatenbank-Anbindung wird **später präzise mit PTLS Pol abgestimmt**.

### Claude's Discretion (Implementierung — Researcher/Planner entscheiden)
- Datenmodell-Details: neue Spalten auf `access_tokens` vs. separate `identities`-Tabelle; `role` als
  enum/text vs. Beibehaltung der bestehenden Boolean-Flags (`is_master`/`is_admin`/`observer`) plus `role`.
- T4-Erfassung: server-seitige Trigger (lesen JWT-`usbnk`) vs. RPC-/App-seitiges Logging; `governance_log`
  erweitern vs. eigene append-only `audit_log`-Tabelle. Append-only-Durchsetzung (RLS/Trigger/revoke).
- Exchange: `argus_exchange_code` erweitern vs. eigener `argus_exchange_person_code`-RPC (analog zur
  4.14-Trennung — Achtung CR-02-Muster: jede Exchange-Funktion muss fremde Token-Arten abweisen).
- Batch-Provisionierungs-RPC: Eingabe-Parsing, Kollisionssicherheit der Geheim-Tokens, Rückgabeformat.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/PHASE7-ROLLENMODELL-DRAFT.md` — **Architektur-Grundlage (MUST READ):** Stufenmodell,
  SCOPE-vs-IDENTITÄT-Invariante, Rollen-Tabelle, „Was JETZT baubar ist", Sicherheits-Leitplanken.
- `supabase/migrations/0001_phase4_jwt_rls.sql` — `argus_praesidium_id()`/`argus_is_master()`,
  RLS-Muster, `argus_exchange_code` (Ur-Form).
- `supabase/migrations/0005_phase412_lageansicht.sql` — Claim-Muster (`is_observer` +
  `observer_praesidium_id` + Helper) — Vorlage für rollen-/scope-Claims.
- `supabase/migrations/0007_jti_sofortsperre.sql` — `jti` + `argus_token_active()` (Pro-Token-Echtzeit-
  Widerruf = das Pro-Person-Widerruf-Fundament für Stufe 1).
- `supabase/migrations/0009_paket2_gastcode_schulung.sql` — `gast`/`expires_at`, `schulung`-Flag je
  Präsidium (Echt/Schulung-Trennung, für den Schema-Link relevant).
- `supabase/migrations/0013_phase414_admin_rolle.sql` + `0014_phase414_admin_exchange_hardening.sql` —
  Präsidiums-Admin (`is_admin` + scoped RPCs), und **CR-02-Lektion**: jede Exchange-Funktion muss fremde
  Token-Arten abweisen (Privilege-Escalation-Schutz). `0004` — Log-Retention (12 Monate) / Purge.
- `docs/leitung-*.html` (Glob; Name aus LEITUNG-URL.md, D-06) — hier kommen Provisionierung,
  USBNK-Suche, Rollenvergabe und die erweiterte Audit-Ansicht hinein.
- `docs/SELF-HOSTING.md` — neue Migration(en) nachführen.
- `docs/datenschutz/` (gitignored) — VVT/TOM/Löschkonzept um Stufe-1-Identität + T4 spiegeln (local-only).
- Betriebswissen: DDL via Supabase Management API + ephemerer PAT (kein CLI); D-06-Geheimhaltung; Repo public.
</canonical_refs>

<specifics>
## Specific Ideas / Vollständigkeits-Punkte (im Plan berücksichtigen)

1. **CR-02-Wachsamkeit:** Bei JEDEM neuen/erweiterten Exchange-RPC die Token-Art-Abweisung prüfen
   (Stufe-1-Token darf nicht über den Gast-/Feld-Exchange anders wirken, und umgekehrt). REST-Negativtests Pflicht.
2. **Pro-Person-Widerruf** = einzelnen USBNK-Token `revoked` setzen → `jti`-Sofortsperre. In der
   Leitungs-Seite als Master-Aktion (USBNK suchen → sperren/entsperren/Rolle ändern).
3. **Master-Bootstrap** bleibt relevant (erste self-gehostete Instanz; vgl. SELF-HOSTING Abschnitt 8) —
   wie erhält der erste Master einen Stufe-1-Token? Mind. dokumentieren.
4. **Schema-Link Präsidium↔Schulungs-Zwilling:** Datenmodell so, dass ein normaler Token beide Scopes
   trägt (die Feld-App-Auswahl/zwei Reiter ist 5.1, aber das Modell wird hier gelegt).
5. **Migration(en):** vermutlich 0015 (Identität/Rollen) + ggf. 0016 (T4-Audit); idempotent; via
   Management API + ephemerer PAT (Checkpoint: PAT erfragen). PAT ist aktuell gültig (Owner-Hinweis).
6. **REST-Positiv-/Negativtests** gegen die Live-/Schulungs-Instanz (Muster 4.12/4.14-Summary).
7. **DSB-Doku** (VVT/TOM/Löschkonzept) um Stufe-1-Identität (USBNK) + T4 nachziehen — local-only.
8. **Append-only T4:** technische Durchsetzung (kein Update/Delete für normale Rollen; Purge nur über den
   kontrollierten Job) explizit verifizieren.
</specifics>

<deferred>
## Deferred Ideas

- **Phase 5.1 — Feld-App:** Pro-Person-Login (Token statt Sammelcode), Echt/Schulung-Picker (zwei Reiter).
  Eigenes App-Release + Trainings-Drehbuch-Update. Erst danach ist T4 für Feld-Aktionen voll personenscharf.
- **Stufe 2 (SSO):** Connector gegen Polizei-IdP (PoliPhone-Profil / PC-Login) → Deployment (PTLS/BITBW).
- **Stufe-1-Token-Missbrauchsschutz** (Rotation/Geräte-Bindung/2. Faktor) — bewusst vertagt
  („wenn die Zeit kommt", Owner 2026-06-22).
- **Massen-Provisionierung** (~30.000 Pro-Person-Tokens, Batch-Paste/CSV) — gestrichen (D-10);
  später präzise mit PTLS Pol + Personaldatenbank/SSO abstimmen. Normale Feldnutzer bleiben bis SSO Stufe 0.
- **Klarname-Speicherung in ARGUS** — bewusst ABGELEHNT (D-02); nur USBNK.
</deferred>

---

*Phase: 05-identitaeten-audit-stufe1*
*Context gathered: 2026-06-27*
