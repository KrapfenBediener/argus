-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Migration 0019 — Phase 5.1: Twin-Scope Re-Exchange
--                             argus_exchange_person_code bekommt p_scope-Parameter
-- ============================================================================
-- Zweck:
--
--   Ein 'normal'-Person-Token trägt im JWT genau EINE praesidium_id. In Phase 5.1
--   hat die Feld-App einen Echt/Schulung-Zwei-Reiter-Picker, aber das Initial-JWT
--   enthält nur das Echt-Präsidium. RLS prüft ausschließlich auf praesidium_id im
--   JWT → schulungs_zwilling_id-CCPs sind für das Echt-JWT unsichtbar (0 CCPs).
--
--   Lösung: Re-Exchange bei bewusstem Moduswechsel (Echt ↔ Schulung).
--   Der Client sendet denselben Code + p_scope='schulung' (oder 'echt').
--   Die Funktion löst den Twin SERVER-SEITIG aus dem Token-Präsidium auf —
--   der Client kann kein beliebiges Präsidium übergeben (keine Eskalation).
--   Das neue JWT enthält praesidium_id = schulungs_zwilling_id.
--   RLS sieht jetzt das Schulungs-Präsidium → CCPs korrekt sichtbar.
--
--   Backward-Kompatibilität:
--   - Alle bestehenden Aufrufer (kein p_scope-Argument) erhalten p_scope='echt'
--     per DEFAULT → Verhalten byte-gleich zu 0015.
--   - Die alte 1-Arg-Signatur (argus_exchange_person_code(text)) wird vorher
--     per DROP gedroppt (PostgreSQL-Überladung würde sonst daneben stehen).
--   - argus_exchange_code, RLS-Policies, alle anderen Funktionen: UNVERÄNDERT.
--
-- Neue Signatur:
--   argus_exchange_person_code(code text, p_scope text default 'echt')
--     → liefert zusätzlich das Feld `scope` ('echt'|'schulung') im JSON.
--     → praesidium_id im JWT = effektives Präsidium (Echt oder Schulungs-Twin).
--     → audit_log.praesidium_id = effektives Präsidium (nicht immer v_token.praesidium_id).
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
--   0017_phase5_review_fixes.sql → 0018_phase51_feld_audit_normal.sql →
--   dieses Skript (0019).
--
-- Anwendung: Supabase Management API
--   POST https://api.supabase.com/v1/projects/{ref}/database/query
--   Authorization: Bearer <ephemerer PAT>
--   Body: {"query": "<gesamter Inhalt dieser Datei>"}
-- Kein CLI (kein Supabase CLI in dieser Umgebung).
-- Idempotenz: drop function if exists (alte 1-Arg-Signatur) + create or replace
--             (2-Arg-Signatur) + grant execute.
-- ============================================================================

-- ── 1) Alte 1-Arg-Signatur droppen (PostgreSQL-Überladungskollision vermeiden) ─
-- Die 2-Arg-Version mit p_scope default 'echt' ersetzt sie vollständig.
-- drop if exists: idempotent, kein Fehler wenn bereits gedroppt.
-- Alle Aufrufer ohne p_scope werden automatisch auf den 2-Arg-Default umgeleitet.
drop function if exists public.argus_exchange_person_code(text);

