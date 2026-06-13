-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Paket 3 (Feedback 2026-06-13): Schulungs-Reset über Tombstones,
--   Schulungs-Provisionierung je Präsidium
-- ============================================================================
-- Owner-Entscheide 2026-06-13:
--   * SCHULUNGS-RESET ALS TOMBSTONE (statt Hard-DELETE): Der bisherige
--     clientseitige Reset löschte ccps-Rows hart — Offline-Geräte fanden beim
--     Reconnect keinen Abschluss-Hinweis und blieben auf altem Stand.
--     argus_schulung_reset tombstont jeden offenen CCP des Schulungs-
--     Präsidiums mit EXAKT der Signatur des Einsatz-Abschlusses
--     (closed_at gesetzt, ort='', master_medic='', join_token=null) —
--     Offline-Geräte bereinigen sich über die VORHANDENE
--     checkClosedEinsatz/handleRemoteClose-Mechanik (isCcpClosedRow).
--     NUR für Präsidien mit schulung=true (0009) — echte Präsidien können
--     über diesen RPC NIEMALS getombstonet werden.
--   * TOMBSTONE-HYGIENE: Schulungs-Tombstones älter als 7 Tage werden beim
--     Reset hart gelöscht (sonst unbegrenzte Row-Anhäufung bei häufigen
--     Resets). Akzeptiertes Restrisiko: ein Gerät, das >7 Tage offline in
--     einer Schulung war, verpasst den Tombstone und behält lokalen
--     Übungsmüll bis zum manuellen Aufräumen (docs/SELF-HOSTING.md).
--   * KEIN Eintrag ins Lösch- oder Governance-Protokoll für Schulungs-Resets:
--     reine Übungsdaten ohne Personenbezug; Log-Spam bei häufigen Resets
--     vermeiden. (Abgrenzung: die 72-h-Löschung echter Einsätze über
--     argus_run_purge bleibt protokolliert.)
--   * PROVISIONIERUNG: argus_provision_schulung legt je Produktiv-Präsidium
--     ein Schulungs-Schwester-Präsidium „<Name> — Schulung" (schulung=true)
--     an. Zuordnung über Namenskonvention — bewusst einfach, kein neues
--     Spalten-/FK-Modell. Idempotent (2. Aufruf legt nichts an), master-only.
--
-- Reihenfolge: 0000 → … → 0010 → dieses Skript. Anwendung wie immer über
-- die Management API. Idempotent (create or replace, not-exists-INSERT).
-- Zeitkonvention: bigint in JS-Millisekunden (vgl. 0002).
-- ============================================================================

-- ── 1) argus_schulung_reset: Tombstone-Reset für Schulungs-Präsidien ────────
-- Berechtigung: Master ODER eigenes Präsidium (Trainer vor Ort resettet
-- selbst) — Muster argus_close_einsatz (0002/0003). Je offenem CCP:
-- patients+checklists löschen, DANN tombstonen (DELETE vor UPDATE — sonst
-- erschiene ein Tombstone mit Rest-Patienten in argus_governance_einsaetze).
create or replace function public.argus_schulung_reset(p_praesidium_id uuid)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_now        bigint := (extract(epoch from now())*1000)::bigint;
  v_praesidium record;
  r            record;
  v_reset      int := 0;
  v_hygiene    int := 0;
