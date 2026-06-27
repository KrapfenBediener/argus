-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 4.14 — Präsidiums-Admin-Rolle: Admin-Token-Art, Claim-Helfer,
--              Admin-Exchange-RPC, scoped Gast-Code-RPCs, argus_lage-Erweiterung
-- ============================================================================
-- Serverseitiger Unterbau der Rolle „Präsidiums-Admin". Muster: Observer-Rolle
-- (0005), abgesichert durch jti-Sofortsperre (0007). Neu:
--
--   * Token-Art is_admin (boolean) + Claim admin_praesidium_id.
--   * Helfer argus_is_admin() (gated auf argus_token_active) +
--     argus_admin_praesidium_id() — analog argus_is_observer/
--     argus_observer_praesidium_id aus 0005/0007.
--   * Eigener Admin-Exchange-RPC argus_exchange_admin_code (analog
--     argus_exchange_observer_code aus 0007). JWT-Payload trägt is_admin:true
--     + admin_praesidium_id + jti — BEWUSST KEIN praesidium_id- und
--     KEIN is_master-Claim (dadurch liefern argus_praesidium_id()/
--     argus_is_master() null/false und ALLE bestehenden RLS-Policies
--     verweigern Roh-Zugriff auf Patientenrows/Tokens/Checklisten).
--   * security-definer-RPC argus_admin_issue_gast: Admin gibt 24h-Gast-Code
--     NUR für sein eigenes Präsidium aus (harte Scope-Prüfung).
--   * security-definer-RPC argus_admin_revoke_gast: Admin sperrt Gast-Code
--     NUR des eigenen Präsidiums, niemals privilegierte Codes.
--   * argus_lage() neu gefasst: neben Observer-Zweig gilt auch Admin-Zweig
--     (eigenes Präsidium, anonyme Zähler — kein Patientenzugriff).
--   * governance_log.action-Kommentar um admin_login/admin_gast_issue/
--     admin_gast_revoke erweitert.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → 0003_phase49_einsatzprotokoll.sql →
--   0004_phase410_log_retention.sql → 0005_phase412_lageansicht.sql →
--   0006_token_hygiene.sql → 0007_jti_sofortsperre.sql →
--   0008_nummernvergabe.sql → 0009_paket2_gastcode_schulung.sql →
--   0010_lage_ort.sql → 0011_paket3_schulung.sql →
--   0012_kurs_evaluation.sql → dieses Skript.
--
-- Anwendung wie 0001–0012: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — alter table add column if not exists,
-- create or replace, grant, comment.
-- ============================================================================

-- ── 1) Spalte: is_admin auf access_tokens ───────────────────────────────────
-- Boolean-Kennzeichnung, konsistent zu is_master/observer/gast/temporary/single_use.
-- revoked (0003) und expires_at (0009) wirken unverändert auch auf Admin-Codes.
alter table public.access_tokens add column if not exists is_admin boolean not null default false;

-- ── 2) Claim-Helfer für die Admin-Claim-Form ────────────────────────────────
-- Muster: argus_is_observer/argus_observer_praesidium_id aus 0005,
-- MIT jti-Gate (argus_token_active) wie 0007 — eine Code-Sperre wirkt sofort.

-- argus_is_admin(): gated auf argus_token_active, damit ein gesperrter Admin-Code
-- SOFORT alle Admin-Operationen sperrt (STRIDE T-0414-05).
create or replace function public.argus_is_admin()
  returns boolean language sql stable security definer as $$
  select public.argus_token_active()
     and coalesce((current_setting('request.jwt.claims', true)::json->>'is_admin')::boolean, false)
$$;
grant execute on function public.argus_is_admin() to anon;

-- argus_admin_praesidium_id(): kein eigenes Gate nötig — analog zur Begründung
-- bei argus_observer_praesidium_id in 0007: ohne is_admin=true ist der Wert
-- wirkungslos; beide RPCs (issue/revoke) prüfen argus_is_admin() zuerst.
create or replace function public.argus_admin_praesidium_id()
  returns uuid language sql stable security definer as $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'admin_praesidium_id','')::uuid
