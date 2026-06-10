-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 4.8 — Datenschutz-Härtung: Einsatz-Lebenszyklus, Purge, Governance
-- ============================================================================
-- Serverseitiger Unterbau für „Einsatz abschließen + automatische Löschung"
-- und den Foto-Lebenszyklus mit Governance-Protokoll (fachliche Begründung:
-- siehe interne SPEC T1/T2 — nicht Teil dieses Repos).
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql → dieses Skript.
--
-- Anwendung wie 0001: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — zweifaches Anwenden ist gefahrlos.
--
-- Zeitstempel-Konvention: alle neuen Frist-/Zeitspalten sind bigint in
-- JS-Millisekunden (Date.now()), NICHT timestamptz (vgl. used_at in 0000).
-- Einzige Ausnahme: purge_log.at (reines Server-Protokoll, timestamptz ok).
-- ============================================================================

-- ── 1) Einsatz-Lebenszyklus-Spalten auf ccps ────────────────────────────────
-- einsatz_typ        null = offen; beim Abschluss 'uebung' oder 'einsatz'
-- purge_after        ms-Zeitpunkt der Datenlöschung (Patienten/Checklisten)
-- photo_purge_after  ms-Zeitpunkt der endgültigen Foto-Löschung (Abschluss+72h,
--                    via Governance verlängerbar)
-- photos_allowed     einsatzweiter Foto-Schalter, Default AUS
alter table public.ccps add column if not exists einsatz_typ        text;
alter table public.ccps add column if not exists purge_after        bigint;
alter table public.ccps add column if not exists photo_purge_after  bigint;
alter table public.ccps add column if not exists photos_allowed     boolean not null default false;

-- ── 2) purge_log — inhaltsfreies Lösch-Protokoll ────────────────────────────
-- Protokolliert NUR Datum, Einsatz-ID/Kennung, Grund und Anzahlen — keine
-- Patientendaten. Schreiben ausschließlich über SECURITY-DEFINER-Funktionen
-- (keine anon-Insert-Policy). Lesen nur mit Master-JWT.
create table if not exists public.purge_log (
  id              uuid primary key default gen_random_uuid(),
  at              timestamptz default now(),
  ccp_id          uuid,
  kennung         text,
  reason          text,        -- 'frist' | 'inaktiv' | 'foto_72h'
  patient_count   int,
  photo_count     int,
  checklist_count int
);
grant select on public.purge_log to anon;
alter table public.purge_log enable row level security;
drop policy if exists argus_purge_log_select on public.purge_log;
create policy "argus_purge_log_select" on public.purge_log
  for select to anon using ( public.argus_is_master() );

-- ── 3) governance_log — Protokoll für Foto-Zugriff & Fristverlängerung ─────
-- Jeder Governance-Foto-Abruf und jede Fristverlängerung wird hier mit
-- Kürzel + Zeitstempel festgehalten. Schreiben nur über SECURITY-DEFINER-
-- Funktionen; Lesen nur mit Master-JWT.
create table if not exists public.governance_log (
  id          uuid primary key default gen_random_uuid(),
  at          bigint,          -- JS-Millisekunden
  ccp_id      uuid,
  patient_id  text,
  kuerzel     text,
  action      text,            -- 'foto_view' | 'frist_verlaengert'
  begruendung text,
  neue_frist  bigint
);
grant select on public.governance_log to anon;
alter table public.governance_log enable row level security;
drop policy if exists argus_governance_log_select on public.governance_log;
create policy "argus_governance_log_select" on public.governance_log
  for select to anon using ( public.argus_is_master() );

-- ── 4) RPC: Einsatz abschließen ─────────────────────────────────────────────
-- Berechtigung: Master ODER der CCP gehört zum Präsidium des Aufrufers.
-- Die MasterMedic-Eigenschaft ist nur App-seitig bekannt — serverseitig ist
-- das Präsidium die Berechtigungsgrenze.
-- Wirkung: bei gesetzter merge_group_id für ALLE CCPs der Gruppe (Einsatz =
-- Verbund), sonst nur für den einen CCP. join_token = null sperrt den Beitritt.
create or replace function public.argus_close_einsatz(p_ccp_id uuid, p_typ text, p_frist_tage int)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now   bigint := (extract(epoch from now())*1000)::bigint;
  v_ccp   record;
  v_count int;
