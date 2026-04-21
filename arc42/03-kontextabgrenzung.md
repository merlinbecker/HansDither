# 3. Kontextabgrenzung

## 3.1 Fachlicher Kontext

Hans Dither ist ein lokaler Pixel-Editor fuer Playdate. Externe Interaktionen entstehen nur durch Benutzerbedienung und lokale Persistenz.

| Kommunikationspartner | Eingaben an das System | Ausgaben des Systems |
|---|---|---|
| Spieler | D-Pad, A/B, Crank, Bildschirmtastatur | UI-Rueckmeldung, Cursor/Tile-Rendering, Save/Load-Effekte |
| Playdate Datastore | Dateinamen und serialisierte Datenobjekte | Persistente Spielstaende und Vorschaubilder |
| Pulp-kompatible JSON-Welt | Bestehende Dokumentstruktur als Input beim Laden | aktualisierte, kompatible Dokumente beim Speichern |

## 3.2 Technischer Kontext

| Kontextsystem | Schnittstelle/Technik | Zweck |
|---|---|---|
| Playdate Runtime | Lua + CoreLibs (graphics, ui, timer, crank, keyboard) | Rendering, Input, Navigation, Menues |
| Dateisystem | playdate.file + playdate.datastore | Lesen/Schreiben von Saves und Preview-Bildern |
| Assets im Bundle | imagetable/pdi/json/pdxinfo | Basistiles, Launchergrafiken, Template-Dokument |

## 3.3 Mapping fachlich -> technisch

| Fachlicher Vorgang | Technische Umsetzung |
|---|---|
| Game auswaehlen/anlegen | GameRoom-Grid + Keyboard + Indexdatei saves/index |
| Room auswaehlen/anlegen | LoadRoom-Grid + gameData.rooms |
| Zeichnen im Tile-Canvas | TileRoom-Tilemap mit Cursor-Overlay und Picker |
| Pixelgenaue Bearbeitung | PixelRoom mit 8x8 Grid-State und Rueckschreiben ins Tile |
| Speichern | TileRoom:saveToFile() + PulpGameIO.buildSaveDocument() |
| Laden | PulpGameIO.prepareLoadedGame() + Imagetable-Rekonstruktion |
