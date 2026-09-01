# Research: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature**: `specs/010-layer-management-with-transparency/`

**Date**: 2026-08-31

**Status**: Complete — All NEEDS CLARIFICATION items from plan.md resolved via research

---

## R1: Image Storage Format Extension (Spec 009 Compatibility)

**Question**: How should layer metadata and pixel transparency be stored while maintaining Spec 009 tile deduplication?

**Research Summary**:

Spec 009 established a hybrid storage model:
- **PDI file**: Deduplicated tile sheet (imagetable, one PDI per image)
- **JSON file**: Frame-to-tile position mapping + metadata

Current JSON schema (Spec 009):
```json
{
  "version": "1.0",
  "frames": [
    {
      "frameIndex": 0,
      "positions": [1, 1, 2, 2, ...],  // 375 tile indices (25×15 grid)
      "duration": 100
    }
  ]
}
```

**Decision**: Extend JSON to include layer structure while keeping PDI unchanged.

**New JSON Schema**:
```json
{
  "version": "1.1",
  "frames": [
    {
      "frameIndex": 0,
      "duration": 100,
      "layers": [
        {
          "layerIndex": 0,
          "name": "Background",
          "positions": [1, 1, 2, 2, ...],  // 375 tile indices
          "transparency": [0, 0, 1, 0, ...]  // 375 bytes: 0=opaque, 1=transparent, 2=empty
        },
        {
          "layerIndex": 1,
          "name": "Character",
          "positions": [0, 0, 0, 9, ...],
          "transparency": [2, 2, 2, 0, ...]
        }
      ]
    }
  ]
}
```

**Rationale**:
- Backward compatible: old images load with all pixels treated as opaque (transparency = 0)
- Per-layer positions allow independent tile management per layer
- Transparency array is compact (1 byte per pixel position)
- Tile deduplication still applies per-layer (Spec 009 `ImageStoreCodec.pruneUnusedTiles()` called per layer)
- No changes to PDI format required (layers are logical containers, not physical separation)

**Alternatives Rejected**:
- **Multiple PDI files per image**: Bloats storage for multi-layer frames; complicated file management
- **Embed in PDI metadata**: Playdate PDI format is immutable; custom extensions would break SDK compatibility

**Evidence**: Playdate SDK `playdate.json` module supports arbitrary nested structures; no custom parser needed.

---

## R2: Pixel Transparency State Representation (revised — per-pixel, in the tile)

**Question**: How is a transparent pixel encoded and rendered?

**Research Summary**:

The early draft stored a per-cell `transparency` array (0/1/2) alongside `positions`. User clarification: transparency is **per pixel** and is only ever set in the Pixel View. A per-cell array cannot express "pixel (6,5) transparent, (5,5) ink in the same 16×16 cell", and `spec.md` also requires that two tiles with the same ink pattern but different transparency deduplicate separately — which only works if transparency is part of the tile.

**Decision**: Transparency lives **per pixel, directly in the 16×16 tile bitmap**, as `gfx.kColorClear`.
- A tile pixel is one of: black (ink), white, transparent (kColorClear).
- `ImageStoreCodec.hashTile` and `imagesVisiblyEqual` compare **3 classes** (black / white / clear), so a white-background tile and a transparent-background tile with the same ink never collide.
- There is **no** per-cell `transparency` array in the JSON. A layer is just `{layerIndex, name, positions[375], visible}`.
- Per-layer non-ink state: Layer 1's non-ink pixels are **white**; Layers 2–3's non-ink pixels are **transparent**. The Pixel/Zoom/Tile edit paths take a per-layer "off state" and, on the upper layers, a whole white tile collapses to "absent" (position 0).

**Pixel View Rendering**:
- Ink: black fill (existing)
- Transparent: checkerboard pattern (FR-011)
- White: white cell (existing)

**Pixel View Input (Fifth Round, 2026-09-01 — from hardware testing)**: painting is **A only**. The earlier design gave B its own paint action ("B sets the layer's non-ink state"); on device this was unwanted (users paint with A) and, worse, the B-held zoom-out gesture dropped a stray non-ink pixel into the tile on every use. B in Pixel View is now inert as a paint key — it only serves the zoom-out modifier (B held + Crank backward, Contract PR-01). Nothing became unreachable: the A toggle already covers `ink ↔ non-ink` per layer, so an A-press on ink on an upper layer erases straight to transparent. `beginStroke()` lost its `button` parameter and the `strokeButton` state; `BButtonDown/Up` are explicit no-ops. Supersedes FR-007's B-paint clause.