-- ── 2) argus_exchange_person_code(code, p_scope) — Twin-Scope-Version ────────
-- BYTE-NAH zur 0015-Fassung. Erweiterungen gegenüber 0015:
--   (a) Parameter p_scope text default 'echt' — Backward-Kompatibilität: kein
--       bestehender Aufrufer muss geändert werden.
--   (b) v_eff_praesidium: effektives Präsidium (Echt oder Twin). Für 'schulung'
--       wird schulungs_zwilling_id SERVER-SEITIG aus der praesidien-Tabelle
--       aufgelöst — der Client kann kein beliebiges Präsidium injecten.
--   (c) JWT praesidium_id = v_eff_praesidium (statt immer v_token.praesidium_id).
--   (d) audit_log.praesidium_id = v_eff_praesidium (effektiver Scope geloggt).
--   (e) Rückgabe: zusätzliches Feld 'scope' ('echt'|'schulung').
--   (f) Präsidiumsname (v_pname) wird für v_eff_praesidium aufgelöst.
-- Unverändertes Verhalten aus 0015:
--   - Normalisierung (upper + regexp_replace, short_code-Split, length<8-Guard).
--   - Guards: not found, revoked, not is_person, expires_at.
--   - TTL 30 Tage (technisches Bearer-exp, D-11).
--   - JWT-Payload: usbnk, argus_role, is_master/is_flz/is_admin, jti, iat, exp.
--   - FLZ/Master-Zweig: praesidium_id=null (präsidienübergreifend, D-12);
--     p_scope hat dort keine Wirkung (null bleibt null).
--   - sub='argus-person', role='anon', iss='supabase'.
--   - security definer + set search_path zu 'public','extensions','vault'.
--   - KEIN Klarname (D-02); KEIN expires_at-Ablaufen (D-11).
create or replace function public.argus_exchange_person_code(
  code    text,
  p_scope text default 'echt'
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions', 'vault'
as $function$
declare
  v_clean           text;
  v_short_code      text;
  v_token           record;
  v_now             int;
  v_exp             int;
  v_ttl_secs        int;
  v_jwt             text;
  v_jwt_secret      text;
  v_pname           text;
  v_eff_praesidium  uuid;   -- effektives Präsidium (Echt oder Schulungs-Twin)
  v_twin            uuid;   -- schulungs_zwilling_id (nur für p_scope='schulung')
begin
  -- Normalisierung identisch allen anderen Exchanges.
  v_clean := upper(regexp_replace(code, '[\s\-]', '', 'g'));
  if length(v_clean) < 8 then
    return jsonb_build_object('error', 'Code zu kurz');
  end if;
  v_short_code := substring(v_clean,1,4) || '-' || substring(v_clean,5,4);

  select praesidium_id, is_person, usbnk, role, revoked, expires_at
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  -- CR-02-Spiegel: weist alle Nicht-Person-Codes ab (D-05/STRIDE T-05-02).
  if not coalesce(v_token.is_person, false) then
    return jsonb_build_object('error', 'Kein Pro-Person-Code');
  end if;
  -- Defensiv: Person-Tokens setzen normalerweise kein expires_at (D-11).
  if v_token.expires_at is not null
     and v_token.expires_at <= (extract(epoch from now())*1000)::bigint then
    return jsonb_build_object('error', 'Code abgelaufen');
  end if;

  -- ── Twin-Auflösung (SERVER-SEITIG, keine Client-Injection möglich) ──────────
  -- FLZ/Master: praesidium_id=null → p_scope hat keine Wirkung (kein Twin).
  -- normal/admin: v_eff_praesidium = Echt-Präsidium oder Schulungs-Twin.
  v_eff_praesidium := v_token.praesidium_id;
  if p_scope = 'schulung' and v_token.praesidium_id is not null then
    -- Twin über praesidien.schulungs_zwilling_id auflösen.
    select schulungs_zwilling_id
      into v_twin
      from public.praesidien
     where id = v_token.praesidium_id;
    if v_twin is null then
      return jsonb_build_object('error', 'Kein Schulungs-Zwilling für dieses Präsidium');
    end if;
    v_eff_praesidium := v_twin;
  end if;

  v_now      := extract(epoch from now())::int;
  v_ttl_secs := 30*24*3600;   -- technisches Bearer-exp 30 Tage (D-11)
  v_exp      := v_now + v_ttl_secs;

  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret'
  limit 1;

  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  -- JWT-Payload: rollen-abgeleitete Claims analog 0015-Muster.
  -- ERWEITERUNG: praesidium_id und admin_praesidium_id nutzen v_eff_praesidium
  -- (statt immer v_token.praesidium_id). FLZ/Master: null bleibt null.
  -- sub='argus-person' (eigene Kennung, nicht 'argus-device').
  -- KEIN Klarname-Claim (D-02).
  v_jwt := extensions.sign(
    json_build_object(
      'iss',                'supabase',
      'sub',                'argus-person',
      'role',               'anon',
      'usbnk',              v_token.usbnk,
      'argus_role',         v_token.role,
      'is_master',          (v_token.role = 'master'),
      'is_flz',             (v_token.role = 'flz'),
      'is_admin',           (v_token.role = 'admin'),
      'praesidium_id',      case when v_token.role in ('master', 'flz')
                                 then null
                                 else v_eff_praesidium end,
      'admin_praesidium_id', case when v_token.role = 'admin'
                                  then v_eff_praesidium
                                  else null end,
      'jti',                v_short_code,
      'iat',                v_now,
      'exp',                v_exp
    ),
    v_jwt_secret
  );

  -- Zwangs-Log VOR Rückgabe (D-13, STRIDE T-05-08): person_login mit USBNK.
  -- ERWEITERUNG: praesidium_id = v_eff_praesidium (effektiver Scope, nicht immer Echt).
  insert into public.audit_log (at, usbnk, action, praesidium_id)
    values ((extract(epoch from now())*1000)::bigint,
            v_token.usbnk, 'person_login', v_eff_praesidium);

  -- Präsidiumsname des effektiven Präsidiums auflösen.
  if v_eff_praesidium is not null then
    select name into v_pname from public.praesidien
    where id = v_eff_praesidium;
  end if;

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'usbnk',           v_token.usbnk,
    'argus_role',      v_token.role,
    'praesidium_id',   v_eff_praesidium,
    'praesidium_name', v_pname,
    'scope',           coalesce(p_scope, 'echt'),
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;
grant execute on function public.argus_exchange_person_code(text, text) to anon;
