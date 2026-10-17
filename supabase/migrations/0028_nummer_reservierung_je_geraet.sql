-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0028 — Idempotente Nummern-Reservierung je Gerät
--                  (ccp_devices.reserved_num, argus_reserve_num, argus_server_time v:28)
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- Phase 6.5, Gap-Plan 11 (Entscheidung D6.5-21).
--
-- Befund (Owner-UAT 2026-10-17): „10 Patienten im CCP, angezeigte lfd. Nr. 63."
-- Ursache: Die App hält die nächste Online-Nummer vorab bereit und holte sie
-- bisher mit argus_claim_nums(p_count=1). Diese RPC erhöht den Server-Zähler
-- (ccps.next_num) sofort und unwiderruflich; die Reservierung selbst lag nur im
-- Arbeitsspeicher der App. Sie ging verloren bei (1) App-Neustart/Update,
-- (2) Client-Abbruch nach 2,5 s, obwohl der Server schon vergeben hatte — bei
-- zähem Netz wiederholte das 3,5-s-Intervall den Versuch und verbrannte laufend
-- Nummern —, (3) CCP-Wechsel.
--
-- Lösung: Die Reservierung wird je Gerät auf dem Server gemerkt
-- (ccp_devices.reserved_num) und ist idempotent. Fragt dasselbe Gerät erneut
-- an, solange noch kein Patient im CCP diese Nummer trägt, bekommt es dieselbe
-- Nummer zurück und der Zähler bleibt unverändert. Erst wenn ein Patient mit der
-- reservierten Nummer existiert, wird die nächste freie Nummer vergeben.
-- Lücken entstehen höchstens, wenn ein Gerät den CCP mit offener Reservierung
-- dauerhaft verlässt.
--
-- argus_claim_nums (0008) bleibt unverändert (ältere App-Stände nutzen sie
-- weiter). Keine RLS-Änderung: ccp_devices bleibt nur per RPC beschreibbar.
--
-- Reihenfolge: 0000 → … → 0027 → 0028. Benötigt 0022 (next_device) und 0026
-- (ccp_devices). Einspielen: durch den Owner im Supabase-SQL-Editor.
-- Idempotent (add column if not exists / create or replace).
-- Prüfskript: supabase/probes/0028_nummer_probe.sql (rollt sich selbst zurück).
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1) Spalte: zuletzt reservierte, noch nicht verwendete Nummer des Geräts ──
alter table public.ccp_devices add column if not exists reserved_num int;

-- ── 2) RPC: Nummer für ein Gerät reservieren (idempotent) ───────────────────
-- Fehler als {"error": …} (nie Exception), Prüfreihenfolge wie argus_claim_nums:
-- CCP existiert → Berechtigung → Einsatz offen → Gerätenummer gültig.
create or replace function public.argus_reserve_num(p_ccp_id uuid, p_dev int)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now   bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_ccp   record;
  v_res   int;
  v_start int;
begin
  -- Zeile sperren → parallele Aufrufe (auch desselben Geräts) laufen nacheinander
  select id, praesidium_id, closed_at, next_num, next_device into v_ccp
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
    return jsonb_build_object('error', 'Einsatz abgeschlossen');
  end if;

  if p_dev is null or p_dev < 1 or p_dev > least(99, greatest(coalesce(v_ccp.next_device, 1), 1)) then
    return jsonb_build_object('error', 'Ungültige Gerätenummer');
  end if;

  -- Bestehende Reservierung dieses Geräts, solange noch kein Patient sie trägt
  select d.reserved_num into v_res
  from public.ccp_devices d
  where d.ccp_id = p_ccp_id and d.device_no = p_dev;

  if v_res is not null
     and not exists (select 1 from public.patients p
                      where p.ccp_id = p_ccp_id and p.num = v_res) then
    return jsonb_build_object('start', v_res, 'count', 1, 'reused', true);
  end if;

  -- Neue Nummer wie argus_claim_nums (selbstheilend: nie hinter vergebene Nummern)
  v_start := greatest(
    coalesce(v_ccp.next_num, 1),
    coalesce((select max(p.num) from public.patients p where p.ccp_id = p_ccp_id), 0) + 1
  );

  update public.ccps set next_num = v_start + 1 where id = p_ccp_id;

  -- Gerätezeile anlegen, falls noch kein Heartbeat da war (NOT NULL: first_seen/last_seen)
  insert into public.ccp_devices (ccp_id, device_no, operator, first_seen, last_seen, reserved_num)
    values (p_ccp_id, p_dev, '', v_now, v_now, v_start)
  on conflict (ccp_id, device_no) do update set
    reserved_num = excluded.reserved_num;

  return jsonb_build_object('start', v_start, 'count', 1, 'reused', false);
end;
$function$;
grant execute on function public.argus_reserve_num(uuid, int) to anon;

comment on function public.argus_reserve_num(uuid, int) is
  'Idempotente Nummern-Reservierung je Gerät (0028, D6.5-21): liefert dieselbe Nummer erneut, solange kein Patient im CCP sie trägt (Zähler unverändert); sonst die nächste freie Nummer wie argus_claim_nums und merkt sie in ccp_devices.reserved_num. Berechtigung: Master oder eigenes Präsidium; Einsatz muss offen sein.';

-- ── 3) Capability-Probe v28 ─────────────────────────────────────────────────
-- Sonst identisch zu 0027. Der Client nutzt argus_reserve_num erst bei v >= 28.
create or replace function public.argus_server_time()
  returns jsonb
  language plpgsql
  volatile
  set search_path to 'public'
as $function$
begin
  return jsonb_build_object(
    'now', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'v',   28
  );
end;
$function$;

grant execute on function public.argus_server_time() to anon;

comment on function public.argus_server_time() is
  'Capability-/Zeit-Probe (Phase 6.5): {now: Server-ms, v: Schema-Version 28}. Ohne Claims aufrufbar.';
