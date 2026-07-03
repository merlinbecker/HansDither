# Contract: EditorRoom — Room-API, Eingaben und Zoom-Übergaben

**Feature**: 003-editor-animation-zoom | **Date**: 2026-07-03

## 1. Room-API (Konsumenten: `Source/main.lua`, `Source/SelectionRoom.lua`)

```lua
-- Source/EditorRoom.lua (Room-Muster wie alle bestehenden Rooms)
EditorRoom:init(switchRoom, zoomRoom, selectionRoom)
EditorRoom:setImage(id)     -- von SelectionRoom vor switchRoom gesetzt (Spec-002-Contract S-01)
EditorRoom:entered()        -- startet Load-Operation (ImageStoreCodec.newLoadOperation, loadingBar);
                            -- nach Erfolg: Frame 1 aktiv, Menü (3 Slots) registriert
EditorRoom:update()         -- tilemap + Cursor + Bauchbinde + ggf. Operation/Overlay
EditorRoom:inputHandler()   -- gemäß Eingabe-Contract unten
EditorRoom:getImageData()   -- für Terminate-Hook in main.lua (Save des offenen Bildes)
```

- **E-01**: `setImage(id)` lädt nichts synchron; das Laden läuft als RoomOperation in `entered()` (Fehlerfall: Fehlerstatus, Rückkehr zum SelectionRoom, kein Absturz — Spec-001-Fehlersemantik).
- **E-02**: "save + exit" speichert via `ImageStoreCodec.newSaveOperation(imageData)` und wechselt erst nach Erfolg zum SelectionRoom (FR-014; Spec-002-Contract S-02 übernimmt die Preview-Aktualisierung).
- **E-03**: `playdate.gameWillTerminate()` in main.lua speichert das offene Bild, wenn EditorRoom (oder eine Zoomstufe) aktiv ist; Zoomstufen committen dabei zuerst ihren Slot-Zustand.

## 2. Eingabe-Contract (bindet FR-002..FR-011)

| Eingabe | Kontext | Wirkung |
|---|---|---|
| D-Pad | Editor | Cursor tileweise bewegen; Halten wiederholt (FR-002) |
| B (kurz) | Editor | Pipette: Tile an Cursor als `activeTile`; auf Weiß (Index 1) → Abwahl (FR-003, research.md R4) |
| A | Editor, `activeTile` gesetzt | Zelle = activeTile; war sie schon activeTile → Zelle = Weiß (FR-004) |
| A | Editor, kein `activeTile` | Toggle Weiß(1) ↔ Schwarz(2) (FR-004) |
| Crank ±1 Tick (getCrankTicks(4)) | Editor, B nicht gehalten | Frame vor/zurück; vorwärts legt Kopie an (< 12), rotiert bei 12→1; rückwärts rotiert 1→letzter (FR-006/FR-007) |
| Crank | Editor, B nicht gehalten | KEINE Tile-Auswahl (FR-005 — Picker existiert nicht mehr) |
| B halten + Crank vor/zurück | Editor/ZoomRoom/PixelRoom | Zoomstufe rein/raus; genau 3 Stufen (FR-009) |
| Menü "save + exit" | Editor | Autosave + Rückkehr (FR-014) |
| Menü "delete frame" | Editor, #frames > 1 | aktiven Frame entfernen, Nachrücker aktiv (FR-008a); bei #frames == 1 wirkungslos |
| Menü "show grid" (Checkmark) | Editor | Grid-Overlay an/aus; Status wird an ZoomRoom durchgereicht (FR-015) |
| beliebig | laufende Save-/Load-Operation | blockiert (Edge Case Spec) |

Frame-Anzeige: Bauchbinde zeigt "Frame n/m" bei jedem Frame-Wechsel (FR-008).

## 3. Zoom-Übergabe-Contracts

```lua
-- Editor → ZoomRoom
ZoomRoom:setFromEditorContext(ctx)
-- ctx = { slots (3×3, je {tileX, tileY, frameIndexPos, originalIndex, originalImage}),
--         gridState (24×24, aus 48×48-Pixelkontext mit 2×2-Blockauflösung),
--         showGrid, imageData-Referenz }

-- ZoomRoom → Editor (Commit beim Rauszoomen)
EditorRoom:applyTileEdits(edits)
-- edits = Liste { frameIndexPos, newImage } NUR für geänderte Slots (Pixelvergleich, Bestandsmuster)
-- EditorRoom dedupliziert: hashTile → hashIndex-Treffer (+ Pixelvergleich) oder
-- imagetable:setImage(#imagetable+1, newImage); schreibt NUR frames[currentFrame] (FR-012/FR-013)

-- ZoomRoom ↔ PixelRoom: bestehendes Übergabemuster, Raster 16×16 statt 8×8;
-- "All Similar" bearbeitet imagetable[idx] in-place (wirkt auf alle Verwendungen, FR-015)
```

- **Z-01**: ZoomRoom-Malstrich schreibt exakt 2×2 native Pixel (FR-010); PixelRoom exakt 1 Pixel (FR-011).
- **Z-02**: Out-of-bounds-Slots (Cursor am Rand) sind nicht editierbar (Bestandsverhalten, Edge Case Spec).
- **Z-03**: Kein Commit ohne Änderung — unveränderte Slots erzeugen keine neuen Tiles (FR-012, SC des QS-06-Musters).

## 4. Entfallende Schnittstellen (Abschluss des Umbaus)

| Entfällt | Ersatz |
|---|---|
| `TileRoom:setGame/getTileContext3x3/applyTileEditsBatch/saveToFile` | EditorRoom-API oben |
| `LoadRoom`/`LoadRoomGrid` (Room + Grid) | SelectionRoom (Spec 002) — Open-Punkt aus Spec 002 wird hier geschlossen |
| `PulpGameIO.*` (4 Module) | `ImageStore`/`ImageStoreCodec` (Spec 001) |
| Crank-Tile-Picker, B-Long-Press-Moduswechsel (AD-014) | Pipette (B kurz), Crank = Frames (AD-019) |
