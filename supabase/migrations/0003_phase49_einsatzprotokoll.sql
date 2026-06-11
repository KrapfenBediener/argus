-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Phase 4.9 — Einsatzprotokoll-Modell: Zwangs-Log, 72-h-Grundfrist,
--             revoked-Flag, RLS-Härtung geschlossener Einsätze
-- ============================================================================
-- Serverseitiger Unterbau für die Leitungs-Seite (Plan 04.9-02) und den
-- Feld-App-Umbau (Plan 04.9-03). Owner-Entscheide 2026-06-10:
--   * Abgeschlossene Einsätze sind nur noch als Einsatzprotokoll über
--     Governance-RPCs einsehbar; jeder Protokoll-Abruf wird mit Kürzel +
--     Zeitstempel festgehalten.
--   * Fotos werden 72 h nach Abschluss HART gelöscht — keine Verlängerung mehr.
--   * Das Einsatzprotokoll (Daten ohne Fotos) hat ebenfalls 72 h Grundfrist,
--     ist aber mit Pflicht-Begründung verlängerbar (Wiedervorlage).
--   * Zugangs-Codes können gesperrt werden (revoked-Flag, Exchange + Re-Check).
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → dieses Skript.
--
-- Anwendung wie 0001/0002: über die Supabase Management API
-- (POST /v1/projects/{ref}/database/query, Authorization: Bearer <PAT>).
-- Das Skript ist idempotent — zweifaches Anwenden ist gefahrlos.
--
-- Zeitstempel-Konvention: alle Frist-/Zeitwerte sind bigint in
-- JS-Millisekunden (Date.now()), NICHT timestamptz (vgl. 0002).
-- ============================================================================

-- ── 1) revoked-Flag auf access_tokens ───────────────────────────────────────
-- Ein gesperrter Code kann nicht mehr eingetauscht werden (Prüfung in
-- argus_exchange_code unten) und wird der Feld-App beim Re-Check
-- (argus_check_code) als gesperrt gemeldet. Bereits ausgestellte JWTs bleiben
-- bis zu ihrem exp gültig — bewusst akzeptiertes Rest-Risiko, echte
-- Identitäten kommen erst in Phase 7.
alter table public.access_tokens add column if not exists revoked boolean not null default false;

