-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 5 (Plan 02) — T4-Audit-Retention: audit_log nach 12 Monaten löschen
-- ============================================================================
-- Serverseitige Umsetzung von D-07 (Phase-5-CONTEXT, § 73 PolG BW):
-- audit_log enthält USBNK-bezogene Einträge (personenbezogene Daten)
-- und würde sonst unbegrenzt wachsen. Einträge älter als 12 Monate
-- (365 Tage in ms, analog governance_log aus 0004) werden als neuer
-- Schritt (e) DIREKT in die bestehende Funktion argus_run_purge
-- (create or replace) integriert. Keine zweite Cron-Infrastruktur:
-- der Job 'argus_purge' (0002, Abschnitt 11, stündlich '17 * * * *')
-- bleibt wörtlich unverändert und ruft die erweiterte Funktion auf.
--
-- Voraussetzung: audit_log-Tabelle ist in 0015 angelegt — dieses
-- Skript ergänzt nur die Retention.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → 0003_phase49_einsatzprotokoll.sql →
--   0004_phase410_log_retention.sql → … → 0015_phase5_identitaeten.sql →
--   dieses Skript.
--
-- Anwendung wie 0001–0015: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — zweifaches Anwenden ist gefahrlos (nur
-- create or replace / grant / comment, kein create table, kein alter).
--
-- Zeitbasis: audit_log.at ist bigint in JS-Millisekunden (Date.now()) —
-- identische Konvention wie governance_log (0004 Schritt d).
-- Vergleich gegen v_now minus 365 Tage in Millisekunden.
--
-- KEINE Rekursion: Schritt (e) schreibt NICHTS in audit_log/purge_log.
-- Ein leeres Ergebnis erzeugt keinerlei Eintrag — kein Log-Spam.
-- ============================================================================

-- ── 1) argus_run_purge: Neufassung mit Schritt (e) audit_log-Retention ───────
-- Schritte (a) Foto, (b) Frist, (c) Inaktiv, (d) Log-Retention sind wörtlich
-- aus 0004 übernommen (KEINE inhaltliche Änderung); neu ist ausschließlich
-- Schritt (e) sowie der zusätzliche Schlüssel 'audit_log_retention' im
-- Return-JSON (rein additiv — bestehende Schlüssel bleiben unverändert).
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
  n_glog    int := 0;  n_plog        int := 0;
  n_alog    int := 0;
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

  -- (d) Log-Retention 12 Monate (D-01): governance_log- und purge_log-
  -- Einträge jenseits der Frist löschen. governance_log.at = bigint-ms
  -- (Cutoff: 365 Tage in ms), purge_log.at = timestamptz (kalendarisches
  -- Zwölf-Monats-Intervall) — siehe Abweichungs-Vermerk im Kopf.
  -- Bewusst KEIN purge_log-/governance_log-Eintrag über diesen Schritt
  -- (keine Rekursion, kein Eintrag bei leerem Ergebnis).
  delete from public.governance_log
    where at is not null and at <= v_now - 365::bigint * 86400000;
  get diagnostics n_glog = row_count;

  delete from public.purge_log
    where at is not null and at <= now() - interval '12 months';
  get diagnostics n_plog = row_count;

  -- (e) audit_log-Retention 12 Monate (D-07, § 73 PolG BW): T4-Audit-Einträge
  -- jenseits der Frist löschen. audit_log.at = bigint-ms (identische Konvention
  -- wie governance_log.at, Cutoff: 365 Tage in ms).
  -- Bewusst KEIN audit_log-/purge_log-Eintrag über diesen Schritt
  -- (keine Rekursion, kein Log-Spam bei leerem Ergebnis — analog Schritt d).
  delete from public.audit_log
    where at is not null and at <= v_now - 365::bigint * 86400000;
  get diagnostics n_alog = row_count;

  return jsonb_build_object(
    'foto',    jsonb_build_object('ccps', c_foto,    'fotos', n_foto),
    'frist',   jsonb_build_object('ccps', c_frist,   'patients', n_pat_frist,   'checklists', n_chk_frist),
    'inaktiv', jsonb_build_object('ccps', c_inaktiv, 'patients', n_pat_inaktiv, 'checklists', n_chk_inaktiv),
    'log_retention', jsonb_build_object('governance_log', n_glog, 'purge_log', n_plog),
    'audit_log_retention', jsonb_build_object('audit_log', n_alog)
  );
end;
$function$;

-- ── 2) Grant erneut setzen (Idempotenz-/Sicherheitsnetz wie 0004) ────────────
grant execute on function public.argus_run_purge() to anon;

-- ── 3) Funktions-Kommentar nachziehen ────────────────────────────────────────
comment on function public.argus_run_purge() is
  'Stündlicher Purge-Lauf (pg_cron argus_purge, 17 * * * *): (a) Foto-Purge, '
  '(b) Daten-Purge nach Fristablauf, (c) Inaktivitäts-Auffangnetz, '
  '(d) Log-Retention: governance_log- und purge_log-Einträge älter als '
  '12 Monate werden gelöscht (D-01, Modell § 73 Abs. 5 PolG BW); '
  'Schritt (d) erzeugt selbst keinen Log-Eintrag. '
  '(e) audit_log-Retention: T4-Audit-Einträge älter als 12 Monate werden '
  'gelöscht (D-07, Modell § 73 PolG BW); '
  'Schritt (e) erzeugt selbst keinen Log-Eintrag.';
