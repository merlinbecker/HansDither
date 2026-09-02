# Feature Specification: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature Branch**: `feature/0.3-addons` (created)

**Created**: 2026-08-31

**Status**: Clarification Phase Complete — Ready for Planning

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

In the Tile View (first View showing complete image with all tiles), the user switches the active layer and the animation frame with **B + D-Pad**: hold B, then press **Up / Down** to cycle the 3 layers of the current frame (Up = forward, Down = backward, wrapping) and **Left / Right** to step through animation frames (Right = next, Left = previous; B + Right on the last frame appends a new frame). Layers are orthogonal to frames — every frame has the same fixed 3 layers. The Crank (without B) is reserved for the tile picker (see US5); B + Crank still drives the zoom chain / Frame Management View.

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

### User Story 4 - Frame Management View (Priority: P2)

A dedicated Frame Management View lets the user keep the animation controllable: reorder frames and delete frames. It is reached from the Tile View by holding B and rotating the Crank backward (counterclockwise) — this gesture is unchanged by the Fourth-Round redesign. All animation frames are shown as a list (mirroring the project-selection UI pattern). The user navigates with the D-Pad, marks a frame with A, moves the marked frame in the sequence with Left/Right, and deletes the marked frame with a **second A-press** on it (B is occupied by the hold-to-stay gesture). At least one frame always remains. Releasing B returns to the Tile View.

There is **no** Layer View — layers are a fixed structure of exactly 3 per frame (like the 12-frame cap) and need no management UI.

**Why this priority**: Reordering and deleting frames is essential for building a real animation. Without it the user cannot fix the order of drawn frames or remove mistakes. P2 because the MVP (US1–US3) is usable without it.

**Independent Test**: In Tile View with 3 frames, hold B and rotate Crank backward → Frame Management View appears listing Frame 1–3. Mark Frame 3 (A), press Left → it becomes Frame 2. Mark a frame (A), press A again → it is removed and the list shrinks to 2. Release B → back in Tile View, showing the reordered/shortened animation.

**Acceptance Scenarios**:

1. **Given** in Tile View, **When** B is held and Crank is rotated counterclockwise, **Then** the Frame Management View opens, listing every animation frame in order
2. **Given** the Frame Management View, **When** the user presses A on a frame entry, **Then** that frame is marked (visual indicator); moving the cursor with the D-Pad clears the mark
3. **Given** a frame is marked, **When** the user presses Left or Right, **Then** the marked frame moves one position earlier / later in the animation sequence (clamped at the ends), and the mark follows it
4. **Given** a frame is marked, **When** the user presses A again on that same frame, **Then** it is deleted and the list refreshes — unless only one frame remains, in which case deletion is rejected
5. **Given** the Frame Management View, **When** the user releases B, **Then** navigation returns to the Tile View with the current frame clamped into the (possibly shorter/reordered) sequence
6. **Given** frames were reordered or deleted, **When** the image is saved and reloaded, **Then** the new frame order and count persist

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
- **Deleting the Last Frame**: The Frame Management View rejects deleting a frame when only one frame remains
- **Reordering at the Ends**: Moving the first frame Left, or the last frame Right, is a no-op (clamped)

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
- **FR-015**: System MUST display the current layer index (1/2/3) and layer name in Tile View (visual indicator)
- **FR-016**: System MUST step the animation frame when **B is held and Left / Right is pressed** (Left = previous, Right = next); **B + Right on the last frame** appends a new frame as a deep copy of the current one (the only frame-creation gesture). When B is **not** held, the D-Pad moves the tile cursor and the Crank drives the tile picker — neither switches layer or frame
- **FR-017**: System MUST wrap layer cycling (after Layer 3 → Layer 1 forward; before Layer 1 → Layer 3 backward)
- **FR-017b**: Switching frames MUST preserve the active layer index (every frame has all 3 layers, so the index always exists)

**Tile Picker & Eyedropper Feedback (US5)**

