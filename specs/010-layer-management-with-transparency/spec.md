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

- Q: Maximum layers per frame — limit or unbounded? → A: **Fixed limit: exactly 3 layers maximum per frame**. Layer 1 (bottom/mandatory base layer) is always present. Layers 2 and 3 are optional. Old images with single layer load as Layer 1 only (backward compatible). Transparency becomes critical for proper layer compositing across all 3 layers.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Precise Pixel-by-Pixel Shifting in Zoom View (Priority: P1)

When working on detailed graphics in the Zoom View (second View showing tiles), a user needs to shift drawn content precisely by single pixels in any direction without affecting the overall tile structure. The user holds B and uses arrow keys (Up/Down/Left/Right) to shift all drawn content within the current frame exactly one pixel at a time while B remains held. The tiles are recalculated after each pixel shift to maintain visual integrity.

**Why this priority**: This is a core editing capability that directly improves precision and user control over artwork. Many pixel art workflows depend on exact positioning, making this a MVP feature for an advanced editor.

**Independent Test**: Load an image with drawn content in Zoom View, hold B and press Up arrow once, verify content shifts up exactly one pixel and tiles remain valid. Repeat for other directions. Reload image to confirm shift persists.

**Acceptance Scenarios**:

1. **Given** a frame with drawn content in Zoom View, **When** B is held and Up arrow is pressed once, **Then** all content shifts up by exactly one pixel and tiles are recalculated
2. **Given** B is being held and Up arrow has been pressed, **When** Down arrow is pressed while B remains held, **Then** content shifts down one pixel (independent of previous direction)
3. **Given** content shifted by B + arrow key, **When** the frame is saved and reloaded, **Then** the shifted position persists exactly as shown
4. **Given** shifted content in one frame, **When** switching to another frame, **Then** only the current frame's content has shifted; other frames are unaffected

---

### User Story 2 - Transparency Support in Pixel View (Priority: P1)

In the Pixel View (third View showing individual 16×16 pixels), the user can now place transparent pixels in addition to opaque drawing. The user presses A to draw opaque pixels as before, but presses B to place transparent pixels at the cursor position. Transparent pixels are stored and persist through save/reload cycles, enabling creation of sprites with actual alpha channel support.

**Why this priority**: Transparency is essential for modern pixel art workflows and enables far more sophisticated visual effects. This is a core feature requested by the user for real graphics flexibility.

**Independent Test**: In Pixel View, place an opaque pixel with A, place a transparent pixel next to it with B, save image, reload, verify transparent pixel appears as transparent (distinct visual state from opaque or empty).

**Acceptance Scenarios**:

1. **Given** cursor in Pixel View at an empty position, **When** B is pressed, **Then** a transparent pixel is placed at cursor position
2. **Given** a transparent pixel already placed, **When** A is pressed at the same position, **Then** the transparent pixel is replaced with an opaque pixel
3. **Given** a transparent pixel in the current frame, **When** frame is saved and image is reloaded, **Then** transparent pixel retains its transparency state
4. **Given** transparent pixels in Frame 1, **When** switching to Frame 2, **Then** Frame 2's pixels are independent (may be empty or contain different transparent/opaque state)
5. **Given** no prior transparency support, **When** old images are loaded, **Then** all pixels are treated as opaque (backward compatibility)

---

### User Story 3 - Layer-Based Editing with Crank Control (Priority: P1)

In the Tile View (first View showing complete image with all tiles), the user can now manage and switch between layers. Animation frames already exist and can be cycled through with the Crank. Layers are orthogonal to frames: each frame can have its own set of layers, and layers can be toggled/cycled without affecting frame switching. The user can hold Up or Down (direction keys) while turning the Crank to cycle through layers in the current frame. Holding Up cycles layers forward, holding Down cycles backward. This control must not conflict with existing Crank behavior (currently used for animation frame cycling).

**Why this priority**: Layers are fundamental to digital art creation. Combined with animation frames, this enables the user to create complex layered animations. This is explicitly requested and part of the core feature set.

**Independent Test**: Load image with Frame 1 containing 3 layers, hold Up and turn Crank, verify Layer indicator changes, release Up, turn Crank and verify frame indicator changes instead. Confirm layers are per-frame by switching frames and observing different layer counts.

**Acceptance Scenarios**:

