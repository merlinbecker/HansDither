# 5. Bausteinsicht

## 5.1 Whitebox Gesamtsystem

Das Gesamtsystem besteht aus einer Room-Orchestrierung mit drei Editierstufen und einem nativen Persistenzpfad: TitleRoom -> SelectionRoom -> EditorRoom <-> ZoomRoom <-> PixelRoom; Speichern und Laden laufen ueber ImageStore/ImageStoreCodec (PDI-Tilemap + Positions-JSON, AD-017).

```mermaid
graph LR
    Title["TitleRoom\n(Splash)"] -->|A| Selection["SelectionRoom\n(Hub, 3x3-Auswahl)"]
    Selection -->|"A: Bild oeffnen / neu"| Editor["EditorRoom\n(25x15 Tiles)"]
    Editor <-->|"B + Crank"| Zoom["ZoomRoom\n(24x24 Raster)"]
    Zoom <-->|"B + Crank"| Pixel["PixelRoom\n(16x16 Pixel)"]
    Selection -.->|"new / copy / delete"| Store[("ImageStore + Codec\nsaves/…")]
    Editor -.->|"Load / Save\n(RoomOperation)"| Store
    Title -.->|"Preview lesen"| Store
```

Die Navigation ist bewusst gerichtet: Der TitleRoom ist eine Einbahnstrasse (nur Splash), der SelectionRoom ist die Basis-Ebene — B fuehrt dort nicht zurueck. Zurueck aus dem Editor geht es ausschliesslich ueber "save + exit" (Systemmenue); innerhalb der Zoomkette navigiert B+Crank in beide Richtungen.

### Enthaltene Bausteine

| Baustein | Verantwortung |
|---|---|
| main.lua | Initialisierung, Room-Verdrahtung, zentrales playdate.update, Terminate-Hook (Commit-Kette der Zoomstufen + Save des offenen Bildes); seit Spec 006 zusaetzlich gameWillPause-Hook (setzt/entfernt das System-Pause-Menuebild ueber EditorRoom:buildPauseMenuImage()). |
| TitleRoom | Einstieg/Startbildschirm; fuehrt zum SelectionRoom. |
| SelectionRoom | Bild-Auswahlscreen (3x3-Raster mit maskierten Thumbnails, endloses Scrollen); Anlage/Kopie/Loeschen ueber Systemmenue; setzt EditorRoom:setImage(id) und wechselt direkt in den Editor (AD-018). Seit Spec 006: der aktuell selektierte Eintrag zeigt zusaetzlich einen vollflaechigen, animierten Hintergrund (Lazy-Load der vollen Bilddaten, verwirft Ladevorgaenge bei schnellem Selektionswechsel) mit Muster-Stoereffekt; alle anderen Eintraege bleiben unveraendert statische Kreis-Thumbnails. |
| EditorRoom | Haupteditor: 25x15-Raster aus 16x16-Tiles auf nativen 400x240 via SDK-tilemap (AD-016). Cursor (D-Pad, SDK-keyRepeatTimer), A = Zeichnen/Toggle, B = Pipette, Crank = Frame-Verwaltung (max. 12, Rotation; seit Spec 006 erst nach voller 360°-Umdrehung statt 90°-Rasterung), B+Crank = Zoomtrigger, Systemmenue (save + exit, reset frame [ersetzt seit Spec 006 "delete frame", AD-032], show grid), Dedup-Commit-Pfad applyTileEdits. Seit Spec 006 zusaetzlich: Inaktivitaets-gesteuerte, cursor-abgewandte Frame-Positions-Bauchbinde und buildPauseMenuImage() (Tile-Uebersicht + Metadaten fuer das System-Pause-Menuebild). |
| ZoomRoom | Mittlere Zoomstufe: 3x3-Tile-Kontext als 24x24-Malraster, eine Zelle = 2x2 native Pixel; Commit geaenderter Slots an EditorRoom:applyTileEdits; "All Similar" schreibt in-place in die Imagetable. Seit Spec 006: unbearbeitete Zellen zeigen die vier echten Quellpixel als Subpixel-Quadranten statt einer einfarbigen Stichprobe. |
| PixelRoom | Innerste Zoomstufe: ein Tile mit echten 16x16 Pixeln; Menueaktionen All Similar und Invert; Rueckgabe an ZoomRoom. |
| ImageStore | Bildverwaltung: Index (saves/index), Anlage/Kopie/Loeschen, Preview-Zugriff. |
| ImageStoreCodec | Coroutine-basierte Save-/Load-Operationen: PDI-Sheet (deduplizierte Tiles) + frames.json (Positionen je Frame), FNV-1a-hashTile, Slicing zur Laufzeit-Imagetable inkl. hashIndex. |
| loadingBar | Einheitliches Overlay fuer Lade-/Speicherfortschritt (Titel, Phasen-Detail, Fehlerstatus). |
| RoomOperation | Gemeinsame Coroutine-Orchestrierung fuer room-lokale Langlaeufer; reicht Phasen-Yields ans Overlay und das Coroutine-Ergebnis an onComplete durch. |
| Bauchbinde | Wiederverwendbare UI-Komponente fuer Hinweisbaender (Frame-Anzeige "Frame n/m", Fehlerstatus). |
| PencilCursor | Cursor-Overlay fuer alle Editierstufen. |
| tests/headless_tests.lua | SDK-freie Regressionstests (normaler Lua-Interpreter, strikte Playdate-Mocks); fangen insbesondere die Fehlerklasse "nicht existierende SDK-API" vor dem Simulator-Lauf ab. |
| Tools/Importer (index.html, app.js) | Historisches Browser-Tool fuer PNG-Import in Pulp-JSON; mit dem v0.3.0-Format nicht kompatibel (bewusst, R-14). |

