# ARGUS — Änderungsverlauf

Sichtbare App-Version (`APP_VERSION` in `index.html`, in der Fußzeile angezeigt).
Schema: semantisch (`MAJOR.MINOR.PATCH`). Solange Beta: `0.x`.
Frühere Stände vor Einführung der sichtbaren Version liegen in der Git-Historie.

---

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
