---
phase: 05-identitaeten-audit-stufe1
reviewed: 2026-06-27T12:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - supabase/migrations/0015_phase5_identitaeten.sql
  - supabase/migrations/0016_phase5_t4_audit.sql
  - docs/leitung-*.html
  - supabase/migrations/0014_phase414_admin_exchange_hardening.sql
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: resolved
remediation:
  via: "Migration 0017_phase5_review_fixes.sql + Leitungs-Seite doPersonRole (Commit 74e84b1); live angewendet (2× HTTP 201) + REST-getestet"
  CR-01: fixed — Rollenwechsel ist jetzt ein atomarer Server-RPC argus_master_role_change_person (in-place UPDATE, gleicher Code, kein Lockout); UI ruft nur noch diesen RPC
  WR-01: fixed — argus_master_search_usbnk escaped % und _ (ilike … escape); Suche '%' liefert 0 statt aller
  WR-02: fixed — argus_master_revoke_person normalisiert short_code (upper+strip+XXXX-XXXX)
  WR-03: fixed — 'normal' aus issue- und role-change-Whitelist entfernt (Fehler 'normal erst ab Phase 5.1'); UI bietet nur master/flz/admin
  IN-01: fixed — Revoke ist idempotent (bei bereits gesperrt: already:true, kein zweiter audit_log-Eintrag)
  IN-02: accepted — argus_exchange_person_code prüft single_use bewusst nicht (Person-Tokens sind nie single_use); dokumentiert
  IN-03: accepted — sessionRole()-Default 'master' ist Alt-Abwärtskompatibilität; RPC-Guards sind die echte Grenze (keine Eskalation)
---

> **REMEDIATION (2026-06-27):** Alle 4 Critical/Warning-Befunde behoben über
> **Migration 0017** + die atomare Rollenwechsel-UI (Commit 74e84b1), live angewendet
> (2× HTTP 201) und per REST verifiziert: Rollenwechsel atomar (flz→master ok, gleicher
> Code, kein Lockout; admin verlangt Präsidium; →normal abgewiesen), USBNK-Suche escaped
> ('%' → 0 Treffer), Revoke normalisiert + idempotent (already:true), 'normal' bis 5.1
> gesperrt. IN-02/IN-03 als bewusst akzeptiert dokumentiert (defensiv/Alt-Kompat, keine
> Eskalation — RPC-Guards sind die echte Grenze).

# Phase 05: Code Review Report

**Reviewed:** 2026-06-27
**Depth:** standard
**Files Reviewed:** 4
**Status:** needs-attention

## Summary

Phase 5 adds the server-side identity layer (is_person/usbnk/role on access_tokens), the audit_log table, argus_exchange_person_code, three Master-only RPCs (issue/revoke/search), and the Leitungs-Seite UI for all of it. The central threat model is privilege escalation and information disclosure.

Overall the implementation is structurally sound: all security-definer functions have `set search_path`, the append-only audit_log has no write grants to anon, the CR-02 guard (is_person rejection in argus_exchange_code) is correctly positioned, argus_is_master/argus_is_flz both gate on argus_token_active() for jti-Sofortsperre, and no Klarname fields exist. The FLZ branch in argus_lage correctly aggregates only anonymous counts. XSS risk in the Leitung UI is handled by the `esc()` helper throughout. No native alert/confirm/prompt calls are present.

One CRITICAL finding: the doPersonRole role-change flow in the Leitung UI is non-atomic — a failure in step 2 (new token issuance) after step 1 (revoke old token) succeeds leaves the target person permanently locked out with no automated recovery path. This is a data-integrity/availability risk for a security-critical administrative action.

Three WARNINGs: (1) argus_master_search_usbnk has no ILIKE wildcard escape, allowing callers to use `%` and `_` as wildcards beyond the intended fragment search; (2) argus_master_revoke_person does not normalize the p_short_code input (uppercase + strip spaces/dashes), creating silent no-ops when called with non-canonical formats; (3) the role-change UI hint at line 1905 lists only "master/flz/admin" as valid roles but the validation whitelist (line 1910) and the RPC also accept "normal", creating a documentation/contract inconsistency.

---

## Critical Issues

### CR-01: Non-atomic role-change leaves user locked out on partial failure

