-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Paket 2 (Feedback 2026-06-13): Gast-Code, schulung-Flag, Geo-Koordinaten,
--   TQ-Anlageort, Export-Status + Export-Protokollierung, Lage-Verbund
-- ============================================================================
-- Owner-Entscheide 2026-06-13:
--   * GAST-CODE: Mehrfach-Code für den Gastkräfte-Zustrom im Einsatz (über
--     Funk durchsagbar / an der Einsatztafel anschreibbar). SERVERSEITIG echt
--     befristet (expires_at, 24 h ab Erstellung durch die Leitungs-Seite);
--     der Ablauf wirkt über argus_token_active (0007) auch auf BEREITS
--     ausgestellte Tickets. Jede Einlösung wird protokolliert
--     (governance_log action 'gast_join', kuerzel = short_code — kein
--     Personenbezug; 12-Monats-Retention aus 0004 greift).
--   * SCHULUNG-FLAG je Präsidium: Schulungs-Präsidien sind maschinell
--     erkennbar → die App leitet den Abschluss-Typ ab (Schulung = 'uebung',
--     sonst 'einsatz') und die Übung/Einsatz-Frage entfällt; sichtbares
--     Schulungs-Banner gegen Verwechslung. Bei der Polizei-Implementierung
--     bekommt jedes Präsidium ein eigenes Schulungs-Schwester-Präsidium
--     mit diesem Flag (Konzept, siehe Chat).
--   * GEO: optionale Koordinaten je CCP (bei Eröffnung per GPS erfasst) —
--     erscheinen in der Lageansicht (Klick kopiert; Brücke zur manuellen
--     VIADUX-Übernahme). Anonyme Einsatz-Infrastrukturdaten, kein
--     Personenbezug.
--   * TQ-ANLAGEORT: patients.tq_site (Extremität) — fachlich für die
--     Übergabe relevant.
--   * EXPORT-VERLAGERUNG: Der Übergabe-Export läuft künftig über die
--     Leitungs-Seite (protokolliert!). ccps.exported_at hält fest, ob ein
--     abgeschlossener Einsatz exportiert wurde („noch nicht exportiert"-
--     Badge als Sicherheitsnetz vor der 72-h-Löschung); argus_mark_export
--     setzt den Status und protokolliert (action 'protokoll_export').
--
-- Reihenfolge: 0000 → … → 0008 → dieses Skript. Anwendung wie immer über
-- die Management API. Idempotent (add column if not exists, update mit
-- Wertgleichheit, create or replace, grants).
-- Zeitkonvention: bigint in JS-Millisekunden (vgl. 0002).
-- ============================================================================

-- ── 1) Spalten ───────────────────────────────────────────────────────────────
alter table public.access_tokens add column if not exists gast       boolean not null default false;
alter table public.access_tokens add column if not exists expires_at bigint;            -- ms; null = unbefristet
alter table public.praesidien    add column if not exists schulung   boolean not null default false;
alter table public.ccps          add column if not exists geo_lat     double precision;
alter table public.ccps          add column if not exists geo_lng     double precision;
alter table public.ccps          add column if not exists exported_at bigint;            -- ms; null = noch nicht exportiert
alter table public.patients      add column if not exists tq_site     text;              -- 'Arm li'|'Arm re'|'Bein li'|'Bein re'|null

-- Schulungs-Flag setzen (idempotent; bei Self-Hosting: eigene Schulungs-
-- Präsidien anlegen und Flag setzen — docs/SELF-HOSTING.md).
update public.praesidien set schulung = true where name = 'Schulungsumgebung' and schulung = false;

-- ── 2) argus_token_active: Ablauf-Prüfung ergänzen (Neufassung von 0007) ─────
-- Gast-Codes (und künftig alles mit expires_at) verlieren mit dem Ablauf
-- SOFORT serverseitig jede Wirkung — auch bereits ausgestellte Tickets.
create or replace function public.argus_token_active()
  returns boolean
  language plpgsql
  stable
  security definer
  set search_path to 'public'
as $function$
declare
  v_jti text;
  v_tok record;
begin
  v_jti := nullif(current_setting('request.jwt.claims', true)::json->>'jti', '');
  if v_jti is null then
    return true;   -- Alt-JWT ohne jti: Übergangsgnade bis exp (0007)
  end if;
  select revoked, expires_at into v_tok
  from public.access_tokens where short_code = v_jti;
  if not found then
    return false;  -- Code gelöscht → wie gesperrt behandeln
  end if;
  if coalesce(v_tok.revoked, false) then
    return false;
  end if;
  if v_tok.expires_at is not null
     and v_tok.expires_at <= (extract(epoch from now())*1000)::bigint then
    return false;  -- Code abgelaufen (Gast-Code) → Tickets sterben mit
  end if;
  return true;