**Backward compatibility**: legacy tiles are only black/white, so the 3-class hash and comparison behave exactly as the old 2-class versions did — legacy images are unaffected.

**Alternatives Rejected**:
- *Per-cell 0/1/2 transparency array*: cannot represent mixed-transparency cells; contradicts the "different transparency → different tile" dedup rule.

**Evidence**: Playdate 1-bit images natively carry a transparency mask (`kColorClear`); the existing sheet-compose / slice pipeline already uses `kColorClear` backgrounds, so it preserves transparent pixels without change.

---

## R3: Layer Rendering Order and Active Layer

**Question**: When multiple layers are present, which layer(s) should be rendered in Tile View? Should only the active layer be editable?

**Research Summary**:

Current architecture (single implicit layer per frame):
- Tile View shows complete rendered frame (all tiles stacked)
- Zoom View shows tile-sized chunk of current frame with detailed view
- Pixel View shows 16×16 pixel detail edit area

With layers, two approaches possible:

**Option A: Composite All Layers (Layer Stack)**
- Tile View renders all layers stacked (Layer 1 bottom, Layer N top)
- User sees full composition while editing any layer
- Zoom/Pixel View only edits active layer
- Pro: WYSIWYG (what-you-see-is-what-you-get)
- Con: Performance cost; per-frame tile recalculation affects all layers

**Option B: Single Active Layer (Current Behavior)**
- Tile View renders only the active layer
- User sees only current layer content
- Pro: Simpler state management, faster rendering
- Con: User can't see layer interaction/composition until export

**Decision**: **Option A (Composite All Layers)** — implemented as a flat composite cache.

**Rationale**:
- Matches user expectations from traditional layer-based editors
- Spec requirement (US3) emphasizes seeing all layers in Tile View
- Cheap: the composite is one flat 375-entry array per frame, rendered by the existing tilemap

**Implementation** (as built):
- `imageData.frameLayers[f]` (exactly 3 layers) is the source of truth; `imageData.frames[f]` is a derived flat array where, per cell, the topmost layer with a non-empty tile wins (`LayerModel.compositeToFlat`), else Layer 1's white tile.
- The composite cache is regenerated after every layer mutation (draw, shift, clear, frame add/switch).
- Only the active layer is edited (Zoom/Pixel edits and the Tile-View toggle all route through `writeActiveLayerPosition`).
- Per-pixel transparency lives in the tile bitmap itself (kColorClear), so where an upper layer's tile has clear pixels the lower layers already show through when that tile is drawn.
- **Layer-dependent non-ink colour**: on Layer 1 the "off" tile is the white base tile (index 1); on Layers 2–3 it is "absent" (index 0 → nothing drawn → transparent). `writeActiveLayerPosition` maps a white write to "absent" on the upper layers.

**Evidence**: the existing tilemap render path already draws a flat 375-entry array; no new compositing engine needed.

---

## R4: Layer Persistence Across Frame Switches

**Question**: When user switches frames, which layer should be active? Index-based or content-based?

**Research Summary**:

Scenario: Frame 1 has 3 layers, Frame 2 has 2 layers. User is on Frame 1, Layer 2. Switches to Frame 2.

**Option A: Reset to Layer 1**
- Simple state logic
- Pro: No confusion about non-existent layers
- Con: Repetitive; user must re-select layer on every frame switch

**Option B: Preserve Index with Wrap-Around**
- Active layer index preserved if it exists in new frame
- If index >= frame layer count, wrap to Layer 1
- Pro: Reduces re-selection work; consistent with animation software (Aseprite)
- Con: Risk of working on "wrong" layer if layer counts differ significantly

**Option C: Preserve by Name/ID**
- If layer with same name exists in new frame, activate it
- Pro: Sophisticated; assumes consistent layer naming
- Con: Requires layer IDs; complicates state management

**Decision**: **Option B (Preserve Index)** — trivially, since Third Round fixed every frame at exactly 3 layers.

**Rationale**:
- Every frame has all 3 layers, so a preserved index (1..3) always exists — no wrap is ever needed in practice.
- A defensive `clampActive` to Layer 1 stays in the code for corrupt/legacy data only.
- Minimizes user re-selection work (edit Layer 2 across multiple frames).

**Evidence**: Existing Hans-Dither frame cycling uses index preservation; extending to the fixed 3 layers is natural.

---

