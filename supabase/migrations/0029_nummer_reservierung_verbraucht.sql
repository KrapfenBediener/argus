-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0029 — Nummern-Reservierung: verbrauchte Nummer direkt melden
--                  (argus_reserve_num(p_ccp_id, p_dev, p_used), argus_server_time v:29)
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- Phase 6.5, Nachbesserung zu 0028 (Entscheidung D6.5-21).
--
-- Befund (Owner-UAT 2026-10-17, App 0.34.4): Im Online-Betrieb trugen neue
-- Patienten dauerhaft die Gerätenummer („A-7-1"). Ursache: Mit 0028 liefert
-- argus_reserve_num dieselbe Nummer erneut, bis ein Patient mit dieser Nummer
-- AUF DEM SERVER liegt. Die App fragte deshalb erst nach dem erfolgreichen
-- Upload nach der nächsten Nummer; kollidierte der Upload (z. B. mit sofortigem
-- Prio/TQ im Schnellmenü) oder blockierte das offene Schnellmenü die
-- Hintergrund-Aktualisierung, lag beim nächsten Anlegen keine Nummer bereit und
-- die App nahm den Offline-Weg mit Gerätekennung.
--
-- Lösung: Das Gerät meldet beim Nachfragen die soeben verbrauchte Nummer mit
-- (p_used). Entspricht sie der eigenen Reservierung, gilt diese sofort als
-- verbraucht und die nächste freie Nummer wird vergeben — unabhängig davon, ob
-- der Patient schon hochgeladen ist. Ohne p_used verhält sich die Funktion wie
-- 0028 (idempotent bei Neustart/Timeout).
--
-- Die 2-Parameter-Fassung aus 0028 wird ersetzt (Default p_used = null hält
-- Aufrufe von App 0.34.4 kompatibel). Keine RLS-Änderung.
-- Reihenfolge: … → 0028 → 0029. Idempotent.
-- ══════════════════════════════════════════════════════════════════════════

drop function if exists public.argus_reserve_num(uuid, int);
drop function if exists public.argus_reserve_num(uuid, int, int);

create or replace function public.argus_reserve_num(p_ccp_id uuid, p_dev int, p_used int default null)
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

  select d.reserved_num into v_res
  from public.ccp_devices d
  where d.ccp_id = p_ccp_id and d.device_no = p_dev;

  -- Wiederverwenden nur, wenn die Reservierung weder als verbraucht gemeldet
  -- (p_used) noch von einem Patienten belegt ist.
  if v_res is not null
     and (p_used is null or p_used <> v_res)
     and not exists (select 1 from public.patients p
                      where p.ccp_id = p_ccp_id and p.num = v_res) then
    return jsonb_build_object('start', v_res, 'count', 1, 'reused', true);
  end if;

  -- Neue Nummer (selbstheilend wie argus_claim_nums); eine gemeldete verbrauchte
  -- Nummer zählt mit, auch wenn ihr Patient noch nicht hochgeladen ist.
  v_start := greatest(
    coalesce(v_ccp.next_num, 1),
    coalesce((select max(p.num) from public.patients p where p.ccp_id = p_ccp_id), 0) + 1,
    coalesce(p_used, 0) + 1
  );
  update public.ccps set next_num = v_start + 1 where id = p_ccp_id;
  insert into public.ccp_devices (ccp_id, device_no, operator, first_seen, last_seen, reserved_num)
    values (p_ccp_id, p_dev, '', v_now, v_now, v_start)
  on conflict (ccp_id, device_no) do update set
    reserved_num = excluded.reserved_num;
  return jsonb_build_object('start', v_start, 'count', 1, 'reused', false);
end;
$function$;
grant execute on function public.argus_reserve_num(uuid, int, int) to anon;
comment on function public.argus_reserve_num(uuid, int, int) is
  'Nummern-Reservierung je Gerät (0028/0029, D6.5-21): idempotent bei Neustart/Timeout; p_used meldet die soeben verbrauchte Nummer → sofort die nächste, auch vor dem Upload des Patienten. Berechtigung: Master oder eigenes Präsidium; Einsatz muss offen sein.';

create or replace function public.argus_server_time()
  returns jsonb
  language plpgsql
  volatile
  set search_path to 'public'
as $function$
begin
  return jsonb_build_object(
    'now', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'v',   29
  );
end;
$function$;
grant execute on function public.argus_server_time() to anon;
comment on function public.argus_server_time() is
  'Capability-/Zeit-Probe (Phase 6.5): {now: Server-ms, v: Schema-Version 29}. Ohne Claims aufrufbar.';
