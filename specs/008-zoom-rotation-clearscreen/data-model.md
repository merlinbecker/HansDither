# Phase 1 Data Model: Zoom-Room-Performance, Pixel-Rotation und vereinfachte Frame-Verwaltung

**Feature**: 008-zoom-rotation-clearscreen | **Date**: 2026-07-22

Kein neues Persistenzformat (Constitution II) — alle hier beschriebenen
Strukturen sind reiner Laufzeit-Zustand innerhalb der jeweils genannten
Room-Module, aufbauend auf der bestehenden `imageData`-Struktur (Spec 001)
und den bereits vorhandenen Modul-Zuständen aus Spec 003/006.

---

## 1. Zoom-Room-Redraw-Zustand (`ZoomRoom.lua`, R1 — FR-001/002/003/004)

| Feld | Typ | Beschreibung |
|---|---|---|
| `cachedBackground` | `playdate.graphics.image` (400×240, **korrigiert bei der Implementierung von der ursprünglich geplanten 240×240-Variante** — enthält bewusst auch die Checkerboard-Seitenflächen, damit ein einziger `draw(0, 0)`-Aufruf statt eines separaten Seiten-Redraws genügt) oder `nil` | Vorgerenderter statischer Hintergrund (Checkerboard-Seiten, alle 576 Zellen im unbearbeiteten Subpixel-Zustand, gestrichelte Zell- und durchgezogene Tile-Grenzen). `nil` = muss vor dem nächsten Redraw aufgebaut werden. |
| `changedCells` | Liste von `{row, col}` | Zellen, die seit dem letzten Cache-Aufbau vom Grundzustand abweichen (bearbeitet wurden). Wird in `paintCurrentCell()` ergänzt, beim Cache-Aufbau geleert. |
| `backgroundDirty` | boolean | `true` erzwingt einen vollständigen Neuaufbau von `cachedBackground` vor dem nächsten Redraw. |

**Übergänge**:
- `ZoomRoom:entered()`, `setFromEditorContext()`, `setNewTile()`,
  `updateExistingTile()`, `showGridLines`-Toggle → `backgroundDirty = true`.
- Vor jedem Redraw: wenn `backgroundDirty` (oder `cachedBackground == nil`),
  `cachedBackground` einmalig neu aufbauen (bestehende `drawGrid()`-Logik
  für Hintergrund + Gitterlinien, siehe research.md R1), danach
  `changedCells = {}`, `backgroundDirty = false`.
- `paintCurrentCell(value)`: setzt `gridState[row][col] = value` (wie
  bisher) UND fügt `{row, col}` zu `changedCells` hinzu, falls noch nicht
  enthalten.
- Redraw (`drawGrid()`, neu): `cachedBackground:draw(0, 0)` (Vollbild-Blit,
  Cache enthält bereits die Seitenflächen an ihrer finalen Position)
  → für jede Zelle in `changedCells` die aktuelle Farbe
  (`gridState[row][col]`) flächig zeichnen → Gitterlinien-Overlay
  entfällt (bereits Teil des Caches) → Cursor zeichnen.
- Verlässt der Nutzer den Zoom Room (Commit/Zoom-out), werden
  `cachedBackground`/`changedCells` verworfen (nächster Eintritt baut neu
  auf) — kein Zustand überlebt eine Zoom-Room-Sitzung hinaus.

---

## 2. Rotations-Akkumulator (`PixelRoom.lua`, R2 — FR-005/006/007)

| Feld | Typ | Beschreibung |
|---|---|---|
| `rotationAccumDegrees` | number (signiert) | Netto-Grad seit letzter Rotation; positiv = im Uhrzeigersinn, negativ = gegen den Uhrzeigersinn. Initial `0`. |

**Übergänge** (analog zu `crankAccumDegrees` in `EditorRoom.lua`,
Spec 006 R1 — siehe research.md R2):
- Bei jedem `PixelRoom:update()`-Aufruf OHNE gehaltene B-Taste:
  `change = playdate.getCrankChange(); rotationAccumDegrees += change`.
