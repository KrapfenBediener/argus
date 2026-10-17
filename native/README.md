# native/ — Capacitor-iOS-Hülle für ARGUS

Dieses Unterprojekt packt die **unveränderte** Single-File-Web-App aus dem Repo-Stamm (`index.html`, `config.js`, `vendor/`, `fonts/`, Icons, Update-Sheets) in eine native iOS-App (Capacitor 8, SPM). Die Web-App bleibt buildfrei und wird weiterhin als PWA über GitHub Pages ausgeliefert; die Hülle bündelt dieselben Dateien lokal (Local-first, kein `server.url`).

npm-Skripte (in `native/` ausführen):
- `npm run sync` — kopiert die gelisteten Dateien (PRECACHE_URLS, Update-Sheets, Fonts, Icons) nach `www/` und schreibt `www/native-version.json`.
- `npm run version:set` / `npm run version:bump` — schreibt `APP_VERSION` und die Build-Nummer (`version.json`) in `ios/App/App.xcodeproj/project.pbxproj`; `--bump` erhöht die Build-Nummer vorher um 1.
- `npm run ios:sync` — `sync` + `cap sync ios` (kopiert `www/` nach `ios/App/App/public`, verwaltet `CapApp-SPM/Package.swift`).
- `npm run ios:open` / `npm run ios:doctor` — Xcode öffnen bzw. Umgebung prüfen (beides braucht ein installiertes Xcode).

Vollständige Anleitung (Simulator, eigenes iPhone, TestFlight): `docs/NATIVE-HUELLE.md`.
