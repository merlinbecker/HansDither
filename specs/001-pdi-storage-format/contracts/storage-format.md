# Contract: ImageStore — Speicherformat und Lua-API

**Feature**: 001-pdi-storage-format | **Date**: 2026-07-03

Dieser Contract bindet zwei Seiten: das **Dateiformat auf Disk** (stabil, versioniert) und die **Lua-API**, die Spec 002 (Auswahl-/Startscreen) und Spec 003 (Editor) konsumieren.

## 1. Dateiformat-Contract

Verbindliche Struktur siehe [data-model.md](../data-model.md). Zusicherungen:

- **C-01**: `saves/index.json` ist die einzige Quelle für Bildliste, Sortierung (`lastEdited`) und `lastEditedId`. Konsumenten scannen keine Verzeichnisse.
- **C-02**: `frames[f]` ist ohne Transformation gültige Eingabe für `playdate.graphics.tilemap:setTiles(data, 25)`.
- **C-03**: Tile-Indizes sind 1-basiert; Index 1 = Voll-Weiß, Index 2 = Voll-Schwarz (immer vorhanden).
- **C-04**: `sheet.pdi` und `preview.pdi` sind mit `playdate.datastore.readImage()` ladbare PDI-Dateien.
- **C-05**: `version`-Felder ermöglichen spätere Formatevolution; Leser lehnen unbekannte Major-Versionen defensiv ab (Bild gilt als beschädigt, kein Absturz).
- **C-06**: Schreibreihenfolge beim Save: Inhaltsdateien vor `index.json`. Ein Index-Eintrag verweist nie auf noch nicht geschriebene Inhalte.

## 2. Lua-API-Contract (`Source/ImageStore.lua`, `Source/ImageStoreCodec.lua`)

### ImageStore (synchron, kleine Datenmengen)

```lua
ImageStore.getIndex() -> { version, lastEditedId, images = { {id, name, frameCount, lastEdited}, ... } }
-- Lädt/cached den Index; legt bei Erststart einen leeren Index an.

ImageStore.listImages() -> array  -- images absteigend nach lastEdited sortiert

ImageStore.createImage(name) -> id | nil, errorReason
-- Sanitisiert name zu id; bei Kollision: nil + "name-taken" (Aufrufer bietet Suffix an).
-- Legt Ordner, frames.json (1 leerer Frame), sheet.pdi (Tiles 1+2), preview.pdi an; aktualisiert Index.

ImageStore.copyImage(id) -> newId | nil, errorReason
-- Kopiert alle Dateien; Name erhält automatisches Suffix; aktualisiert Index.

ImageStore.deleteImage(id) -> success
-- Entfernt Ordner + Index-Eintrag; bestimmt lastEditedId neu.

ImageStore.getPreviewImage(id) -> playdate.graphics.image | nil
-- nil bei fehlender/defekter preview.pdi (Aufrufer zeigt Platzhalter, FR-011 Spec 002).

ImageStore.getLastEditedPreview() -> image | nil  -- Startscreen-Hintergrund
```

### ImageStoreCodec (Coroutine-Phasen für RoomOperation)

```lua
ImageStoreCodec.newSaveOperation(imageData) -> RoomOperation-kompatible Coroutine
-- imageData: { id, name, imagetable, frames, hashIndex } (Laufzeitrepräsentation, siehe data-model.md)
-- Phasen (loadingBar-Labels): "Dedup" → "Sheet" → "Frames" → "Bilddaten" → "Preview" → "Index"
-- Garantien: FR-001..FR-004, FR-008; C-06; Fehler beenden die Operation sichtbar, Index bleibt konsistent.

ImageStoreCodec.newLoadOperation(id) -> RoomOperation-kompatible Coroutine
-- Ergebnis: imageData wie oben (imagetable aus Sheet gesliced, hashIndex aufgebaut).
-- Garantien: FR-006 (Round-Trip), FR-010 (defensive Validierung: fehlende Dateien/ungültige
-- Indizes → Fehlerstatus bzw. Weiß-Tile-Fallback, kein Absturz).
```

### Fehlersemantik

| Fall | Verhalten |
|---|---|
| Namenskollision bei create | `nil, "name-taken"` — keine Teilanlage |
| Schreibfehler während Save | Operation endet mit Fehlerstatus im Overlay; Index unverändert (C-06) |
| frames.json oder sheet.pdi fehlt beim Load | Load-Operation endet mit Fehlerstatus; Bild bleibt gelistet, öffnet nicht |
| Frame-Index > tileCount | Ersatz durch Index 1 (Weiß), Laden wird fortgesetzt |
| index.json fehlt/defekt | Neuer leerer Index; vorhandene Bildordner bleiben auf Disk erhalten (kein Löschen) |

## 3. Konsumenten

| Konsument | Nutzt |
|---|---|
| Spec 002 (Start-/Auswahlscreen) | `listImages`, `createImage`, `copyImage`, `deleteImage`, `getPreviewImage`, `getLastEditedPreview` |
| Spec 003 (Editor) | `newSaveOperation` (beim Verlassen/Terminate), `newLoadOperation` (beim Öffnen), Laufzeitrepräsentation `imageData` |
| main.lua | Terminate-Hook → Save des offenen Bildes |