1. **Given** an image with multiple frames and layers in Tile View, **When** holding Up and rotating Crank clockwise, **Then** active layer cycles forward (e.g., Layer 1 → Layer 2 → Layer 3 → Layer 1)
2. **Given** Up is being held and Crank is rotated, **When** Up is released and Crank continues to rotate, **Then** Crank now cycles frames (not layers)
3. **Given** Frame 1 with 3 layers and Frame 2 with 2 layers, **When** active on Frame 1 Layer 2 and switching to Frame 2, **Then** active layer becomes Layer 2 (preserved by index). If Frame 2 only has 2 layers and active index was 3, active layer wraps to Layer 1
4. **Given** holding Down and rotating Crank, **When** layers cycle backward, **Then** active layer decrements (e.g., Layer 2 → Layer 1 → Layer 3 [wrapping])
5. **Given** no Up/Down key pressed, **When** Crank is rotated, **Then** animation frames cycle (existing behavior preserved)

---

### User Story 4 - Layer & Frame Management View (Priority: P2)

A dedicated Management View provides centralized control for organizing frames and layers. Access to this view is through the Tile View: hold B and rotate Crank backward (counterclockwise). This action navigates upward in a view hierarchy: Tile View → Layer View → Animation Layer View. Within the Layer View, all layers in the current frame are displayed as entries (similar to project selection UI pattern). The user can delete individual layers. From Layer View, continuing to rotate Crank backward (while still holding B) navigates to Animation Layer View, where all animation frames are listed with their associated layer configurations, and layers can be reordered or deleted globally.

**Why this priority**: Layer and frame management is essential for complex animations. Without this, users cannot organize or clean up their work, making it a P2 feature that unblocks serious workflow use cases.

**Independent Test**: In Tile View with Frame 1 containing 3 layers, hold B and rotate Crank backward, verify Layer View appears showing 3 layer entries, delete one layer entry, Layer View now shows 2 layers, rotate Crank backward again, verify Animation Layer View appears showing all frames.

**Acceptance Scenarios**:

1. **Given** in Tile View, **When** B is held and Crank is rotated counterclockwise, **Then** navigation enters Layer View showing all layers in current frame
2. **Given** Layer View is displayed with multiple layers, **When** user presses A on a layer entry, **Then** that layer is highlighted/selected with visual indicator. When B is pressed on a selected layer, **Then** the layer is deleted and view refreshes
3. **Given** Layer View with multiple layers, **When** navigating left/right or up/down (directional controls), **Then** layer selection moves (following standard UI pattern)
4. **Given** in Layer View, **When** B is held and Crank rotates counterclockwise again, **Then** navigation progresses to Animation Layer View (frame-level management)
5. **Given** Animation Layer View with frame entries displayed, **When** user presses A on a frame entry, **Then** a submenu is entered showing all layers within that frame (similar to Layer View). From this submenu, the user can delete individual layers using the A-press to select and B-press to delete pattern
6. **Given** a layer is deleted in Layer View, **When** returning to Tile View, **Then** that layer is no longer available in Crank cycling and all drawings on that layer are removed

---

### Edge Cases

- **Pixel Shift Beyond Boundaries**: When shifting content by pixels that would move it beyond tile boundaries, tiles are recalculated, but content wraps or clips gracefully (no data loss; see FR-005)
- **Transparency & Tile Generation**: Transparent pixels are treated as distinct from opaque and empty in tile deduplication. Two tiles with identical colors but different transparency patterns are stored separately (affects tile deduplication algorithm in storage)
- **Layer Deletion of Active Layer**: When the active (editable) layer is deleted in Layer View:
  - If Layer 1 is deleted: Error — Layer 1 is mandatory and cannot be deleted
  - If Layer 2 or 3 (while active) is deleted: System automatically switches to Layer 1 (or highest remaining layer)
- **Frame Switching & Active Layer**: When switching between frames with different layer counts, active layer index is preserved with wrapping (see Clarifications, FR-017)
- **Empty Layers**: Layers are allowed to be empty (no pixel content). Empty layers are persistent and not auto-deleted. User deletes them explicitly via Layer View
- **Maximum Layers (3-Layer Hard Limit)**: Each frame supports exactly 3 layers maximum. Layer 1 is mandatory. Layers 2 and 3 are optional per frame. System prevents creation of Layer 4 or higher. (Resolved in Clarifications Session 2)

---

## Requirements *(mandatory)*

### Functional Requirements

**Pixel Shifting (US1)**

