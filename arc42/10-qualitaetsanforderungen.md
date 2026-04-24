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
| Transparenz bei Langlaeufern | Nutzer sieht bei Save/Load stets den aktuellen Fortschritt und Zustand. |
| Importintegritaet | PNG-Import erzeugt nur gueltige room/tile/frame-Beziehungen und bleibt reproduzierbar. |

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

### QS-06 Zoom-Commit-Korrektheit
- Kontext: Nutzer bearbeitet mehrere Slots im ZoomRoom und kehrt zu TileRoom zurueck.
- Stimulus: Zoom-Out mit Commit.
- Reaktion: Nur geaenderte Slots werden uebernommen; identische Tilebilder werden wiederverwendet (Dedupe).
- Metrik: Keine unnoetigen Tile-Neuanlagen fuer unveraenderte Slots; visuell korrekte Rueckgabe im TileRoom.

### QS-07 Show-Grid-Synchronitaet
- Kontext: showGrid wird im TileRoom ein-/ausgeschaltet, danach Wechsel zu ZoomRoom.
- Stimulus: ZoomRoom wird ueber den TileRoom-Zoompfad geoeffnet.
- Reaktion: Inter-tile Rasterlinien im ZoomRoom folgen exakt dem showGrid-Status des TileRoom.
- Metrik: Kein Zustand, in dem TileRoom und ZoomRoom unterschiedliche Grid-Linienmodi zeigen.

### QS-08 Save/Load-Fortschrittsfeedback
- Kontext: grosses Spiel mit vielen Tiles/Rooms wird geladen oder gespeichert.
- Stimulus: Nutzer startet Load in LoadRoom oder Save + Back in TileRoom.
- Reaktion: loadingBar zeigt Phase, Detail und Fortschritt; UI bleibt stabil, ohne inkonsistente Zwischenzustaende.
- Metrik: Sichtbarer Fortschritt ueber den gesamten Ablauf; kein unkontrollierter Room-Wechsel waehrend aktiver Operation.

### QS-09 Aenderbarkeit durch Modulgrenzen
- Kontext: Anpassung nur an Grid-Darstellung in LoadRoom.
- Stimulus: UI-Aenderung an Grid-Rendering/Navigationsverhalten.
- Reaktion: Aenderung bleibt weitgehend auf LoadRoomGrid begrenzt.
- Metrik: Keine verpflichtenden Anpassungen in PulpGameIO- oder TileRoom-Persistenzmodulen.

### QS-10 Import-Pipeline-Korrektheit
- Kontext: Nutzer importiert ein PNG ueber Tools/Importer in ein bestehendes Pulp-Dokument.
- Stimulus: Import starten und anschliessend Export ausfuehren.
- Reaktion: Neuer Room enthaelt genau 375 Tile-Eintraege; referenzierte Tile- und Frame-IDs existieren; editor.sortedTiles bleibt gueltig.
- Metrik: Exportiertes JSON ist erneut ladbar (Importer/Runtime) und zeigt den importierten Room ohne Referenzfehler.

### QS-11 Import-Dedupe-Effizienz
- Kontext: PNG enthaelt viele sich wiederholende 8x8-Muster.
- Stimulus: Import in ein bereits grosses Dokument.
- Reaktion: Bestehende Tiles werden ueber Hashvergleich wiederverwendet; neue Tiles nur bei echten Hash-Misses.
- Metrik: Anzahl neu angelegter Tiles bleibt deutlich unter 375, wenn Musterwiederholungen vorliegen.
