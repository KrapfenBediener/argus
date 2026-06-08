# ARGUS — Änderungsverlauf

Sichtbare App-Version (`APP_VERSION` in `index.html`, in der Fußzeile angezeigt).
Schema: semantisch (`MAJOR.MINOR.PATCH`). Solange Beta: `0.x`.
Frühere Stände vor Einführung der sichtbaren Version liegen in der Git-Historie.

---

## v0.19.1 — 2026-06-08
**Training: gPA-Hänger behoben, Checkliste erkundbar, Lila entfernt**
- **Bugfix „Abtransport → gPA" (Lektion hing, Intro ließ sich nicht beenden):** `pushLock` hatte
  als einziger Cloud-Aufruf im Trainingsablauf **keinen Training-Schutz** → im Echtzeit-Modus ein
  Backend-Call für den Übungs-Patienten (Isolations-Leck + möglicher Netz-Hänger, der den Schritt
  blockierte). Jetzt zusätzlich `!p.training`.
- **Checkliste-Einführung:** eigener Schritt „In der Checkliste" — du kannst die Liste in Ruhe
  ansehen und durchscrollen, **bevor** der „Zurück zur Startseite"-Hinweis erscheint (vorher
  überlagerte er sie sofort).
- **Lila entfernt:** das Training nutzt jetzt durchgehend Schiefer (`--acc`) als Chrome und einen
  weiß-umrandeten Schiefer-Spotlight-Ring — design-konform zur ARGUS-Sprache, kein Lila mehr.
- 30 Lektionen; Ablauf-Logik per Probeläufen 18/18 grün.

---