### Entfallene Bausteine (v0.2 -> v0.3.0)

| Entfallen | Ersatz |
|---|---|
| TileRoom, TileRoomEditor, TileRoomPersistence | EditorRoom (Neuaufbau ohne Pulp-Kopplung, Offscreen-Buffer, Tile-Picker und EditMode-Automat) |
| LoadRoom, LoadRoomGrid | SelectionRoom (AD-018) |
| PulpGameIO, PulpGameIOShared, PulpGameIOSave, PulpGameIOLoad | ImageStore/ImageStoreCodec (AD-017) |
| GameRoom | Durch SelectionRoom ersetzt (AD-018); Datei entfernt. |

### Wichtige Schnittstellen

- switchRoom(newRoom): room-uebergreifende Navigation inklusive Input-Handler-Wechsel.
- EditorRoom:setImage(id) / entered(): Kontextsetzung durch SelectionRoom; das Laden laeuft asynchron als RoomOperation beim Room-Eintritt.
- EditorRoom:applyTileEdits(edits): Ruecknahme geaenderter Zoom-Slots ueber den Dedup-Pfad (hashIndex + Pixelvergleich); schreibt nur den aktiven Frame.
- EditorRoom:getImageData(): Zugriff fuer den Terminate-Hook in main.lua.
- EditorRoom:buildPauseMenuImage(): liefert das 400x240-Menuebild fuer playdate.setMenuImage() (Spec 006); nil ohne geladenes imageData. Ausschliesslich aus main.lua:gameWillPause() aufgerufen.
- ZoomRoom:setFromEditorContext(ctx): Uebernahme des 3x3-Kontexts (Slots, 24x24-gridState, showGrid, imageData-Referenz).
- ZoomRoom:setNewTile(tile) / updateExistingTile(tile, idx): Rueckgabe aus PixelRoom (Standard- bzw. All-Similar-Pfad).
- ZoomRoom:commitForTerminate() / PixelRoom:commitForTerminate(): Commit ohne Room-Wechsel fuer den Terminate-Hook.
- ImageStoreCodec.newSaveOperation(imageData) / newLoadOperation(id): Coroutine-Fabriken fuer RoomOperation.
- RoomOperation:start()/resume(onError): generischer Ablauf fuer Coroutine + loadingBar-Lifecycle inkl. Fehlerpfad.

