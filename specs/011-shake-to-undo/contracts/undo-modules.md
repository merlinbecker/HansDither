# Contract: Modul-Schnittstellen (UndoHistory / ShakeDetector / UndoPrompt)

**Feature**: `specs/011-shake-to-undo`

Interne Lua-Modul-Grenzen — dieses Projekt hat keine externen APIs. Verträge = die öffentlichen Funktionen, die die Räume aufrufen dürfen, plus das erwartete Verhalten. Jede Zeile ist ein Headless-Testfall-Kandidat (Constitution V).

---

## C-011-1 `UndoHistory`

Konstruktor-freies Tabellenmodul (wie `LayerModel`). Instanz via `UndoHistory.new()`.

| Signatur | Vorbedingung | Nachbedingung |
|---|---|---|
| `UndoHistory.new() -> hist` | — | `hist.entries == {}`, `hist.MAX == 3` |
| `hist:push(entry)` | `entry.kind` ∈ {`"content"`,`"deleteFrame"`} | `entry` ist jetzt `entries[#entries]`; wenn vorher schon 3 → alter `entries[1]` ist weg; `#entries <= 3` |
| `hist:peekValid(imageData) -> entry|nil, reason|nil` | — | liefert jüngsten **anwendbaren** Eintrag; dabei jüngere nicht-anwendbare Einträge **entfernt**; kein anwendbarer → `entry = nil`. Nicht anwendbar = `content`-Eintrag mit fehlendem `frameIndex` (**FR-006**) **oder** `deleteFrame`-Eintrag, dessen Wiedereinfügen `#imageData.frameLayers >= 12` verletzen würde (**FR-007** — die Grenze ist Teil der Gültigkeit, nicht eine nachträgliche Ablehnung). `reason` = `"frame-limit"`, wenn beim Aussieben mindestens ein `deleteFrame`-Eintrag an der 12-Grenze verworfen wurde, sonst `nil` — steuert nur den Meldungstext |
| `hist:pop()` | — | `entries[#entries]` entfernt (No-op bei leer) |
| `hist:clear()` | — | `entries == {}` |
| `hist:isEmpty() -> bool` | — | `#entries == 0` |
| `hist:coalesceTarget(kind, frameIndex, layerArrayIndex) -> entry|nil` | — | jüngster Eintrag, wenn `kind`/`frameIndex`/`layerArrayIndex` gleich **und** `entry.runOpen == true`; sonst `nil` |

**Verhaltensverträge**
- **V1 (FR-001)**: 4× `push` → `#entries == 3`, und der zuerst gepushte Eintrag ist nicht mehr enthalten.
- **V2 (FR-006)**: `push` eines `content`-Eintrags mit `frameIndex = 5`; danach `imageData.frameLayers` auf Länge 3 verkürzt; `peekValid` → dieser Eintrag wird verworfen, nächster gültiger (oder `nil`) geliefert.
- **V3 (FR-009)**: neue History → `isEmpty() == true`; nach `push` + `pop` → wieder `true`.
- **V4**: `clear()` leert auch bei 3 Einträgen vollständig.

---

## C-011-2 `UndoHistory` — Anwendungsfunktionen (in `EditorRoom`, nutzen `UndoHistory`-Einträge)

Diese leben in `EditorRoom` (brauchen `registerTile`/`recompositeCell`/`updateTilemapFrame`), sind aber gegen die Eintrags­struktur aus `data-model.md` §2 vertragsgebunden.

