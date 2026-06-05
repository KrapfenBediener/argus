-- © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung.
-- ============================================================================
-- ARGUS — Basis-Schema (Phasen 1–3)
-- ============================================================================
-- Reproduzierbarer Grundzustand der Datenbank: Tabellen, Constraints, Indizes,
-- Grants, RLS-Aktivierung. Aus dem Live-Projekt sehuosjyjmrpzcqrelej extrahiert.
--
-- Reihenfolge zum Aufbau eines frischen Projekts:
--   1) Dieses Skript (0000_base_schema.sql)
--   2) 0001_phase4_jwt_rls.sql  (JWT-RPC, Claim-Funktionen, RLS-Policies, Lockdown)
--
-- Danach: Vault-Secret 'argus_jwt_secret' anlegen, Präsidien + Codes erzeugen
-- (siehe docs/PROD-SETUP.md).
-- ============================================================================

-- ── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pgcrypto  with schema extensions;
create extension if not exists pgjwt     with schema extensions;
-- supabase_vault ist von Supabase verwaltet (Vault-Secrets), nicht hier anlegen.

-- ── Tabellen (in FK-Reihenfolge: praesidien → ccps → patients/checklists/tokens) ──

create table if not exists public.praesidien (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  created_at  timestamptz default now()
);

create table if not exists public.ccps (
  id                 uuid primary key default uuid_generate_v4(),
  kennung            text not null default 'A',
  ort                text default ''::text,
  master_medic       text default ''::text,
  merged             boolean default false,
  created_at         timestamptz default now(),
  updated_at         timestamptz default now(),
  join_token         text unique,
  praesidium_id      uuid references public.praesidien(id),
  merge_group_id     uuid,
  merge_request_from uuid,
  merge_request_at   bigint,
  closed_at          bigint
);
create index if not exists ccps_merge_group_idx on public.ccps using btree (merge_group_id);

create table if not exists public.patients (
  id          text primary key,
  ccp_id      uuid references public.ccps(id) on delete cascade,
  num         integer not null default 1,
  ccp         text not null default 'A'::text,
  cat         text not null default 'T3'::text,
  status      text not null default 'active'::text,
  prio        boolean default false,
  ready       boolean default false,
  tq_start    bigint,
  created     bigint not null default 0,
  last_triage bigint not null default 0,
  updated     bigint not null default 0,
  name        text default ''::text,
  age         text default ''::text,
  gender      text default ''::text,
  allergies   text default ''::text,
  pup_re      text default ''::text,
  pup_li      text default ''::text,
  vit         jsonb default '{"af": "", "hf": "", "rr": "", "avpu": "", "pain": "", "spo2": ""}'::jsonb,
  tx          jsonb default '{}'::jsonb,
  inj         jsonb default '[]'::jsonb,
  moi         text default ''::text,
  injury      text default ''::text,
  fr          text default ''::text,
  notes       text default ''::text,
  "by"        text default ''::text,
  photo       text,
  locked_by   text,
  locked_at   bigint
);

create table if not exists public.checklists (
  id         uuid primary key default uuid_generate_v4(),
  ccp_id     uuid references public.ccps(id) on delete cascade,
  data       jsonb default '{"hdr": {}, "items": {}}'::jsonb,
  updated_at timestamptz default now()
);

create table if not exists public.access_tokens (
  token         text primary key,
  praesidium_id uuid references public.praesidien(id),
  is_master     boolean default false,
  label         text default ''::text,
  created_at    timestamptz default now(),
  short_code    text unique,
  temporary     boolean default false,
  ttl_hours     integer,
  single_use    boolean default false,
  used_at       bigint     -- JS-Millisekunden (Date.now()), NICHT timestamptz!
);

-- ── Grants (RLS schränkt die Zeilen ein; siehe 0001) ─────────────────────────
grant select, insert, update, delete on public.patients   to anon;
grant select, insert, update, delete on public.ccps        to anon;
grant select, insert, update, delete on public.checklists  to anon;
grant select, insert, update         on public.access_tokens to anon;  -- kein DELETE
grant select                          on public.praesidien   to anon;

-- ── RLS aktivieren ───────────────────────────────────────────────────────────
alter table public.praesidien    enable row level security;
alter table public.ccps          enable row level security;
alter table public.patients      enable row level security;
alter table public.checklists    enable row level security;
alter table public.access_tokens enable row level security;

-- praesidien: ohne JWT lesbar (Freischalt-Screen listet alle Präsidien; nur id+name).
drop policy if exists anon_read on public.praesidien;
create policy "anon_read" on public.praesidien for select to anon using (true);

-- Policies für patients / ccps / checklists / access_tokens + die JWT-Funktionen
-- und der Token-Exchange-RPC: siehe 0001_phase4_jwt_rls.sql.
