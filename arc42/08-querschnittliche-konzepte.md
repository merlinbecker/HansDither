# 8. Querschnittliche Konzepte

## 8.1 Input- und Navigationskonzept

- Jeder Room liefert einen eigenen Input-Handler.
- Ein zentraler switchRoom-Mechanismus tauscht Handler atomar aus.
- Bedienmuster sind konsistent:
  - D-Pad fuer Navigation,
  - A fuer Auswahl/Setzen,
  - B als Modus-/Rueckkehr-Modifier,
  - Crank fuer Picker oder Zoom-Trigger.

Nutzen: klare mentale Modelle fuer Nutzer und saubere Trennung je Room.

## 8.2 Rendering- und Redraw-Konzept

- Rendering ist zustandsbasiert ueber needsRedraw.
- TileRoom nutzt tilemap fuer flaechiges Rendering und gridview fuer Cursoroverlay.
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
