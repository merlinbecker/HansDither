# 2. Randbedingungen

## 2.1 Technische Randbedingungen

| Randbedingung | Beschreibung |
|---|---|
| Zielplattform | Playdate-Konsole mit Lua-Runtime und Playdate SDK CoreLibs. |
| Aufloesung/Skalierung | Runtime nutzt Display-Scale 2, damit logisch mit 200x120 gearbeitet wird. |
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
