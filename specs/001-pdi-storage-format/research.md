# Research: Natives PDI-Speicherformat

**Feature**: 001-pdi-storage-format | **Date**: 2026-07-03

Alle Technical-Context-Unbekannten sind aufgelöst; SDK-Fähigkeiten wurden gegen die lokale SDK-Dokumentation (`inside_playdate/`) verifiziert.

## R1: PDI zur Laufzeit schreiben und lesen

- **Decision**: `playdate.datastore.writeImage(image, path)` schreibt ein `playdate.graphics.image` als PDI in den Datenordner; `playdate.datastore.readImage(path)` lädt es wieder. Pfade mit Ordneranteil (z. B. `saves/<id>/sheet`) werden unterstützt; ohne Ordneranteil landet die Datei im `images/`-Ordner.
- **Rationale**: Direkte SDK-Funktionen (Quelle: `inside_playdate/7.18 Files.md`); `readImage()` liest genau das PDI-Format, das `writeImage()` erzeugt — kein eigener Encoder nötig (Constitution I/II).
- **Alternatives considered**: Eigenes Binärformat über `playdate.file` (verworfen: eigener Encoder/Decoder, nicht SDK-first); PNG/GIF-Export (verworfen: `readImage()` liest nur PDI; GIF hat Transparenz-Einschränkungen).

## R2: Ablage der Tile-Positionen je Frame — Evaluation der JSON-Alternative (offene Konzeptfrage, Risiko R-12)

- **Decision**: JSON über `playdate.datastore.write(table, "saves/<id>/frames")` / `datastore.read(...)`. Struktur: ein flaches 1-basiertes Index-Array pro Frame (375 Einträge, Reihenfolge links→rechts, oben→unten), direkt kompatibel mit `tilemap:setTiles(data, width)` und `tilemap:getTiles()`.
- **Rationale**:
  - Größenabschätzung worst case: 12 Frames × 375 Indizes ≈ 4 500 Zahlen ≈ 15–25 KB kompaktes JSON — unkritisch für Dateisystem und Parser; das bisherige Pulp-Dokument war deutlich größer.
  - `datastore.write/read` ist die vom SDK vorgesehene Tabellen-Serialisierung (Quelle: `4.7 Saving game state.md`, `7.18 Files.md`); menschenlesbar und debugbar im Simulator-Datenordner.
  - Das Array-Format entspricht 1:1 dem `tilemap:setTiles`-Eingabeformat → Laden ohne Transformationsschicht.
- **Alternatives considered**:
  - *Ein PDI pro Frame (gerendertes Vollbild)*: verworfen — verliert Tile-Struktur und Dedup, 12×(400×240)-Bilder sind größer und machen Frame-Editing beim Laden unmöglich (Tiles müssten re-gesliced und re-gehasht werden).
  - *Binärpacken (string.pack in Datei via playdate.file)*: verworfen — ~9 KB Ersparnis rechtfertigen keinen eigenen Binär-Codec (Constitution I und IV); schlechter debugbar.
  - *`json.encodeToFile` direkt*: gleichwertig zu `datastore.write` (datastore nutzt JSON); `datastore` gewählt, weil es Dateiendung/Pfadkonvention kapselt und im Projekt etabliert ist.
- **Konsequenz**: R-12 wird herabgestuft; Messpunkt (Dateigröße + Ladezeit bei 12 Frames) ist als Validierung in quickstart.md verankert. Ergebnis wird in arc42 AD-017 nachgetragen.

## R3: Tile-Sammlung — ein Sheet-PDI statt vieler Einzeldateien

- **Decision**: Alle deduplizierten Tiles eines Bildes werden in ein einzelnes Sheet-Image gezeichnet (Rasteranordnung, 25 Tiles pro Zeile, Höhe wächst mit ⌈n/25⌉×16 px) und als **eine** PDI-Datei gespeichert. Beim Laden wird das Sheet mit `datastore.readImage` geladen und per Offscreen-Draw in eine zur Laufzeit erzeugte Imagetable (`gfx.imagetable.new(count)` + `setImage(n, tileImage)`) zerlegt.
- **Rationale**: Eine Datei pro Bild minimiert Dateisystem-Overhead und Ladezeit (ein `readImage` statt n); `imagetable.new(count)`/`setImage` ist der dokumentierte SDK-Weg für zur Laufzeit befüllte Imagetables (Quelle: `7.20.12 Image Table.md`). Vorkompilierte `-table-16-16`-Matrix-Imagetables sind nur zur Compilezeit möglich und daher für Runtime-Saves ungeeignet.
- **Alternatives considered**: Ein PDI pro Tile (`saves/<id>/tiles/001` …) — verworfen: bis zu hunderte kleine Dateien, langsameres Listing/Laden, Lösch-/Kopieroperationen komplexer. Sheet als eine Zeile n×16 — verworfen: sehr breite Bilder bei vielen Tiles; Rasteranordnung hält die Bilddimensionen kompakt.

## R4: Tile-Deduplizierung via FNV-1a