## R5: Frame Management View Navigation (revised Third Round)

**Question**: How is the Frame Management View reached and navigated? (There is no Layer View any more — layers are fixed.)

**Research Summary**:

Existing list-navigation pattern (SelectionRoom): D-Pad moves the cursor, A confirms, B cancels/back.

**Design Decision**: One flat view, one entry gesture.

```
Tile View  --(hold B + Crank counterclockwise)-->  Frame Management View
Frame Management View  --(release B)-->  Tile View
```

**In the Frame Management View**:
- D-Pad Up/Down = move the list cursor between frame entries (clears any mark)
- A = mark the frame under the cursor
- A again on the marked frame = delete it (two-step confirmation) — rejected if only one frame remains
- Left / Right (with a frame marked) = move the marked frame one slot earlier / later (clamped at the ends); the mark follows
- release B = return to Tile View; `currentFrame` is clamped into the new sequence

**Rationale**:
- One gesture in (hold B + Crank back), one gesture out (release B) — no hierarchy, so FR-024 ("prevent navigation loops") is satisfied trivially.
- **Delete is confirmed with a second A, not B**: the user is *holding* B the whole time (that hold is what keeps them in the view), so B cannot also mean "delete". Two A-presses is the Session-1 two-step safety pattern with A in place of B.
- B + Crank-backward in Tile View was a no-op (`zoomTickAccu <= -ZOOM_TICK_THRESHOLD` — "outermost zoom, backward is a no-op"), so the entry gesture is free and does not touch the Contract CR-01 zoom chain.
- Reuses the SelectionRoom list-navigation feel.

**Evidence**: Existing EditorRoom `handleCrank` already reserves the B + backward-crank slot as an explicit no-op; SelectionRoom provides the list-UI precedent.

---

## R6: Tile Recalculation After Pixel Shifts

**Question**: When user shifts content pixel-by-pixel (US1), how should tiles be recalculated to maintain visual integrity?

**Research Summary**:

Current tile system (Spec 009):
- ImageStore stores content as 16×16 tile indices
- Each position in frame references a tile from the tile sheet (imagetable)
- Tiles are deduplicated via hash (same 16×16 pixel content = same tile index)

Pixel shifting requirement: User holds B + arrow to shift all frame content 1 pixel in any direction.

**Challenge**: Shifting by 1 pixel moves content within and across tile boundaries. Example:
- Pixel at tile position (1,0) shifts up → wraps into tile above (0,15)
- Pixel at tile position (0,0) shifts up → wraps to opposite edge or out-of-bounds

**Decision**: Implement via intermediate pixel buffer → tile recalculation

**Algorithm**:
1. Extract all pixels from current frame (iterate all layer positions, fetch tile content)
2. Shift entire pixel buffer by 1 pixel in requested direction (use wraparound or clamp)
3. Re-tile the shifted buffer via Spec 009 `ImageStoreCodec.pruneUnusedTiles()` per layer
4. Update frame positions with new tile indices

**Rationale**:
- Decouples shift logic from tile boundary issues
- Reuses existing Spec 009 tile pruning logic (proven, tested)
- Performance acceptable: 400×240 image = 240×240 pixel buffer (typical artist resolution), single shift per frame = ~57KB memory overhead
- Matches user mental model: "shift content" not "remap tile indices"

**Alternatives Rejected**:
- **Direct tile index remapping**: Error-prone at boundaries; tile index logic becomes fragile
- **Per-tile shifting**: Doesn't handle within-tile shifts (need 16 shift operations per tile)

**Evidence**: Spec 009 already provides robust tile recalculation via ImageStoreCodec; reuse proven code.

