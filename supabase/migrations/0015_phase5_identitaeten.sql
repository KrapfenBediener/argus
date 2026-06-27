-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 5 — Stufe-1-Identitäts-Schicht: is_person/usbnk/role, Claim-Helfer,
--            CR-02-Härtung, audit_log-Tabelle, Person-Exchange-RPC,
--            Master-Issue/Revoke/Search-RPCs, argus_lage-FLZ-Zweig
-- ============================================================================
-- Serverseitiger Kern der Identitäts-Schicht (Stufe 1). Muster: Admin-Rolle
-- (0013/0014), abgesichert durch jti-Sofortsperre (0007). Neu:
--
--   * access_tokens: drei neue Spalten (is_person, usbnk, role).
--   * praesidien: schulungs_zwilling_id für den Schema-Link Echt↔Schulung.
--   * Claim-Helfer argus_is_flz() / argus_usbnk() / argus_argus_role(),
--     gated auf argus_token_active() wie 0007 (Sofortsperre).
--   * CR-02-Härtung: argus_exchange_code (Feld-App-Exchange) weist
--     is_person-Codes ab — BEVOR irgendein Person-Token existiert.
--   * append-only audit_log-Tabelle (personenscharf, T4-Audit, 12 Mo).
--     anon: nur SELECT via RLS (argus_is_master). INSERT ausschließlich
--     über security-definer-RPCs — kein direkter anon-Write-Grant (D-07).
--   * argus_exchange_person_code: eigener Exchange für Stufe-1-Tokens.
--     JWT trägt usbnk + rollen-abgeleitete Claims (is_flz/is_master/is_admin)
--     + jti; KEIN Klarname (D-02); technisches exp 30 Tage (D-11).
--   * argus_master_issue_person: Master gibt Pro-Person-Token aus
--     (usbnk + role; alle Boolean-Flags explizit; kein expires_at; D-11/D-13).
--   * argus_master_revoke_person: Master sperrt Pro-Person-Token (revoked=true
--     → jti-Sofortsperre wirkt sofort). Nur is_person-Tokens widerrufbar.
--   * argus_master_search_usbnk: Master sucht USBNK-Token — SELECT-Liste
--     enthält NIEMALS die token-Secret-Spalte.
--   * argus_lage(): FLZ-Zweig ergänzt (präsidienübergreifend, D-12);
--     Observer-/Admin-Zweig byte-gleich beibehalten.
--   * audit_log.action-Kommentar: vollständiger Aktions-Katalog (D-06).
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → 0003_phase49_einsatzprotokoll.sql →
--   0004_phase410_log_retention.sql → 0005_phase412_lageansicht.sql →
--   0006_token_hygiene.sql → 0007_jti_sofortsperre.sql →
--   0008_nummernvergabe.sql → 0009_paket2_gastcode_schulung.sql →
--   0010_lage_ort.sql → 0011_paket3_schulung.sql →
--   0012_kurs_evaluation.sql → 0013_phase414_admin_rolle.sql →
--   0014_phase414_admin_exchange_hardening.sql → dieses Skript (0015).
--
-- Anwendung wie 0001–0014: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — alter table add column if not exists,
-- create or replace, create table if not exists, grant, comment.
-- ============================================================================

-- ── 1) Identitäts-Spalten auf access_tokens ──────────────────────────────────
-- Ausschließlich USBNK-basiert — KEINE Klarnamen (name/vorname/nachname), D-02.
-- is_person: Kennzeichnung eines Pro-Person-Tokens (analog is_admin in 0013).
-- usbnk:     USBNK des Token-Inhabers; null für alle Stufe-0-Tokens.
-- role:      Rolle als text ('master'|'flz'|'admin'|'normal'|null).
--            Text statt enum: Konsistenz mit Codebase (kein enum bisher);
--            idempotente create-or-replace ohne ALTER TYPE möglich.
alter table public.access_tokens add column if not exists is_person boolean not null default false;
alter table public.access_tokens add column if not exists usbnk     text;
alter table public.access_tokens add column if not exists role      text;

