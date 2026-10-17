-- ══════════════════════════════════════════════════════════════════════════
-- Prüfskript 0029 — argus_reserve_num mit p_used (verbrauchte Nummer melden)
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- KEINE Migration. Nach 0029 im SQL-Editor ausführen. Rollt sich selbst zurück
-- (endet immer mit raise exception). Erwartet: PROBE 0029 ERGEBNIS: N von N ok
-- ══════════════════════════════════════════════════════════════════════════
do $probe$
declare
  v_pa  uuid;
  v_ccp uuid;
  v_r   jsonb;
  v_n   int;
  total int := 0;
  ok_n  int := 0;
  fails text := '';
begin
  insert into public.praesidien (name) values ('Probe 0029') returning id into v_pa;
  insert into public.ccps (kennung, praesidium_id, next_device) values ('Z', v_pa, 3) returning id into v_ccp;
  perform set_config('request.jwt.claims', jsonb_build_object('praesidium_id', v_pa)::text, true);

  -- U1: erste Reservierung = 1
  v_r := public.argus_reserve_num(v_ccp, 1);
  total := total + 1;
  if (v_r->>'start')::int = 1 and (v_r->>'reused') = 'false' then ok_n := ok_n + 1;
  else fails := fails || ' | U1 ' || v_r::text; end if;

  -- U2: ohne p_used idempotent (wie 0028)
  v_r := public.argus_reserve_num(v_ccp, 1);
  total := total + 1;
  if (v_r->>'start')::int = 1 and (v_r->>'reused') = 'true' then ok_n := ok_n + 1;
  else fails := fails || ' | U2 ' || v_r::text; end if;

  -- U3: p_used = 1 (Patient noch NICHT hochgeladen) → sofort 2
  v_r := public.argus_reserve_num(v_ccp, 1, 1);
  select next_num into v_n from public.ccps where id = v_ccp;
  total := total + 1;
  if (v_r->>'start')::int = 2 and (v_r->>'reused') = 'false' and v_n = 3 then ok_n := ok_n + 1;
  else fails := fails || ' | U3 ' || v_r::text || ' next_num=' || coalesce(v_n::text, 'null'); end if;

  -- U4: wiederholte Meldung derselben verbrauchten Nummer 1 verbraucht NICHT erneut (Reservierung ist jetzt 2)
  v_r := public.argus_reserve_num(v_ccp, 1, 1);
  select next_num into v_n from public.ccps where id = v_ccp;
  total := total + 1;
  if (v_r->>'start')::int = 2 and (v_r->>'reused') = 'true' and v_n = 3 then ok_n := ok_n + 1;
  else fails := fails || ' | U4 ' || v_r::text || ' next_num=' || coalesce(v_n::text, 'null'); end if;

  -- U5: zweites Gerät bekommt 3, Gerät 1 behält 2
  v_r := public.argus_reserve_num(v_ccp, 2);
  total := total + 1;
  if (v_r->>'start')::int = 3 and (public.argus_reserve_num(v_ccp, 1)->>'start')::int = 2 then ok_n := ok_n + 1;
  else fails := fails || ' | U5 ' || v_r::text; end if;

  -- U6: Version
  total := total + 1;
  if public.argus_server_time()->>'v' = '29' then ok_n := ok_n + 1;
  else fails := fails || ' | U6 v=' || coalesce(public.argus_server_time()->>'v', 'fehlt'); end if;

  raise exception 'PROBE 0029 ERGEBNIS: % von % ok%', ok_n, total, fails;
end;
$probe$;
