-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0025 — Sync-Fundament (Patienten): Feldgruppen-Merge, Grabsteine,
--                  Konflikt-Marker, Capability-RPC argus_server_time
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- Phase 6.5 (Entscheidungen D6.5-05, -06, -07, -12, -14, -18).
--
-- Problem: Der Upsert eines Geräts überschreibt heute den GANZEN Datensatz
-- (Datensatz-LWW). Ändert Gerät 5 die Priorität und Gerät 2 offline die
-- Vitalwerte, gewinnt der später eintreffende Upload komplett — die andere
-- Änderung geht still verloren. Nur der Server sieht ALLE Schreiber (alte
-- App-Versionen, Offline-Nachzügler, späterer Late-Push); deshalb wird der
-- Merge hier erzwungen und nicht im Client.
--
-- Inhalt:
--   1) Spalten an patients: fts (Feldgruppen-Stempel), deleted_at/by/dev
--      (Grabstein), conf (Konflikt-Marker mit Snapshot). Additiv, mit Defaults.
--   2) Trigger-Funktion argus_patients_merge() + BEFORE-INSERT/UPDATE-Trigger:
--        * je Feldgruppe gewinnt der jüngere Stempel (Gleichstand: Serverstand)
--        * Grabstein schlägt ältere/gleichzeitige Stände; nur ein jüngeres
--          fts.del (Rückholen) hebt ihn auf; ein Grabstein trägt nie Inhalt/Foto
--        * Konflikt in derselben Gruppe zweier Geräte → Marker in conf
--          (Snapshot der unterlegenen Werte, nie ein Foto, max. 20 Einträge)
--        * Stempel > jetzt + 60 s werden auf Server-Jetzt geklemmt
--        * Quittung fts.ack räumt Konflikt-Marker ab
--      Alte Clients (ohne fts) laufen über den Fallback "updated je Gruppe".
--   3) argus_server_time() → {now, v:25}: Capability-Probe des Clients.
--   4) argus_audit_patients(): Verwerfen/Rückholen → patient_discard /
--      patient_restore im audit_log.
--   5-7) Grabstein-Filter in argus_lage(), argus_governance_einsaetze(),
--      argus_governance_protokoll() (Protokoll zusätzlich ohne conf, mit
--      verworfen_n).
--   8) audit_log.action-Katalog um patient_discard/patient_restore ergänzt.
--
-- Reihenfolge: 0000 → … → 0024 → 0025. 0025 hängt NICHT von 0024 ab.
-- Einspielen: durch den Owner im Supabase-SQL-Editor (kein CLI/db push).
-- Idempotent (add column if not exists, create or replace, drop trigger if
-- exists). KEINE RLS-Änderung: die Policies argus_patients_* bleiben
-- unangetastet; anon liest weiterhin 0 Zeilen.
-- Prüfskript: supabase/probes/0025_sync_probe.sql (rollt sich selbst zurück).
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1) Spalten ──────────────────────────────────────────────────────────────
alter table public.patients add column if not exists fts         jsonb  not null default '{}'::jsonb;
alter table public.patients add column if not exists deleted_at  bigint;
alter table public.patients add column if not exists deleted_by  text;
alter table public.patients add column if not exists deleted_dev int;
alter table public.patients add column if not exists conf        jsonb  not null default '[]'::jsonb;

comment on column public.patients.fts is
  'Feldgruppen-Stempel {"<gruppe>":{"t":ms,"d":Gerätenr,"b":Basis-Stempel},"ack":{"t":ms}} (Phase 6.5). Gruppen: cat, st, vit, tx, tq, stamm, foto, del. Wird vom Trigger argus_patients_merge normalisiert. Löschung mit dem Einsatz-Purge (Patientenzeile).';
comment on column public.patients.deleted_at is
  'Grabstein (Verwerfen): Zeitpunkt in ms. NULL = Patient aktiv. Ein Grabstein trägt nie Inhalt/Foto. Löschung mit dem Einsatz-Purge.';
