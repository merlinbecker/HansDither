# Contract: Start-/Auswahlscreen — Room-Schnittstellen und Interaktion

**Feature**: 002-start-selection-screen | **Date**: 2026-07-03

## 1. Room-API (Konsument: `Source/main.lua`)

```lua
-- Source/SelectionRoom.lua (Room-Muster wie alle bestehenden Rooms)
SelectionRoom:init(switchRoom, editorRoom, titleRoom)
SelectionRoom:entered()        -- lädt Index, baut Menü (3 Slots), invalidiert Thumbnail-Cache
SelectionRoom:update()         -- Raster, Overlay-Dialog, needsRedraw-Muster
SelectionRoom:inputHandler()   -- D-Pad/A/B gemäß Interaktions-Contract unten

-- Source/TitleRoom.lua (bestehende Signatur unverändert)
TitleRoom:init(switchRoom, nextRoomReference)  -- nextRoom = SelectionRoom statt GameRoom
```

Verdrahtung in `main.lua`: `TitleRoom → SelectionRoom → <EditorRoom>`; bis Spec 003 den neuen Editor liefert, führt die Bildauswahl auf einen Übergangsstub (Log + Rückkehr), damit der Branch lauffähig bleibt.

## 2. Editor-Übergabe-Contract (Konsument: Spec 003)

```lua
-- SelectionRoom ruft beim Öffnen eines Bildes:
switchRoom(editorRoom)  -- nachdem editorRoom:setImage(id) gesetzt wurde
editorRoom.setImage(self, id)  -- id gemäß ImageStore-Index (Contract C-01, Spec 001)
```

- **S-01**: SelectionRoom übergibt ausschließlich die `id`; das Laden (`ImageStoreCodec.newLoadOperation`) verantwortet der Editor-Room (Ladebalken dort, Muster arc42 8.6).
- **S-02**: Kehrt der Editor zurück (nach Autosave, Spec 003 FR-014), zeigt `entered()` des SelectionRoom automatisch aktualisierte Previews (Cache-Invalidierung bei entered()).

## 3. Interaktions-Contract (bindet FR-003..FR-012)

| Eingabe | Kontext | Wirkung |
|---|---|---|
| A | TitleRoom | → SelectionRoom (FR-003) |
| A | Bildeintrag selektiert | Editor mit dieser id öffnen (FR-008) |
| A | Neu-Eintrag selektiert | Keyboard-Namensflow → createImage → Editor (FR-012, Clarification Name) |
| B | SelectionRoom (kein Dialog/Keyboard) | → TitleRoom (Rückweg; Menü-Slots sind durch FR-009 belegt) |
| D-Pad | Raster | Selektion bewegen; vertikal über Fensterrand scrollt zeilenweise (FR-006) |
| Menü "new image" | immer | wie A auf Neu-Eintrag (FR-009) |
| Menü "copy image" | Bildeintrag selektiert | copyImage + Raster-Refresh; auf Neu-Eintrag: wirkungslos (FR-009/FR-010) |
| Menü "delete image" | Bildeintrag selektiert | Bestätigungsdialog; A löscht, B bricht ab (FR-009 + Clarification) |
| beliebig | Dialog/Keyboard/laufende Aktion | blockiert bis Abschluss (Edge Case konkurrierende Eingaben) |

## 4. Darstellungszusicherungen

- **D-01**: Jede sichtbare Zelle zeigt maskiertes Thumbnail (unskalierter Ausschnitt, Kreismaske), Platzhalter-Kreis (defektes Preview, FR-011) oder den Neu-Eintrag — nie leere/verzerrte Inhalte (SC-003).
- **D-02**: Sortierung strikt aus `ImageStore.listImages()` (lastEdited absteigend, FR-013); der Room sortiert nicht selbst.
- **D-03**: TitleRoom-Hintergrund: `getLastEditedPreview()` oder Bayer-Dither-Fallback (FR-002); Textpanels liegen immer darüber.
- **D-04**: Nach Neu/Kopieren/Löschen spiegelt das Raster den Index ohne App-Neustart (FR-010): entries neu laden, Cache gezielt invalidieren, Selektionsregel aus data-model.md anwenden.

## 5. Abhängigkeiten

| Benötigt | Aus |
|---|---|
| `listImages`, `createImage`, `copyImage`, `deleteImage`, `getPreviewImage`, `getLastEditedPreview` | Spec 001, contracts/storage-format.md Abschnitt 2 |
| `editorRoom.setImage(id)` + Autosave beim Verlassen | Spec 003 (Editor) |
