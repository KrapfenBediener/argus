-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Migration 0018 — Phase 5.1: Feld-Audit-Trigger (patients/ccps → audit_log)
--                             + 'normal'-Entsperrung Issue-/Role-Change-Whitelists
-- ============================================================================
-- Zweck:
--
--   (1) Zwei security-definer AFTER-Trigger-Funktionen, die serverseitig
--       alle D-06-Lebenszyklus-Aktionen auf patients und ccps in audit_log
--       schreiben. argus_usbnk() liest den USBNK aus dem signierten JWT —
--       Client kann den Wert nicht fälschen (STRIDE T-051-01/T-051-02).
--       Trigger schreiben auch bei usbnk=null (Stufe-0-Sessions, §73
--       Vollständigkeit). audit_log bleibt append-only (kein neuer anon-DML-
--       Grant, kein before-Trigger, keine update/delete-Policy).
--
--   (2) argus_master_issue_person + argus_master_role_change_person werden
--       byte-nah zur 0017-Fassung neu erstellt; ausschließlich die Whitelist-
--       Zeile ändert sich: 'normal' wird wieder aufgenommen (5.1-Freigabe).
--       0017 hatte 'normal' für Phase 5 gesperrt; mit Phase 5.1 kann der
--       Master Normalnutzer-Tokens für die Einzel-Ausgabe über die Leitungs-
--       Seite ausgeben. argus_exchange_code und argus_exchange_person_code
--       bleiben unverändert (CR-02 intakt).
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000_base_schema.sql → 0001_phase4_jwt_rls.sql →
--   0002_phase48_datenschutz.sql → 0003_phase49_einsatzprotokoll.sql →
--   0004_phase410_log_retention.sql → 0005_phase412_lageansicht.sql →
--   0006_token_hygiene.sql → 0007_jti_sofortsperre.sql →
--   0008_nummernvergabe.sql → 0009_paket2_gastcode_schulung.sql →
--   0010_lage_ort.sql → 0011_paket3_schulung.sql →
--   0012_kurs_evaluation.sql → 0013_phase414_admin_rolle.sql →
--   0014_phase414_admin_exchange_hardening.sql →
--   0015_phase5_identitaeten.sql → 0016_phase5_t4_audit.sql →
--   0017_phase5_review_fixes.sql → dieses Skript (0018).
--
-- Anwendung: Supabase Management API
--   POST https://api.supabase.com/v1/projects/{ref}/database/query
--   Authorization: Bearer <ephemerer PAT>
--   Body: {"query": "<gesamter Inhalt dieser Datei>"}
-- Kein CLI (kein Supabase CLI in dieser Umgebung).
-- Idempotenz: create or replace function; drop trigger if exists + create trigger.
-- ============================================================================

-- ── 1) argus_audit_patients() — AFTER-Trigger-Funktion für public.patients ──
-- Leitet den action-Typ aus TG_OP + NEW/OLD-Spaltendiff ab.
-- Priorität: photo > checkout > ready > cat_change (genau 1 Eintrag pro Aufruf).
-- Reine Vitalwert-/Feld-Änderungen: KEIN Eintrag (D-06: keine Einzelfeld-Diffs).
-- praesidium_id fehlt in patients → wird über die ccps-Row aufgelöst.
-- Loggt auch bei usbnk=null (Stufe-0-Session, §73-Vollständigkeit).
-- security definer + set search_path: Trigger läuft im privilegierten Kontext
-- des Funktionsbesitzers, nicht als anon (Pitfall 2; STRIDE T-051-03).
create or replace function public.argus_audit_patients()
  returns trigger
  language plpgsql
  security definer
  set search_path to 'public'
as $$
declare
  v_action      text;
  v_praesidium  uuid;
begin
  -- action aus TG_OP + Spaltendiff ableiten (Priorität: photo > checkout > ready > cat_change).
  if TG_OP = 'INSERT' then
    v_action := 'patient_create';
  elsif TG_OP = 'UPDATE' then
    if NEW.photo is not null and OLD.photo is null then
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
      null
    );

  return NEW;
end;
$$;

-- ── 2) argus_audit_ccps() — AFTER-Trigger-Funktion für public.ccps ───────────
-- Leitet den action-Typ aus TG_OP + NEW/OLD-Spaltendiff ab.
-- Priorität: ccp_close > ccp_merge (genau 1 Eintrag pro Aufruf).
-- Sonstige Updates: KEIN Eintrag.
-- praesidium_id liegt direkt in der ccps-Row (NEW.praesidium_id).
-- security definer + set search_path analog argus_audit_patients (Pitfall 2).
create or replace function public.argus_audit_ccps()
  returns trigger
  language plpgsql
  security definer
  set search_path to 'public'
as $$
declare
  v_action text;
