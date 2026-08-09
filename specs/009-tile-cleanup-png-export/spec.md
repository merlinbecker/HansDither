# Feature Specification: Tile-Bereinigung, projektbasierte Dateibenennung und PNG-Export im Backend

**Feature Branch**: `feature/0.3`

**Created**: 2026-08-09

**Status**: Draft

**Input**: User description: "wir muessen folgende Aenderungen vornehmen:
- beim speichern der tiles in das pdi file muss geprueft werden, ob sich nicht genutzte tiles darin befinden (ueber alle frames hinweg). diese muessen dann entfernt werden und die indizes der restlichen tiles muessen aktualisiert werden.

- im backend muss jeder frame als png gerendert werden , die option des pdi downloads sollte nicht mehr angeboten werden, die tilemap sollte auch als png in der entsprechenden namens konvention vom playdate sdk erfolgen (also <name>-table-<w>-<h>)

- nenne die Dateien im Backend auch nach dem Projektnamen auf dem playdate und nicht nach einer random id"

## Clarifications

### Session 2026-08-09

- Q: Wie sollen die pro-Frame-PNGs im Backend bereitgestellt werden (Download/Anzeige)? → A: Frame-Parameter am bestehenden PNG-Endpunkt (`/download/png/{id}?frame=N`, N=0 = bisherige Vorschau); die Projekte-Seite zeigt eine Galerie mit Vorschau-/Downloadlink je Frame. Kleinste Änderung am bestehenden Muster (analog zum vorhandenen `inline=1`-Parameter).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ungenutzte Tiles beim Speichern entfernen (Priority: P1)

Als Nutzer bearbeite ich ein Bild über mehrere Sitzungen hinweg: Ich
übermale Tiles, lösche Frames, ändere Animationen. Wenn ich speichere, soll
die auf dem Gerät abgelegte Tile-Sammlung nur noch die Tiles enthalten, die
tatsächlich in mindestens einem Frame verwendet werden — nicht mehr
benötigte Tiles aus früheren Bearbeitungsständen werden entfernt, und alle
verbleibenden Positionsverweise zeigen weiterhin auf den richtigen Inhalt.

**Why this priority**: Direkt aus dem Feature-Wunsch; ohne Bereinigung
wächst die Tile-Sammlung über eine lange Editier-Sitzung unbegrenzt weiter,
obwohl das Gerät nur begrenzten Speicher hat (Constitution II schreibt
bereits Dedup beim Speichern vor — Bereinigung ist die logische Ergänzung
dazu für Tiles, die durch spätere Bearbeitung ganz aus allen Frames
verschwinden).

**Independent Test**: Ein Bild mit mehreren Frames anlegen, ein Tile in
allen Frames überschreiben, sodass sein ursprünglicher Inhalt in keinem
Frame mehr referenziert wird, speichern, App neu starten und Bild neu
laden — die Tile-Sammlung enthält den alten Inhalt nicht mehr, alle Frames
sehen weiterhin exakt so aus wie vor dem Speichern.

**Acceptance Scenarios**:

1. **Given** ein Bild mit 3 Frames, bei dem ein bestimmtes Tile in keinem
   der 3 Frames mehr referenziert wird, **When** der Nutzer speichert,
   **Then** enthält die gespeicherte Tile-Sammlung dieses Tile nicht mehr,
   und alle übrigen Tile-Positionen bleiben inhaltlich unverändert.
2. **Given** nach dem Entfernen ungenutzter Tiles verschieben sich die
   Indizes der verbleibenden Tiles, **When** gespeichert wird, **Then**
   verweisen alle Positionsdaten aller Frames auf die neuen, korrekten
   Indizes — kein Frame zeigt nach dem Neuladen einen falschen oder
   fehlenden Tile-Inhalt.
3. **Given** ein Bild verwendet in keinem Frame die Farbe Schwarz,
   **When** gespeichert wird, **Then** bleibt das Voll-Schwarz-Basistile
   trotzdem in der Tile-Sammlung erhalten (Basistiles werden nie entfernt,
   siehe Requirements).
