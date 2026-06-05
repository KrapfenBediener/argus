# ARGUS — Regressions-Checkliste (Smoke-Test nach jedem Release)

> Kurz durchklicken nach einem Update — fängt grobe Regressionen ab, bevor sie ins
> Feld kommen. Idealerweise auf einem echten iPhone (Homescreen-App). ⏱ ~10 Min.
> Version unten auf der Startseite prüfen: stimmt sie mit dem Release überein?

## Zugang & Freischaltung
- [ ] Code eingeben → Präsidium wird freigeschaltet, Start-Screen erscheint.
- [ ] „📋 Einfügen": Code/Link in Zwischenablage → einfügen schaltet ohne Tippen frei.
- [ ] MasterToken (`3GNN-HMEV`) → Präsidienauswahl, sieht alle Präsidien.
- [ ] Altgerät ohne JWT (oder frisch): wird zur Code-Eingabe geführt.

## Erfassen
- [ ] „Patient erfassen" → Kategorie antippen → Patient angelegt, Flash „✓ Nr. X · T-Y".
- [ ] tacSTART durchspielen → Ergebnis + Anlegen; MDR-Hinweis sichtbar.
- [ ] Nächste Nummer zählt korrekt hoch; „zuletzt angelegt" zeigt Nr./Kategorie.
- [ ] Schnellaktionen: Prio, TQ (startet Timer), öffnen, Verwerfen (entfernt Patient).
- [ ] Doppeltipp legt **keinen** zweiten Patienten an; App zoomt nicht hinein.

## Patient bearbeiten
- [ ] Patient öffnen → Vitalwerte (WASB-Dropdown W/A/S/B), Maßnahmen, Verletzungen.
- [ ] Foto aufnehmen → antippen öffnet Vollbild → schließbar.
- [ ] „Messung protokollieren" → Verlauf zeigt Eintrag mit Uhrzeit.
- [ ] Kategorie wechseln, Prio setzen.
- [ ] Zeitanzeige „vor … Std … min" bei >1 h; TQ-Timer als H:MM:SS bei >1 h.

## Übersicht & Abtransport
- [ ] Patientenübersicht: Kategorien, PRIO/gPA, „Alle Patienten" anklickbar.
- [ ] „Abtransport → gPA"; ausgecheckten Patienten wieder „Zurückholen".

## Mehrere Geräte (2 Geräte)
- [ ] Gerät A erfasst → erscheint auf Gerät B (Echtzeit).
- [ ] A öffnet Patient → B sieht „schreibgeschützt"; nach A-Verlassen/45 s übernimmt B automatisch.
- [ ] CCP zusammenführen (beidseitig) → gemeinsame Liste; Verbund erscheint als **ein** Eintrag in „CCP beitreten".
- [ ] Trennung der Präsidien: anderer Code sieht nur sein Präsidium (keine Fremddaten).

## Offline
- [ ] Flugmodus an → Patient anlegen/bearbeiten → Banner „⏳ n nicht synchronisiert".
- [ ] Flugmodus aus → Hinweis verschwindet, Daten auf Zweitgerät vorhanden (kein Verlust).

## Admin / Schulung (MasterToken)
- [ ] Admin: Dauerhaft-Link / Einmal-Link erstellen & kopieren.
- [ ] CCP löschen (einzeln) bzw. „Ganzen Verbund löschen"; „CCP beitreten" zeigt Gelöschtes nicht mehr.
- [ ] Schulung: „Zurücksetzen" nur sichtbar, wenn verändert; Reset legt 6 Demo-CCPs an.

## Update-Mechanik
- [ ] Bei neuer Version erscheint „Jetzt aktualisieren"; „Neuerungen" zeigt Highlights + ggf. „Visuelle Übersicht".