begin
  if p_typ is null or p_typ not in ('uebung','einsatz') then
    return jsonb_build_object('error', 'Ungültiger Einsatz-Typ');
  end if;
  if p_frist_tage is null or p_frist_tage < 1 or p_frist_tage > 365 then
    return jsonb_build_object('error', 'Frist muss zwischen 1 und 365 Tagen liegen');
  end if;

  select id, praesidium_id, merge_group_id into v_ccp
  from public.ccps where id = p_ccp_id;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  update public.ccps set
    closed_at         = coalesce(closed_at, v_now),
    einsatz_typ       = p_typ,
    purge_after       = coalesce(closed_at, v_now) + p_frist_tage::bigint * 86400000,
    photo_purge_after = coalesce(closed_at, v_now) + 72::bigint * 3600000,
    join_token        = null
  where id = p_ccp_id
     or (v_ccp.merge_group_id is not null and merge_group_id = v_ccp.merge_group_id);
  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'closed_at',         v_now,
    'purge_after',       v_now + p_frist_tage::bigint * 86400000,
    'photo_purge_after', v_now + 72::bigint * 3600000,
    'ccp_count',         v_count
  );
end;
$function$;
grant execute on function public.argus_close_einsatz(uuid, text, int) to anon;

-- ── 5) RPC: Purge-Lauf ──────────────────────────────────────────────────────
-- Löscht ausschließlich Fälliges und gibt nur Zähler zurück — gefahrlos
-- öffentlich aufrufbar (Cron + opportunistischer App-Start-Aufruf).
-- WIEDERHOLUNGS-GUARDS (Source-Assertion):
--   (a) Foto-Purge matcht nur CCPs, bei denen noch Fotos EXISTIEREN
--       (exists-Prüfung) — photo_purge_after <= now bleibt nach dem ersten
--       Lauf dauerhaft wahr; ohne Guard würde der stündliche Cron denselben
--       CCP jede Stunde erneut loggen.
--   (b) Daten-Purge matcht nur CCPs mit noch vorhandenen patients-/checklists-
--       Rows bzw. noch nicht hergestelltem Tombstone-Zustand.
--   (c) Auffangnetz setzt closed_at — die Row matcht danach nicht erneut.
-- Kein Log-Eintrag bei No-op-Läufen.
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
  c_foto    int := 0;  n_foto        int := 0;
  c_frist   int := 0;  n_pat_frist   int := 0;  n_chk_frist   int := 0;
  c_inaktiv int := 0;  n_pat_inaktiv int := 0;  n_chk_inaktiv int := 0;
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

  -- (b) Daten-Purge nach Fristablauf: Patienten + Checklisten löschen; die
  -- ccps-Row bleibt als inhaltsleerer Tombstone (ort='', master_medic='',
  -- join_token=null) — Geräte erkennen daran den Abschluss für die lokale
  -- Bereinigung.
  for r in
    select c.id, c.kennung from public.ccps c
    where c.purge_after is not null and c.purge_after <= v_now
      and (    exists (select 1 from public.patients   p where p.ccp_id = c.id)
            or exists (select 1 from public.checklists k where k.ccp_id = c.id)
            or coalesce(c.ort,'') <> '' or coalesce(c.master_medic,'') <> ''
            or c.join_token is not null )
  loop
    select count(*), count(photo) into v_pat, v_pho from public.patients   where ccp_id = r.id;
    select count(*)               into v_chk        from public.checklists where ccp_id = r.id;
    delete from public.patients   where ccp_id = r.id;
    delete from public.checklists where ccp_id = r.id;
    update public.ccps set ort = '', master_medic = '', join_token = null where id = r.id;
    insert into public.purge_log (ccp_id, kennung, reason, patient_count, photo_count, checklist_count)
      values (r.id, r.kennung, 'frist', v_pat, v_pho, v_chk);
    c_frist     := c_frist + 1;
    n_pat_frist := n_pat_frist + v_pat;
    n_chk_frist := n_chk_frist + v_chk;
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
    update public.ccps set closed_at = v_now, ort = '', master_medic = '', join_token = null
      where id = r.id;
    insert into public.purge_log (ccp_id, kennung, reason, patient_count, photo_count, checklist_count)
      values (r.id, r.kennung, 'inaktiv', v_pat, v_pho, v_chk);
    c_inaktiv     := c_inaktiv + 1;
    n_pat_inaktiv := n_pat_inaktiv + v_pat;
    n_chk_inaktiv := n_chk_inaktiv + v_chk;
  end loop;

  return jsonb_build_object(
    'foto',    jsonb_build_object('ccps', c_foto,    'fotos', n_foto),
    'frist',   jsonb_build_object('ccps', c_frist,   'patients', n_pat_frist,   'checklists', n_chk_frist),
    'inaktiv', jsonb_build_object('ccps', c_inaktiv, 'patients', n_pat_inaktiv, 'checklists', n_chk_inaktiv)
  );
