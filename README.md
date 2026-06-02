# CCP-App

Digitales Erfassungs- und Sichtungswerkzeug für eine **Verwundetensammelstelle (Casualty Collection Point, CCP)** bei MANV-/LebEL-Lagen.

Die App löst die handschriftliche Sichtung am CCP ab: schnelle Patientenerfassung mit laufender Nummer, Sichtung per tacSTART oder direkter Kategorie, Verwaltung von Vitalwerten/Maßnahmen/Transportstatus und Auschecken beim Abtransport. Entworfen für die Bedienung unter Stress – einfach, robust, offline-fähig.

## Status

- **`legacy/CCP_App.html`** – die bestehende, im Feld erprobte Single-File-Web-App. Voll funktionsfähig, als PWA auf dem iPhone installierbar.
- **Ziel dieses Repos:** daraus eine mehrgeräte-fähige App für eine Closed Beta machen (gemeinsame Patientenliste über mehrere Geräte, Patienten-Sperren, MasterMedic-Rolle, CCP-Zusammenführung), ohne die Einfachheit zu verlieren.

## Dokumentation

| Datei | Inhalt |
|---|---|
| `CLAUDE.md` | Projektkontext & Leitprinzipien (Einstiegspunkt für Claude Code) |
| `docs/PRODUCT_SPEC.md` | Funktionsumfang, Bildschirme, Domänen-Kontext |
| `docs/ARCHITECTURE.md` | Technische Architektur, Sync-Modell, Trade-offs, Tech-Stack |
| `docs/DATA_MODEL.md` | Datenmodell, Speicher-Schlüssel, ID-Schema |
| `docs/FEATURES_MULTIUSER.md` | Detailspezifikation der Mehrgeräte-Features |
| `docs/ROADMAP.md` | Phasenplan mit konkreten Aufgaben |
| `docs/COMPLIANCE.md` | Datenschutz (DSGVO) & Medizinprodukte-Hinweise |

## Schnellstart (bestehende App)

Single-File, kein Build nötig:

```bash
# lokal im Browser ansehen
open legacy/CCP_App.html        # macOS
# oder über einen einfachen statischen Server
python3 -m http.server 8080     # dann http://localhost:8080/legacy/CCP_App.html
```

Auf dem iPhone als App: Datei über eine HTTPS-Adresse ausliefern (z. B. `app.netlify.com/drop`, Datei als `index.html`), in **Safari** öffnen, **Teilen → Zum Home-Bildschirm**.

## Nächster Schritt mit Claude Code

`CLAUDE.md` lesen, dann `docs/ROADMAP.md` Phase 1 beginnen. Die bestehende `legacy/CCP_App.html` ist Referenz und Startpunkt – die Datenhaltungs-Schicht wird gegen einen Backend-Client getauscht, die Oberfläche bleibt erhalten.
