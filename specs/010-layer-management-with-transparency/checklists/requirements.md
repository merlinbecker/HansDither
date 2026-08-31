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


