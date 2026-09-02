# ADR-046: Modaler Undo-Dialog — ein Modul, vollständige Modalität, Commit vor Label

## Status
✅ **Umgesetzt** (Spec 011, US1/US3) — `Source/UndoPrompt.lua`,
`Source/EditorRoom.lua` / `Source/ZoomRoom.lua` / `Source/PixelRoom.lua`
(Anzeige + Eingabe-Gates in `draw()`/`update()`/`inputHandler()`).

## Kontext
Nach einer erkannten Schüttel-Geste (ADR-044) fragt ein Dialog, ob die
letzte riskante Operation zurückgenommen werden soll. Die Editier-Views
haben **jede Taste und die Kurbel belegt** (A malen, B Zoom-Out-Modifier /
Pipette / B+D-Pad-Navigation, Crank Zoomkette / Tile-Picker /
Frame-Verwaltung). Der Dialog muss diese Eingaben vollständig abfangen
(FR-013), sonst malt „(A) Ja" gleichzeitig einen Pixel oder „(B) Nein"
löst die B-Zoom-Geste aus.

Das Projekt hat mit `SelectionRoom.confirmingDelete` /
`drawConfirmDeleteDialog` bereits **genau dieses Muster**: zentrierte Box,
„(A) …" / „(B) …", schluckt Navigation + Crank, solange der Zustand
gesetzt ist.

## Entscheidungs-Treiber
- Constitution IV: bewährte Muster wiederverwenden, nicht neu erfinden.
- FR-013 an **einer** testbaren Stelle, nicht dreimal kopiert.
- FR-015: ein zweites Schütteln bei offenem Dialog ist wirkungslos.
- FR-012 + FR-016: der Dialog nennt die **konkrete** Operation, und „(A) Ja"
  macht **genau die** Operation rückgängig — Label und Wirkung dürfen nicht
  auseinanderlaufen.
- Das Ergebnis eines Undo ist im **Tile View** sichtbar (der Composite-
  Cache + die Tilemap liegen dort).

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: ein Singleton-Modul `UndoPrompt` (open/isOpen/handleA/handleB/draw/reset); jeder Raum ruft `UndoPrompt.draw()` und gated jeden Input-Callback + Crank-Block auf `isOpen()`** | FR-013/FR-015 an einer Stelle; `SelectionRoom`-Muster; drei Räume teilen sich denselben Dialog | jeder Raum braucht das Gate an mehreren Callbacks (mechanisch, aber testbar) |
| B: pro Raum ein eigener `confirmingUndo`-Zustand (wie `SelectionRoom`) | am nächsten am Vorbild | dreifache Duplizierung derselben Gate-Logik |
| C: `playdate.ui`-Dialog | „offiziell" | es gibt keinen fertigen modalen Ja/Nein-Dialog in `playdate.ui`; `gridview` wäre zweckentfremdet |

## Entscheidung
**Option A.**

### `UndoPrompt` (`Source/UndoPrompt.lua`)
- `open(label, onConfirm)` — **No-op, wenn bereits offen** (FR-015: zweites
  Schütteln ändert weder Label noch Callback).
- `isOpen()`, `currentLabel()` (Accessor, Tests/Debug).
- `handleA()` — **erst** schließen, **dann** `onConfirm()` genau einmal
  (ein re-entranter Pfad sieht den Dialog schon geschlossen).
- `handleB()` — schließen, `onConfirm` nicht rufen.
- `reset()` — defensiv beim Raumwechsel.
- `draw()` — zentrierte Box, Zeile 1 `label`, Zeile 2 „(A) Ja", Zeile 3
  „(B) Nein"; nur wenn `isOpen()`.

### Einbindung je Raum (`EditorRoom`/`ZoomRoom`/`PixelRoom`)
- `draw()` ruft am Ende `UndoPrompt.draw()`; die Redraw-Bedingung ist
  `needsRedraw or … or UndoPrompt.isOpen()` (in allen drei Räumen gleich).
- **Jeder** Input-Callback prüft zuerst `if UndoPrompt.isOpen() then …`:
  `AButtonDown → UndoPrompt.handleA()`, `BButtonDown → UndoPrompt.handleB()`,
  alles andere → früh-`return`. Die `update()`-Crank-Blöcke verwerfen bei
  offenem Dialog die Crank-Reste (kein Nachholwert nach dem Schließen).
