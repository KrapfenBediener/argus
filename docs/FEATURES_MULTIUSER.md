# Mehrgeräte-Features – Detailspezifikation

Diese drei Features sind in der bestehenden App als **lokale, anklickbare Vorschau** vorhanden (Optik & Bedienung final beurteilbar). Hier steht, wie sie in der echten, backend-gestützten Version funktionieren sollen.

---

## 1. Patienten-Sperre (soft lock)

**Ziel:** verhindern, dass zwei Personen gleichzeitig denselben Patienten bearbeiten – ohne komplizierte Merge-Logik.

**Regeln:**
- **Lesen ist für alle immer offen.** Gesperrt wird nur das Bearbeiten.
- Öffnet ein Gerät einen Patienten zum Bearbeiten, setzt es eine Sperre (`lockedBy`, `lockedAt`).
- **Heartbeat:** solange der Patient geöffnet ist, erneuert das Gerät die Sperre regelmäßig (z. B. alle ~10 s). Dadurch wird ein aktiver Bearbeiter **nie** unterbrochen, auch bei langer Bearbeitung.
- **Ablauf:** Bleiben die Lebenszeichen aus (App geschlossen, Absturz, Verbindung weg), gilt die Sperre nach **30 Sekunden** als verwaist und wird automatisch freigegeben.
- Versucht ein zweites Gerät zu bearbeiten, während gesperrt: Hinweis „wird gerade von <Kürzel> bearbeitet", nur Ansicht.

**Bewusste Entscheidung:** Es wird **zunächst nur die Ablauffrist** umgesetzt. Sie greift immer von selbst und braucht keine vorab eingeteilte Rolle – das ist die ausfallsichere Grundlage. Eine **MasterMedic-Override-Funktion** (Sperre vorzeitig brechen) und das saubere „Wegnehmen" beim Vorbesitzer (dessen Ansicht auf nur-lesen setzen) sind **bewusst zurückgestellt** und werden später erörtert.

**Datenfelder:** `patients.lockedBy` (Kürzel/Geräte-ID), `patients.lockedAt` (Zeitstempel). Ablauf-/Heartbeat-Intervall serverseitig bzw. über Zeitvergleich beim Client.

---

## 2. MasterMedic-Rolle

**Ziel:** genau eine verantwortliche Stelle pro CCP, ohne Vorab-Planung (man weiß nie, wer zuerst vor Ort ist).

**Regeln:**
- Das Gerät, das den CCP **eröffnet** (erstes Setzen eines Bediener-Kürzels), **beansprucht die Rolle automatisch**.
- Da das Team einander vertraut, kann die Rolle **jederzeit per Tipp** an ein anderes Gerät übergehen – mit einfacher Bestätigungsabfrage. Kein Login-Aufwand.
- Fällt das MasterMedic-Gerät aus, ist nichts blockiert: ein anderes übernimmt einfach.
- Optional (nicht zwingend): Anzeige „MasterMedic seit X min offline – übernehmen?", wenn dessen Lebenszeichen ausbleiben.

**Darstellung (bereits gebaut):** im Banner des Startbildschirms.
- Bist du es selbst: Abzeichen „★ Du bist MasterMedic".
- Bist du es nicht: „MasterMedic: <Kürzel> · übernehmen" (Link). Tipp → Bestätigungsmodal → Übernahme.
- Noch niemand: „Noch kein MasterMedic · übernehmen".

**Backend:** Rolle als gemeinsamer Status des CCP (z. B. `ccps.master_medic`). Übernahme = atomare Aktualisierung dieses Feldes; alle Geräte sehen die Änderung über die Echtzeit-Subscription.

**Heute in der Vorschau:** Rolle wird lokal gesetzt; Umschalten testbar, indem man über „Bediener ändern" ein anderes Kürzel setzt.

---

## 3. CCPs zusammenführen

**Ziel:** mehrere zunächst getrennte CCPs (oder offline entstandene „Insel-CCPs") zu einer Liste vereinen, ohne Nummern-Chaos.

**Regeln:**
- Jeder CCP hat eine **Kennung** (`A`, `B`, …). Patienten-Identität = Kennung + Nummer (`A-07`).
- **Keine Umnummerierung** beim Zusammenführen – `A-07` und `B-07` bleiben unterscheidbar. Hinterlegte **Fotos** dienen zusätzlich der eindeutigen Zuordnung.
- **Präfix-Anzeige nur, wenn nötig:** solange ein einzelner CCP läuft, wird die nackte Nummer gezeigt; erst nach dem Zusammenführen erscheinen die Buchstaben.
- **Sichtbarkeit:** Der Einstieg „CCPs zusammenführen" ist **nur für MasterMedics sichtbar** (in der Patientenübersicht).
- **Beidseitige Bestätigung:** MasterMedic A startet, wählt CCP B aus der Liste der offenen CCPs; MasterMedic B bekommt auf seinem Gerät eine Anfrage und bestätigt. Erst dann verschmelzen die Listen.
- **MasterMedic nach dem Merge:** Vorschlag als Standard – der **initiierende** (A) bleibt MasterMedic des zusammengeführten CCP; B wird normaler Nutzer und kann die Rolle bei Bedarf wieder übernehmen. (Kleine offene Entscheidung, vor der Umsetzung bestätigen.)

**Heute in der Vorschau:** Beim Zusammenführen wird ein eingebautes Beispiel-CCP **B** lokal injiziert (3 Demo-Patienten), die Präfix-Anzeige aktiviert und alles über „Zusammenführung zurücksetzen" wieder entfernt. In der echten App ersetzt der Backend-Ablauf (echte Liste offener CCPs, echte Bestätigung durch MasterMedic B) diesen Demo-Mechanismus; die `demo`-Patienten und die Injektion entfallen.

**Backend:** Zusammenführen = Patienten der CCPs auf einen gemeinsamen CCP-Kontext beziehen (Kennung bleibt je Patient erhalten). Anfrage/Bestätigung über einen kleinen Status („merge_request") auf den beteiligten CCPs.