## 5.2 Ebene 2

### 5.2.1 Whitebox main.lua

Verantwortung:
- Imports aller Rooms und CoreLibs
- Verkabelung: TitleRoom -> SelectionRoom -> EditorRoom <-> ZoomRoom <-> PixelRoom
- Lebenszyklusverwaltung und Terminate-Hook

Interne Logik:
- currentRoom als Single-Point-of-Truth fuer Update und Input.
- Display-Scale ist auf 1 gesetzt; alle Rooms arbeiten nativ auf 400x240.
- Beim Raumwechsel werden Input-Handler ausgetauscht, danach entered() aufgerufen.
- gameWillTerminate(): aktive Zoomstufen committen zuerst (PixelRoom -> ZoomRoom -> EditorRoom), dann wird das offene Bild synchron ueber ImageStoreCodec gespeichert.
- gameWillPause() (Spec 006, AD-031): ruft EditorRoom:buildPauseMenuImage() + playdate.setMenuImage() auf, wenn currentRoom EditorRoom/ZoomRoom/PixelRoom ist (alle drei referenzieren dasselbe imageData), sonst setMenuImage(nil) — laeuft nur beim tatsaechlichen Pausieren, nicht pro Frame.

### 5.2.2 Whitebox SelectionRoom

Verantwortung:
- Auswahl, Anlage (mit Keyboard-Namenseingabe), Kopie und Loeschen von Bildern.
- Vorschaubilder aus dem ImageStore laden und als maskierte Kreis-Thumbnails darstellen.
- Uebergang in den Editor via setImage(id) + switchRoom.

Interne Logik:
- Basis-Ebene der Navigation: B fuehrt nicht zum TitleRoom zurueck; B schliesst nur Loesch-Dialog bzw. Keyboard.
- Selektion laeuft ausschliesslich ueber setSelectedIndex() und ist damit immer mit der Gridview-Selektion (setSelection/scrollToCell) synchron; Navigation klemmt an vorhandenen Eintraegen.
- Namenseingabe ueber das SDK-Keyboard: Commit/Abbruch via keyboardWillHideCallback(ok); waehrend das Keyboard sichtbar ist, wird jeder Frame neu gezeichnet (Raster + Eingabezeile unten links).
- Thumbnail-Cache mit Negativ-Eintraegen (false = "Preview fehlt"), damit fehlende Previews nicht pro Frame von der Platte gelesen werden.
- Spec 006 (Titelscreen-Animation): setSelectedIndex() startet bei jedem Wechsel einen Lazy-Load der vollen Bilddaten (ImageStoreCodec.newLoadOperation + RoomOperation, stiller Overlay ohne sichtbare loadingBar) fuer den neu selektierten Eintrag; ein Ladevorgang fuer einen bereits verlassenen Eintrag wird durch reines Ueberschreiben der Referenz nicht mehr resumed (kein Cancel-Callback noetig, reiner Lesevorgang). Nach Abschluss zeichnet update() ein Tilemap-basiertes 400x240-Vollbild plus einen zeitlich wechselnden Muster-Overlay (gfx.setPattern-Phasenwechsel) VOR dem Gridview; drawCell() laesst die Zelle des betroffenen Eintrags frei, alle anderen Zellen bleiben unveraendert.

### 5.2.3 Whitebox EditorRoom

Verantwortung:
- Haupt-Arbeitsflaeche: 25x15-Tilemap auf voller Displayflaeche, Cursor, Grid-Overlay.
- Eingabesemantik gemaess AD-019 (siehe 8.1): A zeichnet/toggelt, B pipettiert, Crank verwaltet Frames, B+Crank zoomt.
- Frame-Verwaltung mit Kopie-Semantik, harter 12er-Grenze und beidseitiger Rotation; "delete frame" via Systemmenue (letzter Frame gesperrt).
- Autosave: "save + exit" startet die Save-Operation und wechselt nach Erfolg zum SelectionRoom; Fehler zeigen einen Status, der Editor bleibt bedienbar.

