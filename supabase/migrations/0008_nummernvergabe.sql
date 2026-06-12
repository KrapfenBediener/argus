-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- Serverseitige Nummernvergabe (Paket 1, Feedback 2026-06-13)
-- ============================================================================
-- BUG (Feldtest-Feedback): Die laufende Patienten-Nummer wurde rein lokal
-- vergeben (max über die geladenen Patienten + 1). Nach Verlassen und
-- Wiederbetreten eines CCP (lokaler Bestand geleert) oder bei gestörtem
-- Cloud-Load begann die Zählung wieder bei 1 → zwei verschiedene Patienten
-- mit derselben Nummer auf der Haut. Inakzeptabel (Verwechslungsgefahr).
--
-- FIX: Atomarer Zähler je CCP-Zeile (ccps.next_num) + Claim-RPC. Die App
-- holt die Nummer ab jetzt primär vom Server (kollisionssicher auch bei
-- mehreren Geräten); offline fällt sie auf die gehärtete lokale Logik
-- zurück (lokales Maximum + persistierte zuletzt vergebene Nummer).
-- Der Zähler ist SELBSTHEILEND: Er fällt nie hinter max(num) vorhandener
-- Patienten zurück — offline angelegte Patienten, die später synchen,
-- werden beim nächsten Claim übersprungen.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   0000 → 0001 → 0002 → 0003 → 0004 → 0005 → 0006 → 0007 → dieses Skript.
--
-- Anwendung wie 0001–0007: Supabase Management API. Idempotent
-- (add column if not exists; Backfill mit greatest ist wiederholbar;
-- create or replace / grant).
-- ============================================================================

-- ── 1) Zähler-Spalte + Backfill ─────────────────────────────────────────────
alter table public.ccps add column if not exists next_num integer not null default 1;

-- Backfill: Zähler mindestens auf max(num)+1 der vorhandenen Patienten heben.
-- greatest() macht den Backfill idempotent (zweiter Lauf ändert nichts).
update public.ccps c
   set next_num = greatest(c.next_num,
         coalesce((select max(p.num) from public.patients p where p.ccp_id = c.id), 0) + 1);

-- ── 2) Claim-RPC: n Nummern atomar reservieren ──────────────────────────────
-- Row-Lock (for update) macht gleichzeitige Claims zweier Geräte konfliktfrei.
-- Berechtigung wie argus_close_einsatz: Master oder eigenes Präsidium —
-- über die 0007-Helfer wirkt auch die jti-Sofort-Sperre. Abgeschlossene
-- Einsätze vergeben keine Nummern mehr (Schreibsperre konsistent zur RLS).
-- Fehler als jsonb {'error': …} (Muster argus_close_einsatz — die App zeigt
-- nichts an, sie fällt still auf die lokale Vergabe zurück).
create or replace function public.argus_claim_nums(p_ccp_id uuid, p_count int default 1)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_ccp   record;
  v_start int;
begin
  if p_count is null or p_count < 1 or p_count > 50 then
    return jsonb_build_object('error', 'Ungültige Anzahl');
  end if;

  select id, praesidium_id, closed_at, next_num into v_ccp
  from public.ccps where id = p_ccp_id
  for update;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;
  if v_ccp.closed_at is not null then
    return jsonb_build_object('error', 'Einsatz abgeschlossen');
  end if;

  -- selbstheilend: nie hinter bereits vergebene Nummern zurückfallen
  v_start := greatest(
    coalesce(v_ccp.next_num, 1),
    coalesce((select max(p.num) from public.patients p where p.ccp_id = p_ccp_id), 0) + 1
  );

  update public.ccps set next_num = v_start + p_count where id = p_ccp_id;

  return jsonb_build_object('start', v_start, 'count', p_count);
end;
$function$;
grant execute on function public.argus_claim_nums(uuid, int) to anon;

comment on function public.argus_claim_nums(uuid, int) is
  'Serverseitige Nummernvergabe (0008): reserviert atomar p_count laufende '
  'Nummern für einen offenen CCP (Row-Lock, selbstheilend via greatest mit '
  'max(patients.num)). Berechtigung: Master oder eigenes Präsidium; '
  'jti-Sofort-Sperre (0007) greift über die Claim-Helfer.';
