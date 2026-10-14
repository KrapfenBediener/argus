-- 0022_geraetenummer.sql
-- (ursprünglich als 0021 angelegt und am 2026-10-14 so live eingespielt; wegen
--  Nummernkollision mit 0021_master_lage_global umbenannt — Inhalt unverändert,
--  idempotent, erneutes Einspielen ist unschädlich.)
-- Offline-sichere Patientennummern über eine Gerätenummer je CCP.
--
-- Hintergrund: Online kommt die laufende Nummer zentral-atomar vom Server
-- (argus_claim_nums, 0008) und ist kollisionssicher. OFFLINE kann kein
-- gemeinsamer Zähler greifen — zwei Geräte im selben CCP vergaben deshalb
-- dieselben Nummern. Lösung: Jedes Gerät erhält beim Beitritt EINMALIG eine
-- eindeutige Gerätenummer; offline erfasste Patienten tragen diese Nummer als
-- Zusatz (Label "A-7-2"), sodass sie sich geräteübergreifend nie überschneiden.
--
-- Der CCP-Ersteller ist Gerät 1 (rein clientseitig). Der erste Beitritt bekommt
-- 2, der nächste 3, usw. — atomar über argus_claim_device().
--
-- Additive Migration: eine Spalte auf ccps + eine Funktion. KEINE Änderung an
-- der patients-Tabelle (die Gerätenummer reist im vorhandenen Label mit).

alter table public.ccps add column if not exists next_device int not null default 1;

create or replace function public.argus_claim_device(p_ccp_id uuid)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_ccp record;
  v_dev int;
begin
  -- Zeile sperren → atomare Vergabe auch bei gleichzeitigen Beitritten
  select id, praesidium_id, closed_at, next_device into v_ccp
  from public.ccps where id = p_ccp_id
  for update;
  if not found then
    return jsonb_build_object('error', 'CCP nicht gefunden');
  end if;

  -- gleiche Berechtigungsgrenze wie argus_claim_nums (0008)
  if not public.argus_is_master()
     and ( public.argus_praesidium_id() is null
           or v_ccp.praesidium_id is distinct from public.argus_praesidium_id() ) then
    return jsonb_build_object('error', 'Keine Berechtigung');
  end if;
  if v_ccp.closed_at is not null then
    return jsonb_build_object('error', 'Einsatz abgeschlossen');
  end if;

  -- Ersteller = 1 (next_device startet bei 1); erster Beitritt → 2, dann 3 …
  v_dev := greatest(coalesce(v_ccp.next_device, 1), 1) + 1;
  update public.ccps set next_device = v_dev where id = p_ccp_id;

  return jsonb_build_object('device', v_dev);
end;
$function$;

grant execute on function public.argus_claim_device(uuid) to anon;

comment on function public.argus_claim_device(uuid) is
  'Vergibt beim CCP-Beitritt atomar eine eindeutige Gerätenummer (>=2; Ersteller ist 1). Grundlage der offline-sicheren Patientennummern (Label "A-7-2").';
