# Specification Quality Checklist: Layer Management, Precise Pixel Shifting & Transparency Support

**Purpose**: Validate specification completeness and quality before proceeding to planning

**Created**: 2026-08-31

**Feature**: [Link to spec.md](spec.md)

---

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Notes**: Specification is written in user-centric language, emphasizing "what" and "why" over "how". Technical terms (Crank, tile, frame, layer) are domain-specific to Playdate/Hans-Dither and are necessary for clarity.

---

## Requirement Completeness

- [x] [CLARIFICATIONS INTEGRATED] [NEEDS CLARIFICATION] markers resolved and documented in spec
- [x] Requirements are testable and unambiguous (where clarified)
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

**Clarification Markers Found**: 3

1. **Marker 1 (US3, Acceptance Scenario 3)**: Layer persistence strategy when switching frames
   - Current text: "Frame 1 with 3 layers and Frame 2 with 2 layers, When active on Frame 1 Layer 2 and switching to Frame 2, Then Frame 2 defaults to Layer 1 (or [NEEDS CLARIFICATION: layer persistence strategy per frame])"
   - Impact: Moderate (affects UX and state management)
   - Candidates: 
     - A) Always reset to Layer 1 when switching frames
     - B) Preserve layer index (if Frame 2 only has 2 layers and active index was 3, wrap to Layer 1)
     - C) Preserve layer object identity (if same layer exists in both frames, stay on it)

2. **Marker 2 (US4, Acceptance Scenario 2)**: Delete interaction pattern in Layer View
   - Current text: "Layer View with multiple layers, When user selects (A-presses) a layer entry, Then layer is deleted and view refreshes [NEEDS CLARIFICATION: confirm A-press for delete vs. separate delete action]"
   - Impact: Moderate (affects control scheme consistency)
   - Candidates:
     - A) A-press directly deletes (immediate, destructive)
     - B) A-press selects, then B-press confirms delete (safer)
     - C) A-press selects, then Menu/Select deletes (follows system patterns)

3. **Marker 3 (US4, Acceptance Scenario 5)**: Animation Layer View interaction pattern
   - Current text: "Animation Layer View, When user presses A on a frame entry, Then layer reordering or deletion mode is entered for that frame [NEEDS CLARIFICATION: interaction pattern for Animation Layer View: inline reorder vs. submenu]"
   - Impact: Moderate (affects workflow efficiency)
   - Candidates:
     - A) Inline reordering with Crank (select layer, rotate to reorder)
     - B) Submenu for each frame (drill down, manage layers separately)
     - C) Hybrid (visual preview with reorder overlay)

---

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows (4 stories covering pixel shift, transparency, layer cycling, management)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

**Validation**: All 4 user stories map to distinct, testable capabilities. Requirements FR-001 through FR-024 are verifiable without knowing implementation (language, graphics library, etc.). Success criteria (SC-001 through SC-006) are quantitative and technology-agnostic.

---

## CLARIFICATION REQUIRED

### Question 1: Layer Persistence When Switching Frames

**Context** (US3, Acceptance Scenario 3):
> Given Frame 1 with 3 layers and Frame 2 with 2 layers, When active on Frame 1 Layer 2 and switching to Frame 2, Then Frame 2 defaults to Layer 1 (or [NEEDS CLARIFICATION: layer persistence strategy per frame])

**What we need to know**: Should the active layer index be preserved, reset, or intelligently mapped when switching between frames that have different layer counts?

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | Always reset to Layer 1 when switching frames | Simple state management, but requires user to re-select layer on every frame switch. May feel repetitive. |
| B | Preserve layer index with wrapping (e.g., Layer 2 on Frame 1 → Layer 2 on Frame 2 if it exists, else Layer 1) | Predictable, reduces re-selection, but users may accidentally work on wrong layer if counts differ. |
| C | Preserve semantic layer (if layer name/ID exists in both frames, stay on it) | Sophisticated, assumes consistent layer naming across frames. Complex state management. |

**Your choice**: Please respond with A, B, C, or Custom with explanation