begin
  -- action aus TG_OP + Spaltendiff ableiten (Priorität: ccp_close > ccp_merge).
  if TG_OP = 'INSERT' then
    v_action := 'ccp_open';
  elsif TG_OP = 'UPDATE' then
    if NEW.closed_at is not null and OLD.closed_at is null then
      v_action := 'ccp_close';
    elsif NEW.merge_group_id is not null
          and (OLD.merge_group_id is null or OLD.merge_group_id <> NEW.merge_group_id) then
      v_action := 'ccp_merge';
    else
      -- Sonstiges Update → kein Eintrag.
      return NEW;
    end if;
  else
    return NEW;
  end if;

  -- audit_log-Eintrag schreiben (auch bei usbnk=null, §73-Vollständigkeit).
  insert into public.audit_log (at, usbnk, action, ccp_id, patient_id, praesidium_id, detail)
    values (
      (extract(epoch from now()) * 1000)::bigint,
      public.argus_usbnk(),
      v_action,
      NEW.id,
      null,
      NEW.praesidium_id,
      null
    );

  return NEW;
end;
$$;

-- ── 3) Trigger idempotent anlegen ────────────────────────────────────────────
-- drop trigger if exists verhindert Fehler bei erneutem Anwenden (Idempotenz).
-- AFTER INSERT OR UPDATE: Trigger feuert nach dem DML (kein before-Trigger).
-- FOR EACH ROW: separater Aufruf pro modifizierter Zeile.
-- KEIN neuer Grant an anon für audit_log — append-only bleibt erhalten (D-07).
-- Die Trigger-Funktionen schreiben security-definer → anon-Grant nicht nötig.

drop trigger if exists argus_audit_patients_aiu on public.patients;
create trigger argus_audit_patients_aiu
  after insert or update
  on public.patients
  for each row
  execute function public.argus_audit_patients();

drop trigger if exists argus_audit_ccps_aiu on public.ccps;
create trigger argus_audit_ccps_aiu
  after insert or update
  on public.ccps
  for each row
  execute function public.argus_audit_ccps();

