# Research: Editor-Umbau — 16×16-Tiles, Animation und Zoomstufen

**Feature**: 003-editor-animation-zoom | **Date**: 2026-07-03

Alle Unbekannten aufgelöst; SDK-Fähigkeiten gegen `inside_playdate/` und den Bestandscode verifiziert.

## R1: Editor-Rendering — natives Tilemap ohne Offscreen-Skalierung

- **Decision**: `playdate.graphics.tilemap` mit der Laufzeit-Imagetable aus `imageData` (Spec 001): `setImageTable(imagetable)`, `setSize(25, 15)`, Frame-Wechsel = `setTiles(frames[f], 25)`, Einzelmutation = `setTileAtPosition(x, y, index)`; Draw bei (0,0) auf voller 400×240-Fläche. Cursor (PencilCursor) und Bauchbinde zeichnen darüber.
- **Rationale**: 25×15×16px = exakt 400×240 — Daten- und Anzeigeauflösung fallen zusammen (AD-016); der bisherige 200×120-Offscreen-Buffer samt 2×-Skalierung entfällt ersatzlos. `setTiles` akzeptiert das persistierte Frame-Array unverändert (Spec-001-Contract C-02). Quelle: `7.20.13 Tilemap.md`.
- **Alternatives considered**: Sprite-basierte Zellen (verworfen: 375 Sprites ohne Nutzen, tilemap ist der dokumentierte Weg für Rasterflächen); Beibehalt des Offscreen-Musters (verworfen: doppelte Koordinatenebene war genau das Problem, R-11/T-09).

## R2: Crank-Rastung für Frames — getCrankTicks(4) wie der frühere Tile-Picker

- **Decision**: `playdate.getCrankTicks(4)` (4 Ticks pro Umdrehung = 90° pro Rastung), einmal pro Update gelesen (stateful, Quelle: `7.10 Crank.md` + bestehender Kommentar in `Source/TileRoom.lua`). Ohne gehaltenes B: +1 Tick = Frame vor (bei Bedarf als Kopie anlegen), −1 Tick = Frame zurück; mehrere Ticks pro Update werden sequenziell abgearbeitet (Edge Case "schnelles Drehen": jede neue Kopie basiert auf ihrem direkten Vorgänger).
- **Rationale**: Die Spec fordert "gleiche Rastung wie früher die Tile-Auswahl" — der Bestandscode nutzt dafür `getCrankTicks(4)`. Absolute Tick-Grenzen des SDK verhindern Drift. Hardware-Verifikation als Open-Punkt (plan.md).
- **Alternatives considered**: `getCrankChange()` mit eigener Schwellwertlogik (verworfen: eigener Rastungszustand, SDK bietet Ticks fertig); feinere Rastung z. B. 12/Umdrehung (verworfen: Spec bindet an bisherige Rastung).

## R3: Frame-Modell — Kopie-Semantik, Rotation, Löschen

- **Decision**: `frames` = Array von 375er-Index-Arrays (max. 12). Vorwärts auf letztem Frame: existieren < 12 → flache Array-Kopie (`table.move`/Schleife über 375 Zahlen) als neuer Frame; bei 12 → Rotation zu Frame 1. Rückwärts auf Frame 1 → letzter existierender Frame (Clarification). "Frame löschen" (Systemmenü): `table.remove(frames, f)`, nachrückender Frame wird aktiv, gesperrt beim letzten verbliebenen Frame (FR-008a). Frame-Anzeige "Frame n/m" über Bauchbinde bei jedem Wechsel.
- **Rationale**: Array-Kopien von 375 Zahlen sind billig (kein Bild-Kopieren — Tiles liegen dedupliziert in der Imagetable, Frames referenzieren nur). Rotation und Lösch-Semantik sind direkt aus Spec-Clarifications übernommen.
- **Alternatives considered**: Copy-on-Write-Frames (verworfen: Referenz-Aliasing zwischen Frames macht "in Frame 2 malen ohne Frame 1 zu ändern" fehleranfällig — explizite Kopie ist trivial und robust, Constitution IV); Tile-Bilder pro Frame kopieren (verworfen: verletzt Dedup-Modell).

## R4: A/B-Semantik und Wegfall von Tile-Picker/EditMode