4. **Given** der Nutzer speichert und malt in derselben Sitzung sofort
   weiter, **When** er danach erneut speichert, **Then** basiert die
   Bereinigung auf dem aktuellen Bearbeitungsstand, und es entstehen keine
   doppelten oder inkonsistenten Tile-Einträge gegenüber dem ersten
   Speichern.

---

### User Story 2 - Backend-Dateien nach Projektname statt Zufalls-ID benennen (Priority: P1)

Als Nutzer, der seine Bilder über das Backend herunterlädt, möchte ich in
den Dateinamen sofort erkennen, um welches Projekt es sich handelt — statt
einer bedeutungslosen, zufällig erzeugten Zeichenkette soll der auf dem
Playdate vergebene Projektname im Dateinamen stehen.

**Why this priority**: Betrifft alle heruntergeladenen Dateien und ist
Voraussetzung dafür, dass die in User Story 3 geforderte
SDK-Namenskonvention (`<name>-table-<w>-<h>`) einen sprechenden, statt
eines zufälligen Namens verwendet.

**Independent Test**: Ein Projekt mit einem erkennbaren Namen vom Playdate
aus synchronisieren, anschließend im Backend die zugehörigen Dateien
herunterladen — alle Dateinamen enthalten den Projektnamen, keine enthält
die interne Zufalls-ID.

**Acceptance Scenarios**:

1. **Given** ein Projekt wurde vom Playdate mit dem sync-üblichen,
   projektnamenbasierten Bezeichner hochgeladen, **When** der Nutzer eine
   zugehörige Datei herunterlädt, **Then** trägt der Dateiname diesen
   Bezeichner statt der internen Zufalls-ID.
2. **Given** derselbe Projektbezeichner wird erneut hochgeladen (Re-Sync
   nach weiterer Bearbeitung), **When** der Upload verarbeitet wird,
   **Then** werden dieselben, bereits vorhandenen Dateien aktualisiert
   (kein neuer Dateisatz mit neuem Namen).
3. **Given** eine Datei wird ohne projektnamenbasierten Bezeichner
   hochgeladen (z. B. manueller Upload über das Web-Formular), **When**
   der Upload verarbeitet wird, **Then** wird er nicht abgelehnt, und die
   Datei erhält wie bisher einen auf der internen Zufalls-ID basierenden
   Namen.
4. **Given** ein Nutzer greift über eine bestehende Download-URL
   (`/download/{typ}/{id}`) auf ein Projekt zu, **When** der Zugriff
   erfolgt, **Then** funktioniert die URL unverändert — nur der
   ausgelieferte Dateiname ändert sich, nicht die Adressierung/Berechtigung.

---

### User Story 3 - PNG-Export statt PDI-Download (Priority: P2)

Als Nutzer möchte ich meine Zeichnung direkt als PNG-Bilder herunterladen
und die Tile-Sammlung als PNG-Datei erhalten, die ich ohne Umbenennung in
ein anderes Playdate-SDK-Projekt legen kann — statt der bisherigen
rohen PDI-Datei, die ich außerhalb von Hans Dither nicht direkt
weiterverwenden kann.

**Why this priority**: Baut auf der projektbasierten Benennung aus User
Story 2 auf (der SDK-konforme Dateiname braucht den Projektnamen) und ist
im Feature-Wunsch als "auch" (zusätzlich zur Frame-PNG-Erzeugung)
formuliert — eine sinnvolle Ergänzung, aber nicht Grundvoraussetzung für
User Story 1/2.

**Independent Test**: Ein Bild mit mehreren Frames hochladen, anschließend
über das Backend jeden Frame einzeln als PNG abrufen und zusätzlich die
Tilemap-PNG herunterladen; die Tilemap-Datei lässt sich unverändert in ein
neues Playdate-SDK-Projekt legen und dort als Matrix-Imagetable laden. Ein
Versuch, die alte PDI-Route aufzurufen, liefert eine eindeutige
"nicht verfügbar"-Antwort.

**Acceptance Scenarios**:

1. **Given** ein Bild mit n Frames wurde hochgeladen, **When** der Nutzer
   die Bilder-Liste im Backend öffnet, **Then** sieht er für jeden der n
   Frames eine eigene Vorschau mit eigenem Downloadlink.
