-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0027 — Grabstein behält Inhalt (Rückholen stellt alles wieder her)
-- Copyright (c) Gabor Szeman — ARGUS
-- ══════════════════════════════════════════════════════════════════════════
-- Phase 6.5, Owner-Entscheid D6.5-19 (ersetzt den Inhalts-Teil von D6.5-05/-12).
--
-- Problem (UAT 2026-10-17): „Verwerfen → Rückholen" ließ alle Eingaben verloren
-- gehen, auch den laufenden Tourniquet-Timer — der Grabstein aus 0025 leerte
-- Inhalt und Foto und stellte beim Rückholen nur die Hülle (Nummer, Kategorie)
-- wieder her. Für T1 mit laufendem Tourniquet ist das sicherheitsrelevant.
--
-- Neue Semantik (Client und Server identisch, Vektoren V05-V07 in
-- tests/fixtures/merge-vectors.json):
--   * Grabstein = ausschließlich Gruppe "del" (deleted_at/by/dev, fts.del).
--     Keine Änderung an status, prio, ready, Inhalt, Foto, Tourniquet, conf.
--   * Inhaltsgruppen werden auch bei Grabstein normal gemergt (jüngerer
--     Gruppenstempel gewinnt) — ein späteres Rückholen bringt den neuesten Stand.
--   * Grabstein-Schutz unverändert: nur ein jüngerer fts.del-Stempel hebt ihn
--     auf; Stände ohne del-Stempel erwecken nie (Vektor V05).
--   * Sichtbarkeit unverändert: Lage/Einsatzliste/Protokoll filtern
--     deleted_at (0025, nicht angefasst). Der Inhalt unterliegt weiter der
--     normalen Einsatz-Löschfrist (Purge) und der 72-h-Fotofrist.
--   * Alt-Grabsteine aus 0.34.0/0.34.1 (status 'verworfen', leerer Inhalt)
--     bleiben unverändert in der Tabelle; der Client setzt sie beim Rückholen
--     auf status 'active' (Gruppe st).
--
-- Inhalt:
--   1) argus_patients_merge(): 0025-Fassung ohne Grabstein-Hülle (INSERT- und
--      UPDATE-Zweig), conf wird bei Grabstein nicht mehr geleert.
--   2) argus_server_time() → {now, v:27}.
--
-- Reihenfolge: 0000 → … → 0026 → 0027 (setzt 0025 voraus: Spalten fts/deleted_*/conf).
-- Einspielen: durch den Owner im Supabase-SQL-Editor (kein CLI/db push).
-- Idempotent (create or replace). KEINE RLS-Änderung, keine neue Tabelle; der
-- Trigger argus_patients_merge_biu (0025) bleibt bestehen und ruft die ersetzte
-- Funktion auf. `set search_path to 'public'` bleibt gesetzt.
-- Prüfskript: supabase/probes/0027_sync_probe.sql (rollt sich selbst zurück).
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1) Feldgruppen-Merge ohne Grabstein-Hülle ──────────────────────────────
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
  g          text;
  cols       jsonb;
  c          text;
  k          text;
  e          jsonb;
  v_ent      jsonb;
  v_in       jsonb := '{}'::jsonb;   -- normalisierter, geklemmter eingehender fts
  v_old      jsonb;                  -- OLD.fts
  v_fts      jsonb := '{}'::jsonb;   -- Ergebnis-fts
  v_patch    jsonb := '{}'::jsonb;   -- Spaltenwerte, die aus OLD zurückgeschrieben werden
  v_oldj     jsonb;
  v_newj     jsonb;
  v_oj       jsonb;
  v_nj       jsonb;
  v_conf     jsonb;
  v_newc     jsonb := '[]'::jsonb;
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
    if NEW.deleted_at is not null and not (v_in ? 'del') then
      -- Grabstein beim Anlegen (D6.5-19): del-Stempel sicherstellen, Inhalt bleibt unverändert.
      v_in := v_in || jsonb_build_object('del', jsonb_build_object('t', NEW.deleted_at, 'd', NEW.deleted_dev));
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

  -- (d) Grabstein-Gruppe "del" (D6.5-19: nur deleted_*, der Inhalt bleibt). Alte Clients senden nie fts.del → gewinnen nie.
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

  -- (e) entfällt: keine Grabstein-Hülle mehr (0025 setzte hier den Grabstein-Inhalt).
  -- (f) Gruppen mergen.
  for g, cols in select key, value from jsonb_each(v_groups) loop
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

  select coalesce(jsonb_agg(s.x order by s.ord), '[]'::jsonb)
    into v_conf
    from (select a.x, a.ord
            from jsonb_array_elements(coalesce(OLD.conf, '[]'::jsonb) || v_newc) with ordinality as a(x, ord)
           where coalesce((a.x->>'at')::numeric, 0) > v_ack
           order by a.ord desc
           limit 20) s;

  -- (h) Ergebnis zusammensetzen.
  if v_patch <> '{}'::jsonb then
    NEW := jsonb_populate_record(NEW, v_patch);
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
  'BEFORE INSERT OR UPDATE auf patients (Phase 6.5): serverseitiger Feldgruppen-Merge (jüngerer Stempel je Gruppe), Grabstein-Schutz (Grabstein = nur Gruppe del, Inhalt bleibt, D6.5-19), Konflikt-Marker, Klemmen von Zukunftsstempeln. Keine Folge-UPDATEs.';

-- Trigger-Anlage unverändert (0025); zur Sicherheit idempotent erneut.
drop trigger if exists argus_patients_merge_biu on public.patients;
create trigger argus_patients_merge_biu
  before insert or update on public.patients
  for each row
  execute function public.argus_patients_merge();

-- ── 2) Capability-Probe v:27 ───────────────────────────────────────────────
create or replace function public.argus_server_time()
  returns jsonb
  language plpgsql
  volatile
  set search_path to 'public'
as $function$
begin
  return jsonb_build_object(
    'now', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'v',   27
  );
end;
$function$;

grant execute on function public.argus_server_time() to anon;

comment on function public.argus_server_time() is
  'Capability-/Zeit-Probe (Phase 6.5): {now: Server-ms, v: Schema-Version 27}. Ohne Claims aufrufbar.';
