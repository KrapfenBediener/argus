# CCP-App – Projektkontext

## Vision
Digitales Echtzeit-Koordinierungswerkzeug für den CCP (Casualty Collection Point) bei MANV-/LebEL-Lagen der Polizei Baden-Württemberg. Ersetzt Stift-und-Papier-Sichtung durch eine mehrgeräte-fähige, offline-robuste PWA mit Cloud-Backend.

## Status
- Baseline: `CCP_App_Closed_Beta_V1.html` — einsatzerprobt (LebEL-Übung 2026-06-02)
- Ziel: Closed Beta mit 5–8 Geräten, danach Präsentation Polizei BW

## Architektur-Entscheidungen (final)

| Thema | Entscheidung | Begründung |
|---|---|---|
| Plattform | PWA (Vanilla JS) → Capacitor für Polizei-BW-Dienst | Baseline funktioniert heute, kein UI-Rewrite |
| Backend | Supabase EU (Frankfurt) für Beta | Managed, EU-Daten, Echtzeit, RLS, austauschbar |
| Auth | Device-Token + Kürzel + 6-stelliger Join-Code / QR | Kein Login, einhändig, Stressbedienbar |
| Offline | IndexedDB-Queue + Service Worker + 3,5s-Fallback | MUSS funktionieren — Mobilfunk unzuverlässig |
| Fotos | Supabase Storage EU, CCP-scoped, offline-Queue | Müssen für alle Geräte im CCP sichtbar sein |
| Datenlöschung | 24h nach CCP-Schließung automatisch | DSGVO Art. 9, vor BW-Einsatz DSB bestätigen |
| Build-Chain | Keine — CDN für Supabase-Client | Einfachheit, keine Abhängigkeiten |

## Rahmenbedingungen (nicht verhandelbar)
- Dienstliche iPhones Polizei BW: kein Hotspot (weder erstellen noch nutzen)
- Jedes Gerät nutzt unabhängig Mobilfunk
- Bedienung mit Handschuhen, einhändig, unter Stress
- Keine nativen alert/confirm/prompt — PWA-Vollbild deaktiviert diese
- Pseudonymität: Nummern als Standard, Klarnamen optional
- Maximal 4 gleichzeitige CCPs (real: meistens 1–2)

## Compliance (vor offiziellem BW-Einsatz)
- DSGVO Art. 9 + LDSG BW: Abstimmung mit DSB PP Karlsruhe nötig
- MDR-Einstufung tacSTART klären (Entscheidungsunterstützung)
- Org-Verankerung: Träger-Buy-in vor produktivem Mehrbenutzerbetrieb

## Team
- Entwicklung: Einzelperson + Claude Code (bis Beta)
- Zielorganisation: Polizei BW (PP Karlsruhe als erster Ansprechpartner)