2. **Given** ein Frame-Index wird abgerufen, **When** die PNG-Datei
   generiert wird, **Then** entspricht sie exakt dem 400×240-Inhalt dieses
   Frames (identisch zur bisherigen Frame-1-Logik, nur für beliebige
   Frames).
3. **Given** der Nutzer lädt die Tilemap-PNG herunter, **When** die Datei
   ankommt, **Then** trägt sie den Namen `<projektname>-table-<zellbreite>-
   <zellhöhe>.png` (bei Hans Dither: `-table-16-16`) und enthält exakt die
   in der Tile-Sammlung gespeicherten Tiles in der vom SDK erwarteten
   Rasteranordnung.
4. **Given** ein Nutzer ruft die frühere PDI-Download-Route auf, **When**
   der Request verarbeitet wird, **Then** erhält er eine eindeutige
   Fehlermeldung statt einer PDI-Datei; weder die Web-Oberfläche noch die
   JSON-Schnittstelle bieten diesen Download mehr an.
5. **Given** ein ungültiger oder nicht existierender Frame-Index wird
   angefragt, **When** der Request verarbeitet wird, **Then** erhält der
   Nutzer eine eindeutige Fehlermeldung statt eines Absturzes oder eines
   falschen Bildes.

---

### Edge Cases

- Was passiert, wenn ein Bild ausschließlich die beiden Basistiles
  (Voll-Weiß, Voll-Schwarz) enthält und keine weiteren Tiles? Es gibt
  nichts zu entfernen; das Speichern verhält sich wie bisher.
- Was passiert, wenn durch die Bereinigung alle Tiles bis auf die
  Basistiles entfernt werden? Die Tile-Sammlung schrumpft auf genau 2
  Einträge; alle Frame-Positionen zeigen entsprechend auf Index 1 oder 2.
- Was passiert, wenn der Speichervorgang während der Neuindizierung
  abbricht (z. B. Stromausfall)? Der zuletzt vollständig gespeicherte
  Stand bleibt unverändert und konsistent nutzbar (kein halb geschriebener
  Zustand) — analog zur bestehenden Anforderung an robustes Speichern
  (Spec 001, FR-010).
- Was passiert bei einem Upload ohne projektnamenbasierten Bezeichner
  (z. B. älterer Client oder manueller Web-Upload)? Der Upload wird
  weiterhin angenommen; die Dateien erhalten wie bisher einen auf der
  internen Zufalls-ID basierenden Namen.
- Was passiert, wenn ein Bild nur 1 Frame hat? Es existiert genau eine
  abrufbare Frame-PNG (Index 0); keine Sonderbehandlung nötig.
- Was passiert mit bereits vor dieser Änderung hochgeladenen Bildern? Ihre
  vorhandenen Dateien werden nicht rückwirkend umbenannt; die neue
  Benennung gilt für künftige Uploads bzw. beim nächsten Update-in-place
  desselben Projekts.

## Requirements *(mandatory)*

### Functional Requirements

**Tile-Bereinigung (Playdate-Editor)**

- **FR-001**: Das System MUSS beim Speichern eines Bildes über alle Frames
  hinweg ermitteln, welche Tiles der Tile-Sammlung an keiner Position
  irgendeines Frames referenziert werden.
- **FR-002**: Das System MUSS alle so ermittelten ungenutzten Tiles aus
  der beim Speichern erzeugten Tile-Sammlung entfernen — mit Ausnahme der
  beiden Basistiles (Voll-Weiß = Index 1, Voll-Schwarz = Index 2), die
  unabhängig von ihrer tatsächlichen Nutzung in den Frames immer erhalten
  bleiben (bestehende Editor-Invariante: Malen ohne Pipetten-Auswahl
  toggelt zwischen genau diesen beiden Indizes).
- **FR-003**: Nach dem Entfernen MUSS das System die verbleibenden Tiles
  lückenlos neu durchnummerieren und alle Frame-Positionsdaten auf die
  neuen Indizes aktualisieren, sodass jede Position weiterhin exakt auf
  denselben Tile-Inhalt zeigt wie vor der Bereinigung.
- **FR-004**: Die aktive Editier-Sitzung MUSS nach einem erfolgreichen
  Speichern mit der bereinigten, neu durchnummerierten Tile-Sammlung
  weiterarbeiten (Tile-Sammlung, Frames und Dedup-Zuordnung synchron zum
  gespeicherten Stand) — es darf kein Auseinanderlaufen zwischen dem
  aktiven Editierzustand und dem zuletzt gespeicherten Stand entstehen.