---

### Question 2: Delete Interaction in Layer View

**Context** (US4, Acceptance Scenario 2):
> Given Layer View with multiple layers, When user selects (A-presses) a layer entry, Then layer is deleted and view refreshes

**What we need to know**: Should A-press directly delete a layer (destructive, immediate) or should there be a confirmation step?

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | A-press immediately deletes layer without confirmation | Fast workflow for experienced users, but high risk of accidental deletion. No undo. |
| B | A-press selects layer, then B-press or Hold+Confirm confirms delete | Safer, requires two actions, follows safety patterns for destructive operations. Slower workflow. |
| C | A-press selects, Menu button opens submenu with delete option | Consistent with system navigation, explicit, but adds extra step. |

**Your choice**: Please respond with A, B, C, or Custom with explanation

---

### Question 3: Animation Layer View Interaction Pattern

**Context** (US4, Acceptance Scenario 5):
> Given Animation Layer View, When user presses A on a frame entry, Then layer reordering or deletion mode is entered for that frame

**What we need to know**: Should frame management (reorder/delete layers within a frame) happen inline with visual feedback, in a separate submenu, or through a dedicated reordering overlay?

**Suggested Answers**:

| Option | Answer | Implications |
|--------|--------|--------------|
| A | Inline reordering: A-press to select frame, Crank rotates to reorder layers within that frame | Visual, direct manipulation, but requires visual representation of layer order within the entry. |
| B | Submenu drill-down: A-press enters submenu for that frame where user can manage layers (similar to Layer View but frame-specific) | Familiar pattern (repeats Layer View), clear visual hierarchy, but adds navigation depth. |
| C | Separate reorder mode: A-press + Hold B + Crank to reorder; B-press to delete (distinct mode) | Powerful but steep learning curve, multiple simultaneous inputs. Risk of mode confusion. |

**Your choice**: Please respond with A, B, C, or Custom with explanation

## Clarification Resolution

**All clarifications have been resolved** using informed defaults based on Hans-Dither's existing UI patterns (SelectionRoom, animation frame cycling, button conventions):

### Question 1 Resolution: Layer Persistence → **Option B**
- Decision: Preserve layer index with wrapping when switching frames
- Rationale: Reduces repetitive re-selection, provides predictable behavior, consistent with animation software conventions
- Implementation note: If user is on Layer 3 of Frame 1, but Frame 2 only has 2 layers, wrap active layer to Layer 1

### Question 2 Resolution: Delete Interaction → **Option B** 
- Decision: A-press to select/highlight layer, B-press to confirm delete
- Rationale: Safer for destructive operations, prevents accidental deletion, follows Playdate safety patterns (confirmation required for significant actions)
- Updated spec: Layer View now requires two-step interaction (select with A, delete with B)

### Question 3 Resolution: Animation Layer View → **Option B**
- Decision: Submenu drill-down pattern (enter submenu via A-press on frame entry)
- Rationale: Mirrors existing SelectionRoom/ProjectSelection pattern, creates visual hierarchy, follows Hans-Dither's established navigation model
- Updated spec: Animation Layer View drill-down shows per-frame layer management similar to main Layer View

---

## ✅ VALIDATION PASSED

### Integration Note (Session 2, 2026-08-31)

New clarification integrated: **3-Layer Hard Limit per Frame**
- Layer 1 is mandatory (base layer)
- Layers 2 and 3 are optional
- Legacy 1-layer images auto-upgrade to Layer 1
- Affects: FR-012, FR-012b, FR-017, Edge Cases (layer deletion, empty layers, max layers)
- Rationale: Backward compatible, performance-optimized, simplifies architecture

### Integration Note (Session 3, 2026-08-31) — supersedes parts of Sessions 1–2

Re-validated against the updated spec. All 16 checklist items remain passing
(16/16 → 16/16, no state changes). New clarifications integrated:

