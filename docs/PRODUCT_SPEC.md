# Produkt-Spezifikation

## 1. Domänen-Kontext

Ein **CCP (Casualty Collection Point) / Verwundetensammelstelle** ist die Stelle, an der bei einem Massenanfall von Verletzten (MANV) Patienten gesammelt, gesichtet (triagiert) und für den geordneten Abtransport vorbereitet werden. Die App unterstützt den Kollegen, der den CCP leitet und betreibt.

Begriffe:
- **Sichtung / Triage:** Einteilung in Behandlungsdringlichkeit.
- **tacSTART:** geführter Sichtungsalgorithmus (START-Logik), Schritt für Schritt.
- **Kategorien:** T-1 (akut lebensbedrohlich), T-2 (dringend), T-3 (leicht/abwartend), T-5 (ohne Überlebenschance / Betreuung). Daneben der Status **gPA** = ausgecheckt / zum Abtransport übergeben.
- **Prio-Transport:** Markierung für bevorzugten Abtransport.
- **Transportfertig:** Patient ist für den Transport vorbereitet.
- **TQ:** Tourniquet (Abbindung) – die App misst die Anlagezeit mit.

Identifikation der Patienten erfolgt über eine **laufende Nummer** (auf die Haut geschrieben). Klarnamen sind optional. Ein **Foto** kann hinterlegt werden, um Patienten auch dann zweifelsfrei zuzuordnen, wenn die aufgemalte Nummer verwischt.

## 2. Leitprinzipien für jede Designentscheidung

- So wenig Bedienschritte wie möglich; große Tippflächen; einhändig nutzbar.
- Nichts blockiert ohne Netz.
- Der häufige Fall (genau ein CCP) bleibt visuell und bedientechnisch schlicht; Komplexität (mehrere CCPs, Rollen) erscheint nur, wenn sie wirklich gebraucht wird.
- Pseudonym als Standard.

## 3. Bildschirme & Funktionen (Ist-Stand)

### 3.1 Startbildschirm
- Zählerleiste (Anzahl je Kategorie).
- Banner „Gemeinsamer Modus" mit aktuellem **Bediener-Kürzel** (änderbar) und der **MasterMedic-Anzeige** (siehe `docs/FEATURES_MULTIUSER.md`).
- Vier Einstiege: Checkliste, Patient erfassen, Patientenübersicht, Hilfestellungen.

### 3.2 Checkliste CCP
- Kopfdaten: Einsatzort, MasterMedic, Doorman, Assistent.
- Zweiteilige Checkliste (Aufbau-Schleife / Betrieb-Schleife) mit Haken und Freitext-Notiz je Punkt.

### 3.3 Patient erfassen
- **tacSTART:** geführte Ja/Nein-Fragen (kritische Blutung → Gehfähigkeit → Atmung → Atemfrequenz → Puls/Rekap → Befehle) mit Kategorie-Ergebnis. Bei „keine Spontanatmung trotz Freimachen" ordnet die App **nichts automatisch** zu (ärztliche/Einzelfallentscheidung).
- **Direkte Zuordnung:** T-1/T-2/T-3/T-5 per Tipp.
- Die laufende Nummer wird automatisch vergeben (pro CCP).

### 3.4 Patientenübersicht
- Kategorien mit Live-Zähler → Liste → Patientendetail.
- Nur für MasterMedic: Einstieg **„CCPs zusammenführen"** (siehe Multiuser-Spec).

### 3.5 Patientenliste (je Kategorie)
- Sammel-Button **„Alle transportfertigen auschecken → gPA"** (erscheint, wenn welche transportfertig sind; mit Bestätigung).
- Patientenzeilen: Nummer, Name (optional), Alter der letzten Sichtung, laufende TQ-Zeit, Marker (PRIO, 📷 Foto vorhanden, transportfertig).

### 3.6 Patientendetail
- Kopf: Nummer (ggf. mit CCP-Kennung), Kategorie, **Prio-Transport**-Schalter.
- **Foto zur Identifikation:** aufnehmen/wählen (Kamera), wird verkleinert und lokal gespeichert; ersetzbar/entfernbar.
- Stammdaten (optional), Vitalwerte, Pupillen, Verletzungen, Maßnahmen, Tourniquet-Timer (Start/Stopp), Verletzungsmechanismus, Notizen.
- **Transportfertig**-Schalter, **Kategorie wechseln**, **Auschecken (→ gPA)**.

### 3.7 Hilfestellungen
- tacSTART-Kurzreferenz, Rollen, Merksätze.

## 4. Mehrgeräte-Features (UI vorhanden, Logik zu bauen)

Detailliert in `docs/FEATURES_MULTIUSER.md`:
- **MasterMedic-Rolle:** das eröffnende Gerät beansprucht sie automatisch; jederzeit per Tipp übernehmbar.
- **Patienten-Sperre (soft lock):** immer nur ein Bearbeiter pro Patient; Lesen bleibt für alle offen; Sperre läuft 30 s nach letztem Lebenszeichen ab.
- **CCPs zusammenführen:** nur für MasterMedic; CCP-Kennung als Präfix (A-07/B-07); beidseitige Bestätigung; keine Umnummerierung.

## 5. Nicht-Ziele (bewusst ausgeklammert)

- Keine automatische ärztliche Diagnose; tacSTART ist Hilfestellung, keine verbindliche Entscheidung.
- Kein Ersatz für offizielle Leitstellen-/Krankenhaussteuerung (z. B. IVENA) – langfristig ggf. Anbindung, kein Nachbau (siehe Architektur, „Ausblick").
- Keine Klarnamen-Pflicht.

---

## Aktualisierung (Stand v0.16.1, 2026-06-05)

> Funktioneller Ist-Stand über die Erstfassung hinaus. Laufende Liste: `CHANGELOG.md`.

- **Bewusstseinslage WASB** (Wach/Ansprechbar/Schmerzreiz/Bewusstlos) statt AVPU.
- **Vitalwerte-Verlauf:** „Messung protokollieren" (Zeitreihe, für längere Versorgung).
- **Erfassen:** zeigt nächste Nummer + zuletzt angelegten Patienten; Schnellaktionen
  **Prio · TQ · öffnen · Verwerfen**; **Doppeltipp-Sperre** + dezenter Bestätigungs-Flash;
  **kein** versehentliches Zoomen.
- **Foto:** antippen → Vollbild.
- **Mehrgeräte:** Soft-Lock gibt nach Verlassen/45 s automatisch frei (Wartende
  übernehmen selbsttätig); CCP-Verbund als ein Eintrag in „CCP beitreten";
  „Ganzen Verbund löschen" (MasterToken).
- **Freischalten:** Code/Link kopieren → „📋 Einfügen" (kein Abtippen); Code-Typen
  reduziert auf Dauerhaft-Link + Einmal-Link.
- **Onboarding/Hilfe:** Erst-Einführung (überspringbar, nur Neuinstallation),
  Kurzanleitung in den Hilfestellungen, „Was ist neu"-Hinweise + visuelle Sheets.
- **Schulungsumgebung:** „Zurücksetzen" erscheint nur, wenn etwas verändert wurde.
- **Zeitanzeigen** mit Stunden (z. B. „vor 2 Std 5 min", TQ 2:05:30).
- **MDR-Hinweis:** tacSTART-Ergebnis weist dezent auf „Entscheidungsunterstützung,
  kein Ersatz für ärztliche Beurteilung" hin.
