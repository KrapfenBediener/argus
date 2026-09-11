-- ══════════════════════════════════════════════════════════════════════════
-- Migration 0021 — MasterToken darf die Lage präsidienübergreifend sehen
-- ══════════════════════════════════════════════════════════════════════════
-- Owner-Report: „Warum wird der MasterToken von der FLZ/Lage-Ansicht abgewiesen?"
--
-- Bisher: argus_exchange_observer_code akzeptiert NUR observer=true-Codes; der
-- globale MasterToken (is_master, kein Präsidium) fiel in den Zweig
--   „Kein Beobachter-Code" → Ablehnung.
-- Das war Absicht (Beobachter-Rolle ≠ Master), sperrt aber den Master, der ohnehin
-- alles sieht, unnötig aus der reinen Lese-Ansicht aus.
--
-- Fix (additiv, minimal, sicher):
--   * argus_exchange_observer_code bekommt einen Master-Zweig VOR dem observer-
--     Check: ist der Code der MasterToken → statt Ablehnung ein JWT mit
--     is_flz=true (praesidienübergreifend, READ-ONLY) ausstellen.
--   * BEWUSST KEIN is_master-Claim in diesem JWT → die Lage-Seite erhält keinerlei
--     Master-Schreibrechte; is_flz ist nachweislich nur Lese-Gate in argus_lage.
--   * jti = short_code des MasterTokens → argus_token_active() greift (Sofort-
--     Sperre, falls der Master je gesperrt würde); da MasterToken „nicht sperrbar"
--     ist, liefert token_active hier true.
--   * argus_lage ist UNVERÄNDERT: sein bestehender FLZ-Zweig (argus_is_flz())
--     aggregiert alle offenen CCPs aller Präsidien → genau der gewünschte
--     globale Master-Lageblick.
--   * governance_log 'lage_view' wird wie bei Observer geschrieben (Nachweis).
--
-- Reihenfolge unverändert; keine RLS-Änderung; keine neuen Abhängigkeiten. Idempotent.
-- ══════════════════════════════════════════════════════════════════════════

create or replace function public.argus_exchange_observer_code(code text)
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

  select praesidium_id, ttl_hours, revoked, observer, is_master
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;

  -- JWT-Secret (für beide Zweige benötigt).
  select decrypted_secret into v_jwt_secret
  from vault.decrypted_secrets
  where name = 'argus_jwt_secret'
  limit 1;
  if v_jwt_secret is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  v_now := extract(epoch from now())::int;

  -- ── Master-Zweig (0021): globaler, read-only Lageblick über is_flz ──────────
  if coalesce(v_token.is_master, false) then
    v_ttl_secs := 12*3600;   -- 12-h-Lesesitzung
    v_exp := v_now + v_ttl_secs;
    v_jwt := extensions.sign(
      json_build_object(
        'iss', 'supabase',
        'sub', 'argus-observer',
        'role', 'anon',
        'is_flz', true,                 -- präsidienübergreifend, NUR Lese-Gate in argus_lage
        'jti', v_short_code,            -- Sofort-Sperre via argus_token_active()
        'iat', v_now,
        'exp', v_exp
      ),
      v_jwt_secret
    );
    insert into public.governance_log (at, kuerzel, action)
      values ((extract(epoch from now())*1000)::bigint, v_short_code, 'lage_view');
    return jsonb_build_object(
      'jwt',             v_jwt,
      'exp',             v_exp,
      'praesidium_id',   null,
      'praesidium_name', null,
      'flz',             true,          -- Frontend-Signal: globaler (Mehr-Präsidien-)Modus
      'ttl_seconds',     v_ttl_secs
    );
  end if;

  -- ── Observer-Zweig (unverändert gegenüber 0007) ────────────────────────────
  if not coalesce(v_token.observer, false) then
    return jsonb_build_object('error', 'Kein Beobachter-Code');
  end if;
  if v_token.praesidium_id is null then
    return jsonb_build_object('error', 'Konfigurationsfehler');
  end if;

  v_ttl_secs := case
    when v_token.ttl_hours is not null then v_token.ttl_hours*3600
    else 24*3600 end;
  v_exp := v_now + v_ttl_secs;

  v_jwt := extensions.sign(
    json_build_object(
      'iss', 'supabase',
      'sub', 'argus-observer',
      'role', 'anon',
      'is_observer', true,
      'observer_praesidium_id', v_token.praesidium_id,
      'jti', v_short_code,
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  select name into v_pname from public.praesidien
  where id = v_token.praesidium_id;

  insert into public.governance_log (at, kuerzel, action)
    values ((extract(epoch from now())*1000)::bigint, v_short_code, 'lage_view');

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'praesidium_id',   v_token.praesidium_id,
    'praesidium_name', v_pname,
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;

grant execute on function public.argus_exchange_observer_code(text) to anon;
