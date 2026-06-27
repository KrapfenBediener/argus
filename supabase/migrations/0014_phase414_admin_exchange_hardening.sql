-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 0014 — Phase 4.14: Härtung der Code-Exchange-Pfade (Admin-Rolle)
-- ─────────────────────────────────────────────────────────────────────────────
-- Zweck (Befunde aus dem Phasen-04.14-Code-Review):
--   * CR-02 (kritisch, Privilege-Escalation): argus_exchange_code (der Feld-App-
--     Exchange) wies bisher Beobachter-Codes ab, aber NICHT is_admin-Codes. Ein
--     präsidiumsgebundener Admin-Code (is_admin=true, praesidium_id gesetzt) ließ
--     sich darüber gegen ein NORMALES Geräte-JWT mit praesidium_id eintauschen —
--     und erhielt damit über die bestehenden RLS-Policies (praesidium_id =
--     argus_praesidium_id()) vollen Lese-/Schreibzugriff auf Patienten/CCPs/
--     Checklisten des Präsidiums. Das unterläuft die Datenisolation der Admin-Rolle
--     (STRIDE T-0414-04: ein Admin darf KEINE Patientendaten erhalten). Fix: einen
--     is_admin-Abweisungszweig analog zum bestehenden observer-Zweig ergänzen.
--   * CR-01 (Defense-in-Depth/Konsistenz): argus_exchange_admin_code las expires_at,
--     erzwang es aber nicht. Andere Exchanges (argus_exchange_code, 0009) prüfen
--     expires_at. Fix: denselben expires_at-Guard im Admin-Exchange ergänzen.
--
-- Beide Funktionen werden BYTE-NAH zur Live-Fassung (0009 bzw. 0013) neu gefasst —
-- es kommen NUR die Guards hinzu (kein sonstiges Verhalten ändert sich).
--
-- Reihenfolge: 0000 → … → 0012 → 0013 → dieses Skript (0014).
-- Anwendung: Supabase Management API (POST /v1/projects/{ref}/database/query),
--            ephemerer PAT. KEIN CLI.
-- Idempotenz: reine create-or-replace — mehrfaches Anwenden ist unschädlich.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1) CR-02: argus_exchange_code — is_admin-Codes im Feld-App-Exchange abweisen ──
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

  -- is_admin zusätzlich lesen (CR-02).
  select praesidium_id, is_master, ttl_hours, single_use, used_at, revoked, observer, gast, expires_at, is_admin
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
  -- CR-02: Admin-Codes gehören NICHT in die Feld-App. Sie sind reine Leitungs-
  -- Seiten-Credentials (eigener Exchange argus_exchange_admin_code). Ohne diese
  -- Abweisung würde ein Admin-Code hier ein Geräte-JWT mit praesidium_id erhalten
  -- und über RLS vollen Patientenzugriff erlangen (Privilege-Escalation).
  if coalesce(v_token.is_admin, false) then
    return jsonb_build_object('error', 'Admin-Code — nur für die Leitungs-Seite gültig');
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

  -- Gast-Einlösung protokollieren — eine Zeile je Einlösung (Owner-Entscheid:
  -- nachvollziehbar, wer sich über den Tafel-/Funk-Code freigeschaltet hat;
  -- Personenzuordnung organisatorisch via Meldekopf/Kürzel-Disziplin).
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

-- ── 2) CR-01: argus_exchange_admin_code — expires_at erzwingen ─────────────────
create or replace function public.argus_exchange_admin_code(code text)
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

  select praesidium_id, ttl_hours, revoked, is_admin, expires_at
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  if not coalesce(v_token.is_admin, false) then
    return jsonb_build_object('error', 'Kein Admin-Code');
  end if;
  if v_token.praesidium_id is null then
    -- Ein Admin-Code MUSS präsidiumsgebunden sein.
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;
  -- CR-01: expires_at erzwingen (Konsistenz zu argus_exchange_code/0009).
  if v_token.expires_at is not null
     and v_token.expires_at <= (extract(epoch from now())*1000)::bigint then
    return jsonb_build_object('error', 'Code abgelaufen');
  end if;

  v_now := extract(epoch from now())::int;
  v_ttl_secs := case
    when v_token.ttl_hours is not null then v_token.ttl_hours*3600
    else 24*3600 end;
  v_exp := v_now + v_ttl_secs;

  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret'
  limit 1;

  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  -- EIGENE Claim-Form: is_admin + admin_praesidium_id (vgl. is_observer/
  -- observer_praesidium_id in 0005/0007), plus jti für Sofort-Sperrung.
  -- BEWUSST KEIN praesidium_id- und KEIN is_master-Claim — dadurch liefern
  -- argus_praesidium_id()/argus_is_master() null/false → alle bestehenden
  -- RLS-Policies verweigern Roh-Zugriff (STRIDE T-0414-04).
  v_jwt := extensions.sign(
    json_build_object(
      'iss',                'supabase',
      'sub',                'argus-admin',
      'role',               'anon',
      'is_admin',           true,
      'admin_praesidium_id', v_token.praesidium_id,
      'jti',                v_short_code,
      'iat',                v_now,
      'exp',                v_exp
    ),
    v_jwt_secret
  );

  select name into v_pname from public.praesidien
  where id = v_token.praesidium_id;

  -- Zwangs-Log VOR der Rückgabe — ein Eintrag je Admin-Login (STRIDE T-0414-06;
  -- 12-Monats-Retention aus 0004 greift).
  insert into public.governance_log (at, kuerzel, action)
    values ((extract(epoch from now())*1000)::bigint, v_short_code, 'admin_login');

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'praesidium_id',   v_token.praesidium_id,
    'praesidium_name', v_pname,
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;
grant execute on function public.argus_exchange_admin_code(text) to anon;