## v0.19.0 — 2026-06-08
**Geführtes Intro komplett neu aufgebaut (sauberes 3-Modus-Modell)**
Die über viele Iterationen gewachsene Intro-Sequenz wurde verworfen und von Grund auf neu gebaut.
Drei klar getrennte Lektions-Modi lösen die wiederkehrenden Symptome (Top-Element abgeschnitten,
„nur ansehen" aber Buttons aktiv, springende Reihenfolge) strukturell:
- **explain** — nur ansehen: Ziel wird hervorgehoben, ist aber **nicht antippbar** (transparenter
  Blocker im Spotlight-Loch); weiter geht es ausschließlich über „Weiter".
- **do** — geführte Aktion: nur das Ziel ist antippbar, Auto-Weiter bei Erledigung.
- **choice** — mehrere gültige Wege: nichts ist blockiert (z. B. Kachel *oder* „Alle Patienten").

Weitere Korrekturen:
- **Scroll-Band an die echte `sticky`-Topbar (~44px) + dynamische Panelhöhe** angepasst. Vorher
  galt eine 56px-Annahme + zu hohe Verdeckungs-Schwelle → die Zähler-Leiste (Top ≈58px) wurde
  fälschlich als „verdeckt" gewertet und unnötig verscrollt/abgeschnitten. Jetzt: scrollt **nur**,
  wenn das Ziel wirklich außerhalb des freien Bands liegt — Top-Elemente bleiben stehen.
- **Strikt von oben nach unten erklärt:** Startbildschirm (Zähler → Status & Bediener → Checkliste →
  Patient erfassen → Patientenübersicht → Hilfe) und Patienten-Detail (Prio → Foto → Kategorie →
  TQ-Timer → Maßnahmen → Verletzungen → Vitalwerte).
- 29 Lektionen; Ablauf-Logik per Probeläufen 17/17 grün.

---

## v0.18.12 — 2026-06-08
**Training: Erst-Zentrieren-Fix, fehlende Highlights ergänzt, mehr Patienten-Funktionen**
- **Erstes Zentrieren je Schritt sitzt jetzt** — eine zusätzliche Nachmessung per
  `requestAnimationFrame` korrigiert das Erst-Paint-Layout (vorher konnte genau das *erste*
  Spotlight daneben liegen, bis ein Re-Render kam).
- **Highlighting dort ergänzt, wo es fehlte:** „Patienten öffnen" (Spotlight auf die Zähler-Leiste,
  **nicht-blockierend** — Kachel *oder* „Alle Patienten" frei wählbar), Übergabekarte
  (A-/M-/Maßnahmen-Zeile) und der **„Zurückholen"-Button**.
- **Neue Erklär-Lektionen für die übrigen Patienten-Funktionen** — Vitalwerte, Maßnahmen (cABCDE),
  Verletzungen, Foto, Kategorie & Prio — je mit Spotlight auf den jeweiligen Abschnitt (vorher
  sprang das Intro vom TQ-Timer direkt zu „transportfertig").
- Neuer nicht-blockierender Spotlight-Modus (`free`) für Schritte mit mehreren gültigen Wegen.
- 25 Lektionen; Ablauf-Logik per Probeläufen 17/17 grün.

---

## v0.18.11 — 2026-06-08
**Training: Scroll auf direktes `scrollTop`, Erklärungen in Einzelschritte**
- **Scroll endgültig auf die simpelste, zuverlässigste Methode:** direktes `scrollingElement.scrollTop`
  (kein `scrollTo`/`scrollIntoView`/`scrollBy` mehr — die hatten auf der iOS-PWA je anders versagt).
  Das Ziel wird mittig in den freien Bereich zwischen Header und Coach-Panel gesetzt; die Markierung
  wird **nach** dem Scroll gemessen → kein Versatz, nichts mehr hinter dem Panel.
- **CCP-Ansicht in Einzel-Erklärungen aufgeteilt:** „die Lage-Zähler" → „Patient erfassen" →
  „Patientenübersicht", je eine Karte mit „Weiter" (statt einer großen Erklärung).
- **„Patienten öffnen"** erklärt jetzt beide Wege: Sichtungs-Kachel (nur diese Kategorie) ODER
  „Alle Patienten"; in der Übersicht kein erzwungener Spotlight mehr.
- **Übergabekarte in 3 Schritten erklärt** (Kopf + A · T/M/I · S/T + warum gesperrt).
- 20 Lektionen; Ablauf-Logik per Probeläufen 20/20 grün.

---

## v0.18.10 — 2026-06-08
**Training: Scroll endgültig robust + mehr Erklärung**
- **Verdeckungs-Erkennung + sauberes Zentrieren:** Der Spotlight prüft jetzt, ob das Ziel hinter
  Header/Panel (oder außerhalb) liegt, und scrollt nur dann — via `scrollIntoView({block:'nearest'})`
  + `scroll-margin` (Header-/Panel-Zone). Rects werden **nach** dem Scroll gemessen → kein Versatz
  mehr (das vorige `window.scrollTo` hatte alle Highlights verschoben).
- **Neue Lektion „Die CCP-Ansicht im Überblick"** direkt nach der CCP-Eröffnung: erklärt die Zähler
  (T-1…T-5, PRIO, gPA) und die Hauptfunktionen, bevor die erste echte Lektion startet.
- **Übergabekarte-Lektion** erklärt jetzt das A/T/M/I/S/T-Schema und warum die Karte gesperrt ist;
  neue Lektion **„Korrigieren: Zurückholen"** (was „↩ Zurückholen → aktiv" bewirkt).
- 15 Lektionen; Ablauf-Logik per Probeläufen 15/15 grün.

## v0.18.9 — 2026-06-08
**Training: gPA-Übergabe integriert, granularer, Scroll endgültig gefixt**
- **Scroll-Fix:** `window.scrollTo(0,y)` (zwei-Argument-Form, iOS-Standalone-PWA-kompatibel) statt
  der Optionen-Form → das Ziel (z. B. „Patientenübersicht") liegt verlässlich zentriert über dem
  Panel, nicht mehr dahinter.
- **„Patient verwalten" granular & forced** aufgeteilt mit Spotlight je Aktion:
  Patient öffnen → **Tourniquet-Timer** → **transportfertig** → **Abtransport → gPA** →
  **Übergabekarte ansehen**. `sel`/`doit` jetzt auch als Funktion (ansichtsabhängig: Kategorie/Patient).
- **gPA-Übergabe + AT-MIST-Kartenansicht** ins forced-Intro integriert (öffnet den ausgecheckten
  Patienten erneut → Vorlese-Karte).
- 13 Lektionen; Ablauf-Logik per Probeläufen 14/14 grün (inkl. „nach Abtransport nicht in die Karte springen").

## v0.18.8 — 2026-06-08
**Training: linearer ("forced") Ablauf + zuverlässiges Zentrieren**
- **Kein freies Vor-/Zurück-Toggeln mehr** — das war die Hauptquelle der Edge-Case-Bugs
  (Toggle × Auto-Weiter × Spotlight-Neupositionierung). Der „‹ Lektion zurück"-Button ist raus.
- Stattdessen je Aufgaben-Schritt ein dezentes **„Schritt überspringen ›"** als Notausgang,
  falls die Auto-Erkennung mal nicht greift.
- **Scroll via nativem `scrollIntoView({block:'center'})`** statt `window.scrollBy` (das auf der
  iOS-Standalone-PWA nicht zuverlässig griff) → das Ziel (z. B. „Patientenübersicht") liegt jetzt
  verlässlich zentriert über dem Panel statt dahinter.
- Probeläufe der Ablauf-Logik inkl. Überspringen: 13/13 grün.

## v0.18.7 — 2026-06-08
**Training: Weiter-Sperre, Ziel zentrieren, Buttons robust**
- **„Weiter" erst frei, wenn die Aufgabe erledigt ist:** Bei Aktions-Schritten ist die Schaltfläche
  gesperrt (grau „Aufgabe erledigen …") — Fortschritt nur durch die Aufgabe (Auto-Weiter). Bei
  manuellen Schritten und im Review ist „Weiter" normal nutzbar.
- **Ziel zentriert beim Ansichts-Rückkehr:** Der Spotlight scrollt jetzt auch, wenn sich das Ziel
  INNERHALB eines Schritts ändert (Übergang „Zurück" → dann „Patientenübersicht") → der Button
  wird mittig über dem Panel angezeigt, nicht mehr dahinter versteckt (`spotKey` statt nur Schritt).
- **Zurück/Weiter robuster:** Button-Klicks werden bei jedem Coach-Render neu verdrahtet (nicht nur
  beim Panel-Neuaufbau) → „‹"-Zurück greift zuverlässig.

## v0.18.6 — 2026-06-08
**Training: Übergangs-Hinweis + getestet**
- **Übergangs-Hinweis** an View-Wechseln: Steht der nächste Schritt auf der Startseite, du bist
  aber noch auf einer Unteransicht, zeigt das Panel „↩ Zurück zur Startseite — dann weiter mit …"
  (statt direkt die nächste Lektion einzublenden). Der ‹-Button wird dabei hervorgehoben.
- **Härtung:** „Patient verwalten"-Bedingung greift nicht mehr auf `p.vit.af` zu, wenn `vit` fehlt
  (defensiv geguardet).
- **Automatisierte Probeläufe** der Ablauf-Logik (Happy Path, Zurück/Review, 2. Start mit offenem
  CCP, Mehrfach-Ketten) — 19/19 grün. Per JavaScriptCore gegen den echten Code geprüft.

## v0.18.5 — 2026-06-08
**Training: Ton, Beenden, Fokus**
- **„Gut gemacht"-Panel entfernt** (war nach jedem Schritt + bevormundend). Stattdessen eine
  dezente, neutrale Kurzbestätigung als Toast („Schritt erledigt ✓") nur bei tatsächlichem
  Fortschritt; Abschluss-Text neutralisiert.
- **Beenden:** Spotlight/Panel werden VOR dem Bestätigungsdialog entfernt → der Dialog liegt
  frei im Vordergrund (nicht mehr hinter der Abdunklung); bei Abbruch wird wiederhergestellt.
- **Fokus erzwungen:** Die Abdunklung **blockiert** jetzt die übrigen Buttons — nur der
  hervorgehobene (für den Schritt relevante) ist tippbar. Panel-Knöpfe (Weiter/Zurück/Beenden)
  bleiben darüber bedienbar; Schritte ohne Spotlight bleiben frei bedienbar.

## v0.18.4 — 2026-06-08
**Training: Zwischenanzeige, Zurück-Funktion, zentrierter Spotlight**
- **„✓ Gut gemacht!"-Zwischenanzeige** nach jedem erledigten Schritt — mit Vorschau auf die
  nächste Lektion und Navigations-Hinweis (z. B. „geh zurück zur Startseite"), dann erst „Weiter".
- **Zurück (‹) funktioniert jetzt:** Review-Modus — wer zurückblättert, wird nicht mehr sofort
  per Auto-Weiter nach vorn geschoben (`_trainMax`-Frontier). Vorwärts wieder bis zur Front.
- **Ziel-Button wird zentriert** in den Bereich *über* dem Panel gescrollt (`trainScrollTo`) —
  nicht mehr hinter der Lektionsanzeige versteckt (z. B. „Übersicht & Lagebild").

## v0.18.3 — 2026-06-08
**Training robuster & lehrreicher**
- **tacSTART-Spotlight** zielt jetzt nur auf den Einstiegs-Button (`.navbtn[data-action="tacstart"]`),
  nicht mehr auf den „nochmal"-Knopf (der dieselbe Aktion trägt) → Patient #2 lässt sich anlegen,
  Auto-Weiter greift. Lektionstext nennt das „Patient anlegen"-Bestätigen.
- **Checkliste** ist jetzt **manuell** (öffnen, abhaken, „Weiter") statt sofort weiterzuspringen.
- **Definierter Einstieg:** Start setzt die Ansicht passend (Home, wenn CCP offen; sonst Start) →
  zuverlässiger zweiter Durchlauf ohne Schulungs-Reset.
- „Wechsle zur Ansicht"-Hinweis nur noch bei Auto-Lektionen (manuelle zeigen ihn nicht).
- Lektionstexte überarbeitet — erklären jeweils kurz das *Warum*, sodass das Intro allein zum
  Einarbeiten reicht.

## v0.18.2 — 2026-06-08
**Training: zwei Bugfixes**
- **Auto-Weiter blieb nach „Checkliste" hängen:** Lektionen, deren Ziel auf der Startseite
  liegt (`home:true`), leuchten jetzt erst den **„‹ Zurück"-Button** an, wenn man auf einer
  Unteransicht ist — so führt der Spotlight sauber zurück und weiter. Panel-Schlüssel
  berücksichtigt den Hinweistext (kein „eingefrorener" Hinweis mehr).
- **Tutorial klebte nach App-Neustart:** Training wird **nicht mehr** über den Neustart
  fortgeführt (Boot setzt `_training` zurück, localStorage-Flags entfernt). Ein **frischer
  Start** räumt verwaiste Übungsdaten ab und beginnt bei Lektion 1.

## v0.18.1 — 2026-06-08
**Training jetzt interaktiv (Spotlight + Auto-Weiter)**
- Statt des kleinen Textfelds: großes Anweisungs-Panel + **Spotlight** auf das jeweilige
  Ziel-Element (4 Abdunkel-Rechtecke um das Element, robust ohne z-index-Tricks).
- **Auto-Weiter:** die Lektion springt automatisch weiter, sobald ihr Ziel-Zustand
  erreicht ist (CCP eröffnet, Patient angelegt, ausgecheckt …) — via `trainCheckAdvance`.
- Ziel-Erkennung über stabile `data-action`/`data-view`-Selektoren (nicht Pixel) → bricht
  nicht bei jeder UI-Änderung; Scroll/Resize halten den Spotlight in Position.
- „Beenden" räumt Spotlight, Panel und Übungsdaten ab. Kein „Was ist neu"-Popup (Verfeinerung).

## v0.18.0 — 2026-06-08
**Geführtes Training (Schulungsumgebung)**
- Neuer **opt-in Übungsmodus**: ein Drehbuch-Coach (`renderCoach`, `TRAIN_LESSONS`) führt
  Schritt für Schritt durch den Kern-Ablauf (CCP eröffnen → Checkliste → Erfassen →
  tacSTART → Verwalten → Übersicht → Prio → Auscheckung/Übergabekarte).
- **Geräte-lokaler Sandbox:** in `_training` erstellte/bearbeitete Patienten tragen
  `training:true` → werden NIE synchronisiert (wie `demo`). Single-user, beliebig viele
  gleichzeitig, kein Fremd-Reset, keine Verschmutzung echter/geteilter Daten.
- Einstieg **automatisch über die Schulungsumgebung** (Button „🎓 Geführtes Training").
- Coach als eigenständiges Fixed-Overlay, Aufruf in `try/catch` → kann den App-Render
  nie brechen. „Beenden" entfernt die Übungsdaten lokal.
- Datenschicht an 5 Stellen `training` wie `demo` behandelt (addPatient, savePatient,
  flushPendingPatients, loadPatients ×2) — der Nicht-Trainings-Pfad bleibt unverändert.
- Update-Sheet `docs/UPDATE_v0.18.html`, in `UPDATE_SHEETS` registriert.

## v0.17.2 — 2026-06-08
**Fußzeile auch auf der Präsidien-Auswahl/Freischalt-Seite**
- `vPraesidium()` (First Page: Präsidium auswählen/freischalten) zeigt jetzt ebenfalls
  die einheitliche Fußzeile (`appFooter()`): Version · Neuerungen · ©.
  (v0.17.1 hatte sie nur auf dem „Kein Zugang"- und dem Landing-Screen.)

## v0.17.1 — 2026-06-08
**„Neuerungen" auf der Startseite vor dem Login**
- Volle Fußzeile (Version · Neuerungen · ©) jetzt auch auf der First Page (`vLocked`,
  „Kein Zugang"-Screen) — „Neuerungen" (inkl. Sheet-Link) ist damit schon vor dem
  Freischalten erreichbar.
- Fußzeile in `appFooter()` zusammengeführt → eine Quelle für Version/Neuerungen/©.
- Kein „Was ist neu"-Popup, kein eigenes Sheet (zu klein).

## v0.17.0 — 2026-06-08
**AT-MIST-Übergabekarte bei Auscheckung**
- Ausgecheckte Patienten (gPA) zeigen im Detail statt des Formulars eine gesperrte
  **Vorlese-Karte** in AT-MIST-Reihenfolge (neue `vHandover()`): Kopf (Nr · Kategorie ·
  PRIO) → A · T (auto: TQ-Dauer + „erfasst vor …") → M (aus MOI/Unfallhergang) →
  I (Verletzungen) → S (Befund) → T (Maßnahmen).
- **Bearbeitung gesperrt** (eingefrorener Snapshot); „↩ Zurückholen → aktiv" zum Korrigieren.
- **Vitalwerte:** nur erhobene Werte; keine → „Keine Vitalwerte erhoben". PFC-Verlauf
  (protokollierte Messungen) als einklappbarer Block, Default zu — Default später je nach RD-Rückmeldung.
- Reine Darstellung vorhandener Daten — nichts wird übertragen (kein Drittsystem/PZC/QR);
  Pseudonymität & Systemgrenze „ARGUS endet an der Übergabe" gewahrt, MDR-neutral.

## v0.16.2 — 2026-06-06
**„Verletzungen" entschlackt**
- Symbol-Spalte (`O/#/X/B`) vor jedem Verletzungseintrag entfernt — der Klartext
  („Region – Art", z. B. „Arm re – Amputation") stand ohnehin daneben.
- Zugehörige **Legende** „O = Wunde · # = Fraktur · X = Amputation · B = Verbrennung" entfernt.
- Aufgeräumt: ungenutzte `artCode()`-Funktion entfernt; `ARTS` auf reine Namensliste
  reduziert, Dropdown-Befüllung angepasst. Erfassung (Region + Art) unverändert.

## v0.16.1 — 2026-06-05
**Qualitäts-Review — kleine Härtungen (intern)**
- `whatsNewModal`: lokale Variable `sb` umbenannt (überschattete die globale
  Supabase-`sb()`-Funktion; war hier folgenlos, aber Footgun).
- `codeFromText` robuster: erkennt Link / Code-mit-Bindestrich / reinen 8-Zeichen-Code;
  greift bei eingefügten Sätzen nicht mehr daneben.
- Mehrgeräte-/Sperr-/Offline-Logik geprüft — unverändert in Ordnung.

## v0.16.0 — 2026-06-05
**AVPU → WASB (deutsche Bewusstseinslage)**
- Vitalwerte-Feld von AVPU auf **WASB** umgestellt (Wach · Ansprechbar · Schmerzreiz ·
  Bewusstlos), Dropdown mit deutschen Bezeichnungen, Verlaufs-Zeile „WASB …".
- Demo-Daten (`DEMO_CCPS`, `genDemoRows`) auf WASB.
- **Einmalige Daten-Migration** bestehender Patienten (atomar, CASE): A→W, V→A,
  P→S, U→B. Verifiziert (W=18, A=7, S=4, B=1, leer=9). Keine Verlaufs-Einträge betroffen.
- Hinweis: das interne Feld heißt weiterhin `vit.avpu` (nur Werte/Anzeige deutsch).

## v0.15.1 — 2026-06-05
**Zeitanzeigen mit Stunden-Überlauf (Tester-Feedback)**
- `ageStr` (Zeit seit letzter Sichtung im CCP): zeigt ab 60 min „vor H Std M min"
  statt „vor 125 min".
- `fmtDur` (TQ-Timer): zeigt ab 1 h „H:MM:SS" (z. B. 2:05:30) statt „125:30".

## v0.15.0 — 2026-06-04
**Schulung: „Zurücksetzen" nur bei Veränderung**
- Der Button „🎓 Schulung zurücksetzen" ist im **Originalzustand ausgeblendet** und
  erscheint nur, wenn die Schulungsumgebung verändert wurde (`loadSchulDirty`).
  Erkennung serverseitig: Originalzustand = 6 CCPs A–F (unmerged/offen, Demo-Master-
  Medics) + nur Demo-Patienten (id-Präfix `seed`, aktiv, ohne Name). Bei
  unbekanntem Zustand (offline) wird der Button vorsichtshalber gezeigt.

## v0.14.1 — 2026-06-04
- Admin-Panel: „📋 Code"-Button wieder entfernt — der kopierte Link + „📋 Einfügen"
  in der App reicht aus. Nur noch Dauerhaft-Link + Einmal-Link.
- Roadmap-Notiz (Phase 9): native App könnte Deep-Links direkt öffnen + Code
  automatisch einlösen → PWA-Onboarding bewusst minimal halten.

## v0.14.0 — 2026-06-04
**Freischaltung vereinfacht + Code-Typen reduziert**
- **Code-Typen auf 2 reduziert:** „Dauerhaft-Link" + „Einmal-Link (24 h)". Der
  wiederverwendbare 24-h-Code (am wenigsten kontrolliert/streute) ist raus.
- **Admin: „📋 Code"** kopiert den bloßen Dauerhaft-Code (für bereits installierte
  Nutzer) — Link bleibt für neue Geräte.
- **App: „📋 Einfügen"** am Freischalt-Feld liest die Zwischenablage und erkennt
  sowohl einen bloßen Code als auch einen ganzen Link → kein Abtippen mehr.
  (`doUnlock()` ausfaktoriert, von checkunlock + pastecode genutzt.)

## v0.13.1 — 2026-06-04
**Zwei Fehler am Update-Sheet behoben**
- Sheet-Link erschien **immer** (globale `UPDATE_SHEET`) → jetzt `UPDATE_SHEETS` je
  Zielversion; der Link erscheint nur, wenn diese Version zum tatsächlichen
  Versionssprung gehört (kein bereits durchlaufenes Sheet mehr). Meta-Eintrag
  `WHATS_NEW['0.13.0']` entfernt.
- Sheet ließ sich in der iOS-Standalone-PWA **nicht schließen** (`target=_blank`
  navigierte im PWA-Fenster, keine Zurück-Leiste). Jetzt öffnet es in einem
  **In-App-Overlay (iframe) mit „✕ Schließen"** (`openSheetOverlay`).

## v0.13.0 — 2026-06-04
**Update-Sheet verlinkt**
- Die „Was ist neu"-Anzeige (Auto-Popup + „Neuerungen"-Button) verlinkt jetzt auf die
  **visuelle Update-Übersicht** (`UPDATE_SHEET`). Konvention: bei jedem relevanten
  Update ein Sheet unter `docs/` anlegen und `UPDATE_SHEET` setzen.

## v0.12.2 — 2026-06-04
**MDR-Hinweis (dezent)**
- Kleiner, grauer Hinweis „tacSTART ist eine Entscheidungsunterstützung – kein
  Ersatz für die ärztliche/fachliche Beurteilung" am **tacSTART-Ergebnis** (Wirkort)
  und in den **Hilfestellungen** (Dokumentation). So offen wie nötig, so unauffällig
  wie möglich; kein Pop-up/Banner. Stützt die Einordnung als Hilfs-/Doku-Werkzeug.

## v0.12.1 — 2026-06-04
**Kurzanleitung-Feinschliff**
- Hilfestellungen jetzt auch **vor** dem CCP-Eröffnen erreichbar (Button auf der
  CCP-Startseite) — löst das Henne-Ei-Problem („wie eröffne ich einen CCP?").
- Kurzanleitung klappt **nicht mehr von selbst zu**: `help`-Ansicht vom 3,5-s-
  Auto-Refresh ausgenommen.
- Punkt „Installieren" aus der In-App-Kurzanleitung entfernt (sichtbar erst nach
  Installation; bleibt im verteilbaren `docs/TESTER-ANLEITUNG.md`).
- Back aus „Hilfestellungen" führt kontextabhängig zurück (CCP offen → Home, sonst
  Startseite).

## v0.12.0 — 2026-06-04
**Kurzanleitung in der App**
- Hilfestellungen enthalten jetzt einen auf-/zuklappbaren Abschnitt „Kurzanleitung"
  (Installieren, CCP eröffnen/beitreten, Erfassen, Verwalten, Abtransport,
  Mehrgeräte, Offline/Updates) — Inhalt aus `docs/TESTER-ANLEITUNG.md`, jederzeit
  offline im Gerät verfügbar.

## v0.11.1 — 2026-06-04
**Erfassungs-Bestätigung als dezenter Flash**
- Beim Anlegen (direkt + tacSTART) erscheint kurz eine zentrierte, **nicht-
  blockierende** Bestätigung „✓ Nr. X · T-Y" (`flashConfirm`, verblasst nach
  ~0,8 s, `pointer-events:none`) statt des kleinen Toasts. Der „zuletzt angelegt"-
  Block unten bleibt unverändert. (Kein „Was ist neu"-Popup, da selbsterklärend.)

## v0.11.0 — 2026-06-04
**Foto-Vollbild**
- Patientenfoto antippen → Vollbild-Overlay (`photozoom`), erneut tippen schließt.
  Glove-tauglich statt umständlichem Seiten-Pinch-Zoom; Pinch im Vollbild bleibt
  für Detailbetrachtung möglich.

## v0.10.1 — 2026-06-04
**Doppeltipp-Zoom unterbinden**
- `touch-action: manipulation` global → kein versehentliches Hineinzoomen beim
  (Doppel-)Tippen mehr (ergänzt die Doppeltipp-Sperre aus v0.10.0). Pinch-Zoom
  und Scrollen bleiben erhalten.

## v0.10.0 — 2026-06-04
**Schnellaktionen beim Erfassen + Schutz vor Fehlerfassung**
- **Neu:** Am „zuletzt angelegt"-Patienten zusätzlich **TQ-Timer starten/stoppen**
  (`captq`) und **Verwerfen** (`capdiscard`) — neben Prio und öffnen. „Verwerfen"
  löscht einen frisch/versehentlich erfassten Patienten sofort; hat er bereits
  Eingaben, kommt eine Sicherheitsabfrage.
- **Neu:** **Doppeltipp-Sperre** (~0,7 s) bei der Erfassung — verhindert, dass ein
  zu schneller Doppeltipp zwei Patienten anlegt. Kein Bestätigungsdialog (Feld-Tempo
  bleibt erhalten).

## v0.9.2 — 2026-06-04
**Kosmetik**
- App-Icon auf der Startseite ohne Schlagschatten — einheitlich „clean" wie auf
  der Präsidienauswahl. (Kein „Was ist neu"-Popup, da rein optisch.)

## v0.9.1 — 2026-06-04
**Verfeinerungen rund um Verbünde**
- **Behoben:** „CCP beitreten" listete zusammengeführte CCPs einzeln. Jetzt werden
  Mitglieder eines Verbunds (gleiche `merge_group_id`) zu **einem** Eintrag
  („Verbund A+B+C", N CCPs) gebündelt; Beitreten verbindet mit dem Verbund.
- **Geändert:** Lösch-Button ist nicht mehr doppelt — bei einem Verbund steht
  „Ganzen Verbund löschen", bei einem originären CCP „CCP löschen".

## v0.9.0 — 2026-06-04
**Verbund löschen (MasterUser-Token)**
- **Neu:** Ist der aktuelle CCP Teil eines zusammengeführten Verbunds, kann ein
  MasterUser-Token-Inhaber „Ganzen Verbund löschen" — entfernt alle CCPs des
  Verbunds (`merge_group_id`) inkl. Patienten (CASCADE), mit Bestätigung, die
  Anzahl CCPs + Patienten anzeigt. Löschen bleibt MasterUser-Token-exklusiv;
  Abschließen weiterhin MasterMedic.
- **Behoben (Folge):** Nach dem Löschen eines Verbunds tauchen die Verbund-CCPs
  nicht mehr unter „CCP beitreten" auf (vorher blieben Merge-Partner als
  beitretbare Reste übrig).

## v0.8.1 — 2026-06-04
**Korrekturen (Tester-Feedback)**
- **Behoben:** „Alle Patienten" war doppelt (CCP-Hauptmenü + Patientenübersicht) —
  jetzt nur noch unter „Patientenübersicht".
- **Behoben:** Nach dem Löschen/Abschließen von CCPs wurde der Zähler offener CCPs
  nicht aktualisiert → „CCP beitreten" blieb sichtbar, bis man das Präsidium verließ
  und neu betrat. Jetzt wird `loadOpenCcpCount()` direkt nach Löschen/Abschließen
  aufgerufen.
- **Hinweis (kein Bug):** Beim Löschen eines zusammengeführten CCP bleiben die
  übrigen Merge-Partner bestehen (eigene CCPs mit eigenen Patienten) und erscheinen
  weiter in „CCP beitreten". In der Schulung leert „Schulung zurücksetzen" alles.

## v0.8.0 — 2026-06-04
**Erst-Einführung (Onboarding)**
- **Neu:** Bei einer echten Neuinstallation erscheint eine kurze, überspringbare
  Einführung (4 Karten, Button-Navigation — kein Swipe, gem. „keine versteckten
  Gesten"). Jederzeit erneut aufrufbar über „Hilfestellungen → Einführung erneut
  ansehen".
- **Erkennung:** `argus_intro_seen` (pro Gerät). Erstinstallation wird am leeren
  localStorage erkannt — eine spätere Freischaltung für ein weiteres Präsidium löst
  das Intro NICHT erneut aus. Bestehende Nutzer bekommen beim Update auf 0.8.0
  kein Intro (nur stilles Markieren), sondern den „Was ist neu"-Hinweis.

## v0.7.0 — 2026-06-04
**Paket C (Teil): Vitalwerte-Verlauf**
- **Neu:** „Messung protokollieren" im Patientendetail friert die aktuellen
  Vitalwerte (AF/SpO₂/HF/RR/AVPU/Schmerz) mit Uhrzeit + Kürzel als Eintrag ein —
  für längere Versorgung / Prolonged Field Care [Schill]. Bewusst schlank: ein
  Knopf, der Verlauf ist eingeklappt (`<details>`), stört den Normalfall nicht.
  Speicherung in `vit.log` (kein DB-Schema-Eingriff).
- **De-scoped:** C2 (Neuro-Feld) bleibt unverändert; C3 (Funktionsanzeige am CCP)
  gestrichen — bei überschaubaren Teams kennt jeder seine Rolle (Owner-Entscheid).

## v0.6.0 — 2026-06-04
**Update-Kommunikation: kumulative Neuerungen + „Neuerungen"-Button**
- **Neu:** „Was ist neu"-Hinweis zeigt jetzt **alle** Versionen, die seit der zuletzt
  gesehenen dazugekommen sind (kumulativ) — wer mehrere Updates verpasst hat, sieht
  alle relevanten Neuerungen gruppiert, nicht nur die letzte.
- **Neu:** dezenter „Neuerungen"-Link in der Startseiten-Fußzeile — öffnet die
  letzten Änderungen jederzeit auf Wunsch (kein vollständiger Versionsverlauf).
- Intern: `cmpVer()` (Semver-Vergleich); `whatsNewModal(sinceV, recentCap)`.

## v0.5.2 — 2026-06-04
**Fix: Bearbeitungssperre gibt zuverlässig frei**
- **Behoben:** Der wartende Nutzer prüfte die Sperre nie erneut — sie blieb auch
  nach Ablauf der 45 s bestehen, und wenn der Bearbeiter den Patienten verließ,
  musste der Wartende ebenfalls raus und neu öffnen.
- **Neu/Verhalten:** Der Heartbeat behandelt jetzt beide Rollen. Wird die Sperre
  frei (Bearbeiter verlässt den Patienten **oder** 45 s ohne Lebenszeichen), übernimmt
  der Wartende **automatisch** (Realtime sofort, sonst per Heartbeat ≤5 s) — ohne den
  Patienten neu öffnen zu müssen. Hinweistext im Schreibschutz angepasst.

## v0.5.1 — 2026-06-04
**Fix: Update-Auslieferung (iOS-PWA blieb auf alter Version)**
- **Behoben:** Service-Worker-Revalidierung wird per `event.waitUntil` am Leben
  gehalten — iOS beendete den SW bisher direkt nach Auslieferung der gecachten
  Seite, sodass der Cache nie aktualisiert wurde (App blieb auf alter Version).
- **Neu:** zuverlässige Update-Erkennung über `version.json` (network-only),
  geprüft beim Start und bei jedem Sichtbarwerden (deckt iOS-Resume ab) → dezenter
  Banner „Neue Version verfügbar — Jetzt aktualisieren" (nutzer-initiiert, keine
  Unterbrechung mitten in der Bearbeitung). Entspricht dem zurückgestellten
  „Bitte-aktualisieren"-Anstoß (3b).
- **Wartung:** `version.json` muss bei jedem Release gleich `APP_VERSION` gesetzt werden.

## v0.5.0 — 2026-06-04
**Paket B: Erfassungs-Flow + Versions-Hinweis (Tester-Feedback)**
- **Neu:** Erfassungs-Screen zeigt die **nächste Nummer** und den **zuletzt
  angelegten Patienten** (Nr. + Kategorie) dauerhaft an — beugt Doppelerfassung vor
  (ergänzt die Doppelnummer-Warnung um Vorbeugung). [Braunbeck #1]
- **Neu:** Schnellaktionen am zuletzt angelegten Patienten direkt auf dem
  Erfassungs-Screen: **Prio** setzen ohne Navigation [Zobel #8], **öffnen** springt
  in die Details [Braunbeck #2]. Der schnelle Standardfall (Kategorie antippen =
  fertig) bleibt unverändert.
- **Neu:** „Was ist neu"-Hinweis — einmaliger, wegklickbarer Hinweis nach einem
  Update mit kurzen, nutzerverständlichen Highlights (`WHATS_NEW`). Voller
  technischer Verlauf bleibt hier im CHANGELOG.

## v0.4.0 — 2026-06-04
**Paket A: Erreichbarkeit & Mehrgeräte-Sicherheit (Tester-Feedback)**
- **Neu:** „Alle Patienten" — flache, anklickbare Gesamtliste (Startseite + Übersicht).
- **Neu:** PRIO- und gPA-Zähler sind jetzt anklickbar und öffnen die jeweilige Liste.
- **Neu:** Abtransportierte Patienten (gPA) lassen sich wieder aufrufen und per
  „↩ Zurückholen → aktiv" in den aktiven Bestand zurückholen (Korrektur von
  Fehl-Auscheckungen).
- **Behoben:** Soft-Lock-Übernahme durch MasterMedic — der bisherige Bearbeiter
  wird jetzt sofort (Echtzeit) bzw. binnen ~5 s schreibgeschützt und kann die
  Sperre nicht mehr durch Weitertippen zurückerobern (Sperr-Spalten getrennt von
  der Datenspeicherung).
- **Neu:** sichtbare App-Version in der Fußzeile; dieses CHANGELOG.

## v0.3.x — 2026-06-04 (vor sichtbarer Versionierung)
- Offline-Robustheit: offline erfasste/bearbeitete Patienten gehen beim Reconnect
  nicht mehr verloren (lokale Markierung + Merge per Zeitstempel + Nachsync).
- Doppelnummer-Warnung bei parallel vergebenen Laufnummern.
- Schreibweise „Argus" → „ARGUS".

## v0.2.x — 2026-06-03 (vor sichtbarer Versionierung)
- Phase 4: serverseitige Absicherung — Token-Tausch (Code → JWT via RPC,
  pgjwt+Vault), RLS pro Präsidium, Lockdown der `access_tokens`-Tabelle.

## v0.1.0 — 2026-06-03 (vor sichtbarer Versionierung)
- Proprietäre Lizenz/Copyright; Phasen 0–3 (PWA-Hülle, Supabase-Backend,
  Join-Flow, Mehrgeräte-Features) — siehe Git-Historie / `.planning/ROADMAP.md`.
