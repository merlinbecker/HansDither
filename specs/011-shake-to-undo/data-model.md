# Data Model: Schüttel-Undo für die letzten 3 riskanten Aktionen

**Feature**: `specs/011-shake-to-undo` | **Date**: 2026-09-02

Alle Strukturen sind **reine Lua-Tabellen**, reiner Sitzungszustand, **nicht persistiert**. Kein Einfluss auf `frames.json` / `sheet.pdi` / `ImageStoreCodec`.

---

## 1. UndoHistory

Ringpuffer der letzten ≤ 3 riskanten Operationen. Instanz gehört `EditorRoom`.

```lua
history = {
  entries = { <UndoEntry>, ... },   -- 0..3, index 1 = ÄLTESTER, index #entries = JÜNGSTER
  MAX = 3,
}
```

| Feld | Typ | Regel |
|---|---|---|
| `entries` | Array von `UndoEntry` | Länge 0..3. `push` hängt hinten an; bei Länge > 3 wird `entries[1]` (ältester) entfernt (**FIFO-Verdrängung, FR-001**) |
| `MAX` | Zahl | konstant 3 (harte Grenze, Constitution IV) |

**Operationen**

| Funktion | Wirkung |
|---|---|
| `push(entry)` | anhängen; auf `MAX` kürzen (vorne verdrängen) |
| `peekValid(imageData) -> entry, reason` | jüngsten **anwendbaren** Eintrag liefern; nicht anwendbare dabei verwerfen. Nicht anwendbar: `content` mit fehlendem Ziel-Frame (**FR-006**) **oder** `deleteFrame`, dessen Wiedereinfügen `#frameLayers >= 12` verletzt (**FR-007**). Nichts Anwendbares → `entry = nil`. `reason == "frame-limit"`, wenn dabei ein `deleteFrame`-Eintrag an der 12-Grenze verworfen wurde (nur Meldungstext), sonst `nil` |
| `pop()` | jüngsten Eintrag entfernen (nach erfolgreichem Undo, **FR-004**) |
| `clear()` | `entries = {}` — bei Bildwechsel / Verlassen des Editors (**FR-008**) |
| `isEmpty()` | `#entries == 0` (**FR-009**) |
| `coalesceTarget(type, frameIndex, layerArrayIndex, cellKey?)` | liefert den jüngsten Eintrag, wenn er denselben laufenden „Run" fortsetzt (siehe §4), sonst `nil` |