- **Layers are a fixed structure of exactly 3 per frame** — no add/delete (like the 12-frame cap). Supersedes the Session-2 "1–3 optional" model and Session-1 Question 2/3 (there is no Layer View to delete layers in).
- **Non-ink pixel state is layer-dependent**: white on Layer 1, transparent on Layers 2–3. Layer 1 has no transparent state.
- **Empty upper layers** are omitted from the saved file, reconstituted to 3 on load.
- **US4 is now a Frame Management View** (reorder + delete frames, min. 1) — the Layer View / Animation Layer View from Session-1 Questions 2–3 are dropped. Delete is confirmed with a second A-press (B is the hold-to-stay key).
- Affects: FR-006..FR-011 (transparency), FR-012/012b/012c/017b (fixed 3 layers), FR-018..FR-024 (Frame Management View), Edge Cases, Key Entities, Success Criteria, Assumptions.
- The "CLARIFICATION REQUIRED" Questions 1–3 above are historical; Q1 (index preservation) still holds trivially since every frame has all 3 layers.

### Integration Note (Session 4, 2026-08-31) — Tile View control redesign (from hardware testing)

Re-validated against the updated spec. All 16 checklist items remain passing
(16/16 → 16/16, no state changes). New clarifications integrated:

- **Layer switch → B + Up/Down**, **frame switch → B + Left/Right** (B + Right on the last frame appends a frame). The Crank no longer switches layer or frame.
- **Crank alone → tile picker** over the *referenced* tile indices (~30°/tile, wraparound, auto-hide); index 1 (white) = "no selection".
- **Eyedropper toast**: a short B-tap shows "Tile N picked" in the Bauchbinde for ~1.5 s.
- **B + Crank forward/backward** (zoom chain / Frame Management View) is **unchanged**. B + arrow means pixel-shift in Zoom View but layer/frame switch in Tile View — different views, no collision.
- Affects: FR-013/014/016, new FR-025..FR-027 (Tile Picker & Eyedropper Feedback, US5), US3/US4 narrative, SC-003/004, new SC-007, Edge Cases, Assumptions, Architecture Governance. New ADR-042. research.md gains R10.

### Integration Note (Session 5, 2026-09-01) — Pixel View: B stops painting (from hardware testing)

Re-validated against the updated spec. All 16 checklist items remain passing
(16/16 → 16/16, no state changes). One clarification integrated:

- **Pixel View painting is A only.** B no longer places a pixel (a lone B-tap is inert); B stays the zoom-out modifier (B held + Crank backward). The A-press eraser already reaches the layer's non-ink state — white on Layer 1, transparent on Layers 2–3 — so nothing became unreachable. This also removes the stray transparent pixel the old B-paint dropped into the tile on every B-held zoom-out.
- Affects: **FR-007** (rewritten from "B sets the non-ink state" to "B does not paint in Pixel View"), FR-008 wording, US2 narrative + acceptance scenarios + Independent Test, Edge Cases ("Layer 1 Transparency" + new "Pixel View B-press"), Status Summary. ADR-040 gains a Fifth-Round addendum. research.md R2/R8 updated.

### Integration Note (Session 8, 2026-09-06) — Eighth Round: Overlay consolidation & Frame Room (from hardware testing)

Re-validated against the updated spec. All 16 checklist items remain **passing** (16/16 → 16/16, no state changes). Two clarifications integrated (user-decided gestures via `/speckit-specify`):