comment on column public.patients.deleted_by is
  'Grabstein: Kürzel des Bedieners, der verworfen hat. Löschung mit dem Einsatz-Purge.';
comment on column public.patients.deleted_dev is
  'Grabstein: Gerätenummer, von der aus verworfen wurde. Löschung mit dem Einsatz-Purge.';
comment on column public.patients.conf is
  'Konflikt-Marker [{g,at,win:{t,d},lose:{t,d,v}}] (max. 20; v = Werte der unterlegenen Gruppe, nie ein Foto). Nur der Trigger schreibt; fts.ack räumt ab. Löschung mit dem Einsatz-Purge.';

-- ── 2) Feldgruppen-Merge (BEFORE INSERT OR UPDATE) ─────────────────────────
-- Gruppen ↔ Spalten (spiegelt FGROUPS des Clients):
--   cat = cat, last_triage · st = status, prio, ready · vit = vit, pup_re, pup_li
--   tx = tx · tq = tq_start, tq_site
--   stamm = name, age, gender, allergies, moi, injury, fr, notes, inj
--   foto = photo · del (Sondergruppe) = deleted_at, deleted_by, deleted_dev
--   ack (Pseudo-Eintrag, nur "t") = Quittung für Konflikt-Marker
-- Keine Gruppe (Identität/Laufzeit, unangetastet): id, ccp_id, num, ccp,
--   created, by, locked_by, locked_at. Sonderregeln: updated, fts, conf.
--
-- Bewusst KEIN security definer: der Trigger liest nur OLD/NEW.
-- Keine Folge-UPDATEs (Realtime-Flut): der Merge passiert ausschließlich hier.
create or replace function public.argus_patients_merge()
  returns trigger
  language plpgsql
  set search_path to 'public'
as $function$
declare
  v_now      bigint;
  v_lim      bigint;
  v_groups   constant jsonb := '{
    "cat":   ["cat","last_triage"],
    "st":    ["status","prio","ready"],
    "vit":   ["vit","pup_re","pup_li"],
    "tx":    ["tx"],
    "tq":    ["tq_start","tq_site"],
    "stamm": ["name","age","gender","allergies","moi","injury","fr","notes","inj"],
    "foto":  ["photo"]
  }'::jsonb;
  -- Grabstein-Inhalt (Server und Client identisch); cat/last_triage bleiben.
  v_hull     constant jsonb := '{
    "status":"verworfen","prio":false,"ready":false,
    "vit":{"af":"","hf":"","rr":"","avpu":"","pain":"","spo2":""},
    "tx":{},"inj":[],
    "name":"","age":"","gender":"","allergies":"","moi":"","injury":"","fr":"","notes":"",
    "pup_re":"","pup_li":"","tq_start":null,"tq_site":null,"photo":null
  }'::jsonb;
  v_content  constant text[] := array['st','vit','tx','tq','stamm','foto'];
  g          text;
  cols       jsonb;
  c          text;
  k          text;
  e          jsonb;
  v_ent      jsonb;
  v_in       jsonb := '{}'::jsonb;   -- normalisierter, geklemmter eingehender fts
  v_old      jsonb;                  -- OLD.fts
  v_fts      jsonb := '{}'::jsonb;   -- Ergebnis-fts
  v_patch    jsonb := '{}'::jsonb;   -- Spaltenwerte, die aus OLD/Grabstein zurückgeschrieben werden
  v_oldj     jsonb;
  v_newj     jsonb;
  v_oj       jsonb;
  v_nj       jsonb;
  v_conf     jsonb;
  v_newc     jsonb := '[]'::jsonb;
  v_ds       jsonb;
  v_ack      bigint;
  t_old      bigint;
  t_new      bigint;
  d_old      int;
  d_new      int;
  v_b        bigint;
  t_del_old  bigint;
  t_del_new  bigint;
  v_dt       bigint;
  v_db       text;
  v_dd       int;
  v_changed  boolean;
  v_newstyle boolean;
  v_tomb     boolean;
  v_fresh    boolean;
