# 10. Qualitaetsanforderungen

## 10.1 Uebersicht der Qualitaetsanforderungen

| Kategorie | Anforderung |
|---|---|
| Funktionale Korrektheit | Room-Wechsel, Save/Load, Tile-/Pixelbearbeitung muessen konsistent funktionieren. |
| Zuverlaessigkeit | Speichern darf keine defekten Zuordnungen zwischen rooms/tiles/frames erzeugen. |
| Benutzbarkeit | Wichtige Aktionen sind mit kurzer Eingabefolge moeglich und im UI rueckgemeldet. |
| Performance | Interaktionen und Redraw bleiben auf Zielhardware responsiv. |
| Wartbarkeit | Aenderungen in einem Room sollen andere Rooms nur minimal beeinflussen. |
| Kompatibilitaet | Gespeicherte Dokumente bleiben Pulp-kompatibel und verlieren keine kritischen Felder. |

## 10.2 Qualitaetsszenarien

### QS-01 Persistenzintegritaet
- Kontext: Nutzer bearbeitet mehrere Rooms eines Games.
- Stimulus: Save + Back wird ausgeloest.
- Reaktion: Alle Rooms bleiben ladbar, Tile-Referenzen bleiben korrekt, Previews werden aktualisiert.
- Metrik: Nach Reload keine nil-Zugriffe/Abstuerze, Room-Anzahl und visuelle Inhalte stimmen.

### QS-02 Interaktionslatenz
- Kontext: TileRoom mit aktiver Cursorbewegung und Picker-Nutzung.
- Stimulus: wiederholte D-Pad- und Crank-Eingaben.
- Reaktion: Sichtbare Aktualisierung ohne wahrnehmbare Aussetzer.
- Metrik: Keine spuerbaren Hangs im normalen Nutzungspfad auf Zielhardware/Simulator.

### QS-03 Bedienklarheit
- Kontext: Nutzer ohne Vorwissen.
- Stimulus: Erstnutzung mit Blick auf Titel, Grid und Statuszeile.
- Reaktion: Nutzer kann Game anlegen, Room oeffnen, Pixel setzen und speichern.
- Metrik: Grundworkflow ohne externe Hilfe in wenigen Minuten durchfuehrbar.

### QS-04 Aenderbarkeit
- Kontext: Erweiterung um neues Menuefeature in PixelRoom.
- Stimulus: Anpassung nur in PixelRoom.
- Reaktion: Keine notwendigen Aenderungen in GameRoom/LoadRoom.
- Metrik: Feature lokal implementierbar mit begrenztem Seiteneffekt.

### QS-05 Formatkompatibilitaet
- Kontext: Geladenes vorhandenes Pulp-Dokument.
- Stimulus: Bearbeiten und erneutes Speichern.
- Reaktion: Nicht verwaltete Dokumentbereiche bleiben erhalten.
- Metrik: Strukturfelder wie songs/sounds/editor/scripts bleiben vorhanden und gueltig.
