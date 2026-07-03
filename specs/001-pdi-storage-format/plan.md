# Implementation Plan: Natives PDI-Speicherformat

**Branch**: `feature/0.3` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-pdi-storage-format/spec.md`

## Summary

Das Pulp-JSON-Gesamtformat wird durch ein natives Speicherformat ersetzt: Pro Bild wird eine Tile-Sheet-Datei im PDI-Format (alle via FNV-1a-Hash deduplizierten 16×16-Tiles) plus eine JSON-Datei mit den Tile-Positionen je Animationsframe (max. 12) persistiert. Ein neues Modul `ImageStore` ersetzt die PulpGameIO*-Module vollständig und verwaltet eine flache, unbegrenzte Bildliste mit Index, Vorschaubildern und Zuletzt-bearbeitet-Markierung. Alle I/O-Pfade nutzen ausschließlich SDK-Funktionen (`playdate.datastore`, `playdate.graphics.imagetable/tilemap`); lange Läufe bleiben im bestehenden RoomOperation/loadingBar-Muster.

## Technical Context

**Language/Version**: Lua (Playdate SDK Lua-Runtime, aktuelles SDK)

**Primary Dependencies**: Playdate SDK CoreLibs (`playdate.datastore`, `playdate.graphics.image/imagetable/tilemap`, `playdate.file`, `json`); bestehende Projektbausteine `RoomOperation`, `loadingBar`

**Storage**: Playdate-Datenordner (`Disk/Data/<bundleID>` im Simulator): pro Bild `saves/<id>/sheet.pdi` (PDI via `datastore.writeImage`), `saves/<id>/frames.json` (via `datastore.write`), `saves/<id>/preview.pdi`; global `saves/index.json`

**Testing**: Manuelle Testmatrix im Playdate Simulator (Projekt hat kein automatisiertes Test-Setup, siehe arc42 R-05); Validierungsszenarien in [quickstart.md](quickstart.md)

**Target Platform**: Playdate (Device + Simulator), 400×240, 1-Bit

**Project Type**: Single project (Lua-App unter `Source/`)

**Performance Goals**: Save/Load eines maximalen Bildes (12 Frames, bis zu ~375 unterschiedliche Tiles) ohne sichtbaren Freeze > ~1 s am Stück (SC-004); kooperative Abarbeitung über Coroutine-Phasen

**Constraints**: Constitution I (SDK-first), II (native Formate/PDI, Hash-Dedup), IV (Einfachheit); kein Undo; keine Migration alter Pulp-Saves (geklärt); Terminate-Hook muss speichern

**Scale/Scope**: Unbegrenzte Bildanzahl (getestet bis ≥ 20/30, SC-003); 1–12 Frames × 375 Rasterpositionen; Tile-Sammlung theoretisch bis 12×375 Tiles, praktisch durch Dedup deutlich kleiner

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-first | Alle Persistenz-Primitiven sind SDK-Funktionen: `datastore.writeImage/readImage` (PDI), `datastore.write/read` (JSON-Tabellen), `imagetable.new(count)`+`setImage` (Tile-Sammlung im Speicher), `tilemap:setTiles` (Frame-Darstellung), `playdate.file` (Ordner/Listing/Rename). Einzige Eigenleistung: FNV-1a-Hash (SDK bietet keine Hashfunktion) — bereits im Projekt etabliert, Begründung in research.md R4. | PASS |
| II. Native Formate & PDI | Speicherformat = PDI-Sheet + Positions-JSON, Tiles hash-dedupliziert, 400×240/16×16. Pulp-JSON wird nicht mehr geschrieben (FR-012). | PASS |
| III. arc42-Pflege | Umsetzungsschnitt aktualisiert arc42 Kap. 3, 5, 6, 8 (Ist-Beschreibung Persistenz) und setzt AD-017 auf "umgesetzt"; Evaluationsergebnis der Positionsablage wird in AD-017 ergänzt. Als Task eingeplant. | PASS (geplant) |
| IV. Einfachheit | Ein neues Modul (`ImageStore`) ersetzt vier PulpGameIO*-Module; bestehende Muster (RoomOperation, loadingBar, FNV-1a) werden wiederverwendet; keine bildübergreifende Tile-Bibliothek. | PASS |

**Post-Design Re-Check (nach Phase 1)**: PASS — Datenmodell und Contracts führen keine SDK-fremden Formate oder Zusatzabstraktionen ein; Complexity Tracking bleibt leer.

## Project Structure

### Documentation (this feature)

```text
specs/001-pdi-storage-format/
├── plan.md              # Diese Datei
├── research.md          # Phase 0: Entscheidungen inkl. Evaluation Positionsablage
├── data-model.md        # Phase 1: Entitäten und Dateiformate
├── quickstart.md        # Phase 1: Validierungsszenarien (Simulator)
├── contracts/
│   └── storage-format.md  # Phase 1: Dateilayout- und JSON-Schema-Contract + Lua-API
└── tasks.md             # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
Source/
├── main.lua                 # bestehend: Terminate-Hook auf neuen Save-Pfad umstellen
├── ImageStore.lua           # NEU: Index, Anlegen/Kopieren/Löschen, Namens-Kollisionsprüfung
├── ImageStoreCodec.lua      # NEU: Sheet-Komposition/-Slicing, Hash-Dedup, Frames-JSON (Save/Load als Coroutine-Phasen)
├── RoomOperation.lua        # bestehend: unverändert wiederverwendet
├── loadingBar.lua           # bestehend: unverändert wiederverwendet
├── PulpGameIO.lua           # ENTFÄLLT (mit Abschluss von Spec 001–003)
├── PulpGameIOShared.lua     # ENTFÄLLT
├── PulpGameIOSave.lua       # ENTFÄLLT
├── PulpGameIOLoad.lua       # ENTFÄLLT
└── TileRoomPersistence.lua  # Quelle des FNV-1a-Musters; wird im Editor-Umbau (Spec 003) abgelöst

