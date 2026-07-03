# Research: Start- und Auswahlscreen

**Feature**: 002-start-selection-screen | **Date**: 2026-07-03

Alle Unbekannten aufgelöst; SDK-Fähigkeiten gegen die lokale SDK-Dokumentation (`inside_playdate/`) verifiziert.

## R1: Rasterdarstellung und endloses Scrollen

- **Decision**: `playdate.ui.gridview.new(cellW, cellH)` mit `setNumberOfColumns(3)` und Zeilenanzahl `⌈(anzahlBilder + 1) / 3⌉` (inkl. "Neues Bild"-Eintrag). Sichtfenster 3×3 durch Zellgröße ≈ 133×80 im 400×240-Frame; Navigation setzt die Selektion um und ruft `scrollToCell(...)`/`scrollCellToCenter(...)`, wodurch das Raster zeilenweise nachscrollt (FR-006). `changeRowOnColumnWrap = false` verhindert ungewollte Zeilensprünge beim horizontalen Navigieren.
- **Rationale**: gridview kapselt Scrolling, Selektion und Zell-Rendering (`drawCell`-Override) — exakt der SDK-first-Weg (Quelle: `7.32 UI Components.md`); GameRoom nutzt gridview bereits, das Bedienmuster bleibt konsistent.
- **Alternatives considered**: Eigene Scroll-/Paging-Logik wie in LoadRoomGrid (verworfen: dupliziert gridview-Funktionalität, Constitution I); seitenweises Blättern statt Scrollen (verworfen: Konzept fordert "scrollt der komplette GridView eins weiter").

## R2: Kreisförmige Maskierung der Thumbnails (unskalierter Ausschnitt)

- **Decision**: Pro Bild wird einmalig ein Zell-Thumbnail erzeugt: neues Image in Kreisgröße (⌀ ≈ 72 px), `pushContext` → `preview.pdi` so versetzt zeichnen, dass die Bildmitte in der Zellmitte liegt (unskaliert, Clarification "Ausschnitt") → `popContext`; anschließend `image:setMaskImage(kreisMaske)` mit einer weißen Kreisscheibe auf schwarzem Grund (Masken-Semantik: schwarz = transparent, Quelle: `7.20 Graphics.md` "Image-Masken"). Der Kreisrand wird in `drawCell` per `drawCircleInRect` darübergezeichnet; Selektion = dickerer Ring (Muster aus dem gridview-Beispiel der SDK-Doku).
- **Rationale**: Vorberechnete maskierte Images machen `drawCell` zu einem reinen `image:draw` — wichtig, weil drawCell bei jedem Redraw für alle sichtbaren Zellen läuft (SC-002, Risiko R-13). Maske statt Stencil, weil die Maske am Image klebt und nicht bei jedem Draw als globaler Zustand gesetzt/zurückgesetzt werden muss.
- **Alternatives considered**: `setStencilImage` pro drawCell (verworfen: globaler Zeichenzustand, fehleranfällig bei Overlays, Neuberechnung pro Frame); Skalieren des Previews auf Kreisgröße (verworfen durch Clarification — Ausschnitt in Originalgröße); `setClipRect` (verworfen: nur rechteckig).

## R3: Thumbnail-Cache und Invalidierung

- **Decision**: Cache-Tabelle `thumbCache[id] → maskiertes Image`, lazy befüllt beim ersten drawCell-Bedarf; vollständige Invalidierung bei `entered()` des SelectionRoom sowie gezielt nach Neu/Kopieren/Löschen. Fehlt `getPreviewImage(id)` (nil), wird ein statischer Platzhalter-Kreis (Dither-Füllung + "?" ) gecacht (FR-011).
- **Rationale**: Previews ändern sich nur durch Editor-Saves oder Verwaltungsaktionen — beide führen durch `entered()`/Menü-Callbacks, daher reicht grobe Invalidierung (Constitution IV: keine feingranulare Cache-Verwaltung).
- **Alternatives considered**: Kein Cache (verworfen: Maskieren + readImage pro Redraw × 9 Zellen); persistenter Thumbnail-Export als eigene PDI-Datei (verworfen: zusätzliches Format/Dateien ohne Bedarf, Spec 001 Contract bleibt unverändert).

## R4: Systemmenü-Belegung und Rückweg

