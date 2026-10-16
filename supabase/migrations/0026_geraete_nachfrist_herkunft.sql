-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0026 — Gerätestatus, Nachfrist, Herkunft
--                  (ccp_devices, Geräte-RPCs, argus_late_push, Herkunftsprotokoll,
--                   Protokoll-Datenherkunft, Purge-Neufassung)
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- Phase 6.5 (Entscheidungen D6.5-01, -04, -08, -09, -11, -13, -15, -18).
--
-- Problem: Die Feld-App weiß nicht, welche Geräte eines CCP noch leben, ob beim
-- Einsatz-Abschluss alle Daten angekommen sind und woher ein Datensatz stammt.
-- Nach dem Abschluss sperrt die Patienten-RLS jeden Schreibzugriff — ein Gerät,
-- das offline war, verlöre seine Erfassungen. Die RLS wird dafür NICHT
-- gelockert (die ALL-Policies gelten auch für SELECT: eine Nachfrist-Policy
-- würde geschlossene Einsätze lesbar machen, Pitfall 1). Stattdessen gibt es
-- genau einen Schreibweg: die SECURITY-DEFINER-RPC argus_late_push.
--
-- Inhalt:
--   1) governance_log.detail (jsonb): pseudonymes Ereignis-Detail.
--   2) Tabelle ccp_devices (eine Zeile je CCP + Gerätenummer aus 0022, keine
--      neue Identität) + Präsidiums-RLS (nur SELECT; Schreiben nur per RPC).
--   3) RPCs argus_device_heartbeat / argus_device_leave / argus_device_mark.
--   4) argus_server_time() → {now, v:26}.
--   5) argus_log_herkunft (Weg direkt/nachgereicht) und argus_late_push
--      (Nachzügler, 24 h nach Abschluss, Spalten-Whitelist, Merge-Trigger).
--   6) argus_governance_protokoll: zusätzlich devices und herkunft.
--   7) argus_run_purge: Neufassung = 0016 + Token-Hygiene (0006) + ccp_devices.
--   8) Kataloge der governance_log-Spalten action/detail.
--
-- Reihenfolge: 0000 → … → 0025 → 0026. Benötigt 0025 (patients.deleted_at,
-- Merge-Trigger, argus_governance_protokoll-Fassung).
-- Einspielen: durch den Owner im Supabase-SQL-Editor (kein CLI/db push).
-- Idempotent (create table/column if not exists, create or replace, drop policy
-- if exists). KEINE Änderung an Patienten- oder CCP-Policies: argus_patients_*
-- bleiben unangetastet; anon liest weiterhin 0 Zeilen aus patients/ccp_devices.
-- Polling statt Realtime: ccp_devices gehört bewusst NICHT in die Publikation
-- supabase_realtime (das MasterMedic-Gerät fragt per Intervall ab).
-- Prüfskript: supabase/probes/0026_geraete_probe.sql (rollt sich selbst zurück).
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1) governance_log.detail ────────────────────────────────────────────────
alter table public.governance_log add column if not exists detail jsonb;

-- ── 2) ccp_devices: Geräteregister + RLS ────────────────────────────────────
-- Schlüssel = CCP + Gerätenummer aus argus_claim_device (0022). Zeitstempel
-- stempelt ausschließlich der Server (Geräteuhren spielen keine Rolle).
create table if not exists public.ccp_devices (
  ccp_id      uuid   not null references public.ccps(id) on delete cascade,
  device_no   int    not null,
  operator    text   not null default '',
  first_seen  bigint not null,
  last_seen   bigint not null,
  open_n      int    not null default 0,
  app_version text   not null default '',
  left_at     bigint,
  left_by     text,
  lost_at     bigint,
  lost_by     text,
  primary key (ccp_id, device_no)
);

-- Nur Lesen für anon (zusätzlich durch RLS auf das eigene Präsidium begrenzt).
-- Supabase vergibt auf neue Tabellen teils Standardrechte: erst entziehen.
revoke all on public.ccp_devices from anon;
grant select on public.ccp_devices to anon;
alter table public.ccp_devices enable row level security;

drop policy if exists argus_ccp_devices_select on public.ccp_devices;
create policy "argus_ccp_devices_select" on public.ccp_devices
  for select to anon
  using (
    public.argus_is_master()
    or ccp_id in (select id from public.ccps where praesidium_id = public.argus_praesidium_id())
  );

comment on table public.ccp_devices is
  'Geräteregister je CCP (Phase 6.5): Gerätenummer (0022), Bediener-Kürzel, Zeitstempel, Zähler offener Patienten, App-Version, Verlassen/Abgemeldet-Marker. Pseudonym — keine Patientendaten. Schreiben nur über die RPCs argus_device_*; Lesen nur Master und das eigene Präsidium. Löschung mit dem Einsatz-Purge (purge_after bzw. Auffangnetz) oder per CASCADE.';

-- ── 3) Geräte-RPCs ──────────────────────────────────────────────────────────
-- Gemeinsame Regeln: Fehler als {"error":…} (nie Exception); Reihenfolge der
-- Prüfungen CCP existiert → Berechtigung → Rest; Berechtigungsgrenze wie
-- argus_claim_device (0022): Master ODER Präsidium des Aufrufers.

