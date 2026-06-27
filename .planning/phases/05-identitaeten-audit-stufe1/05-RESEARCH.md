# Phase 5: Identitäten & Audit-Protokoll (Stufe 1) — Research

**Researched:** 2026-06-27
**Domain:** Supabase PostgreSQL — JWT-Claim-Erweiterung, Rollen-Register, append-only Audit, Leitungs-Seite (Single-File HTML/JS)
**Confidence:** HIGH (alle Kernbefunde aus direkter Codebase-Analyse)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Phase 5 = nur Backend (Identitäts-/Audit-Schicht) + Leitungs-Seite, kein App-Release. Die Feld-App-Umstellung (Pro-Person-Login + Echt/Schulung-Picker) ist Phase 5.1 (eigenes Release + Drehbuch-Update). Hält die im Feld bewährte App stabil; Backend ist per REST + Leitungs-Seite testbar.

**D-02:** Nur USBNK wird gespeichert (JWT-Claim + T4-Audit). KEINE Klarnamen in ARGUS. Klarname-Auflösung passiert extern im Polizei-Personalsystem. „Namenssuche" der Vorlage wird zur USBNK-Suche. Bewahrt die Pseudonymitäts-Leitlinie; USBNK ist personenbeziehbar (genau der Zweck von Stufe 1/T4), aber ARGUS hält kein zusätzliches PII.

**D-03 (REVIDIERT):** KEINE Massen-Provisionierung. Der dauerhafte Wert ist das (USBNK→Rolle/Scope)-Register + Master-Verwaltung. Stattdessen: Einzel-Ausgabe von Pro-Person-Tokens durch den Master, NUR für die privilegierten Leitungs-Seiten-Rollen (Master/FLZ/Admin) — geringe Stückzahl, exakt das 4.14-Muster.

**D-04:** Rollen im Register: Normaler User · Master-User · FLZ-User · Präsidiums-Admin. Vor SSO aktiv nutzbar sind die Leitungs-Seiten-Rollen. Die Rolle „Normaler User" wird im Register vorgemerkt, aktiviert sich aber erst mit der USBNK-Quelle (SSO/Phase 5.1).

**D-05:** Koexistenz mit Stufe 0: die bestehenden Sammel-/Gast-Codes (argus_exchange_code) bleiben gültig. Privilegierte Pro-Person-Tokens laufen über einen eigenen/erweiterten Exchange. Privilege-Escalation-Leitplanken aus 4.14 (CR-02!) beachten.

**D-06:** Umfang T4-Audit = mittel: Patienten-Lebenszyklus (anlegen, Kategorie-Wechsel, transportfertig, auschecken, Foto), CCP-Lifecycle (eröffnen/schließen/zusammenführen), Login und Governance-Abrufe — jeweils aktions-/zustandsbezogen (USBNK, Zeit, CCP/Patient). KEINE Einzelfeld-Diffs.

**D-07 (locked defaults):** append-only; personenscharf über USBNK; 12-Monats-Frist (§ 73 PolG BW; bestehender stündlicher Purge greift, vgl. Migration 0004). Anzeige in der 4.14-Audit-Ansicht, erweitert um USBNK-Spalte/-Filter.

**D-08 (Abhängigkeit):** Voll personenscharf wird das Protokoll erst, wenn Feld-Sessions die USBNK mitsenden (Phase 5.1). In Phase 5 wird die Infrastruktur gebaut und erfasst bereits alle Stufe-1-Sessions (Master/FLZ/Admin auf der Leitungs-Seite).

**D-10:** Massen-Provisionierung gestrichen. Identität ≠ Berechtigung: die Personaldatenbank/SSO kennt nur die Identität (USBNK), NICHT die ARGUS-Rolle/-Scope — deshalb bleibt das Rollen-Register + die Master-Verwaltung der dauerhafte, jetzt zu bauende Wert.

### Claude's Discretion (Implementierung — Researcher/Planner entscheiden)

- Datenmodell-Details: neue Spalten auf `access_tokens` vs. separate `identities`-Tabelle; `role` als enum/text vs. Beibehaltung der bestehenden Boolean-Flags (`is_master`/`is_admin`/`observer`) plus `role`.
- T4-Erfassung: server-seitige Trigger (lesen JWT-`usbnk`) vs. RPC-/App-seitiges Logging; `governance_log` erweitern vs. eigene append-only `audit_log`-Tabelle. Append-only-Durchsetzung (RLS/Trigger/revoke).
- Exchange: `argus_exchange_code` erweitern vs. eigener `argus_exchange_person_code`-RPC (analog zur 4.14-Trennung — Achtung CR-02-Muster: jede Exchange-Funktion muss fremde Token-Arten abweisen).
- Batch-Provisionierungs-RPC: Eingabe-Parsing, Kollisionssicherheit der Geheim-Tokens, Rückgabeformat.

### Deferred Ideas (OUT OF SCOPE)

- **Phase 5.1 — Feld-App:** Pro-Person-Login (Token statt Sammelcode), Echt/Schulung-Picker (zwei Reiter). Eigenes App-Release + Trainings-Drehbuch-Update.
- **Stufe 2 (SSO):** Connector gegen Polizei-IdP (PoliPhone-Profil / PC-Login).
- **Stufe-1-Token-Missbrauchsschutz** (Rotation/Geräte-Bindung/2. Faktor) — bewusst vertagt.
- **Massen-Provisionierung** (~30.000 Pro-Person-Tokens) — gestrichen (D-10).
- **Klarname-Speicherung in ARGUS** — bewusst ABGELEHNT (D-02); nur USBNK.
</user_constraints>

---

## Summary

Phase 5 baut die server-seitige Identitäts- und Audit-Schicht auf dem bereits konsolidierten Backend (Migrationen 0000–0014). Das Fundament ist solide: `access_tokens` trägt bereits ein vollständiges Token-Register mit jti-Sofortsperre (0007), `governance_log` protokolliert bereits alle Governance-Aktionen (0002/0004), und das 4.14-Muster (eigener Exchange-RPC + security-definer-RPCs für Ausgabe/Sperre + CR-02-Abweisung fremder Token-Arten) ist vollständig etabliert.

Der eigentliche Build-Aufwand ist eng umgrenzt: (1) `access_tokens` um `usbnk text` und `role text` erweitern → das dauerhafte Register; (2) einen eigenen Exchange-RPC `argus_exchange_person_code` für Pro-Person-Tokens erstellen, der `usbnk` + rollen-abgeleitete Claims + jti ins JWT legt; (3) security-definer-RPCs für Master: Token ausgeben (usbnk + Rolle) und sperren; (4) eine eigene append-only `audit_log`-Tabelle für T4 anlegen (dedizierte Tabelle ist besser als `governance_log` erweitern, weil T4 andere Abfrageprofile, andere Retention-Logik und andere Sichtbarkeitsregeln hat); (5) die Leitungs-Seite um USBNK-Suche, Token-Ausgabe, Rollenverwaltung und die erweiterte Audit-Ansicht ergänzen.

Die heute gesperrten Abschnitte „Identitäten" und „Audit-Log" in der Leitungs-Seiten-Navigation (Zeilen 715–718) sind bereits vorhanden — sie müssen nur entsperrt und mit Inhalt gefüllt werden.

