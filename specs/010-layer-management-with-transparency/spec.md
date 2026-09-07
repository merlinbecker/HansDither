# Feature Specification: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature Branch**: `feature/0.3-addons` (created)

**Created**: 2026-08-31

**Status**: Clarification Phase Complete (8 rounds) — Eighth-Round update (overlay consolidation + Frame Room) pending `/speckit-plan` + `/speckit-tasks` re-run before implementation

**Input**: User description: "Ich plane drei Erweiterungen für Hans-Dither: präzises Verschieben im Zoom View, Transparenz im Pixel View und ein Layer-Management mit Crank-Steuerung und eigenem Verwaltungs-View."

---

## Clarifications

### Session 2026-08-31 (First Round)

- Q: Delete interaction in Layer View — A-press direct delete vs. two-step confirmation? → A: Two-step confirmation (A-press selects, B-press confirms delete) for safety on destructive operations, following Playdate safety patterns
- Q: Animation Layer View interaction pattern — inline reorder vs. submenu drill-down? → A: Submenu drill-down pattern (A-press on frame opens submenu showing layers), mirrors existing SelectionRoom pattern and Hans-Dither navigation model
- Q: Layer persistence when switching frames — preserve index vs. reset vs. intelligent mapping? → A: Preserve layer index with wrapping (if Frame 2 has fewer layers than active index, wrap to Layer 1), reduces re-selection and follows animation software conventions

### Session 2026-08-31 (Second Round)

- Q: Maximum layers per frame — limit or unbounded? → A: **Fixed limit: exactly 3 layers maximum per frame**. Layer 1 (bottom/mandatory base layer) is always present. Layers 2 and 3 are optional. Old images with single layer load as Layer 1 only (backward compatible). Transparency becomes critical for proper layer compositing across all 3 layers. *(Superseded by Third Round: layers are now a fixed structure of exactly 3 — see below.)*

### Session 2026-08-31 (Third Round)

- Q: Should users be able to add or delete layers? → A: **No.** Every frame ALWAYS has exactly 3 layers — a fixed structure, like the hard cap of 12 animation frames. There is no UI (and no gesture) to add or remove a layer. An empty layer simply carries no content.
- Q: What is the non-ink ("toggle off") pixel state per layer? → A: **Layer-dependent.** Layer 1 (bottom) toggles between ink and **white** (white is Layer 1's background). Layers 2–3 toggle between ink and **transparent** (so lower layers show through). Each layer has exactly one "off" state; its colour depends on the layer. In Pixel View the A-press eraser produces that "off" state (white on Layer 1, transparent on Layers 2–3). *(Fifth Round: B no longer paints in Pixel View — the A-press eraser is the only route to the "off" state.)*
- Q: Can Layer 1 hold a transparent pixel? → A: **No.** Layer 1 is strictly two-valued (ink / white). Layers 2–3 are strictly two-valued (ink / transparent). Tile deduplication still distinguishes white vs. transparent tiles so the upper layers round-trip correctly.
- Q: What becomes of US4 (Layer & Frame Management View)? → A: **US4 is now a Frame Management View only.** The Layer View is dropped entirely (layers are fixed, nothing to manage). The new view lists all animation frames; the user can reorder frames and delete frames (minimum 1 frame remains), so the animation stays controllable.
- Q: How are empty upper layers stored? → A: A fully-empty Layer 2 or 3 is **omitted from the saved JSON**; on load every frame is reconstituted to exactly 3 layers. Single-layer artwork therefore stays as compact on disk as before.

### Session 2026-08-31 (Fourth Round — Tile View control redesign, from hardware testing)

- Q: How does the user switch the active layer? → A: **Hold B + Up / Down** (Up = layer forward, Down = layer backward, wrap 1↔3). The Crank is no longer involved in layer switching.
- Q: How does the user switch animation frames? → A: **Hold B + Left / Right** (Right = next, Left = previous). Holding B + Right on the last frame appends a new frame (a deep copy — the only frame-creation gesture). The Crank is no longer involved in frame switching.
- Q: What does the Crank do in Tile View now? → A: **Tile picker.** Turning the Crank (without B) brings up a filmstrip overlay of the tiles actually used in the image; each ~30° of net rotation moves the selection one tile further, wrapping at the end. Landing on tile 1 (white) means "no selection" (toggle mode), matching the eyedropper.
- Q: Feedback when a tile is picked with the eyedropper (short B-tap on a tile)? → A: The Bauchbinde briefly shows **"Tile N picked"** (the tile's number) for ~1.5 s, then returns to the frame/layer label.
- Note: **B + Crank forward / backward is unchanged** — it still drives the zoom chain (forward) and opens the Frame Management View (backward). B + arrow therefore means *pixel-shift* in Zoom View (FR-001) but *layer/frame switch* in Tile View — different views, no collision.

### Session 2026-09-01 (Fifth Round — Pixel View: B stops painting, from hardware testing)

- Q: Should B place a pixel in Pixel View? → A: **No.** Painting is A only. A-press toggles a pixel between ink and the active layer's non-ink state (white on Layer 1, transparent on Layers 2–3) — so an A-press on ink on an upper layer already reaches transparent. B in Pixel View is reserved solely for the zoom-out modifier (**B held + Crank backward** leaves Pixel View); a lone B-tap does nothing. This also removes the stray transparent pixel that the previous B-paint behaviour dropped into the tile whenever the user held B to zoom out. Supersedes FR-007's "B-press sets the non-ink state".

### Session 2026-09-01 (Sixth Round — Pixel View: 3-color paint cycle on upper layers, from debugging session)

- Q: On Layers 2–3, should white ever be a directly reachable, standalone paint state (not just a way-station en route to transparent)? → A: **Yes.** An A-press on Layers 2–3 now cycles a pixel through **3 states: ink → white → transparent → ink**. Layer 1 is unchanged (2-state ink/white toggle only — Layer 1 never carries transparency). This supersedes the Fifth Round's Layers 2–3 behaviour, where an A-press on ink erased straight to transparent with no reachable white state.
- Q: What should a cell on Layers 2–3 render/start as when it has no tile placed yet (i.e. is absent from the tilemap)? → A: **Transparent, not white.** White is exclusively Layer 1's default/background colour; Layers 2–3's default for "nothing painted here" is transparent. Any editing surface that materializes a blank canvas for an absent upper-layer cell (e.g. Zoom View when it has no source tile to copy) must fill it with transparent, never white.

### Session 2026-09-01 (Seventh Round — Tile/Zoom View: transparent pixels must actually show the layer(s) below, from debugging session)

- Q: The spec already said transparent pixels on Layers 2–3 let lower layers "show through" (Layer Rendering Order), but activating Layer 2 made Layer 1's content disappear instead — why? → A: **The pixel-perfect merge (`LayerModel.compositeToTiles`/`compositeCellTile`) existed but was never wired into any render path.** Every render path (Tile View's flat composite cache, the v1.1 load path, frame duplication) instead used the cheap cell-level `compositeAt`/`compositeToFlat`, which picks exactly one layer's *whole tile index* per cell — a tile with partial transparency on Layer 2 never blended with Layer 1's tile beneath it, and a fully-absent Layer-2 cell showed the tilemap's empty/white cell instead of Layer 1. Fixed by wiring `compositeCellTile`/`compositeToTiles` into `EditorRoom.recompositeCell`/`recompositeCurrentFrame`/`tickForward` and into `ImageStoreCodec.newLoadOperation`'s `validatedFrames` computation, so Tile View always shows the real pixel-merged result.
- Q: Should Zoom View's mid-level 3×3 tile display show Layer 1 through Layer 2/3's absent or transparent cells while editing? → A: **Yes, but purely as a visual backdrop, never baked into the editable/committed data.** `LayerModel.compositeBelow()` composites only the layers strictly *below* the active layer for a given cell (onion skin); `EditorRoom.buildZoomContext()` attaches this as `slot.backgroundImage` per slot, and `ZoomRoom`'s cell renderer samples it wherever the active layer's own foreground pixel is absent or `kColorClear`. `buildWorkingImage()` (the image actually handed to Pixel View / committed back via `applyTileEdits`) is untouched by this — it still only ever contains the active layer's own content, so the lower layers' pixels are never accidentally painted into the active layer's stored tile.
- Q: Does this change Pixel View's checkerboard rendering of transparency? → A: **No.** FR-011 explicitly requires checkerboard for transparent pixels in Pixel View; that remains the only view where transparency is shown as a pattern rather than as the real content beneath it.

### Session 2026-09-06 (Eighth Round — Overlay-Konsolidierung & Frame-Room, aus dem Hardware-Test)

- Q: Der Tile-Picker (FR-025) wird bildschirmmittig gezeichnet und verdeckt Bild und Cursor — wohin gehört er? → A: **In eine einzige, konsolidierte Overlay-Leiste.** Alle *passiven* Overlay-Elemente der Tile View — Frame/Ebenen-Label (FR-015), Tile-Picker-Filmstreifen (FR-025), „Tile N picked"-Toast (FR-027) und transiente Statusmeldungen — teilen sich künftig **eine** Leiste, die auf der dem Tile-Cursor **abgewandten** Bildschirmzone liegt (Cursor obere Hälfte → Leiste unten, Cursor untere Hälfte → Leiste oben), nie die Cursor-Zelle verdeckt und in der sich keine zwei Elemente gegenseitig überzeichnen. Der modale Undo-Dialog aus Spec 011 bleibt eine **eigene, darüberliegende Schicht** (er muss laut Spec 011 FR-013 voll modal bleiben) — nur seine Platzierung wird mit der Leiste koordiniert, sodass beide sich nie überlappen.
- Q: Die Frame-Verwaltung war ein modaler View, den man nur mit *gehaltenem* B betrat und durch B-Loslassen verließ — wie soll sie stattdessen funktionieren? → A: **Als eigener, dauerhafter Room.** Eintritt aus der Tile View mit **B + Kurbel rückwärts** (einmalige Geste, kein Dauerhalten mehr); Verlassen mit **B + Kurbel vorwärts** (symmetrisch). Dazwischen bleibt man im Room und agiert mit **denselben Steuerungen wie im Bild-Auswahl-Room**: D-Pad navigiert ein **Raster** aus rechteckigen Frame-Kacheln (Thumbnails wie in der Bildauswahl), A wirkt auf die fokussierte Kachel. Die fragile B-Loslassen-Erkennung (Commit c2cbb6f) entfällt damit.
- Q: Im 2D-Raster belegen alle vier D-Pad-Richtungen die Cursor-Navigation — wie sortiert man dann Frames um? → A: **A markiert, danach verschiebt das D-Pad.** A markiert den Frame unter dem Cursor (sichtbarer Rahmen). Solange markiert, verschiebt das D-Pad den markierten Frame in der Animationssequenz (Links/Rechts = ±1 Position, Hoch/Runter = ±eine Rasterzeile, an den Sequenzenden geklemmt); Rasterzelle und Markierung wandern mit. *(Löschen/A-Toggle-Teil überholt durch die Ninth Round unten — Löschen läuft jetzt über das System-Menü, A ist ein reiner Markieren/Aufheben-Umschalter.)*
- Q: Ändert sich das Anlegen neuer Frames? → A: **Nein.** „Frame anhängen" bleibt die Tile-View-Geste **B + Rechts auf dem letzten Frame** (FR-016). Der Frame-Room sortiert und löscht nur. *(Ninth Round: das Frame-Room-Menü bekommt zusätzlich „duplicate frame".)*
- Offen (an `/speckit-plan` / Spec 011): Spec 011 (`research.md` R6) nahm an, die Schüttel-/Undo-Geste sei in der Frame-Verwaltung inaktiv, *weil dort B durch die Halte-Geste belegt ist*. Mit dem persistenten Room wird B nicht mehr gehalten → diese Begründung entfällt. *(Im `/speckit-plan` aufgelöst: der Room startet das Accelerometer nicht und wertet Schütteln nicht aus — konsistent mit Spec 011 FR-010, das die Frame-Verwaltung namentlich ausschließt.)*

