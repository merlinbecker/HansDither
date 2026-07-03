# Feature Specification: Natives PDI-Speicherformat

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-03

**Status**: Draft

**Input**: User description: "Natives Speicherformat für Hans Dither v0.3.0: Das Pulp-JSON-Gesamtformat entfällt als Speicherformat. Ein Bild (400×240, aus 16×16-Tiles) wird gespeichert als PDI-Tilemap/Imagetable mit via Hashing deduplizierten Tiles plus einer JSON-Datei, die je Animationsframe (max. 12) die Positionen der 16×16-Tiles beschreibt. Beim Verlassen des Editors wird gespeichert; beim Öffnen eines Bildes wird alles wieder geladen. Bestehende Games/Rooms-Hierarchie entfällt: es gibt nur noch flache 'Bilder' mit unbegrenzter Anzahl."

## Clarifications

### Session 2026-07-03

- Q: Was passiert mit alten v0.2.x-Spielständen (Pulp-JSON) in v0.3.0? → A: Keine Migration — alte Saves werden ignoriert und nicht gelöscht; v0.3.0 startet mit leerer Bildliste; kein Konvertierungscode.
- Q: Aus welchem Frame wird das Vorschaubild eines Bildes erzeugt? → A: Immer aus dem ersten Frame (stabiles Titelbild der Animation).
- Q: Wie werden neue Bilder benannt/identifiziert? → A: Der Nutzer vergibt den Namen bei der Anlage über die Bildschirmtastatur (wie in v0.2.x); der Name ist der eindeutige Identifikator der Speichereinheit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bild verlustfrei speichern (Priority: P1)

Als Nutzer verlasse ich den Editor (zurück zum Auswahl-/Startscreen oder App-Ende), und mein Bild wird automatisch und vollständig gespeichert: alle bis zu 12 Animationsframes, alle Tiles, ohne dass ich einen expliziten Speicherdialog bedienen muss.

**Why this priority**: Zuverlässige Persistenz ist das oberste Qualitätsziel des Projekts; ohne verlustfreies Speichern ist jede Editorfunktion wertlos.

**Independent Test**: Ein Bild mit mehreren Frames und individuellen Tiles malen, Editor verlassen, App neu starten, Bild öffnen — Inhalt aller Frames ist pixelidentisch wiederhergestellt.

**Acceptance Scenarios**:

1. **Given** ein Bild mit 3 Frames und bearbeiteten Tiles ist im Editor geöffnet, **When** der Nutzer den Editor verlässt, **Then** werden die deduplizierte Tile-Sammlung (natives Bildformat) und die Positionsdaten je Frame persistiert.
2. **Given** ein Bild wurde gespeichert, **When** die App beendet und neu gestartet wird und der Nutzer das Bild öffnet, **Then** sind alle Frames, Tile-Zuordnungen und Pixelinhalte identisch zum Zustand vor dem Speichern.
3. **Given** die App wird über das System beendet, während der Editor aktiv ist, **When** der Terminate-Hook läuft, **Then** wird der aktuelle Stand ohne Datenverlust gespeichert.

---

### User Story 2 - Tiles dedupliziert ablegen (Priority: P2)

Als Nutzer, der große Flächen mit identischen Tiles füllt (z. B. komplett weiße oder gemusterte Bereiche), erwarte ich, dass Speichergröße und Ladezeit nicht mit der Fläche wachsen, sondern nur mit der Anzahl tatsächlich unterschiedlicher Tiles.

**Why this priority**: Dedup via Hashing ist die zentrale Formatentscheidung des Konzepts und begrenzt Speicher- und Ladezeitrisiken bei unbegrenzter Bildanzahl.

**Independent Test**: Ein Bild mit 375 Positionen, aber nur 4 unterschiedlichen Tile-Mustern speichern; die persistierte Tile-Sammlung enthält genau 4 Tiles (plus ggf. definierte Basistiles).

**Acceptance Scenarios**:

1. **Given** ein Frame verwendet dasselbe 16×16-Muster an 100 Positionen, **When** gespeichert wird, **Then** liegt das Muster genau einmal in der Tile-Sammlung, und alle 100 Positionen referenzieren es.
2. **Given** zwei Frames verwenden teilweise dieselben Tiles, **When** gespeichert wird, **Then** werden Tiles frameübergreifend nur einmal abgelegt.
3. **Given** ein Tile wird bearbeitet, sodass es einem bereits vorhandenen Tile gleicht, **When** gespeichert wird, **Then** wird kein Duplikat angelegt, sondern das vorhandene Tile referenziert.

---

### User Story 3 - Unbegrenzt viele flache Bilder verwalten (Priority: P2)

