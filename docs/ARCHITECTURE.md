# Architektur

## 1. Heute: Single-File-PWA, local-first

Die bestehende App ist eine einzelne HTML-Datei (HTML + CSS + Vanilla-JS, keine Build-Kette, keine externen Laufzeit-Abhängigkeiten außer einer Web-Schriftart). Sie ist als PWA auf dem iPhone-Homescreen installierbar (Apple-Meta-Tags, Icon, Manifest).

Die Datenhaltung läuft vollständig über eine **abstrahierte, asynchrone Speicher-Schicht** (`sList/sGet/sSet/sDel`, `getOperator/setOperatorStore`, `loadMeta/setMasterMedic`, `loadPatients/savePatient/addPatient`). Implementiert ist sie heute zweifach:
- Innerhalb der Claude-Artefakt-Umgebung über `window.storage`.
- Auf dem Gerät über einen `localStorage`-Aufsatz (Shim).

Ein einfacher Synchronisations-Ansatz ist bereits angelegt: ein 3,5-Sekunden-Hintergrund-Refresh lädt Daten neu und zeichnet die Ansicht. Auf einer schnellen lokalen Verbindung verhält sich das bereits wie eine primitive Synchronisation.

## 2. Ziel: gemeinsame Daten über mehrere Geräte

Mehrere Kollegen sollen gleichzeitig in derselben Patientenliste arbeiten. Dafür braucht es eine gemeinsame „Quelle der Wahrheit".

### Die Rahmenbedingung des Teams
- **Mobilfunk meist vorhanden, mobile Daten/Internet aber unzuverlässig** (oft mittelmäßig oder weg). Genaueres ist noch mit der zuständigen Stelle (PTLS Pol) abzuklären.
- **Kein Zusatzgerät** kann mitgeführt werden (auch kein Raspberry Pi).
- Geräte sind **iPhones**, die App soll eine **Web-App (PWA)** bleiben.

### Die unvermeidliche Abwägung (auf dem iPhone)
Von diesen drei Wünschen lassen sich nur **zwei gleichzeitig** erfüllen:
1. **gerätefrei** (kein Hub mitführen),
2. **internetfrei** (ohne Datenverbindung funktionieren),
3. **als Web-App/PWA** laufen.

- gerätefrei + Web-App → braucht Internet (Cloud-Sync). **← aktuell gewählter Weg.**
- Web-App + internetfrei → braucht ein lokales Hub-Gerät (ausgeschlossen).
- gerätefrei + internetfrei → nur als native App mit lokaler Funk-Vernetzung (Apple Multipeer), nicht als Web-App; bedeutet App-Store/offizielle Verteilung.

### Entscheidung für die Closed Beta
Für den Start wird angenommen, dass **eine Internetverbindung zuverlässig genug verfügbar** ist (Annahme bewusst getroffen, Failover geparkt). Architektur: **PWA + verwaltetes Cloud-Backend (EU-Region) mit Echtzeit-Sync**. Das eröffnende Diensthandy kann zusätzlich als **Hotspot** dienen (Internet-Brücke, **nicht** als Server – iOS lässt keinen App-Server im Hintergrund zu).

Bei Funkloch arbeitet dank local-first jedes Gerät weiter und gleicht beim Wiederverbinden ab.

## 3. Empfohlener Tech-Stack

**Frontend:** die bestehende App weitgehend **so lassen** (Vanilla-HTML/CSS/JS, PWA). Das respektiert die Einfachheit und minimiert Risiko. Nur ergänzen:
- einen **Service Worker** für die offline-fähige App-Hülle,
- den Austausch der Speicher-Schicht gegen einen Backend-Client (siehe unten).

Eine Migration auf ein Framework (z. B. React/Vite) ist **optional** und nur sinnvoll, wenn die UI deutlich wachsen soll – für die Closed Beta nicht nötig.

**Backend:** **Supabase (EU-Region)** als Primärempfehlung:
- verwaltetes Postgres mit **Echtzeit-Abonnements** (passt zum bestehenden „neu laden und zeichnen"-Muster, lässt sich aber auf Push umstellen),
- **Auth** integriert,
- **Row Level Security** für Zugriffskontrolle,
- EU-Datenhaltung möglich (Datenschutz).
- Alternative: Firebase (Echtzeit gut, EU-Datenresidenz aber aufwändiger).

**Mapping Speicher-Schicht → Backend:**
- `sList/sGet/sSet/sDel` → Tabellen-Operationen bzw. eine Key-Value-Tabelle; Signaturen (async) beibehalten.
- `loadPatients` → Query + Echtzeit-Subscription auf die Patiententabelle des aktiven CCP.
- `savePatient` → Upsert.
- Rollen-/Merge-Status (`loadMeta/setMasterMedic`) → eine kleine CCP-Statustabelle.

## 4. Synchronisation & Konfliktbehandlung

- **Sync:** Echtzeit-Abonnement statt 3,5-s-Polling (Polling als Fallback belassen).
- **Konflikte:** bewusst **kein** CRDT/Merge. Stattdessen **pessimistische Sperre pro Patient** mit 30-Sekunden-Ablauf nach letztem Lebenszeichen (Heartbeat). Lesen bleibt für alle offen. Details: `docs/FEATURES_MULTIUSER.md`.
- **Offline:** local-first bleibt erhalten; getrennt arbeitende Geräte bilden „Insel-CCPs", die über die CCP-Kennung kollisionsfrei wieder zusammengeführt werden.

## 5. Geparkt / Ausblick (nicht für die Closed Beta)

- **Failover über mehrere iPhones** (automatisch das Signal eines anderen Geräts nutzen): auf iOS aus einer App heraus nicht steuerbar. Nur über native App + lokale Funk-Vernetzung oder ein lokales Hub-Gerät lösbar.
- **Offline-Sync ohne Netz** per QR-/Funk-Code (wie etablierte Systeme): zugleich Grundlage des CCP-Zusammenführens im Funkloch.
- **Native App** (z. B. via Capacitor) nur, falls „gar kein Internet" der Regelfall ist – dann lokale Funk-Vernetzung möglich, aber offizielle Verteilung nötig.
- **Anbindung Lagezentrum / ILS / Krankenhausverteilung:** in Deutschland existiert dafür **IVENA eHealth** (inkl. MANV-App). Realistisch ist Einspeisung über eine Schnittstelle in Abstimmung mit Leitstellenträger und Hersteller – **nicht** ein eigener Nachbau. Erst ein Lage-Dashboard (read-only, anonymisierte Zahlen), dann kontrollierte Übergabe.
