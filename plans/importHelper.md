# Import-Helper fuer Pulp JSON + PNG

Stand: 2026-04-22

## 1. Ziel und Scope

Es wird ein lokales Web-Tool (HTML + JavaScript) erstellt, das aus einer Pulp-JSON-Datei und einer PNG-Datei einen neuen Room samt benoetigter Tiles erzeugt und das aktualisierte JSON exportiert.

Ablage:
- `Tools/Importer/`

Muss-Funktionen:
- Upload von 2 Dateien:
  - Pulp-JSON (komplettes Spiel)
  - PNG (Quellbild)
- Visualisierung:
  - Canvas A: Room-Ansicht (25x15 Tiles, 200x120 px logische Flaeche)
  - Canvas B: Tile-Palette entsprechend `editor.sortedTiles`
  - Navigation durch vorhandene Rooms
- Import-Pipeline fuer PNG:
  - Skalierung auf 200x120 mit Aspect-Ratio-Erhalt
  - Letterboxing/Pillarboxing mit Schwarz
  - Zerlegung in 8x8 Tiles
  - Dedupe ueber Hashvergleich analog Lua (`imageHash` / `findOrAppendImage`)
  - Anlegen eines neuen Rooms mit den resultierenden Tile-IDs
- Export:
  - Download des aktualisierten JSON

Nicht-Ziele (fuer ersten Schritt):
- Kein Undo/Redo
- Kein direkter Schreibzugriff auf Originaldateien
- Kein komplexer Tile-Kategorisierungseditor fuer `sortedTiles`

## 2. Architekturbezug (arc42)

Aus der Arc42-Doku abgeleitete Leitplanken:
- Trennung der Verantwortungen (vgl. `arc42/04-loesungsstrategie.md`, `arc42/05-bausteinsicht.md`):
  - Parsing/Validierung
  - Rendern
  - Import-Transformation
  - Export
- Persistenzintegritaet als oberstes Ziel (vgl. `arc42/10-qualitaetsanforderungen.md`, QS-01):
  - Keine inkonsistenten room/tile/frame Referenzen erzeugen
- Pulp-Kompatibilitaet (vgl. `arc42/03-kontextabgrenzung.md`, `arc42/09-architekturentscheidungen.md`):
  - Struktur erhalten, nur gezielt erweitern
  - `editor` Felder defensiv behandeln
- Risiken aus bestehender Architektur uebernehmen (vgl. `arc42/11-risiken-und-technische-schulden.md`):
  - R-01 Mappingfehler bei IDs
  - R-02 Formatinkompatibilitaet

## 3. Uebernahme aus Lua-Code (konkret)

Die JavaScript-Implementierung soll diese Lua-Logik spiegeln:

1. Hash-basierte Tile-Deduplizierung
- Quelle: `Source/TileRoom.lua`
- Funktionen: `imageHash(image)`, `findOrAppendImage(imagetable, image, hashCache)`
- Ansatz in JS:
  - FNV-1a (32-bit) ueber 8x8 Pixel
  - Hash fuer jedes extrahierte Tile berechnen
  - Bei vorhandenem Hash existierende Tile-ID verwenden
  - Sonst neues Frame+Tile anlegen

2. Datenkonsistenz rooms/tiles/frames
- Quelle: `Source/TileRoom.lua` + `Source/PulpGameIO.lua`
- Beim Anlegen neuer Tiles immer:
  - `frames[]` erweitern (id, data[64])
  - `tiles[]` erweitern (id, name, type, frames:[frameId])
- Neuer Room referenziert ausschliesslich gueltige Tile-IDs

3. Baseline-Annahmen
- Grid: 25x15
- Tilegroesse: 8x8
- Room-Pixelmasse: 200x120
- JSON nutzt numerische Tile-IDs in Room-Tiles (0-basiert)

## 4. Zielstruktur im Tool-Ordner

Geplante Dateien:
- `Tools/Importer/index.html`
- `Tools/Importer/style.css`
- `Tools/Importer/app.js`
- optional: `Tools/Importer/README.md` (Nutzung lokal)

Aufruf lokal:
- Direkt per Doppelklick auf `index.html` moeglich (kein Build notwendig)
- Optional besser via kleinem lokalen Server (nur fuer Browser-Sicherheit/Debugging)

## 5. Datenmodell-Strategie im Importer