-- 3a) Heartbeat: Lebenszeichen eines Geräts (Upsert auf CCP + Gerätenummer).
create or replace function public.argus_device_heartbeat(
  p_ccp_id   uuid,
  p_dev      int,
  p_operator text,
  p_open_n   int,
  p_ver      text,
  p_rejoin   boolean default false
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now      bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_ccp      record;
  v_row      record;
  v_old_left bigint;
  v_op       text := left(btrim(coalesce(p_operator, '')), 40);
  v_open     int  := least(greatest(coalesce(p_open_n, 0), 0), 9999);
begin
  select id, praesidium_id, closed_at, purge_after, photo_purge_after, next_device into v_ccp
  from public.ccps where id = p_ccp_id
  for update;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  -- Geschlossener Einsatz: keine Schreibwirkung, nur die Fristen zurückmelden
  -- (Schulungs-Reset/Pitfall 12: tote CCPs bekommen keine Geräte-Zeilen mehr).
  if v_ccp.closed_at is not null then
    return jsonb_build_object(
      'now',               v_now,
      'closed',            true,
      'closed_at',         v_ccp.closed_at,
      'purge_after',       v_ccp.purge_after,
      'photo_purge_after', v_ccp.photo_purge_after
    );
  end if;

  if p_dev is null or p_dev < 1 or p_dev > least(99, greatest(coalesce(v_ccp.next_device, 1), 1)) then
    return jsonb_build_object('error', 'Ungültige Gerätenummer', 'now', v_now);
  end if;

  select d.left_at into v_old_left
  from public.ccp_devices d
  where d.ccp_id = p_ccp_id and d.device_no = p_dev
  for update;

  -- Lebenszeichen schlägt Vermutung (lost_*); Verlassen (left_*) nur bei
  -- ausdrücklichem Wiederbeitritt zurücknehmen.
  insert into public.ccp_devices (ccp_id, device_no, operator, first_seen, last_seen, open_n, app_version)
    values (p_ccp_id, p_dev, v_op, v_now, v_now, v_open, left(btrim(coalesce(p_ver, '')), 16))
  on conflict (ccp_id, device_no) do update set
    operator    = excluded.operator,
    last_seen   = v_now,
    open_n      = excluded.open_n,
    app_version = excluded.app_version,
    lost_at     = null,
    lost_by     = null,
    left_at     = case when coalesce(p_rejoin, false) then null else public.ccp_devices.left_at end,
    left_by     = case when coalesce(p_rejoin, false) then null else public.ccp_devices.left_by end
  returning * into v_row;

  if coalesce(p_rejoin, false) and v_old_left is not null then
    insert into public.governance_log (at, ccp_id, kuerzel, action, detail)
      values (v_now, p_ccp_id, v_op, 'geraet_wieder_beigetreten',
              jsonb_build_object('dev', p_dev, 'open_n', v_open));
  end if;

  return jsonb_build_object(
    'now',     v_now,
    'closed',  false,
    'left_at', v_row.left_at,
    'lost_at', v_row.lost_at
  );
end;
$function$;
grant execute on function public.argus_device_heartbeat(uuid, int, text, int, text, boolean) to anon;

comment on function public.argus_device_heartbeat(uuid, int, text, int, text, boolean) is
  'Gerät meldet sich (Phase 6.5): Upsert auf (CCP, Gerätenummer), last_seen vom Server gestempelt, Lebenszeichen löscht Abgemeldet-Vermutung; Verlassen nur bei p_rejoin zurückgenommen. Geschlossener CCP: {closed:true,…} ohne Schreibwirkung. Berechtigung: Master oder Präsidium des CCP.';

-- 3b) Verlassen: Gerät verlässt den CCP ausdrücklich (D6.5-04, blockiert nie).
create or replace function public.argus_device_leave(
  p_ccp_id   uuid,
  p_dev      int,
  p_operator text,
  p_open_n   int
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now      bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_ccp      record;
  v_old_left bigint;
  v_op       text := left(btrim(coalesce(p_operator, '')), 40);
  v_open     int  := least(greatest(coalesce(p_open_n, 0), 0), 9999);
begin
  select id, praesidium_id, closed_at, next_device into v_ccp
  from public.ccps where id = p_ccp_id
  for update;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  if v_ccp.closed_at is not null then
    return jsonb_build_object('closed', true, 'now', v_now);
  end if;

  if p_dev is null or p_dev < 1 or p_dev > least(99, greatest(coalesce(v_ccp.next_device, 1), 1)) then
    return jsonb_build_object('error', 'Ungültige Gerätenummer', 'now', v_now);
  end if;

  select d.left_at into v_old_left
  from public.ccp_devices d
  where d.ccp_id = p_ccp_id and d.device_no = p_dev
  for update;

  insert into public.ccp_devices (ccp_id, device_no, operator, first_seen, last_seen, open_n, left_at, left_by)
    values (p_ccp_id, p_dev, v_op, v_now, v_now, v_open, v_now, v_op)
  on conflict (ccp_id, device_no) do update set
    operator  = case when excluded.operator <> '' then excluded.operator else public.ccp_devices.operator end,
    last_seen = v_now,
    open_n    = excluded.open_n,
    left_at   = v_now,
    left_by   = excluded.left_by,
    lost_at   = null,
    lost_by   = null;

  -- Ein wiederholter Aufruf (Retry der App) erzeugt keinen zweiten Eintrag.
  if v_old_left is null then
    insert into public.governance_log (at, ccp_id, kuerzel, action, detail)
      values (v_now, p_ccp_id, v_op, 'geraet_verlassen',
              jsonb_build_object('dev', p_dev, 'open_n', v_open));
  end if;

  return jsonb_build_object('ok', true, 'now', v_now, 'left_at', v_now);
end;
$function$;
grant execute on function public.argus_device_leave(uuid, int, text, int) to anon;

comment on function public.argus_device_leave(uuid, int, text, int) is
  'Gerät verlässt den CCP (Phase 6.5): left_at/left_by/open_n/last_seen vom Server gestempelt; governance_log geraet_verlassen (einmalig). Geschlossener CCP: {closed:true} ohne Schreibwirkung.';

-- 3c) Markieren: MasterMedic meldet ein Gerät ab bzw. hebt die Abmeldung auf.
create or replace function public.argus_device_mark(
  p_ccp_id uuid,
  p_dev    int,
  p_lost   boolean,
  p_by     text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now  bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_ccp  record;
  v_row  record;
  v_by   text := left(btrim(coalesce(p_by, '')), 40);
begin
  select id, praesidium_id, closed_at into v_ccp
  from public.ccps where id = p_ccp_id
  for update;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  if v_ccp.closed_at is not null then
    return jsonb_build_object('closed', true, 'now', v_now);
  end if;

  select * into v_row
  from public.ccp_devices d
  where d.ccp_id = p_ccp_id and d.device_no = p_dev
  for update;
  if not found then
    return jsonb_build_object('error', 'Gerät unbekannt', 'now', v_now);
  end if;

  if coalesce(p_lost, false) then
    update public.ccp_devices
       set lost_at = v_now, lost_by = v_by
     where ccp_id = p_ccp_id and device_no = p_dev;
    insert into public.governance_log (at, ccp_id, kuerzel, action, detail)
      values (v_now, p_ccp_id, v_by, 'geraet_abgemeldet',
              jsonb_build_object('dev', p_dev, 'open_n', v_row.open_n));
    return jsonb_build_object('ok', true, 'now', v_now, 'lost_at', v_now);
  end if;

  update public.ccp_devices
     set lost_at = null, lost_by = null
   where ccp_id = p_ccp_id and device_no = p_dev;
  insert into public.governance_log (at, ccp_id, kuerzel, action, detail)
    values (v_now, p_ccp_id, v_by, 'geraet_abmeldung_aufgehoben',
            jsonb_build_object('dev', p_dev, 'open_n', v_row.open_n));
  return jsonb_build_object('ok', true, 'now', v_now, 'lost_at', null);
end;
$function$;
grant execute on function public.argus_device_mark(uuid, int, boolean, text) to anon;

comment on function public.argus_device_mark(uuid, int, boolean, text) is
  'MasterMedic meldet ein Gerät ab (p_lost=true) bzw. hebt die Abmeldung auf (Phase 6.5). Zeile muss existieren; governance_log geraet_abgemeldet / geraet_abmeldung_aufgehoben. Ein späterer Heartbeat des Geräts löscht die Markierung.';

-- ── 4) Capability-Probe v26 ─────────────────────────────────────────────────
-- Sonst identisch zu 0025. Der Client nutzt Heartbeat, Late-Push und Herkunft
-- erst bei v >= 26 (D6.5-18).
create or replace function public.argus_server_time()
  returns jsonb
  language plpgsql
  volatile
  set search_path to 'public'
