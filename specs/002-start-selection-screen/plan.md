# Implementation Plan: Start- und Auswahlscreen

**Branch**: `feature/0.3` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-start-selection-screen/spec.md`

## Summary

Der Startscreen (TitleRoom) zeigt künftig das zuletzt bearbeitete Bild als Hintergrund und die v0.3.0-Texte. Ein neuer `SelectionRoom` ersetzt GameRoom und LoadRoom als einzigen Auswahlscreen: ein 3×3-Raster aus Kreisen (SDK-`gridview`, 3 Spalten, zeilenweises Scrollen) mit kreisförmig maskierten, unskalierten Thumbnail-Ausschnitten aus den `preview.pdi`-Dateien von Spec 001. Systemmenü (exakt 3 SDK-Slots) bietet Neu/Kopieren/Löschen; Löschen mit selbst gezeichnetem Bestätigungsdialog; Neu/Kopieren nutzen die Bildschirmtastatur bzw. Auto-Suffix über die `ImageStore`-API. Auswahl führt direkt in den Editor (Anbindung final in Spec 003).

## Technical Context

**Language/Version**: Lua (Playdate SDK Lua-Runtime, aktuelles SDK)

**Primary Dependencies**: Playdate SDK CoreLibs (`playdate.ui.gridview`, `playdate.graphics` image/masking/stencil, `playdate.keyboard`, `playdate.getSystemMenu()`, `playdate.timer`); `ImageStore`-API aus Spec 001 (contracts/storage-format.md)

**Storage**: Nur lesend/verwaltend über `ImageStore` (Index, Previews); keine eigenen Dateiformate

**Testing**: Manuelle Simulator-Szenarien in [quickstart.md](quickstart.md) (kein automatisiertes Test-Setup, arc42 R-05)

**Target Platform**: Playdate (Device + Simulator), 400×240, 1-Bit

**Project Type**: Single project (Lua-App unter `Source/`)

**Performance Goals**: Raster-Navigation und Scrollen ohne wahrnehmbare Verzögerung; Thumbnails werden gecacht statt pro `drawCell` neu maskiert (SC-002/SC-003)

**Constraints**: Constitution I (SDK-first: gridview/Masken/Keyboard statt Eigenbau), IV (Einfachheit); Systemmenü-Limit: max. 3 eigene Einträge (SDK-Vorgabe) — deckt genau Neu/Kopieren/Löschen; Rückweg zum Startscreen daher über B-Taste; kein Undo

**Scale/Scope**: Unbegrenzte Bildanzahl, flüssig getestet bis ≥ 30 Einträge (SC-002); 2 geänderte Rooms (TitleRoom, neuer SelectionRoom), GameRoom/LoadRoom/LoadRoomGrid entfallen

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-first | Raster = `playdate.ui.gridview` (Scrolling, Selektion, drawCell); Kreismaskierung = SDK-Stencil/Maske (`setStencilImage`/`image:setMaskImage`); Namenseingabe = `playdate.keyboard`; Menü = `playdate.getSystemMenu()`. Einzige Eigenleistung: Bestätigungsdialog-Overlay (SDK bietet keine Dialog-Komponente) — aus SDK-Primitiven komponiert, research.md R4. | PASS |
| II. Native Formate & PDI | Keine neuen Formate; konsumiert ausschließlich `ImageStore`-Contract (PDI-Previews, Index). | PASS |
| III. arc42-Pflege | Umsetzungsschnitt aktualisiert arc42 Kap. 5 (Bausteine: SelectionRoom statt GameRoom/LoadRoom), Kap. 6 (Startszenario verkürzt), Kap. 8 (Navigationskonzept) und setzt AD-018 auf "umgesetzt". Als Task einzuplanen. | PASS (geplant) |
| IV. Einfachheit | Ein neuer Room ersetzt zwei bestehende plus Grid-Helfer; bewährte Muster (needsRedraw, pending-Mechanismus, Keyboard-Flow aus GameRoom) werden übernommen; Thumbnail-Cache ist die einzige neue Optimierung und direkt durch SC-002 begründet. | PASS |

**Post-Design Re-Check (nach Phase 1)**: PASS — Design führt keine SDK-fremden Komponenten ein; der Dialog bleibt ein einfaches Overlay im Room-Update-Muster; Complexity Tracking leer.

## Project Structure

### Documentation (this feature)

```text
specs/002-start-selection-screen/
├── plan.md              # Diese Datei
├── research.md          # Phase 0: SDK-Entscheidungen (gridview, Maskierung, Menü-Limit, Dialog)
├── data-model.md        # Phase 1: UI-Zustandsmodell (Rasterfenster, Cursor, Dialog, Cache)
├── quickstart.md        # Phase 1: Validierungsszenarien (Simulator)
├── contracts/
│   └── selection-ui.md  # Phase 1: Room-Schnittstellen + Interaktions-Contract
└── tasks.md             # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
Source/
├── TitleRoom.lua        # GEÄNDERT: Hintergrund = letztes Bild (ImageStore.getLastEditedPreview),
│                        #   Texte gemäß FR-001 (aus playdate.metadata), Fallback Dither-Muster
├── SelectionRoom.lua    # NEU: 3×3-Kreisraster (gridview), Thumbnail-Cache, Systemmenü-Aktionen,
│                        #   Bestätigungsdialog, Keyboard-Namensflow, Leerzustand
├── GameRoom.lua         # ENTFÄLLT (durch SelectionRoom ersetzt; Entfernung in diesem Schnitt)
├── LoadRoom.lua         # ENTFÄLLT (Rooms-Ebene abgeschafft; Entfernung nach Editor-Anbindung Spec 003)
├── LoadRoomGrid.lua     # ENTFÄLLT (wie LoadRoom)
├── main.lua             # GEÄNDERT: Room-Verdrahtung Title → Selection → Editor;
│                        #   Übergangsstub bis Spec 003 den neuen Editor liefert
└── pdxinfo              # GEÄNDERT: version=0.3.0 (FR-001 zeigt Metadaten-Version)

