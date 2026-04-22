# Hans Dither Importer

## Zweck

Dieses Tool importiert ein PNG als neuen Room in eine Pulp-JSON und legt fehlende Tiles/Frames automatisch an.

## Lokal starten

1. `Tools/Importer/index.html` im Browser oeffnen.
2. Eine Pulp-JSON laden.
3. Eine PNG laden.
4. Optional Threshold anpassen.
5. `Import starten` klicken.
6. Mit `Export JSON` die aktualisierte Datei herunterladen.

## Verhalten

- Das PNG wird mit erhaltenem Seitenverhaeltnis auf 200x120 gebracht.
- Leere Raender werden schwarz aufgefuellt.
- Das Bild wird in 25x15 Tiles zu je 8x8 zerlegt.
- Doppelte Tiles werden ueber FNV-1a-Hash erkannt und wiederverwendet.
- Der neue Room wird an `rooms` angehaengt.
- Neue Tile-IDs werden nur in Gruppe 4 eingefuegt, technisch in `editor.sortedTiles[4]`.

## Hinweise

- Das Tool schreibt nie direkt in vorhandene Dateien, sondern erzeugt eine Exportdatei.
- Geprueft fuer typische Pulp-Strukturen (`rooms`, `tiles`, `frames`, optional `editor`).
