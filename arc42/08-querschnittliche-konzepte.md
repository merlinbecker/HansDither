# 8. Querschnittliche Konzepte

## 8.1 Input- und Navigationskonzept

- Jeder Room liefert einen eigenen Input-Handler.
- Ein zentraler switchRoom-Mechanismus tauscht Handler atomar aus.
- Bedienmuster im Editor (AD-019):
  - D-Pad bewegt den Brush-Cursor tileweise; Halten wiederholt (SDK-keyRepeatTimer).
  - A malt als Strich: Der A-Druck bestimmt den Malwert — steht der Cursor auf dem aktiven Zeichen-Tile (bzw. Schwarz), malt der Strich Weiss (Radierer), sonst das Zeichen-Tile (bzw. Schwarz). Solange A gehalten wird, malen Cursor-Bewegungen denselben Wert weiter; Zellen werden nicht einzeln invertiert. Gleiche Semantik in allen drei Editierstufen (Editor-, Zoom-, PixelRoom).
  - B (kurz) ist die Pipette: Tile an der Cursor-Position wird aktives Zeichen-Tile; Pipette auf Weiss waehlt ab. Die Pipette feuert bei B-Release ohne akkumulierte Zoom-Ticks.
  - Crank ohne Modifier verwaltet Animationsframes (eine Rastung = ein Frame, getCrankTicks(4)); ein globaler Tile-Picker existiert nicht mehr.
  - B halten + Crank wechselt die Zoomstufe (Tick-Akkumulation); waehrend B gehalten ist, loest der Crank keine Frame-Wechsel aus. An den Enden der Kette (Editor rueckwaerts, PixelRoom vorwaerts) ist der Trigger ein No-op.

- Der Editing-Flow ist gestuft (genau drei Zoomstufen, FR-009):
  - EditorRoom (25x15-Tilemap, 16x16-Tiles),
  - ZoomRoom (3x3-Tile-Kontext als 24x24-Malraster, 2x2-Pixelbloecke),
  - PixelRoom (Einzeltile mit echten 16x16 Pixeln).

Nutzen: klare mentale Modelle ohne Moduswechsel — der fruehere EditMode-Automat samt B-Long-Press (AD-014) ist ersatzlos entfallen; Frames und Zoom liegen direkt am Crank.

## 8.2 Rendering- und Redraw-Konzept

- Rendering ist zustandsbasiert ueber needsRedraw ("dirty flag"): Raeume zeichnen nur nach Zustandsaenderung neu, der Framebuffer bleibt sonst stehen.
- Ausnahme SelectionRoom bei offenem SDK-Keyboard: solange keyboard.isVisible() gilt, wird jeder Frame gezeichnet (Keyboard-Animation + live mitlaufende Eingabezeile).
- EditorRoom zeichnet die Tilemap direkt bei (0,0) auf die volle 400x240-Flaeche — Daten- und Anzeigeaufloesung fallen zusammen (AD-016), ein Offscreen-Buffer existiert nicht mehr. Cursor (PencilCursor), optionales Grid-Overlay und Bauchbinde liegen darueber.
- Frame-Wechsel sind reine Index-Operationen: tilemap:setTiles(frames[f], 25) plus Redraw; im Update-Pfad werden keine Bilder kopiert.
- ZoomRoom zeichnet Zellinhalt plus Tilegrenzen; gestrichelte Zellgrenzen folgen dem showGrid-Status des Editors. PixelRoom rendert sein 16x16-Raster ueber gridview.
- loadingBar und Bauchbinde nutzen die native Aufloesung fuer scharfe Text- und UI-Darstellung.
- Timer-Updates (keyRepeat, Richtungshalten) laufen zentral im Update-Loop des jeweiligen Rooms.

Nutzen: geringer Overhead auf limitierter Hardware, eine einzige Koordinatenebene (R-11/T-09 entfallen).

## 8.3 Persistenz- und Formatkonzept