Besonders relevante interne Teile:
- tilemap:setTiles(frames[currentFrame], 25) als einziger Frame-Wechsel-Pfad (keine Bildkopien im Update-Pfad).
- appendTileImage() laesst die Imagetable beim Malen wachsen (mit Neuaufbau-Fallback) und haelt den hashIndex konsistent.
- Eingaben sind waehrend laufender Save-/Load-Operationen blockiert (inkl. Menueaktionen).
- Spec 006 (Crank-Volldrehung): pro update() wird GENAU EINE Crank-Lese-API verwendet — getCrankChange() als signierter Grad-Akkumulator (crankAccumDegrees) ohne B, unveraendert getCrankTicks(4) fuer die B+Crank-Zoomkette; ein Frame-Wechsel loest erst bei ±360° netto aus, Teildrehungen/Richtungswechsel heben sich im Akkumulator von selbst auf.
- Spec 006 (Bauchbinde): lastActivityMs wird bei jeder Eingabe (D-Pad, A, B, beide Crank-Pfade) aktualisiert; draw() zeigt die Frame-Positions-Bauchbinde nur, wenn seit der letzten Eingabe < 5s vergangen sind, auf der dem Cursor gegenueberliegenden Bildschirmhaelfte. Ein Sichtbarkeits-Uebergang wird in update() per Zeitvergleich erkannt und loest gezielt genau einen Redraw aus (analog zum bestehenden statusMessage-Timeout-Muster) — sonst wuerde die Bauchbinde bei reiner Inaktivitaet nie tatsaechlich verschwinden, da draw() nur bei needsRedraw==true laeuft.
- Spec 006 (Reset Frame, AD-032): resetCurrentFrameToPrevious() kopiert alle 375 Tile-Indizes elementweise vom Vorgaenger-Frame; no-op auf Frame 1. Ausgeloest ueber den Systemmenuepunkt "reset frame", der "delete frame" ersetzt (deleteCurrentFrame() bleibt im Code, hat aber keinen Menue-Aufrufer mehr).
- Spec 006 (Pause-Ansicht): buildPauseMenuImage() zaehlt unterschiedliche Tile-Indizes durch Iteration ueber alle frames[*] (NICHT imagetable:getLength(), das koennte nicht mehr referenzierte Alt-Eintraege mitzaehlen), zeichnet bis zu 120 Vorschauen im 12x10-Raster (bei mehr: Truncation, Gesamtzahl bleibt korrekt) sowie Gesamtzahl/Frame-Anzahl, ausschliesslich im linken 200px-Bereich (rechte Haelfte vom System-Menue ueberdeckt).

### 5.2.4 Whitebox ZoomRoom

Verantwortung:
- 3x3-Tile-Kontext als 24x24-Malraster darstellen (Zelle = 2x2 native Pixel, Anzeige 10 px/Zelle, 240x240 zentriert).
- Slot-Mapping inkl. out-of-bounds-Behandlung (Randslots nicht editierbar).
- Aenderungen nur bei Differenz als Edit-Liste an EditorRoom:applyTileEdits zurueckgeben.
- showGrid-Status aus dem EditorRoom uebernehmen (gestrichelte Zellgrenzen).

Interne Logik:
- gridState (24x24, boolesch) plus baselineGrid als Dekodier-Snapshot; Nutzeraenderungen = Abweichungen von der Baseline.
- buildWorkingImage() brennt nur geaenderte Zellen als 2x2-Bloecke ins Basisbild und erhaelt damit feinere Pixel-Details aus dem PixelRoom.
- "All Similar" aus dem PixelRoom schreibt das Tile in-place in die Imagetable (wirkt auf alle Verwendungen ueber alle Frames, FR-013-Ausnahme) und fuehrt den hashIndex nach.
- Spec 006 (Subpixel-Rendering): drawGrid() zeichnet fuer Zellen mit gridState[r][c] == baselineGrid[r][c] (unbearbeitet) die vier echten Quellpixel des zugehoerigen 2x2-Blocks einzeln als 5x5-Quadranten statt einer einfarbigen 10x10-Flaeche; bearbeitete Zellen bleiben unveraendert flaechig (Editier-Semantik selbst unangetastet).

