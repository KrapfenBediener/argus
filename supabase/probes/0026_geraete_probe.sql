-- ══════════════════════════════════════════════════════════════════════════
-- Prüfskript 0026 — Geräteregister, Nachfrist, Herkunft gegen die LIVE-Datenbank
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- KEINE Migration. Nach dem Einspielen von 0026_geraete_nachfrist_herkunft.sql
-- im Supabase-SQL-Editor ausführen (ein Query, "Run").
--
-- Das Skript rollt sich SELBST zurück: es endet immer mit einer Fehlermeldung
-- (raise exception), wodurch die gesamte Transaktion verworfen wird — keine
-- Rückstände, keine Bereinigung nötig. Das gilt auch für den darin ausgelösten
-- argus_run_purge()-Lauf (P12): sein Effekt wird mit zurückgerollt.
--
-- Erwartete Ausgabe (als FEHLER angezeigt, das ist beabsichtigt):
--     PROBE 0026 ERGEBNIS: N von N ok
-- beide Zahlen gleich und KEINE Fehlerliste dahinter. Bei Abweichung steht
-- hinter der Zahl, welche Prüfung (P01-P13) was geliefert hat.
--
-- Was geprüft wird:
--   P01 Heartbeat legt die Zeile an, Server stempelt last_seen
--   P02 fremdes Präsidium → Keine Berechtigung
--   P03 Gerätenummer 100 → Ungültige Gerätenummer
--   P04 Verlassen setzt left_at + governance_log geraet_verlassen
--   P05 Heartbeat lässt left_at stehen; mit Wiederbeitritt wird es gelöscht
--   P06 Abmelden/Aufheben; Heartbeat löscht die Abmelde-Vermutung
--   P07 Herkunft direkt (3 IDs), ungültiger Weg, ID-Muster-Filter
--   P08 Late-Push nach Abschluss (Verbund-Gerät, Whitelist, Fremd-CCP-Schutz)
--   P09 Late-Push mit alter Zeile erweckt keinen Grabstein
--   P10 Nachfrist abgelaufen / purge_after erreicht / Gerät unbekannt / CCP offen
--   P11 RLS: geschlossener CCP für anon 0 Patienten; ccp_devices nur eigenes
--       Präsidium; Direkt-Schreiben auf ccp_devices scheitert
--   P12 argus_run_purge: Schlüssel token_hygiene + devices, löscht Geräte;
--       argus_server_time liefert v = 26
--   P13 argus_governance_protokoll liefert devices und herkunft
-- Alle Testdaten sind fiktiv (Präsidien "Probe 0026 A/B", Kennungen Z, Y, X, W).
-- ══════════════════════════════════════════════════════════════════════════

do $probe$
declare
  v_pa     uuid;
  v_pb     uuid;
  v_grp    uuid := gen_random_uuid();
  v_ccp    uuid;   -- Z: Verbund mit Y, Präsidium A
  v_ccp2   uuid;   -- Y: Verbund mit Z
  v_ccp3   uuid;   -- X: offen
  v_ccpb   uuid;   -- W: Präsidium B
  v_nowms  bigint;
  v_res    jsonb;
  v_dev    record;
  v_c1     bigint;
  v_c2     bigint;
  v_c3     bigint;
  v_ok2    boolean;
  total    int := 0;
  ok_n     int := 0;
  fails    text := '';
