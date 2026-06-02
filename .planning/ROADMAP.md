# CCP-App Roadmap

## Phase 0 — Repo-Struktur & Offline-Hülle
**Ziel:** Saubere Projektstruktur, HTML als Single-File mit Service Worker, offline startbar.

## Phase 1 — Supabase-Backend & Speicherschicht-Tausch
**Ziel:** Alle Daten laufen über Supabase statt localStorage. Echtzeit-Sync zwischen Geräten. Offline-Queue.

## Phase 2 — Join-Flow & Authentifizierung
**Ziel:** Kürzel → CCP-Auswahl → QR/Code-Beitritt. Device-Token. MasterMedic automatisch bei Eröffnung.

## Phase 3 — Mehrgeräte-Features verdrahten
**Ziel:** Echte Patienten-Sperre (soft lock, 30s), echte MasterMedic-Rolle, echtes CCP-Zusammenführen (kein Demo-Modus mehr).

## Phase 4 — Fotos & Storage
**Ziel:** Fotos in Supabase Storage, CCP-scoped, offline-Queue für Upload.

## Phase 5 — Closed Beta vorbereiten
**Ziel:** Datenschutz-Checkliste, HTTPS-Deployment, Kurzanleitung, Feldtest.

## Phase 6 — Capacitor-Wrapper (nach Beta)
**Ziel:** Native iOS-App aus der PWA, MDM-verteilbar für Polizei BW.
