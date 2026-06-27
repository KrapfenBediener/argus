# Phase 7 — Rollen- & Identitätsmodell · Architektur (konvergiert)

> **Status:** Lebendes Architektur-Dokument, konversationell erarbeitet 2026-06-21/22
> (Owner + Claude). Dies IST der inhaltliche Phase-7-Design-Input.
>
> **GSD-Hinweis:** Der formale Weg (`complete-milestone` → `new-milestone` →
> `discuss-phase`) ist aktuell durch **GSD-Buchführungs-Drift** blockiert (keine
> MILESTONES.md, fehlende SUMMARYs für Phasen 01/04, Milestone intern als
> v0.19.5 gelabelt, `phases.list` leer). Retroaktive GSD-Buchführung bringt
> keinen echten Mehrwert (Historie liegt in Git/CHANGELOG/STATE). Daher wird die
> Phase-7-Planung **pragmatisch** über dieses Dokument geführt.

---

## Leitprinzip: SCOPE und IDENTITÄT trennen
- **Scope** (was darf ich? welches Präsidium?) ← kommt aus der **Rolle**.
- **Identität** (wer bin ich? fürs Protokoll) ← kommt aus der **USBNK**.
- **Architektur-Invariante:** Eine Sitzung trägt IMMER `(USBNK, Rolle, Präsidiums-Scope)`.
  Über alle Ausbaustufen bleibt diese Schicht **gleich** — nur die **Quelle** der
  USBNK steigt auf. → **Kein Re-Architecting zwischen den Stufen.**

Begründung DSB/Recht (Owner-Read 2026-06-22): ARGUS läuft polizei-intern;
**personenscharfe Protokollierung ist dort Normalfall** (POLAS wird ebenso
personenscharf protokolliert). Der DSB sieht darin grundsätzlich kein Problem.
→ Die Identitäts-/Protokoll-Schicht (inkl. T4-Audit) ist damit **kein
Sonderhindernis** mehr. *(Prudenz: konkrete Rechtsgrundlage/JI-Regime bei T4-Bau
schriftlich bestätigen lassen.)*

---

## Stufenmodell (nur die USBNK-Quelle ändert sich)
| Stufe | Identitätsquelle | Authentifiziert? | Wann |
|---|---|---|---|
| **0** | geteilter Präsidiums-/Rollen-Code (+ optional Kürzel) | nein (pseudonym) | jetzt · Übung · PPF-Kurs |
| **1** | **Pro-Person-Token, USBNK-gekoppelt** (batch aus Personalbestand provisioniert) | passwort-artig (an Person gebunden) | **vor der Übergabe baubar** |
| **2** | **SSO / Geräte-Profil** (PoliPhone-Profil bzw. PC-Anmeldung liefert USBNK) | **ja, POLAS-Niveau**, kein Extra-Login | Echtbetrieb (Deployment; PTLS/BITBW) |

**Gerätelandschaft (Owner 2026-06-22):**
- **PoliPhone:** persönliches, persistentes Profil (1:1 Person; abmeldbar → andere Person). Stufe 2 liefert USBNK transparent, ohne Extra-Login.
- **PC:** Anmeldung je Sitzung mit USBNK + Passwort. Stufe 2 reitet auf dieser Sitzung mit.
- **Ziel:** KEIN separater ARGUS-Login — ARGUS nutzt die vorhandene Polizei-Sitzung.

---