**Perf-Nachtrag (Review nach Hardware-Test, 2026-09-01, ADR-043)**: der oben
beschriebene Algorithmus wurde als EINE Funktion gebaut
(`LayerModel.shiftLayerContent`) und lief bei jedem einzelnen Tastendruck.
Eine Standalone-Messung (375-Tile-Ebene, ein 1px-Schritt) ergab **~192.000
`image:sample()`-Aufrufe + 375 `image.new()`** — auf dem Playdate (168 MHz,
Lua-Interpreter) geschaetzt mehrere hundert ms je Tastendruck, spuerbar
ruckelig beim Halten der Pfeiltaste (genau das im Risk Record vorhergesehene
Risiko, `spec.md` Architecture Governance). Behoben durch **Aufschieben der
Materialisierung**: `shiftLayerContent` wurde in drei Bausteine zerlegt
(`decodeLayerGrid` / `materializeShiftedGrid` / `imageFromGrid`);
`EditorRoom.shiftActiveLayer` dekodiert die Ebene nur EINMAL pro
Verschiebe-Sitzung und akkumuliert weitere Tastendruecke als reinen
Wrap-Versatz (O(1)) — materialisiert wird erst in `flushLayerShift()`, am
Ende der Geste (B-Release, Rauszoomen, Malen, Pause, Terminate). Die
Zoom-View-Live-Vorschau bleibt bei jedem Tastendruck aktuell (synthetisiert
9 Tiles direkt aus dem gepufferten Raster statt aus real gebauten Tiles).
Offset-Algebra beweist Aequivalenz: N sequentielle 1px-Verschiebungen ==
eine Verschiebung um den akkumulierten Versatz (Modulo-Arithmetik ist
additiv). Details, Alternativen und Flush-Aufrufstellen: [ADR-043](adr/ADR-043-Aufgeschobene-Pixel-Verschiebung.md).

---

## R7: Backward Compatibility (Old Images Without Layers)

**Question**: How should existing images (from Spec 009, created before layer support) load correctly?

**Research Summary**:

Current JSON (Spec 009) has no `layers` array:
```json
{
  "version": "1.0",
  "frames": [{"frameIndex": 0, "positions": [...], "duration": 100}]
}
```

New JSON (this feature) includes `layers` array.

**Decision**: Automatic upgrade on load, detected by **structure** not by the version field.

**Algorithm** (as built):
1. On load, look at `frames[1]`. If it has a `.layers` table → v1.1 (nested). Otherwise → v1.0 (flat 375-entry array per frame).
2. v1.0: each flat frame becomes `{duration, layers=[{layerIndex:0, name:"Layer 1", positions:<copied>, visible:true}]}`.
3. **Every frame is then padded to exactly 3 layers** (Layers 2–3 = empty: all positions 0). No `transparency` array anywhere.
4. Next save writes v1.1; empty Layers 2–3 are simply omitted (still 1 layer entry on disk for legacy art).

**Rationale**:
- Structure-based detection is robust against a missing / wrong `version` field (FR-010).
- Old tiles are black/white only, so the 3-class tile hash behaves identically — legacy images render unchanged.
- Padding to 3 on load means the editor never has to special-case "this frame only has 1 layer".

**Evidence**: `playdate.json` parses both shapes; the codec already round-trips the flat form in the Spec 009 tests.

---

## R8: Test Strategy for Layer & Transparency Features

**Question**: What test scenarios are required to verify layer and transparency features work end-to-end?

**Research Summary**:

Constitution V (Testpflicht) requires:
1. Headless tests: `lua tests/headless_tests.lua` MUST pass
2. Build gate: `buildNumber` increment + `pdc Source "Hans Dither.pdx"` MUST succeed

For this feature, focus on pure Lua logic (no simulator/device interaction):

**Headless coverage (as built / to build)** in `tests/headless_tests.lua`:

- **US1 Shift**: `LayerModel.shiftLayerContent` moves a known pixel by 1 in each direction; wrap from the right edge; `EditorRoom:shiftActiveLayer` leaves the base layer and other frames untouched; ZoomRoom B+arrow dispatches. **Perf-Nachtrag (ADR-043)**: `shiftActiveLayer` defers materialization (positions unchanged before `flushLayerShift()`); N buffered steps + one flush reach the same pixel as N immediate `LayerModel.shiftLayerContent` calls (offset algebra); a paint mid-session (`applyTileEdits`) flushes first so it lands on top of the shift, not the other way round; `BButtonUp`, `commitAndReturnToEditor`, `commitForTerminate`, and zooming into Pixel View each flush an open session — including terminate *without* a prior B-release (no data loss on Home-button-mid-gesture).