$$;
grant execute on function public.argus_admin_praesidium_id() to anon;

-- ── 3) Admin-Exchange-RPC: argus_exchange_admin_code ────────────────────────
-- Eigener Endpunkt analog argus_exchange_observer_code (0007-Fassung mit jti).
-- Normalisierung identisch (upper + regexp_replace, short_code-Split,
-- length<8-Guard). Abweisungen: nicht gefunden, gesperrt, kein is_admin,
-- praesidium_id null (Admin-Code MUSS präsidiumsgebunden sein).
-- TTL: ttl_hours falls gesetzt, sonst 24 h (kurzlebig — KEINE 30 Tage).
-- JWT-Payload: is_admin:true + admin_praesidium_id + jti (=short_code) +
--   iss/sub('argus-admin')/role('anon')/iat/exp —
--   BEWUSST KEIN praesidium_id- und KEIN is_master-Claim.
-- Zwangs-Log VOR Rückgabe: governance_log action 'admin_login' (STRIDE T-0414-06).
-- KEINE Änderung an argus_exchange_code/argus_exchange_observer_code.
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

-- ── 4) governance_log.action: Kommentar nachziehen ──────────────────────────
-- Basis: 0009-Fassung. admin_login/admin_gast_issue/admin_gast_revoke ergänzt.
comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view | lage_view | gast_join | protokoll_export | admin_login | admin_gast_issue | admin_gast_revoke';

