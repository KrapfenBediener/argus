# Drittanbieter-Hinweise / Third-Party Notices

Dieses Projekt (Argus) ist eine Single-File-PWA ohne Build-Pipeline und
ohne npm-Abhängigkeiten. Alle Drittanbieter-Ressourcen sind **lokal im
Repository eingebunden** (self-hosted) — zur Laufzeit erfolgen **keine
Requests an Drittanbieter-Server** (kein CDN, keine externen Font-Dienste).

---

## 1. Supabase JavaScript Client

- **Eingebunden als:** lokale Datei `vendor/supabase.js`
- **Version:** 2.108.1 (UMD-Bundle, feste Version)
- **Herkunft der Kopie:** npm-Paket `@supabase/supabase-js`,
  bezogen über jsdelivr (einmaliger Download, 2026-06-10)
- **Anbieter:** Supabase Inc.
- **Lizenz:** MIT License
  (https://github.com/supabase/supabase-js/blob/master/LICENSE)
- **Verwendung:** Backend-Client für Datenbankzugriff, Echtzeit-Sync
  und Authentifizierung über die Supabase-Plattform.

---

## 2. IBM Plex Sans & IBM Plex Mono (Schriftarten)

- **Eingebunden als:** lokale Dateien `fonts/*.woff2`
  (Sans 400/500/600, Mono 500/600; latin-Subset)
- **Herkunft der Kopie:** Google Fonts (einmaliger Download der
  woff2-Dateien; keine Laufzeit-Verbindung zu Google-Servern)
- **Anbieter:** IBM Corp.
- **Lizenz:** SIL Open Font License 1.1
  (https://scripts.sil.org/OFL)
- **Verwendung:** Primäre App-Schriftart für UI-Text und
  Monospace-Darstellungen (Patientennummern, Codes).

---

Alle übrigen Inhalte sind First-Party-Code von Gabor Szeman
und unterliegen der proprietären Lizenz (siehe LICENSE).
