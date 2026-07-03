# Quickstart: Validierung Editor-Umbau

**Feature**: 003-editor-animation-zoom | **Date**: 2026-07-03

Manuelle Szenarien im Playdate Simulator; Crank-Rastung zusätzlich auf Hardware (Open-Punkt aus plan.md). Referenzen: [contracts/editor-room.md](contracts/editor-room.md), [data-model.md](data-model.md). Voraussetzung: Spec 001 + Spec 002 implementiert.

## Voraussetzungen

- Build `pdc Source HansDither.pdx`, Start im Simulator; Crank-Simulation per Maus/Tastenkürzel.
- Mindestens ein Bild über den Auswahlscreen angelegt.

## Szenario 1: Malen im Editor (SC-001, FR-001..FR-005, US1)

1. Bild im Auswahlscreen wählen → Editor öffnet direkt (25×15-Raster, volle Fläche).
2. Ohne Auswahl A drücken (Toggle Schwarz/Weiß), Cursor bewegen, mehrfach togglen.
3. Ein gemustertes Tile per B aufnehmen (Pipette), an anderer Stelle mit A zeichnen; erneutes A auf derselben Zelle → Weiß.
4. Crank ohne B drehen.
5. **Erwartet**: ≤ 2 Eingaben von Auswahl bis erstem Tile (SC-001); Pipette/Zeichnen/Toggle gemäß Contract; Crank ohne B wählt KEIN Tile (Frames wechseln stattdessen — siehe Szenario 2); B-Pipette auf Weiß wählt ab (Toggle-Modus).

## Szenario 2: Frames per Crank (SC-002, FR-006..FR-008a, US2)

1. In Frame 1 malen; Crank +1 Rastung (90°) → Frame 2 (Kopie); dort ändern; Rastung zurück.
2. **Erwartet**: Frame 1 unverändert, Frame 2 = Kopie + Änderung; Bauchbinde zeigt "Frame n/m".
3. Vorwärts drehen bis 12 Frames, weiter drehen.
4. **Erwartet**: Kein 13. Frame — Rotation zu Frame 1; rückwärts auf Frame 1 → Sprung zum letzten Frame.
5. Schnell mehrere Rastungen am Stück drehen.
6. **Erwartet**: Frames der Reihe nach; jede Kopie basiert auf ihrem direkten Vorgänger (keine Sprünge).
7. Menü → "delete frame" auf einem mittleren Frame; danach bei nur einem verbliebenen Frame erneut versuchen.
8. **Erwartet**: Nachrückender Frame wird aktiv, m sinkt; letzter verbliebener Frame nicht löschbar.

## Szenario 3: Drei Zoomstufen (SC-003, FR-009..FR-013, FR-015, US3)

1. Cursor auf ein Tile, B halten + Crank vor → Zoom Room (24×24-Raster über 3×3 Tiles).
2. Muster malen; ein Malstrich setzt sichtbar 2×2 native Pixel.
3. B halten + Crank weiter vor → Pixel Room (16×16); einzelne Pixel setzen (1×1); Invert und "All Similar" testen.
4. Stufenweise zurückzoomen (B+Crank rückwärts) bis in den Editor; speichern, Bild neu laden.
5. **Erwartet**: Alle Änderungen sichtbar und exakt positioniert über alle Stufen und über Save/Load (SC-003, 0 Koordinatenabweichung); nur tatsächlich geänderte Tiles wurden neu angelegt (Dedup, Z-03); Grid-Linien folgen dem "show grid"-Status; Cursor in Bildecke → out-of-bounds-Slots nicht editierbar.
6. In Frame 2 zoomen und malen, zurück, Frame 1 prüfen.
7. **Erwartet**: Zoom-Änderungen betreffen nur den aktiven Frame (FR-013) — außer explizitem "All Similar" (in-place, alle Verwendungen).

## Szenario 4: Autosave beim Verlassen (FR-014, US4)