### 5.2.5 Whitebox PixelRoom

Verantwortung:
- 16x16-Pixelbearbeitung eines ausgewaehlten Tiles (Anzeige 14 px/Zelle, 224x224 zentriert).
- Rueckgabe entweder als bearbeitetes Tile (Dedup beim Commit) oder in-place-Aenderung (All Similar).

Interne Logik:
- gridState als boolesches Pixelraster; Menueaktionen All Similar (Checkmark) und Invert.
- B+Crank rueckwaerts uebergibt an ZoomRoom; vorwaerts ist an der innersten Stufe ein No-op.

### 5.2.6 Whitebox ImageStore / ImageStoreCodec

Verantwortung:
- ImageStore: Indexdatei, Bildverwaltung (create/copy/delete/list), Preview-Zugriff.
- ImageStoreCodec: phasenweises Speichern (Dedup, Sheet, Frames, Bilddaten, Preview, Index) und Laden (Frames lesen, Sheet lesen, Slicing, Validierung) als Coroutinen.

Interne Logik:
- Ablage je Bild unter saves/<id>/: sheet.pdi (deduplizierte 16x16-Tiles), frames.json (375 Indizes je Frame), preview.pdi.
- FNV-1a-hashTile als gemeinsame Dedup-Grundlage von Codec und Editor-Commit-Pfad.
- Laden baut die Laufzeit-Imagetable samt hashIndex auf; Frame-Daten werden defensiv validiert (Fallback auf Weiss-Tile).

### 5.2.7 Whitebox Tools/Importer (historisch)

- Browser-Tool fuer den PNG-Import ins Pulp-JSON-Format (v0.2). Mit dem v0.3.0-Speicherformat nicht kompatibel; eine Anpassung ist ein spaeteres Vorhaben (R-14). Das Tool bleibt offline/exportbasiert und schreibt nie in bestehende Dateien.

## 5.3 Ebene 3 (fokussiert)

### 5.3.1 Zoom-Commit-Substruktur

- Input: 3x3-Slot-Kontext (frameIndexPos, originalIndex, originalImage) + gridState/baselineGrid + ggf. editierte Tiles aus PixelRoom.
- Verarbeitung: Aenderungserkennung (Zell-Diff bzw. editedImage) -> Arbeitsbild bauen -> Pixelvergleich gegen Original (Z-03) -> Edit-Liste.
- Output: EditorRoom:applyTileEdits dedupliziert (hashIndex + Pixelvergleich) oder haengt neue Tiles an und schreibt frames[currentFrame].

### 5.3.2 Persistenz-Substruktur im Codec

- Input: imageData (id, name, imagetable, frames, hashIndex)
- Verarbeitung: Sheet komponieren -> frames.json aufbauen -> Dateien schreiben -> Preview aus Frame 1 rendern -> Index aktualisieren (letzte Phase, C-06)
- Output: saves/<id>/{sheet.pdi, frames.json, preview.pdi} + aktualisierter Index

---

## 5.4 Backend-Service (Hans Dither Sync)

### 5.4.1 Whitebox Backend-Service

**Verantwortung:**
- Bereitstellung einer Web-API für Synchronisation von Hans-Dither-Projekten zwischen Playdate-Geräten und Web-UI
- Authentifizierung via UID (Playdate-Geräte-ID) und 4-stelliger PIN
- Speicherung von PDI- und JSON-Dateien im Dateisystem
- On-demand PNG-Rendering aus PDI + Tilemap-JSON

**Bausteine:**

