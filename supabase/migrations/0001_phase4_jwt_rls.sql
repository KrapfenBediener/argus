-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 4 — Serverseitige Absicherung (JWT-Exchange + RLS)
-- ============================================================================
-- Reproduzierbarer DB-Stand der Phase 4. Wurde live über die Supabase
-- Management API auf Projekt sehuosjyjmrpzcqrelej angewendet (kein lokaler
-- Supabase-CLI-Build im Projekt).
--
-- VORAUSSETZUNGEN (einmalig, NICHT in dieser Datei reproduzierbar):
--   1. Extension pgjwt aktiviert  ->  schema "extensions" (extensions.sign())
--      create extension if not exists pgjwt with schema extensions;
--   2. JWT-Secret im Supabase Vault unter dem Namen 'argus_jwt_secret'
--      (Wert = Projekt-JWT-Secret; NICHT im Klartext versionieren).
-- ============================================================================

-- ── 04-01: Token-Exchange-RPC ──────────────────────────────────────────────
-- Validiert einen 8-stelligen Code, signiert ein JWT (pgjwt, Secret aus Vault)
-- und gibt es zurück. SECURITY DEFINER -> liest access_tokens an RLS vorbei.
-- Pseudonymität: JWT enthält praesidium_id / is_master / exp, KEINEN Klarnamen.
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

  select praesidium_id, is_master, ttl_hours, single_use, used_at
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
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
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  if v_token.single_use and v_token.used_at is null then
    update public.access_tokens
    set used_at = now()
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

-- ── 04-03-T1: JWT-Claim-Hilfsfunktionen ────────────────────────────────────
-- Lesen die Claims aus dem von PostgREST geparsten Request-JWT.
create or replace function public.argus_praesidium_id()
  returns uuid language sql stable security definer as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'praesidium_id','')::uuid
$$;

create or replace function public.argus_is_master()
  returns boolean language sql stable security definer as $$
  select coalesce((current_setting('request.jwt.claims', true)::json->>'is_master')::boolean, false)
$$;

-- ── 04-03-T2: RLS-Policies (ersetzen anon_all) ─────────────────────────────
-- Zugriff an praesidium_id aus dem JWT gebunden; Master sieht alles.

-- patients
drop policy if exists anon_all on public.patients;
create policy "argus_patients_rw" on public.patients for all to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps where praesidium_id = public.argus_praesidium_id()) )
  with check ( public.argus_is_master()
          or ccp_id in (select id from public.ccps where praesidium_id = public.argus_praesidium_id()) );

-- ccps
drop policy if exists anon_all on public.ccps;
create policy "argus_ccps_rw" on public.ccps for all to anon
  using ( public.argus_is_master() or praesidium_id = public.argus_praesidium_id() )
  with check ( public.argus_is_master() or praesidium_id = public.argus_praesidium_id() );

-- checklists
drop policy if exists anon_all on public.checklists;
create policy "argus_checklists_rw" on public.checklists for all to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps where praesidium_id = public.argus_praesidium_id()) )
  with check ( public.argus_is_master()
          or ccp_id in (select id from public.ccps where praesidium_id = public.argus_praesidium_id()) );

-- ── 04-03-T3: access_tokens & praesidien ───────────────────────────────────
-- Unverändert. praesidien.anon_read (qual: true) bleibt — der Freischalt-Screen
-- listet alle Präsidien ohne JWT. access_tokens behält anon_read /
-- anon_insert_singleuse / anon_update_singleuse (Einmal-Link-Mechanik).
