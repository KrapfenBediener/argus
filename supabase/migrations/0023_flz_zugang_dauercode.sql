-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0023 — Rollen zusammengelegt: „FLZ-Zugang" = bisherige Admin-Rolle
-- ══════════════════════════════════════════════════════════════════════════
-- Owner-Entscheid 2026-10-14 (DSB-abgestimmt): Relevante Token-Arten sind nur
-- noch Dauerhaft · Einmal · FLZ-Zugang. Gast-Code und Beobachter-Code werden in
-- der Leitung nicht mehr angelegt (bestehende bleiben gültig und sperrbar).
--
-- Der FLZ-Zugang (technisch weiterhin access_tokens.is_admin = true, kein
-- Schema-Wechsel) darf:
--   * die Lage des eigenen Präsidiums sehen (FLZ-Seite UND Leitung — der
--     Admin-Zweig in argus_lage aus 0013 bleibt unverändert),
--   * DAUERCODES fürs eigene Präsidium ausgeben (ohne Ablauf; nutzbar auch
--     von präsidiumsfremden Kräften, da ein Dauercode ein normaler Geräte-Code
--     des Präsidiums ist),
--   * Geräte-Codes des eigenen Präsidiums sperren.
-- Weiterhin KEIN Patientendaten-Zugriff (Sicherheitsgrenze aus 0013/0014 bleibt:
-- kein praesidium_id-Claim, kein is_master; RLS auf patients/ccps/checklists
-- unverändert).
--
-- Additiv: zwei neue security-definer-RPCs nach dem Muster von
-- argus_admin_issue_gast / argus_admin_revoke_gast (0013). Die alten RPCs
-- bleiben bestehen (Kompatibilität). Idempotent.
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1) RPC: Dauercode-Ausgabe durch den FLZ-Zugang (eigenes Präsidium) ───────
create or replace function public.argus_admin_issue_dauerhaft(p_praesidium_id uuid, p_label text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public', 'extensions'
as $function$
declare
  v_alphabet    text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   -- ohne 0/O/1/I (vgl. 0013)
  v_short_code  text;
  v_token       text;
  v_now_ms      bigint;
  v_part1       text;
  v_part2       text;
  v_attempt     int := 0;
  v_exists      boolean;
begin
  -- Guard 1: FLZ-/Admin-Token erforderlich (gated auf argus_token_active)
  if not public.argus_is_admin() then
    raise exception 'Nur mit FLZ-Zugang';
  end if;

  -- Guard 2: Ziel-Präsidium MUSS das eigene sein (keine Fremd-Präsidiums-Eskalation)
  if public.argus_admin_praesidium_id() is null
     or p_praesidium_id <> public.argus_admin_praesidium_id() then
    raise exception 'Nur fürs eigene Präsidium';
  end if;

  v_now_ms := (extract(epoch from now())*1000)::bigint;
  v_token  := encode(extensions.gen_random_bytes(16), 'hex');

  -- Short-Code XXXX-XXXX, kollisionsfrei (max. 10 Versuche)
  loop
    v_attempt := v_attempt + 1;
    if v_attempt > 10 then
      raise exception 'Short-Code-Kollision — bitte erneut versuchen';
    end if;
    v_part1 := ''; v_part2 := '';
    for i in 1..4 loop
      v_part1 := v_part1 || substr(v_alphabet, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    for i in 1..4 loop
      v_part2 := v_part2 || substr(v_alphabet, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % length(v_alphabet)), 1);
    end loop;
    v_short_code := v_part1 || '-' || v_part2;
    select exists(select 1 from public.access_tokens where short_code = v_short_code) into v_exists;
    exit when not v_exists;
  end loop;

  -- Dauercode: gast=false, temporary=false, single_use=false, kein Ablauf —
  -- exakt die Semantik eines vom Master angelegten „Dauerhaft"-Codes.
  insert into public.access_tokens (
    token, short_code, praesidium_id, gast,
    is_admin, is_master, observer, single_use, temporary,
    ttl_hours, expires_at, label
  ) values (
    v_token, v_short_code, p_praesidium_id, false,
    false, false, false, false, false,
    null, null, btrim(coalesce(p_label,''))
  );

  -- Zwangs-Log (Nachweis, 12-Monats-Retention aus 0004)
  insert into public.governance_log (at, kuerzel, action)
    values (v_now_ms, v_short_code, 'admin_dauer_issue');

  return jsonb_build_object('short_code', v_short_code);
end;
$function$;
grant execute on function public.argus_admin_issue_dauerhaft(uuid, text) to anon;
comment on function public.argus_admin_issue_dauerhaft(uuid, text) is
  'FLZ-Zugang (is_admin) gibt einen unbefristeten Dauercode NUR fürs eigene Präsidium aus. Kein Patientendaten-Zugriff.';

-- ── 2) RPC: Geräte-Code des eigenen Präsidiums sperren (Dauerhaft/Einmal/Gast) ─
-- Erweitert argus_admin_revoke_gast (nur gast=true) auf alle NICHT-privilegierten
-- Codes des eigenen Präsidiums. Privilegierte Codes (master/admin/observer)
-- bleiben für den FLZ-Zugang unantastbar.
create or replace function public.argus_admin_revoke_code(p_short_code text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_target record;
begin
  if not public.argus_is_admin() then
    raise exception 'Nur mit FLZ-Zugang';
  end if;

  select praesidium_id, is_master, is_admin, observer, revoked into v_target
  from public.access_tokens where short_code = p_short_code;
  if not found then
    raise exception 'Code nicht gefunden';
  end if;

  if v_target.praesidium_id is null
     or v_target.praesidium_id <> public.argus_admin_praesidium_id() then
    raise exception 'Nur Codes des eigenen Präsidiums';
  end if;

  if coalesce(v_target.is_master, false)
     or coalesce(v_target.is_admin, false)
     or coalesce(v_target.observer, false) then
    raise exception 'Privilegierte Codes können hier nicht gesperrt werden';
  end if;

  update public.access_tokens set revoked = true where short_code = p_short_code;

  insert into public.governance_log (at, kuerzel, action)
    values ((extract(epoch from now())*1000)::bigint, p_short_code, 'admin_code_revoke');

  return jsonb_build_object('short_code', p_short_code, 'revoked', true);
end;
$function$;
grant execute on function public.argus_admin_revoke_code(text) to anon;
comment on function public.argus_admin_revoke_code(text) is
  'FLZ-Zugang sperrt einen nicht-privilegierten Geräte-Code (Dauerhaft/Einmal/Gast) NUR des eigenen Präsidiums. Sofortsperre via jti.';

-- ── 3) governance_log.action: Katalog nachziehen ────────────────────────────
comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view | lage_view | gast_join | protokoll_export | admin_login | admin_gast_issue | admin_gast_revoke | admin_dauer_issue | admin_code_revoke';
