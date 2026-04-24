# 1. Einfuehrung und Ziele

## 1.1 Aufgabenstellung
Hans Dither ist ein minimalistischer 1-Bit-Pixel- und Tile-Editor fuer Playdate. Das System soll:

- das Erstellen einfacher Pixelgrafik direkt auf dem Geraet ermoeglichen,
- den Editierfluss ueber D-Pad, Buttons und Crank effizient machen,
- mehrere Games und mehrere Rooms pro Game verwalten,
- Daten Pulp-kompatibel speichern und wieder laden.

Das Projekt adressiert bewusst einen Lern- und Kreativkontext: Pixelart-Entwicklung direkt auf Hardware, mit reduzierten Mitteln und klaren Interaktionen.

Stand dieser Dokumentation: Architektur- und Implementierungsstand fuer Version 0.8. Die arc42 beschreibt damit den aktuellen Codezustand als Grundlage fuer den naechsten Planungsschnitt.

### Quellen im Projekt
- README (Projektidee, Bedienung, Zielsetzung)
- Source/pdxinfo (Metadaten)
- support/devlogs/01-noMoreExcuses.md (Motivation und Kontext)

## 1.2 Qualitaetsziele
Die wichtigsten Qualitaetsziele fuer die Architektur sind:

| Prioritaet | Qualitaetsziel | Beschreibung |
|---|---|---|
| 1 | Zuverlaessige Persistenz | Spielstaende duerfen bei Save/Load nicht verloren gehen; insbesondere muessen Tile-/Frame-/Room-Zuordnungen konsistent bleiben. |
| 2 | Direkte Bedienbarkeit | Kernaktionen (Navigieren, Pixel setzen/loeschen, Room/Game-Auswahl) muessen mit wenigen Eingaben erreichbar sein. |
| 3 | Pulp-Kompatibilitaet | Gespeicherte Daten sollen weiterhin in Pulp verwertbar bleiben; bestehende Felder duerfen nicht unnoetig verloren gehen. |
| 4 | Wartbarkeit | Raumlogik soll modular getrennt bleiben (Title/Game/Load/Tile/Zoom/Pixel), damit Features isoliert erweitert werden koennen. |
| 5 | Performantes Redraw | Rendern soll auf Playdate-Hardware flüssig bleiben (zustandsbasiertes Redraw, einfache Datenstrukturen). |

Ein zusaetzlicher Fokus der aktuellen Version ist die Trennung von Daten- und Anzeigeaufloesung: Pulp-kompatible Tile-/Frame-Daten bleiben in 8x8 bzw. 200x120 Arbeitsraum organisiert, waehrend die Runtime auf nativer 400x240-Aufloesung laeuft.

## 1.3 Stakeholder

| Rolle | Kontakt | Erwartungshaltung |
|---|---|---|
| Projektautor/Entwickler | Merlin Becker | Schnell iterierbare Codebasis, Lernbarkeit, einfache Erweiterung von Editorfeatures. |
| Spieler/Kreative | Endnutzer auf Playdate | Einfache, robuste Bedienung zum Pixeln und Speichern von Arbeiten. |
| Playdate/Pulp-Oekosystem | indirekt (Toolchain/Format) | Datenformat darf bekannte Pulp-Struktur nicht zerstoeren; Interaktionen sollen SDK-konform sein. |
| Wartende Mitentwickler (optional) | spaeteres Projektumfeld | Nachvollziehbare Raumaufteilung und dokumentierte Entscheidungen. |