- **FR-005**: Schlägt der Speichervorgang ab, MUSS der zuletzt erfolgreich
  gespeicherte Stand unverändert und konsistent nutzbar bleiben.

**Projektbasierte Dateibenennung (Backend)**

- **FR-006**: Das Backend MUSS beim Ablegen und beim Ausliefern von
  Dateien zu einem Projekt (Tile-Daten, Positionsdaten, gerenderte Bilder)
  den vom Gerät beim Upload übermittelten, aus dem Playdate-Projektnamen
  abgeleiteten Bezeichner als Dateinamen verwenden statt der intern
  erzeugten Zufalls-Kennung.
- **FR-007**: Liegt zu einem Upload kein solcher Bezeichner vor, MUSS das
  Backend auf die bisherige interne Zufalls-Kennung als Dateiname
  zurückfallen, ohne den Upload abzulehnen.
- **FR-008**: Die interne, für Zugriffskontrolle und URL-Adressierung
  verwendete Kennung eines Projekts DARF sich durch diese Umbenennung
  nicht ändern; ausschließlich Datei- und Downloadnamen sind betroffen.
- **FR-009**: Das Backend MUSS für jeden zur Dateibenennung verwendeten
  Bezeichner sicherstellen, dass daraus kein Zugriff außerhalb des
  vorgesehenen Projektverzeichnisses entstehen kann (keine Pfad- oder
  Verzeichnistraversierung möglich).

**PNG-Export statt PDI-Download (Backend)**

- **FR-010**: Das Backend MUSS zu jedem Frame eines Bildes ein eigenes,
  einzeln abrufbares PNG rendern können (nicht mehr nur den ersten Frame).
- **FR-011**: Das Backend MUSS die Tile-Sammlung zusätzlich als
  eigenständige PNG-Datei bereitstellen, deren Dateiname exakt der
  Playdate-SDK-Namenskonvention für Matrix-Imagetables entspricht
  (`<projektname>-table-<zellbreite>-<zellhöhe>`), sodass die Datei ohne
  Umbenennung in ein anderes Playdate-SDK-Projekt übernommen werden kann.
- **FR-012**: Das Backend DARF den rohen PDI-Dateidownload nicht mehr als
  Option anbieten — weder als Link in der Web-Oberfläche noch als Feld in
  der JSON-Schnittstelle.
- **FR-013**: Ein Aufruf der früheren PDI-Download-Route MUSS eine
  eindeutige "nicht verfügbar"-Antwort liefern statt weiterhin die Datei
  auszuliefern.
- **FR-014**: Nicht mehr erreichbarer Code, der ausschließlich dem
  PDI-Download diente, MUSS entfernt statt nur unerreichbar gemacht werden
  (kein toter Code; Constitution IV). Die interne Nutzung der PDI-Datei
  für das Rendering (Tile-Extraktion aus dem hochgeladenen sheet.pdi)
  bleibt davon unberührt, da sie weiterhin für die PNG-Erzeugung benötigt
  wird.

### Key Entities

- **Tile-Sammlung**: Geordnete Menge aller in einem Bild verwendeten
  Tiles; nach dem Speichern enthält sie ausschließlich referenzierte
  Tiles plus die beiden Basistiles.
- **Basistile**: Eines von genau zwei reservierten Tiles (Voll-Weiß =
  Index 1, Voll-Schwarz = Index 2), die nie durch die Bereinigung entfernt
  werden.
- **Projekt-Bezeichner**: Vom Gerät beim Upload übermittelter, aus dem
  Playdate-Projektnamen abgeleiteter Bezeichner; dient im Backend künftig
  als Basis für Datei- und Downloadnamen, unabhängig von der weiterhin
  bestehenden internen Zugriffs-Kennung.
- **Frame-PNG**: Gerendertes 400×240-Abbild eines einzelnen
  Animationsframes; pro Bild existieren so viele Frame-PNGs wie Frames.
