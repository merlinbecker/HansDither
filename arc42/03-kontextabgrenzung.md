# 3. Kontextabgrenzung

## 3.1 Fachlicher Kontext

Hans Dither ist primaer ein lokaler Pixel-Editor fuer Playdate. Externe
Interaktionen entstehen durch Benutzerbedienung, lokale Persistenz und —
optional — den Upload einzelner Bilder zu einem eigenen Web-Backend.

| Kommunikationspartner | Eingaben an das System | Ausgaben des Systems |
|---|---|---|
| Spieler / Kreative | D-Pad, A/B, Crank, Beschleunigungssensor (Schuettelgeste), Bildschirmtastatur | UI-Rueckmeldung, Tile-/Pixel-Rendering, Bauchbinden-Hinweise, Save/Load-Fortschritt |
| Playdate Datastore / Dateisystem | Pfade + serialisierte Objekte/Bilder | Persistente Bilder (`saves/<id>/`: `sheet.pdi`, `frames.json` v1.1, `preview.pdi`) und der Index `saves/index` |
| Hans Dither Sync-Backend (`www.hans-dither.de`) | HTTPS-POST `/pair`, `/login`, `/upload` (UID + lokal erzeugte PIN, Multipart mit PDI + `frames.json`); QR-Code verweist auf `/?uid=<UID>` | Beim Sync ein Bild-Datensatz im Backend + serverseitig gerenderte PNG/GIF-Artefakte, abrufbar ueber die Ansichts-URL |
| Lokaler Importer-Anwender (Dev-Werkzeug, eingefroren) | PNG im Browser-Tool `Tools/Importer/` | Pulp-kompatible JSON — historisch, nicht Teil des v0.3.0-Laufzeitpfads (siehe Kap. 11, R-14) |

Auth-Details des Backends (PIN-Hashing, Rate-Limiting, Dateivalidierung)
sind in Kap. 8.10 und den ADRs 025/026/027/033 beschrieben und werden hier
nicht wiederholt.

## 3.2 Technischer Kontext

| Kontextsystem | Schnittstelle/Technik | Zweck |
|---|---|---|
| Playdate Runtime | Lua + Playdate SDK CoreLibs (graphics, ui, timer, keyboard, object, qrcode) | Rendering, Input, Navigation, Menues |
| Beschleunigungssensor | `playdate.startAccelerometer` / `readAccelerometer` | Rohdaten fuer die eigene Schuettel-Erkennung (`ShakeDetector`, kein SDK-Shake-Ereignis, AD-044) |
| Dateisystem / Datastore | `playdate.file` + `playdate.datastore` (`write`/`read`, `writeImage`/`readImage`) | Lesen/Schreiben von Bildern und Vorschaubildern; Endungen vergibt das SDK |
| Netzwerk (nur beim Sync) | `playdate.network.http` (Playdate OS 2.7+), Port 443, TLS | Pairing / Login / Multipart-Upload zum Sync-Backend |
| Assets im Bundle | `images/*` (Launcher, Basistiles) | Startgrafik und Basis-Tiles 1..3 |
| Lokaler Browser (Importer, eingefroren) | HTML/CSS/JS unter `Tools/Importer/` | Offline-PNG-Import in Pulp-JSON — separates Werkzeug, keine Runtime-Kopplung |

Anzeige und Daten fallen zusammen: Runtime **und** Persistenz arbeiten nativ
auf 400x240 mit 16x16-Tiles (25x15-Raster). Der fruehere duale
Pulp-Arbeitsraum (200x120 / 8x8) und das Anzeige-Scaling sind mit AD-016
entfallen.

## 3.3 Mapping fachlich -> technisch

| Fachlicher Vorgang | Technische Umsetzung |
|---|---|
| Bild auswaehlen / neu / kopieren / loeschen | `SelectionRoom` (3x3-Kreisraster, `playdate.ui.gridview`, endloses Scrollen) + `ImageStore` + Index `saves/index` |
| Zeichnen im Tile-Canvas | `EditorRoom`: `playdate.graphics.tilemap` (25x15), Cursor-Overlay, Pipette, Tile-Picker; schreibt nur die aktive Ebene |
| Ebene / Frame wechseln | `EditorRoom`: B halten + D-Pad (AD-042); Frames als Kopie-Semantik, max. 12 |
| Frames anordnen / loeschen | `FrameManagementView` (B halten + Kurbel rueckwaerts) |
| Zwischenzoom fuer 3x3-Tilekontext | `ZoomRoom`: 24x24-Zellraster, Slot-Mapping, Batch-Commit an `EditorRoom:applyTileEdits` |
| Pixelgenaue Bearbeitung + 90°-Rotation | `PixelRoom`: 16x16-`gridview`, 3-Zustands-Malen (Tinte/weiss/transparent), Kurbel-Rotation |
| Riskante Operation zuruecknehmen | Schuettelgeste -> `ShakeDetector` -> `UndoPrompt` -> `EditorRoom:undoLast` (Spec 011) |
| Speichern | `EditorRoom` „save + exit" -> `ImageStoreCodec.newSaveOperation` (Coroutine): dedup. `sheet.pdi` + `frames.json` v1.1 + `preview.pdi`, dann `saves/index` |
| Laden | `ImageStoreCodec.newLoadOperation` (Coroutine): Sheet-Slicing + `hashIndex`-Aufbau; v1.0/v1.1 strukturbasiert erkannt, jeder Frame auf 3 Ebenen aufgefuellt |
| Bild ins Web synchronisieren | `SelectionRoom` (Kurbel im Uhrzeigersinn >= 720°) -> `SyncService`: `playdate.network.http` an `www.hans-dither.de` (`/pair` -> `/login` -> Multipart `/upload`), danach QR+PIN-Ergebnisscreen |
| PNG als Room importieren (historisch) | `Tools/Importer/app.js` — Offline-Werkzeug, erzeugt Pulp-JSON; nicht im v0.3.0-Pfad (Kap. 11, R-14) |
