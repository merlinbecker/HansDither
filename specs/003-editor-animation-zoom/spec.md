# Feature Specification: Editor-Umbau — 16×16-Tiles, Animation und Zoomstufen

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-03

**Status**: Draft

**Input**: User description: "Editor-Umbau für Hans Dither v0.3.0: Direkter Einstieg in den Editor (400×240 nativ, 25×15 Raster aus 16×16-Tiles). D-Pad bewegt den Brush; B = Pipette (Tile an Cursor-Position wählen); A = ausgewähltes Tile zeichnen bzw. Schwarz/Weiß toggeln. Globaler Tile-Picker entfällt. Crank ohne Modifier = Frame-Verwaltung (vorwärts: nächster Frame als Kopie, rückwärts: zurück; max. 12 Frames, dann Rotation). B+Crank = Zoom. Zoom Room: 24×24-Grid über 3×3 Tiles, malt 2×2-Pixel-Blöcke. Pixel Room: echtes 16×16-Pixel-Malen. Drei Zoomstufen insgesamt. Automatisches Speichern beim Verlassen."

## Clarifications

### Session 2026-07-03

- Q: Was passiert beim Rückwärtsdrehen des Cranks, wenn Frame 1 aktiv ist? → A: Rotation zum letzten existierenden Frame (symmetrisch zur Vorwärts-Rotation); rückwärts werden nie neue Frames erzeugt.
- Q: Können Frames wieder gelöscht werden? → A: Ja, über den Systemmenü-Eintrag "Frame löschen": entfernt den aktiven Frame (außer dem letzten verbliebenen); nachfolgende Frames rücken auf.
- Q: Gibt es in v0.3.0 eine Abspiel-Funktion für die Animation im Editor? → A: Nein — Vorschau erfolgt manuell per Crank-Durchblättern; Playback ist explizites Nicht-Ziel von v0.3.0.

### Session 2026-07-04

- Q: "All Similar" bearbeitet das Tile in-place in der Imagetable und wirkt damit über alle Frames — Widerspruch zu FR-013 (Änderungen nur im aktiven Frame)? → A: Bewusst so gewollt: "All Similar" ändert alle Verwendungen des Tiles in jedem Frame; FR-013 erhält eine explizite Ausnahme für genau diese Funktion. Normales Malen (Dedup-Pfad, FR-012) bleibt strikt frame-lokal.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Direkt im Editor tileweise malen (Priority: P1)

Als Nutzer lande ich nach der Bildauswahl direkt im Editor und male auf einem 25×15-Raster aus 16×16-Tiles: Das D-Pad bewegt den Brush-Cursor, A setzt an der Cursor-Position das ausgewählte Tile bzw. toggelt zwischen Schwarz und Weiß, B übernimmt das Tile unter dem Cursor als aktives Zeichen-Tile (Pipette).

**Why this priority**: Das ist der Kern-Workflow des Editors; alle weiteren Funktionen (Animation, Zoom) bauen darauf auf.

**Independent Test**: Bild öffnen, Cursor bewegen, mit A Tiles setzen/toggeln, mit B ein vorhandenes Tile aufnehmen und an anderer Stelle zeichnen — vollständig ohne Crank testbar.

**Acceptance Scenarios**:

1. **Given** ein Bild wurde im Auswahlscreen gewählt, **When** der Wechsel erfolgt, **Then** öffnet sich unmittelbar der Editor mit dem 25×15-Tile-Raster auf voller 400×240-Fläche — ohne zwischengeschaltete Room-Auswahl.
2. **Given** der Cursor steht auf einer weißen Zelle und kein Tile ist ausgewählt, **When** der Nutzer A drückt, **Then** wird die Zelle schwarz; erneutes A macht sie wieder weiß (Toggle).
3. **Given** der Cursor steht auf einer Zelle mit einem gestalteten Tile, **When** der Nutzer B drückt, **Then** wird dieses Tile zum aktiven Zeichen-Tile.
4. **Given** ein Tile ist als aktives Zeichen-Tile ausgewählt, **When** der Nutzer auf einer anderen Zelle A drückt, **Then** wird dort das ausgewählte Tile gezeichnet; erneutes A auf derselben Zelle setzt sie zurück auf Weiß.
5. **Given** der Editor ist aktiv, **When** der Nutzer den Crank ohne gedrücktes B dreht, **Then** wird kein Tile ausgewählt (der globale Tile-Picker existiert nicht mehr).