- **Decision**: FNV-1a-32-Hash über die 256 Pixelwerte (0/1) eines 16×16-Tiles; Hash-Map Hash→Tile-Index beim Speichern und beim Editor-Commit. Kollisionsabsicherung durch Pixelvergleich bei Hash-Treffer.
- **Rationale**: Das SDK bietet keine Hashfunktion — dies ist die einzige begründete Eigenleistung (Constitution I, dokumentiert in AD-020-Konsequenz). FNV-1a ist im Projekt etabliert (TileRoomPersistence, Tools/Importer) und für 256-Byte-Eingaben schnell genug; Wiederverwendung statt Neuerfindung (Constitution IV).
- **Alternatives considered**: Direkter Pixelvergleich gegen alle Tiles (O(n) Vergleiche pro Tile, bei 375 Tiles × 256 Pixel zu langsam im Save-Pfad); djb2/CRC32 (kein Vorteil, FNV-1a bereits referenzimplementiert im Repo).

## R5: Atomarität und Fehlerpfade beim Speichern (FR-010, Edge Case Schreibfehler)

- **Decision**: Save schreibt in Neu-Dateien und aktualisiert den Index zuletzt: (1) `frames.json` und `sheet.pdi` schreiben, (2) `preview.pdi` rendern/schreiben, (3) `saves/index.json` (Liste + lastEdited) aktualisieren. Jeder Schritt prüft das Ergebnis; bei Fehler bleibt der Index unangetastet und der Nutzer sieht den Fehlerstatus im loadingBar-Overlay (bestehendes Muster). Beim Laden gilt: fehlt eine der beiden Kerndateien oder ist ein Index außerhalb der Sheet-Länge, wird das Bild als beschädigt markiert (Platzhalter, kein Absturz) bzw. der Verweis auf ein leeres Tile aufgelöst (FR-010, Edge Cases der Spec).
- **Rationale**: `datastore`-Schreiboperationen sind pro Datei atomar genug für den Anwendungsfall; die Reihenfolge "Inhalt vor Index" stellt sicher, dass der Index nie auf halb geschriebene neue Zustände zeigt. Ein voller Transaktionsmechanismus (Temp+Rename für alle Dateien) wäre Zusatzkomplexität ohne nachgewiesenen Bedarf (Constitution IV); Temp+Rename via `playdate.file.rename` bleibt als Härtung möglich, falls die Simulator-Tests Teilschreiber zeigen.
- **Alternatives considered**: Vollständiges Temp-Verzeichnis + Umbenennen (aufgeschoben, siehe oben); Doppelhaltung Alt/Neu mit Generationszähler (verworfen: doppelter Speicherplatz, unnötig für Einzelnutzer-Editor).

## R6: Save/Load als kooperative Phasen (FR-011)

- **Decision**: `ImageStoreCodec.save(bild)` und `.load(id)` sind Coroutine-basierte Abläufe im bestehenden `RoomOperation`+`loadingBar`-Muster mit Phasen: Save = Hash/Dedup → Sheet-Komposition → frames.json → sheet.pdi → preview.pdi → Index; Load = frames.json lesen → sheet.pdi lesen → Imagetable-Slicing → Validierung.
- **Rationale**: Identisch zum dokumentierten Bestandskonzept (arc42 8.6, AD-009/AD-010) — Wiederverwendung statt neuem Async-Muster. Die blockierenden Einzelaufrufe (`writeImage`, `write`) bleiben als finale, markierte Phasen sichtbar.
- **Alternatives considered**: Synchrones Speichern in einem Frame (verworfen: verletzt SC-004 bei 12 Frames); Hintergrund-Autosave-Intervall (verworfen: Konzept definiert Speichern beim Verlassen/Terminate, Constitution IV).

## R7: Bild-Identität, Index und "zuletzt bearbeitet" (FR-007/FR-008/FR-013)

- **Decision**: Der vom Nutzer per Bildschirmtastatur vergebene Name wird zur Verzeichnis-ID sanitisiert (Kleinschreibung, erlaubt: a–z, 0–9, `-`; Leerzeichen→`-`); Anzeigename bleibt unverändert im Index. `saves/index.json` hält ein Array `{id, name, frameCount, lastEdited}` (absteigend sortierbar nach `lastEdited`, Unix-Sekunden via `playdate.getSecondsSinceEpoch()`) sowie `lastEditedId` für den Startscreen. Kollisionsprüfung: existiert die ID bereits, wird die Anlage abgelehnt bzw. ein numerisches Suffix angeboten (FR-013).
- **Rationale**: Verzeichnis pro Bild macht Löschen/Kopieren zu einfachen Datei-/Ordneroperationen über `playdate.file` (FR-009, atomar genug: Ordner löschen bzw. Dateien kopieren, Index zuletzt); ein zentraler Index vermeidet Verzeichnis-Scans beim App-Start und liefert Sortierung + Startscreen-Info aus einer Quelle.
- **Alternatives considered**: Verzeichnis-Listing statt Index (verworfen: lastEdited/Anzeigename müssten pro Bild geladen werden → n Datei-Reads beim Öffnen des Auswahlscreens); UUID-IDs (verworfen: Name ist laut Klärung der Identifikator, UUIDs erschweren Debugging im Datenordner).