-- ── 2) argus_exchange_code: Neufassung mit revoked-Prüfung ──────────────────
-- Identisch zur Fassung aus 0001, plus: revoked wird mitgelesen und direkt
-- nach der not-found-Prüfung abgewiesen. Eigener Wortlaut 'Code wurde
-- gesperrt' (unterscheidbar vom generischen 'Ungültiger oder verbrauchter
-- Code') — die Feld-App zeigt ihn dem Nutzer an.
create or replace function public.argus_exchange_code(code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions', 'vault'
as $function$
declare
  v_clean       text;
  v_short_code  text;
  v_token       record;
  v_ttl_secs    int;
  v_now         int;
  v_exp         int;
  v_jwt         text;
  v_jwt_secret  text;
  v_pname       text;
begin
  v_clean := upper(regexp_replace(code, '[\s\-]', '', 'g'));
  if length(v_clean) < 8 then
    return jsonb_build_object('error', 'Code zu kurz');
  end if;
  v_short_code := substring(v_clean,1,4) || '-' || substring(v_clean,5,4);

  select praesidium_id, is_master, ttl_hours, single_use, used_at, revoked
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  if v_token.single_use and v_token.used_at is not null then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;

  v_now := extract(epoch from now())::int;
  v_ttl_secs := case
    when v_token.is_master then 30*24*3600
    when v_token.ttl_hours is not null then v_token.ttl_hours*3600
    else 30*24*3600 end;
  v_exp := v_now + v_ttl_secs;

  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret'
  limit 1;

  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  v_jwt := extensions.sign(
    json_build_object(
      'iss', 'supabase',
      'sub', 'argus-device',
      'role', 'anon',
      'praesidium_id', v_token.praesidium_id,
      'is_master', coalesce(v_token.is_master, false),
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  if v_token.single_use and v_token.used_at is null then
    -- used_at ist bigint (JS-Millisekunden, vgl. nowMs()/Date.now() in der App),
    -- NICHT timestamptz. now() würde mit Fehler 42804 abbrechen.
    update public.access_tokens
    set used_at = (extract(epoch from now())*1000)::bigint
    where short_code = v_short_code and used_at is null;
  end if;

  if v_token.praesidium_id is not null then
    select name into v_pname from public.praesidien
    where id = v_token.praesidium_id;
  end if;

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'praesidium_id',   v_token.praesidium_id,
    'praesidium_name', v_pname,
    'is_master',       coalesce(v_token.is_master, false),
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;
grant execute on function public.argus_exchange_code(text) to anon;

-- ── 3) RPC: Code-Re-Check (ohne Seiteneffekte) ──────────────────────────────
-- Zweck: Re-Check der Feld-App beim Start/Reconnect — wurde der eigene Code
-- gesperrt? Gibt bewusst NUR das Minimum zurück ({found, revoked}): kein JWT,
-- kein used_at-Update, kein Präsidiums-Leak. Normalisierung identisch zu
-- argus_exchange_code.
create or replace function public.argus_check_code(code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_clean      text;
  v_short_code text;
  v_revoked    boolean;
begin
  v_clean := upper(regexp_replace(code, '[\s\-]', '', 'g'));
  if v_clean is null or length(v_clean) < 8 then
    return jsonb_build_object('found', false, 'revoked', false);
  end if;
  v_short_code := substring(v_clean,1,4) || '-' || substring(v_clean,5,4);

  select revoked into v_revoked
  from public.access_tokens where short_code = v_short_code;

  if not found then
    return jsonb_build_object('found', false, 'revoked', false);
  end if;
  return jsonb_build_object('found', true, 'revoked', coalesce(v_revoked, false));
end;
$function$;
grant execute on function public.argus_check_code(text) to anon;

-- ── 4) argus_close_einsatz: einheitliche 72-h-Grundfrist ────────────────────
-- KOMPATIBILITÄT: Signatur bleibt UNVERÄNDERT (p_frist_tage erhält nur einen
-- Default) — v0.22.0-Geräte übergeben beim Abschluss noch 14/30 Tage; der
-- Parameter wird ab jetzt IGNORIERT, die Frist-Validierung entfällt ersatzlos.
-- Beide Fristen entstehen einheitlich beim Abschluss: Abschluss + 72 h.
-- Verlängerbar ist danach nur noch purge_after (Punkt 9); photo_purge_after
-- ist HART. Berechtigungs- und merge_group-Logik unverändert aus 0002
-- (Einsatz = Verbund; join_token = null sperrt den Beitritt).
create or replace function public.argus_close_einsatz(p_ccp_id uuid, p_typ text, p_frist_tage int default null)
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
  -- p_frist_tage wird bewusst NICHT geprüft und NICHT verwendet (s. o.).

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
    purge_after       = coalesce(closed_at, v_now) + 72::bigint * 3600000,
    photo_purge_after = coalesce(closed_at, v_now) + 72::bigint * 3600000,
    join_token        = null
  where id = p_ccp_id
     or (v_ccp.merge_group_id is not null and merge_group_id = v_ccp.merge_group_id);
  get diagnostics v_count = row_count;

  return jsonb_build_object(
    'closed_at',         v_now,
    'purge_after',       v_now + 72::bigint * 3600000,
    'photo_purge_after', v_now + 72::bigint * 3600000,
    'ccp_count',         v_count
  );
end;
$function$;
grant execute on function public.argus_close_einsatz(uuid, text, int) to anon;

-- ── 5) RPC: Liste der Einsatzprotokolle (ohne Inhalte, ohne Log-Eintrag) ────
-- Reine Liste für die Leitungs-Seite (analog zur entfallenen
-- argus_governance_list): abgeschlossene, noch NICHT gepurgte Einsätze.
-- „Noch nicht gepurged" ist WÖRTLICH an die Purge-Bedingung (b) aus
-- argus_run_purge (0002) angeglichen: Liste und Purge teilen EINE Definition.
-- Ein bloßer (exists patients ODER exists checklists)-Filter würde
-- abgeschlossene Einsätze ohne Patienten und Checklisten (aber mit noch
-- laufender purge_after und vorhandenen Kopfdaten) unsichtbar machen, obwohl
-- ihre Löschfrist läuft und über die Leitungs-Seite sichtbar/verlängerbar
-- sein muss (Wiedervorlage). Vollständig gepurgte Einsätze (Tombstones)
-- erscheinen nur noch im purge_log (Bereich „Protokoll" der Leitungs-Seite).
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
           'patient_count',     (select count(*)       from public.patients   p where p.ccp_id = c.id),
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

-- ── 6) RPC: Einsatzprotokoll-Abruf (jeder Abruf wird protokolliert) ─────────
-- Muster argus_governance_photo: SECURITY-DEFINER, Master-Pflicht,
-- Kürzel-Pflicht, Zwangs-Log VOR der Rückgabe. Bei gesetzter merge_group_id
-- umfasst das Protokoll alle CCPs des Verbunds (Einsatz = Verbund).
-- Foto-Daten kommen NIE über diesen RPC — Patienten werden ohne den
-- photo-Schlüssel geliefert (nur has_photo-Flag); der Einzelabruf läuft über
-- den separat protokollierten argus_governance_photo (Punkt 7).
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
           (to_jsonb(p) - 'photo' - 'locked_by' - 'locked_at')
             || jsonb_build_object('has_photo', p.photo is not null)
           order by p.ccp, p.num), '[]'::jsonb)
  into v_patients
  from public.patients p
  where p.ccp_id = p_ccp_id
     or (v_ccp.merge_group_id is not null
         and p.ccp_id in (select id from public.ccps where merge_group_id = v_ccp.merge_group_id));

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
    'checklists', v_checklists
  );
