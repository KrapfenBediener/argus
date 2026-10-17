-- ══════════════════════════════════════════════════════════════════════════
-- Prüfskript 0027 — Merge-Vektoren V01-V12 (Grabstein behält Inhalt, D6.5-19) gegen die LIVE-Datenbank
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- KEINE Migration. Nach dem Einspielen von 0027_grabstein_behaelt_inhalt.sql im
-- Supabase-SQL-Editor ausführen (ein Query, "Run").
--
-- Das Skript rollt sich SELBST zurück: es endet immer mit einer Fehlermeldung
-- (raise exception), wodurch die gesamte Transaktion verworfen wird — keine
-- Rückstände, keine Bereinigung nötig.
--
-- Erwartete Ausgabe (als FEHLER angezeigt, das ist beabsichtigt):
--     PROBE 0027 ERGEBNIS: N von N ok
-- beide Zahlen gleich und KEINE Fehlerliste dahinter. Bei Abweichung steht
-- hinter der Zahl, welcher Vektor/welche Prüfung was geliefert hat.
--
-- Was geprüft wird:
--   * V01-V12 aus tests/fixtures/merge-vectors.json (hier 1:1 eingebettet),
--     V01 zusätzlich über den Upsert-Pfad (INSERT ... ON CONFLICT DO UPDATE,
--     Annahme A1: BEFORE-Trigger greifen auf dem PostgREST-Upsert).
--   * argus_server_time() liefert v = 27.
--   * Verwerfen/Rückholen erscheinen im audit_log (patient_discard/-restore).
--   * argus_lage(), argus_governance_einsaetze(), argus_governance_protokoll()
--     zählen bzw. zeigen keine Grabsteine; Protokoll ohne conf.
--   * Insert-Normalisierung: Hilfsflag "p" und unbekannte fts-Schlüssel fallen weg.
--   * E8-E10: Verwerfen behält Name/Foto/Tourniquet/Prio/Status; Rückholen bringt alles
--     zurück (inkl. laufendem TQ-Timer); ein Grabstein beim Anlegen behält den Inhalt.
-- Alle Testdaten sind fiktiv (Präsidium "Probe 0027", Kennungen Z und Y).
-- ══════════════════════════════════════════════════════════════════════════

do $probe$
declare
  v_vectors jsonb := $json$