as $function$
begin
  return jsonb_build_object(
    'now', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'v', 26
  );
end;
$function$;

grant execute on function public.argus_server_time() to anon;

comment on function public.argus_server_time() is
  'Capability-/Zeit-Probe (Phase 6.5): {now: Server-ms, v: Schema-Version 26}. Ohne Claims aufrufbar.';

-- ── 5) Herkunft und Nachzügler ──────────────────────────────────────────────

-- 5a) Herkunftsprotokoll (D6.5-09): die App meldet automatisch, auf welchem Weg
--     Patienten beim Server angekommen sind (direkt / nachgereicht). Nur
--     Gerätenummer, Weg, zufällige Patienten-IDs und Zähler — kein Patienteninhalt.
create or replace function public.argus_log_herkunft(
  p_ccp_id  uuid,
  p_dev     int,
  p_weg     text,
  p_ids     text[],
  p_kuerzel text default ''
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_ccp record;
  v_ids text[];
  v_n   int;
begin
  select id, praesidium_id, closed_at into v_ccp
  from public.ccps where id = p_ccp_id;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  if p_weg is null or p_weg not in ('direkt', 'nachgereicht') then
    return jsonb_build_object('error', 'Ungültiger Weg');
  end if;

  -- offen ODER innerhalb der 24-h-Nachfrist nach dem Abschluss
  if v_ccp.closed_at is not null and v_now >= v_ccp.closed_at + 86400000 then
    return jsonb_build_object('error', 'Nachfrist abgelaufen');
  end if;

  if p_dev is null or p_dev < 1 or p_dev > 99 then
    return jsonb_build_object('error', 'Ungültige Gerätenummer');
  end if;

  -- auf 200 gekürzt, nur das Muster zufälliger Patienten-IDs
  select coalesce(array_agg(t.x order by t.o), '{}'::text[]) into v_ids
  from (select u.x, u.o
          from unnest(coalesce(p_ids, '{}'::text[])) with ordinality as u(x, o)
         where u.o <= 200
           and u.x ~ '^[A-Za-z0-9_-]{1,40}$') t;
  v_n := coalesce(array_length(v_ids, 1), 0);

  if v_n = 0 then
    return jsonb_build_object('ok', true, 'n', 0);
  end if;

  insert into public.governance_log (at, ccp_id, kuerzel, action, detail)
    values (v_now, p_ccp_id, left(btrim(coalesce(p_kuerzel, '')), 40), 'herkunft',
            jsonb_build_object('dev', p_dev, 'fuer', p_dev, 'weg', p_weg,
                               'ids', to_jsonb(v_ids), 'n', v_n));

  return jsonb_build_object('ok', true, 'n', v_n);
end;
$function$;
grant execute on function public.argus_log_herkunft(uuid, int, text, text[], text) to anon;

comment on function public.argus_log_herkunft(uuid, int, text, text[], text) is
  'Herkunftsereignis (Phase 6.5): Gerät, Weg (direkt|nachgereicht), zufällige Patienten-IDs (max. 200, Muster-geprüft) in governance_log.detail. Solange der CCP offen ist oder höchstens 24 h geschlossen. Kein Patienteninhalt.';

-- 5b) Nachzügler-Annahme nach dem Abschluss.
-- Keine RLS-Lockerung (D6.5-13, Pitfall 1): ALL-Policies gelten auch für SELECT —
-- Nachfrist ausschließlich über diesen RPC. Annahme nur, wenn
--   * der Aufrufer zum Präsidium des CCP gehört (oder Master ist),
--   * der CCP abgeschlossen ist, closed_at höchstens 24 h zurückliegt und
--     purge_after nicht erreicht ist,
--   * das Gerät in ccp_devices des CCP(-Verbunds) steht.
-- Je Element nur Whitelist-Spalten; Schreiben per Upsert, damit der Merge-Trigger
-- argus_patients_merge_biu greift (Grabsteine bleiben geschützt). Bestehende Zeilen
-- werden nur aktualisiert, wenn sie zum selben CCP gehören.
-- Rückgabe: nur Zähler, nie Patientendaten.
create or replace function public.argus_late_push(
  p_ccp_id  uuid,
  p_dev     int,
  p_rows    jsonb,
  p_kuerzel text default ''
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  -- Owner-Entscheid offen: 24 h (CONTEXT)
  v_nachfrist constant bigint := 86400000;
  c_cols      constant text[] := array[
    'id','ccp_id','num','ccp','cat','status','prio','ready','tq_start','tq_site',
    'created','last_triage','updated','name','age','gender','allergies','pup_re','pup_li',
    'vit','tx','inj','moi','injury','fr','notes','by','photo','fts',
    'deleted_at','deleted_by','deleted_dev'];
  v_now        bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_ccp        record;
  v_ids        uuid[];
  v_elem       jsonb;
  v_el         jsonb;
  v_rec        public.patients;
  v_photo_dead boolean;
  v_cnt        int;
  v_ok         int := 0;
  v_skip       int := 0;
  v_log        text[] := '{}'::text[];
begin
  select id, praesidium_id, merge_group_id, closed_at, purge_after, photo_purge_after into v_ccp
  from public.ccps where id = p_ccp_id;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  if v_ccp.closed_at is null then
    return jsonb_build_object('error', 'CCP offen');
  end if;
  if v_now >= v_ccp.closed_at + v_nachfrist
     or (v_ccp.purge_after is not null and v_now >= v_ccp.purge_after) then
    return jsonb_build_object('error', 'Nachfrist abgelaufen');
  end if;

  -- CCP-IDs des Verbunds (der eigene CCP ist immer dabei)
  select coalesce(array_agg(c.id), array[p_ccp_id]) into v_ids
  from public.ccps c
  where c.id = p_ccp_id
     or (v_ccp.merge_group_id is not null and c.merge_group_id = v_ccp.merge_group_id);

  if p_dev is null
     or not exists (select 1 from public.ccp_devices d
                     where d.device_no = p_dev and d.ccp_id = any (v_ids)) then
    return jsonb_build_object('error', 'Gerät unbekannt');
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return jsonb_build_object('error', 'Ungültige Daten');
  end if;
  if jsonb_array_length(p_rows) > 200 then
    return jsonb_build_object('error', 'Zu viele Zeilen');
  end if;
  if pg_column_size(p_rows) > 10485760 then
    return jsonb_build_object('error', 'Daten zu groß');
  end if;

  v_photo_dead := (v_ccp.photo_purge_after is not null and v_ccp.photo_purge_after <= v_now);

  for v_elem in select e.value from jsonb_array_elements(p_rows) e loop
    begin
      if jsonb_typeof(v_elem) <> 'object' then
        v_skip := v_skip + 1;
        continue;
      end if;

      -- nur Whitelist-Spalten
      select coalesce(jsonb_object_agg(j.key, j.value), '{}'::jsonb) into v_el
      from jsonb_each(v_elem) j
      where j.key = any (c_cols);

      if coalesce(v_el->>'id', '') = '' or (v_el->>'ccp_id') is null
         or not ((v_el->>'ccp_id')::uuid = any (v_ids)) then
        v_skip := v_skip + 1;
        continue;
      end if;

      -- Foto nur, solange die Foto-Frist nicht erreicht ist
      if v_photo_dead then
        v_el := v_el - 'photo';
      end if;

      v_rec := jsonb_populate_record(null::public.patients, v_el);

      insert into public.patients as pt
        (id, ccp_id, num, ccp, cat, status, prio, ready, tq_start, tq_site,
         created, last_triage, updated, name, age, gender, allergies, pup_re, pup_li,
         vit, tx, inj, moi, injury, fr, notes, "by", photo, fts,
         deleted_at, deleted_by, deleted_dev)
      values
        (v_rec.id, v_rec.ccp_id, coalesce(v_rec.num, 1), coalesce(v_rec.ccp, 'A'),
         coalesce(v_rec.cat, 'T3'), coalesce(v_rec.status, 'active'),
         coalesce(v_rec.prio, false), coalesce(v_rec.ready, false), v_rec.tq_start, v_rec.tq_site,
         coalesce(v_rec.created, 0), coalesce(v_rec.last_triage, 0), coalesce(v_rec.updated, 0),
         coalesce(v_rec.name, ''), coalesce(v_rec.age, ''), coalesce(v_rec.gender, ''),
         coalesce(v_rec.allergies, ''), coalesce(v_rec.pup_re, ''), coalesce(v_rec.pup_li, ''),
         coalesce(v_rec.vit, '{"af": "", "hf": "", "rr": "", "avpu": "", "pain": "", "spo2": ""}'::jsonb),
         coalesce(v_rec.tx, '{}'::jsonb), coalesce(v_rec.inj, '[]'::jsonb),
         coalesce(v_rec.moi, ''), coalesce(v_rec.injury, ''), coalesce(v_rec.fr, ''),
         coalesce(v_rec.notes, ''), coalesce(v_rec."by", ''), v_rec.photo,
         coalesce(v_rec.fts, '{}'::jsonb),
         v_rec.deleted_at, v_rec.deleted_by, v_rec.deleted_dev)
      on conflict (id) do update set
        cat         = case when v_el ? 'cat'         then excluded.cat         else pt.cat         end,
        status      = case when v_el ? 'status'      then excluded.status      else pt.status      end,
        prio        = case when v_el ? 'prio'        then excluded.prio        else pt.prio        end,
        ready       = case when v_el ? 'ready'       then excluded.ready       else pt.ready       end,
        tq_start    = case when v_el ? 'tq_start'    then excluded.tq_start    else pt.tq_start    end,
        tq_site     = case when v_el ? 'tq_site'     then excluded.tq_site     else pt.tq_site     end,
        last_triage = case when v_el ? 'last_triage' then excluded.last_triage else pt.last_triage end,
        updated     = case when v_el ? 'updated'     then excluded.updated     else pt.updated     end,
        name        = case when v_el ? 'name'        then excluded.name        else pt.name        end,
        age         = case when v_el ? 'age'         then excluded.age         else pt.age         end,
        gender      = case when v_el ? 'gender'      then excluded.gender      else pt.gender      end,
        allergies   = case when v_el ? 'allergies'   then excluded.allergies   else pt.allergies   end,
        pup_re      = case when v_el ? 'pup_re'      then excluded.pup_re      else pt.pup_re      end,
        pup_li      = case when v_el ? 'pup_li'      then excluded.pup_li      else pt.pup_li      end,
        vit         = case when v_el ? 'vit'         then excluded.vit         else pt.vit         end,
        tx          = case when v_el ? 'tx'          then excluded.tx          else pt.tx          end,
        inj         = case when v_el ? 'inj'         then excluded.inj         else pt.inj         end,
        moi         = case when v_el ? 'moi'         then excluded.moi         else pt.moi         end,
        injury      = case when v_el ? 'injury'      then excluded.injury      else pt.injury      end,
        fr          = case when v_el ? 'fr'          then excluded.fr          else pt.fr          end,
        notes       = case when v_el ? 'notes'       then excluded.notes       else pt.notes       end,
        photo       = case when v_el ? 'photo'       then excluded.photo       else pt.photo       end,
        fts         = case when v_el ? 'fts'         then excluded.fts         else pt.fts         end,
        deleted_at  = case when v_el ? 'deleted_at'  then excluded.deleted_at  else pt.deleted_at  end,
        deleted_by  = case when v_el ? 'deleted_by'  then excluded.deleted_by  else pt.deleted_by  end,
        deleted_dev = case when v_el ? 'deleted_dev' then excluded.deleted_dev else pt.deleted_dev end
      where pt.ccp_id = excluded.ccp_id;
      get diagnostics v_cnt = row_count;

      if v_cnt > 0 then
        v_ok := v_ok + 1;
        if (v_el->>'id') ~ '^[A-Za-z0-9_-]{1,40}$' then
          v_log := v_log || (v_el->>'id');
        end if;
      else
        v_skip := v_skip + 1;   -- Zeile gehört zu einem anderen CCP
      end if;
    exception when others then
      v_skip := v_skip + 1;     -- ungültiger Wert o. Ä.: Element überspringen
    end;
  end loop;

  -- genau EIN Protokolleintrag je Aufruf
  insert into public.governance_log (at, ccp_id, kuerzel, action, detail)
    values (v_now, p_ccp_id, left(btrim(coalesce(p_kuerzel, '')), 40), 'herkunft',
            jsonb_build_object('dev', p_dev, 'fuer', p_dev, 'weg', 'nachfrist',
                               'ids', to_jsonb(v_log[1:200]), 'n', v_ok));

  return jsonb_build_object('ok', v_ok, 'skipped', v_skip, 'now', v_now);
end;
$function$;
grant execute on function public.argus_late_push(uuid, int, jsonb, text) to anon;

comment on function public.argus_late_push(uuid, int, jsonb, text) is
  'Nachzügler-Annahme nach dem Einsatz-Abschluss (Phase 6.5, D6.5-13): nur Präsidium des CCP, höchstens 24 h nach closed_at, vor purge_after, Gerät in ccp_devices des Verbunds, max. 200 Zeilen/10 MB, Spalten-Whitelist, Upsert über den Merge-Trigger. Keine RLS-Lockerung. Rückgabe nur Zähler.';

-- ── 6) argus_governance_protokoll: + devices, + herkunft ────────────────────
-- Basis = 0025-Fassung 1:1 (Verbund-Auflösung, Grabstein-Filter, ohne conf, verworfen_n);
-- additiv zwei Schlüssel für den Export-Abschnitt Datenherkunft (D6.5-09, D6.5-15).
create or replace function public.argus_governance_protokoll(p_ccp_id uuid, p_kuerzel text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now        bigint := (extract(epoch from now())*1000)::bigint;
  v_ccp        record;
  v_ccps       jsonb;
  v_patients   jsonb;
  v_verworfen  bigint;
  v_checklists jsonb;
  v_ids        uuid[];
  v_devices    jsonb;
  v_herkunft   jsonb;
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
    raise exception 'Einsatz noch offen — Einsatzprotokolle gibt es nur für abgeschlossene Einsätze';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id',                c.id,
           'kennung',           c.kennung,
           'einsatz_typ',       c.einsatz_typ,
           'closed_at',         c.closed_at,
           'purge_after',       c.purge_after,
           'photo_purge_after', c.photo_purge_after,
           'ort',               c.ort
         ) order by c.kennung), '[]'::jsonb),
         coalesce(array_agg(c.id), array[p_ccp_id])
  into v_ccps, v_ids
  from public.ccps c
  where c.id = p_ccp_id
     or (v_ccp.merge_group_id is not null and c.merge_group_id = v_ccp.merge_group_id);

  -- Patienten ohne 'photo' (s. o.), ohne Sperr-Interna ('locked_by'/'locked_at'),
  -- plus has_photo-Flag für den Lazy-Load der Leitungs-Seite.
  select coalesce(jsonb_agg(
           (to_jsonb(p) - 'photo' - 'locked_by' - 'locked_at' - 'conf')
             || jsonb_build_object('has_photo', p.photo is not null)
           order by p.ccp, p.num), '[]'::jsonb)
  into v_patients
  from public.patients p
  where (p.ccp_id = p_ccp_id
         or (v_ccp.merge_group_id is not null
             and p.ccp_id in (select id from public.ccps where merge_group_id = v_ccp.merge_group_id)))
    and p.deleted_at is null;

  -- Grabsteine (verworfene Patienten) erscheinen nicht in der Liste, nur als Zähler.
  select count(*)
  into v_verworfen
  from public.patients p
  where (p.ccp_id = p_ccp_id
         or (v_ccp.merge_group_id is not null
             and p.ccp_id in (select id from public.ccps where merge_group_id = v_ccp.merge_group_id)))
    and p.deleted_at is not null;

  select coalesce(jsonb_agg(to_jsonb(k)), '[]'::jsonb)
  into v_checklists
  from public.checklists k
  where k.ccp_id = p_ccp_id
     or (v_ccp.merge_group_id is not null
         and k.ccp_id in (select id from public.ccps where merge_group_id = v_ccp.merge_group_id));

  -- Geräteregister des Einsatzes (Kennung + Gerätenummer, Verbund-Anzeige "A·3")
  select coalesce(jsonb_agg(jsonb_build_object(
           'kennung',     c.kennung,
           'device_no',   d.device_no,
           'operator',    d.operator,
           'first_seen',  d.first_seen,
           'last_seen',   d.last_seen,
           'open_n',      d.open_n,
           'app_version', d.app_version,
           'left_at',     d.left_at,
           'left_by',     d.left_by,
           'lost_at',     d.lost_at,
           'lost_by',     d.lost_by
         ) order by c.kennung, d.device_no), '[]'::jsonb)
  into v_devices
  from public.ccp_devices d
  join public.ccps c on c.id = d.ccp_id
  where d.ccp_id = any (v_ids);

  -- Datenherkunft: Herkunfts- und Geräteereignisse (pseudonym, ohne Patienteninhalt)
  select coalesce(jsonb_agg(jsonb_build_object(
           'at',      g.at,
           'kuerzel', g.kuerzel,
           'action',  g.action,
           'detail',  g.detail
         ) order by g.at), '[]'::jsonb)
  into v_herkunft
  from public.governance_log g
  where g.ccp_id = any (v_ids)
    and g.action in ('herkunft', 'geraet_verlassen', 'geraet_abgemeldet',
                     'geraet_abmeldung_aufgehoben', 'geraet_wieder_beigetreten');

  -- Zwangs-Log VOR der Rückgabe — jeder Protokoll-Abruf = ein Eintrag (D-01, D-17).
  insert into public.governance_log (at, ccp_id, kuerzel, action)
    values (v_now, p_ccp_id, btrim(p_kuerzel), 'protokoll_view');

  return jsonb_build_object(
    'ccps',       v_ccps,
    'patients',   v_patients,
    'verworfen_n', v_verworfen,
    'checklists', v_checklists,
    'devices',    v_devices,
    'herkunft',   v_herkunft
  );