-- ── 4) argus_master_role_change_person — 'normal' wieder in der Whitelist ────
-- 5.1-Freigabe: 'normal' wieder in der Whitelist (0017 hatte es für Phase 5 gesperrt).
-- BYTE-NAH zur 0017-Fassung; NUR die Whitelist-Zeile + Fehlertext geändert:
--   vorher: p_new_role not in ('master', 'flz', 'admin')
--   jetzt:  p_new_role not in ('master', 'flz', 'admin', 'normal')
-- Fehlermeldung vereinfacht zu "Ungültige Rolle" (kein Phasenverweis mehr).
-- Alles andere (Guard argus_is_master, Normalisierung, Zieltoken-Load,
-- is_person-Check, Admin-Präsidiums-Check, atomarer Update, Zwangs-Log,
-- Rückgabe) ist byte-nah identisch zu 0017.
create or replace function public.argus_master_role_change_person(
  p_short_code text,
  p_new_role   text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_norm text;
  v_t    record;
begin
  -- Guard: Nur Master-JWT darf Rollen ändern (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- 5.1-Freigabe: 'normal' wieder in der Whitelist (0017 hatte es für Phase 5 gesperrt).
  if p_new_role not in ('master', 'flz', 'admin', 'normal') then
    raise exception 'Ungültige Rolle';
  end if;

  -- Normalisierung identisch allen Exchange-Funktionen.
  v_norm := upper(regexp_replace(p_short_code, '[\s\-]', '', 'g'));
  if length(v_norm) >= 8 then
    v_norm := substring(v_norm, 1, 4) || '-' || substring(v_norm, 5, 4);
  end if;

  -- Zieltoken laden.
  select is_person, usbnk, role, praesidium_id
  into v_t
  from public.access_tokens
  where short_code = v_norm;

  if not found then
    raise exception 'Code nicht gefunden';
  end if;

  -- Nur Pro-Person-Tokens erlaubt.
  if not coalesce(v_t.is_person, false) then
    raise exception 'Nur Pro-Person-Tokens';
  end if;

  -- Admin-Rolle erfordert Präsidiumszuordnung (Konsistenz mit issue).
  if p_new_role = 'admin' and v_t.praesidium_id is null then
    raise exception 'Admin-Rolle erfordert Präsidium';
  end if;

  -- Atomarer In-Place-Update (kein Sperren, kein neuer Short-Code, kein Lockout).
  -- Die neue Rolle gilt ab dem nächsten Exchange/Login des Nutzers.
  update public.access_tokens
  set role = p_new_role
  where short_code = v_norm;

  -- Zwangs-Log: person_role_change mit actor-USBNK + Ziel-USBNK im detail (D-13).
  insert into public.audit_log (at, usbnk, action, praesidium_id, detail)
    values (
      (extract(epoch from now()) * 1000)::bigint,
      public.argus_usbnk(),
      'person_role_change',
      v_t.praesidium_id,
      'target=' || coalesce(v_t.usbnk, '') || ' old=' || coalesce(v_t.role, '') || ' new=' || p_new_role
    );

  return jsonb_build_object(
    'ok',         true,
    'short_code', v_norm,
    'new_role',   p_new_role
  );
end;
$function$;
grant execute on function public.argus_master_role_change_person(text, text) to anon;

-- ── 5) argus_master_issue_person — 'normal' wieder in der Whitelist ──────────
-- 5.1-Freigabe: 'normal' wieder in der Whitelist (0017 hatte es für Phase 5 gesperrt).
-- BYTE-NAH zur 0017-Fassung; NUR die Whitelist-Zeile + Fehlertext geändert:
--   vorher: p_role not in ('master', 'flz', 'admin')
--   jetzt:  p_role not in ('master', 'flz', 'admin', 'normal')
-- Fehlermeldung vereinfacht zu "Ungültige Rolle" (kein Phasenverweis mehr).
-- WICHTIG (D5.1-01): bei role='normal' wird praesidium_id aus p_praesidium_id
-- gesetzt — gewollt (Feld-Erfassung via RLS braucht praesidium_id im Token).
-- KEINE Eskalation: alle Boolean-Flags (is_master/is_admin/observer/gast) bleiben
-- explizit false; der Person-Exchange leitet Claims aus role ab →
-- role='normal' setzt is_master/is_flz/is_admin alle false (STRIDE T-051-04).
-- Alles andere (Guard argus_is_master, USBNK-Validierung, Admin-Präsidiums-Pflicht,
-- Short-Code-Kollisionsschleife, INSERT, Zwangs-Log, Rückgabe) ist byte-nah
-- identisch zu 0017.
create or replace function public.argus_master_issue_person(
  p_usbnk        text,
  p_role         text,
  p_praesidium_id uuid,
  p_label        text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions'
as $function$
declare
  -- Verwechslungssicheres Alphabet ohne 0/O/1/I (identisch 0013)
  v_alphabet    text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_short_code  text;
  v_token       text;
  v_now_ms      bigint;
  v_part1       text;
  v_part2       text;
  v_attempt     int := 0;
  v_exists      boolean;
  v_actor_usbnk text;
begin
  -- Guard: Nur Master-JWT darf Person-Tokens ausgeben (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- Eingabe-Validierung.
  if p_usbnk is null or btrim(p_usbnk) = '' then
    raise exception 'USBNK erforderlich';
  end if;
  -- 5.1-Freigabe: 'normal' wieder in der Whitelist (0017 hatte es für Phase 5 gesperrt).
  if p_role not in ('master', 'flz', 'admin', 'normal') then
    raise exception 'Ungültige Rolle';
  end if;
  -- Admin-Tokens müssen präsidiumsgebunden sein.
  if p_role = 'admin' and p_praesidium_id is null then
    raise exception 'Admin-Token erfordert Präsidium';
  end if;

  v_actor_usbnk := public.argus_usbnk();   -- USBNK des ausstellenden Masters
  v_now_ms      := (extract(epoch from now())*1000)::bigint;
  v_token       := encode(extensions.gen_random_bytes(16), 'hex');

  -- Short-Code: Kollisions-Schleife, identisch argus_admin_issue_gast (0013).
  loop
    v_attempt := v_attempt + 1;
    if v_attempt > 10 then
      raise exception 'Short-Code-Kollision — bitte erneut versuchen';
    end if;
    v_part1 := '';
    v_part2 := '';
    for i in 1..4 loop
      v_part1 := v_part1 || substr(v_alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    for i in 1..4 loop
      v_part2 := v_part2 || substr(v_alphabet,
        1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    v_short_code := v_part1 || '-' || v_part2;
    select exists(
      select 1 from public.access_tokens where short_code = v_short_code
    ) into v_exists;
    exit when not v_exists;
  end loop;

  -- INSERT: alle Boolean-Flags explizit false (Anti-Pattern-Schutz).
  -- KEIN expires_at (D-11: kein zeitliches Ablaufen für Person-Tokens).
  -- role='normal': praesidium_id wird aus p_praesidium_id gesetzt (D5.1-01,
  -- Feld-Erfassung via RLS). Alle Privilegien-Flags bleiben false.
  insert into public.access_tokens (
    token, short_code, praesidium_id,
    is_person, usbnk, role,
    is_master, is_admin, observer, gast, single_use, temporary,
    ttl_hours, label
  ) values (
    v_token, v_short_code, p_praesidium_id,
    true, btrim(p_usbnk), p_role,
    false, false, false, false, false, false,
    null, btrim(coalesce(p_label, ''))
  );

  -- Zwangs-Log: person_issue mit actor-USBNK (D-13, STRIDE T-05-08).
  -- role='master'-Ausgaben werden explizit im detail-Feld protokolliert (D-13).
  insert into public.audit_log (at, usbnk, action, praesidium_id, detail)
    values (v_now_ms, v_actor_usbnk, 'person_issue', p_praesidium_id,
            'role=' || p_role || ' target=' || btrim(p_usbnk));

  return jsonb_build_object('short_code', v_short_code);
end;
$function$;
grant execute on function public.argus_master_issue_person(text, text, uuid, text) to anon;
