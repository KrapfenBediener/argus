-- ══════════════════════════════════════════════════════════════════════════
-- Prüfskript 0028 — Idempotente Nummern-Reservierung je Gerät (LIVE-Datenbank)
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- KEINE Migration. Nach dem Einspielen von 0028_nummer_reservierung_je_geraet.sql
-- im Supabase-SQL-Editor ausführen (ein Query, "Run").
--
-- Das Skript rollt sich SELBST zurück: es endet immer mit einer Fehlermeldung
-- (raise exception), wodurch die gesamte Transaktion verworfen wird — keine
-- Rückstände, keine Bereinigung nötig.
--
-- Erwartete Ausgabe (als FEHLER angezeigt, das ist beabsichtigt):
--     PROBE 0028 ERGEBNIS: N von N ok
-- beide Zahlen gleich und KEINE Fehlerliste dahinter. Bei Abweichung steht
-- hinter der Zahl, welche Prüfung (R1-R8) was geliefert hat.
--
-- Was geprüft wird:
--   R1 zweimal reservieren (Gerät 1) → dieselbe Nummer, next_num unverändert
--   R2 Patient mit der Nummer anlegen → nächste Reservierung = +1
--   R3 zwei Geräte → verschiedene Nummern; Gerät 1 bekommt seine offene wieder
--   R4 fremdes Präsidium → Keine Berechtigung, nichts verändert
--   R5 ungültige Gerätenummer (0, null, über next_device)
--   R6 geschlossener CCP → Einsatz abgeschlossen; unbekannte CCP-ID → CCP nicht gefunden
--   R7 argus_server_time liefert v = 28
--   R8 selbstheilend: Zähler hinter vorhandenen Patienten → max(num)+1
-- Alle Testdaten sind fiktiv (Präsidien "Probe 0028 A/B", Kennungen Z, Y, X, W).
-- ══════════════════════════════════════════════════════════════════════════

do $probe$
declare
  v_pa     uuid;
  v_pb     uuid;
  v_ccp    uuid;   -- Z: Präsidium A, 3 Geräte
  v_ccp2   uuid;   -- Y: Präsidium A, geschlossen
  v_ccp3   uuid;   -- X: Präsidium A, Zähler hinter vorhandenen Patienten
  v_ccpb   uuid;   -- W: Präsidium B
  v_nowms  bigint;
  v_r1     jsonb;
  v_r2     jsonb;
  v_r3     jsonb;
  v_n      int;
  total    int := 0;
  ok_n     int := 0;
  fails    text := '';