- **Consolidated overlay bar** — the Tile View's passive chrome (frame/layer label FR-015, tile-picker filmstrip FR-025, "Tile N picked" toast FR-027, status messages) shares **one** bar anchored on the edge opposite the tile cursor; it never covers the cursor's tile and its elements never overdraw each other. The Spec 011 modal undo dialog stays a separate, coordinated layer (it must stay fully modal per Spec 011 FR-013). New **FR-028**, new **SC-008**; FR-015/025/027 revised.
- **Frame Management Room** — the hold-B modal "Frame Management View" becomes a **persistent room**: enter with **B + Crank backward**, leave with **B + Crank forward**; frames shown as a **rectangular thumbnail grid** mirroring the project-selection room; reorder = mark with A, then D-Pad moves the marked frame in the animation sequence (Left/Right ±1, Up/Down ±one grid row); a second A-press on an unmoved marked frame deletes it (min. 1 frame); a further A-press on a moved marked frame just clears the mark. Add-frame is unchanged (Tile View B + Right on the last frame, FR-016).
- Affects: US4 (retitled "Frame Management Room", narrative + Independent Test + acceptance scenarios rewritten), **FR-015/018/019/020/021/022/025/027 revised**, **new FR-028**, **SC-004/SC-007 revised**, **new SC-008**, Key Entities ("Frame Management Room" + "Consolidated overlay bar"), Edge Cases (+3), Assumptions (+4), Architecture Governance (new "Eighth-Round Update" subsection with audit-evidence table + 2 new ADRs + 1 risk record), Status Summary.
- **Tracked open item** (not a blocking [NEEDS CLARIFICATION]): Spec 011 `research.md` R6 disabled the shake/undo gesture in this view because B was held; the persistent room frees B → owner `/speckit-plan`, re-evaluation trigger = room-lifecycle implementation.

**Content-quality note**: like the rest of Spec 010, this round names commit hashes / module identifiers (`c2cbb6f`, `FrameManagementView`, `deleteMarked()`) in the Clarifications and Architecture Governance sections. Consistent with the spec's established style; the user-facing sections (User Scenarios, Requirements, Success Criteria) stay implementation-agnostic.

**Downstream**: `/speckit-plan` + `/speckit-tasks` must be re-run for this round (arc42 Kap. 4/5/6/8/9/10/11, 2 new ADRs, plus the still-outstanding Spec-010 Kap. 6/7 runtime-view backfill). `.specify/feature.json` repointed to `specs/010-layer-management-with-transparency`.



### Implementation Note (2026-09-06) — Eighth + Ninth Round done

`/speckit-implement` T060–T096: consolidated overlay bar (FR-028/SC-008) + persistent Frame Management Room (FR-018..FR-022, SC-004) built and green. `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN" (577 OK); `Source/pdxinfo` buildNumber 37 → 40; `pdc` exit 0 per phase. arc42 Kap. 4/5/6/7/8/9/10/11 updated; **ADR-048** (Frame Room) + **ADR-049** (Overlay bar) written (ADR-047 was already Spec 011). All governance checkpoints **Done** except **Manual simulator/hardware integration** (T093/T094 — owner: Merlin, open). Spec quality checklist: 16/16 → 16/16 (no state change).

### Integration + Implementation Note (2026-09-07) — Tenth Round: tile picker full-revolution activation (from hardware testing)

Re-validated against the updated spec — all 16 checklist items remain **passing** (16/16 → 16/16, no state changes). One clarification integrated (Session 2026-09-07): the tile picker was opening on the smallest crank movement, so incidental contact while docking/undocking the Crank kept popping the overlay. **FR-025 / SC-007 revised**: the picker opens only after a **full crank revolution** (≥ 360° net, signed `pickerArmDegrees`, either direction — jiggle cancels toward zero); once open, the ~30°/tile fine stepping is unchanged; after the auto-hide another full revolution is needed. B + Crank tick thresholds untouched. Affects FR-025, SC-007, Clarifications (new Session 2026-09-07), the Fourth-Round Q&A note, "ten rounds" count.

`/speckit-implement` T097–T101: `Source/EditorRoom.lua` (`PICKER_ACTIVATE_DEGREES`, `pickerArmDegrees`, `handleCrank` no-B branch), `tests/headless_tests.lua` (jiggle / partial-turn / full-turn assertions; existing picker sections open via `openPickerWithFullTurn()`). `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN"; `Source/pdxinfo` buildNumber 40 → 41; `pdc` exit 0. Docs pulled through spec / research (R10) / data-model / contracts / quickstart / plan + arc42 §9.30 + **ADR-042 Nachtrag (10. Runde)**. Open: **T101** (hardware sign-off — slow full turn opens reliably, slow drift does not falsely open, no false shake — owner: Merlin).