begin
  v_now := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_lim := v_now + 60000;

  -- (b) Eingehenden fts normalisieren und klemmen (INSERT und UPDATE):
  --     nur bekannte Schlüssel, nur numerische Stempel, t auf Server-Jetzt+60 s
  --     geklemmt, Client-Hilfsflag "p" fällt weg (es werden nur t/d/b übernommen).
  if jsonb_typeof(NEW.fts) = 'object' then
    for k, e in select key, value from jsonb_each(NEW.fts) loop
      if k = any (array['cat','st','vit','tx','tq','stamm','foto','del','ack'])
         and jsonb_typeof(e) = 'object'
         and (e->>'t') ~ '^[0-9]+(\.[0-9]+)?$' then
        v_ent := jsonb_build_object('t', least((e->>'t')::numeric, v_lim::numeric)::bigint);
        if k <> 'ack' then
          if (e->>'d') ~ '^[0-9]{1,9}$' then
            v_ent := v_ent || jsonb_build_object('d', (e->>'d')::int);
          end if;
          if (e->>'b') ~ '^[0-9]{1,15}$' then
            v_ent := v_ent || jsonb_build_object('b', (e->>'b')::bigint);
          end if;
        end if;
        v_in := v_in || jsonb_build_object(k, v_ent);
      end if;
    end loop;
  end if;
  NEW.updated := least(coalesce(NEW.updated, 0), v_lim);
  if NEW.deleted_at is not null then
    NEW.deleted_at := least(NEW.deleted_at, v_lim);
  end if;

  -- (c) INSERT: kein Merge (Zeile existiert noch nicht), nur Hygiene.
  if TG_OP = 'INSERT' then
    NEW.conf := '[]'::jsonb;
    if NEW.deleted_at is not null then
      -- Grabstein beim Anlegen: del-Stempel sicherstellen, Inhalt erzwingen.
      if not (v_in ? 'del') then
        v_in := v_in || jsonb_build_object('del', jsonb_build_object('t', NEW.deleted_at, 'd', NEW.deleted_dev));
      end if;
      v_ds := v_in->'del';
      foreach g in array v_content loop
        v_in := v_in || jsonb_build_object(g, v_ds - 'b');
      end loop;
      NEW := jsonb_populate_record(NEW, v_hull);
      NEW.photo    := null;
      NEW.tq_start := null;
      NEW.tq_site  := null;
    end if;
    NEW.fts := v_in;
    return NEW;
  end if;

  -- ── UPDATE ────────────────────────────────────────────────────────────────
  v_old      := coalesce(OLD.fts, '{}'::jsonb);
  v_oldj     := to_jsonb(OLD);
  v_newj     := to_jsonb(NEW);
  -- Neuer Client = hat fts mitgeschickt (NEW.fts weicht von OLD.fts ab). Alte Clients
  -- senden die Spalte nicht: PostgREST lässt sie dann unverändert (NEW.fts = OLD.fts) →
  -- Fallback über "updated" je geänderter Gruppe.
  v_newstyle := (NEW.fts is distinct from OLD.fts);
  if not v_newstyle then
    v_in := '{}'::jsonb;
  end if;

  -- (d) Grabstein-Gruppe "del". Alte Clients senden nie fts.del → gewinnen nie.
  t_del_old := coalesce((v_old->'del'->>'t')::bigint, OLD.deleted_at, 0);
  t_del_new := coalesce((v_in->'del'->>'t')::bigint, 0);
  if t_del_new > t_del_old then
    v_dt := NEW.deleted_at;
    v_db := NEW.deleted_by;
    v_dd := NEW.deleted_dev;
    v_fts := v_fts || jsonb_build_object('del', v_in->'del');
  else
    v_dt := OLD.deleted_at;
    v_db := OLD.deleted_by;
    v_dd := OLD.deleted_dev;
    if v_old ? 'del' then
      v_fts := v_fts || jsonb_build_object('del', v_old->'del');
    end if;
  end if;
  if v_dt is null then
    v_db := null;   -- Rückgeholt: keine Reste des Grabsteins
    v_dd := null;
  end if;
  v_tomb  := (v_dt is not null);
  v_fresh := v_tomb and OLD.deleted_at is null;

  -- (e) Grabstein: Inhaltsgruppen auf Grabstein-Inhalt; "cat" läuft regulär weiter.
  if v_tomb then
    v_patch := v_hull;
    if v_fresh then
      v_ds := jsonb_build_object('t', (v_fts->'del'->>'t')::bigint,
                                 'd', (v_fts->'del'->>'d')::int);
    end if;
    foreach g in array v_content loop
      if v_fresh then
        v_fts := v_fts || jsonb_build_object(g, v_ds);
      elsif v_old ? g then
        v_fts := v_fts || jsonb_build_object(g, v_old->g);
      else
        v_fts := v_fts || jsonb_build_object(g, jsonb_build_object('t', coalesce(OLD.updated, 0), 'd', null));
      end if;
    end loop;
  end if;

  -- (f) Gruppen mergen.
  for g, cols in select key, value from jsonb_each(v_groups) loop
    if v_tomb and g <> 'cat' then
      continue;   -- bereits durch den Grabstein-Inhalt abgedeckt
    end if;

    v_oj := '{}'::jsonb;
    v_nj := '{}'::jsonb;
    for c in select jsonb_array_elements_text(cols) loop
      v_oj := v_oj || jsonb_build_object(c, v_oldj->c);
      v_nj := v_nj || jsonb_build_object(c, v_newj->c);
    end loop;
    v_changed := (v_oj is distinct from v_nj);

    t_old := coalesce((v_old->g->>'t')::bigint, OLD.updated, 0);
    d_old := (v_old->g->>'d')::int;
    v_b   := null;
    if v_in ? g then
      t_new := (v_in->g->>'t')::bigint;
      d_new := (v_in->g->>'d')::int;
      v_b   := (v_in->g->>'b')::bigint;
    elsif v_changed and not v_newstyle then
      -- alter Client ohne fts: Fallback über "updated"
      t_new := NEW.updated;
      d_new := null;
    else
      -- Gruppe nicht gestempelt (und kein alter Client): Client beansprucht sie nicht
      t_new := t_old;
      d_new := d_old;
    end if;

    if t_new > t_old then
      -- NEW gewinnt: Spalten bleiben, Stempel übernehmen.
      if v_in ? g then
        v_fts := v_fts || jsonb_build_object(g, v_in->g);
      else
        v_fts := v_fts || jsonb_build_object(g, jsonb_build_object('t', t_new, 'd', null));
      end if;
      -- Konflikt: derselbe Gruppeninhalt wurde von zwei Geräten auf unterschiedlicher Basis geändert.
      if v_changed and v_b is not null and v_b is distinct from t_old and d_new is distinct from d_old then
        v_newc := v_newc || jsonb_build_array(jsonb_build_object(
          'g',    g,
          'at',   v_now,
          'win',  jsonb_build_object('t', t_new, 'd', d_new),
          'lose', jsonb_build_object('t', t_old, 'd', d_old)
                  || case when g = 'foto' then '{}'::jsonb else jsonb_build_object('v', v_oj) end));
      end if;
    else
      -- OLD gewinnt (älter oder Gleichstand): Spalten der Gruppe aus OLD zurückschreiben.
      if v_changed then
        v_patch := v_patch || v_oj;   -- jsonb-Werte (vit/tx/inj) bleiben jsonb
      end if;
      -- Stempel aus OLD; fehlt er (Altbestand), den Fallback festschreiben, damit er nicht mit "updated" mitwandert.
      if v_old ? g then
        v_fts := v_fts || jsonb_build_object(g, v_old->g);
      else
        v_fts := v_fts || jsonb_build_object(g, jsonb_build_object('t', t_old, 'd', null));
      end if;
      if v_changed and t_new < t_old
         and v_b is not null and v_b is distinct from t_old and d_new is distinct from d_old then
        v_newc := v_newc || jsonb_build_array(jsonb_build_object(
          'g',    g,
          'at',   v_now,
          'win',  jsonb_build_object('t', t_old, 'd', d_old),
          'lose', jsonb_build_object('t', t_new, 'd', d_new)
                  || case when g = 'foto' then '{}'::jsonb else jsonb_build_object('v', v_nj) end));
      end if;
    end if;
  end loop;

  -- (g) Quittung und Konflikt-Marker. Eingehendes NEW.conf wird IGNORIERT.
  v_ack := greatest(coalesce((v_old->'ack'->>'t')::bigint, 0),
                    coalesce((v_in->'ack'->>'t')::bigint, 0));
  if v_ack > 0 then
    v_fts := v_fts || jsonb_build_object('ack', jsonb_build_object('t', v_ack));
  end if;

  if v_tomb then
    v_conf := '[]'::jsonb;
  else
    select coalesce(jsonb_agg(s.x order by s.ord), '[]'::jsonb)
      into v_conf
      from (select a.x, a.ord
              from jsonb_array_elements(coalesce(OLD.conf, '[]'::jsonb) || v_newc) with ordinality as a(x, ord)
             where coalesce((a.x->>'at')::numeric, 0) > v_ack
             order by a.ord desc
             limit 20) s;
  end if;

  -- (h) Ergebnis zusammensetzen.
  if v_patch <> '{}'::jsonb then
    NEW := jsonb_populate_record(NEW, v_patch);
  end if;
  if v_tomb then
    NEW.photo    := null;
    NEW.tq_start := null;
    NEW.tq_site  := null;
  end if;
  NEW.deleted_at  := v_dt;
  NEW.deleted_by  := v_db;
  NEW.deleted_dev := v_dd;
  NEW.fts         := v_fts;
  NEW.conf        := v_conf;
  NEW.updated     := greatest(coalesce(OLD.updated, 0), NEW.updated);
  return NEW;
