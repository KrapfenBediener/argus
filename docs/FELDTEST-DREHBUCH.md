# ARGUS — Feldtest-Drehbuch (Übungsszenario)

> Strukturierter Probelauf unter realistischen Bedingungen (Phase-6-Vorbereitung).
> Ziel: ARGUS im Mehrgeräte-Betrieb, unter echtem Netz, mit echten Handgriffen prüfen
> — **mit pseudonymen Übungsdaten**, nicht mit echten Patientendaten.

## Vor dem Test
- [ ] Alle Geräte: ARGUS installiert (Homescreen), gleiche **Version** (Startseite unten).
- [ ] **Schulungsumgebung** verwenden (oder ein eigenes Test-Präsidium) — keine Echtdaten.
- [ ] Zugangscodes verteilt (Dauerhaft-Link für Stammteam, Einmal-Links für Gäste).
- [ ] Tester kennen die **Kurzanleitung** (Hilfestellungen) und melden mit **Versionsnummer**.
- [ ] **Backup** vorab gezogen (`python3 scripts/argus_backup.py`).

## Rollen (Beispiel, 3–4 Geräte)
- **MasterMedic / CCP-Leitung** (Gerät 1) — eröffnet CCP, sichtet, koordiniert.
- **Sichter/Doku** (Gerät 2) — erfasst Patienten parallel.
- **Zweiter CCP** (Gerät 3) — eröffnet eigenen CCP, später Zusammenführen.
- **Beobachter** (optional) — schaut nur zu, prüft Echtzeit-Sicht.

## Ablauf (Drehbuch)
1. **Aufbau:** Gerät 1 eröffnet CCP A, füllt Checkliste (Ort, MasterMedic).
2. **Massenerfassung:** Gerät 1 + 2 erfassen zügig ~10 Patienten (tacSTART + Direktzuordnung).
   → *Beobachten:* Nummern eindeutig? Kein Doppeltipp-Phantom? Erscheinen Patienten auf beiden Geräten?
3. **Bearbeiten & Sperre:** Gerät 1 öffnet Patient #X; Gerät 2 öffnet denselben.
   → *Beobachten:* Gerät 2 schreibgeschützt? Nach Verlassen durch Gerät 1 / 45 s: übernimmt Gerät 2 automatisch?
4. **MasterMedic-Übernahme:** Gerät 1 übernimmt eine fremde Sperre.
5. **Versorgung dokumentieren:** Vitalwerte (WASB), TQ-Timer starten, Foto, Maßnahmen; bei einem Patienten „Messung protokollieren".
6. **Zweiter CCP + Zusammenführen:** Gerät 3 eröffnet CCP B, erfasst 3 Patienten; dann CCP A+B **zusammenführen** (beidseitige Bestätigung).
   → *Beobachten:* gemeinsame Liste mit Präfix-Nummern? Verbund-Eintrag in „CCP beitreten"?
7. **Funkloch-Probe:** Ein Gerät in Flugmodus, 2 Patienten erfassen/ändern → wieder online.
   → *Beobachten:* „⏳ nicht synchronisiert" → nach Reconnect alles da, nichts verloren?
8. **Abtransport:** mehrere Patienten „transportfertig" → Sammel-Auscheckung → gPA; einen versehentlich → „Zurückholen".
9. **Lage-Check:** Stimmen Zählerleiste/Übersicht mit der Realität überein?
10. **Abbau:** CCP abschließen bzw. (Master) Verbund/CCP löschen; Schulung zurücksetzen.

## Beobachtungspunkte (Bewertung 1–5 + Notiz)
- Bedienbarkeit unter Zeitdruck / einhändig / mit Handschuhen: ___
- Verständlichkeit für weniger Geschulte: ___
- Echtzeit-Sync / Verzögerungen: ___
- Sperre & Übernahme nachvollziehbar: ___
- Offline-/Reconnect-Verhalten: ___
- Zusammenführen verständlich: ___
- Fehler/Abstürze (mit Version + Schritt notieren): ___

## Nachbereitung
- [ ] Feedback gesammelt (je mit Versionsnummer + konkretem Schritt).
- [ ] Auffälligkeiten als To-dos festhalten; kritische Punkte zuerst.
- [ ] Schulungsumgebung zurückgesetzt; Test-Codes ggf. widerrufen.