**Primary recommendation:** Separate `argus_exchange_person_code`-RPC + neue `audit_log`-Tabelle (nicht `governance_log` erweitern). Beide folgen exakt dem 4.14-Muster. Zwei Migrationen: 0015 (Identität/Rollen) + 0016 (T4-Audit).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| USBNK-Register (Speicherung) | Database (`access_tokens` columns) | — | Bestehende Tabelle; nur neue Spalten |
| Rollen-Register | Database (`access_tokens.role`) | — | Konsistenz mit bestehenden Boolean-Flags |
| Pro-Person-Token-Ausgabe | API/RPC (security definer) | — | Exakt 4.14-Muster (`argus_admin_issue_gast`) |
| Pro-Person-Token-Widerruf | API/RPC (security definer) | — | `revoked=true` → jti-Sofortsperre wirkt sofort |
| Exchange (Person-Token → JWT) | API/RPC (security definer) | — | Eigener Exchange analog `argus_exchange_admin_code` |
| JWT-Claim-Routing | Database (Claim-Helfer-Funktionen) | — | `argus_is_flz()`, `argus_usbnk()`, analog 0005/0013 |
| T4-Audit-Erfassung | API/RPC (security definer, Zwangs-Log) | — | Kein Trigger (JWT-Kontext in Triggers nicht zuverlässig via `current_setting`) |
| T4-Audit-Sichtbarkeit | Database (RLS) | Leitungs-Seite (UI) | Master liest; append-only über Grant/RLS erzwingen |
| USBNK-Suche + Rollenverwaltung | Leitungs-Seite (Frontend) | API/RPC | Nur neue Sektion in bestehender HTML-Datei |
| Präsidium ↔ Schulungs-Zwilling | Database (praesidien.schulung + Join-Logik) | — | Spalte existiert (Migration 0009); Modell-Erweiterung |
| Master-Bootstrap (erster Stufe-1-Token) | SELF-HOSTING.md (Dokumentation) | Supabase Dashboard | Einmalig manuell; kein RPC nötig |

---

## Standard Stack

### Core — keine neuen npm-Pakete

Diese Phase ist ausschließlich SQL-Migrations + Single-File-HTML-Erweiterung. Alle externen Abhängigkeiten (pgjwt/extensions, Vault, Supabase JS Client) sind bereits im Projekt vorhanden. Es werden **keine neuen Pakete installiert**.

[VERIFIED: direkte Codebase-Analyse 0000–0014 + Leitungs-Seite]

| Komponente | Version/Stand | Zweck | Status |
|------------|--------------|-------|--------|
| `extensions.sign()` (pgjwt) | Live in Supabase EU | JWT-Signierung in RPCs | Vorhanden (alle Exchange-RPCs) |
| `vault.decrypted_secrets` | Live in Supabase EU | JWT-Secret-Abruf | Vorhanden (alle Exchange-RPCs) |
| `@supabase/supabase-js` | CDN, geladene Version in leitung-*.html | API-Calls aus dem Leitungs-Seiten-JS | Vorhanden |
| `pg_cron` Job `argus_purge` | Live, `17 * * * *` | Stündlicher Purge inkl. Log-Retention | Vorhanden (0004) |

### Package Legitimacy Audit

> Kein neues Paket in dieser Phase — Audit entfällt.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Leitungs-Seite (Browser)
        │
        │  argus_exchange_person_code(code)
        │  ─────────────────────────────►  [RPC: security definer]
        │                                       │
        │                                  access_tokens lookup
        │                                  (is_person=true, usbnk, role, praesidium_id)
        │                                       │
        │                                  JWT: usbnk + is_flz/is_master + praesidium_id + jti
        │  ◄──────────────────────────────      │
        │  { jwt, usbnk, role, praesidium_name }
        │
        │  (gespeichertes JWT als Bearer)
        │
        │  argus_master_issue_person(usbnk, role, praesidium_id)
        │  ─────────────────────────────►  [RPC: security definer, argus_is_master()]
        │                                  INSERT access_tokens (usbnk, role, is_person=true, ...)
        │                                  INSERT audit_log (action='person_issue', usbnk_actor, ...)
        │  ◄──────────────────────────────
        │  { short_code }
        │
        │  argus_master_revoke_person(short_code)
        │  ─────────────────────────────►  [RPC: security definer, argus_is_master()]
        │                                  UPDATE access_tokens SET revoked=true
        │                                  → jti-Sofortsperre wirkt sofort
        │                                  INSERT audit_log (action='person_revoke', ...)
        │
        │  argus_master_search_usbnk(usbnk_fragment)
        │  ─────────────────────────────►  [RPC: security definer, argus_is_master()]
        │                                  SELECT access_tokens WHERE usbnk ILIKE ...
        │  ◄──────────────────────────────
        │  [{ usbnk, role, short_code, revoked, praesidium_name }]
        │
        │  (T4-Audit-Einträge)
        │  SELECT audit_log ...
        │  ─────────────────────────────►  [RLS: argus_is_master()]
        │  ◄──────────────────────────────
        │  [{ at, usbnk, action, ccp_id, patient_id }]
        │
