# MDR-Einstufung ARGUS — Vorprüfung und Fahrplan

> Erstellt 2026-06-13 auf Basis der konsolidierten MDR (VO (EU) 2017/745,
> Stand 01.01.2026; Volltext im Gesetzes-Wiki `~/ClaudeXObsidian`).
> **Strukturierte Vorprüfung, keine verbindliche Einstufung** — die trifft
> Behörde/Benannte Stelle. Löst RECHTLICHE_HINWEISE.md Punkt B ein.

## Ergebnis in drei Sätzen

Die App als Ganzes (Erfassung, Verwaltung, Auscheckung, Export, Lageansicht)
ist **Dokumentations-/Organisationssoftware und kein Medizinprodukt**. Das
Modul **tacSTART qualifiziert in seiner heutigen Form (Kategorie-*Vorschlag*)
mutmaßlich als Medizinprodukte-Software** — und fiele wegen der Tragweite von
Triage-Entscheidungen unter Anhang VIII **Regel 11 in Klasse III** (mind. IIb):
Benannte Stelle, ISO-13485-QMS, klinische Bewertung — unrealistisch für dieses
Projekt. Lösung: Zweckbestimmung begrenzen (sofort) und tacSTART zum reinen
Sichtungs*formular* umbauen (vor Echtbetrieb).

## Maßnahmen

### MDR-1 — Zweckbestimmung begrenzen `sofort, 30 min`
- [ ] In App (Datenschutz-/Infoseite), README, Website und künftigem
  Lizenzvertrag verankern:
  > „ARGUS ist ein Dokumentations- und Organisationswerkzeug für
  > Verwundetensammelstellen. Es ist kein Medizinprodukt im Sinne der
  > VO (EU) 2017/745. Die Sichtungs- und Behandlungsentscheidung trifft
  > ausschließlich die qualifizierte Einsatzkraft. Bis zum Abschluss der
  > MDR-Bewertung ist die Nutzung auf Übungs- und Ausbildungszwecke
  > beschränkt."
- [ ] Lizenzvertrag-Klausel: Lizenznehmer setzt ARGUS nicht als Medizinprodukt
  ein und bewirbt es nicht als solches.

### MDR-2 — tacSTART de-qualifizieren `UMGESETZT v0.29.0 (2026-06-13)`

> **STATUS: umgesetzt — EINHEITLICHER Umbau (Owner-Entscheid 2026-06-13).**
> Abweichung von der ursprünglich skizzierten *Zwei-Modi*-Architektur: Der
> rechnende tacSTART-Vorschlag wurde **vollständig entfernt — auch im
> Trainingsmodus** (nicht nur im Echtbetrieb). Begründung des Owners: die
> konservativere, einfachere Variante ohne Modus-Kopplung (kein
> Umgehungsverdacht, keine Logik, die man falsch verdrahten kann). Damit
> entfällt die gesamte Berechnungs-/Vorschlagsfunktion app-weit; es bleibt das
> statische Schaubild + manuelle Kategoriewahl. Der „Übungsmodus darf
> vorschlagen"-Pfad unten ist damit **bewusst NICHT umgesetzt** (verworfen, nicht
> offen). Code: `tacChartSVG()` (statisches SVG), `vCapture()` (Schaubild +
> manuelle Wahl), Entfernung von `FLOW`/`vTac`/`tacstart`/`tacanswer`/`tacconfirm`.
> CHANGELOG v0.29.0. Verbleibend offen: nur **MDR-1** (Zweckbestimmungs-Text)
> und **MDR-3** (optionale BfArM-Abgrenzungsanfrage).

**Leitidee.** Der MDR-Auslöser ist die *Funktion* „patientenspezifische Befunde
→ Kategorievorschlag", nicht ihre Optik. Verkleidungen (Vorschlag zuerst/größer,
animierte Flow-Chart, die auf die Kategorie zuläuft, Plausibilitäts-Warnung bei
abweichender Wahl) helfen **nicht** — sie alle *sind* die regulierte Funktion.
Aber: Die MDR greift nur bei medizinischem Zweck **am realen Patienten**. Daraus
folgt die Lösung — der volle tacSTART überlebt im **Übungsmodus**, der Echtbetrieb
bekommt das **Sichtungsformular**.

**Übungsmodus (fiktive Patienten) — darf vorschlagen.** *(VERWORFEN — einheitlicher Umbau, s. Status oben. Kein Vorschlag auch im Training.)*
- [~] ~~tacSTART bleibt wie heute: geführter Ablauf, Kategorie-**Vorschlag**~~ —
  bewusst NICHT umgesetzt; der Vorschlag ist app-weit entfernt (auch im Training
  nur noch Schaubild + manuelle Wahl).