- **FR-025**: Turning the Crank in Tile View **without B held** MUST open a tile-picker overlay (a filmstrip of the tiles actually referenced in the image) and set it as the active drawing tile; each ~30° of net rotation moves the selection one tile further, wrapping at the list ends. The overlay auto-hides ~1.5 s after the last rotation
- **FR-026**: The tile picker MUST iterate only tiles actually referenced by the image — scanning the **layer positions** (`frameLayers[*].layers[*].positions`, skipping `0`), not the flat composite cache and not raw imagetable slots. (The composite cache keeps only the topmost tile per cell, so a tile that lives solely on a covered layer would drop out of the list and could vanish mid-session when a higher layer covers its cell.) Index 1 (white) MUST be reachable in the picker as the "no selection" (toggle-mode) slot, consistent with the eyedropper — the picker appends it on top of the scan (so it works even when no cell references tile 1). The pause/context view (`buildPauseMenuImage`) MUST use the same underlying scan, **without** that appended slot, so its "Tiles: N" stays factual
- **FR-027**: When the eyedropper (short B-tap on a tile) fires, the Bauchbinde MUST briefly show **"Tile N picked"** (the tile's index) for ~1.5 s, then revert to the frame/layer label

**Frame Management View (US4)**

- **FR-018**: System MUST open the Frame Management View when B is held and the Crank is rotated counterclockwise in Tile View (gesture unchanged by the Fourth-Round redesign)
- **FR-019**: The Frame Management View MUST list every animation frame in order as selectable entries
- **FR-020**: The user MUST be able to mark a frame with A; a **second A-press on the marked frame** deletes it (two-step confirmation — B is occupied by the hold-to-stay gesture). Deletion MUST be rejected when only one frame remains
- **FR-021**: The user MUST be able to move the marked frame one position earlier (Left) or later (Right) in the sequence; moves are clamped at the ends; moving the D-Pad cursor clears the mark
- **FR-022**: Releasing B MUST return to the Tile View, with the current frame index clamped into the resulting (possibly shorter/reordered) sequence
- **FR-023**: There MUST be no Layer View or per-frame layer submenu — layers are a fixed structure and are not managed here
- **FR-024**: Reordered / deleted frames MUST persist through save and reload

---

### Key Entities *(include if feature involves data)*

- **Frame**: Container for a single animation frame; contains **exactly 3 Layers**; linked to animation timing (duration) and to its position in the frame sequence
- **Layer**: A drawable canvas within a frame at a fixed stacking index (1 = bottom, 3 = top). Layer 1's non-ink pixels are white (2 reachable states: ink/white). Layers 2–3 have 3 reachable states (ink/white/transparent); their default/no-tile-yet state is transparent. A layer may be empty
- **Pixel**: Individual drawing unit — ink, white, or (Layers 2–3 only) transparent
- **Tile**: A 16×16 cell of pixels referenced by index from the shared PDI imagetable. Tiles are deduplicated by a 3-state hash (ink / white / transparent) so white and transparent tiles never collide
- **FrameManagementView**: UI mode listing all frames in order; supports marking, reordering (Left/Right) and deleting (min. 1 frame)

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can shift the content of the tile under the cursor by exactly one pixel in any direction (content crossing the boundary moves into the neighbour tile) and have shifts persist through save/reload cycles
- **SC-002**: Transparent pixels can be placed on Layers 2–3, rendered visually distinct from ink and white, and persist through save/reload
- **SC-003**: User can switch the active layer with B + Up/Down and the animation frame with B + Left/Right, with the Crank (no B) reserved for the tile picker — none of the three interferes with the others
- **SC-004**: The Frame Management View is reachable with one B + Crank-backward gesture from Tile View and lets the user reorder and delete frames (min. 1)
- **SC-007**: Turning the Crank in Tile View opens a tile-picker overlay that cycles the referenced tiles with wraparound and sets the active drawing tile; the eyedropper shows a brief "Tile N picked" confirmation
- **SC-005**: All legacy images (created before this feature) load without errors, render identically, and gain two empty upper layers
- **SC-006**: Layer content, frame order and frame count persist when images are saved and reloaded; every reloaded frame exposes exactly 3 layers

---

## Assumptions

- **User Control Model**: The three views (Tile, Zoom, Pixel) already exist and have established Crank and button behaviors. Fourth Round (hardware testing) settled the Tile View bindings: **B + Up/Down** = layer, **B + Left/Right** = frame, **Crank alone** = tile picker, **B + Crank** = zoom chain / Frame Management View (unchanged), short **B-tap** = eyedropper. B + arrow is pixel-shift in Zoom View and layer/frame switch in Tile View — different views, no collision.
- **Storage Format**: The existing image storage format (PDI/JSON) can be extended to include transparency data and layer metadata without breaking existing loaders. [DEPENDENCY: Spec 009 tile cleanup must complete first; confirms JSON structure can be extended]
- **Layer Architecture**: Every frame has **exactly 3 layers, always** (fixed structure, like the 12-frame cap). Layer 1 = bottom/base, Layers 2–3 stacked above. No add/delete. An empty upper layer is simply omitted on disk and rebuilt on load.
- **Backward Compatibility (1-Layer Upgrade)**: Legacy images have a single flat layer. On load the existing content becomes Layer 1 and two empty upper layers are added, so the frame exposes 3 layers. Save then writes the v1.1 format (still 1 layer entry on disk while Layers 2–3 stay empty).
- **Frame Independence**: Layers are stored per-frame, not globally, but every frame has the same 3 stacking slots — frame switching never changes the layer count.
- **Layer Rendering Order**: Layers are composited bottom-up (Layer 1 → Layer 3), **pixel-perfectly** (Seventh Round, from a debugging session): where more than one layer contributes to a cell, `LayerModel.compositeCellTile`/`compositeToTiles` merge the actual tile images (kColorClear pixels of an upper layer let the layer(s) below show through); a cell with only one contributing layer keeps that layer's tile index unchanged (no needless new tile). Only the active layer is editable in Zoom/Pixel views; Zoom View additionally shows a purely visual "onion skin" backdrop (`LayerModel.compositeBelow`) of the layers below the active one, so the active layer's own absent/transparent pixels don't hide what's beneath while editing — this backdrop is never written back into any layer's stored data. Layer 1's white background is opaque; Layers 2–3's default (no-tile-yet) state and non-ink "off" state is transparent so lower layers show through — never white.
- **Empty Layer Handling**: Layers 2–3 may be empty. An empty layer is omitted from the saved JSON and rebuilt on load; there is no user action to delete a layer (there is nothing to delete — the slot always exists).
- **Frame Management Navigation**: One gesture (hold B + Crank backward in Tile View) opens the Frame Management View; releasing B returns to Tile View. No deeper hierarchy. (Unchanged by the Fourth-Round redesign — that only moved layer/frame *switching* off the Crank.)

---

## Architecture Governance & Technical Debt

### Architecture Impact Assessment

**Scope**: This feature affects:
- **Data Model**: 3-layer structure per frame + per-pixel transparency carried in the tile bitmap (kColorClear); no per-cell transparency array
- **Runtime Behavior**: Input multiplexing (B + Up/Down = layer, B + Left/Right = frame, Crank alone = tile picker, B + Crank = zoom chain / Frame Management View), plus a re-composite step after every layer edit
- **Interfaces**: Editor state machine, `LayerModel` helper API, new `FrameManagementView` room

**Quality Attributes Affected**:
- **Usability**: Improved precision control (US1), transparent pixels on upper layers (US2), layer cycling (US3), frame reorder/delete (US4)
- **Maintainability**: `imageData.frames` becomes a derived composite cache that must be regenerated on every layer mutation
- **Performance**: Re-tiling on every pixel shift and re-compositing on every edit must stay within one frame on the Playdate. *(Perf review, 2026-09-01: the original whole-layer re-tile was measured at ~192,000 `image:sample()` calls + 375 `image.new()` per key press — far over budget. Resolved by scoping the shift to one tile + one neighbour, ~2,500 ops per key press, done synchronously. See ADR-043.)*

**Evidence & Decisions**:
- **ADR Required**: "Layer Rendering Order & Compositing Strategy" — decision: composite all 3 layers pixel-perfectly bottom-up wherever more than one layer contributes to a cell (Seventh Round; supersedes the earlier "topmost non-empty cell wins" cell-level pick, which is still used as a cheap fallback in contexts without tile-registration access, e.g. plain cell counting); flat composite cache feeds the tilemap
- **ADR Required**: "Pixel Transparency Encoding" — decision: transparency lives per-pixel as kColorClear in the tile; 3-state tile hash; no per-cell array
- **ADR Required**: "Fixed 3-Layer Structure" — decision: layers are a fixed structure (no add/delete), like the 12-frame cap; empty upper layers omitted on disk
- **ADR Required**: "Tile View Control Redesign" (ADR-042) — decision: layer/frame switching moves to B + D-Pad; the free Crank drives a referenced-tile picker; B + Crank (zoom / Frame Management View) unchanged
- **ADR Required**: "Pixel Shift Scoped to One Tile" (ADR-043, 2026-09-01, from hardware testing) — decision: B + arrow shifts only the tile under the cursor plus its neighbour in the push direction (a 2-tile strip moved as one; the neighbour's far edge falls off, no wrap). `LayerModel.shiftTileContent` replaces the whole-layer `shiftLayerContent`. Small enough to run synchronously per key press — the deferred-materialization mechanism from this ADR's first draft is gone
- **Risk Record**: "Playdate Performance Under Pixel Shifting" — **RESOLVED** (2026-09-01): measured ~192,000 `image:sample()` calls per keypress for the whole-layer shift; scoping the shift to one tile + one neighbour (~2,500 ops) removes the problem at the source (ADR-043)

### Existing Dependencies & Compatibility

- **Spec 009 (Tile Cleanup)** — MUST complete first: Provides framework for tile recalculation and frame-to-tiles mapping, which is extended by pixel shifting in US1
- **Existing View System** — Tile View, Zoom View, Pixel View navigation exists; this feature threads the active layer through all three editing paths and adds one new Frame Management View
- **Playdate SDK** — Assumed available: Crank API, button input handling, image rendering; no new platform capabilities required

### Technical Debt & Risk Mitigation

- **Risk**: Tile recalculation on every pixel shift could cause lag on Playdate hardware
  - **Mitigation**: **Resolved (2026-09-01)** — the shift no longer touches the whole layer; it is scoped to the cursor's tile + one neighbour (~2,500 ops/key press, synchronous). ADR-043. Device-level FPS confirmation is still open (Phase 7 T053/T054)
- **Risk**: Layer metadata could break existing save/load cycle if not handled carefully
  - **Mitigation**: Version the file format; provide fallback loader for legacy images
- **Risk**: Input multiplexing (B + Up/Down = layer, B + Left/Right = frame, Crank alone = tile picker) could be confusing
  - **Mitigation**: Clear visual feedback (layer indicator, tile-picker overlay, "Tile N picked" toast); hardware testing (the Fourth-Round redesign itself came out of that testing)

---

## Status Summary

**Clarified** (seven rounds — see `## Clarifications`). Third round restructured US4 (fixed 3 layers, layer-dependent off-state, US4 = Frame Management View). Fourth round (2026-08-31, from hardware testing) redesigned the Tile View controls: layer switch → B + Up/Down, frame switch → B + Left/Right, Crank alone → tile picker, eyedropper → "Tile N picked" toast. B + Crank (zoom chain / Frame Management View) unchanged. Fifth round (2026-09-01, from hardware testing): B no longer paints in Pixel View — painting is A only (FR-007), B stays the zoom-out modifier. Sixth round (2026-09-01, from a debugging session): Layers 2–3 gained a 3-state A-press paint cycle (ink → white → transparent → ink, FR-008) and their default/absent-tile fill is transparent, not white (FR-006). Seventh round (2026-09-01, from a debugging session): wired the previously-unused pixel-perfect `compositeCellTile`/`compositeToTiles` into Tile View's actual render/load paths and added a purely-visual onion-skin backdrop (`compositeBelow`) to Zoom View, so transparent/absent pixels on Layers 2–3 genuinely show the layer(s) below instead of hiding them (Layer Rendering Order).

**Implementation status**: US1–US4 implemented and green on `feature/0.3-addons`. The Fourth-Round control redesign, the Fifth-Round Pixel View change, and the per-tile pixel-shift rework (ADR-043 — B + arrow shifts one tile + one neighbour, not the whole layer) are implemented (394 headless assertions green, buildNumber 30). Remaining: performance profiling + manual simulator/hardware integration (Phase 7 T053–T059); device-level FPS confirmation of the per-tile shift is still open.