**File:** `docs/leitung-*.html:1929-1944`
**Issue:** `doPersonRole` is a two-step client-orchestrated operation: (1) call `argus_master_revoke_person` to revoke the old token, (2) call `argus_master_issue_person` to issue a new token with the new role. If step 1 succeeds and step 2 fails (network error, exception, or server error), the person is left with `revoked=true` on their old token and no new token. The jti-Sofortsperre takes effect immediately on revoke, so the person loses access instantly and cannot recover without a master manually issuing a new token and delivering the short_code out-of-band. The error message ("alter Token bereits gesperrt!") correctly warns about this state but provides no recovery mechanism in the UI. This is a critical availability risk for a security-sensitive administrative action.

**Fix:** Move the two-step logic into a new server-side security-definer RPC `argus_master_role_change_person(p_short_code text, p_new_role text, p_praesidium_id uuid, p_label text)` that executes both steps atomically in one transaction. The RPC should:
1. Guard: `argus_is_master()`
2. Load and validate target token (is_person, current role)
3. UPDATE `revoked=true` on old token
4. INSERT new token (same USBNK, new role/praesidium)
5. INSERT `audit_log` action `'person_role_change'` in a single entry (not two separate entries)
6. Return `{revoked_code: old_sc, new_code: new_sc}`

The client-side doPersonRole then becomes a single RPC call with no atomicity risk. Until this RPC exists, the UI should at minimum add a "Re-issue for this USBNK" recovery button that pre-fills the USBNK after a partial failure.

---

## Warnings

### WR-01: ILIKE wildcard characters in argus_master_search_usbnk not escaped

**File:** `supabase/migrations/0015_phase5_identitaeten.sql:581`
**Issue:** The search query is `a.usbnk ilike '%' || p_usbnk || '%'`. The `%` and `_` characters in p_usbnk are ILIKE wildcards in PostgreSQL. A caller can pass `p_usbnk = '%'` to return ALL is_person tokens, or `p_usbnk = '_'` to match any single-character USBNK. This is not SQL injection (the value is a bind parameter, not identifier interpolation), but it allows broader result sets than the "fragment search" semantic implies. The UI guard (`if(!q){ toast(...); return; }`) blocks empty input but does not strip wildcards. A direct API caller with a valid Master JWT could enumerate all person tokens with a single `p_usbnk='%'` call.

**Fix:** Escape ILIKE special characters before concatenating:
```sql
-- At the start of the function body, after the master guard:
p_usbnk := replace(replace(p_usbnk, '\', '\\'), '%', '\%');
p_usbnk := replace(p_usbnk, '_', '\_');
-- Then use: a.usbnk ilike '%' || p_usbnk || '%' escape '\'
```
Alternatively, accept that a Master seeing all tokens is not an escalation and document the behavior as intentional. But escaping is the safer default.

### WR-02: argus_master_revoke_person does not normalize p_short_code input

**File:** `supabase/migrations/0015_phase5_identitaeten.sql:513`
**Issue:** The function looks up `short_code = p_short_code` without normalizing the input. Short codes in the database are stored as `XXXX-XXXX` (uppercase, with hyphen). If a caller passes `xxxx-xxxx` (lowercase), `XXXXXXXX` (no hyphen), or `XXXX XXXX` (space instead of hyphen), the lookup fails silently with `raise exception 'Code nicht gefunden'` even though the token exists. The Leitung UI always passes the exact DB value (from search results), so this does not affect normal operation. But direct API callers may encounter confusing "not found" errors. For consistency with all other Exchange functions (which normalize via `upper(regexp_replace(...))`), the revoke RPC should normalize too.

**Fix:**
```sql
-- At the top of argus_master_revoke_person, after the master guard:
declare
  v_norm text;
begin
  if not public.argus_is_master() then raise exception 'Nur mit MasterUser-Token'; end if;
  -- Normalize input to canonical XXXX-XXXX form
  v_norm := upper(regexp_replace(p_short_code, '[\s\-]', '', 'g'));
  if length(v_norm) >= 8 then
    p_short_code := substring(v_norm,1,4) || '-' || substring(v_norm,5,4);
  end if;
  -- ... rest of function uses p_short_code ...
```

### WR-03: doPersonRole UI hint lists only three roles but validation accepts four

