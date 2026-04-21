# 7. Verteilungssicht

## 7.1 Infrastruktur Ebene 1

Hans Dither ist ein lokal laufendes Single-Device-System auf Playdate.

| Infrastrukturelement | Rolle |
|---|---|
| Playdate Device/Simulator Runtime | Ausfuehrung des Lua-Codes, Rendering, Input, Menues |
| .pdx Bundle | Enthält Lua-Quellen, Bildassets, Launcher-Assets, JSON-Template |
| Lokaler Datastore | Persistente Saves und Previewbilder unter saves/ |

### Verbindungskanaele
- Runtime <-> Display/Input: Playdate SDK API
- Runtime <-> Datastore/Dateisystem: playdate.datastore und playdate.file

## 7.2 Umgebungen

| Umgebung | Zweck |
|---|---|
| Entwicklungsumgebung (VS Code + SDK) | Codierung, lokale Tests, Iteration |
| Playdate Simulator | Schneller Funktions- und UI-Test ohne Hardwaretransfer |
| Physische Playdate | Zielplattform fuer reale Bedienung mit Crank und Buttons |

## 7.3 Zuordnung von Bausteinen

| Baustein | Infrastrukturzuordnung |
|---|---|
| main.lua + Rooms | Laufzeit im Lua-Kontext auf Playdate |
| PulpGameIO | Laufzeitmodul fuer Save/Load-Transformation |
| images/* | Bundle-Asset, zur Laufzeit als imagetable/image geladen |
| data/HansDitherTemplate.json | Bundle-Datenquelle fuer Pulp-kompatible Struktur |
| saves/* | Laufzeitpersistenz im Datastore |

## 7.4 Qualitaets-/Leistungsmerkmale der Verteilung

- Keine Netzabhaengigkeit, daher robust gegen Offline-Szenarien.
- Geringe Latenz durch lokale Datenhaltung.
- Hardwaregrenzen (CPU/RAM) erzwingen einfache Datenstrukturen und gezielte Redraw-Strategien.