end;
$function$;

comment on function public.argus_patients_merge() is
  'BEFORE INSERT OR UPDATE auf patients (Phase 6.5): serverseitiger Feldgruppen-Merge (jüngerer Stempel je Gruppe), Grabstein-Schutz, Konflikt-Marker, Klemmen von Zukunftsstempeln. Keine Folge-UPDATEs.';

drop trigger if exists argus_patients_merge_biu on public.patients;
create trigger argus_patients_merge_biu
  before insert or update on public.patients
  for each row
  execute function public.argus_patients_merge();

-- ── 3) Capability-Probe ────────────────────────────────────────────────────
-- Liefert Serverzeit (ms) und Schema-Version. Der Client sendet die neuen
-- Spalten erst bei v >= 25 (D6.5-18) und nutzt die Zeit für den Uhrabgleich.
-- Ohne Claims aufrufbar; gibt nur Zeit + Versionsnummer preis.
create or replace function public.argus_server_time()
  returns jsonb
  language plpgsql
  volatile
  set search_path to 'public'
as $function$
begin
  return jsonb_build_object(
    'now', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'v',   25
  );
end;
$function$;

grant execute on function public.argus_server_time() to anon;

comment on function public.argus_server_time() is
  'Capability-/Zeit-Probe (Phase 6.5): {now: Server-ms, v: Schema-Version 25}. Ohne Claims aufrufbar.';