- **Tilemap-PNG**: Die Tile-Sammlung eines Bildes, gerendert als
  PNG-Matrix-Imagetable gemäß Playdate-SDK-Namenskonvention.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nach dem Speichern eines Bildes mit gezielt unbenutzt
  gemachten Tiles enthält die gespeicherte Tile-Sammlung ausschließlich
  noch tatsächlich referenzierte Tiles plus die zwei Basistiles —
  verifiziert an mindestens 3 Testbildern mit unterschiedlich vielen
  verwaisten Tiles.
- **SC-002**: 100 % der aus dem Backend heruntergeladenen Dateien tragen
  den Projektnamen im Dateinamen, sobald dieser vom Gerät beim Upload
  übermittelt wurde.
- **SC-003**: Für ein Bild mit n Frames lassen sich alle n Frames einzeln
  als PNG abrufen, ohne dass eine PDI-Datei heruntergeladen werden muss.
- **SC-004**: Die heruntergeladene Tilemap-PNG-Datei lässt sich ohne
  Umbenennung in ein neues Playdate-SDK-Projekt legen und dort als
  Matrix-Imagetable laden.
- **SC-005**: 100 % der Aufrufe der PDI-Download-Route liefern eine
  eindeutige "nicht verfügbar"-Antwort statt einer PDI-Datei.

## Assumptions

- Der GIF-Download bleibt unverändert bestehen; er ist nicht Teil dieses
  Feature-Wunsches und wird hier weder verändert noch entfernt.
- Es gibt aktuell keine Umbenennungsfunktion für Projekte auf dem
  Playdate — der Projekt-Bezeichner ist ab Anlage stabil. Dadurch
  entstehen durch diese Änderung keine verwaisten Alt-Dateien wegen einer
  nachträglichen Umbenennung; dieser Fall bleibt bewusst außerhalb des
  Scopes.
- Frame-PNGs werden wie das bisherige Vorschau-PNG bedarfsgesteuert
  (on-demand) erzeugt und für spätere Abrufe zwischengespeichert; es gibt
  kein Vorab-Rendering aller Frames direkt beim Upload.
- Der vom Gerät beim Upload übermittelte, sanitisierte Projekt-Bezeichner
  ist bereits auf ein filesystemsicheres Zeichenformat (Kleinbuchstaben,
  Ziffern, Bindestrich, begrenzte Länge) beschränkt; das Backend
  validiert dieses Format weiterhin bei jedem Upload, unabhängig davon,
  ob der Bezeichner zur Dateibenennung verwendet wird.
- Bereits vor dieser Änderung hochgeladene Dateien werden nicht
  rückwirkend umbenannt; die neue Benennung greift ab dem nächsten Upload
  desselben Projekts.

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Applicable — arc42 Kap. 5
  Bausteinsicht (Save-Pfad des Editors um Bereinigungsschritt erweitert;
  Backend-Bausteine Renderer/UploadHandler/download.php ändern Verhalten),
  Kap. 6 Laufzeitsicht (Speichern-Sequenz erhält eine Bereinigungsphase;
  Download-Sequenz verliert die PDI-Route und gewinnt Frame-Auswahl), Kap.
  8 Querschnittliche Konzepte (neue Dateibenennungskonvention im
  Backend), Kap. 9 Architekturentscheidungen (neue ADRs, siehe unten),
  Kap. 10 Qualitätsanforderungen (Speichereffizienz auf dem Gerät,
  Interoperabilität der Backend-Exporte mit dem Playdate SDK), Kap. 11
  Risiken (Fehlerpotenzial bei Neuindizierung).
- **Qualitätsszenarien**: Applicable —
  - Ressourceneffizienz (Gerät): "Nach dem Speichern eines Bildes mit
    ungenutzten Tiles enthält die Tile-Sammlung nur noch referenzierte
    plus Basistiles" (SC-001).
  - Interoperabilität (Backend-Export): "Die heruntergeladene
    Tilemap-PNG-Datei lässt sich ohne Umbenennung in ein anderes
    Playdate-SDK-Projekt übernehmen und dort als Matrix-Imagetable laden"
    (SC-004).
  - Nachvollziehbarkeit (Backend-Dateien): "Heruntergeladene Dateien
    tragen den Projektnamen statt einer bedeutungslosen Zufalls-ID"
    (SC-002).
