# Feature Specification: Start- und Auswahlscreen

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-03

**Status**: Draft

**Input**: User description: "Start- und Auswahlscreen für Hans Dither v0.3.0: Startscreen zeigt das zuletzt gemalte Bild als Hintergrund; Text 'Hans Dither, 1 bit Pixel 'n Tile Editor', 'Version 0.3.0 - still under development - Press A'. Nach A: einziger Auswahlscreen als 3×3-Raster aus Kreisen mit kreisförmig maskierten Thumbnails in Originalgröße; endloses Scrollen über den 9. Eintrag hinaus; Systemmenü mit Löschen/Kopieren/Neu; Auswahl führt direkt in den Editor. Der Rooms-Auswahlscreen entfällt."

## Clarifications

### Session 2026-07-03

- Q: Wie wird das Bild im Kreis des 3×3-Auswahlrasters dargestellt? → A: Als unskalierter Ausschnitt in Originalgröße hinter der Kreismaske (sichtbarer Bereich um die Bildmitte), nicht verkleinert.
- Q: Braucht das Löschen eines Bildes eine Bestätigung? → A: Ja — einfacher Bestätigungsdialog (A bestätigt, B bricht ab) vor dem endgültigen Löschen; es gibt kein Undo.
- Q: In welcher Reihenfolge werden die Bilder im Auswahlraster sortiert? → A: Zuletzt bearbeitet zuerst; der "Neues Bild"-Eintrag steht am Ende der Liste.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Vom Start direkt ins Bild (Priority: P1)

Als Nutzer starte ich die App, sehe den Startscreen mit Titel und Versionshinweis, drücke A und wähle im Auswahlscreen ein Bild — das mich direkt in den Editor bringt. Es gibt keine Zwischenebene ("Rooms") mehr.

**Why this priority**: Der verkürzte Einstieg (Start → Auswahl → Editor) ist die zentrale Workflow-Vereinfachung von v0.3.0; ohne ihn greifen weder Editor noch Speicherformat.

**Independent Test**: App starten, A drücken, vorhandenes Bild wählen — der Editor öffnet sich mit genau diesem Bild; kein weiterer Auswahlschritt dazwischen.

**Acceptance Scenarios**:

1. **Given** die App wird gestartet, **When** der Startscreen erscheint, **Then** zeigt er die Texte "Hans Dither, 1 bit Pixel 'n Tile Editor" und "Version 0.3.0 - still under development - Press A".
2. **Given** der Startscreen ist aktiv, **When** der Nutzer A drückt, **Then** erscheint der Auswahlscreen als 3×3-Raster aus Kreisen.
3. **Given** der Auswahlscreen zeigt vorhandene Bilder, **When** der Nutzer ein Bild markiert und A drückt, **Then** öffnet sich direkt der Editor mit diesem Bild.

---

### User Story 2 - Letztes Bild als Startscreen-Hintergrund (Priority: P3)

Als wiederkehrender Nutzer sehe ich beim App-Start mein zuletzt gemaltes Bild als Hintergrund des Startscreens — meine Arbeit begrüßt mich.

**Why this priority**: Emotionaler Mehrwert und Wiedererkennung, aber ohne funktionale Abhängigkeit; der Default-Hintergrund bleibt als Fallback.

**Independent Test**: Ein Bild bearbeiten, App neu starten — der Startscreen zeigt dieses Bild als Hintergrund; bei frischer Installation erscheint der Dither-Default-Hintergrund.

**Acceptance Scenarios**:

1. **Given** mindestens ein Bild wurde bereits gespeichert, **When** der Startscreen erscheint, **Then** ist das zuletzt bearbeitete Bild als Hintergrund zu sehen (Texte bleiben lesbar darüber).
2. **Given** es existiert noch kein gespeichertes Bild, **When** der Startscreen erscheint, **Then** wird der bisherige Dither-Default-Hintergrund gezeigt.

---

### User Story 3 - Unendlich viele Bilder im 3×3-Kreisraster durchblättern (Priority: P2)

Als Nutzer mit vielen Bildern navigiere ich per D-Pad durch ein 3×3-Raster aus Kreisen; jeder Kreis zeigt das jeweilige Bild in Originalgröße kreisförmig maskiert als Thumbnail. Bewege ich mich über den neunten sichtbaren Eintrag hinaus, scrollt das Raster weiter — es gibt keine Obergrenze an Bildern.

**Why this priority**: Ersetzt die bisherige 6er-Grenze und macht die "unbegrenzt viele Bilder"-Entscheidung aus dem Konzept bedienbar.

**Independent Test**: Mehr als 9 Bilder anlegen; per D-Pad über den 9. Eintrag hinaus navigieren — das Raster scrollt und alle Bilder sind erreichbar.

**Acceptance Scenarios**:

1. **Given** es existieren 12 Bilder, **When** der Auswahlscreen öffnet, **Then** sind die ersten 9 als Kreise mit maskierten Thumbnails sichtbar.
2. **Given** der Cursor steht auf dem letzten sichtbaren Eintrag der untersten Zeile, **When** der Nutzer weiter nach unten navigiert, **Then** scrollt das Raster um eine Zeile und die nächsten Bilder werden sichtbar.
3. **Given** ein Bild besitzt ein gespeichertes Vorschaubild, **When** es im Raster angezeigt wird, **Then** ist der Bildinhalt in Originalgröße kreisförmig maskiert im Kreis zu sehen (kein verzerrtes Skalieren).
4. **Given** ein Eintrag "Neues Bild" ist Teil des Rasters, **When** der Nutzer ihn wählt, **Then** wird per Bildschirmtastatur ein Name abgefragt, ein neues leeres Bild erstellt und der Editor geöffnet.

---

### User Story 4 - Bilder verwalten: Neu, Kopieren, Löschen (Priority: P2)

Als Nutzer verwalte ich meine Bilder über das Systemmenü des Auswahlscreens: ein neues Bild erstellen, das markierte Bild kopieren oder löschen.

**Why this priority**: Ohne Verwaltungsfunktionen wächst die flache Bildliste unkontrolliert; Kopieren ist zudem die Basis für Varianten-Workflows.

**Independent Test**: Über das Systemmenü ein Bild kopieren und eines löschen — das Raster aktualisiert sich korrekt, die Kopie ist eigenständig editierbar.

**Acceptance Scenarios**:

1. **Given** ein Bild ist im Raster markiert, **When** der Nutzer im Systemmenü "Löschen" wählt, **Then** erscheint ein Bestätigungsdialog; erst nach Bestätigung (A) wird das Bild entfernt und das Raster rückt nach; B bricht ab, ohne zu löschen.
2. **Given** ein Bild ist markiert, **When** der Nutzer "Kopieren" wählt, **Then** erscheint eine eigenständige Kopie als neuer Eintrag im Raster.
3. **Given** der Auswahlscreen ist aktiv, **When** der Nutzer "Neu erstellen" wählt, **Then** wird per Bildschirmtastatur ein Name abgefragt, ein neues leeres Bild angelegt und der Editor geöffnet.

---

### Edge Cases

- Was passiert bei frischer Installation ohne Bilder? Der Auswahlscreen zeigt einen "Neues Bild"-Einstieg; der Startscreen nutzt den Default-Hintergrund.
- Was passiert, wenn das zuletzt bearbeitete Bild gelöscht wurde? Der Startscreen fällt auf das nächstjüngste Bild oder den Default-Hintergrund zurück — kein Absturz, kein leerer Hintergrund.
- Was passiert, wenn ein Vorschaubild fehlt oder beschädigt ist? Der Kreis zeigt einen neutralen Platzhalter; Auswahl und Öffnen bleiben möglich.
- Was passiert beim Löschen des letzten verbliebenen Bildes? Das Raster zeigt danach wieder den Leerzustand mit "Neues Bild"-Einstieg.
- Wie verhält sich das Scrollen an den Rändern (erste Zeile nach oben, letzte Zeile nach unten)? Navigation stoppt am Anfang; am Ende folgt der "Neues Bild"-Eintrag als letztes Element.
- Was passiert, wenn während einer laufenden Lösch-/Kopieroperation navigiert wird? Konkurrierende Eingaben werden blockiert, bis die Operation abgeschlossen ist.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Der Startscreen MUSS die Texte "Hans Dither, 1 bit Pixel 'n Tile Editor" sowie "Version 0.3.0 - still under development - Press A" anzeigen; die Versionsangabe folgt den App-Metadaten.
- **FR-002**: Der Startscreen MUSS, sofern mindestens ein Bild existiert, das zuletzt bearbeitete Bild als Hintergrund anzeigen; andernfalls den Dither-Default-Hintergrund.
- **FR-003**: A auf dem Startscreen MUSS direkt zum Auswahlscreen führen.
- **FR-004**: Der Auswahlscreen MUSS der einzige Auswahlscreen der App sein; ein separater Rooms-Auswahlscreen DARF NICHT mehr existieren.
- **FR-005**: Der Auswahlscreen MUSS Bilder als 3×3-Raster aus Kreisen darstellen; jeder Kreis zeigt das Vorschaubild des Bildes in Originalgröße kreisförmig maskiert.
- **FR-006**: Die Navigation im Raster MUSS per D-Pad erfolgen; beim Navigieren über die sichtbaren 9 Einträge hinaus MUSS das Raster zeilenweise weiterscrollen.
- **FR-007**: Die Anzahl der im Auswahlscreen verwaltbaren Bilder DARF NICHT künstlich begrenzt sein.
- **FR-008**: Die Auswahl eines Bildes (A) MUSS direkt den Editor mit diesem Bild öffnen.
- **FR-009**: Das Systemmenü des Auswahlscreens MUSS die Aktionen "Neu erstellen", "Kopieren" (markiertes Bild) und "Löschen" (markiertes Bild) anbieten; "Löschen" MUSS vor der Ausführung einen Bestätigungsdialog anzeigen (A bestätigt, B bricht ab).
- **FR-010**: Nach Neu/Kopieren/Löschen MUSS sich das Raster ohne App-Neustart konsistent aktualisieren.
- **FR-011**: Fehlende oder beschädigte Vorschaubilder MÜSSEN durch einen neutralen Platzhalter ersetzt werden, ohne Auswahl oder Öffnen zu verhindern.
- **FR-012**: Der Zustand ohne Bilder MUSS einen erkennbaren Einstieg zum Erstellen des ersten Bildes bieten.
- **FR-013**: Die Bilder MÜSSEN im Raster nach dem Zeitpunkt der letzten Bearbeitung absteigend sortiert sein (jüngstes zuerst); der "Neues Bild"-Eintrag steht am Ende der Liste.