-- ── 2) Schema-Link Präsidium ↔ Schulungs-Zwilling ───────────────────────────
-- D-04/Specifics-Punkt 4: normaler Token soll ab Phase 5.1 beide Scopes tragen
-- (Echt-Präsidium + sein Schulungs-Pendant). Nur Datenmodell hier; Nutzung
-- (Picker, zwei Reiter) kommt mit Phase 5.1.
alter table public.praesidien
  add column if not exists schulungs_zwilling_id uuid references public.praesidien(id);

-- ── 3) Claim-Helfer: argus_is_flz / argus_usbnk / argus_argus_role ─────────
-- Muster: argus_is_admin/argus_admin_praesidium_id aus 0013 MIT jti-Gate (0007).
-- Alle language sql stable security definer (identisch zu bestehenden Helfern).
-- Pitfall 2: set search_path in ALLEN security-definer-Funktionen.

-- argus_is_flz(): gated auf argus_token_active() — ein gesperrter FLZ-Code
-- sperrt SOFORT alle FLZ-Operationen (STRIDE T-05-06).
create or replace function public.argus_is_flz()
  returns boolean
  language sql
  stable
  security definer
  set search_path to 'public'
as $$
  select public.argus_token_active()
     and coalesce((current_setting('request.jwt.claims', true)::json->>'is_flz')::boolean, false)
$$;
grant execute on function public.argus_is_flz() to anon;

-- argus_usbnk(): gibt null für Stufe-0/Alt-JWT zurück — korrekt (Pitfall 4).
-- KEIN eigenes jti-Gate: ein leerer/null USBNK-Wert ist bei Stufe-0-Sessions
-- erwartet und unschädlich; der Wert selbst trägt keine Privilegien.
create or replace function public.argus_usbnk()
  returns text
  language sql
  stable
  security definer
  set search_path to 'public'
as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'usbnk', '')
$$;
grant execute on function public.argus_usbnk() to anon;

-- argus_argus_role(): analog argus_usbnk — gibt null zurück wenn kein Claim.
create or replace function public.argus_argus_role()
  returns text
  language sql
  stable
  security definer
  set search_path to 'public'
as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'argus_role', '')
$$;
grant execute on function public.argus_argus_role() to anon;

