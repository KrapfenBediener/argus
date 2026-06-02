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

## Phase 5 — Native App für PTLS Pol (nach Polizei-BW-Entscheidung)
**Ziel:** PWA via Capacitor in native iOS-App (.ipa) umwandeln, verteilbar über den dienstlichen App-Store von PTLS Pol (MDM-Verteilung, kein öffentlicher App Store nötig). Setzt offizielle Übernahme durch Polizei BW voraus.
**Voraussetzungen:** Träger-Buy-in, IT-Sicherheitsfreigabe, DSB-Abstimmung, Apple Developer Enterprise Account (PTLS Pol).

## Phase 6 — Lageübersicht für FLZ / ILS (read-only Dashboard)
**Ziel:** Browserbasierte Lesansicht für Führungs- und Lagezentrum (FLZ) oder Integrierte Leitstelle (ILS): wie viele CCPs aktiv, wie viele Patienten je Kategorie (T1/T2/T3/T5/gPA), ohne Zugriff auf personenbezogene Daten. Anonymisierte Echtzeit-Zahlen. Anbindung an IVENA oder direkter Kanal noch zu klären.
**Voraussetzungen:** Klärung zuständige Leitstelle (FLZ vs. ILS), Datenschutz-Folgenabschätzung für Übermittlung.