## Rollen
| Rolle | Zugriff | Identität (Stufe) |
|---|---|---|
| **Normaler User** | Echtbetrieb-Präsidium **+** zugehöriges Schulungs-Präsidium (Feld-Erfassung/Verwaltung) | geteilt (S0) → pro-Person (S1/S2) |
| **FLZ-User** | FLZ-/Lageansicht **+** alles vom normalen User; präsidienübergreifend (durch Protokoll gedeckt) | dito |
| **Master-User** | alles **+** Governance-Panel **+** USBNK-/Namenssuche → Rollen erteilen/widerrufen + Protokoll-Einsicht | pro-Person (privilegiert) |
| **Präsidiums-Admin** *(= „Kurs-Host", schmal)* | NUR eigenes Präsidium: 24h-Gast-Code (+QR) ausgeben/sperren **+** eigene anonyme Lage | S0/S1, präsidiumsbegrenzt |
| **Beobachter (FLZ extern)** | read-only Lage, ein Präsidium | existiert (`is_observer`) |

**Präsidienübergreifend (Echtfall/Amtshilfe):** breiter Zugriff akzeptiert, weil
**personenscharf protokolliert** (Punkt-1-Argumentation). Präsidiums-Picker mit
zwei Reitern **„Echtbetrieb-Auswahl" / „Schulungs-Auswahl"** (harte Echt/Übung-
Trennung; in der Feld-App bereits angelegt). Im MANV muss die Auswahl **schnell**
gehen — Tempo vor Antragsweg.

---

## Was JETZT baubar ist (vor der Übergabe)
1. **Identitäts-Schicht:** Sitzung trägt `(USBNK, Rolle, Präsidiums-Scope)`.
2. **Stufe 1:** Pro-Person-USBNK-Token — **batch aus dem Personalbestand**
   provisionierbar (kein Hand-Provisioning bei 30.000+). Pro-Person-Widerruf,
   Pro-Person-Audit. **Nutzt die vorhandene Infrastruktur:** `access_tokens` +
   `jti`-**Sofortsperre** sind bereits ein Pro-Token-Register mit Echtzeit-
   Widerruf → nur `usbnk` + `role` + `scope` ergänzen.
3. **T4-Audit** (personenscharfes, append-only Protokoll) — durch POLAS-
   Argumentation freigegeben.
4. **Schema-Link Präsidium ↔ Schulungs-Zwilling** (normaler Token = beide).
5. **Übungspräsidium:** Demo-Befüllung **opt-in** + Master-Aktion „leeren" (Q2).
6. **Admin-Surface:** **rollen-adaptive Leitungs-Seite** (Weg B) statt neuer Seite
   je Rolle — eine Governance-Oberfläche, die je angemeldeter Rolle nur das Erlaubte
   zeigt. RLS bleibt die echte Grenze; UI ist Komfort.

## Erst zur Deployment-Zeit (Echtbetrieb, PTLS/BITBW)
- **Stufe-2-SSO-Connector** gegen die echte Polizei-IdP. In der Dev-Supabase nicht
  testbar → gegen eine **klare Schnittstelle** bauen, beim Aufschalten verdrahten.
  Auto-Widerruf via IdP (Polizei-Konto deaktiviert → ARGUS-Zugriff weg).

---

## Technik-Skizze: Präsidiums-Admin-Inkrement (erstes baubares Stück, PPF)
- Token-Art `is_admin` + Claim `admin_praesidium_id` + Helper
  `argus_admin_praesidium_id()` (Muster wie `is_observer`/0005).
- Exchange (erweitern oder eigener RPC) → JWT trägt `is_admin` + `admin_praesidium_id`, **nie** `is_master`.
- `jti`-Sofortsperre gilt automatisch.
- Code-Ausgabe/-Sperre als `security definer`-RPCs mit harter Prüfung:
  Ziel-Präsidium == `argus_admin_praesidium_id()` **und** Token-Art nicht privilegiert
  (nur Gast/24h; nie master/admin/observer).

## Sicherheits-Leitplanken (nicht verhandelbar)
- **Privilege-Escalation-Schutz:** Admin erzeugt/sperrt NIE master/admin/observer-Tokens.
- **REST-Negativtests Pflicht** (Muster Observer 4.12): Fremd-Präsidium, Protokolle/Fotos, Token-Eskalation = jeweils verweigert.
- Admin sieht keine Patientendaten/Protokolle/Fotos (bleibt MasterUser).

---

## OFFEN / später entscheiden
- **⏳ Stufe-1-Token ist passwort-artig** (bei Weitergabe/Diebstahl als diese USBNK
  missbrauchbar). **Lösung bewusst vertagt — „wenn die Zeit kommt" (Owner 2026-06-22).**
  Kandidaten fürs spätere Denken: kurze Gültigkeit/Rotation, Geräte-Bindung,
  zweiter Faktor, oder direkt Stufe 2 (SSO) als Ablösung.
- **Pro-Person-Widerruf:** durch Stufe 1 gelöst (einzelnen USBNK-Token sperren statt Code rotieren).
- **FLZ-Rotation:** durch geteilte/Pro-Person-Tokens + jti-Sofortsperre abgedeckt; Detailmechanik bei Bedarf.
- **Admin-Surface-UI-Details** (rollen-adaptive Leitungs-Seite) — beim Bau ausgestalten.
- **T4-Rechtsgrundlage** schriftlich (POLAS-Analogie / JI-Regime) — Prudenz.

## DSB / PTLS — Status
- **DSB:** personenscharfes Protokoll polizei-intern Normalfall (POLAS) → grundsätzlich ok (Owner-Read). T4 baubar.
- **PTLS:** offizieller Echtbetrieb (und damit Stufe-2-Aufschaltung) bleibt **extern blockiert** bis zur KI-App-Richtlinie. Stufen 0/1 + Architektur sind davon unberührt baubar.

---

## PPF-Kurs-Host
Schlicht ein **Stufe-0/1-Stück für ein Präsidium** (Präsidiums-Admin, nur Gast-Code
+ eigene Lage). Wird **nach** Finalisierung dieses Gesamtbilds als kleines erstes
Inkrement herausgezogen (Owner: „darum kümmern wir uns danach").

---

*Referenzen: `.planning/ROADMAP.md` (Phasen 7/8) · `docs/KONZEPT-POLIZEIBETRIEB.md`
(Stufenmodell MDM/SSO/USBNK) · Migrationen 0001 (Claims), 0005 (observer-Muster),
0007 (jti-Sofortsperre), 0009 (gast) · Memories: dsb-gespraech-outcome,
ptls-vibecoding-block, mdr-tacstart-accepted, ppf-kurse-evaluation, supabase-admin-workflow.*