---

### User Story 2 - Animationsframes per Crank verwalten (Priority: P2)

Als Nutzer drehe ich den Crank vorwärts, um zum nächsten Animationsframe zu wechseln — existiert er noch nicht, wird er als Kopie des aktuellen Frames angelegt. Rückwärtsdrehen wechselt einen Frame zurück. Es gibt maximal 12 Frames; nach dem zwölften rotiert die Navigation zum ersten Frame.

**Why this priority**: Animation ist das große neue Feature von v0.3.0, benötigt aber den funktionierenden Mal-Workflow aus Story 1.

**Independent Test**: In Frame 1 malen, Crank vorwärts drehen, Änderung in Frame 2 vornehmen, zurückdrehen — Frame 1 ist unverändert, Frame 2 enthält die Kopie plus Änderung.

**Acceptance Scenarios**:

1. **Given** das Bild hat nur Frame 1, **When** der Nutzer den Crank um eine Rastung vorwärts dreht, **Then** entsteht Frame 2 als exakte Kopie von Frame 1 und wird zum aktiven Frame.
2. **Given** Frame 2 ist aktiv, **When** der Nutzer den Crank eine Rastung rückwärts dreht, **Then** wird Frame 1 aktiv; dessen Inhalt ist unverändert.
3. **Given** das Bild hat 12 Frames und Frame 12 ist aktiv, **When** der Nutzer vorwärts dreht, **Then** wird kein 13. Frame angelegt, sondern Frame 1 aktiv (Rotation).
4. **Given** ein Frame-Wechsel findet statt, **When** der neue Frame angezeigt wird, **Then** ist im Editor erkennbar, welcher Frame (n von m) gerade aktiv ist.
5. **Given** der Nutzer dreht den Crank mehrere Rastungen am Stück, **When** die Drehung verarbeitet wird, **Then** entspricht die Rastung dem gewohnten Abstand der früheren Tile-Auswahl (eine Rastung = ein Frame).

---

### User Story 3 - Drei Zoomstufen: Übersicht, Zoom Room, Pixel Room (Priority: P2)

Als Nutzer zoome ich mit B+Crank vorwärts vom Tile-Editor in den Zoom Room (24×24-Malraster über den 3×3-Tile-Kontext um den Cursor; ein Malstrich setzt 2×2 native Pixel) und von dort eine weitere Stufe in den Pixel Room (ein einzelnes Tile mit echten 16×16 Pixeln; ein Malstrich setzt 1 Pixel). B+Crank rückwärts führt stufenweise zurück; Änderungen werden dabei übernommen.

**Why this priority**: Detailmalen ist essenziell für 1-Bit-Pixelart, setzt aber Story 1 voraus; die Zoomräume existieren bereits und werden auf die neuen Tile-Maße umgestellt.

**Independent Test**: Im Zoom Room ein Muster malen (2×2-Blöcke), in den Pixel Room wechseln und einzelne Pixel verfeinern, zurückzoomen — das Tile im Editor zeigt beide Änderungen.

**Acceptance Scenarios**:

1. **Given** der Editor ist aktiv und der Cursor steht auf einem Tile, **When** der Nutzer B hält und den Crank vorwärts dreht, **Then** öffnet sich der Zoom Room mit dem 3×3-Tile-Kontext um die Cursor-Position als 24×24-Malraster.
2. **Given** der Zoom Room ist aktiv, **When** der Nutzer eine Rasterzelle setzt, **Then** werden genau 2×2 native Pixel gesetzt (halbe Auflösung, entsprechend der früheren Pulp-Auflösung).
3. **Given** der Zoom Room ist aktiv, **When** der Nutzer B hält und den Crank weiter vorwärts dreht, **Then** öffnet sich der Pixel Room mit dem Tile an der Cursor-Position in voller 16×16-Pixel-Auflösung.
4. **Given** der Pixel Room ist aktiv, **When** der Nutzer eine Zelle setzt, **Then** wird genau 1 nativer Pixel geändert.
5. **Given** in Zoom Room oder Pixel Room wurde gemalt, **When** der Nutzer stufenweise zurückzoomt (B+Crank rückwärts), **Then** sind alle Änderungen im Tile-Editor sichtbar und nur tatsächlich geänderte Tiles wurden ersetzt (Dedup-Verhalten bleibt erhalten).
6. **Given** die Zoomräume sind aktiv, **When** deren bisherige Zusatzfunktionen (z. B. Rasteranzeige, Invert, "All Similar") genutzt werden, **Then** verhalten sie sich wie bisher — nur auf 16×16-Tiles bezogen.

---

### User Story 4 - Automatisch speichern beim Verlassen (Priority: P1)

Als Nutzer verlasse ich den Editor zurück zum Auswahl-/Startscreen, und mein Bild wird automatisch gespeichert — ohne expliziten Speicherbefehl.

**Why this priority**: Schützt die Arbeit des Nutzers; verbindet den Editor mit dem Speicherformat (Spec 001) und ist Teil des definierten Rundlaufs.

**Independent Test**: Malen, Editor über das Systemmenü verlassen, Bild erneut öffnen — alle Frames sind wiederhergestellt.

**Acceptance Scenarios**:

1. **Given** im Editor wurde in mehreren Frames gemalt, **When** der Nutzer über das Systemmenü zurück zum Auswahlscreen geht, **Then** wird das Bild vollständig gespeichert (gemäß Spec 001) und der Speicherfortschritt angezeigt.
2. **Given** der Speichervorgang läuft, **When** er abgeschlossen ist, **Then** zeigt der Auswahlscreen das aktualisierte Vorschaubild des Bildes.

---

### Edge Cases