begin
  -- ── Testdaten ───────────────────────────────────────────────────────────────
  v_nowms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  insert into public.praesidien (name) values ('Probe 0028 A') returning id into v_pa;
  insert into public.praesidien (name) values ('Probe 0028 B') returning id into v_pb;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('Z', v_pa, 3) returning id into v_ccp;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('Y', v_pa, 2) returning id into v_ccp2;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('X', v_pa, 2) returning id into v_ccp3;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('W', v_pb, 2) returning id into v_ccpb;

  -- Aufrufer = Präsidium A
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pa)::text, true);

  -- ── R1: zweimal reservieren → dieselbe Nummer, Zähler nur einmal erhöht ────
  v_r1 := public.argus_reserve_num(v_ccp, 1);
  v_r2 := public.argus_reserve_num(v_ccp, 1);
  select next_num into v_n from public.ccps where id = v_ccp;
  total := total + 1;
  if (v_r1->>'start')::int = 1 and (v_r1->>'count')::int = 1 and (v_r1->>'reused') = 'false'
     and (v_r2->>'start')::int = 1 and (v_r2->>'reused') = 'true'
     and v_n = 2
     and (select reserved_num from public.ccp_devices where ccp_id = v_ccp and device_no = 1) = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R1 r1=' || v_r1::text || ' r2=' || v_r2::text || ' next_num=' || coalesce(v_n::text, 'null');
  end if;

  -- ── R2: Patient mit der Nummer → nächste Reservierung = +1 ─────────────────
  insert into public.patients (id, ccp_id, num) values ('probe0028-p1', v_ccp, 1);
  v_r1 := public.argus_reserve_num(v_ccp, 1);
  select next_num into v_n from public.ccps where id = v_ccp;
  total := total + 1;
  if (v_r1->>'start')::int = 2 and (v_r1->>'reused') = 'false' and v_n = 3
     and (select reserved_num from public.ccp_devices where ccp_id = v_ccp and device_no = 1) = 2 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R2 res=' || v_r1::text || ' next_num=' || coalesce(v_n::text, 'null');
  end if;

  -- ── R3: zwei Geräte → verschiedene Nummern ─────────────────────────────────
  v_r2 := public.argus_reserve_num(v_ccp, 2);
  v_r3 := public.argus_reserve_num(v_ccp, 1);
  select next_num into v_n from public.ccps where id = v_ccp;
  total := total + 1;
  if (v_r2->>'start')::int = 3 and (v_r2->>'reused') = 'false'
     and (v_r3->>'start')::int = 2 and (v_r3->>'reused') = 'true'
     and v_n = 4
     and (select first_seen = last_seen and operator = ''
            from public.ccp_devices where ccp_id = v_ccp and device_no = 2) then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R3 dev2=' || v_r2::text || ' dev1=' || v_r3::text || ' next_num=' || coalesce(v_n::text, 'null');
  end if;

  -- ── R4: fremdes Präsidium ──────────────────────────────────────────────────
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pb)::text, true);
  v_r1 := public.argus_reserve_num(v_ccp, 1);
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pa)::text, true);
  select next_num into v_n from public.ccps where id = v_ccp;
  total := total + 1;
  if v_r1->>'error' = 'Keine Berechtigung' and v_n = 4
     and (select reserved_num from public.ccp_devices where ccp_id = v_ccp and device_no = 1) = 2 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R4 res=' || v_r1::text || ' next_num=' || coalesce(v_n::text, 'null');
  end if;

  -- ── R5: ungültige Gerätenummer ─────────────────────────────────────────────
  total := total + 1;
  if public.argus_reserve_num(v_ccp, 0)->>'error' = 'Ungültige Gerätenummer'
     and public.argus_reserve_num(v_ccp, 4)->>'error' = 'Ungültige Gerätenummer'
     and public.argus_reserve_num(v_ccp, 100)->>'error' = 'Ungültige Gerätenummer'
     and public.argus_reserve_num(v_ccp, null)->>'error' = 'Ungültige Gerätenummer'
     and (select next_num from public.ccps where id = v_ccp) = 4 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R5 dev0=' || public.argus_reserve_num(v_ccp, 0)::text;
  end if;

  -- ── R6: geschlossener CCP, unbekannte CCP-ID ───────────────────────────────
  update public.ccps set closed_at = v_nowms - 3600000 where id = v_ccp2;
  v_r1 := public.argus_reserve_num(v_ccp2, 1);
  v_r2 := public.argus_reserve_num(gen_random_uuid(), 1);
  total := total + 1;
  if v_r1->>'error' = 'Einsatz abgeschlossen' and v_r2->>'error' = 'CCP nicht gefunden'
     and not exists (select 1 from public.ccp_devices where ccp_id = v_ccp2) then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R6 geschlossen=' || v_r1::text || ' unbekannt=' || v_r2::text;
  end if;

  -- ── R7: Capability v = 28 ──────────────────────────────────────────────────
  total := total + 1;
  if public.argus_server_time()->>'v' = '28'
     and (public.argus_server_time()->>'now')::bigint > 0 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R7 v=' || coalesce(public.argus_server_time()->>'v', 'fehlt');
  end if;

  -- ── R8: selbstheilend — Zähler (1) liegt hinter vorhandenen Patienten (max 10) ──
  insert into public.patients (id, ccp_id, num) values ('probe0028-p10', v_ccp3, 10);
  v_r1 := public.argus_reserve_num(v_ccp3, 1);
  select next_num into v_n from public.ccps where id = v_ccp3;
  total := total + 1;
  if (v_r1->>'start')::int = 11 and v_n = 12 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | R8 res=' || v_r1::text || ' next_num=' || coalesce(v_n::text, 'null');
  end if;

  -- IMMER zurückrollen: die Exception verwirft die gesamte Transaktion.
  raise exception 'PROBE 0028 ERGEBNIS: % von % ok%', ok_n, total, fails;
end;
$probe$;