end;
$function$;
grant execute on function public.argus_governance_protokoll(uuid, text) to anon;

-- ── 7) argus_run_purge: Neufassung (Pitfall 3) ──────────────────────────────
-- Rumpf = 0016-Fassung (a Foto, b Frist, c Auffangnetz, d Log-Retention,
-- e audit_log-Retention) + Schritt (f) Token-Hygiene aus 0006 (ging mit 0016 verloren:
-- 0016 baute auf 0004 statt auf 0006 auf) + ccp_devices-Löschung in (b) und (c).
-- Rückgabe-JSON nur additiv: token_hygiene, devices. purge_log unverändert.
create or replace function public.argus_run_purge()
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now    bigint := (extract(epoch from now())*1000)::bigint;
  v_cutoff bigint := (extract(epoch from now())*1000)::bigint - 60::bigint * 86400000;
  r        record;
  v_pat    int;
  v_pho    int;
  v_chk    int;
  v_dev    int;
  c_foto    int := 0;  n_foto        int := 0;
  c_frist   int := 0;  n_pat_frist   int := 0;  n_chk_frist   int := 0;
  c_inaktiv int := 0;  n_pat_inaktiv int := 0;  n_chk_inaktiv int := 0;
  n_glog    int := 0;  n_plog        int := 0;
  n_alog    int := 0;
  n_tok     int := 0;
  n_dev     int := 0;