- Was passiert bei B+Crank am äußersten Bildrand (Cursor in einer Ecke)? Der 3×3-Kontext behandelt Außenbereiche wie bisher als nicht editierbare Out-of-bounds-Slots.
- Was passiert, wenn der Nutzer im Zoom Room über den Rand des 24×24-Rasters navigiert? Der Cursor stoppt am Rand (kein Wrap innerhalb des Zoomkontexts).
- Was passiert mit dem aktiven Zeichen-Tile nach einem Frame-Wechsel? Es bleibt ausgewählt (Auswahl ist frame-unabhängig).
- Was passiert, wenn der Nutzer den Crank sehr schnell dreht (mehrere Rastungen pro Aktualisierung)? Frames werden der Reihe nach durchlaufen; es dürfen keine Frames übersprungen entstehen (jede neue Kopie basiert auf ihrem direkten Vorgänger).
- Was passiert bei Rückwärtsdrehen auf Frame 1? Rotation zum letzten existierenden Frame, symmetrisch zum Vorwärtsverhalten (geklärt, siehe Clarifications); rückwärts entstehen nie neue Frames.
- Was passiert nach "Frame löschen"? Der nachrückende Frame wird aktiv; war der gelöschte Frame der letzte der Sequenz, wird der neue letzte Frame aktiv. Beim letzten verbliebenen Frame ist der Menüeintrag deaktiviert bzw. wirkungslos.
- Was passiert, wenn während eines laufenden Speichervorgangs Eingaben erfolgen? Konkurrierende Eingaben werden blockiert (bestehendes Muster).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Der Editor MUSS die volle native Fläche von 400×240 als 25×15-Raster aus 16×16-Tiles darstellen und direkt nach der Bildauswahl aktiv sein.
- **FR-002**: Das D-Pad MUSS den Brush-Cursor tileweise über das Raster bewegen; gehaltene Richtungen wiederholen die Bewegung (bestehendes Verhalten).
- **FR-003**: B (kurz) MUSS das Tile an der Cursor-Position als aktives Zeichen-Tile übernehmen (Pipette).
- **FR-004**: A MUSS an der Cursor-Position das aktive Zeichen-Tile setzen; steht dort bereits dasselbe Tile, MUSS A die Zelle auf Weiß zurücksetzen. Ohne aktives Zeichen-Tile MUSS A zwischen Schwarz und Weiß toggeln.
- **FR-005**: Ein globaler Tile-Picker DARF NICHT mehr existieren; Crank-Drehung ohne Modifier DARF KEINE Tile-Auswahl auslösen.
- **FR-006**: Crank-Drehung ohne Modifier MUSS Frames verwalten: eine Rastung vorwärts wechselt zum nächsten Frame und legt ihn bei Bedarf als Kopie des aktuellen an; eine Rastung rückwärts wechselt einen Frame zurück.
- **FR-007**: Die Anzahl der Frames MUSS auf maximal 12 begrenzt sein; Navigation über das Ende hinaus MUSS zum ersten Frame rotieren (rückwärts entsprechend zum letzten existierenden Frame).
- **FR-008**: Der aktive Frame (n von m) MUSS im Editor sichtbar angezeigt werden.
- **FR-008a**: Das Systemmenü des Editors MUSS einen Eintrag "Frame löschen" anbieten, der den aktiven Frame entfernt; nachfolgende Frames rücken auf. Der letzte verbliebene Frame DARF NICHT gelöscht werden.
- **FR-009**: B+Crank vorwärts MUSS vom Editor in den Zoom Room und von dort in den Pixel Room zoomen; B+Crank rückwärts MUSS stufenweise zurückführen. Es gibt genau drei Zoomstufen.
- **FR-010**: Der Zoom Room MUSS den 3×3-Tile-Kontext um den Cursor als 24×24-Malraster darstellen; ein Malvorgang MUSS genau einen 2×2-Pixel-Block setzen oder löschen.
- **FR-011**: Der Pixel Room MUSS ein einzelnes Tile mit echten 16×16 Pixeln darstellen; ein Malvorgang MUSS genau 1 Pixel setzen oder löschen.
- **FR-012**: Beim Zurückzoomen MÜSSEN nur tatsächlich geänderte Tiles übernommen und über den Dedup-Pfad (Hashvergleich) verarbeitet werden.
- **FR-013**: Änderungen in Zoom Room und Pixel Room MÜSSEN sich ausschließlich auf den aktiven Frame beziehen. Einzige Ausnahme ist "All Similar": Diese Funktion bearbeitet das Tile definitionsgemäß in-place in der Imagetable und wirkt damit auf alle Verwendungen des Tiles — in allen Zellen und über alle Frames hinweg (geklärt, siehe Clarifications).
- **FR-014**: Beim Verlassen des Editors Richtung Auswahl-/Startscreen MUSS automatisch gespeichert werden (gemäß Spec 001), mit sichtbarem Fortschritt.
- **FR-015**: Die bisherigen Zusatzfunktionen der Zoomräume (Rasteranzeige-Synchronisation, Invert, "All Similar") MÜSSEN erhalten bleiben, bezogen auf 16×16-Tiles.

### Key Entities

