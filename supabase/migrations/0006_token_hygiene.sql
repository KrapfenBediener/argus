-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Token-Hygiene: 24-h-Codes abgeschafft, verbrauchte Einmal-Codes 6 Monate
-- ============================================================================
-- Owner-Entscheid 2026-06-12 (Chat, nach Phase 4.12):
--   * Die reine Code-Art „24 h" (temporary, NICHT single_use) ist abgeschafft.
--     Sie war doppelt irreführend: die TTL begrenzte nur die JWT-Laufzeit
--     (Anmeldedauer am Gerät), der Code selbst blieb unbegrenzt einlösbar.
--     Operativ existieren nur noch: Dauerhaft, Einmalig (single_use, nach
--     Einlösung verbraucht, JWT 24 h), Beobachter (FLZ), MasterToken.
--     Bestehende 24-h-Codes werden hier einmalig GELÖSCHT (Stand 2026-06-12:
--     2 Stück, beide nie benutzt) und die Leitungs-Seite bietet die Art nicht
--     mehr an.
--   * Verbrauchte Einmal-Codes (single_use, used_at gesetzt) sind funktionslos
--     und werden 6 MONATE nach ihrer Einlösung automatisch gelöscht — neuer
--     Schritt (e) in argus_run_purge. 6 Monate = Owner-Vorgabe: lang genug,
--     dass die Leitung in den Zugängen nachvollziehen kann, wer kürzlich
--     Zugang erhielt; deutlich unter der 12-Monats-Log-Frist aus 0004.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000 → 0001 → 0002 → 0003 → 0004 → 0005 → dieses Skript.
--
-- Anwendung wie 0001–0005: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Idempotent — zweifaches Anwenden ist gefahrlos (delete trifft beim zweiten
-- Lauf keine Rows mehr; sonst nur create or replace / grant / comment).
--
-- Zeitbasis: used_at ist bigint in JS-Millisekunden (Date.now(), vgl. 0000);
-- 6 Monate werden als 182 Tage in ms gerechnet (konsistent zur ms-Konvention
-- aus 0002/0004, die 12 Monate als 365 Tage rechnet).
--
-- KEIN Log-Eintrag für Schritt (e): purge_log ist CCP-/inhaltsbezogen
-- (kennung, patient_count, …) und passt nicht auf Token-Zeilen; ein
-- verbrauchter Code trägt keinerlei Personenbezug. Verhalten damit
-- konsistent zu Schritt (d) aus 0004 (Log-Retention loggt sich auch
-- nicht selbst).
-- ============================================================================

-- ── 1) Einmalige Bereinigung: reine 24-h-Codes entfernen ────────────────────
-- Trifft NUR temporary && !single_use — Einmal-Links sind ebenfalls
-- temporary (JWT-TTL 24 h), aber single_use und bleiben unberührt.
-- Master/Observer sind nie temporary, die Guards sind ein Sicherheitsnetz.
delete from public.access_tokens
 where temporary
   and not single_use
   and not coalesce(is_master, false)
   and not coalesce(observer, false);

-- ── 2) argus_run_purge: Neufassung mit Schritt (e) Token-Hygiene ────────────
-- Schritte (a)–(d) sind wörtlich aus 0004 übernommen (KEINE inhaltliche
-- Änderung); neu ist ausschließlich Schritt (e) sowie der zusätzliche
-- Schlüssel 'token_hygiene' im Return-JSON (rein additiv).
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
  n_tok     int := 0;
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

  -- (d) Log-Retention 12 Monate (0004): governance_log- und purge_log-
  -- Einträge jenseits der Frist löschen. governance_log.at = bigint-ms
  -- (Cutoff: 365 Tage in ms), purge_log.at = timestamptz (kalendarisches
  -- Zwölf-Monats-Intervall). Bewusst KEIN Log-Eintrag über diesen Schritt
  -- (keine Rekursion, kein Eintrag bei leerem Ergebnis).
  delete from public.governance_log
    where at is not null and at <= v_now - 365::bigint * 86400000;
  get diagnostics n_glog = row_count;

  delete from public.purge_log
    where at is not null and at <= now() - interval '12 months';
  get diagnostics n_plog = row_count;

  -- (e) Token-Hygiene (Owner-Entscheid 2026-06-12): verbrauchte Einmal-Codes
  -- 6 Monate (182 Tage in ms) nach ihrer Einlösung löschen. Trifft NUR
  -- single_use-Codes mit gesetztem used_at — Dauerhaft/Beobachter/Master
  -- haben kein used_at bzw. sind nicht single_use. Kein Log-Eintrag (s. Kopf).
  delete from public.access_tokens
    where single_use
      and used_at is not null
      and used_at <= v_now - 182::bigint * 86400000;
  get diagnostics n_tok = row_count;

  return jsonb_build_object(
    'foto',    jsonb_build_object('ccps', c_foto,    'fotos', n_foto),
    'frist',   jsonb_build_object('ccps', c_frist,   'patients', n_pat_frist,   'checklists', n_chk_frist),
    'inaktiv', jsonb_build_object('ccps', c_inaktiv, 'patients', n_pat_inaktiv, 'checklists', n_chk_inaktiv),
    'log_retention', jsonb_build_object('governance_log', n_glog, 'purge_log', n_plog),
    'token_hygiene', jsonb_build_object('einmal_codes', n_tok)
  );
end;
$function$;

-- ── 3) Grant erneut setzen (Idempotenz-/Sicherheitsnetz wie 0002/0004) ───────
grant execute on function public.argus_run_purge() to anon;

-- ── 4) Funktions-Kommentar aktualisieren ─────────────────────────────────────
comment on function public.argus_run_purge() is
  'Stündlicher Purge-Lauf (pg_cron argus_purge, 17 * * * *): (a) Foto-Purge, '
  '(b) Daten-Purge nach Fristablauf, (c) Inaktivitäts-Auffangnetz, '
  '(d) Log-Retention: governance_log/purge_log älter 12 Monate (0004), '
  '(e) Token-Hygiene: verbrauchte Einmal-Codes 6 Monate nach Einlösung '
  'löschen (0006). Schritte (d)/(e) erzeugen selbst keinen Log-Eintrag.';