-- ── 4) CR-02: argus_exchange_code — is_person-Abweisung ─────────────────────
-- BYTE-NAH zur 0014-Live-Fassung; NUR is_person-Guard ergänzt (nach is_admin),
-- is_person in die SELECT-Liste aufgenommen. Sonst kein Verhalten geändert.
--
-- Warum: ein Person-Token mit role='master' (is_person=true, is_master=false in
-- access_tokens) würde über argus_exchange_code ein Geräte-JWT mit
-- praesidium_id=null und is_master=false erhalten — auf den ersten Blick harmlos.
-- Aber ein Person-Token mit role='flz' (praesidium_id gesetzt) würde ein JWT mit
-- praesidium_id und is_master=false erhalten — und über die RLS-Policies hätte
-- er vollen Lese-/Schreibzugriff auf Patienten/CCPs. Das ist Privilege-Escalation
-- (STRIDE T-05-01). Abweisung BEVOR irgendein is_person-Token existiert.
create or replace function public.argus_exchange_code(code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions', 'vault'
as $function$
declare
  v_clean       text;
  v_short_code  text;
  v_token       record;
  v_ttl_secs    int;
  v_now         int;
  v_exp         int;
  v_jwt         text;
  v_jwt_secret  text;
  v_pname       text;
begin
  v_clean := upper(regexp_replace(code, '[\s\-]', '', 'g'));
  if length(v_clean) < 8 then
    return jsonb_build_object('error', 'Code zu kurz');
  end if;
  v_short_code := substring(v_clean,1,4) || '-' || substring(v_clean,5,4);

  -- is_admin und is_person zusätzlich lesen (CR-02 / CR-02-Extension).
  select praesidium_id, is_master, ttl_hours, single_use, used_at, revoked, observer, gast, expires_at, is_admin, is_person
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  if coalesce(v_token.observer, false) then
    return jsonb_build_object('error', 'Beobachter-Code — nur für die Lageansicht gültig');
  end if;
  -- CR-02 (0014): Admin-Codes gehören NICHT in die Feld-App.
  if coalesce(v_token.is_admin, false) then
    return jsonb_build_object('error', 'Admin-Code — nur für die Leitungs-Seite gültig');
  end if;
  -- CR-02-Extension (0015): Pro-Person-Codes gehören NICHT in die Feld-App.
  -- Ein Person-Code hier eingelöst würde ein Geräte-JWT erzeugen und könnte
  -- über RLS Patientenzugriff erlangen (Privilege-Escalation, STRIDE T-05-01).
  if coalesce(v_token.is_person, false) then
    return jsonb_build_object('error', 'Pro-Person-Code — nur für die Leitungs-Seite gültig');
  end if;
  if v_token.expires_at is not null
     and v_token.expires_at <= (extract(epoch from now())*1000)::bigint then
    return jsonb_build_object('error', 'Code abgelaufen');
  end if;
  if v_token.single_use and v_token.used_at is not null then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;

  v_now := extract(epoch from now())::int;
  v_ttl_secs := case
    when v_token.is_master then 30*24*3600
    when coalesce(v_token.gast, false) then 24*3600
    when v_token.ttl_hours is not null then v_token.ttl_hours*3600
    else 30*24*3600 end;
  v_exp := v_now + v_ttl_secs;

  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret'
  limit 1;

  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  v_jwt := extensions.sign(
    json_build_object(
      'iss', 'supabase',
      'sub', 'argus-device',
      'role', 'anon',
      'praesidium_id', v_token.praesidium_id,
      'is_master', coalesce(v_token.is_master, false),
      'jti', v_short_code,
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  if v_token.single_use and v_token.used_at is null then
    -- used_at ist bigint (JS-Millisekunden), NICHT timestamptz (42804!).
    update public.access_tokens
    set used_at = (extract(epoch from now())*1000)::bigint
    where short_code = v_short_code and used_at is null;
  end if;

  -- Gast-Einlösung protokollieren (aus 0014 beibehalten).
  if coalesce(v_token.gast, false) then
    insert into public.governance_log (at, kuerzel, action)
      values ((extract(epoch from now())*1000)::bigint, v_short_code, 'gast_join');
  end if;

  if v_token.praesidium_id is not null then
    select name into v_pname from public.praesidien
    where id = v_token.praesidium_id;
  end if;

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'praesidium_id',   v_token.praesidium_id,
    'praesidium_name', v_pname,
    'is_master',       coalesce(v_token.is_master, false),
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;
grant execute on function public.argus_exchange_code(text) to anon;

-- ── 5) audit_log-Tabelle (append-only, T4-Audit, D-07) ──────────────────────
-- NICHT governance_log erweitern (andere Semantik, andere Consumer, Pattern 3).
-- bigint-Millisekunden-Konvention (identisch governance_log) für at-Spalte.
-- Append-only-Durchsetzung: anon erhält AUSSCHLIESSLICH SELECT (RLS-gated).
-- KEIN grant insert/update/delete an anon (deliberate omission, D-07/Pitfall 3).
-- INSERT nur über security-definer-RPCs aus diesem Skript.
create table if not exists public.audit_log (
  id            uuid    primary key default gen_random_uuid(),
  at            bigint  not null,        -- JS-Millisekunden (Konvention aus 0002)
  usbnk         text,                    -- null bei Stufe-0-Aktionen (bis Phase 5.1)
  action        text    not null,        -- s. Aktions-Katalog (comment on column unten)
  ccp_id        uuid,
  patient_id    text,
  praesidium_id uuid,
  detail        text                     -- optionaler Freitext
);

-- SELECT für anon — RLS-gated auf Master-JWT (argus_is_master).
-- KEIN insert/update/delete-Grant an anon (append-only-Enforcement, D-07).
grant select on public.audit_log to anon;

alter table public.audit_log enable row level security;

drop policy if exists argus_audit_log_select on public.audit_log;
create policy "argus_audit_log_select"
  on public.audit_log
  for select
  to anon
  using ( public.argus_is_master() );

-- ── 6) argus_exchange_person_code ────────────────────────────────────────────
-- Eigener Exchange für Stufe-1-Pro-Person-Tokens (analog argus_exchange_admin_code).
-- Normalisierung identisch allen anderen Exchanges (upper + regexp_replace,
-- short_code-Split, length<8-Guard).
-- JWT trägt: usbnk, argus_role, rollen-abgeleitete Claims (is_master/is_flz/is_admin),
-- praesidium_id (FLZ/Master: null — präsidienübergreifend, D-12;
--              Admin: v_token.praesidium_id), admin_praesidium_id (nur für role='admin'),
-- jti, iat, exp (technisches 30-Tage-Bearer-exp, D-11).
-- KEIN Klarname im JWT (D-02). KEIN expires_at-getriebenes Ablaufen (D-11).
-- Zwangs-Log VOR Rückgabe: audit_log action='person_login' (D-13/STRIDE T-05-08).
-- CR-02-Spiegel: weist alle Nicht-Person-Codes (is_person=false) ab.
create or replace function public.argus_exchange_person_code(code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions', 'vault'
as $function$
declare
  v_clean       text;
  v_short_code  text;
  v_token       record;
  v_now         int;
  v_exp         int;
  v_ttl_secs    int;
  v_jwt         text;
  v_jwt_secret  text;
  v_pname       text;
begin
  -- Normalisierung identisch allen anderen Exchanges.
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
  -- CR-02-Spiegel: weist alle Nicht-Person-Codes ab (D-05/STRIDE T-05-02).
  if not coalesce(v_token.is_person, false) then
    return jsonb_build_object('error', 'Kein Pro-Person-Code');
  end if;
  -- Defensiv: Person-Tokens setzen normalerweise kein expires_at (D-11),
  -- aber falls doch gesetzt — prüfen (konsistent zu allen anderen Exchanges).
  if v_token.expires_at is not null
     and v_token.expires_at <= (extract(epoch from now())*1000)::bigint then
    return jsonb_build_object('error', 'Code abgelaufen');
  end if;

  v_now      := extract(epoch from now())::int;
  v_ttl_secs := 30*24*3600;   -- technisches Bearer-exp 30 Tage (D-11)
  v_exp      := v_now + v_ttl_secs;

  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret'
  limit 1;

  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  -- JWT-Payload: rollen-abgeleitete Claims analog 0005/0013-Muster.
  -- FLZ/Master: praesidium_id=null (präsidienübergreifend, D-12).
  -- Admin: praesidium_id + admin_praesidium_id gesetzt.
  -- sub='argus-person' (eigene Kennung, nicht 'argus-device').
  -- KEIN Klarname-Claim (D-02).
  v_jwt := extensions.sign(
    json_build_object(
      'iss',                'supabase',
      'sub',                'argus-person',
      'role',               'anon',
      'usbnk',              v_token.usbnk,
      'argus_role',         v_token.role,
      'is_master',          (v_token.role = 'master'),
      'is_flz',             (v_token.role = 'flz'),
      'is_admin',           (v_token.role = 'admin'),
      'praesidium_id',      case when v_token.role in ('master', 'flz')
                                 then null
                                 else v_token.praesidium_id end,
      'admin_praesidium_id', case when v_token.role = 'admin'
                                  then v_token.praesidium_id
                                  else null end,
      'jti',                v_short_code,
      'iat',                v_now,
      'exp',                v_exp
    ),
    v_jwt_secret
  );

  -- Zwangs-Log VOR Rückgabe (D-13, STRIDE T-05-08): person_login mit USBNK.
  insert into public.audit_log (at, usbnk, action, praesidium_id)
    values ((extract(epoch from now())*1000)::bigint,
            v_token.usbnk, 'person_login', v_token.praesidium_id);

  -- Präsidiumsname (nur wenn praesidium_id gesetzt).
  if v_token.praesidium_id is not null then
    select name into v_pname from public.praesidien
    where id = v_token.praesidium_id;
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

-- ── 7) argus_master_issue_person ─────────────────────────────────────────────
-- Master gibt Pro-Person-Token aus (analog argus_admin_issue_gast in 0013).
-- Guard: argus_is_master() — unprivilegierte JWTs → Exception (STRIDE T-05-03).
-- Alle Boolean-Flags explizit false — verhindert versehentliche Privilegien
-- (Anti-Pattern aus 05-RESEARCH).
-- KEIN expires_at (D-11: Person-Tokens laufen nicht ab).
-- Zwangs-Log: audit_log action='person_issue' mit actor-USBNK (D-13).
-- role='master' ist ERLAUBT (D-13: Master darf weiteren Master ernennen).
create or replace function public.argus_master_issue_person(
  p_usbnk        text,
  p_role         text,
  p_praesidium_id uuid,
  p_label        text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions'
as $function$
declare
  -- Verwechslungssicheres Alphabet ohne 0/O/1/I (identisch 0013)
  v_alphabet    text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_short_code  text;
  v_token       text;
  v_now_ms      bigint;
  v_part1       text;
  v_part2       text;
  v_attempt     int := 0;
  v_exists      boolean;
  v_actor_usbnk text;
begin
  -- Guard: Nur Master-JWT darf Person-Tokens ausgeben (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- Eingabe-Validierung.
  if p_usbnk is null or btrim(p_usbnk) = '' then
    raise exception 'USBNK erforderlich';
  end if;
  if p_role not in ('master', 'flz', 'admin', 'normal') then
    raise exception 'Ungültige Rolle';
  end if;
  -- Admin-Tokens müssen präsidiumsgebunden sein.
  if p_role = 'admin' and p_praesidium_id is null then
    raise exception 'Admin-Token erfordert Präsidium';
  end if;

  v_actor_usbnk := public.argus_usbnk();   -- USBNK des ausstellenden Masters
  v_now_ms      := (extract(epoch from now())*1000)::bigint;
  v_token       := encode(extensions.gen_random_bytes(16), 'hex');

  -- Short-Code: Kollisions-Schleife, identisch argus_admin_issue_gast (0013).
  loop
    v_attempt := v_attempt + 1;
    if v_attempt > 10 then
      raise exception 'Short-Code-Kollision — bitte erneut versuchen';
    end if;
    v_part1 := '';
    v_part2 := '';
    for i in 1..4 loop
      v_part1 := v_part1 || substr(v_alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    for i in 1..4 loop
      v_part2 := v_part2 || substr(v_alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    v_short_code := v_part1 || '-' || v_part2;
    select exists(
      select 1 from public.access_tokens where short_code = v_short_code
    ) into v_exists;
    exit when not v_exists;
  end loop;

  -- INSERT: alle Boolean-Flags explizit false (Anti-Pattern-Schutz).
  -- KEIN expires_at (D-11: kein zeitliches Ablaufen für Person-Tokens).
  insert into public.access_tokens (
    token, short_code, praesidium_id,
    is_person, usbnk, role,
    is_master, is_admin, observer, gast, single_use, temporary,
    ttl_hours, label
  ) values (
    v_token, v_short_code, p_praesidium_id,
    true, btrim(p_usbnk), p_role,
    false, false, false, false, false, false,
    null, btrim(coalesce(p_label, ''))
  );

  -- Zwangs-Log: person_issue mit actor-USBNK (D-13, STRIDE T-05-08).
  -- role='master'-Ausgaben werden explizit im detail-Feld protokolliert (D-13).
  insert into public.audit_log (at, usbnk, action, praesidium_id, detail)
    values (v_now_ms, v_actor_usbnk, 'person_issue', p_praesidium_id,
            'role=' || p_role || ' target=' || btrim(p_usbnk));

  return jsonb_build_object('short_code', v_short_code);
end;
$function$;
grant execute on function public.argus_master_issue_person(text, text, uuid, text) to anon;

-- ── 8) argus_master_revoke_person ────────────────────────────────────────────
-- Master sperrt Pro-Person-Token (revoked=true → jti-Sofortsperre wirkt sofort).
-- Guard: argus_is_master() — unprivilegierte JWTs → Exception (STRIDE T-05-03).
-- Nur is_person-Tokens widerrufbar (schützt vor versehentlichem Sperren anderer
-- Token-Arten; z. B. Gast-Codes, Observer-Codes liegen in anderen RPCs).
-- Zwangs-Log: audit_log action='person_revoke' mit actor-USBNK (D-13).
create or replace function public.argus_master_revoke_person(p_short_code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_target record;
begin
  -- Guard: Nur Master-JWT darf Person-Tokens sperren (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- Zielcode laden.
  select is_person, usbnk, praesidium_id
  into v_target
  from public.access_tokens
  where short_code = p_short_code;

  if not found then
    raise exception 'Code nicht gefunden';
  end if;

  -- Nur Pro-Person-Tokens widerrufbar (STRIDE T-05-03).
  if not coalesce(v_target.is_person, false) then
    raise exception 'Nur Pro-Person-Tokens widerrufbar';
  end if;

  -- Sperren: revoked=true → argus_token_active() liefert false → jti-Sofortsperre.
  update public.access_tokens
  set revoked = true
  where short_code = p_short_code;

  -- Zwangs-Log: person_revoke mit actor-USBNK + Ziel-USBNK im detail (D-13).
  insert into public.audit_log (at, usbnk, action, praesidium_id, detail)
    values ((extract(epoch from now())*1000)::bigint,
            public.argus_usbnk(), 'person_revoke', v_target.praesidium_id,
            'target=' || coalesce(v_target.usbnk, ''));

  return jsonb_build_object('revoked', true);
end;
$function$;
grant execute on function public.argus_master_revoke_person(text) to anon;

-- ── 9) argus_master_search_usbnk ─────────────────────────────────────────────
-- Master sucht Pro-Person-Tokens nach USBNK-Fragment (ILIKE, Partial-Match).
-- Guard: argus_is_master() — unprivilegierte JWTs → Exception (STRIDE T-05-03).
-- SELECT-Liste enthält NIEMALS die token-Secret-Spalte (STRIDE T-05-04/Pitfall 6).
-- Parametrisiertes ILIKE via ||-Konkatenation (injection-sicher, Don't-Hand-Roll).
-- Rückgabe: jsonb_agg (leeres Array statt null wenn keine Treffer).
-- Optional: praesidium_name per Subselect.
create or replace function public.argus_master_search_usbnk(p_usbnk text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_result jsonb;
begin
  -- Guard: Nur Master-JWT darf USBNK-Suche durchführen (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- SELECT: kurze, sichere Spalten-Liste; NIEMALS die token-Secret-Spalte.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'short_code',      a.short_code,
        'usbnk',           a.usbnk,
        'role',            a.role,
        'revoked',         coalesce(a.revoked, false),
        'praesidium_id',   a.praesidium_id,
        'praesidium_name', (select p.name from public.praesidien p where p.id = a.praesidium_id),
        'created_at',      a.created_at,
        'label',           a.label
      )
      order by a.usbnk
    ),
    '[]'::jsonb
  )
  into v_result
  from public.access_tokens a
  where a.is_person = true
    and a.usbnk ilike '%' || p_usbnk || '%';

  return v_result;
end;
$function$;
grant execute on function public.argus_master_search_usbnk(text) to anon;

-- ── 10) argus_lage(): FLZ-Zweig hinzufügen ───────────────────────────────────
-- Basis = aktuelle 0013-Fassung mit Observer-/Admin-Zweig (byte-gleicher Feldsatz).
-- Erweiterung: FLZ ist präsidienübergreifend (D-12): KEIN Präsidiums-Filter,
-- alle offenen CCPs aller Präsidien werden aggregiert.
-- Observer-/Admin-Zweige bleiben unverändert (eigenes Präsidium).
-- Pitfall 7: FLZ trägt praesidium_id-Claim null → bestehende RLS verweigert
-- Roh-Patientenzugriff; FLZ nutzt nur argus_lage().
create or replace function public.argus_lage()
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_pid   uuid;
  v_pname text;
  v_ccps  jsonb;
begin
  -- Eingangs-Guard: Observer, Admin oder FLZ (jeder auf seinen Scope begrenzt).
  -- FLZ darf hier rein (D-12: präsidienübergreifend).
  if not (public.argus_is_observer()
          or public.argus_is_admin()
          or public.argus_is_flz()) then
    raise exception 'Nur mit Beobachter-, Admin- oder FLZ-Zugang';
  end if;

  -- ── FLZ-Zweig: präsidienübergreifend (D-12) ─────────────────────────────
  -- FLZ trägt praesidium_id=null im JWT → argus_praesidium_id() liefert null.
  -- Kein Präsidiums-Filter: alle offenen CCPs aller Präsidien aggregieren.
  if public.argus_is_flz() then
    select coalesce(jsonb_agg(jsonb_build_object(
             'kennung',        c.kennung,
             'ort',            c.ort,
             'lat',            c.geo_lat,
             'lng',            c.geo_lng,
             'verbund',        (c.merge_group_id is not null),
             'verbund_gruppe', c.merge_group_id,
             'praesidium_id',  c.praesidium_id,
             'praesidium_name',(select p.name from public.praesidien p where p.id = c.praesidium_id),
             't1',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'active' and pt.cat = 'T1'),
             't2',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'active' and pt.cat = 'T2'),
             't3',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'active' and pt.cat = 'T3'),
             't5',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'active' and pt.cat = 'T5'),
             'gpa',   (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'gpa'),
             'prio',  (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'active' and pt.prio),
             'ready', (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.status = 'active' and pt.ready),
             'letzte_aenderung', (select max(pt.updated) from public.patients pt where pt.ccp_id = c.id)
           ) order by c.kennung), '[]'::jsonb)
    into v_ccps
    from public.ccps c
    where c.closed_at is null;  -- KEIN Präsidiums-Filter für FLZ

    return jsonb_build_object(
      'praesidium_name', null,   -- FLZ: kein eigenes Präsidium
      'stand',           (extract(epoch from now())*1000)::bigint,
      'ccps',            v_ccps
    );
  end if;

  -- ── Observer-/Admin-Zweig: eigenes Präsidium (0013-Fassung byte-gleich) ──
  if coalesce(public.argus_observer_praesidium_id(),
              public.argus_admin_praesidium_id()) is null then
    raise exception 'Nur mit Beobachter- oder Admin-Zugang';
  end if;

  v_pid := coalesce(public.argus_observer_praesidium_id(),
                    public.argus_admin_praesidium_id());

  select name into v_pname from public.praesidien where id = v_pid;

  select coalesce(jsonb_agg(jsonb_build_object(
           'kennung', c.kennung,
           'ort',     c.ort,
           'lat',     c.geo_lat,
           'lng',     c.geo_lng,
           'verbund', (c.merge_group_id is not null),
           'verbund_gruppe', c.merge_group_id,
           't1',    (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'active' and p.cat = 'T1'),
           't2',    (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'active' and p.cat = 'T2'),
           't3',    (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'active' and p.cat = 'T3'),
           't5',    (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'active' and p.cat = 'T5'),
           'gpa',   (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'gpa'),
           'prio',  (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'active' and p.prio),
           'ready', (select count(*) from public.patients p where p.ccp_id = c.id and p.status = 'active' and p.ready),
           'letzte_aenderung', (select max(p.updated) from public.patients p where p.ccp_id = c.id)
         ) order by c.kennung), '[]'::jsonb)
  into v_ccps
  from public.ccps c
  where c.praesidium_id = v_pid
    and c.closed_at is null;

  return jsonb_build_object(
    'praesidium_name', v_pname,
    'stand',           (extract(epoch from now())*1000)::bigint,
    'ccps',            v_ccps
  );
end;
$function$;
grant execute on function public.argus_lage() to anon;

-- ── 11) audit_log.action: Vollständiger Aktions-Katalog (D-06) ───────────────
-- Phase-5-Scope (jetzt schreibend): person_login, person_issue, person_revoke,
--   person_role_change, governance_abruf.
-- Phase-5.1-Scope (Feld-App, kommen dann zum Schreiben):
--   patient_create, patient_cat_change, patient_ready, patient_checkout,
--   patient_photo, ccp_open, ccp_close, ccp_merge.
-- Katalog vollständig dokumentiert, damit Downstream-Konsumenten den Wertebereich kennen.
comment on column public.audit_log.action is
  'person_login | person_issue | person_revoke | person_role_change | governance_abruf | patient_create | patient_cat_change | patient_ready | patient_checkout | patient_photo | ccp_open | ccp_close | ccp_merge';