Als Nutzer lege ich beliebig viele eigenständige Bilder an — ohne die bisherige Hierarchie aus "Games" und "Rooms". Jedes Bild ist eine eigene Speichereinheit mit eigenem Vorschaubild.

**Why this priority**: Der Wegfall der Games/Rooms-Hierarchie ist Voraussetzung für den neuen Auswahlscreen und vereinfacht das gesamte Datenmodell.

**Independent Test**: Mehr als 9 Bilder anlegen und speichern; alle bleiben unabhängig voneinander ladbar, löschbar und kopierbar.

**Acceptance Scenarios**:

1. **Given** es existieren bereits 9 Bilder, **When** der Nutzer ein zehntes anlegt und speichert, **Then** wird es ohne feste Obergrenze zusätzlich persistiert.
2. **Given** ein Bild wird gelöscht, **When** der Löschvorgang abgeschlossen ist, **Then** sind dessen Tile-Sammlung, Positionsdaten und Vorschaubild entfernt, und andere Bilder bleiben unberührt.
3. **Given** ein Bild wird kopiert, **When** die Kopie gespeichert wird, **Then** entsteht eine unabhängige Speichereinheit, deren spätere Bearbeitung das Original nicht verändert.

---

### Edge Cases

- Was passiert, wenn die Positionsdaten existieren, aber die zugehörige Tile-Sammlung fehlt (oder umgekehrt)? Das Bild wird als beschädigt behandelt: kein Absturz, defensive Meldung, andere Bilder bleiben nutzbar.
- Was passiert, wenn eine Position auf einen nicht existierenden Tile-Index verweist? Fallback auf ein leeres (weißes) Tile, Laden wird fortgesetzt.
- Was passiert mit alten Pulp-JSON-Spielständen aus v0.2.x? Sie werden nicht geladen und nicht migriert (siehe Assumptions); sie dürfen das Auflisten der neuen Bilder nicht stören.
- Was passiert, wenn beim Speichern der Speicherplatz erschöpft ist oder ein Schreibfehler auftritt? Der Nutzer erhält eine sichtbare Fehlermeldung; ein bereits vorhandener älterer Speicherstand darf nicht in einen halb geschriebenen Zustand zerstört werden.
- Was passiert bei einem Bild mit 12 Frames und maximal vielen unterschiedlichen Tiles (12 × 375 Positionen)? Speichern und Laden bleiben funktionsfähig; Fortschritt wird angezeigt (siehe SC-004).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Das System MUSS ein Bild als Kombination aus (a) einer Sammlung deduplizierter 16×16-Tiles im nativen Playdate-Bildformat (PDI/Imagetable) und (b) Positionsdaten je Animationsframe (JSON) persistieren.
- **FR-002**: Das System MUSS Tiles vor dem Speichern über einen Hashvergleich deduplizieren; inhaltsgleiche Tiles werden genau einmal abgelegt.
- **FR-003**: Die Positionsdaten MÜSSEN je Frame die vollständige Belegung des 25×15-Tile-Rasters (400×240 bei 16×16-Tiles) als Referenzen auf die Tile-Sammlung beschreiben.
- **FR-004**: Das System MUSS pro Bild 1 bis maximal 12 Frames speichern und laden.
- **FR-005**: Das System MUSS beim Verlassen des Editors sowie beim Beenden der App (Terminate-Hook) automatisch speichern.
- **FR-006**: Das System MUSS beim Öffnen eines Bildes alle Frames und Tiles vollständig und verlustfrei wiederherstellen (Round-Trip-Garantie).
- **FR-007**: Das System MUSS Bilder als flache Liste ohne Games/Rooms-Hierarchie verwalten; die Anzahl der Bilder ist nicht künstlich begrenzt.
- **FR-008**: Das System MUSS pro Bild ein Vorschaubild persistieren, das von Start- und Auswahlscreen genutzt werden kann, sowie nachvollziehbar machen, welches Bild zuletzt bearbeitet wurde.
- **FR-009**: Das System MUSS Löschen und Kopieren eines Bildes als atomare Operationen auf dessen Speichereinheit unterstützen.
- **FR-013**: Das System MUSS den bei der Anlage per Bildschirmtastatur vergebenen Namen als eindeutigen Identifikator der Speichereinheit verwenden; Namenskollisionen MÜSSEN verhindert werden (Ablehnung oder automatisches Suffix).
- **FR-010**: Das System MUSS beschädigte oder unvollständige Speicherstände defensiv behandeln (kein Absturz, verständliche Rückmeldung, übrige Bilder bleiben nutzbar).
- **FR-011**: Langlaufende Speicher-/Ladevorgänge MÜSSEN kooperativ mit sichtbarem Fortschritt ablaufen (bestehendes Muster: Coroutine + Fortschrittsanzeige).
- **FR-012**: Das Pulp-JSON-Gesamtformat DARF NICHT mehr als Speicherformat geschrieben werden; die Module des Pulp-Speicherpfads werden entfernt oder ersetzt.