- [~] ~~Modus deutlich kennzeichnen (ÜBUNG-Wasserzeichen)~~ — für die
  Vorschlagsfunktion gegenstandslos; das Schulungsumgebungs-Banner bleibt davon
  unberührt bestehen.

**Echtbetrieb (reale Patienten) — dokumentiert nur.** *(gilt jetzt einheitlich für ALLE Patienten)*
- [x] Umbau vom Vorschlagssystem zur **manuellen Kategoriewahl**: kein
  berechneter, vorbelegter oder hervorgehobener Vorschlag, keine Auto-Zuordnung,
  kein Ranking — die Kategorie ist immer eine aktive Auswahl (`catBig` → `addcat`).
- [x] Untersuchungs-**Anleitungen** im Schema bleiben (z. B. „Rekap < 2 s",
  „Atemwege freimachen") — *wie* untersuchen, nicht *was folgt*; das Schaubild
  zeigt die Logik als Wissen (gedruckte Karte), führt sie aber nicht aus.
- [x] UI-Formulierungen entschärft: „Ergebnis tacSTART"/„Entscheidungs-
  unterstützung"/„geführt" → „Sichtungsschema"/„Kategorie festlegen"; Hinweis
  „Sichtungsentscheidung trifft ausschließlich die Einsatzkraft".

**Technische Kopplung.**
- [x] Die Vorschlagslogik (`R:`-Ergebnisse aus dem `FLOW`-Baum, `vTac()`,
  Handler `tacstart`/`tacanswer`/`tacconfirm`) ist **vollständig entfernt** —
  nicht nur ausgeblendet, sondern aus dem Code gelöscht (stärker als die
  ursprünglich geplante Modus-Bindung; kein Umgehungsverdacht möglich).
- [x] Statisches tacSTART-**Schaubild** (`tacChartSVG()`, reines SVG) als
  Nachschlage-Hilfe im Erfassen-Schritt UND unter Hilfestellungen.
- [x] **Anklickbare Endpunkte** (v0.29.1, Owner-Wunsch): die farbigen
  End-Felder im Schaubild legen die Kategorie an (`addcat`; Einzelfall-Feld →
  T-1/T-5-Wahl). **MDR-Bewertung:** zulässig, weil das Schaubild STATISCH
  bleibt — keine Ja/Nein-Verzweigung, alle Pfade gleichzeitig sichtbar, die App
  rechnet/verzweigt nicht. Der Endpunkt ist funktional ein Kategorie-Knopf an
  der vom Nutzer selbst getracten Stelle (= Dokumentation der menschlichen
  Entscheidung), NICHT die Software, die den Algorithmus ausführt. Abgrenzung
  zur verbotenen Variante: eine *animierte/verzweigende* Flow-Chart, die mit den
  Befunden auf eine Kategorie zuläuft, bleibt ❌. Sitzt näher an der Linie als
  die reine Lese-Karte → einer der Punkte für die optionale BfArM-Abgrenzungs-
  anfrage (MDR-3).

**Absichern.**
- [x] **Qualifikations-Memo**: dieses Dokument + CHANGELOG v0.29.0 dokumentieren
  die Grenzziehung (Art. 2 Nr. 1 MDR / MDCG 2019-11): reine Dokumentation ohne
  Analyse-/Empfehlungsfunktion.
- [x] Drehbuch/Lektionen angepasst (Erfassen-Lektionen: Schaubild + manuelle Wahl).
- [x] **Nicht gebaut:** animierte Flow-Chart Richtung Kategorie, „passende
  Kategorie zuerst", Plausibilitäts-/Abweichungswarnung im Echtmodus — alle
  lösen Regel 11 aus. Echte Laienführung im Ernstfall wäre Pfad C (Zertifizierung
  mit Partner), bewusst als spätere Ausbaustufe, nicht jetzt.

### MDR-3 — Absicherung `optional`
- [ ] Formale **Abgrenzungsanfrage beim BfArM** erwägen (schriftliche
  Bestätigung „kein Medizinprodukt" nach Umsetzung von MDR-2) — stärkstes
  Argument gegenüber Träger/DSB/Lizenznehmern.
- [ ] Bei späterem Bedarf an echter Entscheidungsunterstützung (Pfad C,
  Klasse IIb/III): nur mit institutionellem Partner; Hersteller-Pflichten
  lägen beim Eigentümer → spricht zusätzlich für die UG-Gründung.

## Rechtliche Anker

Art. 2 Nr. 1 MDR (Definition über die **Zweckbestimmung des Herstellers**;
„Behandlung von Verletzungen") · Anhang VIII Regel 11 (Entscheidungs-Software:
IIa/IIb/**III**; „sämtliche andere Software" Klasse I) · Art. 51
(Klassifizierung) · MDCG 2019-11 (Qualifikation von Software; Dokumentation
ohne Auswertung ≠ Medizinprodukt).