- `EditorRoom` besitzt die `ShakeDetector`-Instanz und die
  `undoHistory`; Zoom-/Pixel-View reichen ihr Sample über
  `EditorRoom:onShakeSample(x, y, z, commitAndReturn)` weiter.

### Commit **vor** dem Label (Verfeinerung aus der Implementierung)
`EditorRoom:undoRequest(commitAndReturn?)`:

1. **Zuerst** `if commitAndReturn then commitAndReturn() end` — aus
   Zoom-/Pixel-View: offene Zell-Edits committen + zurück in den Tile View
   (`ZoomRoom` über `applyTileEdits` + `switchRoom`; `PixelRoom` über die
   etablierte Exit-Kette `commitToZoomRoom()` → `commitForTerminate()` →
   `switchRoom`).
2. **Dann** `entry, reason = undoHistory:peekValid(imageData)`.
3. `entry` → `UndoPrompt.open(labelFor(entry.op), function()
   EditorRoom:undoLast() end)`.
4. kein `entry` → `showStatus(reason == "frame-limit" and
   "cannot undo - frame limit" or "Nothing to undo")`, **kein Dialog**
   (FR-007/FR-009).

Der Grund: Der **Rotation**-Eintrag entsteht erst beim Commit
(`ZoomRoom:setNewTile` → `recordRotation`). Würde `undoRequest` das Label
vor dem Commit wählen, zeigte der Dialog bei einem Schütteln im Pixel-View
das Label des **älteren** Eintrags (z. B. „Undo Clear Screen?"), während
„(A) Ja" die soeben committete Rotation zurücknimmt (`undoLast` peekt neu
und nimmt den jüngsten). Label ≠ Wirkung — ein FR-016-Bruch. Commit-first
räumt die Historie auf, bevor das Label fällt; der Dialog erscheint dann im
Tile View (wo das Undo-Ergebnis ohnehin sichtbar wird). Aus dem Tile View
selbst wird `undoRequest` ohne `commitAndReturn` gerufen — dort ändert sich
nichts.

## Begründung
- Ein Modul statt drei `confirmingUndo`-Kopien: FR-013 wird an einer Stelle
  getestet (V20).
- `handleA` schließt vor dem Callback → `undoLast()` und ein daraus
  ausgelöster Redraw sehen einen konsistenten „zu"-Zustand.
- Commit-first ist einfacher als „den konkreten Eintrag im Closure
  einfrieren" — und der Rotation-Eintrag existiert vor dem Commit
  überhaupt nicht, ließe sich also gar nicht einfrieren.

## Konsequenzen
- **Positiv**: FR-013/FR-015/FR-016 zentral; `SelectionRoom`-Muster
  wiederverwendet; drei Räume teilen einen Dialog. V17–V25 headless grün.
- **Negativ**: ein Schütteln im Zoom-/Pixel-View **ohne** vorhandenen Undo
  committet trotzdem die offenen Zoom-Edits und wechselt in den Tile View,
  bevor „Nothing to undo" erscheint. Akzeptiert: das Schütteln ist eine
  bewusste Geste, und der Commit ist nicht destruktiv (die Edits würden
  beim normalen Verlassen ohnehin committet).
- **Negativ**: das Input-Gate muss in jedem Callback jedes Raums stehen —
  mechanisch, aber durch V20 abgesichert.
- **Einzeilige Abweichung von research.md R7**: dort committet der
  `onConfirm`-Callback (`commit → undoLast`); umgesetzt ist Commit **in
  `undoRequest` vor `peekValid`**, damit das Label passt. Wirkung für den
  Nutzer identisch, nur die Reihenfolge Commit ↔ Dialog ist getauscht.

## Related
- [ADR-044: Schüttel-Erkennung](ADR-044-Schuettel-Erkennung-Accelerometer.md)
- [ADR-045: Undo-Modell — 3 Schritte, sitzungslokal](ADR-045-Undo-Modell-3-Schritt-sitzungslokal.md)
- [ADR-032: Reset-Frame statt Delete-Frame im Menü](ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md) (`SelectionRoom`-Bestätigungsmuster, hier wiederverwendet)
- [specs/011-shake-to-undo/research.md: R5, R7](../../specs/011-shake-to-undo/research.md)
- [specs/011-shake-to-undo/spec.md: FR-012, FR-013, FR-015, FR-016](../../specs/011-shake-to-undo/spec.md)
