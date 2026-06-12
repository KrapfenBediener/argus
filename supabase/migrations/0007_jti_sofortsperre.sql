-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Token-Identität (jti) + serverseitige Sofort-Sperrung
-- ============================================================================
-- Owner-Entscheid 2026-06-12 (Chat, Nachverfolgbarkeits-Konzept):
--   * Jedes ausgestellte JWT trägt künftig einen jti-Claim (= short_code des
--     einlösenden Codes). Damit ist jede Server-Operation kryptografisch dem
--     ausgebenden Code zuordenbar (Kette: Aktion → Code → Ausgabe-Liste →
--     Person; Personenzuordnung bleibt organisatorisch — Pseudonymität).
--   * SCHLIESST DIE SPERR-LÜCKE: Bisher verhinderte revoked nur das erneute
--     Einlösen + den App-Re-Check; ein bereits ausgestelltes JWT blieb bis
--     zu seinem exp (bis zu 30 Tage!) direkt gegen die REST-API nutzbar.
--     Jetzt prüfen die Claim-Helfer den jti gegen access_tokens.revoked —
--     eine Sperrung wirkt SOFORT serverseitig, für alle Policies und RPCs,
--     ohne dass eine einzige Policy umgeschrieben werden muss:
--       argus_praesidium_id()  → null  bei gesperrtem/gelöschtem Code
--       argus_is_master()      → false bei gesperrtem/gelöschtem Code
--       argus_is_observer()    → false bei gesperrtem/gelöschtem Code
--   * ABWÄRTSKOMPATIBILITÄT: Alt-JWTs ohne jti-Claim bleiben bis zu ihrem
--     exp gültig (Übergangsgnade, max. 30 Tage ab Anwendung dieser
--     Migration) — kein App-Update nötig, keine Zwangsabmeldung der Flotte.
--     Nach spätestens 30 Tagen tragen alle umlaufenden JWTs einen jti.
--   * Gelöschter Code (z. B. Token-Hygiene 0006) ⇒ jti unauffindbar ⇒ wie
--     gesperrt behandelt (deny). Unkritisch: gelöscht werden nur verbrauchte
--     Einmal-Codes ≥ 6 Monate nach Einlösung — deren 24-h-JWTs sind dann
--     längst abgelaufen.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000 → 0001 → 0002 → 0003 → 0004 → 0005 → 0006 → dieses Skript.
--
-- Anwendung wie 0001–0006: Supabase Management API (POST /v1/projects/
-- {ref}/database/query, Bearer <PAT>). Idempotent — nur create or replace,
-- grant, comment.
--
-- Performance-Hinweis: argus_token_active() macht einen Lookup auf
-- access_tokens (PK-/Unique-Index short_code, Tabelle winzig); die Helfer
-- sind STABLE — innerhalb eines Statements wird nicht je Zeile neu gelesen.
-- Keine RLS-Rekursion: die Helfer sind SECURITY DEFINER (Owner umgeht RLS),
-- obwohl die access_tokens-Policies selbst argus_is_master() verwenden.
-- ============================================================================

-- ── 1) Helfer: ist das vorlegende Token aktiv (nicht gesperrt/gelöscht)? ────
create or replace function public.argus_token_active()
  returns boolean
  language plpgsql
  stable
  security definer
  set search_path to 'public'
as $function$
declare
  v_jti text;
  v_rev boolean;
begin
  v_jti := nullif(current_setting('request.jwt.claims', true)::json->>'jti', '');
  if v_jti is null then
    return true;   -- Alt-JWT ohne jti: Übergangsgnade bis exp (s. Kopf)
  end if;
  select revoked into v_rev from public.access_tokens where short_code = v_jti;
  if not found then
    return false;  -- Code gelöscht → wie gesperrt behandeln
  end if;
  return not coalesce(v_rev, false);
