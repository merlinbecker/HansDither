# Data Model: Editor-Umbau — 16×16-Tiles, Animation und Zoomstufen

**Feature**: 003-editor-animation-zoom | **Date**: 2026-07-03

Persistenz und Laufzeitrepräsentation kommen vollständig aus Spec 001 (`imageData`); hier ist der Editor-Zustand samt Operationen beschrieben.

## EditorRoom-Zustand

| Feld | Typ | Regeln |
|---|---|---|
| `imageData` | table | `{id, name, imagetable, frames, hashIndex}` — gesetzt via `setImage(id)` + Load-Operation (Spec-001-Contract); nie nil während der Room aktiv ist |
| `currentFrame` | number | 1..#frames; Wechsel setzt `tilemap:setTiles(frames[currentFrame], 25)` |
| `tilemap` | playdate.graphics.tilemap | 25×15, ImageTable = `imageData.imagetable`; einzige Renderquelle der Malfläche |
| `cursor` | {x, y} | 1..25 / 1..15; D-Pad bewegt tileweise (Richtungs-Halten wiederholt, Bestandsmuster) |
| `activeTile` | number/nil | Pipetten-Auswahl; nil = Schwarz/Weiß-Toggle-Modus; frame-unabhängig (Edge Case Spec) |
| `zoomTickAccu` | number | Tick-Akkumulator für B+Crank (Muster aus TileRoom); Reset bei B-Release |
| `showGrid` | boolean | Checkmark-Menüeintrag; wird an ZoomRoom weitergereicht (FR-015) |
| `savingOperation` | RoomOperation/nil | aktiv während "save + exit"; blockiert alle Eingaben |
| `needsRedraw` | boolean | Bestandsmuster |

### Invarianten

- `frames[f]` enthält ausschließlich Indizes `1..#imagetable` (Spec-001-Validierung; Editor erzeugt nur gültige Indizes).
- `1 <= #frames <= 12`; `1 <= currentFrame <= #frames`.
- Index 1 = Voll-Weiß, Index 2 = Voll-Schwarz (Contract C-03) — Grundlage von Toggle und "Zurücksetzen auf Weiß".
- `hashIndex` ist konsistent zur Imagetable (Load baut ihn auf; jede `setImage`-Erweiterung trägt nach).

## Frame-Operationen

```text
tickForward()   currentFrame < #frames → currentFrame += 1
                currentFrame == #frames und #frames < 12
                                → frames[#frames+1] = copy(frames[currentFrame]); currentFrame += 1
                currentFrame == #frames == 12 → currentFrame = 1   (Rotation, FR-007)
tickBackward()  currentFrame > 1 → currentFrame -= 1
                currentFrame == 1 → currentFrame = #frames          (Clarification; erzeugt nie Frames)
deleteFrame()   #frames > 1 → table.remove(frames, currentFrame);
                currentFrame = min(currentFrame, #frames)           (FR-008a + Edge Case)
                #frames == 1 → gesperrt (Menüeintrag wirkungslos/deaktiviert)
Nach jeder Operation: tilemap:setTiles(frames[currentFrame], 25); Bauchbinde "Frame n/m"
```

## Mal-Operationen (aktiver Frame)

```text
pipette(cursor)     idx = frames[f][cell(cursor)]
                    idx == 1 → activeTile = nil        (Abwahl)
                    sonst    → activeTile = idx
paint(cursor)       mit activeTile:  cell == activeTile → set(1)  sonst → set(activeTile)
                    ohne activeTile: cell == 1 → set(2)  sonst → set(1)      (Toggle FR-004)
set(idx)            frames[f][cell] = idx; tilemap:setTileAtPosition(x, y, idx); needsRedraw
```

## Zoomkontexte

### Editor → ZoomRoom (Kontextübergabe)

| Feld | Inhalt |
|---|---|
| `slots[3][3]` | je Slot: `{tileX, tileY, frameIndexPos, originalIndex, originalImage}`; out-of-bounds-Slots markiert (Bestandslogik) |
| `gridState` | 24×24 boolesches Raster, initialisiert aus den 3×3 Tile-Images (Auslesen mit 2×2-Blockauflösung: Zelle (cx,cy) = Pixel (2cx, 2cy) des 48×48-Kontexts) |
| `showGrid` | vom Editor übernommen (FR-015) |

Malen im ZoomRoom: 1 Zelle = 2×2 native Pixel (research.md R5); Anzeige-Zellgröße 10 px (240×240, zentriert).

### ZoomRoom → PixelRoom

Einzelner Slot als 16×16-Pixelraster (`gridState` 16×16, boolesch); Anzeige ~14 px/Zelle. Rückgabe wie bisher an ZoomRoom (geänderter Slot-Inhalt).

### Commit beim Rauszoomen (ZoomRoom → Editor)

```text
für jeden geänderten Slot (Pixelvergleich gegen originalImage, Bestandslogik):
  neuesImage bauen → hash = hashTile(neuesImage)
  hashIndex[hash] vorhanden (+ Pixelvergleich) → idx = vorhandener Index
  sonst → idx = #imagetable+1; imagetable:setImage(idx, neuesImage); hashIndex[hash] = idx
  frames[currentFrame][slot.frameIndexPos] = idx        (nur aktiver Frame, FR-012/FR-013)
"All Similar" (PixelRoom): bearbeitet imagetable[idx] in-place → wirkt auf alle Verwendungen
```

## Übergänge (Room-Ebene)

```text
SelectionRoom --setImage(id)--> EditorRoom.entered(): Load-Operation (Spec 001), danach Frame 1
EditorRoom --B+Crank vor--> ZoomRoom --B+Crank vor--> PixelRoom
PixelRoom --B+Crank zurück--> ZoomRoom --B+Crank zurück (Commit)--> EditorRoom
EditorRoom --Menü "save + exit"--> Save-Operation --Erfolg--> SelectionRoom
playdate.gameWillTerminate() --> Save des offenen Bildes (Spec 001 FR-005)
```
