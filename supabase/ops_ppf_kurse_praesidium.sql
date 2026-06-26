-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- OPS (kein Schema-Migrationsschritt) — PPF-Kurse: Präsidium bereitstellen
-- ============================================================================
-- Owner-Auftrag 2026-06-21: „neues, leeres Präsidium 'PPF-Kurse' — nutze hierfür
-- VORÜBERGEHEND das Präsidium 'PP Karlsruhe — Schulung'."
--
-- Interpretation (BITTE BESTÄTIGEN): Das vorhandene Schulungs-Präsidium
-- 'PP Karlsruhe — Schulung' wird in 'PPF-Kurse' UMBENANNT und bleibt ein
-- Schulungs-Präsidium (schulung=true → Trainings-/Demo-Funktionen + Reset
-- verfügbar). Das ist eine reine DATEN-Änderung an der Live-Instanz, KEIN
-- Schema-Schritt — deshalb hier als Ops-Skript, nicht als Migration.
--
-- Anwendung: Supabase Management API (POST /v1/projects/{ref}/database/query,
-- Authorization: Bearer <PAT>) — wie 0001 ff. (PAT nur als Shell-Variable,
-- nie in Dateien/Commits).
--
-- HINWEIS Zugangs-Codes: Die access_tokens hängen an der präsidium_id (ändert
-- sich beim Umbenennen NICHT). Bestehende Codes von 'PP Karlsruhe — Schulung'
-- gelten danach für 'PPF-Kurse'. Für den Kurs am besten über die Leitungs-Seite
-- frische Codes (z. B. Gast-Code 24 h oder Einmal-Links) ausgeben.
-- ============================================================================

-- ── 1) Umbenennen ────────────────────────────────────────────────────────────
update public.praesidien
   set name = 'PPF-Kurse'
 where name = 'PP Karlsruhe — Schulung';
-- Erwartung: UPDATE 1. Falls 0 → Name abweichend (Em-Dash „—" vs. Bindestrich?
-- prüfen mit: select id,name,schulung from public.praesidien order by name;).

-- schulung-Flag sicherstellen (sollte bereits true sein):
update public.praesidien set schulung = true where name = 'PPF-Kurse';

-- ── 2) OPTIONAL „leeren" — NUR ausführen, wenn ein wirklich leerer Start ──────
--      gewünscht ist. ⚠️ LÖSCHT alle CCPs/Patienten/Checklisten dieses
--      (Schulungs-)Präsidiums UNWIDERRUFLICH. Auskommentiert belassen, bis
--      bewusst gewünscht. (Schulungs-Präsidien legen beim Betreten ohnehin
--      Demo-CCPs an; für einen Kurs mit eigenen Erfassungen ggf. unerwünscht.)
--
-- with p as (select id from public.praesidien where name = 'PPF-Kurse')
-- delete from public.patients   where ccp_id in (select id from public.ccps where praesidium_id in (select id from p));
-- with p as (select id from public.praesidien where name = 'PPF-Kurse')
-- delete from public.checklists where ccp_id in (select id from public.ccps where praesidium_id in (select id from p));
-- with p as (select id from public.praesidien where name = 'PPF-Kurse')
-- delete from public.ccps       where praesidium_id in (select id from p);

-- ── 3) Kontrolle ─────────────────────────────────────────────────────────────
-- select id, name, schulung from public.praesidien order by name;