- Ein Bild wird nativ gespeichert (AD-017, Constitution II): saves/<id>/sheet.pdi (deduplizierte 16x16-Tiles als PDI), frames.json (375 Tile-Indizes je Frame, max. 12 Frames), preview.pdi (Vorschaubild aus Frame 1).
- Tiles werden vor dem Speichern via FNV-1a-Hash dedupliziert; kein Tile wird doppelt abgelegt.
- Die Laufzeitrepraesentation imageData = {id, name, imagetable, frames, hashIndex} entsteht beim Laden (Sheet-Slicing) und ist die einzige Datenquelle des Editors.
- Der Index (saves/index) wird als letzte Save-Phase aktualisiert (C-06) und traegt lastEditedId fuer den Startscreen.
- Datei-Endungen vergibt der SDK-Datastore selbst (.json bei write/read, .pdi bei writeImage/readImage); im Code stehen Pfade daher ohne Endung. Geloescht wird deshalb der komplette Bild-Ordner rekursiv (playdate.file.delete(path, true)) statt einzelner Dateien.

Nutzen: schnelle SDK-native Ladepfade ohne eigene Parser; Unabhaengigkeit vom Pulp-Oekosystem.

## 8.4 Tile-Lifecycle-Konzept

- Basistiles sind stabil: Index 1 = Voll-Weiss, Index 2 = Voll-Schwarz (Grundlage von Toggle und "Zuruecksetzen auf Weiss"). Diese Invariante wird an beiden Entstehungsorten der Imagetable erzwungen: bei der Neuanlage (createImage) und beim Laden (sliceSheetToImagetable erzeugt fehlende Basistiles als Fallback, auch bei fehlendem oder unvollstaendigem Sheet).
- Malen im Editor schreibt ausschliesslich Frame-Indizes; neue Tile-Bilder entstehen nur ueber den Zoom-Commit.
- Zoom-Commits uebergeben nur geaenderte Slots; EditorRoom:applyTileEdits dedupliziert ueber hashIndex-Treffer plus Pixelvergleich oder haengt ein neues Tile an die Imagetable an (waechst dynamisch, mit Neuaufbau-Fallback) und fuehrt den hashIndex nach.
- Geschrieben wird ausschliesslich frames[currentFrame] (FR-013) — mit einer dokumentierten Ausnahme: "All Similar" (PixelRoom) bearbeitet das Tile in-place in der Imagetable und wirkt damit auf alle Verwendungen ueber alle Frames hinweg.
- Eine Kompaktierung ungenutzter Tiles findet derzeit nicht statt; das Wachstum der Imagetable wird beobachtet (R-13).

Nutzen: begrenzter Speicherverbrauch durch Dedup und konsistente Tile-Referenzen ueber alle Frames.

## 8.5 Evolutionaeres Planungskonzept

Die Entwicklung folgt dem Spec-Kit-Ablauf (Constitution -> Spec -> Plan -> Tasks -> Implementierung) unter specs/; arc42 wird im selben Aenderungsschnitt mitgezogen (Constitution III). Historische Plaene unter plans/ und support/concepts dokumentieren die Evolution bis v0.2.

Nutzen: nachvollziehbare Entscheidungen und kontrollierte technische Schulden.

## 8.6 Asynchrones Operationskonzept (Save/Load)

- Langlaufende Save/Load-Aktionen laufen room-lokal ueber RoomOperation als Coroutine, fortgesetzt pro Frame in update().
- RoomOperation reicht Phasen-Yields als Detailtext ans Overlay und das Ergebnis der Coroutine an onComplete durch; Fehler laufen ueber onError (Overlay-Fehlerstatus, Room raeumt seine Referenz auf).
- Waehrend einer aktiven Operation werden konkurrierende Eingaben blockiert — im EditorRoom einschliesslich der Systemmenue-Aktionen.
- JSON-/Datastore-read/write bleiben als einzelne Runtime-Aufrufe blockierend; diese Phasen sind explizit als finale Schritte markiert.

Nutzen: sichtbarer Fortschritt, bessere Responsivitaet, weniger Duplikation zwischen Rooms.