**File:** `docs/leitung-*.html:1903-1910`
**Issue:** Line 1905 passes the hint string `'Neue Rolle eingeben (master/flz/admin):'` to `promptModal`, but the validation at line 1910 accepts `['master','flz','admin','normal']`. A master who tries to downgrade a user to `normal` role via the role-change flow would succeed at the RPC level (server accepts `normal`) but would not see `normal` as an option in the UI hint, potentially causing confusion. More importantly, the issued form (lines 1790-1793) only exposes `master/flz/admin` in the select dropdown, so `normal` tokens cannot be issued via the standard UI path. This inconsistency between UI affordances and RPC capabilities is a latent defect — especially if the `normal` role gains field-app access in Phase 5.1.

**Fix:** Either:
(a) Add `normal` to the promptModal hint and issue-form dropdown (if normal token issuance via Leitung UI is intended for Phase 5), or
(b) Remove `normal` from the role validation whitelist in both `doPersonRole` (line 1910) and `argus_master_issue_person` (line 429 in 0015) until Phase 5.1 is explicitly in scope. This makes the code match the stated intent in D-03/D-10 ("Normale Feldnutzer bleiben bis SSO Stufe 0").

---

## Info

### IN-01: argus_master_revoke_person produces duplicate audit entries for double-revoke

**File:** `supabase/migrations/0015_phase5_identitaeten.sql:523-533`
**Issue:** The function does not check `if v_target.revoked then raise exception 'Token bereits gesperrt'; end if;` before performing the update. Calling revoke twice on the same token results in: (1) a no-op `UPDATE` (sets `revoked=true` on an already-`revoked=true` row), and (2) a second `audit_log` entry `person_revoke` for the same token. The double audit entry is misleading for forensic review.

**Fix:** Add an idempotency guard before the UPDATE:
```sql
if coalesce(v_target.revoked, false) then
  return jsonb_build_object('revoked', true, 'already_revoked', true);
end if;
```
This returns success (idempotent) without writing a duplicate audit entry.

### IN-02: argus_exchange_person_code does not check single_use/used_at

**File:** `supabase/migrations/0015_phase5_identitaeten.sql:303-325`
**Issue:** The exchange function reads `praesidium_id, is_person, usbnk, role, revoked, expires_at` but not `single_use` or `used_at`. Person tokens are issued with `single_use=false` (explicit, line 471), so this is not a functional bug. However, if a person token is manually set to `single_use=true` in the database (e.g., via a future admin operation or bootstrap script), `argus_exchange_person_code` would allow unlimited re-exchange even after first use. The analogous `argus_exchange_code` and `argus_exchange_admin_code` both check `single_use`.

**Fix:** Add consistency with other exchange functions; either document that `single_use` is intentionally ignored for person tokens (because they are credentials, not one-time codes), or add a defensive check:
```sql
-- After the expires_at check:
if coalesce(v_token.single_use, false) and v_token.used_at is not null then
  return jsonb_build_object('error', 'Ungültiger oder verbrauchter Code');
end if;
```

### IN-03: Legacy sessionStorage sessions without argusl_role key display master-level UI

**File:** `docs/leitung-*.html:535-536`
**Issue:** `sessionRole()` falls back to `'master'` when `argusl_role` is not set in sessionStorage: `return sessionStorage.getItem('argusl_role')||'master'`. Old sessions (pre-Phase 5) that persist from a browser that was not closed between deployments would not have `argusl_role` set. If such a session held a non-master JWT (e.g., a guest device JWT, though this was not the intended use of the Leitung page), `sideNav()` would render the full Master section list. All RPCs and RLS policies would still reject privileged calls — so there is no server-side escalation — but the UI would appear misleadingly as a master session. The fallback comment says "Abwärtskompatibel: Altsitzungen ohne argusl_role → 'master'", suggesting this was a deliberate choice for old master sessions that didn't store the role key; however the fallback is overly broad.

**Fix:** Narrow the fallback to only apply when a JWT is present (if there's no JWT, sessionRole is moot because render() shows the login screen):
```javascript
function sessionRole(){
  var stored = sessionStorage.getItem('argusl_role');
  if(stored) return stored;
  // Only fall back to 'master' if JWT claims confirm is_master
  // (backward compat for sessions created before argusl_role was stored)
  return 'master';
}
```
This is low priority because old sessions pre-Phase 5 were exclusively from master logins (the Leitung page only accepted master codes before). The fallback is effectively correct for all real old sessions.

---

_Reviewed: 2026-06-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