-- ── 4) Audit: Verwerfen / Rückholen ────────────────────────────────────────
-- Basis = 0020-Fassung. Neu: zwei Zweige mit höchster Priorität
-- (patient_discard / patient_restore, detail = {"dev": Gerätenummer}).
-- Trigger-Anlage (argus_audit_patients_aiu, 0018) bleibt unverändert; da der
-- Merge-Trigger BEFORE feuert, sieht das Audit den gemergten Stand — ein
-- verworfener Stale-Write erzeugt keinen Eintrag.
create or replace function public.argus_audit_patients()
  returns trigger
  language plpgsql
  security definer
  set search_path to 'public'
as $$
declare
  v_action      text;
  v_praesidium  uuid;
  v_detail      text := null;
begin
  -- action aus TG_OP + Spaltendiff ableiten (Priorität: discard/restore > photo > checkout > ready > cat_change).
  if TG_OP = 'INSERT' then
    v_action := 'patient_create';
  elsif TG_OP = 'UPDATE' then
    -- 0025: Verwerfen/Rückholen (Grabstein) haben höchste Priorität. Der Grabstein setzt
    -- photo auf null und status auf 'verworfen' → kein falsches patient_photo/-checkout.
    if NEW.deleted_at is not null and OLD.deleted_at is null then
      v_action := 'patient_discard';
      v_detail := jsonb_build_object('dev', NEW.deleted_dev)::text;
    elsif NEW.deleted_at is null and OLD.deleted_at is not null then
      v_action := 'patient_restore';
      v_detail := jsonb_build_object('dev', OLD.deleted_dev)::text;
    -- IN-02 (0020): Foto-Erst-Upload UND Foto-Ersatz lösen 'patient_photo' aus.
    elsif NEW.photo is not null and (OLD.photo is null or NEW.photo <> OLD.photo) then
      v_action := 'patient_photo';
    elsif NEW.status = 'gpa' and coalesce(OLD.status, '') <> 'gpa' then
      v_action := 'patient_checkout';
    elsif NEW.ready = true and coalesce(OLD.ready, false) = false then
      v_action := 'patient_ready';
    elsif NEW.cat <> OLD.cat then
      v_action := 'patient_cat_change';
    else
      -- Reine Vitalwert-/Feld-Änderung → kein Eintrag (D-06).
      return NEW;
    end if;
  else
    return NEW;
  end if;

  -- praesidium_id über die ccps-Row auflösen (patients hat keine eigene Spalte).
  select praesidium_id
    into v_praesidium
    from public.ccps
   where id = NEW.ccp_id;

  -- audit_log-Eintrag schreiben (auch bei usbnk=null, §73-Vollständigkeit).
  insert into public.audit_log (at, usbnk, action, ccp_id, patient_id, praesidium_id, detail)
    values (
      (extract(epoch from now()) * 1000)::bigint,
      public.argus_usbnk(),
      v_action,
      NEW.ccp_id,
      NEW.id,
      v_praesidium,
      v_detail
    );

  return NEW;