┌────────────────────┐
│ argus_run_purge()  │ (pg_cron, stündlich)
│ + Schritt (e):     │
│ audit_log > 12 Mo  │
└────────────────────┘
```

### Recommended Project Structure

```
supabase/migrations/
├── 0015_phase5_identitaeten.sql   # access_tokens-Erweiterung + Claim-Helfer + Exchange + Issue/Revoke/Search-RPCs
└── 0016_phase5_t4_audit.sql       # audit_log-Tabelle + Purge-Erweiterung + audit_log-RLS
docs/
└── leitung-<hex>.html             # +Identitäten-Sektion + Audit-Log-Sektion (bestehende Datei erweitern)
docs/SELF-HOSTING.md               # 0015/0016 nachführen + Master-Bootstrap-Abschnitt 8 erweitern
```

### Pattern 1: Eigener Exchange-RPC für Pro-Person-Tokens (4.14-Muster)

**Was:** Dedizierter `argus_exchange_person_code(code text)` analog `argus_exchange_admin_code`. Liest `is_person=true` aus `access_tokens`, weist alle anderen Token-Arten ab. JWT trägt `usbnk`, `role`-abgeleitete Claims (`is_flz` oder `is_master` je Rolle), `praesidium_id` (für FLZ: null, für Master: null, für Admin: admin_praesidium_id), `jti`.

**Wann verwenden:** Immer wenn ein Stufe-1-Pro-Person-Token gegen ein JWT eingetauscht werden soll. NICHT über `argus_exchange_code` (CR-02-Leitplanke).

**CR-02-Pflicht:** `argus_exchange_code` MUSS um eine `is_person`-Abweisung ergänzt werden (analog zur is_admin-Abweisung in 0014). [VERIFIED: direkte Analyse 0014]

```sql
-- Source: Codebase-Analyse Migration 0013/0014
-- Muster für argus_exchange_person_code (Kern-Logik):
create or replace function public.argus_exchange_person_code(code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions', 'vault'
as $function$
declare
  v_clean       text;
  v_short_code  text;
  v_token       record;   -- praesidium_id, is_person, usbnk, role, revoked, expires_at
  v_now         int;
  v_exp         int;
  v_ttl_secs    int;
  v_jwt         text;
  v_jwt_secret  text;
  v_pname       text;
begin
  -- Normalisierung identisch allen anderen Exchanges
  v_clean := upper(regexp_replace(code, '[\s\-]', '', 'g'));
  if length(v_clean) < 8 then
    return jsonb_build_object('error', 'Code zu kurz');
  end if;
  v_short_code := substring(v_clean,1,4) || '-' || substring(v_clean,5,4);

  select praesidium_id, is_person, usbnk, role, revoked, expires_at
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  if not coalesce(v_token.is_person, false) then
    return jsonb_build_object('error', 'Kein Pro-Person-Code');
  end if;
  if v_token.expires_at is not null
     and v_token.expires_at <= (extract(epoch from now())*1000)::bigint then
    return jsonb_build_object('error', 'Code abgelaufen');
  end if;

  v_now      := extract(epoch from now())::int;
  v_ttl_secs := 30*24*3600;   -- 30 Tage (Master/FLZ langlebig; Planner kann kürzen)
  v_exp      := v_now + v_ttl_secs;

  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret' limit 1;
  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  -- JWT: rollen-abgeleitete Claims analog 0005/0013-Muster.
  -- FLZ-Claim: is_flz=true; Master-Claim: is_master=true.
  -- Scope: praesidium_id NUR für Rollen, die einen präzisen Präsidiums-Scope brauchen
  -- (Admin: admin_praesidium_id; FLZ/Master: null → sehen alles via argus_is_master/flz).
  v_jwt := extensions.sign(
    json_build_object(
      'iss',           'supabase',
      'sub',           'argus-person',
      'role',          'anon',
      'usbnk',         v_token.usbnk,
      'argus_role',    v_token.role,       -- 'master' | 'flz' | 'admin'
      'is_master',     (v_token.role = 'master'),
      'is_flz',        (v_token.role = 'flz'),
      'is_admin',      (v_token.role = 'admin'),
      'praesidium_id', case when v_token.role in ('master','flz')
                            then null
                            else v_token.praesidium_id end,
      'admin_praesidium_id', case when v_token.role = 'admin'
                                  then v_token.praesidium_id
                                  else null end,
      'jti',           v_short_code,
      'iat',           v_now,
      'exp',           v_exp
    ),
    v_jwt_secret
  );

  -- Zwangs-Login-Log
  insert into public.audit_log (at, usbnk, action, praesidium_id)
    values ((extract(epoch from now())*1000)::bigint,
            v_token.usbnk, 'person_login', v_token.praesidium_id);

  if v_token.praesidium_id is not null then
    select name into v_pname from public.praesidien where id = v_token.praesidium_id;
  end if;

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'usbnk',           v_token.usbnk,
    'argus_role',      v_token.role,
    'praesidium_id',   v_token.praesidium_id,
    'praesidium_name', v_pname,
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;
grant execute on function public.argus_exchange_person_code(text) to anon;
```

[VERIFIED: Codebase-Analyse — Muster aus 0013/0014]

### Pattern 2: Datenmodell — neue Spalten auf `access_tokens`

**Was:** `access_tokens` um drei Spalten erweitern: `is_person boolean not null default false`, `usbnk text`, `role text`. Kein separates `identities`-Register nötig — die bestehende Tabelle ist bereits ein Token-Register mit Präsidiums-Scope, revoked-Flag, jti-Sofortsperre. Eine separate Tabelle würde Join-Komplexität hinzufügen ohne Gewinn.

**Begründung gegen separate Tabelle:** `access_tokens` enthält bereits alle Token-Metadaten; der Planner kann beim Aufbau der USBNK-Suche direkt auf `access_tokens WHERE is_person=true` filtern. Keine FK-Joins, keine Synchronisations-Probleme.

**`role`-Spalte als text (nicht enum):** Konsistenz mit der übrigen Codebase (kein enum bisher). Text erlaubt idempotente `create or replace` ohne `ALTER TYPE`. Werte: `'master'`, `'flz'`, `'admin'`, `'normal'` (letzterer nur registriert, bis SSO aktiviert).

[VERIFIED: Codebase-Analyse 0000_base_schema.sql + 0013]

```sql
-- Source: Codebase-Analyse (Muster analog zu 0005/0013)
alter table public.access_tokens add column if not exists is_person boolean not null default false;
alter table public.access_tokens add column if not exists usbnk     text;        -- null für Stufe-0-Tokens
alter table public.access_tokens add column if not exists role      text;        -- 'master'|'flz'|'admin'|'normal'|null

-- Claim-Helfer (analog argus_is_observer/argus_is_admin):
create or replace function public.argus_is_flz()
  returns boolean language sql stable security definer as $$
  select public.argus_token_active()
     and coalesce((current_setting('request.jwt.claims', true)::json->>'is_flz')::boolean, false)
$$;
grant execute on function public.argus_is_flz() to anon;

create or replace function public.argus_usbnk()
  returns text language sql stable security definer as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'usbnk','')
$$;
grant execute on function public.argus_usbnk() to anon;

create or replace function public.argus_argus_role()
  returns text language sql stable security definer as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'argus_role','')
$$;
grant execute on function public.argus_argus_role() to anon;
```

### Pattern 3: T4-Audit — eigene `audit_log`-Tabelle (NICHT `governance_log` erweitern)

**Was:** Eine dedizierte, append-only `audit_log`-Tabelle. `governance_log` bleibt unverändert (ist für Governance-/Foto-Ereignisse; hat anderen Scope und andere Consumer).

**Warum eigene Tabelle:**
- `governance_log` hat keine `usbnk`-Spalte und ist semantisch anders (Governance-Abrufe/Fristen). Eine `usbnk`-Spalte nachträglich hinzuzufügen würde alle bestehenden Rows NULL haben und das Schema verwirren.
- T4-Audit hat andere Abfrageprofile (nach USBNK filtern, nach Patient/CCP, nach Aktionstyp).
- Saubere Trennung: `governance_log` = Foto/Protokoll-Governance; `audit_log` = personenscharfes T4-Protokoll.
- Append-only lässt sich einfacher mit einer neuen Tabelle durchsetzen (no UPDATE/DELETE grant für anon; INSERT nur über security-definer-RPCs).

**Append-only-Durchsetzung:** Kein `UPDATE`- und kein `DELETE`-Grant auf `audit_log` für die `anon`-Rolle. `INSERT` nur über `SECURITY DEFINER`-RPCs (wie `argus_run_purge` für den kontrollierten 12-Monats-Purge). `anon` erhält nur `SELECT` (RLS: `argus_is_master()`).

[VERIFIED: Codebase-Analyse 0002 governance_log + 0004 purge-Muster]

```sql
-- Source: Codebase-Analyse (Muster analog 0002 governance_log + 0004 purge)
create table if not exists public.audit_log (
  id           uuid primary key default gen_random_uuid(),
  at           bigint not null,          -- JS-Millisekunden (Konvention aus 0002)
  usbnk        text,                     -- null bei Stufe-0-Aktionen (bis Phase 5.1)
  action       text not null,            -- s. Aktions-Katalog unten
  ccp_id       uuid,
  patient_id   text,
  praesidium_id uuid,
  detail       text                      -- optionaler Freitext (Rollenwechsel: neue Rolle)
);