end;
$function$;
grant execute on function public.argus_token_active() to anon;
comment on function public.argus_token_active() is
  'Sofort-Sperrung (0007) + Ablauf-Prüfung (0009): prüft jti-Claim gegen '
  'access_tokens.revoked UND expires_at. Ohne jti (Alt-JWT) true; Code '
  'gelöscht/gesperrt/abgelaufen → false. Konsumiert von argus_praesidium_id/'
  'argus_is_master/argus_is_observer — wirkt auf ALLE Policies und RPCs.';

-- ── 3) argus_exchange_code: Gast-Codes (Neufassung von 0007) ─────────────────
-- Neu gegenüber 0007: gast + expires_at werden mitgelesen; abgelaufene Codes
-- werden mit eigenem Wortlaut abgewiesen; Gast-Tickets sind 24 h gültig;
-- jede Gast-Einlösung wird protokolliert (action 'gast_join').
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

  select praesidium_id, is_master, ttl_hours, single_use, used_at, revoked, observer, gast, expires_at
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

-- ── 4) argus_lage: Geo + Verbund (Neufassung von 0005) ───────────────────────
-- Neu: geo_lat/geo_lng (Koordinaten-Klick in der Lage-Seite) und
-- verbund/verbund_gruppe (Feedback: „Lageübersicht zeigt nicht an, dass
-- CCPs zusammengeführt wurden"). Weiterhin AUSSCHLIESSLICH anonyme Zähler.
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

-- ── 5) argus_governance_einsaetze: exported_at mitliefern (Neufassung 0003) ──
create or replace function public.argus_governance_einsaetze()
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v jsonb;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'ccp_id',            c.id,
           'kennung',           c.kennung,
           'merge_group_id',    c.merge_group_id,
           'einsatz_typ',       c.einsatz_typ,
           'closed_at',         c.closed_at,
           'purge_after',       c.purge_after,
           'photo_purge_after', c.photo_purge_after,
           'exported_at',       c.exported_at,
           'patient_count',     (select count(*)       from public.patients   p where p.ccp_id = c.id),
           'photo_count',       (select count(p.photo) from public.patients   p where p.ccp_id = c.id),
           'checklist_count',   (select count(*)       from public.checklists k where k.ccp_id = c.id)
         ) order by c.closed_at desc), '[]'::jsonb)
  into v
  from public.ccps c
  where c.closed_at is not null
    and (    exists (select 1 from public.patients   p where p.ccp_id = c.id)
          or exists (select 1 from public.checklists k where k.ccp_id = c.id)
          or coalesce(c.ort,'') <> '' or coalesce(c.master_medic,'') <> ''
          or c.join_token is not null );
  return v;
end;
$function$;
grant execute on function public.argus_governance_einsaetze() to anon;

-- ── 6) RPC: Export-Status setzen + protokollieren ────────────────────────────
-- Muster argus_extend_protokoll_frist: Master-Pflicht, Kürzel-Pflicht,
-- wirkt auf den ganzen Verbund, Zwangs-Log (action 'protokoll_export').
create or replace function public.argus_mark_export(p_ccp_id uuid, p_kuerzel text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now bigint := (extract(epoch from now())*1000)::bigint;
  v_ccp record;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  if p_kuerzel is null or btrim(p_kuerzel) = '' then
    raise exception 'Kürzel erforderlich';
  end if;

  select id, merge_group_id, closed_at into v_ccp
  from public.ccps where id = p_ccp_id;
  if not found then
    raise exception 'CCP nicht gefunden';
  end if;
  if v_ccp.closed_at is null then
    raise exception 'Einsatz noch offen';
  end if;

  update public.ccps set exported_at = v_now
  where id = p_ccp_id
     or (v_ccp.merge_group_id is not null and merge_group_id = v_ccp.merge_group_id);

  insert into public.governance_log (at, ccp_id, kuerzel, action)
    values (v_now, p_ccp_id, btrim(p_kuerzel), 'protokoll_export');

  return jsonb_build_object('exported_at', v_now);
end;
$function$;
grant execute on function public.argus_mark_export(uuid, text) to anon;

-- ── 7) governance_log.action: Kommentar nachziehen ───────────────────────────
comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view | lage_view | gast_join | protokoll_export';
