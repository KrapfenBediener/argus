-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- FLZ darf die Ortsbezeichnung eines aktiven CCP setzen/korrigieren
-- ============================================================================
-- Owner-Wunsch 2026-06-13: Das FLZ sieht die GPS-Koordinaten in der
-- Lageansicht und kennt die Objekte — es soll die ORTSBEZEICHNUNG eines CCP
-- nachtragen/korrigieren können (z. B. wenn die Eröffnungs-Abfrage im Feld
-- übersprungen wurde).
--
-- Einordnung: Das ist eine ENG BEGRENZTE Schreib-Befugnis auf ein reines
-- Infrastruktur-Label (ccps.ort) — KEINE Personendaten, keine Patienten-
-- zeilen, keine Zähler. Das read-only-Prinzip der Lageansicht für
-- Patientendaten bleibt unberührt. Jede Änderung wird protokolliert
-- (governance_log action 'lage_ort', kuerzel = Beobachter-Code aus dem
-- jti-Claim, neuer Ort in 'begruendung'; 12-Monats-Retention aus 0004).
--
-- Reihenfolge: 0000 → … → 0009 → dieses Skript. Anwendung wie immer.
-- Idempotent (create or replace, grant, comment).
-- ============================================================================

create or replace function public.argus_lage_set_ort(p_kennung text, p_ort text)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_pid   uuid;
  v_jti   text;
  v_ort   text;
  v_count int;
begin
  -- Nur Beobachter (argus_is_observer prüft über argus_token_active auch
  -- revoked/expires — 0007/0009).
  if not public.argus_is_observer() or public.argus_observer_praesidium_id() is null then
    raise exception 'Nur mit Beobachter-Zugang';
  end if;
  v_pid := public.argus_observer_praesidium_id();
  v_jti := nullif(current_setting('request.jwt.claims', true)::json->>'jti', '');

  if p_kennung is null or btrim(p_kennung) = '' then
    raise exception 'Kennung erforderlich';
  end if;
  v_ort := btrim(coalesce(p_ort, ''));
  if length(v_ort) > 120 then
    raise exception 'Ort zu lang (max. 120 Zeichen)';
  end if;

  update public.ccps set ort = v_ort
  where praesidium_id = v_pid
    and kennung = btrim(p_kennung)
    and closed_at is null;
  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'CCP nicht gefunden';
  end if;

  -- Protokoll: wer (Beobachter-Code) hat wann welchem CCP welchen Ort gegeben.
  insert into public.governance_log (at, kuerzel, action, begruendung)
    values ((extract(epoch from now())*1000)::bigint,
            coalesce(v_jti, 'beobachter'), 'lage_ort',
            'CCP '||btrim(p_kennung)||' → '||v_ort);

  return jsonb_build_object('ok', true, 'ort', v_ort);
end;
$function$;
grant execute on function public.argus_lage_set_ort(text, text) to anon;

comment on function public.argus_lage_set_ort(text, text) is
  'FLZ-Orts-Korrektur (0010): Beobachter setzt die Ortsbezeichnung eines '
  'aktiven CCP seines Präsidiums (reines Infrastruktur-Label, keine '
  'Personendaten). Jede Änderung protokolliert (lage_ort).';

comment on column public.governance_log.action is
  'foto_view | frist_verlaengert | protokoll_view | lage_view | gast_join | protokoll_export | lage_ort';
