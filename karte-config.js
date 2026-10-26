/* © 2026 Gabor Szeman – Alle Rechte vorbehalten. Proprietär, Nutzung nur mit Genehmigung. */
/* ARGUS — Kartenmodul („Passform“) der FLZ-Lageübersicht
 *
 * ZWECK
 *   Diese Datei legt fest, von welchem Kartendienst die FLZ-Seite die
 *   Hintergrundkarte (Straßenkarte) unter den CCP-Punkten lädt. Sie ist die
 *   EINZIGE Stelle, an der ein Kartendienst eingetragen wird — die Seite selbst
 *   enthält keine Kachel-Adresse. Die Feld-App (index.html) nutzt keine Karte
 *   und lädt diese Datei nicht.
 *
 *   Vorläufig ist OpenStreetMap eingetragen. Vor der Übergabe an eine Behörde
 *   trägt diese hier ihren eigenen Kartendienst ein ODER schaltet die Karte ab.
 *
 * EIGENEN KARTENDIENST EINTRAGEN (XYZ-/„Slippy-Map“-Kacheln)
 *   kachelUrl  Adresse der Kacheln mit den Platzhaltern {z} (Zoomstufe),
 *              {x} und {y} (Kachelspalte/-zeile), z. B.
 *                'https://karten.behoerde.example/kacheln/{z}/{x}/{y}.png'
 *              Optional {s} für Subdomains (a/b/c). Nur https:// oder ein
 *              Pfad auf demselben Server ('/kacheln/{z}/{x}/{y}.png').
 *   quelle     Quellen-/Lizenzhinweis, wird unten rechts in der Karte
 *              angezeigt (Pflicht — ohne Quellenhinweis keine Karte).
 *   quelleUrl  Optional: Verweis auf die Lizenz-/Nutzungsbedingungen.
 *   maxZoom    Höchste Zoomstufe, die der Dienst liefert (1–22).
 *   referrerPolicy  Optional: 'origin' (Standard — der Dienst erfährt nur die
 *              Server-Adresse, nie den Seitennamen) oder 'no-referrer'.
 *
 *   WMS/WMTS: Dienste, die nur WMS (GetMap) oder WMTS mit eigener
 *   Kachelmatrix anbieten, werden derzeit NICHT unterstützt. Viele
 *   Geodatendienste bieten zusätzlich eine XYZ-Schnittstelle in Web-Mercator
 *   (EPSG:3857) an — diese hier eintragen. Eine WMS-Erweiterung ist möglich
 *   (Leaflet bringt L.tileLayer.wms mit) und wäre eine spätere Ergänzung.
 *
 * KARTE ABSCHALTEN
 *   window.ARGUS_KARTE = null;
 *   Dann zeigt die FLZ-Seite automatisch die schematische Lageskizze (ohne
 *   jeden Abruf bei einem Kartendienst). Dasselbe gilt, wenn diese Datei fehlt
 *   oder ein Eintrag ungültig ist, und wenn der Dienst nicht erreichbar ist.
 *
 * DATENSCHUTZ
 *   Beim Anzeigen der Karte ruft der Browser des FLZ-Rechners Kartenkacheln
 *   direkt beim eingetragenen Dienst ab. Der Dienst sieht dabei die IP-Adresse
 *   des Rechners und den angezeigten Kartenausschnitt (damit ungefähr den
 *   Einsatzort). Patientendaten, Zahlen, CCP-Kennungen oder Ortsnamen werden
 *   NICHT übermittelt — die Punkte und Beschriftungen zeichnet die Seite selbst.
 *   Ist die Passform leer (null), findet keine Übermittlung statt.
 *
 * OPENSTREETMAP-NUTZUNGSBEDINGUNGEN (solange OSM eingetragen ist)
 *   - Quellenhinweis „© OpenStreetMap-Mitwirkende“ mit Verweis auf
 *     https://www.openstreetmap.org/copyright ist Pflicht (ist eingetragen).
 *   - Maßvolle Nutzung: Die Kachel-Server der OSM Foundation sind ein
 *     Spendenangebot ohne Zusage zu Verfügbarkeit oder Last. Für einen
 *     dauerhaften Behördenbetrieb einen eigenen bzw. vertraglich gesicherten
 *     Kartendienst eintragen (Tile Usage Policy:
 *     https://operations.osmfoundation.org/policies/tiles/).
 *   - Kein Vorabladen/Massenabruf; die Seite lädt nur den sichtbaren Ausschnitt.
 *
 * Hier stehen nur öffentliche Werte — keine Zugangsschlüssel eintragen, die
 * geheim bleiben müssen (diese Datei wird an jeden Browser ausgeliefert).
 */
window.ARGUS_KARTE = {
  kachelUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  quelle: '© OpenStreetMap-Mitwirkende',
  quelleUrl: 'https://www.openstreetmap.org/copyright',
  maxZoom: 19
};
