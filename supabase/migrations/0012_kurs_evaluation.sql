-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- 0012 — Kurs-Evaluation: anonymer digitaler Evaluationsbogen
-- ============================================================================
-- Hintergrund (Owner-Auftrag 2026-06-21): Teilnehmer eines PPF-Kurses füllen
-- nach der ARGUS-Nutzung einen digitalen Evaluationsbogen aus
-- (docs/evaluation.html). Diese Migration legt die Ablage dafür an.
--
-- Datenschutz-Design (konsistent zum Projektprinzip Pseudonymität):
--   * KEINE Pflicht-Personendaten. Der Bogen ist anonym; ein optionales
--     Kürzel/Name-Feld liegt – wenn überhaupt ausgefüllt – im answers-jsonb.
--   * anon darf NUR INSERT (Abgabe), KEIN SELECT. Niemand kann über den
--     öffentlichen Anon-Key die abgegebenen Bögen auslesen.
--   * Auslesen ausschließlich über die MasterToken-gebundene RPC
--     argus_eval_list() (security definer, argus_is_master()-Pflicht) bzw.
--     direkt per SQL (Owner/Service).
--
-- Reihenfolge: nach 0000–0011 anwendbar. Idempotent (create if not exists /
-- create or replace / drop policy if exists). Anwendung wie 0001 ff. über die
-- Supabase Management API (POST /v1/projects/{ref}/database/query, Bearer PAT).
-- ============================================================================

-- ── 1) Tabelle ───────────────────────────────────────────────────────────────
create table if not exists public.course_evaluations (
  id          uuid primary key default extensions.uuid_generate_v4(),
  created_at  timestamptz not null default now(),
  course      text,                                  -- z. B. 'PPF-Kurse'
  answers     jsonb not null default '{}'::jsonb     -- vollständige Antwortstruktur
);

-- ── 2) RLS: anon nur INSERT (Abgabe), kein SELECT ───────────────────────────
alter table public.course_evaluations enable row level security;

drop policy if exists eval_anon_insert on public.course_evaluations;
create policy "eval_anon_insert" on public.course_evaluations
  for insert to anon with check (true);

-- bewusst KEINE select/update/delete-Policy für anon → Lesen/Ändern gesperrt.
grant insert on public.course_evaluations to anon;

-- ── 3) Auslesen nur mit MasterToken (security definer umgeht RLS bewusst) ────
create or replace function public.argus_eval_list()
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare v jsonb;
begin
  if not public.argus_is_master() then
    raise exception 'Nur mit MasterUser-Token';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id',         e.id,
           'created_at', e.created_at,
           'course',     e.course,
           'answers',    e.answers
         ) order by e.created_at desc), '[]'::jsonb)
  into v
  from public.course_evaluations e;
  return v;
end;
$function$;
grant execute on function public.argus_eval_list() to anon;

comment on table public.course_evaluations is
  'Anonyme Kurs-Evaluationsbögen (docs/evaluation.html). anon nur INSERT; '
  'Auslesen via argus_eval_list() (MasterToken) oder SQL.';