begin
  -- (a) Foto-Purge: Fotos endgültig nullen, Restdatensatz bleibt unberührt.
  for r in
    select c.id, c.kennung from public.ccps c
    where c.photo_purge_after is not null and c.photo_purge_after <= v_now
      and exists (select 1 from public.patients p where p.ccp_id = c.id and p.photo is not null)
  loop
    update public.patients set photo = null where ccp_id = r.id and photo is not null;
    get diagnostics v_pho = row_count;
    insert into public.purge_log (ccp_id, kennung, reason, photo_count)
      values (r.id, r.kennung, 'foto_72h', v_pho);
    c_foto := c_foto + 1;
    n_foto := n_foto + v_pho;
  end loop;

  -- (b) Daten-Purge nach Fristablauf: Patienten + Checklisten + Geräteregister
  -- löschen; die ccps-Row bleibt als inhaltsleerer Tombstone (ort='',
  -- master_medic='', join_token=null) — Geräte erkennen daran den Abschluss für
  -- die lokale Bereinigung. Geräte-Zeilen allein reichen als Anlass (Pitfall 12).
  for r in
    select c.id, c.kennung from public.ccps c
    where c.purge_after is not null and c.purge_after <= v_now
      and (    exists (select 1 from public.patients     p where p.ccp_id = c.id)
            or exists (select 1 from public.checklists   k where k.ccp_id = c.id)
            or exists (select 1 from public.ccp_devices  d where d.ccp_id = c.id)
            or coalesce(c.ort,'') <> '' or coalesce(c.master_medic,'') <> ''
            or c.join_token is not null )
  loop
    select count(*), count(photo) into v_pat, v_pho from public.patients   where ccp_id = r.id;
    select count(*)               into v_chk        from public.checklists where ccp_id = r.id;
    delete from public.patients   where ccp_id = r.id;
    delete from public.checklists where ccp_id = r.id;
    delete from public.ccp_devices where ccp_id = r.id;
    get diagnostics v_dev = row_count;
    update public.ccps set ort = '', master_medic = '', join_token = null where id = r.id;
    insert into public.purge_log (ccp_id, kennung, reason, patient_count, photo_count, checklist_count)
      values (r.id, r.kennung, 'frist', v_pat, v_pho, v_chk);
    c_frist     := c_frist + 1;
    n_pat_frist := n_pat_frist + v_pat;
    n_chk_frist := n_chk_frist + v_chk;
    n_dev       := n_dev + v_dev;
  end loop;

  -- (c) Auffangnetz: offene CCPs ohne Aktivität > 60 Tage. Letzte Aktivität =
  -- greatest(created_at als ms, max(patients.updated)) — ccps.updated_at wird
  -- von der App nicht gepflegt. Setzt zusätzlich closed_at (Guard: Row matcht
  -- danach weder (c) noch — mangels purge_after — (b)).
  for r in
    select c.id, c.kennung from public.ccps c
    where c.closed_at is null
      and greatest(
            coalesce((extract(epoch from c.created_at)*1000)::bigint, 0),
            coalesce((select max(p.updated) from public.patients p where p.ccp_id = c.id), 0)
          ) <= v_cutoff
  loop
    select count(*), count(photo) into v_pat, v_pho from public.patients   where ccp_id = r.id;
    select count(*)               into v_chk        from public.checklists where ccp_id = r.id;
    delete from public.patients   where ccp_id = r.id;
    delete from public.checklists where ccp_id = r.id;
    delete from public.ccp_devices where ccp_id = r.id;
    get diagnostics v_dev = row_count;
    update public.ccps set closed_at = v_now, ort = '', master_medic = '', join_token = null
      where id = r.id;
    insert into public.purge_log (ccp_id, kennung, reason, patient_count, photo_count, checklist_count)
      values (r.id, r.kennung, 'inaktiv', v_pat, v_pho, v_chk);
    c_inaktiv     := c_inaktiv + 1;
    n_pat_inaktiv := n_pat_inaktiv + v_pat;
    n_chk_inaktiv := n_chk_inaktiv + v_chk;
    n_dev         := n_dev + v_dev;
  end loop;

  -- (d) Log-Retention 12 Monate (D-01): governance_log- und purge_log-
  -- Einträge jenseits der Frist löschen. governance_log.at = bigint-ms
  -- (Cutoff: 365 Tage in ms), purge_log.at = timestamptz (kalendarisches
  -- Zwölf-Monats-Intervall). Bewusst KEIN purge_log-/governance_log-Eintrag
  -- über diesen Schritt (keine Rekursion, kein Eintrag bei leerem Ergebnis).
  delete from public.governance_log
    where at is not null and at <= v_now - 365::bigint * 86400000;
  get diagnostics n_glog = row_count;

  delete from public.purge_log
    where at is not null and at <= now() - interval '12 months';
  get diagnostics n_plog = row_count;

  -- (e) audit_log-Retention 12 Monate (D-07, § 73 PolG BW): T4-Audit-Einträge
  -- jenseits der Frist löschen. audit_log.at = bigint-ms (identische Konvention
  -- wie governance_log.at, Cutoff: 365 Tage in ms). Kein Log-Eintrag (s. o.).
  delete from public.audit_log
    where at is not null and at <= v_now - 365::bigint * 86400000;
  get diagnostics n_alog = row_count;

  -- (f) Token-Hygiene (0006, Owner-Entscheid 2026-06-12): verbrauchte Einmal-Codes
  -- 6 Monate (182 Tage in ms) nach ihrer Einlösung löschen. Trifft NUR
  -- single_use-Codes mit gesetztem used_at — Dauerhaft/Beobachter/Master
  -- haben kein used_at bzw. sind nicht single_use. Kein Log-Eintrag (s. o.).
  delete from public.access_tokens
    where single_use
      and used_at is not null
      and used_at <= v_now - 182::bigint * 86400000;
  get diagnostics n_tok = row_count;

  return jsonb_build_object(
    'foto',    jsonb_build_object('ccps', c_foto,    'fotos', n_foto),
    'frist',   jsonb_build_object('ccps', c_frist,   'patients', n_pat_frist,   'checklists', n_chk_frist),
    'inaktiv', jsonb_build_object('ccps', c_inaktiv, 'patients', n_pat_inaktiv, 'checklists', n_chk_inaktiv),
    'log_retention', jsonb_build_object('governance_log', n_glog, 'purge_log', n_plog),
    'audit_log_retention', jsonb_build_object('audit_log', n_alog),
    'token_hygiene', jsonb_build_object('einmal_codes', n_tok),
    'devices', jsonb_build_object('rows', n_dev)
  );
