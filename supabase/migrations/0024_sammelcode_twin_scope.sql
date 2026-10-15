-- 0024 — Sammelcode (Dauercode / 24-h-Code) schaltet auch den Schulungs-Zwilling frei
--
-- Bisher trug ein per argus_exchange_code ausgestelltes Geräte-JWT IMMER die
-- praesidium_id des Codes (Echtbetrieb). Für die Schulungsumgebung musste das
-- Gerät einen ZWEITEN Code (des Schulungs-Präsidiums) einlösen. Owner-Entscheid
-- 2026-10-15: EIN Dauercode fürs PP soll Echtbetrieb UND Schulungs-Zwilling
-- freischalten.
--
-- Lösung (Muster 0019/0020, argus_exchange_person_code): optionaler Parameter
-- p_scope ('echt' | 'schulung'). Bei 'schulung' wird SERVER-SEITIG der Twin über
-- praesidien.schulungs_zwilling_id aufgelöst (keine Client-Injection möglich);
-- das JWT trägt dann praesidium_id = Twin. Die App löst den Code beim
-- Freischalten zweimal ein (echt + schulung) und hält je Präsidium ein JWT.
--
-- Sicherheit:
--   * jti bleibt der short_code → Sperre (revoked / argus_token_active) wirkt
--     für BEIDE JWTs gleichzeitig.
--   * Ein Code, der direkt an ein Schulungs-Präsidium gebunden ist, liefert
--     bei p_scope='schulung' sich selbst (kein Twin nötig).
--   * Ein Twin-JWT gewährt nie mehr als das Echt-JWT: gleiche Rolle (Gerät),
--     nur anderes Präsidium — und zwar ausschließlich das in der DB hinterlegte.
--   * Master-Codes (praesidium_id null): p_scope ohne Wirkung.
--   * p_scope-Whitelist (CR-02-Muster aus 0020).
--
-- Die alte 1-Parameter-Signatur wird ENTFERNT (sonst wäre der Aufruf mit nur
-- `code` mehrdeutig). PostgREST ruft die neue Funktion mit Default p_scope='echt'
-- auf — bestehende Clients funktionieren unverändert.
--
-- Idempotent.

drop function if exists public.argus_exchange_code(text);
drop function if exists public.argus_exchange_code(text, text);

create or replace function public.argus_exchange_code(code text, p_scope text default 'echt')
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
  v_eff_praes   uuid;
  v_twin        uuid;
  v_is_schul    boolean;
begin
  -- p_scope-Whitelist (CR-02-Muster): alles andere ist ein Client-Fehler.
  if coalesce(p_scope, 'echt') not in ('echt', 'schulung') then
    return jsonb_build_object('error', 'Ungültiger Scope');
  end if;

  v_clean := upper(regexp_replace(code, '[\s\-]', '', 'g'));
  if length(v_clean) < 8 then
    return jsonb_build_object('error', 'Code zu kurz');
  end if;
  v_short_code := substring(v_clean,1,4) || '-' || substring(v_clean,5,4);

  select praesidium_id, is_master, ttl_hours, single_use, used_at, revoked, observer, gast, expires_at, is_admin, is_person
  into v_token from public.access_tokens
  where short_code = v_short_code;

  if not found then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if coalesce(v_token.revoked, false) then
    return jsonb_build_object('error', 'Code wurde gesperrt');
  end if;
  if coalesce(v_token.observer, false) then
    return jsonb_build_object('error', 'Beobachter-Code — nur für die Lageansicht gültig');
  end if;
  if coalesce(v_token.is_admin, false) then
    return jsonb_build_object('error', 'Admin-Code — nur für die Leitungs-Seite gültig');
  end if;
  if coalesce(v_token.is_person, false) then
    return jsonb_build_object('error', 'Pro-Person-Code — nur für die Leitungs-Seite gültig');
  end if;
  if v_token.expires_at is not null
     and v_token.expires_at <= (extract(epoch from now())*1000)::bigint then
    return jsonb_build_object('error', 'Code abgelaufen');
  end if;
  -- Einmal-Code: die ZWEITE Einlösung (Twin) desselben Geräts folgt unmittelbar
  -- auf die erste; used_at ist dann bereits gesetzt. Daher ist der Twin-Scope
  -- für Einmal-Codes nicht verfügbar (Einmal-Codes sind ohnehin Echtbetrieb-Gäste).
  if v_token.single_use and v_token.used_at is not null then
    return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
  end if;
  if v_token.single_use and coalesce(p_scope,'echt') = 'schulung' then
    return jsonb_build_object('error', 'Einmal-Codes gelten nur für den Echtbetrieb');
  end if;

  -- ── Twin-Auflösung (SERVER-SEITIG) ──────────────────────────────────────────
  v_eff_praes := v_token.praesidium_id;
  if coalesce(p_scope,'echt') = 'schulung' and v_token.praesidium_id is not null then
    select schulung, schulungs_zwilling_id into v_is_schul, v_twin
      from public.praesidien where id = v_token.praesidium_id;
    if coalesce(v_is_schul, false) then
      v_eff_praes := v_token.praesidium_id;          -- Code hängt schon am Schulungs-Präsidium
    elsif v_twin is null then
      return jsonb_build_object('error', 'Kein Schulungs-Präsidium für dieses Präsidium hinterlegt');
    else
      v_eff_praes := v_twin;
    end if;
  end if;

  v_now := extract(epoch from now())::int;
  v_ttl_secs := case
    when v_token.is_master then 30*24*3600
    when coalesce(v_token.gast, false) then 24*3600
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
      'praesidium_id', v_eff_praes,
      'is_master', coalesce(v_token.is_master, false),
      'jti', v_short_code,
      'iat', v_now,
      'exp', v_exp
    ),
    v_jwt_secret
  );

  if v_token.single_use and v_token.used_at is null then
    update public.access_tokens
    set used_at = (extract(epoch from now())*1000)::bigint
    where short_code = v_short_code and used_at is null;
  end if;

  if coalesce(v_token.gast, false) then
    insert into public.governance_log (at, kuerzel, action)
      values ((extract(epoch from now())*1000)::bigint, v_short_code, 'gast_join');
  end if;

  if v_eff_praes is not null then
    select name into v_pname from public.praesidien where id = v_eff_praes;
  end if;

  return jsonb_build_object(
    'jwt',             v_jwt,
    'exp',             v_exp,
    'praesidium_id',   v_eff_praes,
    'praesidium_name', v_pname,
    'scope',           coalesce(p_scope,'echt'),
    'is_master',       coalesce(v_token.is_master, false),
    'ttl_seconds',     v_ttl_secs
  );
end;
$function$;

grant execute on function public.argus_exchange_code(text, text) to anon;
comment on function public.argus_exchange_code(text, text) is
  'Geräte-Code gegen JWT tauschen (0024): p_scope=''schulung'' liefert ein JWT für den '
  'server-seitig aufgelösten Schulungs-Zwilling (praesidien.schulungs_zwilling_id). '
  'jti = short_code → Sperre wirkt für beide Scopes. Einmal-Codes: nur Echtbetrieb.';