- **Erwartete Evidenz unter `docs/architecture/`**: Applicable —
  `docs/architecture/security-review-backend.md` (Spec 005/007) MUSS um
  eine neue Zeile ergänzt werden: Dateinamen, die aus einem
  geräteseitig gesetzten, aber serverseitig bereits whitelist-validierten
  Wert (bestehende Regex-Prüfung beim Upload) abgeleitet werden, sind
  gegen Pfad-/Verzeichnistraversierung abgesichert (FR-009). Zusätzlich
  MUSS die dort dokumentierte S-04-Zeile (PDI-Format-Validierung) darauf
  geprüft werden, ob sie nach Entfernen der PDI-Download-Route weiterhin
  zutrifft (die interne PDI-Verarbeitung bleibt bestehen, nur der
  Download entfällt). Owner: Entwickler. Re-Evaluierungs-Trigger:
  `/speckit-plan`-Lauf für diese Spec.
- **ADR erforderlich**: Ja — Kandidaten: (1) Umgang mit der
  Tile-Neuindizierung im Save-Pfad — FR-004 legt bereits fest, dass die
  aktive Editier-Sitzung nach dem Speichern mit dem bereinigten Stand
  weiterarbeitet (nicht nur die serialisierte Datei); die Begründung
  dieser Entscheidung (Speicher-/Konsistenzgründe auf begrenzter
  Zielhardware) MUSS als ADR festgehalten werden. **Aufgelöst in der
  Planungsphase** (`plan.md`/`research.md` R2): Die Untersuchung des
  Raum-Lebenszyklus zeigt, dass FR-004 bereits strukturell garantiert ist
  (Speichern verlässt immer den Editor, Wiedereintritt lädt immer neu) —
  es besteht kein echter Trade-off zwischen Alternativen, daher als
  Recherche-Ergebnis dokumentiert statt als eigenes ADR. (2) Wahl des
  bestehenden, sync-seitig bereits übermittelten Projekt-Bezeichners
  (statt eines neu einzuführenden separaten "Projektname"-Feldes) als
  Grundlage für die Backend-Dateibenennung. Owner: Entwickler.
  Re-Evaluierungs-Trigger: Planungsphase (Constitution Prinzip I:
  SDK-/Ist-Zustand-Verifikation vor Festlegung). **Aufgelöst**: als AD-038
  in `plan.md` festgehalten.
- **Sicherheitsrelevante Architektur**: Ja — Backend-Dateinamen werden ab
  dieser Änderung aus einem geräteseitig gesetzten Wert abgeleitet
  (FR-006/FR-009); die bestehende serverseitige Whitelist-Validierung
  dieses Werts ist die maßgebliche Kontrolle gegen Pfad-/
  Verzeichnistraversierung und MUSS in der Planungsphase explizit als
  weiterhin ausreichend für den neuen Verwendungszweck (Dateiname statt
  nur DB-Lookup-Schlüssel) bestätigt werden. Ein dediziertes
  Secure-Architecture-Preset ist im Projekt nicht verfügbar; die
  Sicherheitsbewertung erfolgt wie bei Spec 007 inline über die
  `docs/architecture/security-review-backend.md`-Evidenz.
- **Risiken**: Applicable —
  - Fehler bei der Tile-Neuindizierung (FR-003) könnten zu falschen oder
    fehlenden Tile-Inhalten nach dem Neuladen führen — hohe Kritikalität,
    da direkt die Kernanforderung "verlustfreies Speichern" (Spec 001,
    FR-006) berührt; erfordert gezielte Round-Trip-Tests mit gezielt
    verwaisten Tiles.
  - Weicht die Playdate-SDK-Namenskonvention für Matrix-Imagetables in
    einer künftigen SDK-Version vom hier zugrunde gelegten Muster
    (`<name>-table-<w>-<h>`) ab, wird der Tilemap-Export inkompatibel —
    zu beobachten bei SDK-Updates (Constitution Prinzip I).
- **Technische Schuld**: Applicable — das Entfernen der PDI-Download-Route
  darf keinen toten Code (unerreichbare Auslieferungsfunktion) im Backend
  hinterlassen (FR-014, Constitution Prinzip IV, Präzedenzfall AD-037).

