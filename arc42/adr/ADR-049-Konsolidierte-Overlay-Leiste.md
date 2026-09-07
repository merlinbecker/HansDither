# ADR-049: Konsolidierte Tile-View-Overlay-Leiste (cursorabgewandt)

## Status
✅ **Umgesetzt** (Spec 010, 8. Runde aus dem Hardware-Test) —
`Source/Bauchbinde.lua` (`draw` neu, `drawBottom` Wrapper),
`Source/EditorRoom.lua` (`overlayAnchor`/`overlayRegionRect`/`cursorCellRect`,
`draw()`, `drawTilePickerOverlay(vAnchor)`).

## Kontext
Die Tile View haelt mehrere passive Hinweis-Overlays:

- Frame/Ebenen-Label „Frame n/m  L#/# Name" (FR-015),
- Tile-Picker-Filmstreifen (FR-025) — gezeichnet **bildschirmmittig**,
- „Tile N picked"-Pipetten-Toast (FR-027),
- Statustexte (Fehler/„Nothing to undo" …),
- dazu der modale Undo-Dialog aus Spec 011 (`UndoPrompt`, eigene Schicht).

Der Hardware-Test der ausgelieferten Spec-010/011-Version zeigte: der
zentrierte Tile-Picker verdeckt Bild **und** Cursor; ausserdem kollidieren
Label und Statuszeile unten-links, wenn der Cursor auf der rechten
Bildschirmhaelfte steht (beide `drawBottom(..., "left", …)`).

Die `Bauchbinde` folgt fuer das Label bereits der Spec-006-FR-003-Konvention
„auf der dem Cursor gegenueberliegenden Bildschirm**haelfte**" (horizontal).

## Entscheidungs-Treiber
- FR-028 / SC-008: EINE Leiste, die die Cursor-Zelle **nie** verdeckt und in
  sich kollisionsfrei ist.
- Constitution IV: die etablierte „cursor-abgewandt"-Konvention erweitern,
  nicht ein zweites Layout-System bauen.
- Spec 011 FR-013: der Undo-Dialog muss voll modal bleiben — er darf nicht in
  eine passive Leiste gefaltet werden (das oeffnete Spec 011 erneut).
- Die Platzierungslogik soll ohne echtes Rendering testbar sein.

## Entscheidung
Alle **passiven** Overlay-Elemente teilen sich EINE Leiste in der dem
Tile-Cursor **abgewandten** Zone.

- Horizontale Haelfte weiter nach `cursor.x` (Spec 006 FR-003).
- Vertikaler Rand nach `cursor.y`: `overlayAnchor(cursorY, GRID_ROWS)` →
  `"bottom"`, wenn `cursorY <= GRID_ROWS/2` (obere Cursor-Haelfte), sonst
  `"top"` (Gleichstand → `"bottom"`).
- `Bauchbinde:draw(lines, side, vAnchor, w, h)` zeichnet **mehrzeilig**
  (Einzeiler exakt wie zuvor; ab zwei Zeilen waechst die Box); Label und
  Statustext stehen als zwei Bandzeilen in derselben Box — der separate fixe
  `drawBottom(statusMessage, "left", …)` entfaellt.
- `drawBottom(text, side, w, h)` bleibt **signaturgleicher** Wrapper
  (`self:draw(text, side, "bottom", w, h)`) → `SelectionRoom.lua:456`
  unveraendert.
- Der Tile-Picker liegt bei Sichtbarkeit in derselben Zone
  (`drawTilePickerOverlay(vAnchor)`, `py` ankerrelativ statt `(240-panelH)//2`);
  das Label pausiert solange. Ist zugleich Status zu zeigen, weicht die
  Statuszeile auf den **gegenueberliegenden** Anker aus (SC-008).
- Der Undo-Dialog (`UndoPrompt.draw()`) bleibt eine **eigene, koordinierte
  Schicht** — zuletzt gezeichnet, zentriert, voll modal.
- `overlayAnchor` / `overlayRegionRect(anchor, contentH, screenH)` /
  `cursorCellRect(cx, cy)` sind reine Funktionen (als `EditorRoom.*`
  headless erreichbar).

## Konsequenzen
- SC-008 headless verifiziert: fuer jede Cursorzeile 1..GRID_ROWS schneidet
  `overlayRegionRect(overlayAnchor(y), h, 240)` die `cursorCellRect(cx, y)`
  **nie**; bei sichtbarem Picker ueberzeichnen sich Filmstreifen (abgewandte
  Zone) und Statuszeile (Gegen-Zone) **nie**. `drawBottom`-4-Arg-Kompatibilitaet
  ebenfalls getestet; die bestehenden Bauchbinden-Tests (`bandFillEntry`,
  `h == 22`, `.x`) bleiben unveraendert gruen.
- `EditorRoom:draw()` hat statt drei Ad-hoc-Zeichenbloecken (Label unten,
  Picker mittig, Status unten-links) **einen** Layout-Durchlauf.
- buildNumber 37 → 39, `pdc` sauber.

## Verworfene Alternativen
- *Undo-Dialog in die Leiste falten* — bricht Spec 011 FR-013 (volle
  Modalitaet) / SC-005 (headless V20).
- *Picker zentriert lassen, nur kleiner* — liegt weiter ueber dem Bild.
- *Nur horizontal ausweichen (wie bisher)* — ein horizontal versetztes
  Mittel-Panel ueberlappt einen Cursor nahe der vertikalen Mitte.

## Bezug
- Spec: `specs/010-layer-management-with-transparency/spec.md` — FR-028,
  SC-008; FR-015/025/027 revidiert (8. Runde).
- Plan/Contracts: `plan.md` „Eighth-Round Update" (Phase A);
  `contracts/frame-room-and-overlay.md` (Bauchbinde + Overlay draw);
  `research.md` R13.
- arc42: §9.37; Kap. 5 (Bauchbinde-/EditorRoom-Zeile), §6.18, Kap. 8
  („Konsolidierte Tile-View-Overlay-Leiste"), QS-24, R-34.
- Verwandt: Spec 006 FR-003 (cursor-abgewandte Bauchbinde), AD-042
  (Tile-Picker), Spec 011 AD-046 (`UndoPrompt`).