- **FR-001**: System MUST allow user to hold B and press direction keys (Up/Down/Left/Right) in Zoom View to shift all content in the active frame by exactly one pixel per key press
- **FR-002**: System MUST recalculate all tile references after each pixel shift to maintain visual and data integrity
- **FR-003**: System MUST persist pixel shifts when image is saved and reloaded
- **FR-004**: System MUST apply shifts only to the active frame; other frames remain unaffected
- **FR-005**: System MUST handle shifts at tile boundaries gracefully (no content loss at edges)

**Transparency Support (US2)**

- **FR-006**: System MUST distinguish between three pixel states: opaque, transparent, and empty
- **FR-007**: System MUST allow B-press in Pixel View to place transparent pixels at cursor position
- **FR-008**: System MUST allow A-press in Pixel View to place/overwrite opaque pixels (existing behavior)
- **FR-009**: System MUST persist transparency state when image is saved and reloaded
- **FR-010**: System MUST treat legacy images without transparency as fully opaque (backward compatibility)
- **FR-011**: Transparent pixels in Pixel View MUST render visually distinct from opaque or empty pixels (e.g., checkerboard pattern or distinct color)

**Layer Cycling with Crank (US3)**

- **FR-012**: System MUST store exactly 3 layers per frame maximum (Layer 1 is mandatory/base, Layers 2 and 3 are optional). Layer 1 is always present, even in legacy images
- **FR-012b**: System MUST NOT allow creation of more than 3 layers per frame; UI must prevent adding Layer 4
- **FR-013**: System MUST support holding Up and rotating Crank to cycle forward through layers in active frame
- **FR-014**: System MUST support holding Down and rotating Crank to cycle backward through layers in active frame
- **FR-015**: System MUST display current layer index (1/2/3) and layer name in Tile View (visual indicator)
- **FR-016**: System MUST preserve existing Crank behavior for frame cycling when Up/Down keys are not held
- **FR-017**: System MUST handle layer wrap-around (after Layer 3, cycle back to Layer 1, and vice versa for backward)

**Management View (US4)**

- **FR-018**: System MUST enter Layer View when B is held and Crank is rotated counterclockwise in Tile View
- **FR-019**: Layer View MUST display all layers in the current frame as selectable entries
- **FR-020**: System MUST allow deletion of layers in Layer View via two-step interaction: A-press selects/highlights layer, B-press confirms deletion
- **FR-021**: System MUST navigate to Animation Layer View when B is held and Crank rotates counterclockwise from Layer View
- **FR-022**: Animation Layer View MUST display all animation frames with layer configuration summary
- **FR-023**: Animation Layer View MUST allow frame-level layer management via submenu drill-down: A-press on frame entry opens submenu showing all layers within that frame (similar to main Layer View), where user can select and delete layers using A-press (select) + B-press (confirm delete)
- **FR-024**: System MUST prevent navigation loops (e.g., no cycling from Animation Layer View back into Layer View)

---

### Key Entities *(include if feature involves data)*

- **Frame**: Container for a single animation frame, contains one or more Layers, linked to animation timing
- **Layer**: Container for drawable content within a frame, contains pixel grid (16×16 minimum), supports transparency, linked to visual rendering order
- **Pixel**: Individual drawing unit, can be opaque, transparent, or empty; stored with color/transparency state
- **Tile**: Reference to a tile in the tile sheet used for efficient storage; multiple pixels may reference the same tile
- **LayerView**: UI mode showing all layers in current frame as entries; supports selection, deletion, cycling
- **AnimationLayerView**: UI mode showing all frames with layer organization; supports frame-level and layer-level management

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can shift drawn content by exactly one pixel in any direction and have shifts persist through save/reload cycles
- **SC-002**: Transparent pixels can be placed, stored, and rendered visually distinct from opaque or empty pixels
- **SC-003**: User can cycle through layers using Crank + Up/Down without interfering with existing frame cycling behavior
- **SC-004**: Layer and frame management view is reachable within 2-3 Crank rotations from Tile View and provides intuitive layer deletion
- **SC-005**: All legacy images (created before transparency support) load without errors and render all pixels as opaque
- **SC-006**: Layer information persists when images are saved and reloaded (each frame retains its layer count and content)

---

## Assumptions