[
  {
    "id": "V01-prio-und-vitalwerte",
    "desc": "Verschiedene Gruppen: A setzt Prio (st), B ändert Vitalwerte (vit) offline — beide Änderungen bleiben erhalten. Die jüngere vit-Änderung des Servers (t150) schlägt die ältere des eingehenden Stands (t100).",
    "old": {
      "prio": false, "vit": {"hf": "80"}, "updated": 150,
      "fts": {"st": {"t": 100, "d": 1}, "vit": {"t": 150, "d": 2}}
    },
    "new": {
      "prio": true, "vit": {"hf": "70"}, "updated": 200,
      "fts": {"st": {"t": 200, "d": 5, "b": 100}, "vit": {"t": 100, "d": 1}}
    },
    "expect": {"prio": true, "vit.hf": "80", "fts.st.t": 200, "fts.vit.t": 150}
  },
  {
    "id": "V02-gleiche-gruppe-neuere-gewinnt",
    "desc": "Gleiche Gruppe vit: der jüngere Stempel (eingehend, t200) gewinnt.",
    "old": {"vit": {"hf": "80"}, "updated": 150, "fts": {"vit": {"t": 150, "d": 2}}},
    "new": {"vit": {"hf": "90"}, "updated": 200, "fts": {"vit": {"t": 200, "d": 5, "b": 150}}},
    "expect": {"vit.hf": "90"}
  },
  {
    "id": "V03-gleiche-gruppe-aeltere-verliert",
    "desc": "Gleiche Gruppe vit: der ältere eingehende Stempel (t150) verliert gegen den Server (t200) — später eintreffender alter Stand überschreibt nichts.",
    "old": {"vit": {"hf": "90"}, "updated": 200, "fts": {"vit": {"t": 200, "d": 5, "b": 150}}},
    "new": {"vit": {"hf": "80"}, "updated": 150, "fts": {"vit": {"t": 150, "d": 2}}},
    "expect": {"vit.hf": "90"}
  },
  {
    "id": "V04-gleichstand-stabil",
    "desc": "Gleichstand (t300 beide): kein Überschreiben, der Serverstand bleibt — stabil und deterministisch.",
    "old": {"cat": "T2", "updated": 300, "fts": {"cat": {"t": 300, "d": 1}}},
    "new": {"cat": "T1", "updated": 300, "fts": {"cat": {"t": 300, "d": 4}}},
    "expect": {"cat": "T2"}
  },
  {
    "id": "V05-grabstein-schlaegt-alten-stand",
    "desc": "Der Server hält einen Grabstein (del t500) mit Inhalt (D6.5-19). Ein eingehender Stand ohne del-Stempel erweckt den Patienten NICHT (Grabstein bleibt, deleted_at 500). Jüngere Inhaltsstempel (t600) werden normal übernommen: Name 'Testname', Status 'active'.",
    "old": {
      "deleted_at": 500, "deleted_by": "MUE", "deleted_dev": 3, "status": "active",
      "name": "", "vit": {}, "updated": 500,
      "fts": {"del": {"t": 500, "d": 3}, "stamm": {"t": 500, "d": 3}, "st": {"t": 500, "d": 3}}
    },
    "new": {
      "name": "Testname", "vit": {"hf": "80"}, "status": "active", "updated": 600,
      "fts": {"stamm": {"t": 600, "d": 2}, "vit": {"t": 600, "d": 2}}
    },
    "expect": {"deleted_at": 500, "name": "Testname", "vit.hf": "80", "status": "active"}
  },
  {
    "id": "V06-rueckholen-mit-juengerem-del",
    "desc": "Rückholen: ein eingehender del-Stempel (t700) ist jünger als der Grabstein (t500) und hebt ihn auf. Der Alt-Grabstein (0.34.0/1, leerer Inhalt) behält seinen serverseitigen Inhalt (die rückholende Seite hatte nur einen älteren Stand der Stammdaten, t400), der Status kommt aus der jüngeren Gruppe st.",
    "old": {
      "deleted_at": 500, "deleted_by": "MUE", "deleted_dev": 3, "status": "verworfen",
      "cat": "T2", "name": "", "updated": 500,
      "fts": {"del": {"t": 500, "d": 3}, "st": {"t": 500, "d": 3}, "cat": {"t": 500, "d": 3}, "stamm": {"t": 500, "d": 3}}
    },
    "new": {
      "deleted_at": null, "status": "active", "cat": "T1", "name": "Testname", "updated": 700,
      "fts": {"del": {"t": 700, "d": 3}, "st": {"t": 700, "d": 3}, "cat": {"t": 400, "d": 2}, "stamm": {"t": 400, "d": 2}}
    },
    "expect": {"deleted_at": null, "status": "active", "cat": "T2", "name": ""}
  },
  {
    "id": "V07-juengerer-grabstein-behaelt-inhalt",
    "desc": "Ein eingehender Grabstein (del t800) ist jünger als alles auf dem Server: er gewinnt (deleted_at 800), der Inhalt bleibt erhalten (Name 'Testname', Status 'active') — D6.5-19.",
    "old": {
      "name": "Testname", "vit": {"hf": "80"}, "status": "active", "updated": 100,
      "fts": {"stamm": {"t": 100, "d": 1}, "vit": {"t": 100, "d": 1}}
    },
    "new": {
      "deleted_at": 800, "deleted_by": "MUE", "deleted_dev": 4, "name": "Testname", "updated": 800,
      "fts": {"del": {"t": 800, "d": 4}}
    },
    "expect": {"deleted_at": 800, "name": "Testname", "vit.hf": "80", "status": "active"}
  },
  {
    "id": "V08-alter-client-ohne-fts",
    "desc": "Alter Client ohne fts-Stempel: Fallback über 'updated'. Geänderte Gruppe (st, Prio) gewinnt mit Stempel t=updated=300; unveränderte Gruppe (vit) behält den Serverstempel (t100).",
    "old": {
      "prio": false, "vit": {"hf": "80"}, "updated": 100,
      "fts": {"st": {"t": 100, "d": 1}, "vit": {"t": 100, "d": 1}}
    },
    "new": {"prio": true, "vit": {"hf": "80"}, "updated": 300},
    "expect": {"prio": true, "vit.hf": "80", "fts.st.t": 300, "fts.vit.t": 100}
  },
  {
    "id": "V09-zukunftsstempel-geklemmt",
    "serverOnly": true,
    "desc": "Nur Server/SQL-Probe: ein Stempel aus der Zukunft (Geräteuhr falsch) wird auf Serverzeit + Toleranz geklemmt. Platzhalter NOW+N = Serverzeit in ms plus N.",
    "old": {"vit": {"hf": "80"}, "updated": 100, "fts": {"vit": {"t": 100, "d": 1}}},
    "new": {"vit": {"hf": "99"}, "updated": 200, "fts": {"vit": {"t": "NOW+86400000", "d": 5}}},
    "expect": {"fts.vit.t": {"max": "NOW+60000"}}
  },
  {
    "id": "V10-konflikt-erzeugt-marker",
    "serverOnly": true,
    "desc": "Nur Server/SQL-Probe: gleichzeitige Änderung derselben Gruppe (eingehende Basis b150 < Serverstempel t200). Der jüngere Stand (t250) gewinnt, der Verlierer wird als Konflikt-Marker mit Snapshot (Gerät 2, hf 80) festgehalten.",
    "old": {"vit": {"hf": "80"}, "updated": 200, "fts": {"vit": {"t": 200, "d": 2}}, "conf": []},
    "new": {"vit": {"hf": "95"}, "updated": 250, "fts": {"vit": {"t": 250, "d": 5, "b": 150}}},
    "expect": {"vit.hf": "95", "conf.0.g": "vit", "conf.0.lose.d": 2, "conf.0.lose.v.vit.hf": "80"}
  },
  {
    "id": "V11-ack-entfernt-konflikte",
    "serverOnly": true,
    "desc": "Nur Server/SQL-Probe: eine Quittung (fts.ack, t2000) jünger als der Marker (at1000) räumt die Konflikt-Marker ab.",
    "old": {"vit": {"hf": "80"}, "updated": 200, "fts": {"vit": {"t": 200, "d": 2}}, "conf": [{"g": "vit", "at": 1000}]},
    "new": {"vit": {"hf": "80"}, "updated": 2000, "fts": {"ack": {"t": 2000}}},
    "expect": {"conf": []}
  },
  {
    "id": "V12-foto-konflikt-ohne-snapshot",
    "serverOnly": true,
    "desc": "Nur Server/SQL-Probe: ein Konflikt in der Gruppe foto erzeugt einen Marker OHNE Foto-Snapshot (Größe/Datenschutz) — lose.v enthält kein photo.",
    "old": {"photo": "data:image/jpeg;base64,AAAA", "updated": 200, "fts": {"foto": {"t": 200, "d": 2}}, "conf": []},
    "new": {"photo": "data:image/jpeg;base64,BBBB", "updated": 250, "fts": {"foto": {"t": 250, "d": 5, "b": 150}}},
    "expect": {"conf.0.g": "foto", "conf.0.lose.v.photo": {"absent": true}}
  }
]
$json$::jsonb;
  v_pid     uuid;
  v_ccp     uuid;
  v_ccp2    uuid;
  v_base    jsonb;
  v         jsonb;
  vid       text;
  mode      text;
  pid       text;
  v_num     int := 0;
  v_old     jsonb;
  v_new     jsonb;
  v_txt     text;
  v_m       text;
  v_nowms   bigint;
  v_act     jsonb;
  v_res     jsonb;
  v_e       jsonb;
  ek        text;
  ev        jsonb;
  av        jsonb;
  v_ok      boolean;
  v_why     text;
  setlist   text;
  setlist_u text;
  total     int := 0;
  ok_n      int := 0;
  fails     text := '';