### Session 2026-09-06 (Ninth Round — Frame-Room-Steuerung, aus `/speckit-clarify`)

- Q: Wie soll sich die Frame-Room-Steuerung insgesamt verhalten? → A: **Wie der Bild-Auswahl-Room (`SelectionRoom`) — plus der Zusatz „Verschieben".** D-Pad navigiert das Thumbnail-Raster, **A** markiert einen Frame (sichtbarer Rahmen) bzw. hebt die Markierung wieder auf (reiner Umschalter — A löscht **nie**), **B** ist Zurück/Abbrechen, destruktive Aktionen laufen über das **System-Menü**. Der Zusatz: solange ein Frame markiert ist, verschiebt das D-Pad **diesen** Frame in der Sequenz. Der frühere „zweiter A-Druck löscht / dritter A-Druck hebt auf"-Mechanismus (Eighth Round) entfällt.
- Q: Frame löschen — welcher Frame, welche Bestätigung? → A: **System-Menüpunkt „delete frame", analog zu „delete image" im `SelectionRoom`.** Wirkt auf den **Cursor-Frame**; zeigt vorher den bekannten A/B-Bestätigungsdialog (`drawConfirmDeleteDialog`/`confirmingDelete`, A = ja / B = nein); abgelehnt (Dialog erscheint gar nicht) bei nur 1 Frame.
- Q: Welche Menüpunkte bekommt der Frame-Room? → A: **Zwei** — „delete frame" und „duplicate frame". „duplicate frame" macht eine tiefe Kopie des Cursor-Frames und fügt sie direkt dahinter ein; abgelehnt bei bereits 12 Frames (harte Obergrenze). „Frame anhängen" bleibt zusätzlich die Tile-View-Geste B + Rechts (FR-016). *(Overturns die `/speckit-plan`-Notiz „kein Room-eigenes System-Menü".)*
- Q: Frame-Room verlassen (B + Kurbel vorwärts) — Schutz gegen den Kurbel-Nachlauf der Eintrittsgeste (B + Kurbel rückwärts)? → A: **Die Verlassen-Geste ist erst scharf, nachdem B seit dem Betreten mindestens einmal losgelassen wurde** (`bReleasedSinceEnter`). Der Nachlauf nach dem Eintritt wird ignoriert. *(Präzisiert FR-022 — war bisher nur im Plan, R12.)*

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Precise Pixel-by-Pixel Shifting in Zoom View (Priority: P1)

When working on detailed graphics in the Zoom View (second View showing tiles), a user needs to nudge the content of a single tile by one pixel at a time. The user holds B and uses arrow keys (Up/Down/Left/Right) to shift the content of **the tile under the cursor** by exactly one pixel while B remains held. Only that one tile and its immediate neighbour in the push direction change — not the whole screen. The one-pixel strip that crosses the tile boundary moves into that neighbour and stays there (the neighbour's own content shifts along too and its far edge falls off); repeated presses walk the content across, tile by tile. The vacated edge of the source tile is filled with the layer's non-ink state.

**Why this priority**: This is a core editing capability that directly improves precision and user control over artwork. Many pixel art workflows depend on exact positioning, making this a MVP feature for an advanced editor.

**Independent Test**: Zoom into a tile with drawn content, hold B and press Right once; verify the tile's content shifts right one pixel, the pixel that crossed the boundary is now at the left edge of the right neighbour, and no other tile changed. Repeat for other directions. Reload image to confirm the shift persists.

**Acceptance Scenarios**:

1. **Given** the cursor on a tile with drawn content in Zoom View, **When** B is held and an arrow is pressed once, **Then** that tile's content shifts one pixel in that direction and its neighbour in that direction shifts along as one 2-tile strip (the neighbour's far edge falls off; no third tile is touched)
2. **Given** B is being held and Right has been pressed, **When** Left is pressed while B remains held, **Then** the same tile's content shifts left one pixel (independent of previous direction)
3. **Given** content shifted by B + arrow key, **When** the frame is saved and reloaded, **Then** the shifted position persists exactly as shown
4. **Given** shifted content in one frame, **When** switching to another frame, **Then** only the current frame's tile has shifted; other frames are unaffected
5. **Given** the cursor on a tile at the edge of the 25×15 tile grid, **When** B + the arrow toward that edge is pressed, **Then** only that tile changes and the strip that crosses the boundary is discarded (no wrap)

---

### User Story 2 - Transparency Support in Pixel View (Priority: P1)

In the Pixel View (third View showing individual 16×16 pixels), the user can now place transparent pixels in addition to opaque drawing. Painting is **A only**. On **Layer 1** (the base layer, which never carries transparency) A-press toggles a pixel between ink and white — 2 states, as before. On **Layers 2–3** an A-press instead steps a pixel through a **3-state cycle: ink → white → transparent → ink**; white is a distinct, directly reachable paint state on upper layers, not merely a pass-through to transparent. A blank/unpainted pixel on Layers 2–3 starts in the transparent state (the layer's default "not contributed" state — the same state used, e.g., for a tile position not yet present in the tilemap on an upper layer, as opposed to Layer 1's default white). Transparent pixels are stored and persist through save/reload cycles, enabling creation of sprites with actual alpha channel support. B does not paint here (Fifth Round); B held + Crank backward is the zoom-out gesture. *(Sixth Round, from hardware testing — supersedes "Fifth Round"'s 2-state ink/transparent-only toggle on Layers 2–3.)*

**Why this priority**: Transparency is essential for modern pixel art workflows and enables far more sophisticated visual effects. This is a core feature requested by the user for real graphics flexibility.

**Independent Test**: On Layer 2 in Pixel View, place an opaque pixel with A, press A again on that pixel to make it white, press A a third time to make it transparent, press A a fourth time to make it opaque again (closing the cycle), save image, reload, verify the transparent pixel appears as transparent (distinct visual state from opaque or white).

**Acceptance Scenarios**:

1. **Given** cursor in Pixel View on Layer 2/3 over an ink pixel, **When** A is pressed, **Then** the pixel becomes white
2. **Given** a white pixel on Layer 2/3, **When** A is pressed at the same position, **Then** the pixel becomes transparent (the layer's default non-contributing state)
3. **Given** a transparent pixel already placed on Layer 2/3, **When** A is pressed at the same position, **Then** the transparent pixel is replaced with an opaque (ink) pixel, closing the 3-state cycle
4. **Given** cursor in Pixel View on Layer 1 over an ink pixel, **When** A is pressed, **Then** the pixel becomes white (2-state toggle only; Layer 1 never holds transparency)
5. **Given** a transparent pixel in the current frame, **When** frame is saved and image is reloaded, **Then** transparent pixel retains its transparency state
6. **Given** transparent pixels in Frame 1, **When** switching to Frame 2, **Then** Frame 2's pixels are independent (may be empty or contain different transparent/opaque state)
7. **Given** no prior transparency support, **When** old images are loaded, **Then** all pixels are treated as opaque (backward compatibility)
8. **Given** a cell on Layer 2/3 that has no tile in the tilemap yet, **When** it is displayed or edited (e.g. via Zoom View), **Then** it renders/starts as fully transparent, never as white (white is exclusively Layer 1's default)

---

### User Story 3 - Layer & Frame Switching with B + D-Pad (Priority: P1)

In the Tile View (first View showing complete image with all tiles), the user switches the active layer and the animation frame with **B + D-Pad**: hold B, then press **Up / Down** to cycle the 3 layers of the current frame (Up = forward, Down = backward, wrapping) and **Left / Right** to step through animation frames (Right = next, Left = previous; B + Right on the last frame appends a new frame). Layers are orthogonal to frames — every frame has the same fixed 3 layers. The Crank (without B) is reserved for the tile picker (see US5); B + Crank still drives the zoom chain (forward) and enters the Frame Management Room (backward — see US4, revised Eighth Round).

**Why this priority**: Layers are fundamental to digital art creation. Combined with animation frames, this enables the user to create complex layered animations. This is explicitly requested and part of the core feature set.

**Independent Test**: Load an image, hold B and press Up, verify the layer indicator cycles Layer 1 → 2 → 3 → 1; hold B and press Right, verify the frame indicator advances. Every frame has the same fixed set of 3 layers.

**Acceptance Scenarios**:

1. **Given** an image in Tile View, **When** holding B and pressing Up, **Then** the active layer cycles forward Layer 1 → Layer 2 → Layer 3 → Layer 1
2. **Given** holding B, **When** pressing Left or Right, **Then** the animation frame steps to the previous / next frame (B + Right on the last frame appends a new frame — a deep copy)
3. **Given** the user is on Layer 2 of Frame 1, **When** switching to another frame, **Then** the active layer stays Layer 2 (index preserved; every frame has all 3 layers so no wrap is needed)
4. **Given** holding B and pressing Down, **When** layers cycle backward, **Then** the active layer decrements Layer 2 → Layer 1 → Layer 3 (wrapping)
5. **Given** B is **not** held, **When** the D-Pad is pressed, **Then** the tile cursor moves (unchanged); **When** the Crank is turned, **Then** the tile picker opens (US5) — neither switches layer or frame
6. **Given** the eyedropper picked a tile with a short B-tap, **When** it fires, **Then** the Bauchbinde briefly shows "Tile N picked"

---

### User Story 4 - Frame Management Room (Priority: P2)

A dedicated **Frame Management Room** lets the user keep the animation controllable: reorder, delete and duplicate frames, at their own pace. It is **entered** from the Tile View with **B + Crank backward** (a discrete gesture) and **left** with **B + Crank forward** — a persistent room, not a hold-to-stay modal; the user stays in it until they deliberately leave. Inside, every animation frame is shown as a **rectangular thumbnail in a grid**, and the controls mirror the project-selection room: the **D-Pad** moves the grid cursor, **A** marks the focused frame (visible border) or unmarks it (a plain toggle — A never deletes), **B** is back/cancel, and the destructive actions live on the **system menu**. The *addition* is moving: while a frame is marked, the D-Pad moves *that frame* within the animation sequence (Left/Right by one position, Up/Down by one grid row, clamped at the sequence ends) and the cell + mark follow it. **Deleting** a frame is the system-menu item **"delete frame"** — analogous to the project-selection room's "delete image": it acts on the frame under the cursor and shows an A/B confirmation dialog first; it is rejected when only one frame remains. A second system-menu item, **"duplicate frame"**, deep-copies the frame under the cursor and inserts it directly after (rejected at the 12-frame cap). At least one frame always remains.

There is **no** Layer View — layers are a fixed structure of exactly 3 per frame (like the 12-frame cap) and need no management UI.

**Why this priority**: Reordering and deleting frames is essential for building a real animation. Without it the user cannot fix the order of drawn frames or remove mistakes. P2 because the MVP (US1–US3) is usable without it.

**Independent Test**: In Tile View with 3 frames, hold B and rotate the Crank backward → the Frame Management Room opens showing Frame 1–3 as thumbnails in a grid and stays open after B and the Crank are released. Mark Frame 3 (A), press Left → it becomes Frame 2 and the mark follows; press A → the mark clears. Put the cursor on a frame, open the system menu → "delete frame" → confirm with A → the grid shrinks to 2. Release B, then hold B and rotate the Crank forward → back in Tile View, showing the reordered/shortened animation.

**Acceptance Scenarios**:

1. **Given** in Tile View, **When** B is held and the Crank is rotated backward, **Then** the Frame Management Room opens, showing every animation frame as a rectangular thumbnail in a grid, and it stays open after B and the Crank are released
2. **Given** the Frame Management Room, **When** the user presses A on a frame, **Then** that frame is marked (visible border); pressing A again unmarks it (A never deletes)
3. **Given** a frame is marked, **When** the user presses a D-Pad direction, **Then** the marked frame moves within the animation sequence — Left/Right by one position, Up/Down by one grid row (performed as that many sequential adjacent moves) — clamped at the sequence ends, and the grid cell + mark follow it
4. **Given** the cursor is on a frame, **When** the user selects "delete frame" from the system menu and confirms with A, **Then** that frame is removed and the grid refreshes — unless only one frame remains, in which case "delete frame" is rejected and no dialog appears
5. **Given** the cursor is on a frame and the image has fewer than 12 frames, **When** the user selects "duplicate frame" from the system menu, **Then** a deep copy of that frame is inserted directly after it
6. **Given** the user just entered the room and is still holding B, **When** the crank runs forward from the entry motion, **Then** nothing happens; the exit takes effect only after B has been released at least once
7. **Given** the user is in the Frame Management Room and B has been released at least once, **When** B is held and the Crank is rotated forward, **Then** navigation returns to the Tile View with the current frame clamped into the (possibly shorter/reordered) sequence
8. **Given** frames were reordered, deleted or duplicated, **When** the image is saved and reloaded, **Then** the new frame order and count persist

---

### Edge Cases

- **Pixel Shift at the tile-grid edge**: When the source tile is at the edge of the 25×15 tile grid and the shift points off that edge, there is no neighbour to receive the crossing strip — only the source tile changes and the strip is discarded. (Revised 2026-09-01, from hardware testing — the earlier whole-layer shift wrapped around; per-tile shift does not. See ADR-043.)
- **Transparency & Tile Generation**: Transparent tiles are treated as distinct from opaque and white tiles in tile deduplication. Two tiles with the same ink pattern but one white background and one transparent background are stored separately (3-state tile hash)
- **Layer 1 Transparency**: Layer 1 (bottom) has no transparent state — its non-ink pixels are white, and A-press is a 2-state ink/white toggle. Layers 2–3 have 3 reachable paint states (ink, white, transparent) via an A-press 3-state cycle; their default/absent-tile state is transparent (never white)
- **Pixel View B-press**: B does not paint in Pixel View (Fifth Round). A lone B-tap is inert; B is only the zoom-out modifier (B held + Crank backward). All 3 states on Layers 2–3 (ink/white/transparent) and both states on Layer 1 (ink/white) are reachable purely through the A-press cycle (Sixth Round)
- **Frame Switching & Active Layer**: Switching frames (B + Left/Right) preserves the active layer index. Because every frame has all 3 layers, the index always exists — no wrap is required (a defensive clamp to Layer 1 remains for corrupt data)
- **Empty Layers**: Layers 2 and 3 may be entirely empty. An empty layer carries no content and is omitted from the saved file; it is reconstituted on load so every frame always exposes exactly 3 layers in the editor
- **Fixed Layer Count**: Every frame has exactly 3 layers, always. There is no gesture or UI to add or remove a layer (Clarifications, Third Round)
- **B + D-Pad vs. cursor / stroke**: While B is held the D-Pad switches layer/frame and does **not** move the tile cursor; a short B-tap with no D-Pad or Crank in between is still the eyedropper. If B is pressed *after* a direction key is already held, the cursor freezes rather than fighting the navigation
- **Tile Picker with one tile**: If the image references only tile 1, the picker still opens but every step resolves to "no selection"; nothing crashes
- **Tile Picker & session tiles**: The picker lists tiles referenced across all frames' **layer positions** (not `imagetable:getLength()`, and not the flat composite cache) — orphaned session tiles (appended by edits, pruned only on save) are skipped, while a tile that only exists on a covered layer stays selectable
- **Deleting the Last Frame**: The Frame Management Room's "delete frame" menu item is rejected — and its confirmation dialog is not shown — when only one frame remains
- **Delete confirm dialog is modal** *(2026-09-06; Ninth Round)*: while the "delete frame" A/B dialog is open, only A (confirm) and B (cancel) act; D-Pad, the system menu and every other input are inert — mirrors the project-selection room's `confirmingDelete`
- **Duplicate at the frame cap** *(2026-09-06; Ninth Round)*: "duplicate frame" is rejected when the image already has 12 frames
- **Frame Room exit vs. entry residual** *(2026-09-06; Ninth Round)*: "B + Crank forward" leaves the room only after B has been released at least once since entering; the crank follow-through from the "B + Crank backward" entry gesture is ignored
- **Reordering at the Ends**: Moving the first frame earlier (Left / Up), or the last frame later (Right / Down), is a no-op (clamped). Reordering acts on the 1-D animation sequence even though frames are laid out in a 2-D grid, so Left/Right can carry a frame across a grid row boundary, and an Up/Down move is `numColumns` sequential adjacent steps *(2026-09-06)*
- **Overlay bar vs. cursor at mid-screen** *(2026-09-06)*: when the tile cursor sits on the horizontal centre line, the consolidated overlay bar (FR-028) defaults to the bottom edge
- **Frame Room gesture vs. zoom chain** *(2026-09-06)*: from the Tile View, B + Crank *forward* still starts the zoom chain and B + Crank *backward* enters the Frame Management Room; the *forward* direction means "leave" only once the user is already inside the Frame Management Room — different rooms, no collision
- **Picker overlay while the frame/layer label is showing** *(2026-09-06)*: both live in the same consolidated bar (FR-028); the picker filmstrip shares that region with the label rather than covering screen-centre, and neither overdraws the other

---

## Requirements *(mandatory)*

### Functional Requirements

**Pixel Shifting (US1)**

- **FR-001**: System MUST allow user to hold B and press direction keys (Up/Down/Left/Right) in Zoom View to shift the content of **the tile under the cursor** by exactly one pixel per key press (revised 2026-09-01, from hardware testing — was "all content in the active frame"; see ADR-043)
- **FR-002**: System MUST recalculate the tile references of the affected cells after each pixel shift — the source tile and (unless the source tile is at the tile-grid edge) its neighbour in the push direction. Both move as one 2-tile strip: the neighbour's own content shifts along and its far edge is discarded; the source tile's vacated edge is filled with the layer's non-ink state (white on Layer 1, transparent on Layers 2–3). No other cell is touched.
- **FR-003**: System MUST persist pixel shifts when image is saved and reloaded
- **FR-004**: System MUST apply shifts only to the active frame; other frames remain unaffected
- **FR-005**: System MUST handle shifts at the tile-grid edge gracefully: when the source tile has no neighbour in the push direction, only the source tile changes and the strip that crosses the boundary is discarded (no wrap; revised 2026-09-01 — was wrap-around; see ADR-043)

**Transparency Support (US2)**

- **FR-006**: System MUST support a per-pixel non-ink default state whose colour depends on the layer: **white** on Layer 1 (bottom), **transparent** on Layers 2–3. This is also the fill state for any Layers 2–3 cell that has no tile placed in the tilemap yet (never white)
- **FR-007**: System MUST NOT paint in Pixel View on a B-press (Fifth Round, from hardware testing — supersedes the earlier "B sets the non-ink state"). A lone B-tap is inert; B in Pixel View is reserved solely for the zoom-out modifier (B held + Crank backward). Painting is A only
- **FR-008**: System MUST let A-press cycle a pixel's paint state, layer-dependent: on **Layer 1**, a 2-state toggle ink ↔ white (eraser behaviour, as in Spec 008); on **Layers 2–3**, a 3-state cycle **ink → white → transparent → ink** (Sixth Round — white is a directly reachable, standalone paint state on upper layers, not merely a way-station to transparent)
- **FR-009**: System MUST persist transparent pixels through save/reload — a transparent tile round-trips distinctly from a white tile
- **FR-010**: System MUST treat legacy images without transparency as fully opaque black/white (backward compatibility)
- **FR-011**: Transparent pixels in Pixel View MUST render visually distinct from ink and from white (e.g. checkerboard pattern)

**Layer & Frame Switching with B + D-Pad (US3)**

- **FR-012**: Every frame MUST have **exactly 3 layers, always** — a fixed structure (Layer 1 = bottom/base, Layers 2–3 stacked above). Legacy 1-layer images gain two empty upper layers on load
- **FR-012b**: There MUST be no gesture or UI to add or delete a layer; the layer count is not user-modifiable
- **FR-012c**: An entirely empty Layer 2 or 3 MUST be omitted from the saved file and reconstituted on load (every frame exposes 3 layers in the editor)
- **FR-013**: System MUST cycle the active layer forward when **B is held and Up is pressed** in Tile View
- **FR-014**: System MUST cycle the active layer backward when **B is held and Down is pressed**
- **FR-015**: System MUST display the current layer index (1/2/3) and layer name in Tile View (visual indicator), rendered **within the consolidated overlay bar** (FR-028) *(revised 2026-09-06, from hardware testing)*
- **FR-016**: System MUST step the animation frame when **B is held and Left / Right is pressed** (Left = previous, Right = next); **B + Right on the last frame** appends a new frame as a deep copy of the current one (the only frame-creation gesture). When B is **not** held, the D-Pad moves the tile cursor and the Crank drives the tile picker — neither switches layer or frame
- **FR-017**: System MUST wrap layer cycling (after Layer 3 → Layer 1 forward; before Layer 1 → Layer 3 backward)
- **FR-017b**: Switching frames MUST preserve the active layer index (every frame has all 3 layers, so the index always exists)

**Tile Picker & Eyedropper Feedback (US5)**

- **FR-025**: Turning the Crank in Tile View **without B held** MUST open a tile-picker overlay (a filmstrip of the tiles actually referenced in the image) and set it as the active drawing tile; each ~30° of net rotation moves the selection one tile further, wrapping at the list ends. The overlay auto-hides ~1.5 s after the last rotation. The filmstrip MUST be drawn **inside the consolidated overlay bar** (FR-028), anchored to the edge opposite the tile cursor — never screen-centred over the artwork *(revised 2026-09-06, from hardware testing)*
- **FR-026**: The tile picker MUST iterate only tiles actually referenced by the image — scanning the **layer positions** (`frameLayers[*].layers[*].positions`, skipping `0`), not the flat composite cache and not raw imagetable slots. (The composite cache keeps only the topmost tile per cell, so a tile that lives solely on a covered layer would drop out of the list and could vanish mid-session when a higher layer covers its cell.) Index 1 (white) MUST be reachable in the picker as the "no selection" (toggle-mode) slot, consistent with the eyedropper — the picker appends it on top of the scan (so it works even when no cell references tile 1). The pause/context view (`buildPauseMenuImage`) MUST use the same underlying scan, **without** that appended slot, so its "Tiles: N" stays factual
- **FR-027**: When the eyedropper (short B-tap on a tile) fires, the **consolidated overlay bar** (FR-028) MUST briefly show **"Tile N picked"** (the tile's index) for ~1.5 s, then revert to the frame/layer label *(revised 2026-09-06 — "Bauchbinde" → consolidated overlay bar)*

**Frame Management Room (US4)** *(revised 2026-09-06, from hardware testing — was "Frame Management View"; the hold-B modal becomes a persistent room)*

- **FR-018**: System MUST enter the **Frame Management Room** when B is held and the Crank is rotated backward in the Tile View. This is a **discrete gesture**: the room persists after B and the Crank are released (no hold-to-stay) *(revised 2026-09-06)*
- **FR-019**: The Frame Management Room MUST show every animation frame as a **rectangular thumbnail laid out in a grid**, and its controls MUST mirror the project-selection room's — the D-Pad moves the grid cursor, A marks/unmarks the focused frame, B is back/cancel, and destructive actions are on the system menu (FR-020) *(revised 2026-09-06; Ninth Round — controls aligned to `SelectionRoom`)*
- **FR-020**: A MUST be a plain mark/unmark toggle on the focused frame (visible border) and MUST NOT delete. Frame **deletion** MUST be a **system-menu action** ("delete frame"), analogous to the project-selection room's "delete image": it acts on the frame under the cursor and MUST show an A/B confirmation dialog (reusing the `SelectionRoom` confirm pattern) before removing it. It MUST be rejected — with no dialog shown — when only one frame remains. A second system-menu item, **"duplicate frame"**, MUST deep-copy the frame under the cursor and insert it directly after; it MUST be rejected at the 12-frame cap *(revised 2026-09-06; Ninth Round — was "second A-press deletes")*
- **FR-021**: While a frame is marked, the D-Pad MUST move **that frame** within the animation sequence — Left/Right by one position, Up/Down by one grid row (= `numColumns` positions, performed as that many sequential adjacent moves so the frame-reindex stays a series of adjacent swaps) — clamped at the sequence ends, with the grid cell and the mark following it. Moving the marked frame MUST NOT clear the mark; only a second A-press does (FR-020) *(revised 2026-09-06; Ninth Round)*
- **FR-022**: The user MUST leave the Frame Management Room with **B + Crank forward**, evaluated **only after B has been released at least once since the room was entered** (so the backward entry gesture's crank follow-through cannot bounce the user straight back out), returning to the Tile View with the current frame index clamped into the (possibly shorter/reordered) sequence *(revised 2026-09-06; Ninth Round — added the release-once arming clause)*
- **FR-023**: There MUST be no Layer View or per-frame layer submenu — layers are a fixed structure and are not managed here
- **FR-024**: Reordered / deleted / duplicated frames MUST persist through save and reload

**Consolidated Tile View Overlay (cross-cutting US3 + US5) — new 2026-09-06, from hardware testing**

- **FR-028**: The Tile View's *passive* overlay elements — the frame/layer label (FR-015), the tile-picker filmstrip (FR-025), the "Tile N picked" toast (FR-027) and transient status messages — MUST share **one** consolidated overlay bar. The bar MUST sit in the screen zone **opposite the tile cursor** (cursor in the top half → bar along the bottom edge; cursor in the bottom half → bar along the top edge), MUST NOT cover the cursor's own tile, and MUST NOT let two of its elements overdraw each other. The modal undo dialog (Spec 011) stays a **separate layer above** the bar — it must remain fully modal per Spec 011 FR-013 — with its placement coordinated so the two never overlap

---

### Key Entities *(include if feature involves data)*

- **Frame**: Container for a single animation frame; contains **exactly 3 Layers**; linked to animation timing (duration) and to its position in the frame sequence
- **Layer**: A drawable canvas within a frame at a fixed stacking index (1 = bottom, 3 = top). Layer 1's non-ink pixels are white (2 reachable states: ink/white). Layers 2–3 have 3 reachable states (ink/white/transparent); their default/no-tile-yet state is transparent. A layer may be empty
- **Pixel**: Individual drawing unit — ink, white, or (Layers 2–3 only) transparent
- **Tile**: A 16×16 cell of pixels referenced by index from the shared PDI imagetable. Tiles are deduplicated by a 3-state hash (ink / white / transparent) so white and transparent tiles never collide
- **Frame Management Room**: A persistent room — entered with B + Crank backward, left with B + Crank forward (armed after one B-release) — showing all frames as a grid of rectangular thumbnails. Controls mirror the project-selection room: D-Pad navigates, A marks/unmarks (toggle, never deletes), B is back/cancel. The *addition* is moving: D-Pad while a frame is marked reorders it in the sequence. Frame **deletion** ("delete frame", with an A/B confirm) and **duplication** ("duplicate frame") are system-menu actions, mirroring the project-selection room's menu. Min. 1 frame, max 12 *(revised 2026-09-06; Ninth Round — controls aligned to `SelectionRoom`, delete moved to the system menu)*
- **Consolidated overlay bar**: A single screen-edge region in the Tile View carrying the passive overlay elements (frame/layer label, tile-picker filmstrip, "Tile N picked" toast, status messages), anchored to the edge opposite the tile cursor so it never covers the cursor *(new 2026-09-06)*

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can shift the content of the tile under the cursor by exactly one pixel in any direction (content crossing the boundary moves into the neighbour tile) and have shifts persist through save/reload cycles
- **SC-002**: Transparent pixels can be placed on Layers 2–3, rendered visually distinct from ink and white, and persist through save/reload
- **SC-003**: User can switch the active layer with B + Up/Down and the animation frame with B + Left/Right, with the Crank (no B) reserved for the tile picker — none of the three interferes with the others
- **SC-004**: The Frame Management Room is entered with one B + Crank-backward gesture from the Tile View, **persists** until the user leaves it with B + Crank forward (armed after one B-release), and lets the user — with controls that mirror the project-selection room — reorder (D-Pad on a marked frame) and, via its system menu, delete (with an A/B confirm) or duplicate frames, shown as a grid of thumbnails; min. 1 frame, max 12 *(revised 2026-09-06; Ninth Round)*
- **SC-007**: Turning the Crank in Tile View opens a tile-picker overlay **within the consolidated overlay bar, never covering the tile under the cursor**, that cycles the referenced tiles with wraparound and sets the active drawing tile; the eyedropper shows a brief "Tile N picked" confirmation in the same bar *(revised 2026-09-06)*
- **SC-005**: All legacy images (created before this feature) load without errors, render identically, and gain two empty upper layers
- **SC-006**: Layer content, frame order and frame count persist when images are saved and reloaded; every reloaded frame exposes exactly 3 layers
- **SC-008**: In the Tile View, for every cursor position, no passive overlay element (frame/layer label, tile picker, "Tile N picked" toast, status message) covers the tile under the cursor, and no two of them overdraw each other *(new 2026-09-06)*

---

## Assumptions

- **User Control Model**: The three views (Tile, Zoom, Pixel) already exist and have established Crank and button behaviors. Fourth Round (hardware testing) settled the Tile View bindings: **B + Up/Down** = layer, **B + Left/Right** = frame, **Crank alone** = tile picker, **B + Crank forward** = zoom chain, **B + Crank backward** = enter Frame Management Room (Eighth Round: now a *persistent* room — see the *Frame Management Navigation* assumption below), short **B-tap** = eyedropper. B + arrow is pixel-shift in Zoom View and layer/frame switch in Tile View — different views, no collision.
- **Storage Format**: The existing image storage format (PDI/JSON) can be extended to include transparency data and layer metadata without breaking existing loaders. [DEPENDENCY: Spec 009 tile cleanup must complete first; confirms JSON structure can be extended]
- **Layer Architecture**: Every frame has **exactly 3 layers, always** (fixed structure, like the 12-frame cap). Layer 1 = bottom/base, Layers 2–3 stacked above. No add/delete. An empty upper layer is simply omitted on disk and rebuilt on load.
- **Backward Compatibility (1-Layer Upgrade)**: Legacy images have a single flat layer. On load the existing content becomes Layer 1 and two empty upper layers are added, so the frame exposes 3 layers. Save then writes the v1.1 format (still 1 layer entry on disk while Layers 2–3 stay empty).
- **Frame Independence**: Layers are stored per-frame, not globally, but every frame has the same 3 stacking slots — frame switching never changes the layer count.
- **Layer Rendering Order**: Layers are composited bottom-up (Layer 1 → Layer 3), **pixel-perfectly** (Seventh Round, from a debugging session): where more than one layer contributes to a cell, `LayerModel.compositeCellTile`/`compositeToTiles` merge the actual tile images (kColorClear pixels of an upper layer let the layer(s) below show through); a cell with only one contributing layer keeps that layer's tile index unchanged (no needless new tile). Only the active layer is editable in Zoom/Pixel views; Zoom View additionally shows a purely visual "onion skin" backdrop (`LayerModel.compositeBelow`) of the layers below the active one, so the active layer's own absent/transparent pixels don't hide what's beneath while editing — this backdrop is never written back into any layer's stored data. Layer 1's white background is opaque; Layers 2–3's default (no-tile-yet) state and non-ink "off" state is transparent so lower layers show through — never white.
- **Empty Layer Handling**: Layers 2–3 may be empty. An empty layer is omitted from the saved JSON and rebuilt on load; there is no user action to delete a layer (there is nothing to delete — the slot always exists).
- **Frame Management Navigation** *(revised 2026-09-06, from hardware testing)*: The Frame Management **Room** is entered with **B + Crank backward** and left with **B + Crank forward** — a persistent room, not a hold-to-stay modal. From the Tile View, B + Crank forward still starts the zoom chain (the room is only ever *entered* backward); B + Crank forward means "leave" only once the user is inside the room. Inside, controls mirror the project-selection room: D-Pad navigates the thumbnail grid, A marks/acts; B is not consumed except as the modifier for the B + Crank-forward exit.
- **Consolidated overlay** *(2026-09-06)*: the Tile View's passive chrome (frame/layer label, tile-picker filmstrip, "Tile N picked" toast, status messages) shares one bar anchored opposite the tile cursor. The Spec 011 modal undo dialog stays a separate, higher layer (it must stay fully modal per Spec 011 FR-013); only its placement is coordinated with the bar so they never overlap.
- **Add-frame unchanged** *(2026-09-06)*: appending a frame stays the Tile View gesture **B + Right on the last frame** (FR-016). The Frame Management Room only reorders and deletes.
- **Spec 011 interaction dependency** *(2026-09-06)*: Spec 011 records the "delete frame" undo entry inside the frame-deletion path; promoting the view to a room must keep that path intact. Spec 011's `research.md` R6 assumed the shake/undo gesture is inactive here *because B is held* — with the persistent room B is no longer held, so that assumption is flagged for re-evaluation in `/speckit-plan`.

---

## Architecture Governance & Technical Debt

### Architecture Impact Assessment

**Scope**: This feature affects:
- **Data Model**: 3-layer structure per frame + per-pixel transparency carried in the tile bitmap (kColorClear); no per-cell transparency array
- **Runtime Behavior**: Input multiplexing (B + Up/Down = layer, B + Left/Right = frame, Crank alone = tile picker, B + Crank backward = enter Frame Management Room, B + Crank forward = zoom chain / leave Frame Management Room), plus a re-composite step after every layer edit. *(2026-09-06)* Frame Management becomes a full room in the `switchRoom` rotation with an `entered()`/`exit` lifecycle (was a hold-B modal view); the Tile View's overlay drawing gains a single-region, cursor-aware layout pass.
- **Interfaces**: Editor state machine, `LayerModel` helper API, `FrameManagementView` — *(2026-09-06)* promoted from a hold-B list modal to a persistent grid room; Tile View overlay drawing consolidated into one bar

**Quality Attributes Affected**:
- **Usability**: Improved precision control (US1), transparent pixels on upper layers (US2), layer cycling (US3), frame reorder/delete (US4). *(2026-09-06)* Overlay chrome no longer covers the artwork under the cursor (FR-028 / SC-008); frame reordering happens in a calm persistent room instead of under a held button
- **Maintainability**: `imageData.frames` becomes a derived composite cache that must be regenerated on every layer mutation
- **Performance**: Re-tiling on every pixel shift and re-compositing on every edit must stay within one frame on the Playdate. *(Perf review, 2026-09-01: the original whole-layer re-tile was measured at ~192,000 `image:sample()` calls + 375 `image.new()` per key press — far over budget. Resolved by scoping the shift to one tile + one neighbour, ~2,500 ops per key press, done synchronously. See ADR-043.)*

**Evidence & Decisions**:
- **ADR Required**: "Layer Rendering Order & Compositing Strategy" — decision: composite all 3 layers pixel-perfectly bottom-up wherever more than one layer contributes to a cell (Seventh Round; supersedes the earlier "topmost non-empty cell wins" cell-level pick, which is still used as a cheap fallback in contexts without tile-registration access, e.g. plain cell counting); flat composite cache feeds the tilemap
- **ADR Required**: "Pixel Transparency Encoding" — decision: transparency lives per-pixel as kColorClear in the tile; 3-state tile hash; no per-cell array
- **ADR Required**: "Fixed 3-Layer Structure" — decision: layers are a fixed structure (no add/delete), like the 12-frame cap; empty upper layers omitted on disk
- **ADR Required**: "Tile View Control Redesign" (ADR-042) — decision: layer/frame switching moves to B + D-Pad; the free Crank drives a referenced-tile picker; B + Crank (zoom / Frame Management View) unchanged
- **ADR Required**: "Pixel Shift Scoped to One Tile" (ADR-043, 2026-09-01, from hardware testing) — decision: B + arrow shifts only the tile under the cursor plus its neighbour in the push direction (a 2-tile strip moved as one; the neighbour's far edge falls off, no wrap). `LayerModel.shiftTileContent` replaces the whole-layer `shiftLayerContent`. Small enough to run synchronously per key press — the deferred-materialization mechanism from this ADR's first draft is gone
- **Risk Record**: "Playdate Performance Under Pixel Shifting" — **RESOLVED** (2026-09-01): measured ~192,000 `image:sample()` calls per keypress for the whole-layer shift; scoping the shift to one tile + one neighbour (~2,500 ops) removes the problem at the source (ADR-043)
- **ADR Required** *(2026-09-06)*: "Frame Management as a Persistent Room" — decision: replace the B-hold modal view with a room entered/left by B + Crank backward / forward; removes the fragile B-release timing (commit c2cbb6f); frames shown as a thumbnail grid mirroring the project-selection room
- **ADR Required** *(2026-09-06)*: "Consolidated Tile View Overlay Bar" — decision: one cursor-opposite screen-edge region for all passive chrome (frame/layer label, tile picker, "Tile N picked" toast, status); the tile picker is no longer screen-centred; the Spec 011 modal undo dialog stays a separate layer with coordinated placement
- **Risk Record** *(2026-09-06)*: "Spec 011 shake-gesture rationale expires" — Spec 011 `research.md` R6 disabled the shake/undo gesture in this view *because B was held*. The persistent room frees B → the rationale no longer holds. **Open** — owner: next planning pass; follow-up: decide in `/speckit-plan` whether the shake/undo gesture is active in the Frame Management Room; re-evaluation trigger: implementing the room lifecycle change

### Existing Dependencies & Compatibility

- **Spec 009 (Tile Cleanup)** — MUST complete first: Provides framework for tile recalculation and frame-to-tiles mapping, which is extended by pixel shifting in US1
- **Existing View System** — Tile View, Zoom View, Pixel View navigation exists; this feature threads the active layer through all three editing paths and adds one new Frame Management Room
- **Playdate SDK** — Assumed available: Crank API, button input handling, image rendering; no new platform capabilities required. *(2026-09-06)* The Frame Management Room's thumbnail grid reuses the same SDK grid/list primitive already driving the project-selection room and the Pixel View
- **Spec 011 (Shake-to-Undo)** *(2026-09-06)* — interaction dependency: the "delete frame" undo entry is recorded inside `FrameManagementView.deleteMarked()`; promoting the view to a persistent room must keep that recording path intact. Spec 011 also assumed B is occupied by the hold gesture here (`research.md` R6) — see the Risk Record above

### Technical Debt & Risk Mitigation

- **Risk**: Tile recalculation on every pixel shift could cause lag on Playdate hardware
  - **Mitigation**: **Resolved (2026-09-01)** — the shift no longer touches the whole layer; it is scoped to the cursor's tile + one neighbour (~2,500 ops/key press, synchronous). ADR-043. Device-level FPS confirmation is still open (Phase 7 T053/T054)
- **Risk**: Layer metadata could break existing save/load cycle if not handled carefully
  - **Mitigation**: Version the file format; provide fallback loader for legacy images
- **Risk**: Input multiplexing (B + Up/Down = layer, B + Left/Right = frame, Crank alone = tile picker) could be confusing
  - **Mitigation**: Clear visual feedback (layer indicator, tile-picker overlay, "Tile N picked" toast); hardware testing (the Fourth-Round redesign itself came out of that testing)
- **Risk** *(2026-09-06)*: The consolidated overlay bar must dodge the cursor *and* stay non-overlapping with up to four elements — a mis-layout could hide content or collide
  - **Mitigation**: Single layout pass with a defined anchor rule (cursor-opposite edge, bottom on tie); SC-008 as the acceptance gate; the Spec 011 modal dialog kept on a separate coordinated layer
- **Risk** *(2026-09-06)*: Promoting `FrameManagementView` to a persistent room changes its lifecycle; the delete-undo recording path (Spec 011) and the frame-index clamp on return must survive the rewrite
  - **Mitigation**: Keep `deleteMarked()`'s undo-record call; re-run the Spec 011 headless section covering `deleteFrame` undo; explicit `entered()`/exit clamp tests

### Eighth-Round Update (2026-09-06) — Overlay Consolidation & Frame Room

**Trigger**: hardware testing of the shipped Spec 010 / Spec 011 build. Two defects: the tile-picker overlay drew screen-centred over the artwork and the cursor; the Frame Management View's hold-B modality was awkward for real reordering work.

**Change stays on** `feature/0.3-addons` (no new branch — no `before_specify` hook is configured).

**Architecture governance (iSAQB preset) — applicability for this round:**

- **Affected**: runtime behaviour (Frame Management joins the `switchRoom` rotation; Tile View overlay layout pass), building blocks (`FrameManagementView` lifecycle; consolidated overlay unit), interfaces (room `entered()`/exit; overlay draw entry point), quality attributes (usability, robustness of the room transition).
- **Not affected**: data model (frame order / count persist exactly as today via v1.1 — no format change), context boundary (no new external interface), deployment (no build/packaging change), persistence.
- **Security-relevant architecture**: **N/A (confirmed)** — local UI/room restructuring only; no network, no secrets, no persistence change, no new attack surface. Re-evaluation trigger: if overlay/room state is ever persisted or configured externally.
- **ADRs needed**: two (see *Evidence & Decisions*) — "Frame Management as a Persistent Room", "Consolidated Tile View Overlay Bar". Plus one architecture-risk record ("Spec 011 shake-gesture rationale expires").

**Audit Evidence Applicability (Eighth Round)** — the actual arc42 edits are made in `/speckit-plan` (project memory rule "arc42 während Planung"); each checkpoint carries a status line here:

| Checkpoint | Status | Evidenz / Begründung / Follow-up |
|---|---|---|
| arc42 Kap. 2 — Randbedingungen | **N/A** | Keine neue Plattformfähigkeit/Eingabeprimitive; die Gesten nutzen den bereits belegten „B + Kurbel"-Kanal. Re-Eval-Trigger: falls die Room-Navigation eine neue Eingabeprimitive braucht |
| arc42 Kap. 3 — Kontextabgrenzung | **N/A** | Keine neue externe Schnittstelle. Trigger: — |
| arc42 Kap. 4 — Lösungsstrategie | **Done (2026-09-06, T081)** | `arc42/04-loesungsstrategie.md` → Abschnitt „Spec 010 — 8./9. Runde: Frame-Room & Overlay-Konsolidierung" (2 Leitentscheidungen) |
| arc42 Kap. 5 — Bausteinsicht | **Done (2026-09-06, T082)** | `arc42/05-bausteinsicht.md` → FrameManagementView-Zeile (Room-Lifecycle + `gridview` + `thumbCache`), Bauchbinde-Zeile (`draw`/vAnchor), EditorRoom-Zeile (`overlayAnchor`, eine Overlay-Leiste) |
| arc42 Kap. 6 — Laufzeitsicht | **Done (2026-09-06, T083)** | `arc42/06-laufzeitsicht.md` §6.17 (Frame-Room betreten/umsortieren/löschen/duplizieren/verlassen) + §6.18 (konsolidierte Overlay-Leiste). Der ältere Spec-010-Rückstand (T052) ist über §6.3/§6.14/§6.15 + §6.17/§6.18 abgedeckt (siehe Kap. 11 T-08) |
| arc42 Kap. 7 — Verteilungssicht | **Done (N/A dokumentiert, T084)** | `arc42/07-verteilungssicht.md` → „Spec 010 8./9. Runde — keine Änderung an dieser Sicht" |
| arc42 Kap. 8 — Querschnittliche Konzepte | **Done (2026-09-06, T085)** | `arc42/08-querschnittliche-konzepte.md` → „Konsolidierte Tile-View-Overlay-Leiste" + „Symmetrische B+Kurbel-Room-Gesten mit Arming" |
| arc42 Kap. 9 — Architekturentscheidungen (+ `arc42/adr/`) | **Done (2026-09-06, T086/T087)** | §9.36 AD-048 + `arc42/adr/ADR-048-Frame-Verwaltung-persistenter-Room.md`; §9.37 AD-049 + `arc42/adr/ADR-049-Konsolidierte-Overlay-Leiste.md`. (`ADR-047` war bereits von Spec 011 belegt) |
| arc42 Kap. 10 — Qualitätsanforderungen | **Done (2026-09-06, T088)** | `arc42/10-qualitaetsanforderungen.md` → QS-24 (Overlay/SC-008), QS-25 (Thumbnail-Perf), QS-26 (deterministischer Room-Exit) |
| arc42 Kap. 11 — Risiken & technische Schulden | **Done (2026-09-06, T089)** | `arc42/11-risiken-und-technische-schulden.md` §11.8 → R-32 (Crank-Rückstau/Arming), R-33 (Thumbnail-Kosten), R-34 (Overlay-Layout), T-08 (Kap.-6-Rückstand aufgelöst) |
| Secure-Architecture-Preset (iSAQB) | **N/A (bestätigt, T095)** | Rein lokale UI-/Room-Umstrukturierung: kein Netzwerk, keine Secrets, keine Persistenzänderung (Frame-Reihenfolge/-Anzahl über v1.1 unverändert), keine neue Angriffsfläche. Re-Eval-Trigger: falls Overlay-/Room-Zustand je persistiert oder extern konfiguriert wird |
| Architektur-Review (Modulschnitt, keine zyklischen Importe, eine Crank-API) | **Done (2026-09-06, T089/T090)** | Notiz in `plan.md` → „Architektur-Review (T089 …)": `FrameManagementView` ohne `import "EditorRoom"`; `getCrankTicks(4)` einzige Crank-API im Room; `Bauchbinde:drawBottom` signaturgleich; `gridview` = SDK. Keine Contract-Verletzung |
| Constitution V — Gate 1 (`lua tests/headless_tests.lua`) | **Done (2026-09-06, T091)** | „ALLE TESTS BESTANDEN", 577 OK-Assertions; neue Sektionen: Overlay-Anker/SC-008, FrameManagementView (Toggle/Raster-Nav/Hoch-Runter-Dekomposition/Menü-Löschen mit Bestätigung/Duplizieren/12er-Grenze/armierter Exit), `remapFrames({inserted})`; V9/V23b/F4/V21 auf das neue Modell umgestellt |
| Constitution V — Gate 2 (`buildNumber` +1, `pdc`) | **Done (2026-09-06, T092)** | `Source/pdxinfo` `buildNumber` 37 → 38 (Phase 8) → 39 (Phase 9, Overlay) → 40 (Phase 10, Frame-Room); `pdc Source "Hans Dither.pdx"` je Phase exit 0. Phase 11 (arc42) ohne Code-Änderung → kein weiterer Bump |
| Manuelle Simulator-/Hardware-Integration | **Open** | Owner: Merlin (T093/T094). Simulator: quickstart Szenario 4 (neu) + 8. Gerät: `thumbCache`-Aufbauzeit für 12 Frames < 1 Frame (R-33); kein Fehl-Exit durch Kurbel-Nachlauf der Eintrittsgeste (R-32); Overlay verdeckt Cursor-Zelle in keiner Position (SC-008 visuell). Endwerte in ADR-048/ADR-049. Plus die weiterhin offenen Spec-010-Phase-7-Punkte (T053, T055–T059). Trigger: jetzt (Implementierung fertig) |
| `docs/architecture/` Evidenzpfad | **Done (Konvention)** | Erfüllt über `arc42/` gemäß Constitution III — wie in den früheren Runden dokumentiert |

**Ninth-Round refinement (2026-09-06, from `/speckit-clarify`)** — control clarifications on top of the Eighth Round; no new architecture surface:

- The `/speckit-plan` decision "the Frame Room registers **no** system menu items" (R12 / draft ADR-048) is **overturned**: the room registers **"delete frame"** and **"duplicate frame"** on `playdate.getSystemMenu()`, exactly as `SelectionRoom` registers "new / copy / delete image". Delete **reuses** the `SelectionRoom` confirm-dialog pattern (`confirmingDelete` / `drawConfirmDeleteDialog`, A = yes / B = no) — reuse of a proven pattern, Constitution IV. **ADR-048 must be written with the menu + confirm-dialog design**, not the menu-less one.
- The `movedSinceMark` state bit from the plan is **removed** — A is a plain mark/unmark toggle, so there is no "moved vs. not moved" branch. Net: less state (Constitution IV).
- `FR-022`'s arming clause (`bReleasedSinceEnter`) and `FR-021`'s "`numColumns` sequential adjacent moves" — both previously only in the plan (R12) — are now **in the spec**, so spec and plan agree.
- Duplicate-frame path: deep-copy the cursor frame (`LayerModel.cloneFrameLayers` + a flat-composite copy) and insert it at `cursor + 1` in both `imageData.frameLayers` and `imageData.frames`; rejected at `#frameLayers >= 12`. Like reorder and delete, it MUST notify Spec 011's undo history of the index shift (`EditorRoom:onFramesReindexed` → `undoHistory:remapFrames`) — today that helper handles `{ swapped }` and `{ removed }`; an insertion case is needed. **The exact `remapFrames` payload for an insertion is a `/speckit-plan` item** (it is the mirror of the `removed` shift the `deleteFrame` undo already performs).

---

## Status Summary

**Clarified** (nine rounds — see `## Clarifications`). Third round restructured US4 (fixed 3 layers, layer-dependent off-state, US4 = Frame Management View). Fourth round (2026-08-31, from hardware testing) redesigned the Tile View controls: layer switch → B + Up/Down, frame switch → B + Left/Right, Crank alone → tile picker, eyedropper → "Tile N picked" toast. B + Crank (zoom chain / Frame Management View) unchanged. Fifth round (2026-09-01, from hardware testing): B no longer paints in Pixel View — painting is A only (FR-007), B stays the zoom-out modifier. Sixth round (2026-09-01, from a debugging session): Layers 2–3 gained a 3-state A-press paint cycle (ink → white → transparent → ink, FR-008) and their default/absent-tile fill is transparent, not white (FR-006). Seventh round (2026-09-01, from a debugging session): wired the previously-unused pixel-perfect `compositeCellTile`/`compositeToTiles` into Tile View's actual render/load paths and added a purely-visual onion-skin backdrop (`compositeBelow`) to Zoom View, so transparent/absent pixels on Layers 2–3 genuinely show the layer(s) below instead of hiding them (Layer Rendering Order). **Eighth round (2026-09-06, from hardware testing)**: the tile-picker overlay drew screen-centred over the artwork, and the Frame Management View's hold-B modality was awkward for real reordering. This round consolidates all *passive* Tile View overlay chrome into one cursor-opposite bar (new **FR-028**; FR-015/025/027 revised; new **SC-008**) and turns the Frame Management View into a **persistent room** entered/left with B + Crank backward / forward, showing frames as a rectangular thumbnail grid with D-Pad reordering (US4 rewritten → "Frame Management Room"; FR-018–FR-022 revised; SC-004/SC-007 revised). **Ninth round (2026-09-06, from `/speckit-clarify`)**: aligned the Frame Management Room's controls to the project-selection room (`SelectionRoom`) — D-Pad navigates, A is a plain mark/unmark toggle, B is back/cancel; frame **deletion** moved off the "second A-press" onto a system-menu item ("delete frame" with an A/B confirm dialog), and a "duplicate frame" menu item added; the "B + Crank forward" exit is armed only after one B-release; `numColumns`-step Up/Down reorder spelled out as sequential adjacent moves (FR-020/021/022 revised, SC-004 revised, US4 acceptance scenarios rewritten). The `/speckit-plan` "no room-local system menu" decision is overturned.

**Implementation status**: US1–US3 implemented and green on `feature/0.3-addons` (394 headless assertions, buildNumber 30). **US4's prior implementation (list view, hold-B modal) is superseded by the Eighth-Round design and must be re-implemented as the Frame Management Room + consolidated overlay bar.** The Eighth-Round update needs `/speckit-plan` + `/speckit-tasks` re-run (including the arc42 Kap. 4/5/6/8/9/10/11 edits, two new ADRs, and the still-outstanding Spec-010 Kap. 6/7 runtime-view backfill). Also still open from earlier: performance profiling + manual simulator/hardware integration (Phase 7 T053–T059); device-level FPS confirmation of the per-tile shift.
