# Edit Modes Plan fuer TileRoom

## Ziel

Der TileRoom soll zwei Edit-Modi erhalten, um spaeter Animationen sauber zu integrieren:

1. TilePickerMode (bestehendes Verhalten erweitert)
2. AnimationMode (zunaechst Platzhalter mit Frame-Wechsel)

Die B-Taste bekommt zwei Rollen:

- kurzer Druck: Pipette (Tile aus aktueller Zelle als aktives Picker-Tile uebernehmen)
- langer Druck (>= 1.5s): Moduswechsel zwischen TilePickerMode und AnimationMode

## Ist-Zustand (relevant)

- Crank waehlt im TileRoom direkt das aktive Tile aus.
- B gedrueckt + Crank wird aktuell fuer den Wechsel in den ZoomRoom verwendet.
- Das Tile-Picker-Fenster wird nur bei Crank-Bewegung sichtbar.
- Es gibt aktuell keine generische Bauchbinde-Komponente.

## Ziel-Verhalten im Detail

## 1) Kurzer B-Druck als Pipette

Wenn B kurz gedrueckt wird (kein Long-Press):

- Tile-Index aus aktuell selektierter Zelle lesen.
- Wenn gueltig, als aktives Picker-Tile setzen.
- Tile-Picker-Fenster sichtbar machen.
- Picker-Timeout neu starten, damit das Fenster nach der Aktion sichtbar bleibt.

Hinweis:

- Basis-Tiles 1/2 bleiben technisch waehlbar durch Pipette, falls in der selektierten Zelle vorhanden.
- Crank-Logik kann weiterhin zyklisch auf den erlaubten Bereich begrenzen (aktuelles Verhalten ab Index 3).

## 2) Bauchbinde links neben dem Picker

Sobald der Tile-Picker sichtbar ist, wird zusaetzlich links auf derselben Hoehe eine Bauchbinde gezeichnet:

- schwarzer Hintergrund
- weisser Text
- Text: tilePicker

Design-Regeln:

- vertikal gleiche Y-Position wie Picker-Fenster
- horizontal links vom Picker mit kleinem Abstand
- robustes Clamping am linken Bildschirmrand (kein Zeichnen ausserhalb)

## 3) Long-Press B fuer Mode-Wechsel

Wenn B mindestens 1.5 Sekunden gehalten wird:

- einmaliger Toggle des Modus:
  - TilePickerMode -> AnimationMode
  - AnimationMode -> TilePickerMode
- Toggle darf pro B-Haltephase nur einmal ausgeloest werden.
- Beim Loslassen von B wird der Long-Press-Zustand zurueckgesetzt.

## 4) Verhalten je Modus

### TilePickerMode

- bestehendes Tile-Auswaehlen ueber Crank bleibt erhalten
- kurzer B-Druck fuehrt Pipette aus
- Tile-Picker-Fenster + Bauchbinde werden wie beschrieben gezeigt

### AnimationMode (Platzhalter)

- Crank schaltet vorerst nur zwischen Animationframes (Platzhalter-Index)
- noch keine Aenderung an Tilemap/Frames persistieren
- optionales Overlay fuer spaetere Erweiterung vorbereiten (nicht zwingend in erster Iteration)

## Technischer Zuschnitt (Dateien)

- Source/TileRoom.lua
  - neuer editMode-State
  - B-Press-Timing (Short vs Long)
  - Pipette-Logik
  - mode-spezifische Crank-Logik
  - Sichtbarkeitssteuerung Picker

- Source/TileRoomEditor.lua
  - Bauchbinde-Zeichnung als wiederverwendbare Funktion
  - Erweiterung von drawTilePickerWindow() um Bauchbinde-Aufruf

## Konfliktaufloesung mit bestehender Zoom-Interaktion

Der aktuelle Pfad "B halten + Crank" kollidiert mit Long-Press-B fuer Mode-Wechsel.

Geplante Loesung:

- Zoom-Trigger aus B entkoppeln (gem. bestehendem Kommentar auf Richtung "D-Pad Up + Crank" korrigieren),
  damit B exklusiv fuer Pipette/Modewechsel genutzt wird.

Falls Zoom kurzfristig unveraendert bleiben muss, wird dieser Punkt als separates Follow-up markiert.

## Akzeptanzkriterien

1. Kurzer B-Druck uebernimmt das Tile der selektierten Zelle als aktives Picker-Tile.
2. Nach Pipette ist das Picker-Fenster sichtbar und verschwindet erst nach Timeout.
3. Bei sichtbarem Picker wird links daneben die Bauchbinde "tilePicker" gezeichnet.
4. B-Haltezeit >= 1.5s toggelt den Modus genau einmal pro Haltevorgang.
5. Im TilePickerMode funktioniert Crank-Tilewahl weiterhin.
6. Im AnimationMode wechselt Crank nur den Frame-Platzhalter.
7. Keine Regression bei Cursorbewegung, Paint mit A und Save/Load.

## Test-Szenarien (manuell)

1. Tile unter Cursor auf ein anderes setzen, kurz B druecken, dann A-Malen: das gepickte Tile wird gemalt.
2. Crank drehen: Picker und Bauchbinde erscheinen, Timeout blendet wieder aus.
3. B 1.5s halten: Mode wechselt; erneutes Halten wechselt zurueck.
4. In AnimationMode Crank drehen: nur Frame-Platzhalter aendert sich, Tilemap bleibt unveraendert.
5. Speichern/Laden nach Moduswechsel und Picker-Aktionen: keine Fehler, Tilemap konsistent.
