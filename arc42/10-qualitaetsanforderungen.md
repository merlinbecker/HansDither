# 10. Qualitaetsanforderungen

## 10.1 Uebersicht der Qualitaetsanforderungen

| Kategorie | Anforderung |
|---|---|
| Funktionale Korrektheit | Room-Wechsel, Save/Load, Tile-/Pixel-/Frame-Bearbeitung muessen konsistent funktionieren. |
| Zuverlaessigkeit | Speichern darf keine defekten Zuordnungen zwischen Frames, Tile-Indizes und Imagetable erzeugen. |
| Benutzbarkeit | Wichtige Aktionen sind mit kurzer Eingabefolge moeglich und im UI rueckgemeldet (Frame-Anzeige, Fortschritt). |
| Performance | Interaktionen und Redraw bleiben auf Zielhardware responsiv; Frame-Wechsel ohne Bildkopien im Update-Pfad. |
| Wartbarkeit | Aenderungen in einem Room sollen andere Rooms nur minimal beeinflussen. |
| Formattreue | Gespeicherte Bilder nutzen ausschliesslich native Formate (PDI + JSON, Constitution II) und bleiben nach Save/Load pixelidentisch. |
| Transparenz bei Langlaeufern | Nutzer sieht bei Save/Load stets den aktuellen Fortschritt und Zustand. |

## 10.2 Qualitaetsszenarien

### QS-01 Persistenzintegritaet
- Kontext: Nutzer bearbeitet ein Bild mit mehreren Frames.
- Stimulus: "save + exit" wird ausgeloest, das Bild wird spaeter erneut geoeffnet.
- Reaktion: Alle Frames bleiben ladbar, Tile-Referenzen bleiben korrekt, das Preview wird aktualisiert.
- Metrik: Nach Reload keine nil-Zugriffe/Abstuerze; Frame-Anzahl und visuelle Inhalte stimmen exakt.

### QS-02 Interaktionslatenz
- Kontext: EditorRoom mit aktiver Cursorbewegung, Malen und Frame-Wechsel.
- Stimulus: wiederholte D-Pad-, A/B- und Crank-Eingaben.
- Reaktion: Sichtbare Aktualisierung ohne wahrnehmbare Aussetzer; keine Eingabe geht verloren (SC-004).
- Metrik: Keine spuerbaren Hangs im normalen Nutzungspfad auf Zielhardware/Simulator.

### QS-03 Bedienklarheit
- Kontext: Nutzer mit v0.2.0-Vorwissen, ohne Anleitung.
- Stimulus: Erstnutzung von Frame-Verwaltung und Zoomstufen.
- Reaktion: Nutzer kann Bild oeffnen, malen, Frames anlegen/durchlaufen und alle drei Zoomstufen nutzen.
- Metrik: Erfolgreich innerhalb von 5 Minuten (SC-005), unterstuetzt durch sichtbare Frame-Hinweise (Bauchbinde).

### QS-04 Aenderbarkeit
- Kontext: Erweiterung um ein neues Menuefeature im PixelRoom.
- Stimulus: Anpassung nur im PixelRoom.
- Reaktion: Keine notwendigen Aenderungen in SelectionRoom oder ImageStore/Codec.
- Metrik: Feature lokal implementierbar mit begrenztem Seiteneffekt.

### QS-05 Formattreue
- Kontext: Bild mit mehreren Frames und Detail-Edits.
- Stimulus: Speichern und erneutes Laden.
- Reaktion: sheet.pdi enthaelt jedes Tile genau einmal (Dedup); frames.json referenziert nur gueltige Indizes.
- Metrik: Ein im Pixel Room gesetzter Einzelpixel liegt nach Save/Load exakt an derselben nativen Position (SC-003, 0 Koordinatenabweichung).

### QS-06 Zoom-Commit-Korrektheit
- Kontext: Nutzer bearbeitet mehrere Slots im ZoomRoom und kehrt zum EditorRoom zurueck.
- Stimulus: Zoom-Out mit Commit.
- Reaktion: Nur geaenderte Slots werden uebernommen; identische Tilebilder werden wiederverwendet (hashIndex + Pixelvergleich); geschrieben wird nur der aktive Frame.
- Metrik: Keine Tile-Neuanlagen fuer unveraenderte Slots (Z-03); visuell korrekte Rueckgabe im EditorRoom.

### QS-07 Show-Grid-Synchronitaet
- Kontext: "show grid" wird im EditorRoom umgeschaltet, danach Wechsel in den ZoomRoom.
- Stimulus: ZoomRoom wird ueber den B+Crank-Zoompfad geoeffnet.
- Reaktion: Gestrichelte Zellgrenzen im ZoomRoom folgen exakt dem showGrid-Status des Editors.
- Metrik: Kein Zustand, in dem EditorRoom und ZoomRoom unterschiedliche Grid-Linienmodi zeigen.

### QS-08 Save/Load-Fortschrittsfeedback
- Kontext: Bild mit vielen Tiles/Frames wird geladen oder gespeichert.
- Stimulus: Bildauswahl im SelectionRoom oder "save + exit" im EditorRoom.
- Reaktion: loadingBar zeigt Titel und Phase; UI bleibt stabil; Eingaben (inkl. Menueaktionen) sind blockiert.
- Metrik: Sichtbarer Fortschritt ueber den gesamten Ablauf; kein unkontrollierter Room-Wechsel waehrend aktiver Operation.

### QS-09 Frame-Integritaet
- Kontext: Bild mit mehreren Frames; Nutzer malt und nutzt die Zoomstufen in einem Frame.
- Stimulus: Frame-Wechsel per Crank (inkl. schnellem Drehen), Frame-Kopie, Frame-Loeschen, Zoom-Commits.
- Reaktion: Aenderungen betreffen ausschliesslich den aktiven Frame (Ausnahme: dokumentiertes "All Similar"); neue Frames sind exakte Kopien ihres direkten Vorgaengers; Rotation 12->1 und 1->letzter funktioniert beidseitig; der letzte Frame ist nicht loeschbar.
- Metrik: Nach beliebiger Frame-Navigation sind alle nicht bearbeiteten Frames byte-identisch zu ihrem Stand vor der Navigation; die Frame-Anzeige "n/m" stimmt immer.

### QS-10 Import-Pipeline-Korrektheit (historisch)
- Das Importer-Szenario bezieht sich auf das Pulp-Format (v0.2) und ist mit v0.3.0 nicht kompatibel (R-14); es bleibt nur als Referenz fuer eine kuenftige Importer-Anpassung dokumentiert.
