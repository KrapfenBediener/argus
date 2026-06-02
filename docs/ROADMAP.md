# Roadmap / Bauplan

Konkrete, geordnete Aufgaben für Claude Code. Grundsatz: **kleine, überprüfbare Schritte**, die im Feld bewährte Einfachheit nie opfern. Die bestehende `legacy/CCP_App.html` ist Referenz und Startpunkt.

## Phase 0 – Projekt aufsetzen
- [ ] `legacy/CCP_App.html` ins Repo legen (unverändert als Referenz).
- [ ] Statischen Dev-Server einrichten (kein schwerer Build nötig).
- [ ] Die App-Datei in eine wartbare Struktur aufteilen **oder** bewusst als Single-File belassen (Entscheidung dokumentieren; Single-File ist für die Einfachheit legitim). Falls aufgeteilt: `index.html`, `app.js`, `app.css`, Assets – Verhalten identisch halten.
- [ ] Service Worker ergänzen: App-Hülle offline cachen, damit das Homescreen-Icon auch ohne Netz startet. Patientendaten kommen weiter live aus dem Backend.

## Phase 1 – Backend & Sync (Kern)
- [ ] Backend anlegen: **Supabase, EU-Region** (siehe `docs/ARCHITECTURE.md`). Tabellen gemäß `docs/DATA_MODEL.md` (`ccps`, `patients`, `checklists`).
- [ ] **Speicher-Schicht austauschen, Signaturen beibehalten:** `sList/sGet/sSet/sDel`, `loadPatients/savePatient/addPatient`, `getOperator/setOperatorStore`, `loadMeta/setMasterMedic` zeigen jetzt auf den Backend-Client. **Keine** View-Funktion umschreiben.
- [ ] Echtzeit-Abonnement auf die Patienten (und CCP-Status) des aktiven CCP; das 3,5-s-Polling als Fallback belassen.
- [ ] Leichte **Authentifizierung** + Geräte-/Bediener-Identität (Team vertraut einander; bewusst niedrigschwellig halten).
- [ ] **CCP-Kontext:** Beim ersten Start einen CCP mit Kennung `A` anlegen; alle Patienten daran hängen.
- [ ] Offline-Verhalten verifizieren: ohne Netz weiterarbeiten, bei Wiederverbindung abgleichen.

## Phase 2 – Mehrgeräte-Features verdrahten
Spezifikation: `docs/FEATURES_MULTIUSER.md`.
- [ ] **Patienten-Sperre:** Felder `lockedBy`/`lockedAt`; Heartbeat (~10 s) beim Öffnen; **30-s-Ablauf** nach letztem Lebenszeichen; gesperrte Patienten nur lesbar mit Hinweis „bearbeitet von <Kürzel>". (Override **noch nicht** bauen.)
- [ ] **MasterMedic-Rolle** als gemeinsamer CCP-Status; automatische Beanspruchung beim Eröffnen; Übernahme per Tipp + Bestätigung; Änderung über Echtzeit an alle.
- [ ] **CCPs zusammenführen** echt: Liste offener CCPs, Anfrage an MasterMedic B, beidseitige Bestätigung, kein Umnummerieren, Präfix-Anzeige ab >1 CCP. Den **Demo-CCP-B-Mechanismus und alle `demo`-Felder entfernen**.

## Phase 3 – Closed Beta vorbereiten
- [ ] Datenschutz/Recht abarbeiten: `docs/COMPLIANCE.md` (EU-Hosting bestätigt, Verschlüsselung, Zugriffe, Löschkonzept; MDR-Einstufung klären). **Vor** echtem Patienteneinsatz.
- [ ] Verteilung an Tester: HTTPS-Adresse → „Zum Home-Bildschirm" (PWA). Kurzanleitung für die Kollegen.
- [ ] Feldtest (LebEL-Übung) mit echten Geräten; Sperre/Rolle/Merge unter realen Bedingungen prüfen (gerade bei wackeligem Netz).
- [ ] Feedback-Schleife: kleine Korrekturen an Wording/Platzierung.

## Geparkt (nach Beta entscheiden)
Siehe `docs/ARCHITECTURE.md`, Abschnitt „Ausblick":
- Failover über mehrere iPhones / Funkloch-Sync per QR-Code.
- Native App + lokale Funk-Vernetzung, falls „kein Internet" der Regelfall ist.
- MasterMedic-Override für Sperren; Rolle-nach-Merge final festlegen.
- Anbindung Lagezentrum / ILS / IVENA (read-only Lage-Dashboard zuerst).

## Definition of Done je Schritt
- Bestehende Bedienung unverändert oder einfacher.
- Funktioniert offline mindestens lesend/erfassend weiter.
- Keine nativen `alert/confirm/prompt`; In-App-Modals genutzt.
- Auf einem echten iPhone als Homescreen-App getestet (nicht nur im Desktop-Browser).