Interne Runtime-Objekte in JS:
- `state.pulpJson`
- `state.currentRoomIndex`
- `state.roomRenderCache`
- `state.hashToTileId` (aus bestehenden Tiles aufgebaut)
- `state.tileIdToFrameData`

Hilfsfunktionen:
- `validatePulpJsonStructure(json)`
- `getNextId(collection)` fuer `rooms`, `tiles`, `frames`
- `frameDataFromImageData8x8(imageData)` -> Array[64] mit 0/1
- `hashTileBinary(tilePixels64)` -> fnv1a-hex
- `renderRoomToCanvas(room, tiles, frames, canvasCtx)`
- `renderSortedTilesToCanvas(sortedTiles, tiles, frames, canvasCtx)`

## 6. PNG-Import-Pipeline (Detail)

1. Datei einlesen
- PNG via `FileReader` -> `Image`
- Nach Laden in Offscreen-Canvas zeichnen

2. Aspect-ratio-konforme Anpassung auf 200x120
- Skalierungsfaktor `s = min(200/srcW, 120/srcH)`
- Zielgroesse `drawW = round(srcW*s)`, `drawH = round(srcH*s)`
- Schwarzer Hintergrund 200x120
- Zentriert zeichnen (`offsetX`, `offsetY`)

3. Binarisierung (1-bit)
- Aus RGBA je Pixel Luminanz bestimmen
- Schwellwert (z. B. 128) -> 0 (weiss) / 1 (schwarz)
- Alpha kann optional in Schwellenwert einbezogen werden (transparente Pixel als schwarz fuer Letterbox-Bereich bereits korrekt)

4. Tile-Slicing
- 25x15 Tiles iterieren
- Pro Tile 8x8 -> 64 Werte erzeugen

5. Dedupe + Anlage
- Hash pro 64er-Tile
- Wenn Hash in bestehendem Cache:
  - vorhandene Tile-ID in Room-Tileliste eintragen
- Sonst:
  - neue `frame.id` + `frame.data`
  - neues `tile.id` + `tile.frames=[frameId]`
  - Hash-Cache erweitern

6. Room anlegen
- `rooms.push({...})` mit neuem `id` und Name (z. B. `import_<timestamp>`)
- `tiles` Feld des Rooms mit 375 Tile-IDs fuellen
- Pflichtfelder (`song`, `exits`, `script`) defensiv setzen

7. Editor.sortedTiles aktualisieren
- Wenn `editor.sortedTiles` vorhanden:
  - neue Tile-IDs in erste Gruppe (`sortedTiles[0]`) anhaengen, doppelte vermeiden
- Wenn nicht vorhanden:
  - als `[[...alle tile ids...]]` initialisieren
- Bestehende Gruppen unveraendert lassen

## 7. UI-/UX-Konzept

Layout:
- Linke Spalte: Datei-Inputs + Controls
- Mitte: Room-Canvas + Room-Navigation (Prev/Next + Name/ID)
- Rechte Spalte: Tile-Canvas (`sortedTiles` Darstellung)
- Unten: Import-Status und Export-Button

Interaktionen:
- `JSON laden` aktiviert Room-Navigation
- `PNG laden` zeigt Vorschau-Info (Aufloesung, Skalierung)
- `Import starten` fuehrt Pipeline aus, rendert neuen Room sofort
- `Export JSON` erzeugt Download (`Blob`, `URL.createObjectURL`)

Fehlerfaelle:
- Ungueltiges JSON
- Fehlende Kernfelder (`rooms`, `tiles`, `frames`)
- Nicht-PNG oder defekte Bilddatei
- Import ohne beide Dateien

## 8. Teststrategie (manuell, erster Wurf)

Testfaelle:
1. JSON laden (gueltig) -> Rooms rendern korrekt
2. JSON laden (ungueltig) -> klare Fehlermeldung
3. PNG mit 200x120 -> keine Letterbox, korrekter Room
4. PNG mit anderer Ratio -> schwarze Raender korrekt
5. Import bei bereits vorhandenen gleichen Tiles -> keine Duplikate
6. Export -> Datei enthaelt neuen Room und referenzierte Tiles/Frames
7. Re-Import exportierter Datei -> weiterhin darstellbar

Akzeptanzkriterien:
- Room hat immer 375 Tile-Eintraege
- Jede verwendete Tile-ID existiert in `tiles[]`
- Jedes Tile referenziert vorhandenen Frame
- Neue Tiles sind in `editor.sortedTiles` sichtbar

