# Specification Quality Checklist: Schüttel-Undo für die letzten 3 riskanten Aktionen

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-02
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Notes**: Domänenbegriffe (Frame, Layer, Tile, Crank, Clear Screen, Room/View, Accelerometer) sind projektspezifisch und für die Verständlichkeit nötig. SDK-Funktionsnamen tauchen nur in FR-018 / Architektur-Sektion als Governance-Nachweis auf (Constitution I verlangt die explizite Benennung), nicht in den User Stories oder Success Criteria.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — zwei Clarifications in Session 2026-09-02 geklärt; die vier verbleibenden offenen Punkte sind als *Audit → Open* mit Owner/Follow-up/Trigger geführt (Planungs-, keine Scope-Fragen). SC-006 nennt jetzt eine konkrete, messbare Quote (9/10); nur der Bewegungsschwellwert, der sie erreicht, bleibt als Hardware-Tuning-Parameter in *Audit → Open*.
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

**Notes**: FRs sind entlang der Verifikationsgrenze aufgeteilt — FR-001…FR-009 (Verlaufsmodell) sind headless-testbar (Constitution V Gate 1), FR-010…FR-017 (Schüttel-Geste/Dialog) sind überwiegend Simulator-/Hardware-Integration, FR-018/FR-019 sind Governance/SDK-First. Scope negativ abgegrenzt: kein Redo, kein feingranulares Mal-Undo, nur vier Operationstypen, kein Frame-Umsortieren/-Hinzufügen, keine Persistenz.

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows (US1 Einzel-Undo / US2 3-stufiger Verlauf / US3 modaler, verständlicher Dialog)
- [x] Feature meets measurable outcomes defined in Success Criteria (SC-001…SC-008)
- [x] No implementation details leak into specification

## Architecture Governance (iSAQB-Preset)

- [x] Architecture Applicability ausgefüllt (betroffene/nicht betroffene Aspekte, Qualitätsszenarien, Evidenzpfad)
- [x] ADR-Bedarf benannt (3 ADRs) und arc42-Kapitel 2/4/5/6/8/9/10/11 als betroffen markiert
- [x] Security-relevante Architektur bewertet → `N/A` mit Begründung + Re-Evaluations-Trigger (secure-architecture-Preset nicht angewandt)
- [x] Audit Evidence Applicability: jeder Checkpoint mit `Applicable` / `N/A` (+ Begründung + Trigger) / `Open` (+ Owner + Follow-up + Trigger)
- [x] `docs/architecture/`-Vorgabe adressiert: über `arc42/09` + `arc42/adr/` erfüllt, Abweichung begründet (Constitution III)

**Status-Hinweis (Evidenz vs. Abhaken)**: Die als `Applicable` markierten arc42-Zeilen erfassen *geplante* Evidenzpfade mit Owner `/speckit-plan` — die arc42-Dateien und ADRs selbst sind zum Zeitpunkt dieser Spec **unverändert** (dies ist `/speckit-specify`; arc42-Edits erfolgen laut Memory-Regel in der Planungsphase). Die Häkchen oben bestätigen, dass die Governance-*Analyse* vollständig ist, nicht dass die arc42-Evidenz bereits geschrieben wurde; deren Fertigstellung ist über die Owner/Follow-up-Spalten der *Audit Evidence Applicability*-Tabelle nachverfolgbar.

## Notes

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`.
- Validierung am 2026-09-02: alle Punkte bestanden (1 Iteration). Keine offenen `[NEEDS CLARIFICATION]`-Marker.
- Die vier *Open*-Punkte blockieren `/speckit-plan` nicht — sie sind dort aufzulösen (Memory-Regel „arc42 während Planung").