- **Decision**: B (kurz) = Pipette: `activeTile = frames[f][cursorIdx]`; Pipette auf einer Weiß-Zelle (Index 1) setzt `activeTile = nil` (Abwahl → Toggle-Modus, Spec-Assumption). A: mit `activeTile` → Zelle setzen bzw. bei gleichem Index auf 1 (Weiß) zurück; ohne `activeTile` → Toggle 1↔2 (Basistiles Weiß/Schwarz, Spec-001-Contract C-03). Der B-Long-Press-Moduswechsel (AD-014) und der Crank-Tile-Picker entfallen ersatzlos; B-Halten dient nur noch als Zoom-Modifier.
- **Rationale**: Direkt aus Spec FR-003..FR-005 und Clarifications; die Prioritätsregel "Crank während B-Hold = Zoom" vereinfacht sich, weil kein Long-Press-Timer mehr konkurriert (QS-03a obsolet).
- **Alternatives considered**: activeTile-Abwahl über eigenen Button-Chord (verworfen: keine freien Tasten, Pipette-auf-Weiß ist entdeckbar und dokumentiert); Merken des activeTile pro Frame (verworfen: Spec-Edge-Case legt frame-unabhängige Auswahl fest).

## R5: Zoomkette — B+Crank als Stufenwechsel, Zoomräume parametrisch umgestellt

- **Decision**: Bestehender B+Crank-Trigger aus TileRoom (Tick-Akkumulation bei gehaltenem B) wird in den EditorRoom übernommen: vorwärts Editor→ZoomRoom→PixelRoom, rückwärts zurück (drei Stufen, FR-009). ZoomRoom behält sein 24×24-`gridState`-Raster, aber eine Zelle schreibt jetzt einen 2×2-Pixelblock in 16×16-Tiles (3×3-Slot-Mapping unverändert; Anzeige-Zellgröße 240/24 = 10 px). PixelRoom wird von 8×8 auf 16×16 Zellen parametrisiert (Anzeige ~14 px/Zelle, 224×224 zentriert). Commit beim Rauszoomen: geänderte Slots → `hashTile` → vorhandener Index aus `hashIndex` oder `imagetable:setImage(neuerIndex)` + Frame-Update nur im aktiven Frame (FR-012/FR-013).
- **Rationale**: 3 Tiles × 16 px = 48 px Kontext; 48/2 = 24 Rasterzellen — die bestehende 24×24-Logik passt exakt, nur die Schreibauflösung ändert sich (2×2 statt 1×1 im alten 8×8-Raum). "All Similar"/Invert/Grid-Sync bleiben funktional unverändert (FR-015); "All Similar" bearbeitet das Tile in der Imagetable in-place und wirkt damit — wie bisher dokumentiert — auf alle Verwendungen, auch über Frames hinweg (bewusst beibehalten, siehe Spec-Assumption "Funktionen bleiben gleich").
- **Alternatives considered**: ZoomRoom auf 48×48-Raster mit 1×1-Malen (verworfen: Spec definiert 24×24 mit 2×2-Blöcken als mittlere Stufe); vier Zoomstufen (verworfen: Spec fixiert genau drei).

## R6: Systemmenü-Belegung des EditorRoom (SDK-Limit 3 Slots)

- **Decision**: "save + exit" (Autosave via `ImageStoreCodec.newSaveOperation` + Rückkehr zum SelectionRoom), "delete frame" (mit FR-008a-Sperre beim letzten Frame), "show grid" (Checkmark-Item, Grid-Sync in die Zoomräume wie bisher). Verlassen ohne Speichern gibt es nicht (FR-014); `gameWillTerminate` speichert zusätzlich (Spec 001 FR-005).
- **Rationale**: Exakt drei benötigte Aktionen für drei verfügbare Slots (Quelle: `7.5 Interacting with the system menu.md`); "show grid" ist Bestandsfunktion der FR-015-Familie.
- **Alternatives considered**: "back" ohne Save (verworfen: widerspricht FR-014); Frame-Löschen per Tastenkombination (verworfen: destruktive Aktion gehört ins Menü, Muster aus Spec 002).

## R7: Autosave-Ablauf beim Verlassen

- **Decision**: "save + exit" startet eine RoomOperation mit `ImageStoreCodec.newSaveOperation(imageData)` (loadingBar-Phasen aus Spec 001), blockiert Eingaben während des Laufs und wechselt nach Erfolg zum SelectionRoom (dessen `entered()` lädt Previews neu — Spec-002-Contract S-02). Fehler: Overlay zeigt Fehlerstatus, Editor bleibt bedienbar (kein Datenverlust im Speicher).
- **Rationale**: Identisch zum dokumentierten "Save + Back"-Muster (arc42 6.4/AD-009/AD-010) auf neuer Codec-Basis — Wiederverwendung statt Neuentwurf.
- **Alternatives considered**: Speichern bei jedem Frame-Wechsel (verworfen: I/O im Malfluss, SC-004-Risiko); Dirty-Flag mit Nachfrage (verworfen: Autosave ist die geklärte Spec-Vorgabe, kein Verwerfen vorgesehen).