### Key Entities

- **Bild (Image)**: Eigenständige Arbeit des Nutzers; 400×240 Pixel, 25×15 Tile-Raster, 1–12 Frames, Vorschaubild, Zeitpunkt der letzten Bearbeitung. Der Name wird bei der Anlage vom Nutzer über die Bildschirmtastatur vergeben und dient als eindeutiger Identifikator (geklärt, siehe Clarifications).
- **Frame**: Eine von bis zu 12 Animationsstufen eines Bildes; vollständige Belegung des Tile-Rasters durch Tile-Referenzen.
- **Tile**: 16×16 Pixel großer 1-Bit-Bildbaustein; existiert genau einmal je eindeutigem Inhalt (Hash) in der Tile-Sammlung eines Bildes.
- **Tile-Sammlung**: Geordnete Menge aller in einem Bild verwendeten Tiles; persistiert im nativen Playdate-Bildformat (PDI/Imagetable).
- **Positionsdaten**: JSON-Struktur, die je Frame die Tile-Referenzen des Rasters beschreibt; verweist per Index auf die Tile-Sammlung.
- **Vorschaubild**: Maskierbare Repräsentation des ersten Frames eines Bildes für Auswahl- und Startscreen (geklärt, siehe Clarifications).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100 % der Speichern-Laden-Durchläufe stellen alle Frames pixelidentisch wieder her (Round-Trip ohne Verlust), verifiziert über eine manuelle Testmatrix mit mindestens 5 unterschiedlichen Bildern.
- **SC-002**: Bei einem Bild mit n unterschiedlichen Tile-Inhalten enthält die persistierte Tile-Sammlung genau n Einträge — unabhängig davon, an wie vielen Positionen und in wie vielen Frames sie verwendet werden.
- **SC-003**: Der Nutzer kann mindestens 20 Bilder anlegen, speichern, kopieren und löschen, ohne dass ein Vorgang fehlschlägt oder ein anderes Bild beeinflusst wird.
- **SC-004**: Speichern und Laden eines maximal großen Bildes (12 Frames) zeigt durchgehend sichtbaren Fortschritt und blockiert die Anzeige nie länger als etwa eine Sekunde am Stück.
- **SC-005**: Ein beschädigter Speicherstand führt in 0 Fällen zum Absturz; der Nutzer kann danach weiterhin alle intakten Bilder öffnen.

## Assumptions

- Alte Pulp-JSON-Spielstände aus v0.2.x werden nicht migriert (geklärt, siehe Clarifications): alte Dateien werden ignoriert und nicht gelöscht; es entsteht kein Konvertierungscode.
- Die Evaluierung einer "besseren Alternative" zur JSON-Positionsablage (laut Konzept offen) erfolgt in der Planungsphase dieses Features; JSON ist der gesetzte Standard, solange die Evaluierung nichts Besseres ergibt. Das Ergebnis wird als Architekturentscheidung in arc42 Kapitel 9 dokumentiert.
- Die Tile-Sammlung eines Bildes ist bildlokal; es gibt keine bildübergreifende, globale Tile-Bibliothek.
- Das Vorschaubild wird beim Speichern erzeugt bzw. aktualisiert; es leitet sich aus dem ersten Frame ab.
- "Zuletzt gemaltes Bild" (für den Startscreen-Hintergrund) wird über die Speicherverwaltung dieses Features bereitgestellt.
- Das PNG-Importer-Browser-Tool (Tools/Importer) basiert auf dem Pulp-Format und ist von v0.3.0 zunächst ausgenommen; seine Anpassung ist nicht Teil dieses Features.

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Persistenz-/Formatkonzept (arc42 Kap. 8), Randbedingungen (Kap. 2), Kontextabgrenzung (Kap. 3, Wegfall Pulp-Interoperabilität), Bausteinsicht (Kap. 5, Ersatz PulpGameIO*), Laufzeitsicht (Kap. 6, Save/Load-Szenarien), Qualitätsanforderungen (Kap. 10), Risiken (Kap. 11).
- **Erwartete Evidenz**: Aktualisierte arc42-Kapitel im selben Änderungsschnitt (Constitution Prinzip III); neue Architekturentscheidungen in Kap. 9: "PDI-Tilemap + Positions-JSON statt Pulp-JSON" und Ergebnis der Evaluierung der Positionsablage.
- **ADR erforderlich**: Ja (Formatentscheidung, Ablage-Alternative). Sicherheitsrelevante Architektur: N/A — lokales Offline-System ohne Netzwerk/vertrauliche Daten.