-- ── 5) RPC: scoped Gast-Code-Ausgabe ────────────────────────────────────────
-- argus_admin_issue_gast: Admin gibt 24-h-Gast-Code NUR fürs eigene Präsidium
-- aus. Security definer umgeht die master-only-RLS (0001) kontrolliert.
-- Harte Scope-Prüfung: Ziel-Präsidium MUSS == argus_admin_praesidium_id()
-- (Kern-Mitigation gegen Fremd-Präsidiums-Eskalation, STRIDE T-0414-02).
create or replace function public.argus_admin_issue_gast(p_praesidium_id uuid, p_label text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions'
as $function$
declare
  -- Verwechslungssicheres Alphabet ohne 0/O/1/I (vgl. genShortCode der Leitungs-Seite)
  v_alphabet    text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_short_code  text;
  v_token       text;
  v_now_ms      bigint;
  v_expires_ms  bigint;
  v_part1       text;
  v_part2       text;
  v_attempt     int := 0;
  v_exists      boolean;
begin
  -- Guard 1: Admin-Token erforderlich (STRIDE T-0414-02)
  if not public.argus_is_admin() then
    raise exception 'Nur mit Admin-Token';
  end if;

  -- Guard 2: Ziel-Präsidium MUSS identisch mit dem eigenen Admin-Präsidium sein
  --          (harte Scope-Prüfung — verhindert Fremd-Präsidiums-Eskalation)
  if public.argus_admin_praesidium_id() is null
     or p_praesidium_id <> public.argus_admin_praesidium_id() then
    raise exception 'Nur fürs eigene Präsidium';
  end if;

  v_now_ms     := (extract(epoch from now())*1000)::bigint;
  v_expires_ms := v_now_ms + 24*3600000;   -- 24 Stunden ab jetzt (ms)
  v_token      := encode(extensions.gen_random_bytes(16), 'hex');

  -- Short-Code generieren — 8 Zeichen aus verwechslungssicherem Alphabet,
  -- Format XXXX-XXXX; Kollisions-Schleife (Tabelle ist winzig, max. Versuche 10).
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

  -- Eintragen als Gast-Code fürs eigene Präsidium (is_admin=false, is_master=false,
  -- observer=false, single_use=false, temporary=false — reiner 24h-Gast-Code).
  insert into public.access_tokens (
    token, short_code, praesidium_id, gast,
    is_admin, is_master, observer, single_use, temporary,
    ttl_hours, expires_at, label
  ) values (
    v_token, v_short_code, p_praesidium_id, true,
    false, false, false, false, false,
    null, v_expires_ms, btrim(coalesce(p_label,''))
  );

  -- Zwangs-Log (STRIDE T-0414-06)
  insert into public.governance_log (at, kuerzel, action)
    values (v_now_ms, v_short_code, 'admin_gast_issue');

  return jsonb_build_object(
    'short_code',  v_short_code,
    'expires_at',  v_expires_ms
  );
end;
$function$;
grant execute on function public.argus_admin_issue_gast(uuid, text) to anon;

-- ── 6) RPC: scoped Gast-Code-Sperre ─────────────────────────────────────────
-- argus_admin_revoke_gast: Admin sperrt Gast-Code NUR des eigenen Präsidiums,
-- NIEMALS privilegierte Codes (master/admin/observer). (STRIDE T-0414-03)
create or replace function public.argus_admin_revoke_gast(p_short_code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_target record;
begin
  -- Guard 1: Admin-Token erforderlich
  if not public.argus_is_admin() then
    raise exception 'Nur mit Admin-Token';
  end if;

  -- Zielcode laden
  select praesidium_id, is_master, is_admin, observer, gast
  into v_target
  from public.access_tokens
  where short_code = p_short_code;

  if not found then
    raise exception 'Code nicht gefunden';
  end if;

  -- Guard 2: Ziel-Präsidium MUSS identisch mit dem eigenen Admin-Präsidium sein
  if v_target.praesidium_id is null
     or v_target.praesidium_id <> public.argus_admin_praesidium_id() then
    raise exception 'Nur fürs eigene Präsidium';
  end if;

  -- Guard 3: Privilegierte Codes (master/admin/observer) sind nicht sperrbar —
  --          Admin darf NUR Gast-Codes sperren (STRIDE T-0414-03).
  if coalesce(v_target.is_master, false)
     or coalesce(v_target.is_admin, false)
     or coalesce(v_target.observer, false) then
    raise exception 'Nur Gast-Codes des eigenen Präsidiums sperrbar';
  end if;

  -- Guard 4: nur gast=true-Codes sperrbar (sicherheitshalber explizit)
  if not coalesce(v_target.gast, false) then
    raise exception 'Nur Gast-Codes des eigenen Präsidiums sperrbar';
  end if;

  -- Sperren
  update public.access_tokens set revoked = true
  where short_code = p_short_code;

  -- Zwangs-Log (STRIDE T-0414-06)
  insert into public.governance_log (at, kuerzel, action)
    values ((extract(epoch from now())*1000)::bigint, p_short_code, 'admin_gast_revoke');

  return jsonb_build_object('revoked', true);
end;
$function$;
grant execute on function public.argus_admin_revoke_gast(text) to anon;

-- ── 7) argus_lage(): Admin-Zweig hinzufügen (Neufassung von 0009) ────────────
-- Feldsatz BYTE-GLEICH zur 0009-Fassung (geo, verbund) — NICHT abgespeckt.
-- Erweiterung: neben Observer-Zweig gilt auch Admin-Zweig.
-- Ein Admin sieht AUSSCHLIESSLICH die anonyme Lage seines eigenen Präsidiums —
-- keine Patientenrows, keine Namen/Fotos/Vitalwerte (STRIDE T-0414-04).
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
  -- Eingangs-Guard: Observer ODER Admin (jeweils aufs eigene Präsidium begrenzt)
  if not (public.argus_is_observer() or public.argus_is_admin())
     or coalesce(public.argus_observer_praesidium_id(),
                 public.argus_admin_praesidium_id()) is null then
    raise exception 'Nur mit Beobachter- oder Admin-Zugang';
  end if;

  -- Präsidium aus dem passenden Claim lesen (Observer-Claim hat Vorrang;
  -- bei einem Admin-JWT ist argus_observer_praesidium_id() null → fallback)
  v_pid := coalesce(public.argus_observer_praesidium_id(),
                    public.argus_admin_praesidium_id());

  select name into v_pname from public.praesidien where id = v_pid;

  -- Anonyme Zähler je aktivem CCP des Präsidiums (identisch zu 0009-Fassung)
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
