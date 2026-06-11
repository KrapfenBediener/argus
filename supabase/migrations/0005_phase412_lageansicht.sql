-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 4.12 — FLZ-Lageansicht Stufe a: Beobachter-Token, Observer-JWT,
--              Aggregat-RPC argus_lage, lage_view-Protokoll
-- ============================================================================
-- Serverseitiger Unterbau für die separate read-only Beobachter-Seite
-- (FLZ/ILS). Sicherheits-Design fixiert 2026-06-04 (ROADMAP Phase 8):
--   * Observer-JWT trägt eine EIGENE Claim-Form: is_observer:true +
--     observer_praesidium_id — bewusst NICHT praesidium_id. Dadurch liefert
--     argus_praesidium_id() für Beobachter null und ALLE bestehenden
--     Patienten-/CCP-/Checklisten-/Token-RLS-Policies verweigern Roh-Zugriff.
--     Es wird KEINE neue RLS-Policy für Beobachter angelegt.
--   * Zahlen kommen ausschließlich aus der security-definer-Aggregat-RPC
--     argus_lage (liest observer_praesidium_id). Keine Patientenrows, keine
--     Namen/Fotos/Vitalwerte, keine Bediener-/MasterMedic-Kürzel.
--   * Beobachter-Codes funktionieren NICHT im Feld-App-Exchange
--     (argus_exchange_code weist sie ab); MasterToken/normale Codes
--     funktionieren NICHT im Beobachter-Exchange.
--   * Jeder Beobachter-Login wird schlank protokolliert (governance_log,
--     action 'lage_view', einmal je Exchange — nicht je Poll).
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → 0003_phase49_einsatzprotokoll.sql →
--   0004_phase410_log_retention.sql → dieses Skript.
--
-- Anwendung wie 0001–0004: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — zweifaches Anwenden ist gefahrlos.
--
-- Zeitstempel-Konvention: bigint in JS-Millisekunden (Date.now()), vgl. 0002.
-- ============================================================================

-- ── 1) Token-Art „Beobachter" auf access_tokens ─────────────────────────────
-- Boolean-Kennzeichnung, konsistent zu is_master/temporary/single_use.
-- revoked (0003) wirkt unverändert auch auf Beobachter-Codes.
alter table public.access_tokens add column if not exists observer boolean not null default false;

-- ── 2) Claim-Helfer für die Observer-Claim-Form (Muster 0001) ───────────────
create or replace function public.argus_is_observer()
  returns boolean language sql stable security definer as $$
  select coalesce((current_setting('request.jwt.claims', true)::json->>'is_observer')::boolean, false)
$$;

create or replace function public.argus_observer_praesidium_id()
  returns uuid language sql stable security definer as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'observer_praesidium_id','')::uuid
$$;

-- ── 3) argus_exchange_code: Neufassung mit Beobachter-Abweisung ──────────────
-- Identisch zur Fassung aus 0003, plus: observer wird mitgelesen und direkt
-- nach der revoked-Prüfung abgewiesen. Eigener, für Nutzer verständlicher
-- Wortlaut — die Feld-App zeigt data.error unverändert an, daher ist KEIN
-- App-Update nötig (index.html bleibt unangetastet).
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

-- ── 4) RPC: Beobachter-Exchange (eigener Endpunkt, nur observer-Codes) ──────
-- Eigener RPC statt Erweiterung des Feld-Exchanges: saubere beidseitige
-- Trennung ohne index.html-Änderung. Normalisierung identisch zu
-- argus_exchange_code. TTL: ttl_hours falls gesetzt, sonst 24 h — Beobachter-
-- JWTs sind bewusst kurzlebig (KEINE 30 Tage); eine Code-Sperre (revoked)
-- wirkt damit spätestens nach 24 h, beim nächsten Login sofort.
-- Erfolgs-Log: genau EIN governance_log-Eintrag je Login (action 'lage_view',
-- kuerzel = eingelöster short_code — kein Personenbezug), nicht je Poll.
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

  -- EIGENE Claim-Form: is_observer + observer_praesidium_id.
  -- Bewusst KEIN praesidium_id- und KEIN is_master-Claim — dadurch liefern
  -- argus_praesidium_id()/argus_is_master() null/false und alle bestehenden
  -- RLS-Policies verweigern Roh-Zugriff (per REST-Negativtests belegt).
  v_jwt := extensions.sign(
    json_build_object(
      'iss', 'supabase',
      'sub', 'argus-observer',
      'role', 'anon',
      'is_observer', true,
      'observer_praesidium_id', v_token.praesidium_id,
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  select name into v_pname from public.praesidien
  where id = v_token.praesidium_id;

  -- Zwangs-Log VOR der Rückgabe — ein Eintrag je Login/Session (DSFA-Hinweis
  -- „Protokollierung des Observer-Zugriffs"); 12-Monats-Retention aus 0004 greift.
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

-- ── 5) Aggregat-RPC: argus_lage (observer-exklusiv) ─────────────────────────
-- Liefert je AKTIVEM (nicht abgeschlossenem) CCP des Beobachter-Präsidiums
-- ausschließlich anonyme Zähler. Abgeschlossene Einsätze sind NICHT enthalten
-- (Lage = aktuell, kein Archiv). Kategorie-/Status-Semantik wie die Feld-App:
-- cat ∈ T1/T2/T3/T5 (nur status='active' gezählt), gPA = status='gpa',
-- prio/ready nur bei aktiven Patienten. Designentscheid: NUR Observer-JWTs —
-- normale Feld-JWTs und Master erhalten die Exception (Master nutzt die
-- Leitungs-Seite; saubere, testbare Trennung).
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
  if not public.argus_is_observer() or public.argus_observer_praesidium_id() is null then
    raise exception 'Nur mit Beobachter-Zugang';
  end if;
  v_pid := public.argus_observer_praesidium_id();

  select name into v_pname from public.praesidien where id = v_pid;

  select coalesce(jsonb_agg(jsonb_build_object(
           'kennung', c.kennung,
           'ort',     c.ort,
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

-- ── 6) governance_log.action: Kommentar nachziehen ──────────────────────────
comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view | lage_view';
