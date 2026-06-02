# Datenschutz & Recht

> **Wichtig:** Dies ist eine technische Hinweissammlung, **keine Rechtsberatung**. Vor einem offiziellen Einsatz mit echten Patientendaten ist die Abstimmung mit dem **Datenschutzbeauftragten** und dem **Träger der Organisation** zwingend.

## 1. Datenschutz (DSGVO)

Patientenbezogene Gesundheitsdaten gehören zu den **besonderen Kategorien** personenbezogener Daten (Art. 9 DSGVO) und sind besonders geschützt.

**Günstige Ausgangslage:** Die App arbeitet **pseudonym** – Identifikation über laufende Nummer, Klarnamen optional. Das reduziert das Risiko erheblich und entspricht der Empfehlung, im einfachsten Fall mit anonymen IDs zu arbeiten.

**Trotzdem zu klären/umzusetzen:**
- **Rechtsgrundlage** für die Verarbeitung im Einsatz.
- **EU-Hosting** des Backends (z. B. Supabase EU-Region) – Daten dürfen den EU-Raum nicht unkontrolliert verlassen.
- **Verschlüsselung** in Übertragung und Speicherung.
- **Zugriffskontrolle** (nur berechtigte Geräte/Personen) und Nachvollziehbarkeit von Änderungen.
- **Löschkonzept / Aufbewahrungsfristen** (wann werden Einsatzdaten gelöscht; Fotos sind besonders sensibel).
- Ggf. **Datenschutz-Folgenabschätzung (DSFA)**, da besondere Datenkategorien betroffen sind.

**Fotos:** besonders sensibel. Lokal verkleinert gespeichert; bei Cloud-Speicherung dieselben Schutzanforderungen wie oben. Aufbewahrung eng begrenzen.

## 2. Medizinprodukte-Recht (MDR)

- **Reine Dokumentation** (Erfassen, Verwalten, Anzeigen) ist eher risikoarm.
- Die **tacSTART-Funktion schlägt eine Sichtungskategorie vor**. Software, die Entscheidungen zu Diagnose/Triage unterstützt, kann als **Medizinprodukt-Software** eingestuft werden.
- Die App ordnet bewusst **nicht in jedem Fall automatisch** zu (z. B. bei „keine Spontanatmung trotz Freimachen" keine automatische Kategorie) – das ist eine sinnvolle Abgrenzung, ersetzt aber keine rechtliche Prüfung.
- **Empfehlung:** Einstufung vor offiziellem Einsatz fachlich/juristisch klären lassen.

## 3. Organisatorische Verankerung

Sobald die App über den privaten Übungsgebrauch hinausgeht (mehrere Geräte, gemeinsame Daten, später ggf. Anbindung an Lage/Leitstelle), ist sie **kein privates Werkzeug** mehr:
- Buy-in von Träger/Behörde und IT-Sicherheit nötig (sonst Schatten-IT).
- Klare Verantwortlichkeiten (wer betreibt das Backend, wer verwaltet Zugänge).
- Diese Punkte gehören **vor** die produktive Nutzung, nicht danach.