- `rotationAccumDegrees >= 360` → `rotationAccumDegrees -= 360`,
  `rotateGridClockwise()` (FR-005).
- `rotationAccumDegrees <= -360` → `rotationAccumDegrees += 360`,
  `rotateGridCounterClockwise()` (FR-006).
- Kein Reset auf 0 bei Richtungswechsel — der signierte Wert gleicht sich
  durch Addition von selbst aus (FR-007, keine sichtbare Zwischen-Rotation
  bei Teildrehungen).
- Bei gehaltener B-Taste: `rotationAccumDegrees` wird NICHT verändert; der
  Crank-Wert fließt stattdessen unverändert in die bestehende
  `getCrankTicks(4)`-Zoom-Out-Kette (FR-010, research.md R2).
- Beim Betreten des Pixel Room (`PixelRoom:setCurrentTile()`):
  `rotationAccumDegrees = 0` (kein Übertrag zwischen Bearbeitungssitzungen
  verschiedener Tiles).

---

## 3. Pixel-Rotation (`PixelRoom.lua`, R3 — FR-005/006/008)

Kein neues Datenfeld — Transformation direkt auf dem bestehenden
`gridState[row][col]` (16×16 Bool-Tabelle, `true` = schwarz).

```text
rotateGridClockwise():
  fuer r = 1..16, c = 1..16:
    new[r][c] = gridState[17 - c][r]
  gridState = new

rotateGridCounterClockwise():
  fuer r = 1..16, c = 1..16:
    new[r][c] = gridState[c][17 - r]
  gridState = new
```

Beide Funktionen setzen anschließend `needsRedraw = true`. Die
selektierte Gridview-Zelle (`gridView:getSelection()`) bleibt
positionsstabil (Spalte/Zeile ändern sich nicht durch die Rotation) —
der Cursor "wandert" also relativ zum gedrehten Bildinhalt, was dem
FR-008-Verhalten entspricht (Rotation ist eine Zustandsänderung des
Tile-Inhalts, keine Cursor-Aktion). Die Rotation wirkt ausschließlich auf
`gridState`; erst beim Verlassen des Pixel Room (`commitToZoomRoom()`)
fließt das Ergebnis über den bestehenden `buildTileImage()`/Dedup-Pfad in
den Zoom Room bzw. Editor zurück (FR-008, unverändertes Commit-Verhalten).

---

## 4. Aktiver Frame / "Clear Screen" (`EditorRoom.lua`, R4 — FR-011/012/013/014/015)

Kein neues Datenfeld — Wiederverwendung der bestehenden
`imageData.frames[currentFrame]`-Struktur (Array von 375 Tile-Indizes,
Spec 001) und der Basistile-Invariante aus `ImageStoreCodec`
(Index 1 = Voll-Weiß, Index 2 = Voll-Schwarz).

```text
clearCurrentFrame():
  current = imageData.frames[currentFrame]
  fuer i = 1..#current:
    current[i] = 1   -- Voll-Weiß-Basistile
  updateTilemapFrame()
  needsRedraw = true
```

**Menü-Zustand** (`buildSystemMenu()`): dritter Systemmenü-Slot zeigt
`"clear screen"` statt `"reset frame"`; ruft `clearCurrentFrame()` statt
`resetCurrentFrameToPrevious()` auf. Die Funktion
`resetCurrentFrameToPrevious()` selbst wird aus `EditorRoom.lua` entfernt
(FR-011, research.md R4 — vollständige Entfernung, kein toter Code wie
bei `deleteCurrentFrame()`/AD-032).

**Invarianten**:
- Frame-Anzahl und -Reihenfolge bleiben unverändert (FR-015) — nur die
  375 Indizes des AKTIVEN Frames werden überschrieben.
- Andere Frames sind über separate Array-Referenzen in
  `imageData.frames` unabhängig und bleiben unangetastet (FR-013).
- `clearCurrentFrame()` auf einem bereits vollständig weißen Frame ist
  idempotent (alle Werte sind bereits `1`, keine sichtbare Änderung).