| Baustein | Verantwortung | Technologie |
|---|---|---|
| `public/index.php` | Einstiegspunkt: UID-Eingabe, Pairing, Login, Images-Liste | PHP 8.x |
| `public/upload.php` | Upload-Handler für PDI + JSON-Dateien | PHP 8.x |
| `public/download.php` | Download-Handler für PDI/JSON/PNG-Dateien | PHP 8.x |
| `includes/config.php` | Konfiguration: DB-Zugang, Pfade, Konstanten | PHP 8.x |
| `includes/database.php` | MySQL-Datenbankverbindung mit Prepared Statements; seit Spec 007 auch Transaktions-Wrapper (`beginTransaction()`/`commit()`/`rollback()`) für den race-sicheren Upload-Zähl-Check (ADR-033) | MySQLi |
| `includes/auth.php` | PIN-Authentifizierung, bcrypt-Hashing, Rate-Limiting, Session-Management | PHP 8.x |
| `includes/validation.php` | Dateivalidierung: PDI (Magic Bytes + vollständiges Parsing via `pdi_parser.php`), JSON (Syntax + seit Spec 007 Struktur-Schema via `validateFramesJsonSchema()`, ADR-034); Dateigrößen-Limit seit Spec 007 auf 300 KB gesenkt | PHP 8.x |
| `includes/upload_handler.php` | Datei-Speicherung, UUID-Generierung, DB-Einträge; seit Spec 007 zusätzlich pro-UID-Obergrenze von 12 Bildern via Transaktion + Row-Lock (ADR-033) | PHP 8.x |
| `includes/renderer.php` | PNG-Rendering aus PDI + JSON via GD-Bibliothek | PHP GD |
| `MySQL-Datenbank` | Speicherung von UID→PIN-Hash, Images-Metadaten, Sessions | MySQL 8.x |
| `Dateisystem` | Speicherung von PDI/JSON/PNG-Dateien unter `/uploads/{UID}/` | all-inkl.com Hosting |

### 5.4.2 Ebene 2: Backend-Architektur

```mermaid
graph TD
    Client[Playdate/Browser] -->|HTTP/HTTPS| Backend[Backend-Service]
    Backend -->|1. UID + PIN| Auth[Authentifizierung]
    Backend -->|2. PDI + JSON| Upload[Upload-Handler]
    Backend -->|3. Dateivalidierung| Validation[validation.php]
    Backend -->|4. Speicherung| DB[(MySQL)]
    Backend -->|5. Dateisystem| FS[/uploads/{UID}/]
    Backend -->|6. PNG-Rendering| Renderer[renderer.php]
    Backend -->|7. Response| Client
```

**Interne Logik:**
- **Authentifizierungsfluss:** UID-Eingabe → (UID existiert?) → Login oder Pairing → Session-Token (UUID, 30 Min Gültigkeit)
- **Upload-Fluss:** Token-Prüfung → Dateivalidierung (PDI: Magic Bytes + vollständiges Parsing, JSON: json_decode + Struktur-Schema seit Spec 007) → Dateigröße ≤ 300 KB (Spec 007) → Transaktion mit Row-Lock auf `users` + Zähl-Check ≤ 12 Bilder/UID bei Neuanlage (Spec 007, ADR-033) → UUID-Generierung → Datei-Speicherung → DB-Eintrag → Commit. Ein am Limit abgelehnter Upload (403) wird auf dem Playdate-Gerät (`Source/SyncService.lua`) als eigene, von anderen Fehlern unterscheidbare Meldung angezeigt (Spec 007, research.md R6) statt im generischen Fehlerpfad zu verschwinden.
- **Download-Fluss:** Token-Prüfung → Berechtigung (Image.uid == Session.uid) → Datei-Auslieferung (PNG on-demand generieren)
- **Rate-Limiting:** 3 Fehlversuche → 5 Min Sperre (locked_until Timestamp in DB)

### 5.4.3 Ebene 3: Datenbank-Schema

**Tabellen:**
- `users`: UID (PK), pin_hash (bcrypt), failed_attempts, locked_until, created_at
- `images`: id (UUID PK), uid (FK), pdi_path, json_path, png_path, uploaded_at
- `sessions`: token (UUID PK), uid (FK), expires_at, created_at

**Beziehungen:**
- 1 User → N Images (CASCADE auf DELETE)
- 1 User → N Sessions (CASCADE auf DELETE)
- 1 Image → 1 PDI-Datei + 1 JSON-Datei + 0..1 PNG-Datei
