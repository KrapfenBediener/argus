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