begin
  -- ── Testdaten: Präsidium + zwei CCPs ──────────────────────────────────────
  insert into public.praesidien (name) values ('Probe 0027') returning id into v_pid;
  insert into public.ccps (kennung, praesidium_id) values ('Z', v_pid) returning id into v_ccp;
  insert into public.ccps (kennung, praesidium_id) values ('Y', v_pid) returning id into v_ccp2;

  -- ── Phase 1: Altstände ROH einlegen (Merge-Trigger vorübergehend aus) ──────
  alter table public.patients disable trigger argus_patients_merge_biu;

  insert into public.patients (id, ccp_id) values ('probe0027-base', v_ccp);
  select to_jsonb(p) - 'id' into v_base from public.patients p where p.id = 'probe0027-base';
  delete from public.patients where id = 'probe0027-base';

  for v in select value from jsonb_array_elements(v_vectors) loop
    vid := v->>'id';
    foreach mode in array case when vid like 'V01-%' then array['update','upsert'] else array['update'] end loop
      v_num := v_num + 1;
      pid   := 'probe0027-' || vid || '-' || mode;
      v_old := coalesce(v->'old', '{}'::jsonb);
      insert into public.patients
        select * from jsonb_populate_record(null::public.patients,
          v_base || jsonb_build_object('id', pid, 'ccp_id', v_ccp, 'num', v_num, 'ccp', 'Z') || v_old);
    end loop;
  end loop;

  -- Lage-/Protokoll-Prüfung: ein aktiver und ein Grabstein-Patient (bewusst
  -- inkonsistent: status 'active' MIT deleted_at, damit nur der deleted_at-Filter wirkt).
  insert into public.patients
    select * from jsonb_populate_record(null::public.patients,
      v_base || jsonb_build_object('id', 'probe0027-L1', 'ccp_id', v_ccp2, 'num', 1, 'ccp', 'Y',
                                   'status', 'active', 'cat', 'T1'));
  insert into public.patients
    select * from jsonb_populate_record(null::public.patients,
      v_base || jsonb_build_object('id', 'probe0027-L2', 'ccp_id', v_ccp2, 'num', 2, 'ccp', 'Y',
                                   'status', 'active', 'cat', 'T1', 'deleted_at', 1, 'deleted_by', 'PRB', 'deleted_dev', 3));

  alter table public.patients enable trigger argus_patients_merge_biu;

  -- ── Phase 2: eingehende Stände anwenden und Erwartungen prüfen ─────────────
  for v in select value from jsonb_array_elements(v_vectors) loop
    vid := v->>'id';
    foreach mode in array case when vid like 'V01-%' then array['update','upsert'] else array['update'] end loop
      pid     := 'probe0027-' || vid || '-' || mode;
      v_nowms := (extract(epoch from clock_timestamp()) * 1000)::bigint;

      -- Platzhalter NOW+N (V09) durch echte Serverzeit ersetzen
      v_txt := (v->'new')::text;
      while v_txt ~ '"NOW\+[0-9]+"' loop
        v_m   := substring(v_txt from '"NOW\+([0-9]+)"');
        v_txt := replace(v_txt, '"NOW+' || v_m || '"', (v_nowms + v_m::bigint)::text);
      end loop;
      v_new := v_txt::jsonb;

      select string_agg(format('%1$I = n.%1$I', key), ', '),
             string_agg(format('%1$I = excluded.%1$I', key), ', ')
        into setlist, setlist_u
        from jsonb_each(v_new);

      if mode = 'update' then
        execute format(
          'update public.patients p set %s '
          'from (select (jsonb_populate_record(q, $1)).* from public.patients q where q.id = $2) n '
          'where p.id = $2', setlist)
          using v_new, pid;
      else
        execute format(
          'insert into public.patients '
          'select * from jsonb_populate_record(null::public.patients, $1) '
          'on conflict (id) do update set %s', setlist_u)
          using v_base || jsonb_build_object('id', pid, 'ccp_id', v_ccp, 'num', 1, 'ccp', 'Z') || v_new;
      end if;

      select to_jsonb(p) into v_act from public.patients p where p.id = pid;

      v_ok  := true;
      v_why := '';
      for ek, ev in select key, value from jsonb_each(v->'expect') loop
        av := v_act #> string_to_array(ek, '.');
        if jsonb_typeof(ev) = 'object' and ev ? 'absent' then
          if av is not null then
            v_ok := false; v_why := v_why || ' ' || ek || '=' || av::text || ' (soll fehlen)';
          end if;
        elsif jsonb_typeof(ev) = 'object' and ev ? 'max' then
          if av is null or jsonb_typeof(av) <> 'number'
             or (av #>> '{}')::numeric >
                ((extract(epoch from clock_timestamp()) * 1000)::bigint
                 + substring(ev->>'max' from '\+([0-9]+)')::bigint) then
            v_ok := false; v_why := v_why || ' ' || ek || '=' || coalesce(av::text, 'fehlt') || ' (nicht geklemmt)';
          end if;
        else
          if av is distinct from ev then
            v_ok := false; v_why := v_why || ' ' || ek || '=' || coalesce(av::text, 'fehlt') || ' (soll ' || ev::text || ')';
          end if;
        end if;
      end loop;

      total := total + 1;
      if v_ok then ok_n := ok_n + 1;
      else fails := fails || ' | ' || vid || '[' || mode || ']:' || v_why;
      end if;
    end loop;
  end loop;

  -- ── Zusatzprüfungen ────────────────────────────────────────────────────────
  -- E1: Capability-RPC
  total := total + 1;
  if public.argus_server_time()->>'v' = '27' and (public.argus_server_time()->>'now')::bigint > 0 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E1 argus_server_time liefert nicht v=27';
  end if;

  -- E2: Verwerfen im audit_log (V07 verwirft)
  total := total + 1;
  if exists (select 1 from public.audit_log
              where action = 'patient_discard' and patient_id = 'probe0027-V07-juengerer-grabstein-behaelt-inhalt-update') then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E2 kein audit_log patient_discard (V07)';
  end if;

  -- E3: Rückholen im audit_log (V06 holt zurück)
  total := total + 1;
  if exists (select 1 from public.audit_log
              where action = 'patient_restore' and patient_id = 'probe0027-V06-rueckholen-mit-juengerem-del-update') then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E3 kein audit_log patient_restore (V06)';
  end if;

  -- E4: Insert-Normalisierung (Hilfsflag p und unbekannte Schlüssel fallen weg)
  insert into public.patients (id, ccp_id, num, ccp, fts)
    values ('probe0027-N1', v_ccp, 900, 'Z', '{"vit":{"t":5,"d":1,"p":1},"bogus":{"t":1}}'::jsonb);
  total := total + 1;
  if (select fts from public.patients where id = 'probe0027-N1') = '{"vit":{"t":5,"d":1}}'::jsonb then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E4 Insert-Normalisierung: fts=' ||
             coalesce((select fts::text from public.patients where id = 'probe0027-N1'), 'fehlt');
  end if;

  -- E8: Verwerfen behält Inhalt (D6.5-19): Name, Foto, Tourniquet, Prio und Status bleiben
  insert into public.patients (id, ccp_id, num, ccp, status, prio, name, photo, tq_start, tq_site, fts)
    values ('probe0027-T1', v_ccp, 901, 'Z', 'active', true, 'Testname', 'data:image/jpeg;base64,AAAA', 5, 'Arm',
            '{"tq":{"t":10,"d":1},"stamm":{"t":10,"d":1},"foto":{"t":10,"d":1},"st":{"t":10,"d":1}}'::jsonb);
  update public.patients
     set deleted_at = 1000, deleted_by = 'PRB', deleted_dev = 3, fts = '{"del":{"t":1000,"d":3}}'::jsonb
   where id = 'probe0027-T1';
  total := total + 1;
  if (select deleted_at = 1000 and name = 'Testname' and photo is not null and tq_start = 5
             and tq_site = 'Arm' and prio = true and status = 'active'
        from public.patients where id = 'probe0027-T1') then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E8 Grabstein hat Inhalt verloren: ' ||
             coalesce((select to_jsonb(p) - 'photo' from public.patients p where id = 'probe0027-T1')::text, 'fehlt');
  end if;

  -- E9: Rückholen (jüngerer del-Stempel) bringt alles zurück, inkl. laufendem TQ-Timer
  update public.patients
     set deleted_at = null, deleted_by = null, deleted_dev = null, fts = '{"del":{"t":2000,"d":4}}'::jsonb
   where id = 'probe0027-T1';
  total := total + 1;
  if (select deleted_at is null and name = 'Testname' and photo is not null and tq_start = 5
             and tq_site = 'Arm' and prio = true and status = 'active'
        from public.patients where id = 'probe0027-T1') then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E9 Rückholen: Inhalt fehlt: ' ||
             coalesce((select to_jsonb(p) - 'photo' from public.patients p where id = 'probe0027-T1')::text, 'fehlt');
  end if;

  -- E10: Grabstein beim Anlegen (INSERT) behält ebenfalls den Inhalt und bekommt einen del-Stempel
  insert into public.patients (id, ccp_id, num, ccp, name, tq_start, deleted_at, deleted_by, deleted_dev)
    values ('probe0027-T2', v_ccp, 902, 'Z', 'Testname', 7, 500, 'PRB', 3);
  total := total + 1;
  if (select name = 'Testname' and tq_start = 7 and deleted_at = 500 and (fts->'del'->>'t') = '500'
        from public.patients where id = 'probe0027-T2') then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E10 Insert-Grabstein: ' ||
             coalesce((select to_jsonb(p) - 'photo' from public.patients p where id = 'probe0027-T2')::text, 'fehlt');
  end if;

  -- E5: argus_lage() (Beobachter-Claim) zählt den Grabstein nicht
  perform set_config('request.jwt.claims',
    jsonb_build_object('is_observer', true, 'observer_praesidium_id', v_pid)::text, true);
  v_res := public.argus_lage();
  select e into v_e from jsonb_array_elements(v_res->'ccps') e where e->>'kennung' = 'Y';
  total := total + 1;
  if v_e is not null and (v_e->>'t1')::int = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E5 argus_lage t1=' || coalesce(v_e->>'t1', 'CCP fehlt') || ' (soll 1)';
  end if;

  -- E6/E7: Einsatzliste und Protokoll (Master-Claim, abgeschlossener Einsatz)
  update public.ccps set closed_at = (extract(epoch from clock_timestamp()) * 1000)::bigint where id = v_ccp2;
  perform set_config('request.jwt.claims', '{"is_master": true}', true);

  select e into v_e from jsonb_array_elements(public.argus_governance_einsaetze()) e
   where e->>'ccp_id' = v_ccp2::text;
  total := total + 1;
  if v_e is not null and (v_e->>'patient_count')::int = 1 then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E6 einsaetze patient_count=' || coalesce(v_e->>'patient_count', 'CCP fehlt') || ' (soll 1)';
  end if;

  v_res := public.argus_governance_protokoll(v_ccp2, 'PRB');
  total := total + 1;
  if jsonb_array_length(v_res->'patients') = 1
     and (v_res->>'verworfen_n')::int = 1
     and not ((v_res->'patients'->0) ? 'conf') then
    ok_n := ok_n + 1;
  else
    fails := fails || ' | E7 protokoll patients=' || jsonb_array_length(v_res->'patients')
             || ' verworfen_n=' || coalesce(v_res->>'verworfen_n', 'fehlt') || ' (soll 1/1, ohne conf)';
  end if;

  -- IMMER zurückrollen: die Exception verwirft die gesamte Transaktion.
  raise exception 'PROBE 0027 ERGEBNIS: % von % ok%', ok_n, total, fails;
end;
$probe$;