arc42/                   # Kap. 5, 6, 8 + AD-018 im Umsetzungsschnitt aktualisieren
```

**Structure Decision**: Single project, flache `Source/`-Struktur. `SelectionRoom` ist ein eigenständiger Room nach bestehendem Muster (init/update/entered/inputHandler); auf einen separaten Grid-Helfer (Analogie LoadRoomGrid) wird verzichtet, weil `gridview` Scrolling und Selektion bereits kapselt (Constitution I/IV). GameRoom wird in diesem Schnitt entfernt; LoadRoom/LoadRoomGrid erst mit Spec 003, da der bestehende TileRoom bis dahin über den alten Pfad erreichbar bleiben muss (kein toter Zwischenzustand im Feature-Branch).

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht: SelectionRoom, Wegfall GameRoom/LoadRoom/LoadRoomGrid), Kap. 6 (Laufzeitszenario 6.1 verkürzt auf Title→Selection→Editor), Kap. 8 (8.1 Navigationskonzept ohne Rooms-Ebene) — Evidenz: Diff im Feature-Branch.
- **ADRs**: AD-018 (flache Bilder, 3×3-Kreisraster) bei Umsetzung auf "umgesetzt" setzen; SDK-Einsatzentscheidungen (gridview, Stencil-Maskierung, Menü-Limit-Konsequenz "B = zurück") als Konsequenz-Ergänzung in AD-020. Kein neuer ADR nötig.
- **Risiko-/Schulden-Review**: R-13 (Ladezeit Auswahlscreen bei vielen Bildern) wird durch Thumbnail-Cache + Messszenario in quickstart.md adressiert; Ergebnis dort protokollieren. N/A: Sicherheitsarchitektur (lokale UI-Navigation, keine schutzbedürftigen Daten).
- **Offen (Open)**: Endgültiger Entfernzeitpunkt von LoadRoom/LoadRoomGrid — Owner: Projektinhaber, Follow-up: tasks.md von Spec 003, Re-Evaluation: bei Editor-Anbindung.