begin
  -- Berechtigungs-Gate ZUERST (Master ODER eigenes Präsidium, Muster
  -- argus_close_einsatz): der RPC ist anon-grantet — die Existenz-/schulung-
  -- Prüfung VOR dem Gate wäre ein Existenz-Orakel (Nicht-Berechtigte könnten
  -- per UUID-Probe Existenz und Schulungs-Status fremder Präsidien
  -- unterscheiden). Nicht-Berechtigte sehen einheitlich 'Keine Berechtigung'.
  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or p_praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;

  -- Schulung-Pflicht-Check (vor jeder Mutation): echte Präsidien werden NIE
  -- getombstonet.
  select id, schulung into v_praesidium
  from public.praesidien where id = p_praesidium_id;
  if not found then
    return jsonb_build_object('error', 'Präsidium nicht gefunden');
  end if;
  if not coalesce(v_praesidium.schulung, false) then
    return jsonb_build_object('error', 'Nur für Schulungs-Präsidien');
  end if;

  -- Reset-Schleife je OFFENEM CCP des Schulungs-Präsidiums.
  -- Reihenfolge ZWINGEND: erst DELETE, dann UPDATE (kein Tombstone mit
  -- Rest-Patienten — Filter in argus_governance_einsaetze bliebe sonst wahr).
  for r in
    select c.id from public.ccps c
    where c.praesidium_id = p_praesidium_id and c.closed_at is null
  loop
    delete from public.patients   where ccp_id = r.id;
    delete from public.checklists where ccp_id = r.id;
    -- Tombstone-Signatur EXAKT wie Einsatz-Abschluss/Purge (isCcpClosedRow
    -- am Client matcht closed_at + ort='' + master_medic='' + join_token=null):
    update public.ccps set
      closed_at    = v_now,
      ort          = '',
      master_medic = '',
      join_token   = null
    where id = r.id;
    v_reset := v_reset + 1;
  end loop;

  -- Hygiene: Schulungs-Tombstones > 7 Tage hart löschen.
  -- praesidium_id-Filter ZWINGEND (nur das eigene Präsidium); der
  -- schulung=true-Guard ist durch den Pflicht-Check oben gegeben und wird
  -- hier redundant mitgeprüft (Defense in depth). KEIN Lösch-Protokoll-
  -- Eintrag — Schulungsdaten ohne Personenbezug, kein Log-Spam (Owner-Entscheid).
  delete from public.ccps c
  where c.praesidium_id = p_praesidium_id
    and c.closed_at is not null
    and c.closed_at < v_now - 7::bigint * 86400000
    and exists (select 1 from public.praesidien pp
                where pp.id = c.praesidium_id and pp.schulung);
  get diagnostics v_hygiene = row_count;

  return jsonb_build_object('ok', true, 'reset', v_reset, 'hygiene', v_hygiene);
end;
$function$;
grant execute on function public.argus_schulung_reset(uuid) to anon;
comment on function public.argus_schulung_reset(uuid) is
  'Schulungs-Reset (0011): tombstont alle offenen CCPs eines Schulungs-'
  'Präsidiums (closed_at, ort='''', master_medic='''', join_token=null; '
  'patients+checklists vorab gelöscht) — Offline-Geräte bereinigen sich '
  'über die bestehende Abschluss-Erkennung. Nur schulung=true; Berechtigung '
  'Master oder eigenes Präsidium. Löscht zusätzlich Schulungs-Tombstones '
  '> 7 Tage hart (nur eigenes Präsidium). Bewusst kein Lösch-Protokoll-Eintrag.';

-- ── 2) argus_provision_schulung: Schulungs-Schwester-Präsidien anlegen ──────
-- Master-only (streng, Muster argus_mark_export/argus_governance_einsaetze).
-- Idempotent über Namenskonvention „<Name> — Schulung": legt nur an, was
-- noch fehlt; 2. Aufruf liefert eine leere Liste.
create or replace function public.argus_provision_schulung()
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_namen jsonb;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;

  -- Je Produktiv-Präsidium (schulung=false) ohne vorhandenes Schwester-
  -- Präsidium „<Name> — Schulung" eines anlegen (schulung=true):
  with neu as (
    insert into public.praesidien (name, schulung)
    select p.name || ' — Schulung', true
    from public.praesidien p
    where coalesce(p.schulung, false) = false
      and not exists (
        select 1 from public.praesidien s
        where s.schulung = true
          and s.name = p.name || ' — Schulung'
      )
    returning name
  )
  select coalesce(jsonb_agg(name), '[]'::jsonb) into v_namen from neu;

  return jsonb_build_object('angelegte', v_namen);
end;
$function$;
grant execute on function public.argus_provision_schulung() to anon;
comment on function public.argus_provision_schulung() is
  'Schulungs-Provisionierung (0011, master-only): legt je Präsidium ohne '
  'schulung-Flag ein Schwester-Präsidium „<Name> — Schulung" (schulung=true) '
  'an, sofern es noch nicht existiert (Namenskonvention, kein FK-Modell). '
  'Idempotent — Rückgabe {angelegte:[Namen]} bzw. leere Liste.';