## 9. Implementierungsreihenfolge

1. Projektstruktur in `Tools/Importer` anlegen
2. Grund-UI (Dateiinputs, zwei Canvases, Buttons, Status)
3. JSON Parser + Grundrenderer fuer bestehende Rooms
4. Tile-Renderer fuer `sortedTiles`
5. PNG Skalierung (200x120, Aspect Ratio, schwarze Balken)
6. Tile-Slicing + FNV-1a Dedupe
7. JSON-Mutation (neuer Room + neue tiles/frames + sortedTiles update)
8. Export-Funktion
9. Manuelle Testmatrix durchgehen und Korrekturen

## 10. Detaillierte Todo-Liste (Start)

### Phase A - Setup
- [ ] Ordner `Tools/Importer` erstellen
- [ ] `index.html` mit semantischer Grundstruktur anlegen
- [ ] `style.css` fuer responsives 3-Spalten-Layout anlegen
- [ ] `app.js` als zentrale Logikdatei einbinden
- [ ] Kleine lokale Nutzungsanleitung in Kommentar/README ergaenzen

### Phase B - JSON Laden und Rendern
- [ ] File-Input fuer JSON implementieren
- [ ] JSON Parsing mit Try/Catch und Fehlermeldungen
- [ ] Strukturvalidierung fuer `rooms`, `tiles`, `frames`
- [ ] Room-Navigation (Prev/Next) + Anzeige von Name/ID
- [ ] Room-Canvas Renderer (25x15, Tiles aus Frames zeichnen)
- [ ] Fallback-Rendering fuer fehlende Tile/Frame-Referenzen

### Phase C - sortedTiles Canvas
- [ ] `editor.sortedTiles` robust lesen (optional vorhanden)
- [ ] Tile-Palette-Canvas mit Gruppen-Visualisierung rendern
- [ ] Tile-ID-Labels optional einblendbar machen
- [ ] Graceful Fallback wenn `sortedTiles` fehlt

### Phase D - PNG Verarbeitung
- [ ] PNG File-Input implementieren
- [ ] Bild asynchron laden und Quellmasse anzeigen
- [ ] Offscreen-Canvas fuer Zielbild 200x120 aufbauen
- [ ] Aspect-ratio Skalierung + zentriertes Draw implementieren
- [ ] Schwarzes Padding fuer freie Flaechen sicherstellen
- [ ] Optionalen Threshold-Parameter (Default 128) vorbereiten

### Phase E - Tile Extraktion und Dedupe
- [ ] 200x120 Bild in 25x15 Tiles zu je 8x8 zerlegen
- [ ] Tile-Pixel in 64er-Array (0/1) transformieren
- [ ] FNV-1a Hashfunktion in JS implementieren
- [ ] Bestehenden Hash-Cache aus vorhandenen Tiles aufbauen
- [ ] Bei Treffer vorhandene Tile-ID verwenden
- [ ] Bei neuem Tile Frame+Tile anlegen und Hash-Cache erweitern

### Phase F - Room Anlage und JSON Mutation
- [ ] Neue Room-ID sicher vergeben (`max+1`)
- [ ] Room-Objekt mit Pflichtfeldern erstellen
- [ ] 375 Tile-IDs in Room schreiben
- [ ] Room in `rooms` einfuegen
- [ ] `editor.sortedTiles` mit neuen Tile-IDs erweitern
- [ ] `editor` defensiv initialisieren, falls Feld fehlt

### Phase G - Export und UX-Finish
- [ ] Export-Button aktivieren, sobald Import erfolgreich war
- [ ] JSON Download als `.json` implementieren
- [ ] Erfolg/Fehlerstatus klar im UI anzeigen
- [ ] Edge-Cases testen (leere Datei, grosses PNG, kaputte IDs)
- [ ] Kleine Qualitaetsrunde fuer Code-Lesbarkeit und Kommentare

### Phase H - Verifikation gegen Projektziele
- [ ] Persistenzintegritaet mit 2-3 Beispiel-Dateien pruefen
- [ ] Dedupe-Verhalten gegen Lua-Logik querchecken
- [ ] `sortedTiles` Darstellung visuell validieren
- [ ] Exportdatei gegen `pulp/pulpschema.json` stichprobenartig pruefen
- [ ] Kurzes Ergebnisprotokoll in `plans/importHelper.md` ergaenzen