end;
$function$;

grant execute on function public.argus_run_purge() to anon;

comment on function public.argus_run_purge() is
  'Stündlicher Purge-Lauf (pg_cron argus_purge, 17 * * * *): (a) Foto-Purge, '
  '(b) Daten-Purge nach Fristablauf inkl. Geräteregister ccp_devices, '
  '(c) Inaktivitäts-Auffangnetz inkl. ccp_devices, '
  '(d) Log-Retention: governance_log/purge_log älter 12 Monate, '
  '(e) audit_log-Retention 12 Monate, '
  '(f) Token-Hygiene: verbrauchte Einmal-Codes nach 182 Tagen (0006). '
  'Neufassung 0026 = 0016 + Token-Hygiene + ccp_devices. '
  'Die Schritte (d)-(f) erzeugen selbst keinen Log-Eintrag.';

-- ── 8) Kataloge der governance_log-Spalten ──────────────────────────────────
comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view | lage_view | gast_join | protokoll_export | admin_login | admin_gast_issue | admin_gast_revoke | admin_dauer_issue | admin_code_revoke | herkunft | geraet_verlassen | geraet_abgemeldet | geraet_abmeldung_aufgehoben | geraet_wieder_beigetreten';

comment on column public.governance_log.detail is
  'Ereignis-Detail (jsonb, Phase 6.5), pseudonym: Gerätenummer, Weg (direkt|nachgereicht|nachfrist), zufällige Patienten-IDs, Zähler. Kein Patienteninhalt. Retention 365 Tage wie das übrige governance_log.';
