# ARGUS — Briefing für das Gespräch mit dem Datenschutzbeauftragten (DSB)

> **Zweck:** Gesprächsvorlage, damit das DSB-Gespräch (Empfehlung aus dem
> Tester-Feedback) effizient und vollständig läuft. **Kein Rechtsrat.**
> Detaillierte technische Sammlung: `docs/COMPLIANCE.md`.

## 1. Was ist ARGUS (in einem Absatz)
Digitales Erfassungs- und Sichtungswerkzeug für eine Verwundetensammelstelle
(Casualty Collection Point) bei MANV-/Übungslagen. Ersetzt die handschriftliche
Sichtung: Patienten werden per laufender Nummer erfasst, per Sichtungsalgorithmus
(tacSTART) oder direkt einer Kategorie (T1/T2/T3/T5) zugeordnet und bis zum
Abtransport verwaltet. PWA (Webapp), läuft mehrgeräte-fähig und offline.

## 2. Welche Daten werden verarbeitet
- **Pseudonym:** Identifikation über **laufende Nummer** (auf der Haut notiert).
  Klarname/Alter/Geschlecht sind **optional**.
- **Gesundheitsdaten** (Art. 9 DSGVO, besondere Kategorie): Kategorie, Vitalwerte,
  Verletzungen, Maßnahmen, Tourniquet-Zeit, Notizen.
- **Foto** (optional, zur Identifikation) — besonders sensibel.
- **Bediener-Kürzel** (kein Konto, kein Klarname erzwungen).
- **Keine** Benutzerkonten im Feld; Zugang über Code → kurzlebiges Ticket (JWT).

## 3. Technische Schutzmaßnahmen (Ist-Stand)
- **EU-Hosting:** Supabase, EU-Region.
- **Verschlüsselung:** TLS in Übertragung; Verschlüsselung at rest beim Anbieter.
- **Zugriffskontrolle:** 8-stelliger Code → signiertes JWT (praesidium-gebunden) →
  serverseitige Row-Level-Security. Ohne gültiges Ticket liefert das Backend nichts.
  Codes selbst sind ohne Ticket nicht mehr abrufbar.
- **Pseudonymität** durchgängig gewahrt.
- **Local-first:** Geräte arbeiten offline weiter, gleichen später ab.

## 4. Offene Punkte, die wir vom DSB geklärt brauchen
1. **Rechtsgrundlage** der Verarbeitung im Übungs- bzw. Einsatzkontext (BOS).
2. **Datenschutz-Folgenabschätzung (DSFA):** erforderlich (besondere Kategorien)?
3. **Auftragsverarbeitungsvertrag (AVV)** mit dem Hosting-Anbieter — Vorlage/OK?
4. **Aufbewahrung & Löschung:** zulässige Fristen; wann müssen Einsatz-/Übungsdaten
   (insb. Fotos) gelöscht werden? → fließt ins Löschkonzept (Phase 5).
5. **Foto-Funktion:** zulässig/erwünscht, oder einschränken/abschaltbar machen?
6. **Medizinprodukt-Einstufung (MDR):** Die tacSTART-Kategorievorschläge könnten
   ARGUS als Medizinprodukt-Software qualifizieren. Einschätzung / weiteres Vorgehen?
7. **Übermittlung an Dritte** (späteres FLZ/ILS-Dashboard, nur anonyme Zahlen) —
   Anforderungen vorab klären.

## 5. Was wir mitbringen / zusichern können
- Pseudonymität als Default, optionale Klarnamen.
- EU-Hosting, serverseitige Zugriffstrennung, Pseudonym-Tickets.
- Bereitschaft, Löschkonzept + Aufbewahrungsfristen umzusetzen (Phase 5).
- Dokumentierte Architektur (`docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`).

> Ergebnis des Gesprächs hier oder in `docs/COMPLIANCE.md` festhalten und als
> Voraussetzung für Phase 6 (Open Beta / Echtbetrieb) abhaken.
