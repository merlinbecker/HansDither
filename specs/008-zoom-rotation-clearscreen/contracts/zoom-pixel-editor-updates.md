# Contract: Zoom-Room-Performance, Pixel-Rotation und vereinfachte Frame-Verwaltung — geänderte/neue Schnittstellen

**Feature**: 008-zoom-rotation-clearscreen | **Date**: 2026-07-22

Ergänzt (überschreibt NICHT) `specs/003-editor-animation-zoom/contracts/editor-room.md`
und `specs/006-editor-ui-polish/contracts/editor-room-ui-polish.md` — nur
hier gelistete Punkte ändern sich; alle dort dokumentierten E-01..E-03/
Z-01..Z-03/CR-01..CR-04-Contracts bleiben unverändert gültig. Neue Klauseln
dieser Spec nutzen die Präfixe `ZR-` (ZoomRoom-Rendering), `PR-`
(PixelRoom-Rotation) und `EM-` (Editor-Systemmenü), um Kollisionen mit
bestehenden Nummerierungen auszuschließen.

## 1. Zoom-Room-Rendering-Contract (ergänzt Z-01/CR-04)

**ZR-01**: `ZoomRoom:drawGrid()` DARF pro Redraw höchstens einmal den
gesamten 24×24-Rasterbereich neu berechnen (Cache-Aufbau bei
`backgroundDirty`); jeder weitere Redraw MUSS sich auf `changedCells`
(Zellen mit tatsächlicher Zustandsänderung) plus den Cursor beschränken
(FR-002).

**ZR-02**: `backgroundDirty` MUSS bei jedem Ereignis gesetzt werden, das
den zugrunde liegenden Bildinhalt oder die Anzeigeeinstellungen ändert:
`entered()`, `setFromEditorContext()`, `setNewTile()`,
`updateExistingTile()` (**korrigiert bei der Implementierung**:
`showGridLines` ändert sich ausschließlich innerhalb von
`setFromEditorContext()`, es gibt keinen separaten Live-Toggle in einer
laufenden Zoom-Room-Sitzung, siehe data-model.md). Cursorbewegung und
Malstriche setzen es NICHT (FR-001/003).

**ZR-03**: Das bestehende Editier-/Commit-Verhalten (`beginStroke`,
`paintCurrentCell`, `collectEdits`, Dedup-Pfad) sowie alle bestehenden
Zusatzfunktionen (Invert, "All Similar", Out-of-Bounds-Verhalten) MÜSSEN
nach dieser Änderung unverändert funktionieren (FR-004) — die Contracts
Z-01..Z-03 und CR-04 (Spec 003/006) bleiben in Kraft.

## 2. Pixel-Room-Rotations-Contract (NEU)

**PR-01**: Im Pixel Room MUSS eine Crank-Drehung OHNE gehaltene B-Taste
über `playdate.getCrankChange()` in `rotationAccumDegrees` akkumuliert
werden; bei B gehalten bleibt `playdate.getCrankTicks(4)` für die
bestehende Zoom-Out-Geste unverändert zuständig (FR-005/006/009/010). Pro
`PixelRoom:update()`-Aufruf wird GENAU EINE Crank-Lese-API verwendet
(analog zu CR-01 aus Spec 006).

**PR-02**: Erreicht `rotationAccumDegrees` ≥360°, MUSS `gridState` exakt
gemäß der Formel `new[r][c] = old[17-c][r]` (1-indiziert, 16×16) rotiert
werden (FR-005); bei ≤-360° gilt `new[r][c] = old[c][17-r]` (FR-006). Der
Akkumulator wird jeweils um ±360° reduziert, nicht auf 0 zurückgesetzt.

**PR-03**: Teildrehungen (< 360° netto) DÜRFEN `gridState` NICHT
verändern (FR-007) — nur `rotationAccumDegrees` wird fortgeschrieben.

**PR-04**: Die Rotation wirkt ausschließlich auf das aktuell im Pixel
Room offene `gridState`; das Ergebnis MUSS beim Verlassen des Pixel Room
über den bestehenden `buildTileImage()`/Dedup-Commit-Pfad übernommen
werden, wie jede andere Pixel-Änderung (FR-008, unverändert gegenüber
Z-01..Z-03).

## 3. Editor-Systemmenü-Contract (ersetzt den "reset frame"-Eintrag aus CR-08/AD-032)

**EM-01**: `EditorRoom:buildSystemMenu()` MUSS den dritten Menü-Slot von
`"reset frame"` auf `"clear screen"` umstellen und dabei
`clearCurrentFrame()` statt `resetCurrentFrameToPrevious()` aufrufen;
`"save + exit"` und `"show grid"` bleiben unverändert (FR-011/012/014).

**EM-02**: `clearCurrentFrame()` MUSS jeden der 375 Tile-Indizes des
aktiven Frames auf den Basis-Index 1 (Voll-Weiß, `ImageStoreCodec`-
Invariante) setzen und darf keine anderen Einträge in `imageData.frames`
verändern (FR-013/015).

**EM-03**: Die Funktion `resetCurrentFrameToPrevious()` MUSS vollständig
aus `Source/EditorRoom.lua` entfernt werden (FR-011) — im Unterschied zu
AD-032 (Spec 006), wo `deleteCurrentFrame()` bewusst als toter Code im
Code verblieb, verlangt diese Spec die vollständige Entfernung der
Funktion "Reset Frame", nicht nur ihres Menü-Zugriffs.