begin
  -- ── Testdaten ───────────────────────────────────────────────────────────────
  insert into public.praesidien (name) values ('Probe 0026 A') returning id into v_pa;
  insert into public.praesidien (name) values ('Probe 0026 B') returning id into v_pb;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('Z', v_pa, 3) returning id into v_ccp;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('Y', v_pa, 3) returning id into v_ccp2;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('X', v_pa, 2) returning id into v_ccp3;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('W', v_pb, 2) returning id into v_ccpb;
  update public.ccps set merge_group_id = v_grp where id in (v_ccp, v_ccp2);

  -- Aufrufer = Präsidium A
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pa)::text, true);

  -- ── P01: Heartbeat legt die Zeile an ──────────────────────────────────────
  v_nowms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_res := public.argus_device_heartbeat(v_ccp, 1, 'ABC', 2, '0.34.0');
  select * into v_dev from public.ccp_devices where ccp_id = v_ccp and device_no = 1;
  total := total + 1;
  if (v_res->>'closed') = 'false' and v_dev.device_no = 1 and v_dev.operator = 'ABC'
     and v_dev.open_n = 2 and v_dev.app_version = '0.34.0'
     and abs(v_dev.last_seen - v_nowms) < 60000 and v_dev.first_seen = v_dev.last_seen then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P01 res=' || v_res::text || ' last_seen=' || coalesce(v_dev.last_seen::text, 'fehlt');
  end if;

  -- ── P02: fremdes Präsidium ─────────────────────────────────────────────────
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pb)::text, true);
  v_res := public.argus_device_heartbeat(v_ccp, 1, 'EVIL', 0, 'x');
  total := total + 1;
  if v_res->>'error' = 'Keine Berechtigung'
     and (select operator from public.ccp_devices where ccp_id = v_ccp and device_no = 1) = 'ABC' then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P02 res=' || v_res::text;
  end if;
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pa)::text, true);

  -- ── P03: Gerätenummer außerhalb des Bereichs ───────────────────────────────
  v_res := public.argus_device_heartbeat(v_ccp, 100, 'ABC', 0, 'x');
  total := total + 1;
  if v_res->>'error' = 'Ungültige Gerätenummer'
     and not exists (select 1 from public.ccp_devices where ccp_id = v_ccp and device_no = 100) then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P03 res=' || v_res::text;
  end if;

  -- ── P04: Verlassen ─────────────────────────────────────────────────────────
  v_res := public.argus_device_leave(v_ccp, 1, 'ABC', 1);
  select * into v_dev from public.ccp_devices where ccp_id = v_ccp and device_no = 1;
  total := total + 1;
  if (v_res->>'ok') = 'true' and v_dev.left_at is not null and v_dev.left_by = 'ABC' and v_dev.open_n = 1
     and (select count(*) from public.governance_log
           where ccp_id = v_ccp and action = 'geraet_verlassen' and (detail->>'dev')::int = 1) = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P04 res=' || v_res::text || ' left_at=' || coalesce(v_dev.left_at::text, 'null');
  end if;

  -- ── P05: Heartbeat ohne/mit Wiederbeitritt ─────────────────────────────────
  v_res := public.argus_device_heartbeat(v_ccp, 1, 'ABC', 2, '0.34.0');
  select * into v_dev from public.ccp_devices where ccp_id = v_ccp and device_no = 1;
  v_ok2 := (v_dev.left_at is not null and (v_res->>'left_at') is not null);
  v_res := public.argus_device_heartbeat(v_ccp, 1, 'ABC', 2, '0.34.0', true);
  select * into v_dev from public.ccp_devices where ccp_id = v_ccp and device_no = 1;
  total := total + 1;
  if v_ok2 and v_dev.left_at is null and (v_res->>'left_at') is null
     and (select count(*) from public.governance_log
           where ccp_id = v_ccp and action = 'geraet_wieder_beigetreten') = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P05 ohne_rejoin_behaelt=' || v_ok2::text || ' res=' || v_res::text;
  end if;

  -- ── P06: Abmelden, unbekanntes Gerät, Heartbeat löscht die Vermutung ───────
  v_res := public.argus_device_mark(v_ccp, 1, true, 'MM');
  select * into v_dev from public.ccp_devices where ccp_id = v_ccp and device_no = 1;
  v_ok2 := (v_dev.lost_at is not null and v_dev.lost_by = 'MM'
            and (select count(*) from public.governance_log
                  where ccp_id = v_ccp and action = 'geraet_abgemeldet') = 1);
  total := total + 1;
  if v_ok2 and public.argus_device_mark(v_ccp, 2, true, 'MM')->>'error' = 'Gerät unbekannt' then
    perform public.argus_device_heartbeat(v_ccp, 1, 'ABC', 2, '0.34.0');
    select * into v_dev from public.ccp_devices where ccp_id = v_ccp and device_no = 1;
    perform public.argus_device_mark(v_ccp, 1, false, 'MM');
    if v_dev.lost_at is null
       and exists (select 1 from public.governance_log
                    where ccp_id = v_ccp and action = 'geraet_abmeldung_aufgehoben') then
      ok_n := ok_n + 1;
    else
      fails := fails || ' | P06 Heartbeat/Aufheben: lost_at=' || coalesce(v_dev.lost_at::text, 'null');
    end if;
  else
    fails := fails || ' | P06 Abmelden: ' || v_res::text;
  end if;

  -- ── P07: Herkunft ──────────────────────────────────────────────────────────
  v_res := public.argus_log_herkunft(v_ccp, 1, 'direkt', array['prb26-a1', 'prb26-a2', 'prb26-a3'], 'ABC');
  total := total + 1;
  if (v_res->>'n')::int = 3
     and exists (select 1 from public.governance_log
                  where ccp_id = v_ccp and action = 'herkunft' and detail->>'weg' = 'direkt'
                    and (detail->>'n')::int = 3 and jsonb_array_length(detail->'ids') = 3)
     and public.argus_log_herkunft(v_ccp, 1, 'xyz', array['prb26-a1'], 'ABC')->>'error' = 'Ungültiger Weg'
     and (public.argus_log_herkunft(v_ccp, 1, 'nachgereicht',
            array['good1', 'bad id!', 'x' || repeat('y', 60)], 'ABC')->>'n')::int = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P07 res=' || v_res::text;
  end if;

  -- ── P08: Late-Push nach dem Abschluss ──────────────────────────────────────
  -- Gerät 3 steht in ccp_devices von Y (gleicher Verbund), schiebt Zeilen für Z nach.
  perform public.argus_device_heartbeat(v_ccp2, 3, 'DEF', 0, '0.34.0');
  insert into public.patients (id, ccp_id, num, ccp, name) values ('prb26-X', v_ccpb, 1, 'W', 'orig');
  v_nowms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  update public.ccps
     set closed_at = v_nowms - 3600000,
         purge_after = v_nowms - 3600000 + 72::bigint * 3600000,
         photo_purge_after = v_nowms - 3600000 + 72::bigint * 3600000
   where id in (v_ccp, v_ccp2);

  -- Heartbeat auf geschlossenem CCP: closed=true, keine Schreibwirkung
  v_res := public.argus_device_heartbeat(v_ccp, 2, 'GHI', 0, 'x');
  total := total + 1;
  if (v_res->>'closed') = 'true' and (v_res->>'closed_at') is not null
     and not exists (select 1 from public.ccp_devices where ccp_id = v_ccp and device_no = 2) then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P08a Heartbeat geschlossen: ' || v_res::text;
  end if;

  v_res := public.argus_late_push(v_ccp, 3, jsonb_build_array(
    jsonb_build_object('id', 'prb26-L1', 'ccp_id', v_ccp, 'num', 5, 'ccp', 'Z', 'cat', 'T1',
      'status', 'active', 'name', 'Probe', 'created', v_nowms, 'last_triage', v_nowms, 'updated', v_nowms,
      'locked_by', 'XYZ', 'conf', '[{"g":"vit"}]'::jsonb,
      'fts', jsonb_build_object('stamm', jsonb_build_object('t', v_nowms, 'd', 3))),
    jsonb_build_object('id', 'prb26-F1', 'ccp_id', v_ccpb, 'num', 1, 'ccp', 'W', 'name', 'Fremd'),
    jsonb_build_object('id', 'prb26-X', 'ccp_id', v_ccp, 'num', 1, 'ccp', 'Z', 'name', 'Übernahme')
  ), 'DEF');
  total := total + 1;
  if (v_res->>'ok')::int = 1 and (v_res->>'skipped')::int = 2
     and exists (select 1 from public.patients
                  where id = 'prb26-L1' and ccp_id = v_ccp and name = 'Probe' and locked_by is null and conf = '[]'::jsonb)
     and not exists (select 1 from public.patients where id = 'prb26-F1')
     and (select name from public.patients where id = 'prb26-X') = 'orig'
     and (select count(*) from public.governance_log
           where ccp_id = v_ccp and action = 'herkunft' and detail->>'weg' = 'nachfrist'
             and (detail->>'n')::int = 1) = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P08b late_push res=' || v_res::text;
  end if;

  -- ── P09: alter Stand erweckt keinen Grabstein ──────────────────────────────
  -- Grabstein roh auf dem Server (wie ein verworfener Patient), dann Late-Push ohne del-Stempel.
  insert into public.patients (id, ccp_id, num, ccp, deleted_at, deleted_by, deleted_dev, fts)
    values ('prb26-T1', v_ccp, 7, 'Z', 500, 'MUE', 3, '{"del":{"t":500,"d":3}}'::jsonb);
  v_res := public.argus_late_push(v_ccp, 3, jsonb_build_array(
    jsonb_build_object('id', 'prb26-T1', 'ccp_id', v_ccp, 'num', 7, 'ccp', 'Z', 'status', 'active',
      'name', 'Zombie', 'updated', v_nowms,
      'fts', jsonb_build_object('stamm', jsonb_build_object('t', v_nowms, 'd', 2),
                                'st', jsonb_build_object('t', v_nowms, 'd', 2)))
  ), 'DEF');
  total := total + 1;
  if (select deleted_at from public.patients where id = 'prb26-T1') = 500
     and (select name from public.patients where id = 'prb26-T1') = ''
     and (select status from public.patients where id = 'prb26-T1') = 'verworfen' then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P09 Grabstein: res=' || v_res::text || ' name='
             || coalesce((select name from public.patients where id = 'prb26-T1'), 'fehlt');
  end if;

  -- ── P10: Fehlerfälle ───────────────────────────────────────────────────────
  update public.ccps set closed_at = v_nowms - 25 * 3600000 where id in (v_ccp, v_ccp2);
  v_ok2 := (public.argus_late_push(v_ccp, 3, '[]'::jsonb)->>'error') = 'Nachfrist abgelaufen';
  update public.ccps
     set closed_at = v_nowms - 3600000, purge_after = v_nowms - 1000
   where id in (v_ccp, v_ccp2);
  v_ok2 := v_ok2 and (public.argus_late_push(v_ccp, 3, '[]'::jsonb)->>'error') = 'Nachfrist abgelaufen';
  update public.ccps
     set closed_at = v_nowms - 3600000, purge_after = v_nowms - 3600000 + 72::bigint * 3600000
   where id in (v_ccp, v_ccp2);
  total := total + 1;
  if v_ok2
     and (public.argus_late_push(v_ccp, 9, '[]'::jsonb)->>'error') = 'Gerät unbekannt'
     and (public.argus_late_push(v_ccp3, 1, '[]'::jsonb)->>'error') = 'CCP offen'
     and (public.argus_late_push('00000000-0000-0000-0000-000000000000', 1, '[]'::jsonb)->>'error') = 'CCP nicht gefunden'
     and (public.argus_late_push(v_ccp, 3, '{"a":1}'::jsonb)->>'error') = 'Ungültige Daten' then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P10 Fehlerfälle: Fristen=' || v_ok2::text;
  end if;

  -- ── P11: RLS ───────────────────────────────────────────────────────────────
  v_c1 := -1; v_c2 := -1; v_c3 := -1;
  v_ok2 := false;
  begin
    execute 'set local role anon';
    select count(*) into v_c1 from public.patients where ccp_id in (v_ccp, v_ccp2);
    select count(*) into v_c2 from public.ccp_devices where ccp_id in (v_ccp, v_ccp2);
    begin
      insert into public.ccp_devices (ccp_id, device_no, first_seen, last_seen) values (v_ccp, 2, 1, 1);
    exception when others then
      v_ok2 := true;   -- Direkt-Schreiben abgewiesen (erwartet)
    end;
    perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pb)::text, true);
    select count(*) into v_c3 from public.ccp_devices where ccp_id in (v_ccp, v_ccp2);
    execute 'reset role';
  exception when others then
    execute 'reset role';
    fails := fails || ' | P11 Ausnahme: ' || sqlerrm;
  end;
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pa)::text, true);
  total := total + 1;
  if v_c1 = 0 and v_c2 > 0 and v_c3 = 0 and v_ok2 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P11 patients=' || v_c1 || ' devices_eigen=' || v_c2 || ' devices_fremd=' || v_c3
             || ' direkt_geschrieben=' || (not v_ok2)::text;
  end if;

  -- ── P13: Protokoll mit devices und herkunft (Master) ───────────────────────
  perform set_config('request.jwt.claims', '{"is_master": true}', true);
  v_res := public.argus_governance_protokoll(v_ccp, 'PRB');
  total := total + 1;
  if jsonb_typeof(v_res->'devices') = 'array' and jsonb_typeof(v_res->'herkunft') = 'array'
     and jsonb_array_length(v_res->'devices') >= 2
     and exists (select 1 from jsonb_array_elements(v_res->'herkunft') e
                  where e->>'action' = 'herkunft' and e->'detail'->>'weg' = 'nachfrist')
     and exists (select 1 from jsonb_array_elements(v_res->'devices') e
                  where e->>'kennung' = 'Y' and (e->>'device_no')::int = 3) then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P13 devices=' || coalesce(jsonb_typeof(v_res->'devices'), 'fehlt')
             || ' herkunft=' || coalesce(jsonb_typeof(v_res->'herkunft'), 'fehlt');
  end if;

  -- ── P12: Purge + Capability ────────────────────────────────────────────────
  -- Y läuft ab (purge_after in der Vergangenheit), Z bleibt. Der Lauf wirkt auf die
  -- ganze Datenbank, wird aber mit der Transaktion zurückgerollt.
  update public.ccps set purge_after = v_nowms - 1000 where id = v_ccp2;
  v_res := public.argus_run_purge();
  total := total + 1;
  if (v_res ? 'token_hygiene') and (v_res ? 'devices') and (v_res ? 'audit_log_retention')
     and (select count(*) from public.ccp_devices where ccp_id = v_ccp2) = 0
     and (select count(*) from public.ccp_devices where ccp_id = v_ccp) > 0
     and public.argus_server_time()->>'v' = '26'
     and (public.argus_server_time()->>'now')::bigint > 0 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | P12 purge=' || v_res::text || ' v=' || coalesce(public.argus_server_time()->>'v', 'fehlt');
  end if;

  -- IMMER zurückrollen: die Exception verwirft die gesamte Transaktion.
  raise exception 'PROBE 0026 ERGEBNIS: % von % ok%', ok_n, total, fails;
end;
$probe$;
