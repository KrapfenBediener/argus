-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Migration 0017 — Phase 5 Code-Review-Fixes: atomic Rollenwechsel, ILIKE-
--                 Escape, Revoke-Normalisierung + Idempotenz
-- ============================================================================
-- Adressierte Befunde aus 05-REVIEW.md:
--
--   CR-01 + WR-03: Nicht-atomarer Rollenwechsel in der Leitungs-Seite.
--     Neuer RPC argus_master_role_change_person — atomarer In-Place-Update des
--     role-Felds im selben Token (kein Sperren + Neuausgabe). Der Short-Code
--     bleibt gültig; die neue Rolle gilt ab dem nächsten Exchange/Login.
--     Außerdem: 'normal' aus argus_master_issue_person-Whitelist entfernt
--     (Konsistenz; 'normal' kommt erst mit Phase 5.1).
--
--   WR-01: argus_master_search_usbnk — ILIKE-Wildcards (% und _) in p_usbnk
--     werden jetzt escaped. Suche bleibt Fragment-Suche, verhindert aber
--     unbeabsichtigte Volltreffer-Abfragen via direktem API-Aufruf.
--
--   WR-02 + IN-01: argus_master_revoke_person — normalisiert p_short_code
--     jetzt wie alle anderen Exchange-Funktionen (upper + strip + XXXX-XXXX).
--     Idempotent: bereits gesperrte Tokens geben sofort zurück, ohne
--     duplizierten Audit-Log-Eintrag zu erzeugen.
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
--   dieses Skript (0017).
--
-- Anwendung: Supabase Management API (POST /v1/projects/{ref}/database/query),
--            ephemerer PAT. KEIN CLI.
-- Idempotenz: reine create-or-replace — mehrfaches Anwenden ist unschädlich.
-- ============================================================================

-- ── 1) CR-01 + WR-03: argus_master_role_change_person (neuer atomarer RPC) ──
-- Ersetzt den zweiteiligen revoke+issue-Pfad in der Leitungs-Seite vollständig.
-- In-Place-Update des role-Felds: derselbe Short-Code bleibt gültig;
-- das nächste argus_exchange_person_code gibt ein JWT mit der neuen Rolle aus.
-- Wenn sofortige Abmeldung nötig ist, nutzt der Master "Sperren" separat.
-- 'normal' ist absichtlich ausgeschlossen (D-03/D-10: erst Phase 5.1).
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

  -- Whitelist: 'normal' explizit ausgeschlossen bis Phase 5.1.
  if p_new_role not in ('master', 'flz', 'admin') then
    raise exception 'Ungültige oder noch nicht verfügbare Rolle (normal erst ab Phase 5.1)';
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

-- ── 2) WR-03: argus_master_issue_person — 'normal' aus Whitelist entfernt ────
-- BYTE-NAH zur 0015-Fassung; NUR die Whitelist-Zeile geändert:
--   vorher: ('master', 'flz', 'admin', 'normal')
--   jetzt:  ('master', 'flz', 'admin')
-- Fehlermeldung erwähnt, dass 'normal' erst ab Phase 5.1 kommt.
-- Alles andere ist identisch zu 0015.
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
  if p_role not in ('master', 'flz', 'admin') then
    raise exception 'Ungültige Rolle (normal erst ab Phase 5.1)';
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

-- ── 3) WR-01: argus_master_search_usbnk — ILIKE-Wildcards escapen ────────────
-- BYTE-NAH zur 0015-Fassung; NUR das Such-Prädikat geändert:
--   vorher: a.usbnk ilike '%' || p_usbnk || '%'
--   jetzt:  ILIKE mit escape '\' nach Escape der Sonderzeichen \, %, _
-- Alles andere (Guard, SELECT-Liste, Rückgabe) ist identisch zu 0015.
create or replace function public.argus_master_search_usbnk(p_usbnk text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_result  jsonb;
  v_pattern text;
begin
  -- Guard: Nur Master-JWT darf USBNK-Suche durchführen (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- ILIKE-Wildcards escapen: zuerst Backslash, dann %, dann _.
  -- escape '\' teilt PostgreSQL mit, dass '\' der Escape-Zeichensatz ist.
  v_pattern := '%'
    || replace(replace(replace(p_usbnk, '\', '\\'), '%', '\%'), '_', '\_')
    || '%';

  -- SELECT: kurze, sichere Spalten-Liste; NIEMALS die token-Secret-Spalte.
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'short_code',      a.short_code,
        'usbnk',           a.usbnk,
        'role',            a.role,
        'revoked',         coalesce(a.revoked, false),
        'praesidium_id',   a.praesidium_id,
        'praesidium_name', (select p.name from public.praesidien p where p.id = a.praesidium_id),
        'created_at',      a.created_at,
        'label',           a.label
      )
      order by a.usbnk
    ),
    '[]'::jsonb
  )
  into v_result
  from public.access_tokens a
  where a.is_person = true
    and a.usbnk ilike v_pattern escape '\';

  return v_result;
end;
$function$;
grant execute on function public.argus_master_search_usbnk(text) to anon;

-- ── 4) WR-02 + IN-01: argus_master_revoke_person — Normalisierung + Idempotenz ─
-- BYTE-NAH zur 0015-Fassung; zwei Änderungen:
--   (a) p_short_code wird wie alle Exchange-Funktionen normalisiert
--       (upper + strip + XXXX-XXXX).
--   (b) Idempotenzprüfung: bereits gesperrte Tokens geben sofort zurück
--       ohne zweiten UPDATE und ohne duplizierten Audit-Log-Eintrag.
-- Alles andere (Guard, is_person-Check, Update, Log) ist identisch zu 0015.
create or replace function public.argus_master_revoke_person(p_short_code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_norm   text;
  v_target record;
begin
  -- Guard: Nur Master-JWT darf Person-Tokens sperren (STRIDE T-05-03).
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- Normalisierung identisch allen Exchange-Funktionen (WR-02).
  v_norm := upper(regexp_replace(p_short_code, '[\s\-]', '', 'g'));
  if length(v_norm) >= 8 then
    v_norm := substring(v_norm, 1, 4) || '-' || substring(v_norm, 5, 4);
  end if;

  -- Zielcode laden.
  select is_person, usbnk, revoked, praesidium_id
  into v_target
  from public.access_tokens
  where short_code = v_norm;

  if not found then
    raise exception 'Code nicht gefunden';
  end if;

  -- Nur Pro-Person-Tokens widerrufbar (STRIDE T-05-03).
  if not coalesce(v_target.is_person, false) then
    raise exception 'Nur Pro-Person-Tokens widerrufbar';
  end if;

  -- Idempotenzprüfung: kein doppelter UPDATE + kein duplizierter Audit-Eintrag (IN-01).
  if coalesce(v_target.revoked, false) then
    return jsonb_build_object('revoked', true, 'already', true);
  end if;

  -- Sperren: revoked=true → argus_token_active() liefert false → jti-Sofortsperre.
  update public.access_tokens
  set revoked = true
  where short_code = v_norm;

  -- Zwangs-Log: person_revoke mit actor-USBNK + Ziel-USBNK im detail (D-13).
  insert into public.audit_log (at, usbnk, action, praesidium_id, detail)
    values ((extract(epoch from now())*1000)::bigint,
            public.argus_usbnk(), 'person_revoke', v_target.praesidium_id,
            'target=' || coalesce(v_target.usbnk, ''));

  return jsonb_build_object('revoked', true);
end;
$function$;
grant execute on function public.argus_master_revoke_person(text) to anon;
