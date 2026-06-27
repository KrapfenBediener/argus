-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Migration 0020 — Phase 5.1 Code-Review-Fixes
--                  (CR-02, WR-01, IN-02 aus 05.1-REVIEW.md)
-- ============================================================================
-- Adressierte Befunde:
--
--   CR-02: argus_exchange_person_code — p_scope-Whitelist.
--     Bisher wurde jeder Nicht-'schulung'-Wert still als 'echt' behandelt;
--     ein direkt-API-Aufruf mit p_scope='admin' oder Tippfehler erzeugte ein
--     JWT ohne Abweisung. Fix: Whitelist-Guard am Funktionsanfang (nach Code-
--     Normalisierung), der alle Werte außer 'echt' und 'schulung' mit einem
--     Fehler-JSON abbricht.
--     BYTE-NAH zur 0019-Fassung; ausschließlich der Whitelist-Block ist neu.
--
--   WR-01: argus_master_role_change_person — 'normal'-Rolle erfordert Präsidium.
--     Die Funktion prüfte bisher nur für p_new_role='admin', ob das Zieltoken
--     ein praesidium_id hat. Ein Master konnte ein flz/master-Token
--     (praesidium_id=null) auf 'normal' setzen; beim nächsten Exchange bekam
--     der Nutzer "Person-Code ohne Präsidium". Fix: denselben Präsidiums-
--     Guard auch für 'normal' hinzufügen (Konsistenz mit argus_master_issue_person).
--     BYTE-NAH zur 0018-Fassung; ausschließlich der neue Guard ist neu.
--
--   IN-02: argus_audit_patients — Foto-Ersatz wird ebenfalls geloggt.
--     Bisher feuerte 'patient_photo' nur beim ersten Setzen (OLD.photo IS NULL).
--     Foto-Ersatz (OLD.photo IS NOT NULL AND NEW.photo <> OLD.photo) erzeugte
--     keinen Audit-Eintrag. Fix: Bedingung auf OR-Zweig erweitern.
--     BYTE-NAH zur 0018-Fassung; ausschließlich die photo-Bedingung ist neu.
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
--   0019_phase51_twin_scope.sql → dieses Skript (0020).
--
-- Anwendung: Supabase Management API
--   POST https://api.supabase.com/v1/projects/{ref}/database/query
--   Authorization: Bearer <ephemerer PAT>
--   Body: {"query": "<gesamter Inhalt dieser Datei>"}
-- Kein CLI (kein Supabase CLI in dieser Umgebung).
-- Idempotenz: create or replace function + grant execute.
--   argus_exchange_person_code: drop if exists (alte 1-Arg-Signatur) wurde
--   bereits in 0019 erledigt; hier nur create or replace der 2-Arg-Version.
-- ============================================================================

-- ── 1) CR-02: argus_exchange_person_code — p_scope-Whitelist ─────────────────
-- BYTE-NAH zur 0019-Fassung. Einzige Änderung:
--   Nach der Code-Normalisierung + Guards (not found, revoked, not is_person,
--   expires_at) wird p_scope gegen die Whitelist ('echt', 'schulung') geprüft.
--   Alle anderen Werte → sofortiges return mit 'error'. Der validierte Scope
--   wird in der Rückgabe nicht blind zurückgespiegelt, sondern nach der
--   Twin-Auflösung aus v_eff_praesidium abgeleitet (scope-Feld bleibt wie in
--   0019: coalesce(p_scope,'echt') — aber da p_scope nun immer 'echt' oder
--   'schulung' ist, ist der Wert trustworthy).
-- Alle anderen Teile (Normalisierung, JWT-Claims, Audit-Log, Rückgabe) sind
-- byte-nah identisch zu 0019.
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

  -- CR-02 (0020): Scope-Whitelist — nur 'echt' und 'schulung' sind gültig.
  -- Jeder andere Wert (Tippfehler, direkter API-Aufruf mit beliebigem String)
  -- wird sofort abgewiesen; kein stilles Fall-through zu 'echt'.
  if p_scope not in ('echt', 'schulung') then
    return jsonb_build_object('error', 'Ungültiger Scope — erlaubt: echt, schulung');
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

-- ── 2) WR-01: argus_master_role_change_person — 'normal' erfordert Präsidium ──
-- BYTE-NAH zur 0018-Fassung. Einzige Änderung:
--   Nach dem Admin-Präsidiums-Guard wird ein symmetrischer Guard für 'normal'
--   hinzugefügt: wenn das Zieltoken praesidium_id=null hat (z. B. ex-flz/master),
--   darf die Rolle nicht auf 'normal' geändert werden — ein normales Token ohne
--   Präsidium kann nicht angemeldet werden (argus_exchange_person_code gibt
--   "Person-Code ohne Präsidium" zurück, Feld-App weist es ab).
--   Konsistenz mit argus_master_issue_person, das für 'normal' ebenfalls
--   praesidium_id erfordert (0018, Zeile 307-309).
-- Alle anderen Teile (argus_is_master-Guard, Whitelist, Normalisierung,
-- Token-Load, is_person-Check, UPDATE, Audit-Log, Rückgabe) sind byte-nah
-- identisch zu 0018.
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

  -- 5.1-Freigabe: 'normal' in der Whitelist (identisch 0018).
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

  -- WR-01 (0020): 'normal'-Rolle erfordert ebenfalls Präsidiumszuordnung.
  -- Ein Token ohne praesidium_id kann nach einem Role-Change auf 'normal' nicht
  -- angemeldet werden — argus_exchange_person_code weist es mit "Person-Code ohne
  -- Präsidium" ab. Frühzeitige Ablehnung hier schützt vor konfusem Nutzererlebnis.
  if p_new_role = 'normal' and v_t.praesidium_id is null then
    raise exception 'Normal-Rolle erfordert Präsidium — bitte Token neu ausgeben';
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

-- ── 3) IN-02: argus_audit_patients — Foto-Ersatz ebenfalls loggen ─────────────
-- BYTE-NAH zur 0018-Fassung. Einzige Änderung:
--   Die photo-Bedingung wird von
--     NEW.photo is not null and OLD.photo is null
--   erweitert auf
--     NEW.photo is not null and (OLD.photo is null or NEW.photo <> OLD.photo)
--   Damit wird 'patient_photo' auch ausgelöst, wenn ein Foto ERSETZT wird
--   (OLD.photo IS NOT NULL AND NEW.photo <> OLD.photo — Operator nimmt neues Foto).
--   Foto-Löschung (NEW.photo is null) erzeugt weiterhin keinen Eintrag (by design:
--   DSB-Freigabe, Fotos dauerhaft aktiv; Löschung ist ein Fehlerfall, kein Workflow).
--   Die Prioritäts-Kette (photo > checkout > ready > cat_change) bleibt unverändert.
--   Genau 1 Eintrag pro Trigger-Aufruf (kein double-log).
-- Alle anderen Teile (TG_OP-Zweige, ccps-Join, INSERT, RETURN NEW) sind byte-nah
-- identisch zu 0018.
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
    -- IN-02 (0020): Foto-Erst-Upload UND Foto-Ersatz lösen 'patient_photo' aus.
    if NEW.photo is not null and (OLD.photo is null or NEW.photo <> OLD.photo) then
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
grant execute on function public.argus_audit_patients() to anon;