**Lebenszyklus**: `clear()` in `EditorRoom` bei `handleLoadSuccess` und beim Wechsel zu `SelectionRoom`. Kein `clear()` bei Frame-/Room-/Ebenen-Wechsel und **nicht** beim Speichern (in der aktuellen Codebasis existiert ohnehin nur „save + exit", das ohnehin `clear()` über den Selection-Wechsel auslöst).

---

## 2. UndoEntry

Zwei Varianten, unterschieden durch `kind`.

### 2a. Content-Eintrag (`kind = "content"`)

Für **Clear Screen**, **90°-Rotation**, **Pixel-Verschiebung** — alle drei ändern Zellen **einer** Ebene **eines** Frames.

```lua
{
  kind = "content",
  op = "clear" | "rotate" | "shift",   -- nur für das Dialog-Label
  frameIndex = <int>,                   -- 1-basiert, Position in imageData.frameLayers
  layerArrayIndex = <int>,              -- 1..3, Index in entry.layers
  cells = {
    [cellIdx] = { prevPosIndex = <int>, prevImage = <gfx.image | nil> },
    ...
  },
  runOpen = <bool>,                     -- true = Run läuft noch, weitere Zellen dürfen ergänzt werden (§4)
}
```

| Feld | Regel |
|---|---|
| `frameIndex` | muss beim Undo noch existieren, sonst Eintrag ungültig (**FR-006**) |
| `layerArrayIndex` | 1..3; jeder Frame hat immer 3 Ebenen (`LayerModel.LAYER_COUNT`) |
| `cells[cellIdx].prevPosIndex` | Tile-Index in `layer.positions` **vor** der Operation (0 = „absent" auf oberer Ebene ist zulässig) |
| `cells[cellIdx].prevImage` | 16×16-`gfx.image` **vor** der Operation, oder `nil`, wenn `prevPosIndex` direkt in der (nur wachsenden) Imagetable auflösbar bleibt. Für `rotate`/`shift` immer gesetzt (neue Bilder). Bilder werden **referenziert, nicht kopiert** |
| `cells` bei `op="clear"` | enthält alle 375 Zellen der aktiven Ebene |
| `cells` bei `op="rotate"` | genau 1 Zelle (die im PixelRoom bearbeitete) |
| `cells` bei `op="shift"` | 1..2 Zellen pro Shift, über den Run akkumuliert (§4) |

**Undo (`applyContentEntry`)** — in `EditorRoom`:
```
entry = imageData.frameLayers[frameIndex]           -- existiert (peekValid geprüft)
layer = entry.layers[layerArrayIndex]
für jede cellIdx in cells:
    if prevImage: idx = registerTile(prevImage)     -- dedupliziert / hängt an
    else:         idx = prevPosIndex
    layer.positions[cellIdx] = idx
currentFrame = frameIndex
recompositeCurrentFrame()  (bzw. recompositeCell je Zelle + updateTilemapFrame)
```

### 2b. Frame-löschen-Eintrag (`kind = "deleteFrame"`)

```lua
{
  kind = "deleteFrame",
  op = "deleteFrame",
  index = <int>,                 -- Ursprungsposition in frameLayers / frames
  frameLayersEntry = <deep copy of imageData.frameLayers[index]>,
  framesEntry      = <copy of imageData.frames[index] | nil>,   -- 375er Composite-Cache; nil, wenn imageData.frames fehlt
}
```

| Feld | Regel |
|---|---|
| `index` | Position, an der der Frame wieder eingefügt wird (geklemmt auf `#frameLayers+1`) |
| `frameLayersEntry` | **tiefe** Kopie: `{ duration, layers = { 3 × { layerIndex, name, visible, positions = copyArray(375) } } }` (via `LayerModel.copyArray` je Ebene) |
| `framesEntry` | flache Kopie des 375er-Arrays — **oder `nil`**, wenn `imageData.frames` beim Erfassen fehlt (defensiver Pfad; `FrameManagementView.deleteMarked` selbst prüft `if imageData.frames`). Erfassung und Undo müssen denselben Guard nutzen |

**Gültigkeit (in `peekValid`, VOR dem Dialog — FR-007)**: Würde `#imageData.frameLayers >= 12` das Wiedereinfügen verletzen, ist der Eintrag **nicht anwendbar** — `peekValid` verwirft ihn und setzt `reason = "frame-limit"`. Es gibt **keine** Ablehnung nach dem A-Druck: entweder erscheint gar kein Dialog (Meldung „cannot undo — frame limit"), oder der Dialog führt garantiert zu einem erfolgreichen Undo.

**Undo (`applyDeleteFrameEntry`)** — in `EditorRoom`, nur für einen von `peekValid` freigegebenen Eintrag:
```
i = min(index, #imageData.frameLayers + 1)
table.insert(imageData.frameLayers, i, frameLayersEntry)
if imageData.frames and framesEntry then table.insert(imageData.frames, i, framesEntry) end
currentFrame = i
imageData.activeLayer = LayerModel.clampActive(imageData.frameLayers[i], imageData.activeLayer or 1)
updateTilemapFrame()
```

---

## 3. ShakeDetector (Zustand)

```lua
{
  T = 0.85,          -- Schwellwert |x| in g   (Hardware-Tuning, ADR-044)
  W = 500,           -- ms: Fenster zwischen den beiden Ausschlägen
  R = 1200,          -- ms: Refraktärzeit nach einer Kante
  lastPosMs = nil,   -- Zeitpunkt letzter Ausschlag  x > +T
  lastNegMs = nil,   -- Zeitpunkt letzter Ausschlag  x < -T
  blockedUntilMs = 0 -- Refraktär-Ende
}
```

**`feed(x, y, z, nowMs) -> bool`** (reine Zustandsfortschreibung):
1. `nowMs < blockedUntilMs` → `false`.
2. `x > T` → `lastPosMs = nowMs`; `x < -T` → `lastNegMs = nowMs`.
3. Liegen `lastPosMs` **und** `lastNegMs` innerhalb `W` ms zueinander → Kante: `blockedUntilMs = nowMs + R`, `lastPosMs = lastNegMs = nil`, `return true`.
4. sonst `false`.

**`reset()`** setzt `lastPosMs/lastNegMs = nil`, `blockedUntilMs = 0` — beim Öffnen des Dialogs und beim Betreten eines Editier-Raums.

Keine Allokation pro `feed`. Kein SDK-Zugriff ⇒ headless-testbar mit synthetischen `(x, nowMs)`-Folgen.

---

## 4. Run-/Coalescing-Zustand (in EditorRoom)

Verhindert, dass wiederholte Shifts/Rotationen je einen Eintrag erzeugen (Clarification „nur große Operationen"; research R3/R4).

```lua
activeRun = { entry = <UndoEntry|nil>, type = "shift"|"rotate"|nil,
              frameIndex = <int>, layerArrayIndex = <int> }
```

| Regel | |
|---|---|
| **shift**: Run-Start beim ersten `shiftActiveLayerContent()` nach `BButtonDown` in `ZoomRoom` → `entry.runOpen = true`, `activeRun` gesetzt | Weitere Shifts im selben B-Halten: nur neue `cells` in denselben `entry` ergänzen (nie `prevImage`/`prevPosIndex` überschreiben, wenn `cellIdx` schon vorhanden) |
| **shift**: Run-Ende bei `BButtonUp` in `ZoomRoom`, beim Verlassen der `ZoomRoom` oder bei Ziel-Zellwechsel → `entry.runOpen = false`, `activeRun = nil` | |
| **rotate**: Snapshot beim **ersten** `rotateGrid*()` je PixelRoom-Sitzung (Flag im PixelRoom), Übergabe an die History **bei `commitToZoomRoom()`** | Mehrere Rotationen derselben Sitzung → ein Eintrag (Pre-Rotation-Zustand) |
| **clear** / **deleteFrame**: nie coalesced — jede Auslösung ein Eintrag | |

---

## 5. UndoPrompt (Zustand)

```lua
{
  open = false,
  label = "",                 -- z.B. "Undo Clear Screen?"
  onConfirm = <function|nil>, -- gesetzt von der aufrufenden Room
}
```

| Feld | Regel |
|---|---|
| `open` | `true` zwischen `open()` und `handleA()`/`handleB()`. Solange `true`: alle Room-Inputs außer A/B geschluckt (**FR-013**), zweite Schüttel-Kante ignoriert (**FR-015**) |
| `label` | aus `entry.op`: `clear`→„Clear Screen", `rotate`→„Rotation", `shift`→„Pixel-Verschiebung", `deleteFrame`→„Frame löschen" |
| `onConfirm` | `handleA()` ruft es (→ `EditorRoom:undoLast()`), dann `open=false`; `handleB()` nur `open=false` |

---

## 6. Beziehungen

```
EditorRoom
 ├─ besitzt  UndoHistory              (entries: ≤3 UndoEntry)
 ├─ besitzt  ShakeDetector            (1 Instanz, von allen 3 Räumen gefüttert)
 ├─ besitzt  activeRun                (Coalescing)
 ├─ ruft     UndoPrompt.open/draw     (Shared-Singleton-Modul)
 └─ imageData.frameLayers[frameIndex].layers[layerArrayIndex].positions[cellIdx]  ← Undo-Ziel

ZoomRoom  ──füttert──▶ ShakeDetector ;  meldet Shift-Run an EditorRoom
PixelRoom ──füttert──▶ ShakeDetector ;  meldet Rotation-Snapshot an EditorRoom bei commit
FrameManagementView ──meldet deleteFrame-Eintrag──▶ EditorRoom  (vor table.remove)
```

**Invarianten**
- `#entries <= 3` jederzeit.
- Jeder `content`-Eintrag referenziert einen `frameIndex`, der zum Zeitpunkt des `push` existiert; beim Undo erneut geprüft (`peekValid`).
- `prevImage`-Referenzen bleiben gültig, weil die Imagetable zur Laufzeit nur wächst (`appendTileToImagetable`), nie umnummeriert (Umnummerierung nur in `ImageStoreCodec.newSaveOperation` auf tiefen Kopien).
- Ein `deleteFrame`-Eintrag, dessen Wiedereinfügen die 12-Frame-Grenze verletzen würde, ist **nicht anwendbar** und wird von `peekValid` ausgesiebt, **bevor** ein Dialog erscheint (FR-007).
- Ein geöffneter `UndoPrompt` führt bei „(A) Ja" **immer** zu einem erfolgreichen Undo — `hasUndo()`/`peekValid` haben die Anwendbarkeit vorab garantiert.

**Einstieg & Navigation**
- `EditorRoom:undoRequest()` ist der einzige Einstieg für die erkannte Geste: `entry, reason = peekValid(imageData)`; `entry` → `UndoPrompt.open(labelFor(entry), () -> undoLast())`; kein `entry` → `showStatus(reason == "frame-limit" and "cannot undo — frame limit" or "Nothing to undo")`.
- `undoLast()` läuft nie aus `switchRoom`/`entered()` heraus. Aus `ZoomRoom`/`PixelRoom` bestätigt: `onConfirm` committet offene Zell-Edits (`commitForTerminate`-Pfad), `switchRoom(EditorRoom)` (→ `entered()` läuft vollständig, klemmt `currentFrame`), **danach** `undoLast()` (setzt `currentFrame` final auf den betroffenen Frame). Committete Edits auf denselben Zellen wie der Undo-Eintrag werden vom Restore bewusst überschrieben.