- **User Control Model**: The three views (Tile, Zoom, Pixel) already exist and have established Crank and button behaviors. This feature extends those controls, assuming no conflicting bindings (e.g., B is available in Zoom View for shift control, Up/Down are available in Tile View for layer cycling). [VERIFY: confirm available button/input bindings]
- **Storage Format**: The existing image storage format (PDI/JSON) can be extended to include transparency data and layer metadata without breaking existing loaders. [DEPENDENCY: Spec 009 tile cleanup must complete first; confirms JSON structure can be extended]
- **Layer Architecture**: Exactly **3 layers maximum per frame** (fixed hard limit). Layer 1 (base layer) is mandatory and always present. Layers 2 and 3 are optional. Each frame independently can have 1, 2, or 3 layers active.
- **Backward Compatibility (1-Layer Upgrade)**: Legacy images (created before this feature) have only 1 layer (the base content). On load, they are automatically upgraded: the existing content becomes Layer 1, and Layers 2 and 3 are empty/not created. The image remains editable with full layer support.
- **Frame Independence**: Layers are stored per-frame, not globally. This allows frames to have different layer counts (e.g., Frame 1 has 3 layers, Frame 2 has 1 layer). [DESIGN CHOICE: simplifies frame-switching logic and layer persistence]
- **Layer Rendering Order**: Layers are rendered in index order (Layer 1 bottom, Layer 3 top) in Tile View compositing. Only the active layer is editable in Zoom/Pixel views. Transparency between layers is critical for proper compositing (see US2).
- **Empty Layer Handling**: Layers are allowed to be empty (contain no pixel content). Empty layers are not automatically deleted; user has full control via Layer View deletion.
- **Management View Navigation**: The view hierarchy (Tile View → Layer View → Animation Layer View) is linear and unidirectional (B + Crank backward progresses one step; no back button). [DESIGN CHOICE: follows Playdate's constrained navigation patterns]

---

## Architecture Governance & Technical Debt

### Architecture Impact Assessment

**Scope**: This feature affects:
- **Data Model**: Introduction of transparency channel and layer metadata in image storage format
- **Runtime Behavior**: View navigation hierarchy, input multiplexing (Crank behavior conditional on held keys)
- **Interfaces**: Editor state machine, layer management API

**Quality Attributes Affected**:
- **Usability**: Improved precision control (US1), enhanced artistic capabilities (US2), workflow efficiency (US3/US4)
- **Maintainability**: Increased complexity in frame/layer state management; risk of state consistency issues across view transitions
- **Performance**: Layer rendering and tile recalculation on every pixel shift could impact frame rate (Playdate has limited resources)

**Evidence & Decisions**:
- See `docs/architecture/` for expected artifacts after planning:
  - `data-model-transparency.md`: Detailed schema for transparency channel in JSON/PDI storage
  - `layer-state-machine.md`: View transition diagram and input routing logic
  - `rendering-pipeline.md`: Layer compositing and tile recalculation strategy
- **ADR Required**: "Layer Rendering Order & Compositing Strategy" (determine if single active layer or multi-layer preview in Tile View)
- **Risk Record**: "Playdate Performance Under Pixel Shifting" (repeated tile recalculation on every Crank rotation must not drop frame rate below 30 FPS)

### Existing Dependencies & Compatibility

- **Spec 009 (Tile Cleanup)** — MUST complete first: Provides framework for tile recalculation and frame-to-tiles mapping, which is extended by pixel shifting in US1
- **Existing View System** — Assumed stable: Tile View, Zoom View, Pixel View navigation exists; this feature adds Management View without refactoring existing views
- **Playdate SDK** — Assumed available: Crank API, button input handling, image rendering; no new platform capabilities required

### Technical Debt & Risk Mitigation

- **Risk**: Tile recalculation on every pixel shift could cause lag on Playdate hardware
  - **Mitigation**: Performance testing during planning phase; consider batching shifts or lazy recalculation
- **Risk**: Layer metadata could break existing save/load cycle if not handled carefully
  - **Mitigation**: Version the file format; provide fallback loader for legacy images
- **Risk**: Input multiplexing (Up/Down + Crank for layers vs. Crank alone for frames) could be confusing
  - **Mitigation**: Clear visual feedback (layer indicator, state display); user testing during planning

---

## Status Summary

**Ready for Clarification**: 3 clarification markers identified (layer persistence across frames, delete interaction pattern, Animation Layer View interaction). User is invited to resolve via `/speckit-clarify`.

**Next Steps**: → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks`
