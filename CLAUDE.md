# CLAUDE.md – Projektkontext für Claude Code

> Diese Datei wird von Claude Code automatisch als Projektkontext gelesen. Sie ist die zentrale Einstiegsstelle. Detaillierte Spezifikationen liegen unter `docs/`.

## Worum es geht

**CCP-App** – ein digitales Erfassungs- und Sichtungswerkzeug für einen **Casualty Collection Point / Verwundetensammelstelle** im Rahmen von MANV-/Feldübung-Lagen (Massenanfall von Verletzten / lebensbedrohliche Einsatzlagen).

Die App ersetzt die handschriftliche Sichtung am CCP: Patienten werden mit einer laufenden Nummer (auf der Haut notiert) erfasst, per Sichtungsalgorithmus (tacSTART) oder direkt einer Kategorie (T1/T2/T3/T5) zugeordnet, verwaltet (Vitalwerte, Verletzungen, Maßnahmen, Tourniquet-Zeit, Prio-Transport, Foto) und beim Abtransport ausgecheckt.

**Ausgangspunkt ist eine fertige, funktionierende Single-File-Web-App:** `legacy/CCP_App.html`. Sie ist im Feld bereits erprobt (Großübung). Ziel dieses Projekts ist, daraus eine echte **mehrgeräte-fähige App für eine Closed Beta** zu machen, ohne die im Feld bewährte Einfachheit zu verlieren.

## Oberste Leitprinzipien (nicht verhandelbar)

1. **Einfachheit vor Funktionsfülle.** Die App wird unter Stress, mit Handschuhen, einhändig bedient. Jede neue Funktion muss sich gegen „macht es die Bedienung komplizierter?" rechtfertigen. Der häufige Fall (ein einzelner CCP) bleibt so schlicht wie heute.
2. **Local-first.** Jedes Gerät arbeitet auch ohne Verbindung voll weiter und gleicht später ab. Niemals eine Funktion bauen, die ohne Netz blockiert.
3. **Pseudonymität.** Patienten werden über Nummern identifiziert, Klarnamen sind optional. Das ist ein bewusster Datenschutz-Vorteil und bleibt so.
4. **Feldtauglichkeit über Eleganz.** Große Tippflächen, hoher Kontrast, keine versteckten Gesten, keine Abhängigkeit von schnellem Netz.

## Aktueller Stand (was die HTML-Datei schon kann)

Siehe `docs/PRODUCT_SPEC.md` für Details. Kurz:
- Checkliste CCP (Aufbau & Leitung, mit Notizen und Kopfdaten)
- Patientenerfassung per tacSTART (geführte Vorsichtung) oder direkter Kategorie-Zuordnung, mit automatischer laufender Nummer
- Patientenübersicht nach Kategorien, Patientendetail (Vitalwerte, Verletzungen, Maßnahmen, TQ-Timer, Prio, transportfertig, Notizen, Kategoriewechsel, Auschecken)
- **Foto** zur Identifikation (Kamera, automatisch verkleinert, lokal gespeichert)
- **Sammel-Auscheckung** aller transportfertigen Patienten einer Kategorie
- **MasterMedic-Rolle** und **CCPs zusammenführen** – aktuell als lokale, anklickbare **Vorschau** (Logik noch nicht geräteübergreifend, siehe unten)
- Installierbar als PWA auf dem iPhone-Homescreen (Vollbild, Icon, Offline-Hülle)
- Lokale Persistenz über eine abstrahierte Speicher-Schicht

## Was zu bauen ist (das eigentliche Projektziel)

Die geräteübergreifenden Features (Mehrbenutzer-Sync, echte Rollenübernahme, echtes CCP-Zusammenführen, Patienten-Sperren) brauchen ein Backend. Die UI dafür ist in der Vorschau bereits gebaut – es fehlt die „Verdrahtung".

Reihenfolge und Details: **`docs/ROADMAP.md`**. Architektur: **`docs/ARCHITECTURE.md`**. Die Mehrgeräte-Features im Detail: **`docs/FEATURES_MULTIUSER.md`**.

## Die wichtigste technische Naht

Die gesamte Datenhaltung der bestehenden App läuft durch eine dünne, **asynchrone** Schicht. Diese Funktionen sind der einzige Ort, der beim Anschluss eines Backends ausgetauscht werden muss – die UI bleibt unangetastet:

- `sList(prefix)`, `sGet(key)`, `sSet(key,val)`, `sDel(key)` – generische Schlüssel/Wert-Persistenz
- `getOperator()` / `setOperatorStore(v)` – Bediener-Kürzel
- `loadMeta()` / `setMasterMedic(v)` – Rollen-/Merge-Status
- `loadPatients()` / `savePatient(p)` / `addPatient(cat)` – Patienten

**Regel für Claude Code:** Diese Signaturen beibehalten, nur die Implementierung gegen den Backend-Client tauschen. Nicht die View-Funktionen umschreiben, um Daten zu holen.

## Konventionen

- **Sprache der Oberfläche:** Deutsch. Knappe, einsatztaugliche Formulierungen.
- **Design:** bestehende Optik beibehalten (Schrift IBM Plex, vorhandene Farbpalette, Komponenten `banner`, `navbtn`, `bigcat`, `patrow`, `pill`, `card`, Modals). Nicht „aufhübschen".
- **Dialoge:** keine nativen `alert/confirm/prompt` verwenden – iOS deaktiviert diese im PWA-Vollbildmodus. Stattdessen die vorhandenen In-App-Modals `confirmModal()` / `promptModal()` nutzen.
- **Keine Browser-Storage-Annahmen brechen:** weiterhin offline-fähig bleiben.
- **Nummernlogik:** laufende Nummer pro CCP; CCP-Kennung (A/B/…) liegt immer im Datensatz, wird aber nur angezeigt, wenn mehr als ein CCP zusammengeführt ist.

## Datenschutz & Recht (vor offizieller Nutzung klären)

**Zentrale Arbeitsgrundlage: `docs/datenschutz/`** — vollständiges Dossier (00–08:
VVT, Rechtsgrundlagen, DSFA, TOM, Löschkonzept, Supabase-AVV, Einwilligung,
Maßnahmenplan) plus **`docs/datenschutz/DATENSCHUTZ-SPEC.md`** mit den konkreten
Umsetzungs-Tasks T1–T6 inkl. Akzeptanzkriterien. Bei Datenschutz-Arbeit IMMER zuerst
die SPEC lesen. Kurzkontext: Polizei BW als Verantwortlicher, Eigentümer bleibt
Gabor Szeman (→ § 82 PolG BW Auftragsverarbeitung), ARGUS ist Durchgangsspeicher
(Export an Trägerdoku, kurze Löschfristen), Foto-Härtung + Auto-Löschung sind
Bedingung für den Echtbetrieb. Ältere Hinweissammlung: `docs/COMPLIANCE.md`;
MDR-Frage (tacSTART) weiterhin offen. **Keine Rechtsberatung** — DSB/Träger
entscheiden.

## Wie man die bestehende App startet

Es ist eine einzelne Datei ohne Build. Zum Testen `legacy/CCP_App.html` lokal im Browser öffnen oder über einen einfachen statischen Server ausliefern. Auf dem iPhone: über eine HTTPS-Adresse (z. B. Netlify) öffnen und „Zum Home-Bildschirm" hinzufügen.