end;
$function$;
grant execute on function public.argus_governance_protokoll(uuid, text) to anon;

-- ── 7) argus_governance_photo bleibt bestehen ───────────────────────────────
-- Der Foto-Einzelabruf mit foto_view-Log (0002, Abschnitt 7) wird von der
-- Leitungs-Seite weiterverwendet: der Protokoll-RPC (Punkt 6) liefert bewusst
-- keine Base64-Fotos, Fotos werden einzeln und je Abruf protokolliert
-- nachgeladen (Lazy-Load). Keine Code-Änderung an der Funktion.

-- ── 8) argus_governance_list entfernen (keine toten RPCs) ───────────────────
-- Ersetzt durch argus_governance_einsaetze (Punkt 5). Einziger Konsument war
-- das Feld-App-Governance-Panel (v0.21.1–v0.22.0), das in Plan 04.9-03
-- zurückgebaut wird — bis zum App-Update zeigt das alte Panel auf
-- Master-Geräten einen Fehlertext (bewusst akzeptiert, reine
-- MasterUser-Funktion).
drop function if exists public.argus_governance_list();

-- ── 9) Frist-Verlängerung: argus_extend_photo_frist → argus_extend_protokoll_frist ──
-- Owner-Entscheid 2026-06-10: Fotos sind HART (72 h nach Abschluss, KEINE
-- Verlängerung) — verlängerbar ist nur noch das Einsatzprotokoll (Daten ohne
-- Fotos), d. h. die Verlängerung wirkt auf purge_after, NICHT auf
-- photo_purge_after. Die alte Foto-Verlängerungsfunktion entfällt ersatzlos
-- (keine toten RPCs). Wirkt wie argus_close_einsatz auf den ganzen Verbund.
drop function if exists public.argus_extend_photo_frist(uuid, text, text, int);