- **Decision**: Die drei verfügbaren Slots (SDK-Limit: "maximum of three custom menu items", Quelle: `7.5 Interacting with the system menu.md`) werden mit "new image", "copy image", "delete image" belegt (`removeAllMenuItems()` bei Room-Eintritt, Neuaufbau pro Room — bestehendes Muster). Der Rückweg SelectionRoom → TitleRoom liegt auf der B-Taste.
- **Rationale**: Das Menü-Limit ist eine harte SDK-Randbedingung; die drei Verwaltungsaktionen (FR-009) füllen es exakt. B als Rückweg folgt dem etablierten App-Muster "B = zurück/Modifier" (arc42 8.1).
- **Alternatives considered**: "Zurück" als Menüeintrag (verworfen: verdrängt eine Pflichtaktion aus FR-009); Löschen/Kopieren in ein Untermenü/Dialog verlagern (verworfen: SDK kennt keine Untermenüs).

## R5: Bestätigungsdialog Löschen (Clarification)

- **Decision**: Einfaches Overlay im SelectionRoom-Update (kein eigener Room): abgedunkelter Hintergrund (Dither-Pattern), zentriertes Panel mit Bildname, "(A) delete / (B) cancel"; eigener Eingabezustand `confirmingDelete`, der D-Pad/Menü-Navigation blockiert (Edge Case "konkurrierende Eingaben"). A ruft `ImageStore.deleteImage(id)`, invalidiert Cache, passt Selektion an; B schließt nur das Overlay.
- **Rationale**: Das SDK bietet keine Dialog-Komponente — Komposition aus Zeichenprimitiven ist die minimale, begründete Eigenleistung (Constitution I, dokumentiert im plan.md Constitution Check). Ein Zustandsflag im Room ist einfacher als ein eigener Room-Wechsel für einen Zwei-Tasten-Dialog (Constitution IV).
- **Alternatives considered**: Eigener "DialogRoom" (verworfen: Room-Wechsel-Overhead und Input-Handler-Tausch für einen trivialen Dialog); Timer-basiertes "Halten zum Löschen" (verworfen: schlechter entdeckbar, kein etabliertes Muster im Projekt).

## R6: Namensvergabe Neu/Kopieren (Clarification Spec 001/002)

- **Decision**: "Neu erstellen" öffnet `playdate.keyboard` (Flow inkl. pending-Mechanismus aus dem bisherigen GameRoom übernehmen); bei `keyboard.hide` mit leerem/abgebrochenem Text wird nichts angelegt (Edge-Case-Muster besteht). Ergebnis geht an `ImageStore.createImage(name)`; bei `"name-taken"` zeigt der Room einen Hinweis und öffnet die Tastatur erneut mit Suffix-Vorschlag. "Kopieren" ruft `ImageStore.copyImage(id)` ohne Tastatur (Auto-Suffix laut Spec-Annahme).
- **Rationale**: Wiederverwendung des erprobten Keyboard-Flows (Constitution IV); Kollisionslogik liegt im ImageStore-Contract (FR-013 Spec 001), die UI reagiert nur auf den Fehlercode.
- **Alternatives considered**: Auto-Namen ohne Tastatur (durch Clarification verworfen); Tastatur auch beim Kopieren (verworfen: Spec-Annahme legt Auto-Suffix fest, weniger Eingabeschritte).

## R7: Startscreen-Hintergrund und Sortierquelle

- **Decision**: TitleRoom ruft `ImageStore.getLastEditedPreview()`; bei nil bleibt der bisherige Bayer-Dither-Hintergrund. Die Panels/Texte (FR-001) werden unverändert darübergelegt; die Version kommt weiterhin aus `playdate.metadata` (dazu `Source/pdxinfo` auf `version=0.3.0` heben). Sortierung des Rasters (FR-013: lastEdited absteigend) kommt fertig aus `ImageStore.listImages()` — der Room sortiert nicht selbst.
- **Rationale**: Fallback-Kette und Sortierung liegen im Datenmodul (eine Quelle, Contract C-01); TitleRoom bleibt rein darstellend. Metadaten-basierte Versionsanzeige besteht bereits (getMetadataRows) und erfüllt FR-001 ohne Hardcoding.
- **Alternatives considered**: Version hart im Code (verworfen: pdxinfo ist die kanonische Quelle); Preview-Vollbild mit Abdunklung per drawFaded (nicht nötig — weiße Panels sichern Lesbarkeit, Akzeptanzszenario "Texte bleiben lesbar").