| Signatur | Nachbedingung |
|---|---|
| `EditorRoom:recordClear(frameIndex, layerArrayIndex, prevPositions, getPrevImage)` | ein `content`/`op="clear"`-Eintrag mit 375 Zellen wird gepusht (VOR dem Leeren aufgerufen) |
| `EditorRoom:beginShiftRun(frameIndex, layerArrayIndex)` / `:recordShiftCells(cells)` / `:endShiftRun()` | erster Aufruf pusht `content`/`op="shift"`, `runOpen=true`; `recordShiftCells` ergänzt nur **neue** `cellIdx`; `endShiftRun` setzt `runOpen=false` |
| `EditorRoom:recordRotation(frameIndex, layerArrayIndex, cellIdx, prevImage)` | pusht **einmal** je PixelRoom-Sitzung einen `content`/`op="rotate"`-Eintrag mit genau dieser Zelle |
| `EditorRoom:recordDeleteFrame(index, frameLayersEntryCopy, framesEntryCopy?)` | pusht `deleteFrame`-Eintrag (von `FrameManagementView` VOR `table.remove` aufgerufen); `framesEntryCopy` ist `nil`, wenn `imageData.frames` fehlt (defensiver Pfad) |
| `EditorRoom:undoLast() -> "applied" \| "empty"` | wendet den von `peekValid` gelieferten Eintrag an (`applyContentEntry` / `applyDeleteFrameEntry`), `pop()`, setzt `currentFrame` auf den betroffenen Frame, `updateTilemapFrame`, `needsRedraw`; `"empty"` wenn `peekValid` keinen Eintrag liefert (leerer Verlauf **oder** nur nicht-anwendbare Einträge, FR-006/007/009). Es gibt **keine** Ablehnung nach dem A-Druck — die 12-Frame-Grenze ist schon in `peekValid` ausgesiebt. Dieser Aufruf erfolgt bereits als `onConfirm` des Dialogs; `hasUndo()` hat vorher „es gibt etwas" garantiert |
| `EditorRoom:undoRequest()` | Einstieg für die erkannte Schüttel-Geste: `entry, reason = peekValid(imageData)`. `entry` vorhanden → `UndoPrompt.open(labelFor(entry), function() self:undoLast() end)` (FR-012). Kein `entry` → `showStatus(reason == "frame-limit" and "cannot undo — frame limit" or "Nothing to undo")`, **kein** Dialog (FR-007/FR-009) |
| `EditorRoom:hasUndo() -> bool` | `peekValid(imageData) ~= nil` (bestimmt, ob überhaupt ein Dialog erscheint — FR-012) |
| `EditorRoom:clearUndoHistory()` | `history:clear()` — aus `handleLoadSuccess` und beim Wechsel zu `SelectionRoom` |

**Verhaltensverträge**
- **V5 (FR-004/005, Clear)**: aktive Ebene voll bemalt → `recordClear` → `clearCurrentFrame` → `undoLast()` → `layer.positions` **element­weise identisch** zum Stand vor `clearCurrentFrame`; `undoLast` liefert `"applied"`; History danach ein Eintrag kürzer.
- **V6 (FR-005, Rotation)**: Tile mit asymmetrischem Muster; 1× `rotateGridClockwise` + Commit → `undoLast()` → betroffene Zelle zeigt wieder das Ausgangs-Tile (Pixelvergleich).
- **V7 (FR-005, Shift)**: Zelle mit Muster; B halten, 3× Right; B los; `undoLast()` → Quell- und Nachbarzelle wieder auf Ausgangsstand; **ein** Eintrag wurde erzeugt (nicht drei).
- **V8 (FR-002)**: nur `setCell`/`beginStroke` (Malen) ohne riskante Operation → `history:isEmpty()` bleibt `true`.
- **V9 (FR-005, deleteFrame)**: 3 Frames; `recordDeleteFrame(2, copy2, cache2)` → `table.remove(...,2)` → `undoLast()` → `#frameLayers == 3`, Frame an Position 2 element­weise identisch zur Kopie, `currentFrame == 2`.
- **V10 (FR-007)**: 12 Frames; `deleteFrame`-Eintrag für Index 3 als jüngster im Verlauf. `peekValid` → `nil, "frame-limit"`; `EditorRoom:undoRequest()` öffnet **keinen** Dialog, zeigt `showStatus("cannot undo — frame limit")`; der Eintrag ist verworfen; `#frameLayers == 12` unverändert.
- **V10b**: wie V10, aber darunter liegt ein gültiger `content`-Eintrag → `peekValid` liefert diesen (der `deleteFrame`-Eintrag darüber wurde ausgesiebt); `undoRequest()` öffnet den Dialog für den `content`-Eintrag.
- **V11 (FR-002, Rotation-Erfassungspunkt)**: „male 5 Pixel im PixelRoom, dann 1× rotieren, Commit" → `undoLast()` stellt den Zustand **inkl. der 5 gemalten Pixel** wieder her, nur die Rotation wird zurückgenommen (Snapshot beim ERSTEN `rotateGrid*`, nicht bei `setCurrentTile`).

---

## C-011-3 `ShakeDetector`

| Signatur | Nachbedingung |
|---|---|
| `ShakeDetector.new(opts?) -> d` | `opts` überschreibt `T`/`W`/`R` (Defaults 0.85 / 500 / 1200); interner Zustand leer |
| `d:feed(x, y, z, nowMs) -> bool` | `true` **genau dann**, wenn ein Ausschlag `x > T` und ein Ausschlag `x < -T` innerhalb `W` ms zueinander auftraten und keine Refraktärsperre aktiv ist; nach `true` gilt `R` ms Sperre |
| `d:reset()` | interner Zustand wie nach `new()` |

