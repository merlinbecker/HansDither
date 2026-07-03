# Implementation Plan: Editor-Umbau — 16×16-Tiles, Animation und Zoomstufen

**Branch**: `feature/0.3` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-editor-animation-zoom/spec.md`

## Summary

Ein neuer `EditorRoom` ersetzt den Pulp-gekoppelten TileRoom: 25×15-Raster aus 16×16-Tiles auf nativen 400×240, gerendert über SDK-`tilemap` + Laufzeit-Imagetable aus dem `imageData`-Contract von Spec 001. Eingaben: D-Pad bewegt den Cursor, B = Pipette, A = Zeichnen/Toggle; der Crank (Rastung `getCrankTicks(4)` wie der frühere Tile-Picker) verwaltet bis zu 12 Animationsframes mit Kopie-Semantik und beidseitiger Rotation; B+Crank wechselt durch drei Zoomstufen. ZoomRoom (24×24-Raster über 3×3 Tiles, 2×2-Pixel-Malstrich) und PixelRoom (16×16, 1×1) werden auf die neuen Maße umgestellt und behalten ihre Zusatzfunktionen. Beim Verlassen speichert `ImageStoreCodec.newSaveOperation` automatisch; danach werden TileRoom*, LoadRoom* und PulpGameIO* entfernt.

## Technical Context

**Language/Version**: Lua (Playdate SDK Lua-Runtime, aktuelles SDK)

**Primary Dependencies**: Playdate SDK CoreLibs (`playdate.graphics.tilemap/imagetable/image`, `playdate.getCrankTicks`, Buttons, `playdate.getSystemMenu()`, timer); Spec-001-Contract (`imageData`, `ImageStoreCodec.newSaveOperation/newLoadOperation`, FNV-1a-`hashIndex`); Spec-002-Contract (`editorRoom:setImage(id)`); bestehende Bausteine `RoomOperation`, `loadingBar`, `Bauchbinde`, `PencilCursor`

**Storage**: Ausschließlich über den Spec-001-Contract (keine eigenen Formate); Editor mutiert die Laufzeitrepräsentation `imageData` (frames, imagetable, hashIndex)

**Testing**: Manuelle Simulator-Szenarien in [quickstart.md](quickstart.md); Crank-Rastung zusätzlich auf Hardware prüfen (Constitution: hardware-nahe Funktionen am Gerät)

**Target Platform**: Playdate (Device + Simulator), 400×240, 1-Bit

**Project Type**: Single project (Lua-App unter `Source/`)

**Performance Goals**: Cursor/Malen/Frame-Wechsel ohne wahrnehmbare Verzögerung (SC-004); Frame-Wechsel = `tilemap:setTiles(frames[f], 25)` + Redraw, keine Bildkopien im Update-Pfad

**Constraints**: Constitution I (SDK-first: tilemap statt Offscreen-Scaling — Daten- und Anzeigeauflösung fallen zusammen, AD-016), IV (Einfachheit: harte 12-Frame-Grenze, kein Playback laut Clarification); Systemmenü-Limit 3 Slots (SDK); kein Undo

**Scale/Scope**: 1–12 Frames × 375 Zellen; Imagetable wächst dynamisch beim Malen (Dedup begrenzt); 1 neuer Room, 2 umgebaute Rooms, 6 entfallende Dateien

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-first | Rendering = `tilemap` + Imagetable (nativ, ohne Offscreen-Skalierung — das duale Auflösungskonzept entfällt ersatzlos); Frame-Rastung = `playdate.getCrankTicks(4)`; Cursor/Grid = vorhandene SDK-Zeichenprimitiven; Menü = `getSystemMenu()`. Eigenleistungen sind nur Kompositionen bestehender Muster (B+Crank-Trigger, Slot-Mapping der Zoomräume) — bereits etabliert und in AD-019 dokumentiert. | PASS |
| II. Native Formate & PDI | Editor arbeitet direkt auf der Spec-001-Laufzeitrepräsentation (`frames` = `tilemap:setTiles`-kompatible Arrays, Contract C-02); keine neuen Formate. | PASS |
| III. arc42-Pflege | Umsetzungsschnitt aktualisiert arc42 Kap. 5/6/8/10/12, setzt AD-016/AD-019 auf "umgesetzt", markiert AD-014/AD-015 als abgelöst und entfernt die Pulp-Ist-Beschreibungen. Als Tasks einzuplanen. | PASS (geplant) |
| IV. Einfachheit | Neuaufbau des EditorRoom statt Weiterverbiegen des 881-Zeilen-TileRoom mit Pulp-Kopplung; ZoomRoom/PixelRoom werden parametrisch umgestellt statt neu geschrieben; Wegfall von EditMode-Automat, Tile-Picker und Offscreen-Buffer reduziert Zustandskomplexität netto. | PASS |

**Post-Design Re-Check (nach Phase 1)**: PASS — Datenfluss bleibt auf dem Spec-001-Contract; keine neuen Abstraktionsschichten; Complexity Tracking leer.

## Project Structure

### Documentation (this feature)

```text
specs/003-editor-animation-zoom/
├── plan.md              # Diese Datei
├── research.md          # Phase 0: Crank-Rastung, Frame-Modell, Zoomraum-Umstellung, Menübelegung
├── data-model.md        # Phase 1: Editor-Zustand, Frame-Operationen, Zoomkontexte
├── quickstart.md        # Phase 1: Validierungsszenarien (Simulator + Hardware-Check Crank)
├── contracts/
│   └── editor-room.md   # Phase 1: Room-API, Eingabe-Contract, Zoom-Übergaben
└── tasks.md             # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
Source/
├── EditorRoom.lua        # NEU: 25×15-Tilemap-Editor, Cursor, A/B-Semantik, Frame-Verwaltung,
│                         #   B+Crank-Zoomtrigger, Autosave beim Verlassen, Systemmenü
├── ZoomRoom.lua          # UMBAU: 3×3×16px-Kontext als 24×24-Raster (Zelle = 2×2 native Pixel),
│                         #   Commit über imageData-Dedup-Pfad statt TileRoom-API
├── PixelRoom.lua         # UMBAU: 16×16-Pixelraster statt 8×8; Rückgabe an ZoomRoom unverändert
├── main.lua              # GEÄNDERT: SelectionRoom → EditorRoom verdrahten (ersetzt Stub aus 002);
│                         #   Terminate-Hook final auf EditorRoom umstellen
├── Bauchbinde.lua        # WIEDERVERWENDET: Frame-Anzeige "Frame n/m"
├── PencilCursor.lua      # WIEDERVERWENDET: Cursor-Overlay
├── TileRoom.lua          # ENTFÄLLT (inkl. TileRoomEditor.lua, TileRoomPersistence.lua)
├── LoadRoom.lua          # ENTFÄLLT (inkl. LoadRoomGrid.lua — Open-Punkt aus Spec 002 wird hier geschlossen)
└── PulpGameIO*.lua       # ENTFÄLLT (4 Dateien; Deprecation aus Spec 001 T026 wird eingelöst)

