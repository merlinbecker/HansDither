# Data Model: Natives PDI-Speicherformat

**Feature**: 001-pdi-storage-format | **Date**: 2026-07-03

## Übersicht

```text
saves/
├── index.json                 # Bildverzeichnis (eine Datei, Quelle für Auswahl-/Startscreen)
└── <bild-id>/                 # ein Ordner pro Bild
    ├── frames.json            # Positionsdaten je Frame (datastore.write)
    ├── sheet.pdi              # deduplizierte Tile-Sammlung (datastore.writeImage)
    └── preview.pdi            # Vorschaubild aus Frame 1 (datastore.writeImage)
```

## Entitäten

### Index (`saves/index.json`)

| Feld | Typ | Regeln |
|---|---|---|
| `version` | number | Formatversion, initial `1` |
| `lastEditedId` | string \| nil | ID des zuletzt bearbeiteten Bildes (Startscreen-Hintergrund); nil bei leerer Liste |
| `images` | array | Liste aller Bilder, Reihenfolge irrelevant (Sortierung erfolgt über `lastEdited`) |
| `images[n].id` | string | eindeutig; sanitisiert aus dem Nutzernamen (a–z, 0–9, `-`); Verzeichnisname |
| `images[n].name` | string | Anzeigename, wie per Bildschirmtastatur vergeben |
| `images[n].frameCount` | number | 1..12 (redundant zu frames.json, für Anzeige ohne Bild-Load) |
| `images[n].lastEdited` | number | Unix-Sekunden (`playdate.getSecondsSinceEpoch()`) |

Invarianten: `id` ist eindeutig über `images`; `lastEditedId` verweist auf ein existierendes Bild oder ist nil (Fallback-Regel siehe Spec 002 Edge Cases).

### Bild / Frames (`saves/<id>/frames.json`)

| Feld | Typ | Regeln |
|---|---|---|
| `version` | number | Formatversion, initial `1` |
| `name` | string | Anzeigename (Kopie aus Index, macht den Ordner selbstbeschreibend) |
| `gridWidth` | number | fest `25` |
| `gridHeight` | number | fest `15` |
| `tileCount` | number | Anzahl Tiles im Sheet (Validierung der Frame-Indizes) |
| `frames` | array | 1..12 Einträge |
| `frames[f]` | array | genau `gridWidth × gridHeight` = 375 Zahlen; 1-basierte Indizes in die Tile-Sammlung; Reihenfolge links→rechts, oben→unten (kompatibel zu `tilemap:setTiles(data, width)`) |

Validierung beim Laden: `1 <= frames[f][i] <= tileCount`, sonst Fallback auf Weiß-Tile (Index 1); `#frames` zwischen 1 und 12, sonst Bild als beschädigt behandeln.

### Tile-Sammlung (`saves/<id>/sheet.pdi`)

- Ein einzelnes 1-Bit-Image, Rasteranordnung: 25 Tiles pro Zeile, Zellgröße 16×16 px; Breite = `min(tileCount, 25) × 16`, Höhe = `⌈tileCount / 25⌉ × 16`.
- Tile `n` (1-basiert) liegt bei Zelle `((n-1) % 25, ⌊(n-1) / 25⌋)`.
- Konvention: Tile 1 = Voll-Weiß, Tile 2 = Voll-Schwarz (Basistiles, immer vorhanden — Grundlage für den Schwarz/Weiß-Toggle in Spec 003 und den Fallback bei defekten Referenzen).
- Dedup-Invariante: kein Tile-Inhalt kommt doppelt vor (FNV-1a-Hash + Pixelvergleich bei Kollision).

### Vorschaubild (`saves/<id>/preview.pdi`)

- 400×240-Render von Frame 1 (geklärt in Spec-Clarifications), erzeugt bei jedem Save.
- Konsumenten: Auswahlscreen-Kreise und Startscreen-Hintergrund (Spec 002); dort wird maskiert/ausgeschnitten, nicht hier.

## Laufzeitrepräsentation (In-Memory)

| Struktur | Inhalt | SDK-Abbildung |
|---|---|---|
| `imagetable` | Tile-Sammlung des geöffneten Bildes | `gfx.imagetable.new(count)` + `setImage(n, img)` (aus Sheet gesliced) |
| `frames[f]` | Index-Array (375, 1-basiert) je Frame | direkt in `tilemap:setTiles(frames[f], 25)` beim Frame-Wechsel |
| `hashIndex` | Map FNV-1a-Hash → Tile-Index | Dedup beim Editieren (Spec 003) und beim Save |

## Zustandsübergänge

```text
[Neu anlegen]   Name via Tastatur → ID sanitisieren → Kollisionsprüfung →
                Ordner + frames.json (1 Frame, alle Indizes = 1) + sheet.pdi (Tiles 1+2) +
                preview.pdi (weiß) → Index-Eintrag + lastEditedId
[Öffnen/Laden]  frames.json lesen → sheet.pdi lesen → Imagetable slicen → validieren
[Speichern]     Dedup/Hash → Sheet komponieren → frames.json → sheet.pdi → preview.pdi →
                Index (frameCount, lastEdited, lastEditedId)   [Reihenfolge fix, Index zuletzt]
[Kopieren]      Zielname via Auto-Suffix → Ordnerdateien kopieren → Index-Eintrag
[Löschen]       Ordner löschen → Index-Eintrag entfernen → lastEditedId ggf. neu bestimmen
[Beschädigt]    Kerndatei fehlt/invalid → Bild als defekt markiert, andere Bilder unberührt
```
