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
| SDK-Konformitaet | SDK-Bausteine werden bevorzugt; begruendete Eigenlogik (Rotation AD-036, Pixel-Verschiebung AD-043, Schuettel-Erkennung AD-044) ist in Kap. 9 dokumentiert (Constitution I, Qualitaetsziel 1.2-6). |
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

---

## 10.3 Backend-Qualitaetsanforderungen (Hans Dither Sync)

### QS-11 Authentifizierungs-Sicherheit
- **Kontext:** Nutzer versucht, auf fremde Images zuzugreifen
- **Stimulus:** Falsche UID/PIN-Kombination, abgelaufener Session-Token, manipulierte Token-Werte
- **Reaktion:** Zugriff wird verweigert mit HTTP 401/403, keine Daten werden preisgegeben
- **Metrik:** 100% der nicht-autorisierten Requests werden abgelehnt (SC-003)

### QS-12 Rate-Limiting-Funktionalitaet
- **Kontext:** Brute-Force-Angriff auf PIN
- **Stimulus:** 3 aufeinanderfolgende Fehlversuche für eine UID
- **Reaktion:** Account wird für 5 Minuten gesperrt (locked_until Timestamp)
- **Metrik:** Nach 3 Fehlversuchen: 429 Too Many Requests für 5 Minuten (SC-004)

### QS-13 Dateivalidierungs-Sicherheit
- **Kontext:** Nutzer versucht, schädliche Dateien hochzuladen
- **Stimulus:** Upload von .php, .exe, .sh oder anderen gefährlichen Dateitypen
- **Reaktion:** Upload wird abgelehnt mit HTTP 400, Datei wird NICHT gespeichert
- **Metrik:** 100% der gefährlichen Dateitypen werden abgelehnt (S-04)

### QS-14 PDI-Validierung
- **Kontext:** Upload einer ungültigen PDI-Datei
- **Stimulus:** Datei ohne Magic Bytes, ungültiger Header, unplausible Abmessungen
- **Reaktion:** Upload wird abgelehnt mit HTTP 400
- **Metrik:** Nur Dateien mit gültigem PDI-Format werden akzeptiert

### QS-15 JSON-Validierung
- **Kontext:** Upload einer ungültigen JSON-Datei
- **Stimulus:** Datei die nicht valides JSON enthält
- **Reaktion:** Upload wird abgelehnt mit HTTP 400
- **Metrik:** Nur Dateien mit gültigem JSON-Schema werden akzeptiert

### QS-16 Upload-Performance
- **Kontext:** Nutzer lädt PDI + JSON (jeweils ~5MB) hoch
- **Stimulus:** POST /upload.php mit beiden Dateien
- **Reaktion:** Upload und Speicherung innerhalb von 5 Sekunden
- **Metrik:** 95% der Uploads < 5 Sekunden (SC-002)

### QS-17 PNG-Rendering-Qualitaet
- **Kontext:** Nutzer lädt korrekte PDI + JSON hoch
- **Stimulus:** GET /download/png/{id}
- **Reaktion:** PNG wird generiert mit korrekten Abmessungen (400x240)
- **Metrik:** Generiertes PNG hat exakte Abmessungen und korrekte Pixel-Darstellung

### QS-18 Berechtigungspruefung
- **Kontext:** Nutzer A versucht auf Images von Nutzer B zuzugreifen
- **Stimulus:** GET /download/* mit Token von Nutzer A, aber Image-ID von Nutzer B
- **Reaktion:** Zugriff wird verweigert mit HTTP 401
- **Metrik:** 100% der berechtigungslosen Zugriffe werden abgelehnt (SC-005)

## 10.4 Ergaenzende Qualitaetsszenarien (Spec 008)

### QS-19 Zoom-Room-Reaktionsfaehigkeit
- Kontext: Zoom Room mit aktiver Cursorbewegung (auch gehaltene Richtungstaste) und Malstrichen.
- Stimulus: kontinuierliche D-Pad-/A-Eingaben ueber mehrere Sekunden.
- Reaktion: Redraw beschraenkt sich auf Hintergrund-Blit + geaenderte Zellen statt Vollbild-Neuberechnung (AD-035); keine wahrnehmbare Verzoegerung, kein Haengenbleiben.
- Metrik: Verhalten auf echter Hardware gleichwertig zum Tile-Editor (SC-001/SC-002); objektiv nachgewiesener Rueckgang der Game-CPU-Zeit via `playdate.getStats()`/Sampler gegenueber dem Vorher-Zustand.

### QS-20 Pixel-Rotations-Exaktheit
- Kontext: Pixel Room mit gezeichnetem Muster.
- Stimulus: volle Kurbelumdrehung (vorwaerts oder rueckwaerts, ohne B).
- Reaktion: `gridState` wird per exaktem Index-Remap um 90 Grad rotiert (AD-036); keine Zwischen-Rotation bei Teildrehungen.
- Metrik: Vier aufeinanderfolgende volle Vorwaertsdrehungen ergeben wieder exakt das Ausgangsbild, 0 Pixelverlust (SC-003/SC-004).

## 10.5 Ergaenzende Qualitaetsszenarien (Spec 011 — Schuettel-Undo)

### QS-21 Robustheit: Clear-Screen-Undo stellt vollstaendig wieder her
- Kontext: Frame mit Inhalt auf der aktiven Ebene, danach „Clear Screen".
- Stimulus: Schuetteln (links-rechts) → Dialog → „(A) Ja".
- Reaktion: `applyContentEntry` schreibt alle 375 Zellindizes der aktiven Ebene zurueck und kompositiert den Frame neu (AD-045).
- Metrik: `layer.positions` ist elementweise identisch zum Stand vor „Clear Screen"; im Editor in < 1 s sichtbar (FR-002). Headless verifiziert (V5/V5b), Sichtpruefung im Simulator (T043, quickstart Szenario A).

### QS-22 Performance: Sensor-Polling ohne FPS-Einbruch im Zoom-View
- Kontext: Zoom View mit aktiver Cursorbewegung; `ShakeDetector` laeuft mit.
- Stimulus: kontinuierliche D-Pad-/A-Eingaben ueber mehrere Sekunden bei laufendem Accelerometer.
- Reaktion: pro `update()` genau ein `readAccelerometer()` + ein Zustandsschritt in `ShakeDetector:feed` (keine Allokation im Normalfall, AD-044); kein zusaetzlicher Redraw ausser bei tatsaechlich geoeffnetem Dialog.
- Metrik: Zoom-View-FPS auf echter Hardware unveraendert zur Spec-008-Basislinie (Risiko R-27). **Offen** bis T042 (Hardware).

### QS-23 Speicher: Undo-Verlauf bleibt klein
- Kontext: 3 riskante Operationen im Verlauf, worst case eine davon „Frame loeschen".
- Stimulus: Verlauf voll (`MAX = 3`), ein `deleteFrame`-Eintrag = tiefe Kopie (3 Ebenen × 375 ints + 375er-Cache).
- Reaktion: Voll-Snapshot je betroffener Zelle als int + Bild-**Referenz** (Bilder werden nicht kopiert); FIFO verdraengt den vierten Eintrag (AD-045).
- Metrik: Gesamt-RAM der `UndoHistory` < ~100 KB Lua-Heap. Grobabschaetzung am Geraet dokumentieren (T042). Headless: FIFO + `isEmpty` nach 3× `undoLast` verifiziert (V1/V2).