### Key Entities

- **Bildeintrag**: Repräsentation eines gespeicherten Bildes im Auswahlscreen; besteht aus Vorschaubild (kreisförmig maskiert), Identifikator/Name und Sortierposition (Reihenfolge: zuletzt bearbeitet zuerst — geklärt, siehe Clarifications).
- **Auswahlraster**: Sichtfenster von 3×3 Kreisen über der geordneten Gesamtliste aller Bilder plus abschließendem "Neues Bild"-Eintrag; besitzt Scrollposition und Cursor.
- **Zuletzt-bearbeitet-Markierung**: Information, welches Bild zuletzt im Editor bearbeitet wurde; Quelle für den Startscreen-Hintergrund (bereitgestellt durch das Speicherformat-Feature, Spec 001).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Ein Nutzer erreicht aus dem Startscreen mit maximal 3 Eingaben (A, Navigation, A) den Editor mit einem vorhandenen Bild.
- **SC-002**: Bei 30 angelegten Bildern sind alle 30 über das scrollende Raster erreichbar und innerhalb von 30 Sekunden auffindbar.
- **SC-003**: 100 % der Rasterzellen zeigen entweder ein korrekt maskiertes Thumbnail oder einen definierten Platzhalter — nie leere oder verzerrte Inhalte.
- **SC-004**: Nach jeder Verwaltungsaktion (Neu/Kopieren/Löschen) spiegelt das Raster den neuen Bestand ohne Neustart korrekt wider (0 Geisterträge, 0 fehlende Einträge).
- **SC-005**: Ein Erstnutzer ohne Vorwissen kann ohne externe Hilfe innerhalb von 2 Minuten ein neues Bild anlegen und im Editor landen.

## Assumptions

- Sortierung der Bilder im Raster (geklärt, siehe Clarifications): zuletzt bearbeitet zuerst; der "Neues Bild"-Eintrag steht am Ende der Liste.
- "Originalgröße maskiert" bedeutet (geklärt, siehe Clarifications): Das 400×240-Vorschaubild wird unskaliert hinter einer kreisförmigen Maske gezeigt (sichtbarer Ausschnitt um die Bildmitte), nicht auf Kreisgröße verkleinert.
- Löschen erfordert einen einfachen Bestätigungsdialog (geklärt, siehe Clarifications), da kein Undo vorgesehen ist (Nicht-Ziel laut arc42).
- Die Benennung neuer Bilder erfolgt bei der Anlage durch den Nutzer über die Bildschirmtastatur (wie in v0.2.x); der Name ist der eindeutige Identifikator des Bildes (geklärt in Spec 001, Clarifications 2026-07-03). Abbruch der Tastatureingabe bricht die Anlage ab (bestehendes App-Muster). Kopien erhalten einen automatisch abgeleiteten Namen (z. B. Suffix).
- Dieses Feature hängt von Spec 001 (natives Speicherformat) ab: flache Bildliste, Vorschaubilder und Zuletzt-bearbeitet-Markierung werden dort bereitgestellt.

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Bausteinsicht (arc42 Kap. 5: GameRoom wird zum Bild-Auswahlscreen, LoadRoom/LoadRoomGrid entfallen), Laufzeitsicht (Kap. 6: verkürztes Startszenario), Randbedingungen (Kap. 2: Wegfall der 6er-Grenzen), Querschnittskonzepte (Kap. 8: Navigation).
- **Erwartete Evidenz**: Aktualisierte arc42-Kapitel 2, 5, 6, 8 im selben Änderungsschnitt; Architekturentscheidung in Kap. 9 zum Wegfall der Rooms-Ebene und zur SDK-Nutzung für Raster/Maskierung (gridview, Bildmaskierung) gemäß Constitution Prinzip I/III.
- **ADR erforderlich**: Ja (Wegfall Rooms-Ebene, unbegrenztes scrollendes Raster statt fester Grid-Grenze). Sicherheitsrelevante Architektur: N/A — rein lokale UI-Navigation.