arc42/                       # Kap. 3, 5, 6, 8 + AD-017 im Umsetzungsschnitt aktualisieren
```

**Structure Decision**: Single project, bestehende flache `Source/`-Struktur bleibt. Zwei neue Module: `ImageStore` (Verwaltung/Index, synchron, kleine Datenmengen) und `ImageStoreCodec` (rechenintensive Sheet/Frames-Codierung als Coroutine-Phasen für RoomOperation). Die Trennung folgt dem etablierten Muster "Orchestrierung vs. Datenlogik" (arc42 8.7). Die Editor-Anbindung (wer ruft save/load auf) gehört zu Spec 003; die Auswahl-/Startscreen-Anbindung zu Spec 002.

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: Aktualisierung arc42 Kap. 3 (Kontext: Pulp-Interop entfällt), Kap. 5 (Bausteine: ImageStore/ImageStoreCodec statt PulpGameIO*), Kap. 6 (Laufzeitszenarien Save/Load neu), Kap. 8 (Persistenzkonzept) — im Umsetzungsschnitt dieses Features (Evidenz: Diff der arc42-Kapitel im Feature-Branch).
- **ADRs**: AD-017 (PDI + Positions-JSON) wird mit dem Evaluationsergebnis aus research.md R2 ergänzt und bei Umsetzung auf "umgesetzt" gesetzt. Kein weiterer ADR nötig (Modulschnitt folgt bestehendem AD-011-Muster).
- **Risiko-/Schulden-Review**: R-12 (JSON-Größe) wird durch research.md R2 bewertet und mit Messpunkt in quickstart.md abgesichert; R-14 (Interop-Verlust) bleibt akzeptiert. N/A: Sicherheitsarchitektur (lokales Offline-System ohne Netzwerk, keine personenbezogenen Daten).