end;
$$;
grant execute on function public.argus_audit_patients() to anon;

-- ── 5) argus_lage(): Grabsteine nicht zählen ───────────────────────────────
-- Basis = 0015-Fassung (FLZ- und Observer-/Admin-Zweig, Feldsatz byte-gleich);
-- einzige Änderung: jeder Subselect über die Patiententabelle filtert Grabsteine heraus.
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
  -- Eingangs-Guard: Observer, Admin oder FLZ (jeder auf seinen Scope begrenzt).
  -- FLZ darf hier rein (D-12: präsidienübergreifend).
  if not (public.argus_is_observer()
          or public.argus_is_admin()
          or public.argus_is_flz()) then
    raise exception 'Nur mit Beobachter-, Admin- oder FLZ-Zugang';
  end if;

  -- ── FLZ-Zweig: präsidienübergreifend (D-12) ─────────────────────────────
  -- FLZ trägt praesidium_id=null im JWT → argus_praesidium_id() liefert null.
  -- Kein Präsidiums-Filter: alle offenen CCPs aller Präsidien aggregieren.
  if public.argus_is_flz() then
    select coalesce(jsonb_agg(jsonb_build_object(
             'kennung',        c.kennung,
             'ort',            c.ort,
             'lat',            c.geo_lat,
             'lng',            c.geo_lng,
             'verbund',        (c.merge_group_id is not null),
             'verbund_gruppe', c.merge_group_id,
             'praesidium_id',  c.praesidium_id,
             'praesidium_name',(select p.name from public.praesidien p where p.id = c.praesidium_id),
             't1',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'active' and pt.cat = 'T1'),
             't2',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'active' and pt.cat = 'T2'),
             't3',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'active' and pt.cat = 'T3'),
             't5',    (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'active' and pt.cat = 'T5'),
             'gpa',   (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'gpa'),
             'prio',  (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'active' and pt.prio),
             'ready', (select count(*) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null and pt.status = 'active' and pt.ready),
             'letzte_aenderung', (select max(pt.updated) from public.patients pt where pt.ccp_id = c.id and pt.deleted_at is null)
           ) order by c.kennung), '[]'::jsonb)
    into v_ccps
    from public.ccps c
    where c.closed_at is null;  -- KEIN Präsidiums-Filter für FLZ

    return jsonb_build_object(
      'praesidium_name', null,   -- FLZ: kein eigenes Präsidium
      'stand',           (extract(epoch from now())*1000)::bigint,
      'ccps',            v_ccps
    );
  end if;

  -- ── Observer-/Admin-Zweig: eigenes Präsidium (0013-Fassung byte-gleich) ──
  if coalesce(public.argus_observer_praesidium_id(),
              public.argus_admin_praesidium_id()) is null then
    raise exception 'Nur mit Beobachter- oder Admin-Zugang';
  end if;

  v_pid := coalesce(public.argus_observer_praesidium_id(),
                    public.argus_admin_praesidium_id());

  select name into v_pname from public.praesidien where id = v_pid;

  select coalesce(jsonb_agg(jsonb_build_object(
           'kennung', c.kennung,
           'ort',     c.ort,
           'lat',     c.geo_lat,
           'lng',     c.geo_lng,
           'verbund', (c.merge_group_id is not null),
           'verbund_gruppe', c.merge_group_id,
           't1',    (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'active' and p.cat = 'T1'),
           't2',    (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'active' and p.cat = 'T2'),
           't3',    (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'active' and p.cat = 'T3'),
           't5',    (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'active' and p.cat = 'T5'),
           'gpa',   (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'gpa'),
           'prio',  (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'active' and p.prio),
           'ready', (select count(*) from public.patients p where p.ccp_id = c.id and p.deleted_at is null and p.status = 'active' and p.ready),
           'letzte_aenderung', (select max(p.updated) from public.patients p where p.ccp_id = c.id and p.deleted_at is null)
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

-- ── 6) argus_governance_einsaetze(): patient_count ohne Grabsteine ─────────
-- Basis = 0009-Fassung; nur patient_count ändert sich.
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
           'patient_count',     (select count(*)       from public.patients   p where p.ccp_id = c.id and p.deleted_at is null),
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

-- ── 7) argus_governance_protokoll(): ohne Grabsteine, ohne conf, mit verworfen_n ──
-- Basis = 0003-Fassung. conf (Konflikt-Snapshots) wird nie ausgeliefert.
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
         ) order by c.kennung), '[]'::jsonb)
  into v_ccps
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

  -- Zwangs-Log VOR der Rückgabe — jeder Protokoll-Abruf = ein Eintrag (D-01, D-17).
  insert into public.governance_log (at, ccp_id, kuerzel, action)
    values (v_now, p_ccp_id, btrim(p_kuerzel), 'protokoll_view');

  return jsonb_build_object(
    'ccps',       v_ccps,
    'patients',   v_patients,
    'verworfen_n', v_verworfen,
    'checklists', v_checklists
  );
end;
$function$;
grant execute on function public.argus_governance_protokoll(uuid, text) to anon;

-- ── 8) audit_log.action: Katalog erweitert um Verwerfen/Rückholen ──────────
comment on column public.audit_log.action is
  'person_login | person_issue | person_revoke | person_role_change | governance_abruf | patient_create | patient_cat_change | patient_ready | patient_checkout | patient_photo | patient_discard | patient_restore | ccp_open | ccp_close | ccp_merge';
