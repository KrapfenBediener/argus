# Phase 0: Repo-Struktur & Offline-Hülle — Kontext

**Erhoben:** 2026-06-02  
**Status:** Bereit zur Planung  
**Quelle:** Vollständige Analyse der HTML-Baseline + Architektur-Dokumente

---

## Phase-Abgrenzung

Phase 0 liefert die **saubere Projektbasis**, aus der alle weiteren Phasen aufbauen:
- Die bestehende HTML-Datei (`CCP_App_Closed_Beta_V1.html`) wird als Referenz eingefroren und bleibt **unverändert**.
- Die aktive Entwicklungsversion (`index.html`) ist eine 1:1-Kopie — identisches Verhalten, identisches Aussehen.
- Ein Service Worker macht die App-Hülle offline verfügbar (Start vom Home-Bildschirm auch ohne Netz).
- Die Speicher-Schicht bleibt **noch** auf localStorage — kein Backend in Phase 0.
- Die Supabase-Client-Bibliothek wird per CDN eingebunden (noch nicht verdrahtet, nur bereitgestellt).

---

## Entscheidungen (unveränderlich)

### Dateistruktur
- **Single-File bleibt**: Die App bleibt eine einzige `index.html` (kein Framework, kein Build). Diese Entscheidung ist final für die Beta.
- **Legacy eingefroren**: `legacy/CCP_App_Closed_Beta_V1.html` darf nach Phase 0 nie verändert werden — sie ist die Referenz.
- **Service Worker**: Separate Datei `sw.js` im Root. Cacht: `index.html`, alle eingebundenen Fonts/Icons (da inline Base64 — kein Aufwand), Shell-Assets.

### Technische Baseline
- **Kein Build-Schritt**: Kein npm, kein Vite, kein Webpack. `python3 -m http.server` reicht für lokale Entwicklung.
- **Supabase per CDN**: `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/...">` einbinden, aber noch nicht initialisieren. Macht Phase 1 zum einfachen Austausch.
- **Manifest & Icons**: Bereits in der HTML als Base64 inline — kein Änderungsbedarf.
- **PWA-Vollbild**: `apple-mobile-web-app-capable` bereits gesetzt — bleibt.

### Was Phase 0 NICHT tut
- Kein Backend, kein Supabase-Konto anlegen (Phase 1).
- Keine UI-Änderungen.
- Keine neuen Features.
- Keine Authentifizierung.

---

## Canonical References
- `CCP_App_Closed_Beta_V1.html` — Die Referenz. Jede Änderung in `index.html` wird gegen sie gemessen.
- `docs/ARCHITECTURE.md` — Stack-Entscheidung, Service-Worker-Anforderungen.
- `docs/ROADMAP.md` — Phase-0-Aufgaben.
- `CLAUDE.md` — Leitprinzipien (kein alert/confirm, offline-fähig, keine Storage-Annahmen brechen).