- **US2 Transparency**: PixelRoom paints with **A only** (Fifth Round) — an A-press on ink erases to the layer's off-state (white on Layer 1, kColorClear on Layers 2–3); a lone B-tap is inert (no stray pixel on zoom-out); B held + Crank backward still zooms out; 3-class `hashTile` separates white-bg and transparent-bg tiles; `setCurrentTile` reads the three classes back.
- **US3 Layer/Frame Switching (Fourth Round)**: B + Up/Down cycles the 3 layers with wrap; B + Left/Right steps frames (B + Right at the last frame appends a deep copy); the Crank with no B switches nothing; the active layer index is preserved across frame switches; a B-release that followed a B + D-Pad nav does **not** also fire the eyedropper (`bNavConsumed`).
- **US3 fixed-3**: `LayerModel` always yields exactly 3 layers; load pads to 3; save omits empty Layers 2–3; a v1.0 flat image loads as 3 layers.
- **US5 Tile Picker (Fourth Round)**: Crank without B steps the active tile through the *referenced* indices — scanned from the layer positions (`frameLayers[*].layers[*].positions`), so a tile on a covered layer is still reachable — at ~30°/tile with wraparound; overlay auto-hides ~1.5 s after the last turn; the eyedropper toast shows "Tile N picked".
- **Editing model**: an edit on Layer 2 does not touch Layer 1; the A-press eraser on an upper layer returns the cell to "absent" (0), not opaque white; round-trips through save/reload.
- **US4 Frame Management**: reorder moves a frame one slot (clamped at ends); delete removes it (rejected at 1 frame); `currentFrame` clamps on return; reorder/delete persist through save/reload.

**Rationale**: headless tests catch SDK-API misuse and state-management bugs before the simulator; pixel-through-PDI round-trips (`image:draw` is a no-op in the mock) are verified manually in the simulator instead.

---

## R9: Layer Count — Fixed Structure of Exactly 3 (revised Third Round)

**Question**: Should the number of layers per frame be user-modifiable at all?

**Research Summary**:

Second Round set a *maximum* of 3 layers (Layer 1 mandatory, 2–3 optional, add/delete via a Layer View). Third Round (2026-08-31) tightened this: layers are a **fixed structure of exactly 3 per frame**, like the hard cap of 12 animation frames — there is no gesture and no UI to add or remove a layer.

