# 8. Querschnittliche Konzepte

## 8.1 Input- und Navigationskonzept

- Jeder Room liefert einen eigenen Input-Handler.
- Ein zentraler switchRoom-Mechanismus tauscht Handler atomar aus.
- Bedienmuster sind konsistent:
  - D-Pad fuer Navigation,
  - A fuer Auswahl/Setzen,
  - B als Modus-/Rueckkehr-Modifier,
  - Crank fuer Picker oder Zoom-Trigger.

- Der Editing-Flow ist gestuft:
  - TileRoom (roomweite Tilemap),
  - ZoomRoom (3x3 Tilekontext als 24x24 Pixelgrid),
  - PixelRoom (Einzeltile-Detail).

Nutzen: klare mentale Modelle fuer Nutzer und saubere Trennung je Room.

## 8.2 Rendering- und Redraw-Konzept

- Rendering ist zustandsbasiert ueber needsRedraw.
- TileRoom nutzt tilemap fuer flaechiges Rendering und gridview fuer Cursoroverlay.
- ZoomRoom zeichnet Pixelinhalt plus Tilegrenzen; inter-tile Rasterlinien werden ueber showGrid synchron zu TileRoom ein-/ausgeblendet.
- Blink-/Timer-Updates laufen zentral im Update-Loop.

Nutzen: geringer Overhead auf limitierter Hardware, gut steuerbare Darstellung.

## 8.3 Persistenz- und Formatkonzept

- Interne Arbeitsdaten bleiben kompakt und editierfreundlich.
- Externe Speicherung erzeugt ein vollstaendiges Pulp-Dokument.
- Nicht aktiv verwaltete Felder werden erhalten (Merge statt hartem Neuaufbau).
- Tile-IDs werden beim Speichern ggf. remapped; Mappings werden explizit nachgefuehrt.

Nutzen: Kompatibilitaet plus editorinterne Einfachheit.

## 8.4 Tile-Lifecycle-Konzept

- Basis-Tiles sind stabil (1..3).
- Neue oder bearbeitete Tiles werden dedupliziert bzw. in-place ersetzt.
- ZoomRoom-Commits uebergeben nur geaenderte Slots; TileRoom dedupliziert diese ueber Hashvergleich.
- Vor Save erfolgt Kompaktierung ungenutzter Tiles ueber alle Rooms.

Nutzen: begrenzter Speicherverbrauch und konsistente Tile-Referenzen.

## 8.5 Evolutionaeres Planungskonzept

Die Dateien unter plans/ und support/concepts dokumentieren die schrittweise Evolution:
- erst Grid/Cursor,
- dann Tilemap,
- dann Pixel-Detailbearbeitung,
- dann performantes Save/Load,
- dann Pulp-Kompatibilitaets-Refactoring.

Nutzen: nachvollziehbare Entscheidungen und kontrollierte technische Schulden.

## 8.6 Asynchrones Operationskonzept (Save/Load)

- Langlaufende Save/Load-Aktionen werden room-lokal ueber RoomOperation gesteuert.
- Die eigentliche Arbeit laeuft als Coroutine und wird pro Frame in update() fortgesetzt.
- Waehrend einer aktiven Operation werden konkurrierende Eingaben blockiert.
- Ein loadingBar-Overlay zeigt Titel, Detailtext und Fortschritt pro Phase.
- JSON-/Datastore read/write bleiben als einzelne Runtime-Aufrufe blockierend; diese Phasen werden explizit als finale Schritte markiert.

Nutzen: sichtbarer Fortschritt, bessere Responsivitaet waehrend Vorbereitungsschritten, weniger Duplikation zwischen Rooms.

## 8.7 Modul-Splitting nach Verantwortungen

- LoadRoom trennt Orchestrierung von Grid-UI durch LoadRoomGrid.
- TileRoom trennt Interaktion (TileRoomEditor) von Persistenzlogik (TileRoomPersistence).
- PulpGameIO trennt Fassade, Shared-Helfer, Save- und Load-Logik.

Nutzen: kleinere Dateien, bessere Test- und Wartbarkeit, klarere Seiteneffekte pro Modul.

## 8.8 Import-Integritaetskonzept (Tools/Importer)

- Das Browser-Tool behandelt Imports strikt offline und exportbasiert (kein in-place Ueberschreiben).
- Die Pipeline ist deterministisch: 200x120 Normalisierung -> Binarisierung -> 8x8-Slicing -> Hash-Dedupe -> Room/Tile/Frame-Mutation.
- Dedupe folgt demselben Prinzip wie im Lua-Editorpfad (Hashvergleich vor Neuanlage).
- editor.sortedTiles wird defensiv aktualisiert, ohne bestehende Gruppenstrukturen zu zerstoeren.

Nutzen: reproduzierbare Importergebnisse, geringeres Risiko inkonsistenter Referenzen und klare Trennung zur Device-Runtime.