**Verhaltensverträge**
- **V12 (FR-010)**: Folge `x = +1.0 @ t=0`, `x = -1.0 @ t=200` → `feed` liefert beim zweiten Sample `true`.
- **V13 (FR-011, Fehlalarm)**: 300 Samples `x ∈ [-0.2, 0.2]` über 10 s → nie `true`.
- **V14 (FR-011, zu langsam)**: `x = +1.0 @ t=0`, `x = -1.0 @ t=900` (`> W`) → nie `true`.
- **V15 (einseitig)**: `x = +1.0` zehnmal hintereinander, nie negativ → nie `true`.
- **V16 (Refraktär, FR-015-nah)**: nach einem `true` bei `t=200` erzeugt ein sauberer Links-Rechts-Schwung bei `t=600` (`< 200 + R`) **kein** zweites `true`; bei `t=1500` wieder `true` möglich.

---

## C-011-4 `UndoPrompt`

Singleton-Tabellenmodul (ein Dialog global).

| Signatur | Nachbedingung |
|---|---|
| `UndoPrompt.open(label, onConfirm)` | `isOpen() == true`, `label` gespeichert; No-op wenn bereits offen (**FR-015**) |
| `UndoPrompt.isOpen() -> bool` | Status |
| `UndoPrompt.handleA()` | ruft `onConfirm()`, dann `isOpen() == false` |
| `UndoPrompt.handleB()` | `isOpen() == false`, `onConfirm` **nicht** gerufen |
| `UndoPrompt.draw()` | zeichnet die zentrierte Box nur wenn `isOpen()`; sonst No-op |
| `UndoPrompt.reset()` | `isOpen() == false` (defensiv beim Raumwechsel) |

**Verhaltensverträge**
- **V17 (FR-014)**: `open("Undo Rotation?", spy)` → `handleA()` → `spy` genau einmal gerufen, `isOpen() == false`.
- **V18 (FR-014)**: `handleB()` → `spy` nie gerufen, `isOpen() == false`.
- **V19 (FR-015)**: `open(...)` zweimal → zweiter Aufruf ändert `label`/`onConfirm` nicht.
- **V20 (FR-013, Room-Gate)**: Mit `UndoPrompt.isOpen()==true` ignorieren die Inputhandler von `EditorRoom`/`ZoomRoom`/`PixelRoom` D-Pad/Crank/A(Stroke)/B(Zoom) und leiten nur A→`handleA`, B→`handleB` — geprüft über die vorhandenen Mock-Beobachter (kein `setCell`, kein `switchRoom`, kein `shiftActiveLayer` während offen).

---

## C-011-5 Room-Integration (Verhaltensverträge, headless)

- **V21 (FR-010 Geltungsbereich)**: `EditorRoom:update()` / `ZoomRoom:update()` / `PixelRoom:update()` rufen `readAccelerometer()` und `shakeDetector:feed(...)`; `SelectionRoom`/`TitleRoom`/`FrameManagementView` tun das **nicht** (Mock-Zähler `accelReadCount` steigt nur in den drei Editier-Räumen).
- **V22 (FR-012)**: `feed` liefert `true` → `EditorRoom:undoRequest()`; bei vorhandenem `peekValid`-Eintrag wird `UndoPrompt.isOpen()` `true` mit dessen Label.
- **V23 (FR-009)**: `feed` liefert `true` **und** `peekValid` → `nil, nil` (Verlauf leer) → `UndoPrompt.isOpen()` bleibt `false`; `showStatus("Nothing to undo")` (vorhandener `statusMessage`-Mechanismus).
- **V23b (FR-007)**: `feed` liefert `true` **und** `peekValid` → `nil, "frame-limit"` → kein Dialog; `showStatus("cannot undo — frame limit")`.
- **V24 (FR-017)**: `EditorRoom:entered()` / `ZoomRoom:entered()` / `PixelRoom:entered()` rufen `startAccelerometer()` (idempotent); der Wechsel zu `SelectionRoom` ruft `stopAccelerometer()`.
- **V25 (FR-016)**: Dialog aus `ZoomRoom` bestätigt → `UndoPrompt.handleA` → `onConfirm`: `ZoomRoom` committet offene Edits (`commitForTerminate`-Pfad), dann `switchRoom(EditorRoom)`; `EditorRoom:entered()` läuft vollständig durch (liest `returnFrame`, klemmt `currentFrame`); **erst danach** ruft `onConfirm` `EditorRoom:undoLast()`, das `currentFrame` final auf den betroffenen Frame setzt. `undoLast()` wird nie aus `switchRoom`/`entered()` heraus aufgerufen. Nach dem Undo ist `currentRoom == EditorRoom`. Deckt zugleich ab: committete Zoom-Raster-Edits, die dieselben Zellen wie der Undo-Eintrag betreffen, werden vom Undo-Restore bewusst überschrieben (der Nutzer hat „rückgängig" gewählt).
