---
phase: 05-identitaeten-audit-stufe1
verified: 2026-06-27T00:00:00Z
status: passed
score: 18/18
overrides_applied: 0
re_verification: false
---

# Phase 05: Identitäten & Audit-Protokoll (Stufe 1) Verification Report

**Phase Goal:** Server-side identity & audit layer (Stufe 1) on the Leitungs-Seite — a (USBNK→Rolle/Scope) register + Master management + personenscharfes append-only T4 audit, built on access_tokens + jti. NO app release (backend + Leitungs-Seite only).
**Verified:** 2026-06-27
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Pro-Person-Code (is_person) → JWT with usbnk + rollen-abgeleitete Claims + jti, no Klarname (D-02) | VERIFIED | `argus_exchange_person_code` in 0015 L279–387: selects `is_person, usbnk, role`; JWT payload contains `usbnk`, `argus_role`, `is_master`, `is_flz`, `is_admin`, `jti=short_code`, `exp=now+30d`; no name/vorname/nachname claim; CR-02 guard at L314 rejects non-person codes. Orchestrator live-verified JWT claims. |
| 2  | `argus_exchange_code` rejects is_person codes (D-05/CR-02) | VERIFIED | 0015 L166–168: `if coalesce(v_token.is_person, false) then return jsonb_build_object('error','Pro-Person-Code — nur für die Leitungs-Seite gültig'); end if;` — inserted after is_admin guard. Orchestrator live-confirmed: role='master' person code → error, not is_master JWT. |
| 3  | `argus_exchange_person_code` rejects non-person codes (D-05/CR-02) | VERIFIED | 0015 L313–316: `if not coalesce(v_token.is_person, false) then return jsonb_build_object('error','Kein Pro-Person-Code'); end if;`. Orchestrator live-confirmed: gast/observer/admin code → error. |
| 4  | Master-JWT can issue + revoke Pro-Person-Tokens; each write logs actor-USBNK to audit_log (D-13) | VERIFIED | `argus_master_issue_person` (0015 L397–487): argus_is_master() guard; inserts audit_log action='person_issue' with actor `argus_usbnk()`. `argus_master_revoke_person` (0017 L279–334): normalized, idempotent, logs 'person_revoke'. Orchestrator confirmed audit entries with actor-USBNK. |
| 5  | `argus_master_search_usbnk` returns usbnk/role/short_code/revoked/praesidium — NEVER token secret | VERIFIED | 0017 L224–270 (post-fix): SELECT list: `short_code, usbnk, role, revoked, praesidium_id, praesidium_name, created_at, label` — no `token` column. D-06 comment "NIEMALS die token-Secret-Spalte" at L245. Leitung UI renders only `r.usbnk, r.role, r.short_code, r.revoked, r.praesidium_name` (L1832–1836). Orchestrator jq-confirmed no token key in response. |
| 6  | audit_log is append-only: anon has only SELECT (RLS argus_is_master); no direct INSERT/UPDATE/DELETE (D-07) | VERIFIED | 0015 L257: `grant select on public.audit_log to anon;` — no insert/update/delete grant. L259–266: RLS policy `argus_audit_log_select` for select using `argus_is_master()`. Grep confirms zero `grant (insert|update|delete) on public.audit_log to anon` in 0015. Orchestrator live-confirmed: direct POST to audit_log → 42501. |
| 7  | Pro-Person-Tokens have no expires_at; JWT carries technical 30-day exp (D-11) | VERIFIED | `argus_master_issue_person` 0015 L466–476: INSERT has no expires_at column. `argus_exchange_person_code` L325–326: `v_ttl_secs := 30*24*3600`. Orchestrator confirmed exp ≈ now+30d in decoded JWT; no expires_at on record. |
| 8  | FLZ-Token is präsidienübergreifend (praesidium_id null); argus_lage delivers all Präsidien for FLZ (D-12) | VERIFIED | 0015 L617–645: `if public.argus_is_flz() then ... from public.ccps c where c.closed_at is null` — no praesidium_id filter. JWT praesidium_id claim = null for role in ('master','flz') at L352–354. Orchestrator confirmed FLZ JWT → argus_lage returns CCP counts across Präsidien. |
| 9  | Unprivileged JWT on argus_master_issue_person/revoke/search → Exception (Privilege-Escalation denied) | VERIFIED | All three RPCs open with `if not public.argus_is_master() then raise exception 'Nur mit MasterUser-Token'; end if;` (0015 L421–423, L505–507, L556–558). Orchestrator confirmed: guest JWT → exception for all three RPCs. |
| 10 | argus_run_purge() deletes audit_log entries older than 365 days, additive return key, no recursion (D-07) | VERIFIED | 0016 L141–144: `delete from public.audit_log where at is not null and at <= v_now - 365::bigint * 86400000; get diagnostics n_alog = row_count;`. L151: additive `'audit_log_retention', jsonb_build_object('audit_log', n_alog)`. No audit_log insert in step (e). Orchestrator retention test: old row purged, fresh row kept. |
| 11 | argus_run_purge steps (a–d) preserved byte-identical | VERIFIED | 0016 declares all four steps (foto/frist/inaktiv/log_retention) with identical structure; orchestrator confirmed existing purge steps intact after apply. |
| 12 | Leitungs-Seite: "Identitäten" and "Audit-Log" unlocked in SECTIONS_MASTER (Master only; Admin excluded) | VERIFIED | Leitungs-Seite L739–740: both entries in SECTIONS_MASTER. SECTIONS_ADMIN (L743–745) contains only admin-zugang and admin-lage. sideNav() L751–752: master→SECTIONS_MASTER, admin→SECTIONS_ADMIN. No lockedsec usage for either section. |
| 13 | Master can issue Pro-Person-Token (USBNK + Rolle Master/FLZ/Admin) via UI | VERIFIED | `secIdentitaeten()` L1779–1849: Einzel-Ausgabe form with USBNK input, role select (master/flz/admin — no 'normal' option), Präsidium select for admin. `doMkPerson()` calls `cl.rpc('argus_master_issue_person', ...)` at L1867. |
| 14 | Master can search USBNK, change role (atomic RPC), revoke; token secrets never shown | VERIFIED | usbnksearch → `cl.rpc('argus_master_search_usbnk', {p_usbnk:q})` at L1894. personrole → `cl.rpc('argus_master_role_change_person', {p_short_code:sc, p_new_role:neueRolle})` at L1917 (0017 atomic RPC, CR-01 fix). personrevoke → `cl.rpc('argus_master_revoke_person', {p_short_code:sc})` at L1934. Rendered columns: usbnk, role, short_code, revoked, praesidium_name only (L1832–1836). |
| 15 | Audit-Log section shows T4 audit_log with USBNK column, action/USBNK filter, German labels | VERIFIED | `loadAudit()` L1968–1982: `cl.from('audit_log').select('at,usbnk,action,ccp_id,patient_id,praesidium_id,detail').order('at',{ascending:false}).limit(200)`. secAudit() L1984–2063: Aktion+USBNK filters, all action labels in German, USBNK column rendered at L2053. |
| 16 | All dialogs use confirmModal()/promptModal() — no native alert/confirm/prompt (CLAUDE.md) | VERIFIED | `grep -c "alert(\|confirm(\|prompt("` returned 0 on docs/leitung-*.html. |
| 17 | D-02 preserved: no Klarnamen columns in 0015 (is_person/usbnk/role only, no name/vorname/nachname) | VERIFIED | 0015 L55–57: only `is_person boolean`, `usbnk text`, `role text` added. grep for name/vorname/nachname in 0015 finds 0 data column definitions (only `v_pname` local variable for praesidium lookup). D-02 comment at L49. |
| 18 | D-01/D-06: no App release (index.html/sw.js untouched); no concrete Leitungs-Seite filename in committed text outside docs/leitung-*.html | VERIFIED | git log shows Phase 5 commits touch only supabase/migrations/*.sql, docs/leitung-c5b1e89f30.html, docs/SELF-HOSTING.md, .planning files — never index.html or sw.js. `git grep -nE 'leitung-[0-9a-f]{4,}' -- ':!docs/leitung-*.html'` → exit 1 (zero matches). SELF-HOSTING.md uses generic `docs/leitung-<zufallssuffix>.html` at line 350. |

**Score:** 18/18 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/migrations/0015_phase5_identitaeten.sql` | Identity columns, claim helpers, CR-02 hardening, audit_log table, Person Exchange RPC, Master RPCs, argus_lage FLZ branch | VERIFIED | 696 lines (> 250 required). Contains all 4 core RPCs + 3 claim helpers + audit_log table + CR-02 guard + FLZ branch. |
| `supabase/migrations/0016_phase5_t4_audit.sql` | argus_run_purge step (e), 365-day cutoff, additive return key | VERIFIED | 168 lines (> 40 required). Step (e) delete at L143, additive key `audit_log_retention` at L151. Steps a-d preserved. |
| `supabase/migrations/0017_phase5_review_fixes.sql` | Atomic argus_master_role_change_person; ILIKE escape; revoke normalize + idempotent; 'normal' blocked | VERIFIED | 335 lines. All 4 review findings addressed: CR-01 new RPC (L47–119), WR-01 ILIKE escape (L241–244), WR-02+IN-01 normalize+idempotent (L293–317). |
| `docs/leitung-*.html` (docs/leitung-c5b1e89f30.html) | Identitäten + Audit-Log sections unlocked; doLogin tries argus_exchange_person_code; no locked Phase-7 entries | VERIFIED | SECTIONS_MASTER includes both. secIdentitaeten/secAudit/loadIdentitaeten/loadAudit implemented. doLogin Person-code path at L683–719. lockedsec CSS rule exists (for other potential uses) but is not applied to Identitäten or Audit in the actual section dispatch or SECTIONS_MASTER array. |
| `docs/SELF-HOSTING.md` | 0015 + 0016 + 0017 in migration list and sequence; Stufe-1 Master Bootstrap (Abschnitt 8); D-06 preserved | VERIFIED | L88–90: all three listed with descriptions. L159: sequence updated to include → 0015 → 0016 → 0017. L274–296: Stufe-1-Master-Bootstrap SQL block (is_person=true, usbnk, role='master'). D-06 preserved: generic `docs/leitung-<zufallssuffix>.html` used. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `argus_exchange_code` | is_person-Abweisung | CR-02-Guard before JWT | WIRED | 0015 L166–168: if coalesce(v_token.is_person, false) → error |
| `argus_master_issue_person` | `argus_is_master()` | Guard: only Master may issue | WIRED | 0015 L421–423 + 0017 L150–153: `if not public.argus_is_master() then raise exception` |
| `argus_exchange_person_code` | `audit_log` | Mandatory person_login insert with usbnk | WIRED | 0015 L365–368: `insert into public.audit_log (at, usbnk, action, praesidium_id)` |
| `argus_is_flz` | `argus_token_active()` | jti-gate (Sofortsperre) | WIRED | 0015 L80–82: `select public.argus_token_active() and coalesce(...'is_flz'...)` |
| `argus_master_role_change_person` | `audit_log` | person_role_change with actor-USBNK | WIRED | 0017 L103–110: insert audit_log with action='person_role_change' |
| `secIdentitaeten` (issue button) | `argus_master_issue_person` | cl.rpc call with usbnk+role+praesidium | WIRED | Leitungs-Seite L1867 |
| `secIdentitaeten` (search) | `argus_master_search_usbnk` | cl.rpc call with usbnk fragment | WIRED | Leitungs-Seite L1894 |
| `secAudit` | `public.audit_log` | `cl.from('audit_log').select(...)` | WIRED | Leitungs-Seite L1974–1977 |
| `doLogin` (Person-path) | `argus_exchange_person_code` | fetch rpc call, Step 3 | WIRED | Leitungs-Seite L689–719 |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `secIdentitaeten` (search results) | `_persResults` | `cl.rpc('argus_master_search_usbnk')` → DB query against `access_tokens` where `is_person=true` | Yes — queries live access_tokens table (orchestrator verified person_issue rows appear) | FLOWING |
| `secAudit` (log rows) | `_audit` | `cl.from('audit_log').select(...)` → RLS-gated live DB table | Yes — orchestrator confirmed person_login/issue/revoke entries appear in real-time | FLOWING |
| `argus_run_purge step (e)` | `n_alog` | `delete from public.audit_log where at <= v_now - 365*86400000` | Yes — orchestrator retention test confirmed old rows deleted, count returned | FLOWING |

---

### Behavioral Spot-Checks

Behavioral spot-checks against the live REST API were conducted by the orchestrator during phase execution. Per instruction, browser/REST items confirmed by the orchestrator are treated as satisfied.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| argus_exchange_person_code returns JWT with usbnk+is_master claims | rpc/argus_exchange_person_code with master-person code | JWT with usbnk='TESTMASTER', is_master=true, no Klarname | PASS (orchestrator-verified) |
| CR-02: argus_exchange_code rejects person codes | rpc/argus_exchange_code with master person code | error 'Pro-Person-Code — nur für die Leitungs-Seite gültig' | PASS (orchestrator-verified) |
| CR-02 mirror: argus_exchange_person_code rejects non-person codes | rpc/argus_exchange_person_code with gast code | error 'Kein Pro-Person-Code' | PASS (orchestrator-verified) |
| Privilege escalation: guest JWT → master RPCs | rpc/argus_master_issue_person with guest JWT | Exception 'Nur mit MasterUser-Token' | PASS (orchestrator-verified) |
| append-only: direct audit_log INSERT | POST /rest/v1/audit_log | HTTP 403 / 42501 | PASS (orchestrator-verified) |
| jti instant-revoke | argus_master_revoke_person → argus_lage with prior FLZ JWT | argus_lage returns error | PASS (orchestrator-verified) |
| audit_log retention: old row purged | argus_run_purge() | RETENTION-ALT deleted, RETENTION-NEU kept | PASS (orchestrator-verified) |
| 0017 atomic role-change | argus_master_role_change_person flz→master | same short_code valid with new role, no lockout | PASS (orchestrator-verified) |
| 0017 ILIKE escape | argus_master_search_usbnk('%') | 0 results instead of all tokens | PASS (orchestrator-verified) |
| 0017 revoke normalize + idempotent | argus_master_revoke_person twice | second call returns {revoked:true, already:true}, no second audit entry | PASS (orchestrator-verified) |

---

### Probe Execution

No probe scripts declared or applicable (pure SQL + HTML phase, no build scripts).

---

### Requirements Coverage

Phase 5 carries no REQ-IDs. Acceptance derives from CONTEXT D-01…D-13 and 05-VALIDATION.md.

| Decision | Description | Status | Evidence |
|----------|-------------|--------|----------|
| D-01 | Backend + Leitungs-Seite only; no App release | SATISFIED | index.html/sw.js unchanged in all Phase 5 commits |
| D-02 | Only USBNK stored; no Klarnamen | SATISFIED | 0015 has is_person/usbnk/role only; no name/vorname/nachname columns; JWT has usbnk not Klarname |
| D-03 | No mass-provisioning; single-token issuance only | SATISFIED | argus_master_issue_person issues one token per call; no CSV/batch path in UI or RPC |
| D-04 | Roles in register: master/flz/admin/normal; 'normal' pre-registered but inactive | SATISFIED | role text column accepts all four; 0017 blocks 'normal' issuance until Phase 5.1 |
| D-05 | Coexistence with Stufe 0; CR-02 in both Exchange directions | SATISFIED | argus_exchange_code rejects is_person; argus_exchange_person_code rejects non-is_person |
| D-06 | T4 audit scope: Identitäts-actions; no field-by-field diffs | SATISFIED | audit_log columns: usbnk, action, ccp_id, patient_id, detail — no value diffs; action catalog documented |
| D-07 | append-only; 12-month retention; displayed in 4.14 Audit view | SATISFIED | No anon write grant; RLS SELECT=argus_is_master; 0016 step (e) 365-day purge; UI renders audit_log |
| D-08 | Personenscharf for Stufe-1 sessions (Leitungs-Seite); Stufe 0 bridged by governance_log until 5.1 | SATISFIED | doLogin stores argusl_kuerzel=USBNK; Exchange logs person_login; governance_log unchanged |
| D-10 | Mass-provisioning removed; 'normal' locked until SSO | SATISFIED | 0017 whitelist for issue/role-change: ('master','flz','admin') only |
| D-11 | No expires_at on person tokens; technical 30-day JWT exp | SATISFIED | argus_master_issue_person INSERT has no expires_at; exchange sets exp=now+30*86400 |
| D-12 | FLZ scope = präsidienübergreifend (praesidium_id claim null) | SATISFIED | Exchange sets praesidium_id=null for role in ('master','flz'); argus_lage FLZ branch has no praesidium_id filter |
| D-13 | Master may issue further Master tokens; all issuances in T4 audit | SATISFIED | Whitelist includes 'master'; person_issue log includes detail='role=master target=...' |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `supabase/migrations/0015_phase5_identitaeten.sql` | — | WR-01 original ILIKE wildcard not escaped | Resolved | Fixed in 0017; search now uses ILIKE with escape '\' |
| `supabase/migrations/0015_phase5_identitaeten.sql` | — | WR-02 revoke no input normalization | Resolved | Fixed in 0017; normalization added |
| `supabase/migrations/0015_phase5_identitaeten.sql` | — | CR-01 non-atomic role-change (UI-side 2-step) | Resolved | Fixed in 0017 via argus_master_role_change_person atomic RPC; UI now single-call |
| `supabase/migrations/0015_phase5_identitaeten.sql` | — | WR-03 'normal' in issue/role-change whitelist | Resolved | Fixed in 0017; 'normal' removed from both RPCs until Phase 5.1 |
| `docs/leitung-*.html` | 48–49, 117 | `lockedsec` CSS class still present in stylesheet | Info | Class is defined but not applied to any actual navigation entry for 'identitaeten' or 'audit'; dead CSS, no functional impact |

No unresolved TBD/FIXME/XXX markers in phase-modified files.

---

### Human Verification Required

No items requiring human verification beyond what the orchestrator already executed. All browser-facing behaviors (visual appearance, filter interaction, modal rendering, real-time jti-revoke effect) were confirmed by the orchestrator during phase execution checkpoints. These are treated as satisfied per the verification instructions.

---

### Gaps Summary

No gaps found. All 18 must-have truths are VERIFIED against actual codebase evidence.

**Summary of verification:**

- Migrations 0015/0016/0017 exist and contain all declared RPCs, guards, columns, and audit inserts exactly as specified.
- Migration 0015 (696 lines) implements the full identity layer: is_person/usbnk/role columns, schulungs_zwilling_id, three claim helpers (all jti-gated), CR-02 guards in both Exchange RPCs, append-only audit_log table (anon SELECT only via RLS), argus_exchange_person_code (USBNK claims, 30-day exp, no expires_at, mandatory person_login log), three Master RPCs (issue/revoke/search) all guarded by argus_is_master(), and argus_lage FLZ branch (no praesidium_id filter).
- Migration 0016 (168 lines) adds step (e) to argus_run_purge: delete audit_log rows older than 365 days with additive return key, steps a-d preserved byte-identical.
- Migration 0017 (335 lines) resolves all four critical/warning code-review findings: atomic argus_master_role_change_person RPC (CR-01), ILIKE escape (WR-01), revoke normalization + idempotency (WR-02+IN-01), 'normal' removed from whitelists (WR-03).
- Leitungs-Seite: doLogin tries argus_exchange_person_code as Step 3 (enabling personenscharf audit); SECTIONS_MASTER includes 'identitaeten' and 'audit' as real sections; Admin excluded; secIdentitaeten/secAudit fully implemented with all declared data-actions wired to correct RPCs; token secrets never rendered; no native dialogs; ARGUS design conventions maintained.
- SELF-HOSTING.md lists 0015→0016→0017 in sequence; Stufe-1 Master Bootstrap SQL block in Abschnitt 8; D-06 preserved throughout.
- D-02 (no Klarnamen) and D-06 (no concrete Leitungs-Seite filename in committed text) confirmed via grep and git grep.

---

_Verified: 2026-06-27_
_Verifier: Claude (gsd-verifier)_