- **Editor-Raster**: 25×15 Zellen à 16×16 Pixel; jede Zelle referenziert ein Tile des aktiven Frames.
- **Brush-Cursor**: Aktuelle Bearbeitungsposition im Raster; bestimmt Ziel von A/B und den Zoomkontext.
- **Aktives Zeichen-Tile**: Das per Pipette gewählte Tile, das A zeichnet; Zustand "kein Tile gewählt" bedeutet Schwarz/Weiß-Toggle.
- **Frame**: Eine von maximal 12 Animationsstufen; vollständige Rasterbelegung; neue Frames entstehen als Kopie ihres Vorgängers.
- **Zoomkontext**: Der 3×3-Tile-Ausschnitt um den Cursor (Zoom Room) bzw. das Einzeltile (Pixel Room), inklusive Rückschreib-/Dedup-Verhalten.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Der Weg von der Bildauswahl bis zum ersten gesetzten Tile erfordert höchstens 2 Eingaben (A zum Öffnen, A zum Setzen) — keine Zwischenscreens.
- **SC-002**: Eine Animation mit 12 Frames kann vollständig per Crank erstellt und durchlaufen werden; die Rotation nach Frame 12 zu Frame 1 funktioniert in 100 % der Versuche.
- **SC-003**: Ein im Pixel Room gesetzter Einzelpixel ist nach Rückkehr in den Editor und nach Speichern/Laden exakt an derselben nativen Position sichtbar (0 Koordinatenabweichung über alle drei Zoomstufen).
- **SC-004**: Cursorbewegung, Malen und Frame-Wechsel reagieren auf Zielhardware ohne wahrnehmbare Verzögerung (flüssig bei normaler Bedienung, keine Eingabe geht verloren).
- **SC-005**: Ein Nutzer, der v0.2.0 kennt, kann alle drei Zoomstufen und die Frame-Verwaltung ohne Anleitung innerhalb von 5 Minuten erfolgreich nutzen (unterstützt durch sichtbare Modus-/Frame-Hinweise).

## Assumptions

- Rückwärtsdrehen auf Frame 1 rotiert zum letzten existierenden Frame (geklärt, siehe Clarifications).
- Der Schwarz/Weiß-Toggle (A ohne aktives Zeichen-Tile) arbeitet mit zwei definierten Basistiles (Voll-Schwarz, Voll-Weiß); eine Abwahl des aktiven Zeichen-Tiles ist möglich (z. B. Pipette auf Weiß).
- Die Rastung des Cranks für Frame-Wechsel übernimmt den Winkelabstand der bisherigen Tile-Picker-Rastung.
- Die Frame-Anzeige nutzt das bestehende Hinweis-Band (Bauchbinde); der bisherige Moduswechsel per B-Long-Press (TilePickerMode/AnimationMode) entfällt ersatzlos, da Frames jetzt direkt am Crank liegen.
- "Alle anderen Funktionen bleiben gleich" wird als Beibehaltung der bestehenden Zoomraum-Funktionen (Rastersynchronisation, Invert, All Similar, Out-of-bounds-Verhalten) auf neuer Tile-Größe interpretiert.
- Ein automatisches Abspielen der Animation (Playback) ist explizites Nicht-Ziel von v0.3.0 (geklärt, siehe Clarifications); die Vorschau erfolgt manuell per Crank-Durchblättern.
- Dieses Feature hängt von Spec 001 (Speicherformat, Frames-Persistenz) und Spec 002 (direkter Einstieg über den Auswahlscreen) ab.

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Bausteinsicht (arc42 Kap. 5: TileRoom/ZoomRoom/PixelRoom-Umbau, Wegfall Tile-Picker und EditMode-Automat), Laufzeitsicht (Kap. 6: neue Editier-, Animations- und Zoomszenarien), Querschnittskonzepte (Kap. 8: Input-Semantik, Rendering ohne Offscreen-Skalierung, da Daten- und Anzeigeauflösung jetzt zusammenfallen), Qualitätsanforderungen (Kap. 10), Risiken (Kap. 11: Frame-Kopien × Speicher).
- **Erwartete Evidenz**: Aktualisierte arc42-Kapitel 5, 6, 8, 10, 11 im selben Änderungsschnitt; Architekturentscheidungen in Kap. 9: Crank als Frame-Steuerung (ersetzt AD-014-Teilverhalten), Wegfall des dualen Auflösungskonzepts (ersetzt AD-015), SDK-Nutzung für Tilemap/Imagetable in 16×16 (Constitution Prinzip I).
- **ADR erforderlich**: Ja (Input-Neubelegung Crank/B, Aufgabe des dualen Auflösungsmodells, Frame-Datenmodell im Editor). Sicherheitsrelevante Architektur: N/A — lokale Editorfunktion.
