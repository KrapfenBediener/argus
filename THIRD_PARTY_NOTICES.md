# Drittanbieter-Hinweise / Third-Party Notices

Dieses Projekt (Argus) ist eine Single-File-PWA ohne Build-Pipeline und
ohne npm-Abhängigkeiten in der Web-App selbst. Alle Drittanbieter-Ressourcen
der Web-App sind **lokal im Repository eingebunden** (self-hosted) — zur
Laufzeit erfolgen **keine Requests an Drittanbieter-Server** (kein CDN,
keine externen Font-Dienste). Die optionale iOS-Hülle (`native/`) bezieht
Capacitor über npm (siehe Abschnitt 4).

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

## 3. qrcode-generator (QR-Code-Erzeugung)

- **Eingebunden als:** kompakter, unveränderter Kern inline in der
  Leitungs-Seite (`docs/leitung-*.html`); nicht in der Feld-App
  (`index.html`)
- **Autor:** Kazuhiko Arase
- **Quelle:** https://github.com/kazuhikoarase/qrcode-generator
- **Lizenz:** MIT License (Copyright (c) 2009 Kazuhiko Arase)
- **Verwendung:** Darstellung von Zugangscodes als scannbarer QR-Code
  (reine Client-Berechnung, keine Netz-Requests).

---

## 4. Capacitor (iOS-Hülle)

- **Eingebunden als:** npm-Abhängigkeiten in `native/package.json`
  (nur für die native iOS-Hülle; die Web-App im Repo-Stamm bleibt
  buildfrei)
- **Pakete und Versionen:**
  - `@capacitor/core` 8.5.3
  - `@capacitor/cli` 8.5.3
  - `@capacitor/ios` 8.5.3
  - `@capacitor/app` 8.1.2
- **Anbieter:** Drifty Co. (Ionic) — Copyright (c) 2017-present Drifty Co.
  für `core`, `cli`, `ios`; Copyright 2020-present Ionic für `app`
- **Lizenz:** MIT License (LICENSE-Datei des jeweiligen npm-Pakets;
  Repository: https://github.com/ionic-team/capacitor)
- **Verwendung:** Laufzeit-Brücke zwischen der WebView und iOS; verpackt
  die unveränderte Web-App als iOS-App.

---

Alle übrigen Inhalte sind First-Party-Code von Gabor Szeman
und unterliegen der proprietären Lizenz (siehe LICENSE).