arc42/                    # Kap. 5, 6, 8, 10, 12 + AD-014/015/016/019 im Umsetzungsschnitt
```

**Structure Decision**: `EditorRoom` als Neuaufbau (Room-Muster: init/entered/update/inputHandler), weil der bestehende TileRoom untrennbar mit Pulp-Arbeitsraum, Offscreen-Skalierung, Tile-Picker und EditMode-Automat verwoben ist — alle vier Konzepte entfallen laut Spec. ZoomRoom/PixelRoom bleiben als Dateien erhalten und werden auf 16×16-Parameter und den `imageData`-Commit-Pfad umgestellt (ihre Slot-/Grid-Logik ist auflösungsagnostisch). Die Entfernung der Altmodule (TileRoom*, LoadRoom*, PulpGameIO*) ist der Abschluss dieses Features und schließt den Open-Punkt aus Spec 002.

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht: EditorRoom, umgebaute Zoomräume, entfallene Module), Kap. 6 (Laufzeitszenarien 6.2–6.4 neu: Malen, Frame-Wechsel, Zoomkette, Autosave), Kap. 8 (8.1 Input-Semantik neu, 8.2/8.2.1 duales Auflösungskonzept entfernen, 8.4 Tile-Lifecycle auf imageData), Kap. 10 (QS-03a/QS-12 obsolet, neue Szenarien Frame-Integrität), Kap. 12 (Glossar-Ist) — Evidenz: Feature-Branch-Diff.
- **ADRs**: AD-016 und AD-019 auf "umgesetzt"; AD-014 (EditMode/B-Long-Press) und AD-015 (duale Auflösung) als "abgelöst durch AD-019/AD-016" markieren; AD-002-Konsequenz (Tile-Picker) aktualisieren. Kein neuer ADR nötig — alle Entscheidungen sind bereits als AD-016..AD-020 dokumentiert.
- **Risiko-/Schulden-Review**: Mit Umsetzung entfallen R-11 und T-09 (duales Koordinatenmodell) sowie QS-03a — in `arc42/11-risiken-und-technische-schulden.md` austragen/aktualisieren. Neu zu beobachten: Speicherwachstum der Imagetable bei intensivem Detail-Malen über 12 Frames (an R-13 anhängen, Messpunkt in quickstart.md). N/A: Sicherheitsarchitektur (lokale Editorfunktion ohne Netzwerk/schutzbedürftige Daten).
- **Offen (Open)**: Exakte Crank-Rastung (4 Ticks/Umdrehung = 90°) auf Hardware verifizieren — Owner: Projektinhaber, Follow-up: quickstart.md Hardware-Szenario, Re-Evaluation: erster Geräte-Test vor Release 0.3.0.