create or replace function public.argus_extend_protokoll_frist(p_ccp_id uuid, p_kuerzel text, p_grund text, p_stunden int default 72)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now bigint := (extract(epoch from now())*1000)::bigint;
  v_ccp record;
  v_neu bigint;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  if p_kuerzel is null or btrim(p_kuerzel) = '' then
    raise exception 'Kürzel erforderlich';
  end if;
  if p_grund is null or btrim(p_grund) = '' then
    raise exception 'Begründung erforderlich';
  end if;
  if p_stunden is null or p_stunden < 1 or p_stunden > 720 then
    raise exception 'Verlängerung muss zwischen 1 und 720 Stunden liegen';
  end if;

  select id, merge_group_id, closed_at, purge_after into v_ccp
  from public.ccps where id = p_ccp_id;
  if not found then
    raise exception 'CCP nicht gefunden';
  end if;
  if v_ccp.closed_at is null then
    raise exception 'Einsatz noch offen';
  end if;

  v_neu := greatest(v_now, coalesce(v_ccp.purge_after, v_now)) + p_stunden::bigint * 3600000;
  -- Update auf die Row UND alle Rows derselben merge_group — der Einsatz =
  -- der Verbund, konsistent zu argus_close_einsatz.
  update public.ccps set purge_after = v_neu
  where id = p_ccp_id
     or (v_ccp.merge_group_id is not null and merge_group_id = v_ccp.merge_group_id);

  insert into public.governance_log (at, ccp_id, kuerzel, action, begruendung, neue_frist)
    values (v_now, p_ccp_id, btrim(p_kuerzel), 'frist_verlaengert', btrim(p_grund), v_neu);

  return jsonb_build_object('purge_after', v_neu);
end;
$function$;
grant execute on function public.argus_extend_protokoll_frist(uuid, text, text, int) to anon;

-- ── 10) RLS-Härtung: Inhalte geschlossener Einsätze nur noch via Governance ─
-- (a) patients: die Lese-Policy bindet Nicht-Master zusätzlich an einen
-- OFFENEN CCP (closed_at is null) — nach dem Abschluss sind Patientendaten
-- für Feld-Geräte nicht mehr lesbar, nur noch über die protokollierten
-- Governance-RPCs (SECURITY-DEFINER, von RLS nicht betroffen). Die
-- Schreib-Policy argus_patients_write (0002) hatte diese Bindung bereits.
drop policy if exists argus_patients_select on public.patients;
create policy "argus_patients_select" on public.patients for select to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()
                          and closed_at is null) );

-- (b) checklists nachziehen: dieselbe Trennung wie bei patients (0002) —
-- Lesen UND Schreiben für Nicht-Master nur bei offenem CCP.
drop policy if exists argus_checklists_rw     on public.checklists;
drop policy if exists argus_checklists_select on public.checklists;
drop policy if exists argus_checklists_write  on public.checklists;

create policy "argus_checklists_select" on public.checklists for select to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()
                          and closed_at is null) );

create policy "argus_checklists_write" on public.checklists for all to anon
  using ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()
                          and closed_at is null) )
  with check ( public.argus_is_master()
          or ccp_id in (select id from public.ccps
                        where praesidium_id = public.argus_praesidium_id()
                          and closed_at is null) );

-- (c) argus_ccps_select bleibt UNVERÄNDERT (0002, Abschnitt 10): die Feld-App
-- erkennt den Einsatz-Abschluss über die weiterhin lesbare Tombstone-Row
-- (checkClosedEinsatz/applyMeta in index.html); nur die INHALTE
-- (patients/checklists) sind für Nicht-Master nach Abschluss gesperrt.

-- ── 11) pg_cron/Purge: keine Änderung nötig ─────────────────────────────────
-- argus_run_purge und der Job argus_purge (0002, Abschnitte 5 + 11) bleiben
-- unverändert: die 72-h-Grundfrist entsteht ausschließlich beim Abschluss
-- (Punkt 4) bzw. per Verlängerung (Punkt 9); die Purge-Funktion liest nur
-- purge_after/photo_purge_after und braucht keine Anpassung.
comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view';