1. In mehreren Frames malen, Menü → "save + exit".
2. **Erwartet**: loadingBar-Phasen sichtbar; danach Auswahlscreen mit aktualisiertem Thumbnail; erneutes Öffnen stellt alle Frames wieder her.
3. Im Editor malen, Simulator "Exit Game" (gameWillTerminate); App neu starten.
4. **Erwartet**: Letzter Stand gespeichert (auch aus Zoomstufen heraus: Slot-Commit vor Save, Contract E-03).

## Szenario 5: Performance und Speicher (SC-004, Risiko-Beobachtung)

1. 12 Frames mit intensivem Detail-Malen (Pixel Room) füllen; Cursorbewegung, Malen und Frame-Wechsel in schneller Folge.
2. **Erwartet**: Keine wahrnehmbare Verzögerung, keine verlorenen Eingaben (SC-004).
3. Nach "save + exit": Größe von `saves/<id>/sheet.pdi` und `frames.json` notieren.
4. **Befund hier protokollieren**; bei auffälligem Imagetable-Wachstum Vermerk an R-13 in `arc42/11-risiken-und-technische-schulden.md`.

## Szenario 6: Hardware-Check Crank (Open-Punkt aus plan.md)

1. Auf dem Gerät: Frame-Wechsel-Rastung (90°/getCrankTicks(4)) und B+Crank-Zoomtrigger erfühlen.
2. **Erwartet**: Rastung fühlt sich wie die frühere Tile-Picker-Rastung an (Spec-Vorgabe); kein versehentliches Frame-Anlegen beim Zoomen. Befund hier protokollieren; bei Bedarf Tick-Wert als Konstante justieren und in AD-019 nachtragen.

## Szenario 7: SC-005 — Lernbarkeit

1. Einem v0.2.0-kundigen Nutzer das Gerät geben, ohne Erklärung: Animation mit 3 Frames + Detail-Edit in allen drei Zoomstufen erstellen lassen.
2. **Erwartet**: Erfolgreich innerhalb von 5 Minuten; Bauchbinden-Hinweise (Frame n/m) reichen als Orientierung.

---

## Validierung

### Durchgeführte Tests (Implementierungsstand: 2026-07-03)

| Szenario | Status | Datum | Befund |
|---|---|---|---|
| **Szenario 1** (Malen) | ⏳ pending | - | Grundlegende Editor-Funktionalität implementiert, Test im Simulator ausstehend |
| **Szenario 2** (Frames) | ⏳ pending | - | Frame-Wechsel + Crank-Handling implementiert, Test ausstehend |
| **Szenario 3** (Zoom) | ⏳ pending | - | Grundgerüst da, Zoom-Räume noch nicht angepasst |
| **Szenario 4** (Autosave) | ⏳ pending | - | Save + Exit implementiert, Test ausstehend |
| **Szenario 5** (Performance) | ⏳ pending | - | Grundgerüst implementiert, Performance-Test ausstehend |
| **Szenario 6** (Hardware) | ⏳ pending | - | Crank-Handling implementiert, Hardware-Test ausstehend |
| **Szenario 7** (Lernbarkeit) | ⏳ pending | - | Benutzeroberfläche implementiert, Usability-Test ausstehend |

### Implementierungsstatus

- ✅ **Phase 1 (Setup)**: EditorRoom.lua Grundgerüst erstellt
- ✅ **Phase 2 (Foundational)**: Load-Workflow, Rendering, Verdrahtung implementiert
- ✅ **US1 (P1, Malen)**: Cursor-Bewegung, A/B-Semantik, Pipette implementiert
- ✅ **US4 (P1, Autosave)**: Save + Exit, Terminate-Hook implementiert
- ✅ **US2 (P2, Frames)**: Frame-Wechsel, Crank-Handling implementiert
- ⏳ **US3 (P2, Zoom)**: Grundgerüst da, Zoom-Räume Anpassung ausstehend
- ⏳ **Phase 7 (Polish)**: Altmodule entfernen, Messungen, arc42-Evidenz ausstehend