-- Append-only-Enforcement: nur SELECT für anon; INSERT/UPDATE/DELETE nie direkt
grant select on public.audit_log to anon;
-- KEIN: grant insert/update/delete ... to anon  ← deliberate omission
alter table public.audit_log enable row level security;
drop policy if exists argus_audit_log_select on public.audit_log;
create policy "argus_audit_log_select" on public.audit_log
  for select to anon using ( public.argus_is_master() );
-- INSERT nur über security-definer-RPCs (nie direkt über anon-key)
```

**Aktions-Katalog (T4, D-06):**

| Aktion | Trigger | USBNK vorhanden? |
|--------|---------|-----------------|
| `person_login` | Exchange-RPC erfolgreich | ja (Phase 5) |
| `person_issue` | Master gibt Token aus | ja (actor + target usbnk) |
| `person_revoke` | Master widerruft Token | ja |
| `person_role_change` | Master ändert Rolle | ja |
| `patient_create` | Patient angelegt | Phase 5.1 (bis dahin null) |
| `patient_cat_change` | Kategorie gewechselt | Phase 5.1 |
| `patient_ready` | Transportfertig gesetzt | Phase 5.1 |
| `patient_checkout` | Ausgecheckt (gPA) | Phase 5.1 |
| `patient_photo` | Foto erfasst | Phase 5.1 |
| `ccp_open` | CCP eröffnet | Phase 5.1 |
| `ccp_close` | CCP abgeschlossen | Phase 5.1 |
| `ccp_merge` | CCPs zusammengeführt | Phase 5.1 |
| `governance_abruf` | Protokoll-/Governance-Abruf | ja (Phase 5, Leitungs-Seite) |

**Phase-5-Scope:** Nur die mit „Phase 5" markierten Aktionen werden jetzt implementiert (Leitungs-Seiten-Sessions). Die Feld-App-Aktionen (patient_*, ccp_*) kommen mit Phase 5.1.

### Pattern 4: Pro-Person-Token-Ausgabe (Master-RPC, 4.14-Muster)

**Was:** `argus_master_issue_person(p_usbnk text, p_role text, p_praesidium_id uuid, p_label text)` — security definer, nur für `argus_is_master()`. Erzeugt einen `is_person=true`-Eintrag in `access_tokens` mit `usbnk` und `role`. Kollisions-Schleife für `short_code` wie in `argus_admin_issue_gast` (0013). Schreibt `person_issue` in `audit_log`.

**Was:** `argus_master_revoke_person(p_short_code text)` — security definer, nur für `argus_is_master()`. Setzt `revoked=true` → jti-Sofortsperre wirkt sofort. Schreibt `person_revoke` in `audit_log`. Darf niemals Master-Tokens widerrufen (Guard: `is_master=false` oder eigenes Token prüfen).

**Was:** `argus_master_search_usbnk(p_usbnk text)` — security definer, nur für `argus_is_master()`. Gibt alle `access_tokens` zurück, wo `usbnk ILIKE '%' || p_usbnk || '%'` und `is_person=true`. Gibt `usbnk, role, short_code, revoked, praesidium_name, created_at` zurück — KEINE Token-Secrets.

```sql
-- Source: Codebase-Analyse (Muster aus 0013 argus_admin_issue_gast)
-- Kernlogik argus_master_issue_person:
create or replace function public.argus_master_issue_person(
  p_usbnk text, p_role text, p_praesidium_id uuid, p_label text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions'
as $function$
declare
  v_alphabet   text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_short_code text;
  v_token      text;
  v_now_ms     bigint;
  v_part1      text;
  v_part2      text;
  v_attempt    int := 0;
  v_exists     boolean;
  v_actor_usbnk text;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  -- Eingabe-Validierung
  if p_usbnk is null or btrim(p_usbnk) = '' then
    raise exception 'USBNK erforderlich';
  end if;
  if p_role not in ('master','flz','admin','normal') then
    raise exception 'Ungültige Rolle';
  end if;
  -- Admin-Tokens brauchen ein Präsidium
  if p_role = 'admin' and p_praesidium_id is null then
    raise exception 'Admin-Token erfordert Präsidium';
  end if;

  v_actor_usbnk := public.argus_usbnk();   -- USBNK des ausstellenden Masters für Audit
  v_now_ms      := (extract(epoch from now())*1000)::bigint;
  v_token       := encode(extensions.gen_random_bytes(16), 'hex');

  -- Short-Code generieren (Kollisions-Schleife, identisch 0013)
  loop
    v_attempt := v_attempt + 1;
    if v_attempt > 10 then
      raise exception 'Short-Code-Kollision — bitte erneut versuchen';
    end if;
    v_part1 := ''; v_part2 := '';
    for i in 1..4 loop
      v_part1 := v_part1 || substr(v_alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    for i in 1..4 loop
      v_part2 := v_part2 || substr(v_alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    v_short_code := v_part1 || '-' || v_part2;
    select exists(select 1 from public.access_tokens where short_code = v_short_code)
    into v_exists;
    exit when not v_exists;
  end loop;

  insert into public.access_tokens (
    token, short_code, praesidium_id, is_person, usbnk, role,
    is_master, is_admin, observer, gast, single_use, temporary, ttl_hours, label
  ) values (
    v_token, v_short_code, p_praesidium_id, true, btrim(p_usbnk), p_role,
    false, false, false, false, false, false, null, btrim(coalesce(p_label,''))
  );

  insert into public.audit_log (at, usbnk, action, praesidium_id, detail)
    values (v_now_ms, v_actor_usbnk, 'person_issue', p_praesidium_id,
            'role=' || p_role || ' target=' || btrim(p_usbnk));

  return jsonb_build_object('short_code', v_short_code);
end;
$function$;
grant execute on function public.argus_master_issue_person(text, text, uuid, text) to anon;
```

### Pattern 5: Schema-Link Präsidium ↔ Schulungs-Zwilling

**Was:** `praesidien.schulung` (boolean, vorhanden seit 0009) differenziert bereits Schulungs-Präsidien. Das Modell für Phase 5 ist: Wenn ein normaler Token beide Scopes trägt (Echt + Schulung), braucht die Tabelle einen Verweis vom Echt-Präsidium auf sein Schulungs-Pendant. Empfehlung: neue Spalte `schulungs_zwilling_id uuid references praesidien(id)` auf `praesidien`. Diese erlaubt dem Exchange-RPC, bei einem normalen Token `['praesidium_id', 'schulungs_praesidium_id']` ins JWT zu legen (für Phase 5.1, wenn der Picker ausgebaut wird).

**Phase-5-Scope:** Nur das Datenmodell (Spalte) hinzufügen. Die Feld-App-Nutzung (Picker) kommt mit Phase 5.1. [VERIFIED: Codebase-Analyse 0009]

```sql
-- Source: Codebase-Analyse 0009 (praesidien.schulung)
alter table public.praesidien
  add column if not exists schulungs_zwilling_id uuid references public.praesidien(id);
-- Füllen: für jedes Echt-Präsidium den UUID seines Schulungs-Pendant eintragen
-- (via Supabase-Dashboard nach Deployment — oder als idempotente UPDATE-Zeilen
-- in der Migration, wenn die UUIDs bereits bekannt sind).
```

### Anti-Patterns to Avoid

- **`governance_log` um `usbnk` erweitern:** governance_log ist für Governance-/Foto-Abrufe. Bestehende Rows hätten NULL-usbnk, Filter würden verwirrende Mischergebnisse liefern. Eigene `audit_log`-Tabelle ist sauber.
- **Trigger für T4-Audit-Erfassung:** PostgreSQL-Trigger können `current_setting('request.jwt.claims')` lesen, aber nur wenn sie im Kontext eines PostgREST-Requests laufen. Bei Direkt-SQL (Management-API-Aufrufe) oder pg_cron-Jobs fehlt der JWT-Kontext → der `usbnk`-Claim wäre null. Alle T4-Log-Einträge MÜSSEN über security-definer-RPCs erfolgen, die den USBNK-Claim explizit lesen und weiterreichen.
- **`is_person=true` ohne `is_admin/is_master/observer/gast` explizit auf `false` setzen:** INSERT-Rows müssen alle Boolean-Flags explizit setzen, um versehentliche Privilegien zu verhindern (vgl. `argus_admin_issue_gast` in 0013).
- **`argus_exchange_code` ohne `is_person`-Abweisung live lassen:** Sobald `is_person=true`-Tokens existieren, MUSS `argus_exchange_code` sie abweisen (CR-02-Logik: ein Person-Code dort eingelöst würde ein `praesidium_id`-JWT erzeugen und RLS-Zugriff auf Patientendaten geben — für FLZ/Master sogar mit `is_master=true`-Claim). Dies ist die erste Zeile in Migration 0015.
- **`search_path` in security-definer-Funktionen vergessen:** Alle neuen RPCs MÜSSEN `set search_path to 'public', 'extensions', 'vault'` (bzw. passende Teilmenge) tragen. Fehlendes `search_path` bei `security definer` = kritische Sicherheitslücke (schema injection). [VERIFIED: alle bestehenden RPCs in 0001–0014 tragen search_path]
- **`usbnk` im JWT als `sub` setzen:** Die bestehende Konvention ist `'sub', 'argus-device'` / `'argus-admin'` / `'argus-observer'`. USBNK geht als eigener Claim (`'usbnk'`), nicht als `sub` — sonst könnten Supabase-interne Auth-Mechanismen interferieren.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Kollisionssichere Short-Codes | eigene UUID/Zufall-Logik | `argus_admin_issue_gast`-Muster aus 0013 | bewährt, getestet, selbes Alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| JWT-Signierung | eigene Crypto | `extensions.sign()` (pgjwt, bereits aktiv) | einzige authorisierte Methode im Projekt |
| Sofort-Widerruf | eigene Sperr-Logik | `revoked=true` → `argus_token_active()` Gate | bereits in allen Claim-Helfern eingebaut; wirkt sofort ohne JWT-Ablauf |
| Append-only-Enforcement | Trigger/Hooks | Grant-Beschränkung + security-definer INSERT | einfacher, auditierbarer, keine Race-Conditions |
| Log-Retention | eigener Cron-Job | `argus_run_purge()` Schritt (e) hinzufügen | bestehender stündlicher pg_cron-Job (`17 * * * *`), kein zweiter Job nötig |
| USBNK-Suche mit SQL-Injection-Schutz | String-Konkatenation in RPC | parametrisiertes `ILIKE '%' || p_usbnk || '%'` in security-definer-RPC | PostgreSQL parametrisiert `||`-Konkatenation automatisch sicher |

---

## Common Pitfalls

### Pitfall 1: CR-02-Regression — `is_person`-Tokens im Feld-Exchange

**Was schiefgeht:** `argus_exchange_code` wird aufgerufen mit einem `is_person=true`-Code. Wenn `is_person` nicht abgewiesen wird: ein FLZ-Token (role='flz', is_person=true, is_master=false) würde via `argus_exchange_code` ein JWT mit `is_master=false` und `praesidium_id=null` erzeugen — vermutlich kein direkter Schaden, aber ein Master-Token (role='master', is_person=true) würde `is_master=true` + `praesidium_id=null` erhalten → voller RLS-Zugriff auf alle Daten über den Feld-App-Exchange.

**Warum:** `argus_exchange_code` liest aktuell `is_master` direkt aus `access_tokens` und legt es ins JWT (0014-Zeile 97). Ein Person-Token mit `role='master'` hätte `is_master=false` (weil is_master-Spalte false ist) — ABER ein Person-Token mit Rolle FLZ, der ein `praesidium_id` hat, könnte Patientenzugriff bekommen.

**Wie vermeiden:** `argus_exchange_code` um Guard `if coalesce(v_token.is_person, false) then return jsonb_build_object('error', 'Pro-Person-Code — nur für die Leitungs-Seite gültig'); end if;` ergänzen. Dies ist die erste Änderung in Migration 0015 — BEVOR irgendein is_person-Token existiert.

**Warnsignale:** REST-Negativtest schlägt an: `curl -X POST .../rpc/argus_exchange_code -d '{"code":"<person-code>"}'` sollte Fehler zurückgeben.

### Pitfall 2: `search_path` bei security-definer-Funktionen

**Was schiefgeht:** Eine neue security-definer-Funktion ohne `set search_path` erlaubt einem Angreifer mit `CREATE SCHEMA`-Rechten, eine gleichnamige Funktion in einem eigenen Schema zu platzieren (schema-injection-Angriff).

**Warum:** PostgreSQL löst `public.access_tokens` etc. über den `search_path` auf. Ohne expliziten `set search_path = 'public'` läuft die Funktion mit dem `search_path` des aufrufenden Benutzers.

**Wie vermeiden:** Alle neuen Funktionen tragen `set search_path to 'public'` (RPCs ohne Vault-Zugriff) oder `set search_path to 'public', 'extensions', 'vault'` (Exchange-RPCs). [VERIFIED: alle 0001–0014-Funktionen halten dieses Muster]

### Pitfall 3: `audit_log`-INSERT direkt via anon-Key

**Was schiefgeht:** Wenn `anon` INSERT-Rechte auf `audit_log` hätte, könnte ein Angreifer mit einem gültigen JWT beliebige Einträge (falsche USBNK, falsche Aktionen) schreiben → T4-Audit wäre kompromittiert.

**Warum:** Das `anon`-Grant-Modell in Supabase ist weit offen; RLS schützt SELECT, aber ohne explizite INSERT-Policy würde ein `grant insert ... to anon` direkte Writes erlauben.

**Wie vermeiden:** `grant select on public.audit_log to anon` — KEIN `insert/update/delete`-Grant. INSERT erfolgt ausschließlich über `security definer`-RPCs, die den Caller prüfen. Explizit testen: `curl -X POST .../audit_log -H "Authorization: Bearer <jwt>" -d '{"at":...}'` → HTTP 403.

### Pitfall 4: USBNK im JWT als `null` bei fehlendem Claim

**Was schiefgeht:** `argus_usbnk()` gibt `nullif(..., '')` zurück → `null` wenn der Claim fehlt (Alt-JWTs, Stufe-0-Sessions). T4-Audit-Einträge aus diesen Sessions hätten `usbnk = null` — das ist korrekt und erwartet (Phase 5.1 ergänzt USBNK für Feld-Sessions). ABER: ein RPC, der `argus_usbnk()` aufruft und dann einen Nicht-Null-Check macht, würde fälschlicherweise Feld-Sessions abweisen.

**Wie vermeiden:** `argus_usbnk()` gibt `null` zurück für Stufe-0-Sessions → ist OK. T4-Audit-Einträge aus Phase-5-RPCs haben immer eine USBNK (weil nur über `argus_is_master()`/`argus_is_flz()` erreichbar, die `argus_token_active()` gaten). Feld-App-Aktionen (Phase 5.1) schreiben explizit `usbnk = null` bis SSO.

### Pitfall 5: Master-Bootstrap — erster Stufe-1-Token

**Was schiefgeht:** `argus_master_issue_person` erfordert `argus_is_master()` — also ein gültiges Master-JWT. Aber wer gibt dem ersten Master seinen Pro-Person-Token? Ein Henne-Ei-Problem.

**Lösung:** Der erste Pro-Person-Token für den Master wird direkt über die Supabase-Dashboard-UI oder über einen einmaligen Management-API-Aufruf in `access_tokens` eingetragen (identisch zum bisherigen Master-Bootstrap-Prozess: `INSERT INTO access_tokens (token, short_code, is_master=true, ...)` aus dem Dashboard). Dieser erste Token erhält zusätzlich `is_person=true`, `usbnk='<USBNK-des-Masters>'`, `role='master'`. SELF-HOSTING.md Abschnitt 8 (Master-Bootstrap) muss um diese Anleitung erweitert werden.

### Pitfall 6: `usbnk`-Suche gibt Token-Secrets zurück

**Was schiefgeht:** `argus_master_search_usbnk` könnte versehentlich die `token`-Spalte (das Geheim-Token) zurückgeben.

**Wie vermeiden:** SELECT-Liste in der Suche: `short_code, usbnk, role, revoked, praesidium_id, created_at, label` — NIEMALS `token`. Explizit testen.

### Pitfall 7: FLZ-Claim `is_flz` interagiert nicht mit bestehenden RLS-Policies

**Was schiefgeht:** FLZ-User sollen die Lageansicht sehen, aber (wie Admin) KEINE Patientenrows. Wenn `is_flz=true` in einem JWT steht und `argus_praesidium_id()` null ist (empfohlenes Design), verweigern alle bestehenden RLS-Policies Roh-Zugriff auf patients/ccps/checklists — korrekt. FLZ nutzt nur `argus_lage()` (security definer).

**Konkret:** `argus_lage()` muss um einen FLZ-Zweig analog dem Admin-Zweig (0013) erweitert werden — oder FLZ nutzt direkt den Observer-Exchange + Observer-Token. Empfehlung: FLZ = eigener Token-Typ (`is_flz=true` + `praesidium_id=null` für alle Präsidien), eigener `argus_exchange_person_code`-Zweig für FLZ-JWTs, `argus_lage()` erweitert um FLZ-Zweig (FLZ sieht alle Präsidien ohne Einschränkung auf ein Präsidium). [ASSUMED — Planner muss FLZ-Scope (ein Präsidium vs. alle) mit Owner bestätigen]

---

## Code Examples

### Existing: `argus_token_active()` — jti-Gate-Fundament

```sql
-- Source: Codebase 0009 (aktuelle Live-Fassung)
-- Prüft jti-Claim gegen revoked + expires_at.
-- Alle neuen Claim-Helfer MÜSSEN dies gaten.
create or replace function public.argus_token_active()
  returns boolean language plpgsql stable security definer
  set search_path to 'public'
as $function$
declare v_jti text; v_tok record;
begin
  v_jti := nullif(current_setting('request.jwt.claims', true)::json->>'jti', '');
  if v_jti is null then return true; end if;  -- Alt-JWT: Übergangsgnade
  select revoked, expires_at into v_tok from public.access_tokens where short_code = v_jti;
  if not found then return false; end if;
  if coalesce(v_tok.revoked, false) then return false; end if;
  if v_tok.expires_at is not null
     and v_tok.expires_at <= (extract(epoch from now())*1000)::bigint then return false; end if;
  return true;
end; $function$;
```

### Existing: CR-02-Abweisung-Muster (aus 0014)

```sql
-- Source: Codebase 0014 — MUSS für is_person analog repliziert werden
-- In argus_exchange_code (nach dem observer-Guard):
if coalesce(v_token.is_admin, false) then
  return jsonb_build_object('error', 'Admin-Code — nur für die Leitungs-Seite gültig');
end if;
-- Neu hinzuzufügen (Migration 0015, erster Schritt):
if coalesce(v_token.is_person, false) then
  return jsonb_build_object('error', 'Pro-Person-Code — nur für die Leitungs-Seite gültig');
end if;
```

### Existing: Log-Retention-Erweiterung (Muster für Schritt (e) in `argus_run_purge`)

```sql
-- Source: Codebase 0004 — identisches Muster für audit_log-Retention
delete from public.audit_log
  where at is not null and at <= v_now - 365::bigint * 86400000;
get diagnostics n_alog = row_count;
-- Im Return-JSON additiv ergänzen:
'audit_log_retention', n_alog
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-----------------|--------------|--------|
| Gesperrte Abschnitte „Identitäten" + „Audit-Log" in Leitungs-Seite (Phase-7-Sperrzone) | Jetzt baubar (DSB-Entfall, Owner-Entscheid 2026-06-27) | 2026-06-27 | Beide Sektionen entsperren + befüllen |
| Kein USBNK-Feld in `access_tokens` | `usbnk text` + `is_person boolean` + `role text` auf `access_tokens` | Phase 5 (jetzt) | Rollen-Register im bestehenden Token-Register |
| `governance_log` = einziges Protokoll | `governance_log` (Governance/Foto) + `audit_log` (T4, personenscharf) | Phase 5 (jetzt) | Klare Trennung, append-only durchsetzbar |
| FLZ = nur Beobachter-Rolle (read-only Lage via is_observer) | FLZ = Pro-Person-Token (is_flz=true), eigener JWT-Claim-Helfer | Phase 5 (jetzt) | Personenscharfe FLZ-Session |

**Deprecated/outdated:**
- Die gesperrten Sidebar-Einträge „Identitäten" und „Audit-Log" in der Leitungs-Seite (Zeilen 715–718) müssen entsperrt und mit echten Sektionen ersetzt werden.

---

## Migration-Planung

**Zwei Migrationen empfohlen:**

### Migration 0015 — Identität/Rollen

1. `access_tokens` um `is_person`, `usbnk`, `role` erweitern
2. `praesidien` um `schulungs_zwilling_id` erweitern
3. `argus_is_flz()`, `argus_usbnk()`, `argus_argus_role()` Claim-Helfer anlegen
4. **CR-02: `argus_exchange_code` um `is_person`-Abweisung ergänzen** (BEVOR irgendein is_person-Token existiert)
5. `argus_exchange_person_code` anlegen
6. `argus_master_issue_person` anlegen
7. `argus_master_revoke_person` anlegen
8. `argus_master_search_usbnk` anlegen
9. `governance_log.action`-Kommentar um neue Aktionen erweitern
10. `argus_lage()` um FLZ-Zweig erweitern

### Migration 0016 — T4-Audit

1. `audit_log`-Tabelle anlegen (mit RLS, ohne anon INSERT/UPDATE/DELETE-Grant)
2. `argus_run_purge()` um Schritt (e) `audit_log`-Retention (365 Tage) erweitern
3. `comment on table public.audit_log` mit Aktions-Katalog

**Beide Migrationen:** idempotent (alter add column if not exists, create or replace), via Supabase Management API + ephemerer PAT (kein CLI). Checkpoint: PAT erfragen (Owner-Hinweis: aktuell gültig).

---

## Open Questions (RESOLVED 2026-06-27)

> Alle vier durch Owner-Entscheide / locked decisions geklärt:
> Q1 → **D-12** (FLZ präsidienübergreifend, `praesidium_id=null`) ·
> Q2 → Koexistenz `is_flz`/`is_observer`, kein Merge (im Research bestätigt) ·
> Q3 → **D-13** (Master darf Master ausgeben, im T4 protokolliert; Bootstrap-Insert) ·
> Q4 → **D-11** (kein `expires_at`; Widerruf-only via jti; 30-Tage-JWT-`exp` nur als Bearer-Hygiene).

1. **FLZ-Scope: ein Präsidium oder alle?** — **RESOLVED: D-12** (präsidienübergreifend)
   - Was wir wissen: PHASE7-ROLLENMODELL-DRAFT sagt FLZ sieht „FLZ-/Lageansicht + alles vom normalen User; präsidienübergreifend (durch Protokoll gedeckt)".
   - Was unklar: Bedeutet das `praesidium_id=null` im JWT (sieht alle via Master-ähnlichem Gate) oder ein Array von Präsidien oder ein dynamischer Picker?
   - Empfehlung: Für Phase 5 (nur Leitungs-Seite): `praesidium_id=null` im FLZ-JWT → `argus_lage()` FLZ-Zweig ohne Präsidiums-Filter. Ein FLZ-Person-Token ist immer bundesland-/landesweit. Der Präsidiums-Picker (Phase 5.1) kann das verfeinern.

2. **Wie hängen `is_flz` und `is_observer` zusammen?**
   - `is_observer` (bisheriger FLZ-Beobachter) = anon, geteilter Code, read-only Lage, 24h-JWT.
   - `is_flz` (neuer FLZ-User Stufe 1) = pro-Person, USBNK, read-only Lage + ggf. mehr.
   - Koexistenz: Beide Typen können gleichzeitig existieren. `argus_lage()` sollte FLZ-Zweig ergänzen, Observer-Zweig behalten. Kein Merge.

3. **Soll `argus_master_issue_person` auch Master-Tokens ausgeben können?**
   - Aktuell: Der erste Master-Token wird manuell eingetragen (Bootstrap-Prozess). Weitere Master-Tokens könnten über denselben RPC ausgegeben werden — aber dann darf ein Master einen weiteren Master ernennen, was eine Eskalationsebene erzeugt.
   - Empfehlung: `role='master'` in der RPC erlauben, aber im Audit-Log explizit protokollieren (action='person_issue', detail='role=master'). Planner soll Owner bestätigen.

4. **TTL für Pro-Person-Tokens (FLZ/Master)?**
   - Bestehend: Master-Tokens haben 30 Tage (0001-Fassung). FLZ-Tokens sollten ähnlich sein (nicht 24h wie Gast/Admin — die Person hat sich authentifiziert).
   - Empfehlung: 30 Tage auch für FLZ/Master, kein `expires_at`. Widerruf über `revoked=true` (jti-Sofortsperre). Owner kann anders entscheiden.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase Management API + PAT | Migration apply | ✓ (Owner-Hinweis: PAT gültig) | — | — |
| `extensions.sign()` (pgjwt) | Exchange-RPC | ✓ (Live seit 0001) | — | — |
| `vault.decrypted_secrets` | Exchange-RPC | ✓ (Live seit 0001) | — | — |
| `pg_cron` Job `argus_purge` | Purge-Erweiterung Schritt (e) | ✓ (Live seit 0002) | `17 * * * *` | App-Start-Aufruf (eingebaut) |
| `extensions.gen_random_bytes` | Short-Code-Generierung | ✓ (Live seit 0013) | — | — |

**Missing dependencies with no fallback:** keine.

---

## Validation Architecture

> Nyquist-Validation-Flag in `.planning/config.json` nicht gesetzt → als aktiviert behandelt.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Kein test runner; Projektkonvention = REST-Direkttests via `curl` + JavaScriptCore (`osascript -l JavaScript`) für Logiktests |
| Config file | none |
| Quick run command | `curl -s -X POST "https://<ref>.supabase.co/rest/v1/rpc/<fn>" -H "apikey: <anon>" -H "Authorization: Bearer <jwt>" -d '<body>'` |
| Full suite command | Alle REST-Positiv-/Negativtests sequenziell (Muster aus 4.12/4.14-SUMMARY) |

### Phase Requirements → Test Map

| Req | Verhalten | Testtyp | Automatisierbar | Notiz |
|-----|-----------|---------|-----------------|-------|
| D-02 USBNK-only | JWT enthält `usbnk`-Claim, kein Klarname | REST-Positiv | `curl` + `jq` auf JWT-Payload | Einfach |
| D-05 Koexistenz | `argus_exchange_code` weist `is_person=true`-Code ab | REST-Negativ | curl | Pflicht (CR-02-Extension) |
| D-05 Koexistenz | `argus_exchange_person_code` weist Nicht-Person-Code ab | REST-Negativ | curl | Pflicht |
| D-07 append-only | `anon`-Key kann kein direktes INSERT auf `audit_log` | REST-Negativ | curl | Pflicht |
| D-07 append-only | `anon`-Key kann kein UPDATE/DELETE auf `audit_log` | REST-Negativ | curl | Pflicht |
| D-07 12-Monats-Retention | `argus_run_purge()` löscht `audit_log`-Rows > 365 Tage | Funktionstst | Muster aus 04.10-01-SUMMARY | Synthetische Alt-Rows |
| Privilege-Escalation | Person-Code mit `role='master'` über `argus_exchange_code` → Fehler | REST-Negativ | curl | CR-02-Extension |
| Privilege-Escalation | FLZ-JWT auf `patients`-Tabelle → leer (RLS verweigert) | REST-Negativ | curl | Analog 4.12-Negativtests |
| Privilege-Escalation | Master-Issue-RPC mit Gast-JWT → Exception | REST-Negativ | curl | Analog 4.14 Guard-Tests |
| jti-Sofortsperre | Person-Token sperren → nächster API-Call mit vorherigem JWT schlägt fehl | REST-Positiv + Negativ | curl | Analog 4.12-Sperrtest |
| USBNK-Suche | Suche gibt Token-Secret `token`-Spalte NICHT zurück | REST-Positiv | curl + `jq 'has("token")'` | Pflicht |
| T4-Login-Audit | Exchange-RPC schreibt `person_login` in `audit_log` | REST-Positiv | curl + SELECT | Pflicht |

### Wave 0 Gaps

- [ ] REST-Test-Skript für Phase 5 (analog `04.14-01-SUMMARY.md` Abschnitt „REST-Negativtests") — muss in Plan 01 als eigene Aufgabe erscheinen.
- [ ] Synthetischer Alt-Row in `audit_log` für Retention-Test (wie 04.10-01 für governance_log).

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | ja — Token-Ausgabe + Exchange | security-definer-RPC + jti-Sofortsperre |
| V3 Session Management | ja — JWT TTL + Revoke | `argus_token_active()` Gate |
| V4 Access Control | ja — Privilege-Escalation-Schutz | CR-02-Abweisung in jedem Exchange-RPC |
| V5 Input Validation | ja — USBNK + Rolle als Eingabe | explizite Whitelist-Prüfung in issue-RPC |
| V6 Cryptography | ja (vererbend) | `extensions.sign()` — niemals hand-rollen |
| V7 Error Handling | ja | generische Fehlermeldungen (kein DB-Stacktrace in JWT) |
| V8 Data Protection | ja — USBNK ist personenbeziehbar | kein Klarname, USBNK nur in audit_log + JWT |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Privilege-Escalation via falschen Exchange | Elevation of Privilege | `is_person`-Abweisung in `argus_exchange_code` (CR-02-Extension) |
| Fremd-Präsidiums-Eskalation (Admin-Token) | Elevation of Privilege | Scope-Prüfung in issue-RPCs (p_praesidium_id == eigenes) |
| Audit-Log-Fälschung | Tampering | Kein anon INSERT/UPDATE/DELETE-Grant; nur security-definer-INSERT |
| USBNK-Disclosure via Suche | Information Disclosure | SELECT-Liste ohne `token`-Spalte; RLS Master-only |
| Schema-Injection via search_path | Elevation of Privilege | `set search_path` in ALLEN neuen security-definer-Funktionen |
| Replay eines widerrufenen JWTs | Elevation of Privilege | `argus_token_active()` prüft jti; Sofortsperre |
| Master gibt sich selbst höhere Rechte | Elevation of Privilege | Audit-Log schreibt actor-USBNK; `role='master'`-Issue explizit protokolliert |

---

## Project Constraints (from CLAUDE.md)

- **Keine nativen `alert/confirm/prompt`:** iOS deaktiviert diese im PWA-Vollbildmodus. Stattdessen `confirmModal()` / `promptModal()` in der Leitungs-Seite. *(Gilt für alle Leitungs-Seite-UI-Änderungen.)*
- **D-06 Geheimhaltung Dateiname:** Der konkrete Dateiname der Leitungs-Seite darf NICHT in committete Texte. Alle Code-Änderungen referenzieren sie als `docs/leitung-*.html` (Glob). D-06-Gate (`git grep -cE 'leitung-[0-9a-f]{6,}'`) vor jedem Commit.
- **Nur USBNK, keine Klarnamen** (D-02): keine `name`-, `vorname`-, `nachname`-Spalten in neuen Tabellen.
- **Local-first:** keine Änderung an der Feld-App (index.html bleibt unangetastet).
- **Datenbank-Konventionen:** bigint-Millisekunden für Zeitstempel (nicht timestamptz), außer bei reinen Server-Protokoll-Tabellen (purge_log.at = timestamptz ist die einzige Ausnahme).
- **DAUERREGEL Training-Drehbuch:** Bei jeder UI-/Funktionsänderung Drehbuch mit-anpassen. Da Phase 5 kein App-Release ist, entfällt das — ABER bei Phase 5.1 gilt es explizit.
- **ARGUS Design-Sprache:** IBM Plex, hell, Schiefer `#1f2530` als Chrome, Triage nur als Funktion. `docs/UI-AUSBLICK.html` ist Referenz-Optik. Alle neuen UI-Elemente in der Leitungs-Seite halten diese Design-Sprache.
- **Supabase-Admin-Workflow:** DDL via Management API + ephemerer PAT; kein CLI; JWT-Exchange als RPC, nicht Edge Function.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | FLZ-Scope = alle Präsidien (`praesidium_id=null` im JWT) | Architecture Patterns / Open Questions | Wenn FLZ nur ein Präsidium sieht: anderes JWT-Claim-Design nötig (admin_praesidium_id-Analog) |
| A2 | TTL für Pro-Person-Tokens = 30 Tage (kein expires_at) | Architecture Patterns | Wenn Owner kürzere TTL will: expires_at-Spalte nutzen, analog Gast-Code |
| A3 | `role='master'` über `argus_master_issue_person` erlaubt (Master kann weiteren Master ernennen) | Architecture Patterns / Open Questions | Wenn Owner das einschränken will: Guard in RPC + eigener Bootstrap-Pfad |

**Alle anderen Befunde in diesem Dokument sind VERIFIED (direkte Codebase-Analyse) oder CITED (Codebase-Kommentare/Migrations-Köpfe).**

---

## Sources

### Primary (MEDIUM confidence via context7; HIGH via direkte Codebase-Analyse)

- Codebase `supabase/migrations/0000_base_schema.sql` — vollständiges Schema, access_tokens-Aufbau
- Codebase `supabase/migrations/0001_phase4_jwt_rls.sql` — argus_exchange_code Ur-Form, Claim-Helfer, RLS-Policies
- Codebase `supabase/migrations/0005_phase412_lageansicht.sql` — Beobachter-Token + eigener Exchange-RPC (Muster für Phase 5)
- Codebase `supabase/migrations/0007_jti_sofortsperre.sql` — argus_token_active(), jti-Gate-Fundament
- Codebase `supabase/migrations/0009_paket2_gastcode_schulung.sql` — praesidien.schulung, expires_at, argus_token_active v2
- Codebase `supabase/migrations/0013_phase414_admin_rolle.sql` — Admin-Rolle (Muster-Vorlage für FLZ/Person-Tokens)
- Codebase `supabase/migrations/0014_phase414_admin_exchange_hardening.sql` — CR-02-Abweisung (verbindliches Muster)
- Codebase `supabase/migrations/0004_phase410_log_retention.sql` — argus_run_purge, Log-Retention-Muster
- Codebase `supabase/migrations/0002_phase48_datenschutz.sql` — governance_log-Schema
- Codebase `docs/leitung-*.html` (Leitungs-Seite) — bestehende Sektionen, gesperrte Phase-7-Einträge, sessionRole(), Protokoll-Ansicht
- `.planning/PHASE7-ROLLENMODELL-DRAFT.md` — Stufenmodell, SCOPE/IDENTITÄT-Invariante, Rollen-Tabelle
- `.planning/phases/05-identitaeten-audit-stufe1/05-CONTEXT.md` — locked decisions D-01…D-10

### Secondary (LOW confidence — nicht in dieser Session verifiziert)

- PostgreSQL-Dokumentation zu `search_path`-Injection-Risiken bei `SECURITY DEFINER`-Funktionen [ASSUMED] — das Muster ist in der gesamten Codebase konsistent umgesetzt.

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — alle Komponenten direkt aus Codebase-Analyse
- Architecture: HIGH — alle Patterns aus bestehenden Migrations abgeleitet
- Data Model: HIGH — direkte Schema-Analyse (0000–0014)
- T4-Audit-Design: HIGH — aus Codebase-Analyse + CONTEXT.md D-06/D-07
- Pitfalls: HIGH — aus direkter CR-02/0014-Analyse + bestehenden Migrations-Kopf-Kommentaren

**Research date:** 2026-06-27
**Valid until:** 2026-07-27 (30 Tage; Schema-Änderungen in Zwischenmigrationen würden dieses Research veralten lassen)