end;
$function$;
grant execute on function public.argus_token_active() to anon;
comment on function public.argus_token_active() is
  'Sofort-Sperrung (0007): prüft den jti-Claim (= short_code) des Request-JWT '
  'gegen access_tokens.revoked. Ohne jti-Claim (Alt-JWT) true; Code gelöscht '
  'oder gesperrt → false. Wird von argus_praesidium_id/argus_is_master/'
  'argus_is_observer konsumiert — dadurch greifen ALLE Policies und RPCs.';

-- ── 2) Claim-Helfer gaten auf argus_token_active() ──────────────────────────
-- Neufassungen von 0001 (praesidium_id, is_master) und 0005 (is_observer);
-- argus_observer_praesidium_id() braucht KEIN Gate — argus_lage prüft
-- argus_is_observer() zuerst, und ohne is_observer ist der Wert wirkungslos.
create or replace function public.argus_praesidium_id()
  returns uuid language sql stable security definer as $$
  select case when public.argus_token_active()
    then nullif(current_setting('request.jwt.claims', true)::json->>'praesidium_id','')::uuid
    else null end
$$;

create or replace function public.argus_is_master()
  returns boolean language sql stable security definer as $$
  select public.argus_token_active()
     and coalesce((current_setting('request.jwt.claims', true)::json->>'is_master')::boolean, false)
$$;

create or replace function public.argus_is_observer()
  returns boolean language sql stable security definer as $$
  select public.argus_token_active()
     and coalesce((current_setting('request.jwt.claims', true)::json->>'is_observer')::boolean, false)
$$;

-- ── 3) argus_exchange_code: Neufassung mit jti-Claim ────────────────────────
-- Identisch zur Fassung aus 0005, plus 'jti' im JWT-Payload. Antwortformat
-- unverändert — kein App-Update nötig.
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

  select praesidium_id, is_master, ttl_hours, single_use, used_at, revoked, observer
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
  if v_token.single_use and v_token.used_at is not null then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;

  v_now := extract(epoch from now())::int;
  v_ttl_secs := case
    when v_token.is_master then 30*24*3600
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
    -- used_at ist bigint (JS-Millisekunden, vgl. nowMs()/Date.now() in der App),
    -- NICHT timestamptz. now() würde mit Fehler 42804 abbrechen.
    update public.access_tokens
    set used_at = (extract(epoch from now())*1000)::bigint
    where short_code = v_short_code and used_at is null;
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

-- ── 4) argus_exchange_observer_code: Neufassung mit jti-Claim ───────────────
-- Identisch zur Fassung aus 0005, plus 'jti' im JWT-Payload.
create or replace function public.argus_exchange_observer_code(code text)
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

  select praesidium_id, ttl_hours, revoked, observer
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  if not coalesce(v_token.observer, false) then
    return jsonb_build_object('error', 'Kein Beobachter-Code');
  end if;
  if v_token.praesidium_id is null then
    -- Ein Beobachter-Code MUSS präsidiumsgebunden sein (Lage = ein Präsidium).
    return jsonb_build_object('error', 'Konfigurationsfehler');
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

  -- EIGENE Claim-Form: is_observer + observer_praesidium_id (vgl. 0005),
  -- plus jti für die Sofort-Sperrung (0007).
  v_jwt := extensions.sign(
    json_build_object(
      'iss', 'supabase',
      'sub', 'argus-observer',
      'role', 'anon',
      'is_observer', true,
      'observer_praesidium_id', v_token.praesidium_id,
      'jti', v_short_code,
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  select name into v_pname from public.praesidien
  where id = v_token.praesidium_id;

  -- Zwangs-Log VOR der Rückgabe — ein Eintrag je Login/Session (vgl. 0005);
  -- 12-Monats-Retention aus 0004 greift.
  insert into public.governance_log (at, kuerzel, action)
    values ((extract(epoch from now())*1000)::bigint, v_short_code, 'lage_view');

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'praesidium_id',   v_token.praesidium_id,
    'praesidium_name', v_pname,
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;
grant execute on function public.argus_exchange_observer_code(text) to anon;