end;
$function$;
grant execute on function public.argus_run_purge() to anon;

-- ── 6) RPC: Governance-Übersicht (ohne Foto-Daten, ohne Log-Eintrag) ────────
-- Listet Patienten mit vorhandenem Foto, deren Foto aus der Normalansicht
-- bereits entfernt ist (ausgecheckt ODER Einsatz abgeschlossen). Nur Master.
create or replace function public.argus_governance_list()
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
           'patient_id',        p.id,
           'num',               p.num,
           'kennung',           c.kennung,
           'status',            p.status,
           'ccp_id',            c.id,
           'photo_purge_after', c.photo_purge_after
         ) order by c.kennung, p.num), '[]'::jsonb)
  into v
  from public.patients p
  join public.ccps c on c.id = p.ccp_id
  where p.photo is not null
    and (p.status = 'gpa' or c.closed_at is not null);
  return v;
end;
$function$;
grant execute on function public.argus_governance_list() to anon;

-- ── 7) RPC: Governance-Foto-Abruf (jeder Abruf wird protokolliert) ──────────
create or replace function public.argus_governance_photo(p_patient_id text, p_kuerzel text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now    bigint := (extract(epoch from now())*1000)::bigint;
  v_photo  text;
  v_ccp_id uuid;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  if p_kuerzel is null or btrim(p_kuerzel) = '' then
    raise exception 'Kürzel erforderlich';
  end if;
  select photo, ccp_id into v_photo, v_ccp_id
  from public.patients where id = p_patient_id;
  if not found then
    raise exception 'Patient nicht gefunden';
  end if;
  -- Log-Eintrag VOR der Rückgabe — jeder Foto-Abruf = ein Eintrag.
  insert into public.governance_log (at, ccp_id, patient_id, kuerzel, action)
    values (v_now, v_ccp_id, p_patient_id, btrim(p_kuerzel), 'foto_view');
  return jsonb_build_object('photo', v_photo);
end;
$function$;
grant execute on function public.argus_governance_photo(text, text) to anon;

-- ── 8) RPC: Foto-Frist verlängern (nur Master, Pflicht-Begründung) ─────────
create or replace function public.argus_extend_photo_frist(p_ccp_id uuid, p_kuerzel text, p_grund text, p_stunden int default 72)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now bigint := (extract(epoch from now())*1000)::bigint;
  v_old bigint;
  v_neu bigint;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  if p_grund is null or btrim(p_grund) = '' then
    raise exception 'Begründung erforderlich';
  end if;
  if p_kuerzel is null or btrim(p_kuerzel) = '' then
    raise exception 'Kürzel erforderlich';
  end if;
  if p_stunden is null or p_stunden < 1 or p_stunden > 720 then
    raise exception 'Verlängerung muss zwischen 1 und 720 Stunden liegen';
  end if;

  select photo_purge_after into v_old from public.ccps where id = p_ccp_id;
  if not found then
    raise exception 'CCP nicht gefunden';
  end if;

  v_neu := greatest(v_now, coalesce(v_old, v_now)) + p_stunden::bigint * 3600000;
  update public.ccps set photo_purge_after = v_neu where id = p_ccp_id;
  insert into public.governance_log (at, ccp_id, kuerzel, action, begruendung, neue_frist)
    values (v_now, p_ccp_id, btrim(p_kuerzel), 'frist_verlaengert', btrim(p_grund), v_neu);
  return jsonb_build_object('photo_purge_after', v_neu);