**Decision**: **Every frame has exactly 3 layers, always.**
- Layer 1 (index 0): bottom/base. Its non-ink pixels are **white** (Layer 1's background).
- Layers 2–3 (index 1–2): stacked above. Their non-ink pixels are **transparent** (kColorClear) so lower layers show through.
- No add, no delete. The layer count is not part of the editing model — it is a constant.
- An entirely empty Layer 2 or 3 is **omitted from the saved JSON** and reconstituted on load; single-layer artwork stays compact on disk.

**Rationale**:
1. **Simplicity (Constitution IV)**: no add/delete state machine, no active-layer-was-deleted handling, no Layer View. `activeLayer` is a plain 1..3 cursor.
2. **Backward Compatibility**: a legacy flat image becomes Layer 1 + two empty upper layers; the save still writes a single layer entry while 2–3 stay empty.
3. **Predictability**: fixed 3 × 375 tile-index positions per frame; frame switching never changes the layer count, so the active index always exists.
4. **Matches the 12-frame precedent**: hard, simple limits are explicitly encouraged (Constitution IV) and already used for frames.

**Alternatives Rejected**:
- *1–3 optional layers with add/delete (Second Round)*: needs a Layer View, delete-active-layer handling, and a "how do you create Layer 2" gesture the spec never defined — more UI and state for no clear workflow gain.

**Implementation Impact**:
- **Data Model**: `LayerModel` always builds/validates exactly 3 layers; `addLayer`/`deleteLayer` are removed.
- **Storage Format**: on save, trailing empty upper layers are dropped (1–3 layer entries on disk); on load, every frame is padded back to 3.
- **Pixel editing**: the non-ink (A-press eraser) result is white on Layer 1, transparent on Layers 2–3 — the Pixel/Zoom/Tile edit paths take a per-layer "off state". *(Fifth Round: the A-press eraser is the only paint route in Pixel View; B does not paint.)*
- **US4**: no Layer View. US4 becomes a **Frame Management View** (reorder + delete frames, min. 1).

**Status**: ✅ Clarified (Spec 010 Clarifications, Third Round). Supersedes the Second-Round "1–3 optional" model.

---

## R10: Tile View Control Redesign (Fourth Round — from hardware testing)

**Question**: On device, layer + frame switching on the Crank felt awkward and the Crank was otherwise idle in Tile View. What should the Tile View controls be?

**Research Summary**:

Hardware testing of the Third-Round build showed three problems: (1) "hold Up/Down + full Crank revolution" for a *single* layer step is slow and easy to overshoot; (2) a full 360° revolution to advance one frame is imprecise; (3) the Crank does nothing useful on its own in Tile View, while tile selection still requires walking the cursor onto an existing tile and eyedropping it.

**Decision**: Move layer/frame switching to **B + D-Pad**; give the free Crank a **tile picker**.

```
B + Up / Down     -> active layer  +1 / -1   (wrap 1..3)
B + Left / Right  -> frame  prev / next      (B + Right at last frame = append deep copy)
Crank (no B)      -> tile-picker overlay: ~30°/tile through the REFERENCED tiles, wrap
B + Crank fwd/back-> zoom chain / Frame Management View   (UNCHANGED)
short B-tap       -> eyedropper; Bauchbinde shows "Tile N picked" ~1.5 s
```

**Rationale**:
- **One press = one step** for layer and frame — no revolution counting, no overshoot.
- The picker iterates only tiles actually referenced by the image, scanned from the **layer positions** (`frameLayers[*].layers[*].positions`, skipping `0`) — **not** the flat composite cache. The cache keeps only the topmost tile per cell (`compositeToFlat`), so a tile that lives only on a covered layer would be missing and could disappear mid-session when a higher layer covers its cell. `imagetable:getLength()` is also wrong (session-orphaned tiles, pruned only on save). Selecting index 1 (white) means "no selection" (`activeTile = nil`, toggle mode) — set with an explicit `if`, not `(picked == 1) and nil or picked` (Lua yields `picked` there, always). `EditorRoom:buildPauseMenuImage` (the pause/context view, CR-06) shares this exact scan — its old composite-cache iteration under-counted covered-layer tiles in "Tiles: N".
- `referencedTileIndices()` is the plain factual scan (no seed). `pickerList()` memoises it for the picker (`stepTilePicker` can fire ~12×/`update()` on a fast crank, plus once per `draw()`; invalidated on every tile mutation via `recompositeCell`/`recompositeCurrentFrame`/`entered()`) **and prepends index 1** as the deselect slot so the toggle-mode path is always reachable — even for an image where no cell references tile 1 (which would otherwise strand the picker). The pause view calls the un-seeded scan directly, keeping its count factual.
- `bNavConsumed` latches when B + D-Pad runs, so the subsequent B-release does not also fire the eyedropper. It is cleared only in `BButtonDown`/`BButtonUp`, never derived from live button state (the user may release the direction key before B).
- **CR-01 preserved**: the B branch of `handleCrank` still calls `getCrankTicks(4)`; the no-B branch uses `getCrankChange()` + a `crankAccumDegrees` accumulator with a sub-360° (30°) threshold — never both APIs in one frame.
- B + arrow means pixel-shift in Zoom View (FR-001) and layer/frame switch in Tile View — different rooms, no conflict.

**Alternatives Rejected**:
- *Keep layer/frame on the Crank, add a modifier for the picker*: adds a third Crank mode; the Crank was already the awkward part.
- *Tick-based picker via a second `getCrankTicks(tpr)`*: `getCrankTicks` is stateful in this codebase (see `EditorRoom:update` line ~941) and the headless mock can't catch a tpr-switching bug — would ship blind to hardware.

**Status**: ✅ Implemented (EditorRoom; 356 headless assertions green). Supersedes the "Up/Down + Crank" layer control and "Crank alone = frames" from R3/R4/R9.

---

## Summary Table (Updated)

| Research Item | Decision (current) |
|---------------|--------------------|
| R1: Storage Format | JSON v1.1: `frames[].layers[].{layerIndex,name,positions[375],visible}`; **no** transparency array |
| R2: Transparency State | Per-pixel `kColorClear` in the tile; 3-class tile hash (black/white/clear) |
| R3: Layer Rendering | Composite all 3 layers into a flat cache; topmost non-empty cell wins |
| R4: Frame Switching | Preserve active layer index (all frames have 3 layers, so it always exists) |
| R5: Frame Management View | One flat view; enter with B + Crank-backward from Tile View, exit on B release |
| R6: Pixel Shifting | Decode layer → 400×240 buffer → shift 1px (wrap) → re-tile all 375 cells |
| R7: Backward Compat | Structure-based v1.0/v1.1 detection; pad every frame to 3 layers on load |
| R8: Tests | Headless section per user story + Constitution V gates |
| R10: Tile View Controls | B + Up/Down = layer, B + Left/Right = frame, Crank = tile picker (scans layer positions, not the composite cache); B + Crank unchanged |
| **R9: Layer Count** | **Exactly 3 layers per frame, always — no add/delete (Third Round)** |

---

**Status**: ✅ Research complete — updated for the Third-Round fixed-3-layer clarification.
