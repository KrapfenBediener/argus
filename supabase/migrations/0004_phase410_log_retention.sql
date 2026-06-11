-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 4.10 — Log-Retention: governance_log/purge_log nach 12 Monaten löschen
-- ============================================================================
-- Serverseitige Umsetzung von D-01 (Datenschutz-Schlusspaket, 2026-06-11):
-- governance_log und purge_log enthalten Bediener-Kürzel (pseudonyme Daten)
-- und wuchsen bisher unbegrenzt. Einträge älter als 12 Monate (Modell
-- § 73 Abs. 5 PolG BW) werden künftig automatisch gelöscht — als neuer
-- Schritt (d) DIREKT in der bestehenden Funktion argus_run_purge (create or
-- replace). Keine zweite Cron-Infrastruktur: der Job 'argus_purge'
-- (0002, Abschnitt 11, stündlich '17 * * * *') bleibt wörtlich unverändert.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → 0003_phase49_einsatzprotokoll.sql →
--   dieses Skript.
--
-- Anwendung wie 0001–0003: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — zweifaches Anwenden ist gefahrlos (nur
-- create or replace / grant / comment, kein create table, kein alter).
--
-- Zeitbasis — ABWEICHUNG vom 12-Monats-Wortlaut des CONTEXT (verifiziert
-- in 0002): die beiden Log-Tabellen sind unterschiedlich typisiert und
-- werden deshalb mit zwei verschiedenen Vergleichen gelöscht:
--   * governance_log.at ist bigint in JS-Millisekunden (Date.now()) —
--     Vergleich gegen v_now minus 365 Tage in Millisekunden (zwölf Monate
--     als 365 Tage gerechnet, konsistent zur ms-Konvention aus 0002).
--   * purge_log.at ist timestamptz (default now(), reines Server-Protokoll,
--     einzige timestamptz-Ausnahme laut 0002) — Vergleich gegen now() minus
--     ein kalendarisches Zwölf-Monats-Intervall. NICHT in bigint umrechnen:
--     der Spaltentyp wird respektiert.
--
-- KEINE Rekursion: Schritt (d) schreibt NICHTS in purge_log/governance_log.
-- Der Wiederholungs-Guard ist damit inhärent — gelöscht werden nur Rows
-- jenseits der Frist; ein leeres Ergebnis erzeugt keinerlei Eintrag und
-- der stündliche Cron produziert keinen Log-Spam.
-- ============================================================================

-- ── 1) argus_run_purge: Neufassung mit Schritt (d) Log-Retention ────────────
-- Schritte (a) Foto, (b) Frist, (c) Inaktiv sind wörtlich aus 0002
-- übernommen (KEINE inhaltliche Änderung); neu ist ausschließlich
-- Schritt (d) sowie der zusätzliche Schlüssel 'log_retention' im
-- Return-JSON (rein additiv — die App wertet das Ergebnis des
-- opportunistischen App-Start-Aufrufs nicht aus).
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

  return jsonb_build_object(
    'foto',    jsonb_build_object('ccps', c_foto,    'fotos', n_foto),
    'frist',   jsonb_build_object('ccps', c_frist,   'patients', n_pat_frist,   'checklists', n_chk_frist),
    'inaktiv', jsonb_build_object('ccps', c_inaktiv, 'patients', n_pat_inaktiv, 'checklists', n_chk_inaktiv),
    'log_retention', jsonb_build_object('governance_log', n_glog, 'purge_log', n_plog)
  );
end;
$function$;

-- ── 2) Grant erneut setzen (Idempotenz-/Sicherheitsnetz wie 0002) ────────────
grant execute on function public.argus_run_purge() to anon;

-- ── 3) Funktions-Kommentar mit der 12-Monats-Regel ───────────────────────────
comment on function public.argus_run_purge() is
  'Stündlicher Purge-Lauf (pg_cron argus_purge, 17 * * * *): (a) Foto-Purge, '
  '(b) Daten-Purge nach Fristablauf, (c) Inaktivitäts-Auffangnetz, '
  '(d) Log-Retention: governance_log- und purge_log-Einträge älter als '
  '12 Monate werden gelöscht (D-01, Modell § 73 Abs. 5 PolG BW); '
  'Schritt (d) erzeugt selbst keinen Log-Eintrag.';
