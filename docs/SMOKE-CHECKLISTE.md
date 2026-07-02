# ARGUS — Smoke-Test-Checkliste (echte Geräte)

> ~15 Minuten, vor jedem Beta-Meilenstein. Zwei iPhones (A = Leitung/Master,
> B = Bediener), einmal durch alle drei Oberflächen. Im **Schulungs-Präsidium**
> durchführen — nie mit echten Daten.

## Feld-App (beide Geräte)

- [ ] **Install:** Homescreen-App öffnet im Vollbild, Version unten = aktuelle (`version.json`)
- [ ] **Login B:** Code eingeben → Präsidium freigeschaltet (persönlicher Code: „Angemeldet als USBNK …")
- [ ] **Picker:** Echt/Schulung-Reiter erscheinen; Schulung wählen → **gelber Banner** dauerhaft sichtbar (auch nach App-Neustart!)
- [ ] **CCP:** A eröffnet CCP (GPS-Abfrage erscheint) → B sieht ihn unter „CCP beitreten" und tritt bei
- [ ] **tacSTART:** B erfasst Patienten geführt (gehfähig → … → Kategorie bestätigen); Nummer automatisch (z. B. A-1)
- [ ] **Sync:** Patient erscheint auf A **ohne** Neuladen (< 5 s)
- [ ] **Sperre:** A öffnet den Patienten → B sieht Schreibschutz; nach Verlassen wieder frei
- [ ] **Foto:** B macht Patientenfoto → auf A sichtbar; Zoom (Antippen) geht
- [ ] **TQ-Timer:** starten (Ort + Zeit) → läuft auf beiden Geräten
- [ ] **gPA:** transportfertig → Abtransport → AT-MIST-Übergabekarte erscheint; „Zurückholen" geht
- [ ] **Offline:** B in Flugmodus → Patient anlegen geht weiter („⏳ nicht synchronisiert"); online → gleicht ab
- [ ] **Training:** „Geführtes Training starten" → erste 3 Lektionen durchtippen, Spotlight sitzt (nichts hinterm Panel), „Beenden" räumt ab
- [ ] **Toggle (A, Master/Admin):** „Schulungsumgebung leeren" → leer; „… befüllen" → 6 Demo-CCPs

## Leitungs-Seite (Gerät A oder Desktop)

- [ ] **Login Master:** volle Ansicht (Zugänge); **Login Admin-Code:** nur Gast-Code + Lage (kein Master-Material sichtbar!)
- [ ] **Zugang ausgeben:** Gast-Code (24 h) erstellen → QR anzeigen → sperren
- [ ] **Einsatzprotokoll:** abgeschlossenen Übungs-CCP öffnen; Foto-Abruf wird protokolliert
- [ ] Kein natives Browser-Popup irgendwo (alles In-App-Modals)

## Lage-Seite (Desktop)

- [ ] **Beobachter-Code:** Login → Zahlen je Kategorie stimmen mit Feld überein
- [ ] **📍-Pin:** Antippen kopiert Koordinate (WGS84)
- [ ] Kein Patienten-Detail erreichbar (nur Aggregat)

## Abschluss

- [ ] Schulungsumgebung **leeren** (keine Testdaten zurücklassen)
- [ ] Auffälligkeiten mit **Version + Ansicht + Schrittfolge** notieren → Feedback

_Stand: v0.33.3 · bei UI-Änderungen mitziehen (DAUERREGEL)._
