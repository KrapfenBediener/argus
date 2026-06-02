# Testprotokoll — Phase 0: Repo-Struktur & Offline-Hülle

**Tester:** _______________  
**Datum:** _______________  
**Gerät:** iPhone (Modell: _______________, iOS: _______________)  
**Gesamtergebnis:** ☐ BESTANDEN  ☐ FEHLGESCHLAGEN

---

## Vorbereitung

Vor dem Test: App über HTTPS ausliefern (Service Worker benötigt HTTPS oder localhost).

**Option A — Netlify Drop (empfohlen für ersten Test):**
1. `index.html` und `sw.js` in einen Ordner legen
2. [netlify.com/drop](https://app.netlify.com/drop) öffnen → Ordner hineinziehen
3. Generierte HTTPS-URL notieren: ___________________________

**Option B — Lokaler HTTPS-Server:**
```bash
python3 -m http.server 8080
# Dann: http://localhost:8080/index.html (localhost gilt als sicher für SW)
```

---

## Prüfpunkt 1 — App startet und sieht identisch aus ✓

**Was prüfen:** `index.html` verhält sich visuell und funktional identisch zur Legacy-HTML.

| # | Prüfschritt | Erwartet | Ergebnis |
|---|-------------|----------|----------|
| 1.1 | URL im Safari öffnen | CCP-Startbildschirm mit Zählerleiste erscheint | ☐ ok ☐ Fehler |
| 1.2 | IBM Plex Schrift sichtbar | Schrift korrekt geladen (nicht System-Fallback) | ☐ ok ☐ Fehler |
| 1.3 | Uhr oben rechts läuft | Aktuelle Uhrzeit wird angezeigt und tickt | ☐ ok ☐ Fehler |
| 1.4 | Bediener-Kürzel setzen | Prompt erscheint → Kürzel eingeben → erscheint im Banner | ☐ ok ☐ Fehler |
| 1.5 | Patient erfassen | Patient #1 anlegen (T-1) → in Übersicht sichtbar | ☐ ok ☐ Fehler |
| 1.6 | Reload | Patient #1 noch vorhanden (localStorage) | ☐ ok ☐ Fehler |

**Notizen:** _______________________________________________________________

---

## Prüfpunkt 2 — Service Worker registriert sich ✓

**Was prüfen:** `sw.js` wurde korrekt registriert.

| # | Prüfschritt | Erwartet | Ergebnis |
|---|-------------|----------|----------|
| 2.1 | Safari DevTools → Application → Service Workers | Service Worker für diese URL gelistet, Status "activated" | ☐ ok ☐ Fehler |
| 2.2 | Console im Browser | Keine roten Fehler zu sw.js | ☐ ok ☐ Fehler |

> **Hinweis:** Safari DevTools auf dem iPhone: über Mac mit `Entwickler > iPhonename > Safari` verbinden.  
> Alternativ: Browser-Konsole auf dem Mac (localhost) prüfen.

**Notizen:** _______________________________________________________________

---

## Prüfpunkt 3 — App startet offline vom Home-Bildschirm ✓

**Was prüfen:** Die App-Hülle lädt ohne Netzverbindung (Service Worker Cache).

| # | Prüfschritt | Erwartet | Ergebnis |
|---|-------------|----------|----------|
| 3.1 | App zu Home-Bildschirm hinzufügen: Safari → Teilen → „Zum Home-Bildschirm" | App-Icon erscheint auf Home-Screen | ☐ ok ☐ Fehler |
| 3.2 | App vom Home-Bildschirm öffnen | Läuft im Vollbild (keine Safari-Leiste) | ☐ ok ☐ Fehler |
| 3.3 | iPhone in Flugzeugmodus versetzen | Kein WLAN, kein Mobilfunk | ☐ ok ☐ Fehler |
| 3.4 | App schliessen und neu öffnen (Home-Screen-Icon) | App startet — zeigt CCP-Startbildschirm | ☐ ok ☐ Fehler |
| 3.5 | Vorher erfasster Patient sichtbar? | Patient #1 noch vorhanden (aus localStorage) | ☐ ok ☐ Fehler |
| 3.6 | Neuen Patienten anlegen offline | Patient #2 anlegen → wird gespeichert (localStorage) | ☐ ok ☐ Fehler |
| 3.7 | Flugzeugmodus aus | App läuft weiterhin normal | ☐ ok ☐ Fehler |

**Notizen:** _______________________________________________________________

---

## Prüfpunkt 4 — Supabase CDN geladen (nicht initialisiert) ✓

**Was prüfen:** Das Supabase-Script ist eingebunden, aber die App verhält sich genau wie vorher.

| # | Prüfschritt | Erwartet | Ergebnis |
|---|-------------|----------|----------|
| 4.1 | Browser-Konsole prüfen: `window.supabaseLib` | Gibt Supabase-Objekt zurück (kein undefined) | ☐ ok ☐ Fehler |
| 4.2 | Konsole: `window.supabaseLib === window.supabase` | Gibt `true` zurück | ☐ ok ☐ Fehler |
| 4.3 | Konsole: kein Fehler zu `createClient` | Kein Fehler in der Konsole | ☐ ok ☐ Fehler |
| 4.4 | App-Verhalten unverändert | Keine neuen Fehler, keine veränderte UI | ☐ ok ☐ Fehler |

**Notizen:** _______________________________________________________________

---

## Zusammenfassung

| Prüfpunkt | Ergebnis |
|-----------|----------|
| 1 — App startet identisch | ☐ PASS ☐ FAIL |
| 2 — SW registriert | ☐ PASS ☐ FAIL |
| 3 — Offline-Start | ☐ PASS ☐ FAIL |
| 4 — Supabase CDN (nicht initialisiert) | ☐ PASS ☐ FAIL |

**Gefundene Probleme:**

| # | Beschreibung | Schwere | Behoben am |
|---|-------------|---------|------------|
| | | | |

---

## Freigabe Phase 0

☐ Alle Prüfpunkte bestanden — **Phase 0 freigegeben für Phase 1 (Backend & Sync)**

Unterschrift/Kürzel: _______________ Datum: _______________