end;
$function$;
grant execute on function public.argus_extend_photo_frist(uuid, text, text, int) to anon;

-- ── 9) RLS-Härtung patients: Lese-/Schreib-Policies trennen ─────────────────
-- Schreibzugriffe für Nicht-Master zusätzlich an einen OFFENEN CCP gebunden
-- (closed_at is null). Verspätete Offline-Flushes auf abgeschlossene Einsätze
-- schlagen damit bewusst fehl — die Geräte bereinigen lokal.
-- Hinweis: argus_patients_write ist FOR ALL (Postgres kennt keine
-- Mehr-Kommando-Policy außer ALL); Policies sind permissiv, d. h. für SELECT
-- gilt die großzügigere argus_patients_select, für INSERT/UPDATE/DELETE greift
-- ausschließlich argus_patients_write.
drop policy if exists argus_patients_rw     on public.patients;
drop policy if exists argus_patients_select on public.patients;
drop policy if exists argus_patients_write  on public.patients;

create policy "argus_patients_select" on public.patients for select to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()) );

create policy "argus_patients_write" on public.patients for all to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()
                          and closed_at is null) )
  with check ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()
                          and closed_at is null) );

-- ── 10) RLS-Härtung ccps: Einsatz-Sperre per REST nicht umkehrbar ───────────
-- Zero-Trust-Linie aus Phase 4: ein abgeschlossener CCP (closed_at not null)
-- ist für Präsidiums-Geräte komplett update-/delete-gesperrt — kein Client
-- kann per direkter REST-API closed_at = null setzen, den join_token
-- wiederherstellen oder purge_after/photo_purge_after manipulieren.
-- SOURCE-ASSERTION zur Richtung der Bedingung: die closed_at-is-null-Prüfung
-- steht in der USING-Klausel (Zustand der BESTEHENDEN Row), NICHT in
-- WITH CHECK — das Setzen von closed_at auf einer offenen Row bleibt erlaubt
-- (bestehender Pfad „CCP/Verbund löschen" in index.html), nur das
-- nachträgliche Ändern einer geschlossenen Row ist blockiert. Die
-- SECURITY-DEFINER-RPCs (insb. argus_close_einsatz, argus_extend_photo_frist)
-- sind von RLS nicht betroffen. Master bleibt uneingeschränkt.
drop policy if exists argus_ccps_rw     on public.ccps;
drop policy if exists argus_ccps_select on public.ccps;
drop policy if exists argus_ccps_write  on public.ccps;

create policy "argus_ccps_select" on public.ccps for select to anon
  using ( public.argus_is_master() or praesidium_id = public.argus_praesidium_id() );

create policy "argus_ccps_write" on public.ccps for all to anon
  using ( public.argus_is_master()
          or ( praesidium_id = public.argus_praesidium_id() and closed_at is null ) )
  with check ( public.argus_is_master()
          or praesidium_id = public.argus_praesidium_id() );

-- ── 11) pg_cron: stündlicher Purge-Lauf ─────────────────────────────────────
-- Fehlertolerant gekapselt — auf Instanzen ohne pg_cron bricht die Migration
-- nicht. Fallback ist der opportunistische argus_run_purge()-Aufruf der App
-- beim Start (Plan 04.8-03): so läuft der Purge auch, wenn das Projekt
-- pausiert war und erst durch App-Traffic aufwacht.
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron nicht verfügbar: %', sqlerrm;
  end;
  begin
    perform cron.unschedule('argus_purge');
  exception when others then
    null;  -- Job existiert noch nicht / pg_cron fehlt — idempotent ignorieren
  end;
  begin
    perform cron.schedule('argus_purge', '17 * * * *', 'select public.argus_run_purge()');
  exception when others then
    raise notice 'cron.schedule fehlgeschlagen: % — Fallback: App-Start-Aufruf', sqlerrm;
  end;
end $$;
