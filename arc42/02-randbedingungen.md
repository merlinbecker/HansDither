# 2. Randbedingungen

## 2.1 Technische Randbedingungen

| Randbedingung | Beschreibung |
|---|---|
| Zielplattform | Playdate-Konsole mit Lua-Runtime und Playdate SDK CoreLibs. |
| Aufloesung/Skalierung | Runtime nutzt Display-Scale 1 auf nativen 400x240. Editor-Daten bleiben trotzdem im Pulp-Arbeitsraum (200x120 bzw. 8x8 Tiles) und werden fuer die Anzeige gezielt 2x vergroessert. |
| Eingabegeraete | D-Pad, A/B-Buttons und Crank sind zentrale Bedienkomponenten. |
| Persistenz | Speicherung erfolgt ueber playdate.datastore und Dateisystempfade unter saves/. |
| Grafikmodell | Tile-basierte Darstellung mit imagetable und tilemap; zusaetzlich offscreen erzeugte Tiles. |
| Datenformat-Interoperabilitaet | Save-Daten muessen als vollstaendiges, Pulp-kompatibles Dokument erzeugt werden. |

## 2.2 Organisatorische Randbedingungen

| Randbedingung | Beschreibung |
|---|---|
| Projektziel | Lern- und Praxisprojekt mit iterativer Feature-Entwicklung. |
| Teamgroesse | Primär Einzelentwicklung, daher Fokus auf Lesbarkeit und modulare Trennung. |
| Dokumentationssprache | Deutsch in Architektur, Englisch teilweise in Devlog/Readme-Inhalten. |
| Lizenz | MIT-Lizenz erlaubt breite Nutzung und Weitergabe. |

## 2.3 Konzeptionelle Randbedingungen

| Randbedingung | Beschreibung |
|---|---|
| Room-Architektur | Anwendung ist in Rooms organisiert; Wechsel erfolgt zentral ueber switchRoom(). |
| Datenmodell intern | Editor arbeitet intern mit kompakten Arbeitsdaten (rooms/tiles/frames). |
| Datenmodell extern | Speichern muss bestehende Pulp-Strukturen/Felder erhalten (Merge-Ansatz). |
| Basistiles | Basis-Tiles 1..3 bleiben erhalten und werden bei Kompaktierung nicht entfernt. |
| Grenzen | Maximale Anzahl Games und Rooms ist derzeit funktional begrenzt (jeweils 6 im UI). |

## 2.4 Randbedingungen aus der Constitution (gueltig ab v0.3.0)

Quelle: `.specify/memory/constitution.md` (Version 1.0.0).

| Randbedingung | Beschreibung |
|---|---|
| SDK-first | Vor jeder Eigenimplementierung wird geprueft, ob das offizielle Playdate SDK die Funktion bietet oder abbilden kann; SDK-Entscheidungen werden in Kapitel 9 dokumentiert. |
| Native Formate & PDI | Persistenz ueber PDI-Tilemap + Positions-JSON je Frame; Tiles via Hashing dedupliziert; kein Pulp-JSON-Speicherformat mehr. |
| Native Aufloesung | 400x240 Pixel, 16x16-Tiles (25x15-Raster); kein separater Pulp-Arbeitsraum mehr. |
| Harte Grenzen | Maximal 12 Animationsframes pro Bild; Anzahl der Bilder unbegrenzt. |
| arc42-Pflege | Betroffene arc42-Kapitel werden im selben Aenderungsschnitt aktualisiert. |