## 8.7 Modul-Verantwortungen

- ImageStore (Verwaltung/Index) ist von ImageStoreCodec (Kodierung/Dekodierung) getrennt.
- Wiederverwendbare UI-Bausteine (loadingBar, Bauchbinde, PencilCursor) sind von Room-Logik entkoppelt.
- Der EditorRoom buendelt Cursor-, Mal-, Frame- und Zoom-Trigger-Logik in einem Room; die Zoomraeume kapseln ihre Raster- und Commit-Logik selbst.

Nutzen: klare Zustandsgrenzen und geringe Kopplung zwischen Persistenz und UI.

## 8.8 SDK-Konformitaets- und Testkonzept

Hintergrund: Eine Serie von Laufzeit-Crashes in v0.3.0 ging auf dieselbe Fehlerklasse zurueck — plausibel klingende, aber nicht existierende SDK-APIs, die erst beim ersten Aufruf auf dem Geraet crashen (Lua ist dynamisch, pdc prueft keine API-Namen).

Regeln:

| Regel | Begruendung / typischer Fehler |
|---|---|
| import nur auf Dateiebene | import ist eine pdc-Compile-Direktive; Aufruf zur Laufzeit wirft "import() called outside of pdz loading". |
| SDK-Aufrufe gegen die lokale SDK-Quelle verifizieren (CoreLibs/*.lua, CoreLibs/__stub.lua, Inside Playdate) | Erfundene APIs wie gridview:setSelectedCell, keyboard.setCommitCallback oder gfx.drawImage — richtig sind setSelection(section, row, col), keyboardWillHideCallback(ok) und image:draw(x, y). |
| Gridview-/SDK-Callbacks als Methoden definieren (self-Parameter) | Das Gridview ruft drawCell als self:drawCell(...) auf; ohne self verschieben sich alle Argumente um eins. |
| Keyboard-Callbacks sind Felder, keine Setter; show(text) setzt den Textinhalt | Es gibt keine set*Callback-Funktionen und keinen Prompt-Parameter. |
| Kein Raumwechsel aus SDK-Callbacks heraus, solange das SDK-Modul aktiv ist | keyboardWillHideCallback feuert beim START der Zuklapp-Animation; das Keyboard haelt playdate.update und einen Input-Handler. Ein switchRoom in dem Moment korrumpiert den Handler-Stack. Muster: Absicht vormerken (pendingCommitName) und in update() ausfuehren, sobald keyboard.isVisible() false ist. |
| Jeder SDK-Aufruf im Code traegt einen Referenz-Kommentar | Der Code dient zugleich als SDK-Lernmaterial (Projektziel). |

Teststrategie: tests/headless_tests.lua laedt die echten Source-Dateien mit strikten Playdate-Mocks in einem normalen Lua-Interpreter; jeder Zugriff auf eine unbekannte SDK-Methode schlaegt sofort fehl. Getestet werden Navigations-Klemmen des SelectionRoom, der Keyboard-Commit/Abbruch-Flow und die reinen Codec-Helfer (Sheet-Geometrie). Der pdc-Build fungiert zusaetzlich als Syntax-Gate.

Nutzen: Die haeufigste Crash-Klasse wird vor dem Simulator-Lauf gefangen; Regressionen in der Raum-Logik sind ohne Geraet pruefbar.

## 8.9 Import-Integritaetskonzept (Tools/Importer, historisch)

- Das Browser-Tool arbeitet auf dem Pulp-JSON-Format (v0.2) und ist mit dem v0.3.0-Format nicht kompatibel (R-14); eine Anpassung ist ein spaeteres Vorhaben.
- Es bleibt strikt offline und exportbasiert (kein in-place Ueberschreiben) und nutzt dasselbe Dedupe-Prinzip (FNV-1a) wie der Editorpfad.

Nutzen: klare Trennung zur Device-Runtime; dokumentierter Ausgangspunkt fuer einen kuenftigen v0.3.0-Import.
