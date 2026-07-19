# Feature Specification: Editor-UI-Verbesserungen — Bauchbinde, Frame-Navigation, Titel- und Zoom-Darstellung

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-18

**Status**: Draft

**Input**: User description: "UI-Feedback aus einem Transkript: (1) Die Bauchbinde im Tile-View ('Frame X von Y') soll nach 5 Sekunden Inaktivität automatisch verschwinden und sich intelligent gegenüber der Cursor-Position positionieren. (2) Frame-Wechsel per Crank soll erst nach einer vollen Umdrehung erfolgen, damit ein eingeklappter Crank nie versehentlich den Frame wechselt. (3) Der Titelscreen soll das ausgewählte Bild als vollflächigen, animierten Hintergrund mit VHS-Griesel-Effekt zeigen (statt einer Zickzack-Bewegung im Kreis). (4) Der Zoom-View soll den Bildhintergrund in echter 16×16-Pixel-Auflösung zeigen, auch wenn das Editier-Grid nur 8×8-Zellen (2×2-Pixel-Blöcke) umfasst. (5) Eine erweiterte Kontext-/Pause-Ansicht soll zusätzlich zu den Standard-Pause-Optionen eine Tile-Übersicht (bis zu 120 Kacheln in 12×10) mit Gesamt-Tile-Anzahl unten links und Metainformationen (u. a. Frame-Anzahl) zeigen. (6) Eine neue Aktion 'Reset Frame' soll den Inhalt des vorherigen Frames vollständig in den aktuellen Frame kopieren."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Zoom-View zeigt den Bildhintergrund pixelgenau (Priority: P1)

Beim Wechsel vom Tile-View in den Zoom-View sieht der Nutzer aktuell ein
Editier-Grid, dessen Zellen zwar korrekt sitzen, aber den darunterliegenden
Bildinhalt nicht in der echten Quellauflösung zeigen. Der Nutzer muss sehen
können, welche einzelnen Pixel sich innerhalb jeder 2×2-Editierzelle
befinden, bevor er entscheidet, ob er die Zelle füllt oder leert.

**Why this priority**: Ohne korrekte Pixel-Darstellung trifft der Nutzer
Bearbeitungsentscheidungen auf Basis falscher visueller Information — das
ist ein Korrektheitsproblem, das die Kernfunktion des Zoom-Views (gezieltes
Detail-Editing) unterläuft.

**Independent Test**: Ein Bild mit bekanntem, unregelmäßigem 16×16-Pixel-
Muster wird im Editor angelegt; beim Wechsel in den Zoom-View muss jede
2×2-Editierzelle exakt die vier zugehörigen Quellpixel erkennbar
überlagern.

**Acceptance Scenarios**:

1. **Given** ein Bild mit gemischten schwarzen/weißen Pixeln in einem
   16×16-Tile, **When** der Nutzer in den Zoom-View dieses Tiles wechselt,
   **Then** zeigt der Hintergrund alle 256 Quellpixel in ihrer echten
   Anordnung, überlagert vom 8×8-Editier-Grid.
2. **Given** eine 2×2-Editierzelle mit zwei schwarzen und zwei weißen
   Quellpixeln, **When** der Nutzer diese Zelle betrachtet, **Then** kann er
   alle vier Einzelpixel visuell unterscheiden, bevor er die Zelle als
   Ganzes füllt oder leert.

---

### User Story 2 - Frame-Wechsel erfordert eine volle Crank-Umdrehung (Priority: P1)

Der Nutzer wechselt Animationsframes aktuell schon bei kleinen
Crank-Bewegungen. Das führt dazu, dass ein zufälliges Antippen oder das
Einklappen des Cranks den angezeigten Frame verändert. Der Nutzer möchte,
dass ein Frame-Wechsel erst nach einer vollständigen 360°-Umdrehung
erfolgt, damit der beim Einklappen sichtbare Frame garantiert der ist, den
er zuletzt bewusst ausgewählt hat.

**Why this priority**: Ungewollte Frame-Wechsel wirken sich direkt auf die
Verlässlichkeit des Editors aus — der Nutzer kann sonst nie sicher sein,
an welchem Frame er gerade arbeitet.

**Independent Test**: Der Crank wird in kleinen Schritten gedreht, die in
Summe weniger als eine volle Umdrehung ergeben; der angezeigte Frame darf
sich dabei zu keinem Zeitpunkt ändern. Erst eine vollständige Umdrehung in
eine Richtung wechselt den Frame in diese Richtung.

**Acceptance Scenarios**:

1. **Given** Frame 2 von 4 ist aktiv, **When** der Nutzer den Crank um
   270° im Uhrzeigersinn dreht, **Then** bleibt Frame 2 weiterhin
   angezeigt.
2. **Given** Frame 2 von 4 ist aktiv, **When** der Nutzer den Crank um
   360° im Uhrzeigersinn dreht, **Then** wechselt die Anzeige zu Frame 3.
3. **Given** der Nutzer hat den Crank um 270° gedreht und dreht ihn ohne
   Pause um weitere 90° in dieselbe Richtung weiter (insgesamt 360°),
   **When** die volle Umdrehung erreicht ist, **Then** wechselt der Frame
   genau einmal.
4. **Given** eine laufende Teil-Umdrehung, **When** der Nutzer den Crank
   einklappt, bevor eine volle Umdrehung erreicht wurde, **Then** bleibt
   der zuletzt angezeigte Frame unverändert erhalten.

---

### User Story 3 - Bauchbinde blendet sich automatisch aus und weicht dem Cursor aus (Priority: P2)

Die Bauchbinde zeigt im Tile-View die aktuelle Frame-Position (z. B.
"Frame 1 von 12") permanent an und kann dabei den Arbeitsbereich
verdecken. Sie soll nach 5 Sekunden Inaktivität verschwinden und sich —
solange sie sichtbar ist — auf der Bildschirmhälfte zeigen, die vom
aktuellen Cursor am weitesten entfernt ist.

**Why this priority**: Reduziert visuelle Ablenkung und stellt sicher,
dass die Anzeige nie den Bereich verdeckt, in dem der Nutzer gerade
zeichnet.

**Independent Test**: Nutzer führt keine Eingabe aus und misst, ob die
Bauchbinde nach 5 Sekunden ausgeblendet wird; anschließend bewegt er den
Cursor abwechselnd in die linke und rechte Bildschirmhälfte und prüft, ob
die Bauchbinde jeweils auf der gegenüberliegenden Seite erscheint.

**Acceptance Scenarios**:

1. **Given** die Bauchbinde ist sichtbar, **When** 5 Sekunden ohne jede
   Nutzereingabe vergehen, **Then** blendet sich die Bauchbinde aus.
2. **Given** die Bauchbinde ist ausgeblendet, **When** der Nutzer eine
   beliebige Eingabe tätigt (Bewegung, Crank, Knopf), **Then** erscheint
   die Bauchbinde wieder und der 5-Sekunden-Timer beginnt neu.
3. **Given** der Cursor befindet sich in der rechten unteren
   Bildschirmhälfte, **When** die Bauchbinde eingeblendet wird, **Then**
   erscheint sie links unten.
4. **Given** der Cursor befindet sich in der linken unteren
   Bildschirmhälfte, **When** die Bauchbinde eingeblendet wird, **Then**
   erscheint sie rechts unten.

---

### User Story 4 - Frame per "Reset Frame" auf den Vorgänger zurücksetzen (Priority: P2)

Wenn der Nutzer an einem Frame arbeitet und mit dem Ergebnis unzufrieden
ist, möchte er nicht alles neu zeichnen, sondern auf Basis des letzten
Standes (dem direkten Vorgänger-Frame) neu ansetzen. Dafür kopiert "Reset
Frame" den kompletten Inhalt des vorherigen Frames in den aktuell aktiven
Frame.

**Why this priority**: Spart Zeichenzeit bei Fehlversuchen und senkt die
Hemmschwelle, mit einem Frame zu experimentieren, ohne bereits geleistete
Vorarbeit zu verlieren.

**Independent Test**: Frame 2 wird bewusst anders bearbeitet als Frame 1;
nach Auslösen von "Reset Frame" auf Frame 2 muss dessen Inhalt exakt dem
aktuellen Inhalt von Frame 1 entsprechen.

**Acceptance Scenarios**:

1. **Given** Frame 1 und Frame 2 mit unterschiedlichem Inhalt, **When**
   der Nutzer auf Frame 2 "Reset Frame" auslöst, **Then** entspricht der
   Inhalt von Frame 2 danach exakt dem aktuellen Inhalt von Frame 1.
2. **Given** der Nutzer befindet sich auf Frame 1 (kein Vorgänger
   existiert), **When** er versucht, "Reset Frame" auszulösen, **Then**
   ist die Aktion nicht verfügbar bzw. hat keine Wirkung.

---

### User Story 5 - Erweiterte Kontext-/Pause-Ansicht mit Tile-Übersicht (Priority: P3)

Neben den Standard-Pause-Funktionen möchte der Nutzer in der
Kontext-/Pause-Ansicht eine Übersicht aller im aktuellen Bild verwendeten
Tiles sehen: als Raster mit bis zu 120 Kachel-Vorschauen (12 Spalten × 10
Zeilen), der Gesamtzahl der Tiles unten links, sowie zusätzlichen
Metainformationen wie der Anzahl der Animationsframes im übrigen
Bildschirmbereich.

**Why this priority**: Gibt dem Nutzer einen schnellen Überblick über
Umfang und Wiederverwendung seiner Arbeit, ist aber für die
Kernbearbeitung nicht zwingend notwendig — daher niedrigere Priorität als
Korrektheits- und Bedienungssicherheits-Themen.

**Independent Test**: Ein Bild mit bekannter Anzahl unterschiedlicher
Tiles (z. B. 30) und bekannter Frame-Anzahl (z. B. 4) wird geöffnet; die
Kontext-/Pause-Ansicht muss 30 Tile-Vorschauen, die Zahl "30" unten links
und die Frame-Anzahl "4" als Metainformation anzeigen.

**Acceptance Scenarios**:

1. **Given** ein Bild mit 30 unterschiedlichen Tiles, **When** der Nutzer
   die Kontext-/Pause-Ansicht öffnet, **Then** zeigt sie 30
   Tile-Vorschauen im 12×10-Raster und die Zahl "30" unten links.
2. **Given** dasselbe Bild mit 4 Animationsframes, **When** die
   Kontext-/Pause-Ansicht geöffnet ist, **Then** ist die Zahl "4" als
   Frame-Anzahl im Metainformationsbereich sichtbar.
3. **Given** ein Bild mit mehr als 120 unterschiedlichen Tiles, **When**
   der Nutzer die Kontext-/Pause-Ansicht öffnet, **Then** zeigt das
   12×10-Raster eine Teilmenge der Tiles, während die angezeigte
   Gesamtzahl weiterhin den echten, vollständigen Wert ausweist.

---

### User Story 6 - Titelscreen zeigt animierten Hintergrund mit VHS-Effekt (Priority: P3)

Auf dem Titelscreen werden Bilder aktuell als Kreise mit statischem
Bildausschnitt dargestellt. Für das aktuell ausgewählte Bild soll
stattdessen dessen eigene Animation als vollflächiger Hintergrund
abgespielt werden, überlagert von einem VHS-Griesel-Effekt, damit der
Nutzer den vollständigen Bildinhalt und die Animation erkennt, ohne den
Editor zu öffnen.

**Why this priority**: Reine visuelle Verbesserung der Bildauswahl ohne
Einfluss auf Kernfunktionen des Editors — daher niedrigste Priorität
dieser Spec.

**Independent Test**: Ein Bild mit mehreren Animationsframes wird auf dem
Titelscreen ausgewählt; der Bildschirmhintergrund muss die Frames dieses
Bilds nacheinander vollflächig anzeigen, sichtbar überlagert von einem
Störeffekt, während andere Bilder weiterhin als Kreise erkennbar bleiben.

**Acceptance Scenarios**:

1. **Given** ein Bild mit 3 Animationsframes ist auf dem Titelscreen
   ausgewählt, **When** der Nutzer den Titelscreen betrachtet, **Then**
   spielt der Vollbild-Hintergrund die 3 Frames dieses Bilds nacheinander
   ab.
2. **Given** der Vollbild-Hintergrund ist aktiv, **When** der Nutzer ihn
   betrachtet, **Then** ist ein VHS-Griesel-/Störeffekt sichtbar über dem
   Hintergrund.
3. **Given** mehrere Bilder sind auf dem Titelscreen verfügbar, **When**
   eines davon ausgewählt ist, **Then** bleiben die übrigen, nicht
   ausgewählten Bilder weiterhin als statische Kreis-Miniaturen erkennbar.
4. **Given** ein Bild mit nur 1 Animationsframe ist ausgewählt, **When**
   der Nutzer den Titelscreen betrachtet, **Then** zeigt der
   Vollbild-Hintergrund dieses eine Standbild weiterhin mit
   VHS-Griesel-Effekt, ohne dass ein Frame-Wechsel stattfindet.

---

### Edge Cases

- Was passiert, wenn der Nutzer den Crank mitten in einer Umdrehung
  anhält und in die Gegenrichtung zurückdreht, bevor eine volle
  Umdrehung erreicht wurde? Der Frame darf sich in diesem Fall nicht
  ändern; der Drehfortschritt zählt erst ab einer vollständigen 360°-
  Bewegung in eine Richtung.
- Was passiert, wenn der Cursor sich exakt in der horizontalen
  Bildschirmmitte befindet? Die Bauchbinde muss dennoch eine eindeutige
  Seite wählen und darf den Arbeitsbereich nicht verdecken.
- Was passiert bei "Reset Frame" auf Frame 1, für den kein
  Vorgänger-Frame existiert? Die Aktion ist nicht verfügbar bzw.
  wirkungslos (siehe User Story 4, Acceptance Scenario 2).
- Was passiert, wenn ein Bild mehr unterschiedliche Tiles enthält, als
  im 12×10-Raster der Kontext-/Pause-Ansicht Platz haben (> 120)? Die
  Gesamtzahl bleibt korrekt sichtbar, auch wenn nicht alle Tiles als
  Vorschau dargestellt werden können.
- Was passiert, wenn ein Bild nur einen einzigen Animationsframe besitzt?
  "Reset Frame" ist wie bei Frame 1 nicht verfügbar, und der animierte
  Titelscreen-Hintergrund zeigt das einzelne Standbild ohne
  Frame-Wechsel, aber weiterhin mit VHS-Griesel-Effekt.
- Was passiert, wenn der Nutzer während der 5-Sekunden-Inaktivität nur
  den Cursor bewegt, ohne den Frame zu wechseln? Die Bauchbinde bleibt
  eingeblendet bzw. erscheint neu und aktualisiert ihre Position gemäß
  der neuen Cursor-Position; der Inaktivitäts-Timer wird zurückgesetzt.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUSS die Frame-Positions-Anzeige (Bauchbinde) im
  Tile-View nach 5 Sekunden ohne Nutzereingabe automatisch ausblenden.
- **FR-002**: System MUSS die Bauchbinde bei jeder Nutzereingabe (Bewegung,
  Crank, Knopfdruck) sofort wieder einblenden und den 5-Sekunden-Timer
  zurücksetzen.
- **FR-003**: System MUSS die Bauchbinde auf der Bildschirmhälfte anzeigen,
  die der aktuellen Cursor-Position gegenüberliegt (Cursor rechts →
  Bauchbinde links, Cursor links → Bauchbinde rechts), damit sie den
  aktiven Arbeitsbereich nicht verdeckt.
- **FR-004**: Nutzer MÜSSEN den Crank um eine vollständige 360°-Umdrehung
  in Vorwärtsrichtung drehen, damit der Editor zum nächsten
  Animationsframe wechselt; Teildrehungen DÜRFEN den angezeigten Frame
  NICHT verändern.
- **FR-005**: Nutzer MÜSSEN den Crank um eine vollständige 360°-Umdrehung
  in Rückwärtsrichtung drehen, damit der Editor zum vorherigen
  Animationsframe wechselt; Teildrehungen DÜRFEN den angezeigten Frame
  NICHT verändern.
- **FR-006**: System MUSS den zuletzt angezeigten Frame beibehalten, wenn
  der Crank eingeklappt oder losgelassen wird, während eine Umdrehung noch
  nicht vollständig ist.
- **FR-007**: System MUSS im Zoom-View den Bildhintergrund in der echten
  Quellauflösung von 16×16 Pixeln zeichnen, auch wenn das darüberliegende
  Editier-Grid nur 8×8 Zellen umfasst.
- **FR-008**: System MUSS das 8×8-Editier-Grid im Zoom-View weiterhin so
  behandeln, dass jede Zelle einen 2×2-Pixel-Block der Quellauflösung
  abbildet und nur als Ganzes gefüllt oder geleert werden kann.
- **FR-009**: Nutzer MÜSSEN im Zoom-View alle vier Einzelpixel innerhalb
  einer 2×2-Editierzelle visuell unterscheiden können, bevor sie diese
  Zelle bearbeiten.
- **FR-010**: System MUSS eine Kontext-/Pause-Ansicht bereitstellen, die
  zusätzlich zu den Standard-Pause-Funktionen (Lautstärke, Home,
  Screenshot) eine Übersicht aller im aktuellen Bild verwendeten,
  unterschiedlichen Tiles als Raster mit bis zu 120 Vorschauplätzen
  (12 Spalten × 10 Zeilen) zeigt.
- **FR-011**: Die Kontext-/Pause-Ansicht MUSS die Gesamtzahl der im
  aktuellen Bild verwendeten, unterschiedlichen Tiles unten links
  anzeigen.
- **FR-012**: Die Kontext-/Pause-Ansicht MUSS zusätzliche
  Metainformationen zum aktuellen Bild — mindestens die Anzahl der
  Animationsframes — im übrigen Bildschirmbereich anzeigen.
- **FR-013**: Übersteigt die Anzahl unterschiedlicher Tiles eines Bildes
  die 120 verfügbaren Vorschauplätze, MUSS die Kontext-/Pause-Ansicht
  weiterhin die korrekte Gesamtzahl (FR-011) anzeigen, auch wenn nur ein
  Teil der Tiles als Vorschau dargestellt wird.
- **FR-014**: Nutzer MÜSSEN eine "Reset Frame"-Aktion auslösen können,
  solange nicht der erste Animationsframe aktiv ist; diese Aktion ERSETZT
  den gesamten Inhalt des aktuell aktiven Frames durch den aktuellen
  Inhalt des unmittelbar vorhergehenden Frames.
- **FR-015**: System MUSS "Reset Frame" deaktivieren bzw. wirkungslos
  lassen, solange der erste Animationsframe eines Bildes aktiv ist, da
  kein Vorgänger-Frame existiert.
- **FR-016**: System MUSS für das aktuell auf dem Titelscreen ausgewählte
  Bild dessen eigene Animationsframes als vollflächigen,
  bildschirmfüllenden Hintergrund abspielen (in derselben Reihenfolge, in
  der sie auch im Editor durchlaufen werden).
- **FR-017**: System MUSS über dem vollflächigen animierten Hintergrund
  des ausgewählten Bilds einen VHS-Griesel-/Störeffekt einblenden.
- **FR-018**: System MUSS alle nicht ausgewählten Bilder auf dem
  Titelscreen weiterhin als statische Kreis-Miniaturen darstellen,
  unverändert durch den animierten Vollbild-Hintergrund des ausgewählten
  Bilds.

### Key Entities

- **Frame-Positions-Anzeige (Bauchbinde)**: Sichtbarkeitsstatus
  (eingeblendet/ausgeblendet), Anzeigeseite (links/rechts) und
  Inaktivitäts-Timer; zeigt Text im Format "Frame X von Y".
- **Animationsframe**: Gehört zu genau einem Bild, hat eine Position in
  der Frame-Reihenfolge (1 bis maximal 12) und referenziert die Tiles,
  aus denen sich sein Inhalt zusammensetzt.
- **Tile**: Kleinste wiederverwendbare Bildeinheit (16×16 Pixel) eines
  Bildes; wird über alle Frames eines Bildes hinweg dedupliziert gezählt.
- **Kontext-/Pause-Ansicht**: Zeigt die Tile-Übersicht (bis zu 120
  Vorschauen), die Gesamt-Tile-Anzahl sowie Metainformationen (u. a.
  Frame-Anzahl) zum aktuellen Bild, zusätzlich zu den Standard-Pause-
  Funktionen.
- **Titelscreen-Auswahl**: Das aktuell hervorgehobene Bild auf dem
  Titelscreen, dargestellt als animierter Vollbild-Hintergrund mit
  VHS-Griesel-Effekt; alle übrigen Bilder bleiben statische
  Kreis-Miniaturen.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nutzer, die den Crank vor Abschluss einer vollen Umdrehung
  einklappen, behalten in 100% der Fälle exakt den zuvor angezeigten
  Frame — kein einziger ungewollter Frame-Wechsel durch Teildrehungen.
- **SC-002**: Die Bauchbinde ist in 100% der Testfälle spätestens 5
  Sekunden nach der letzten Eingabe ausgeblendet und erscheint bei
  erneuter Eingabe nie auf derselben Bildschirmhälfte wie die aktuelle
  Cursor-Position.
- **SC-003**: Nutzer können im Zoom-View für jede 2×2-Editierzelle alle 4
  zugrunde liegenden Einzelpixel visuell unterscheiden — 0 unsichtbare
  Pixel-Details gegenüber der Quellauflösung.
- **SC-004**: Nutzer erkennen den vollständigen animierten Bildinhalt
  eines auf dem Titelscreen ausgewählten Bilds, ohne den Editor zu
  öffnen — 100% der vorhandenen Animationsframes werden im
  Vollbild-Hintergrund durchlaufen.
- **SC-005**: Nutzer sehen in der Kontext-/Pause-Ansicht unabhängig von
  der Bildgröße die korrekte Gesamt-Tile-Anzahl sowie mindestens die
  Frame-Anzahl als Metainformation.
- **SC-006**: Ein Frame kann per "Reset Frame" in unter 3 Sekunden auf den
  Stand seines Vorgänger-Frames zurückgesetzt werden, ohne dass der
  Nutzer manuell neu zeichnet.

## Assumptions

- Die B+Crank-Zoomkette (Zoomstufen-Navigation, siehe Spec 003) ist von
  dieser Änderung nicht betroffen; die Volldrehungs-Anforderung
  (FR-004/FR-005) gilt ausschließlich für die reine Frame-Navigation ohne
  gedrückte B-Taste.
- "Cursor" bezeichnet die aktuell im Tile-Grid per D-Pad ausgewählte
  Position, nicht einen Mauszeiger. Da die Bauchbinde stets am unteren
  Bildschirmrand sitzt, genügt für die Positionslogik (FR-003) die
  horizontale Bildschirmhälfte des Cursors (links/rechts).
- "Reset Frame" überschreibt den Zielframe ohne zusätzliche
  Sicherheitsabfrage — konsistent mit der bestehenden "delete
  frame"-Aktion, die ebenfalls ohne Rückfrage ausgeführt wird.
- Übersteigt die Anzahl unterschiedlicher Tiles eines Bildes die 120
  Vorschauplätze der Kontext-/Pause-Ansicht, werden nur die ersten 120
  (nach Erstellungsreihenfolge) als Vorschau dargestellt; die separat
  ausgewiesene Gesamtzahl (FR-011/FR-013) bleibt davon unberührt und
  zeigt stets den echten Wert.
- Die im Transkript genannten Pause-Optionen "Volume", "Home" und
  "Screenshot" sind bestehende, vom Playdate-Betriebssystem
  bereitgestellte Pause-Funktionen. Diese Spec fügt ausschließlich die
  neuen, bildbezogenen Inhalte hinzu (Tile-Übersicht, Metainformationen,
  Reset Frame) und verändert die OS-Funktionen selbst nicht.
- Wie die erweiterte Kontext-/Pause-Ansicht technisch umgesetzt wird
  (z. B. als eigener In-Game-Screen anstelle des nativen System-Menüs),
  ist aus fachlicher Sicht bewusst offengelassen und wird in der
  Planungsphase mit SDK-Verifikation geklärt (siehe Architecture
  Governance unten).
- "Animierter Hintergrund" auf dem Titelscreen (FR-016) bedeutet das
  Abspielen der eigenen Animationsframes des ausgewählten Bilds in
  derselben Reihenfolge wie im Editor — nicht eine zusätzliche
  Schwenk-/Zickzack-Bewegung. Eine im selben Transkript zunächst
  diskutierte Zickzack-Bewegung des Bildausschnitts innerhalb des Kreises
  wurde vom Nutzer noch im gleichen Gespräch zugunsten dieses
  Vollbild-Ansatzes verworfen und ist nicht Teil dieser Spec.

---

## Dependencies

- **Spec 002 (Start/Selection Screen)**: Definiert `SelectionRoom` mit der
  Kreis-Darstellung der Bilder, die um den animierten Vollbild-Hintergrund
  (US6) erweitert wird.
- **Spec 003 (Editor-Umbau — Animation und Zoomstufen)**: Definiert
  `EditorRoom` (Frame-Modell, Crank-Navigation, System-Menü),
  `ZoomRoom`/`PixelRoom` (Zoomstufen, 8×8-Grid über 16×16-Pixel-Tiles) und
  das bestehende `Bauchbinde`-Modul, die alle von dieser Spec erweitert
  werden.
- **Playdate SDK**: Crank-Messung (`playdate.getCrankChange`/
  `getCrankTicks`), System-Menü (`playdate.getSystemMenu`, bekanntes
  3-Slot-Limit gemäß Spec 004), Grafik-Primitiven für Vollbild- und
  Rasterzeichnung.

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Applicable — Bausteinsicht
  (`Bauchbinde`-Modul, `EditorRoom`-Crank-Handling, `ZoomRoom`-Rendering,
  `SelectionRoom`-Titelscreen, neue Kontext-/Pause-Ansicht),
  Laufzeitsicht (Crank-Interaktion inkl. Inaktivitäts-Timer,
  Bild-Animationswiedergabe auf dem Titelscreen), Qualitätsmerkmale
  (Bedienbarkeit/Usability, visuelle Korrektheit).
- **Qualitätsszenarien**: Applicable —
  - Usability: "Klappt ein Nutzer den Crank nach einer Teildrehung ein,
    bleibt der zuvor angezeigte Frame unverändert erhalten" (SC-001).
  - Korrektheit: "Wechselt ein Nutzer vom Tile-View in den Zoom-View,
    zeigt der Hintergrund exakt die 16×16-Pixel-Quelldaten, nicht eine
    vergröberte Näherung" (SC-003).
- **Erwartete Evidenz unter `docs/architecture/`**: Open — aktuell
  existiert dort nur `docs/architecture/security-review-backend.md`
  (Backend-Sicherheitsreview, thematisch nicht einschlägig). Für dieses
  rein clientseitige UI-Feature wird in der Planungsphase geprüft, ob ein
  Update der arc42-Kapitel 5/6 (Bausteine `EditorRoom`/`ZoomRoom`/
  `SelectionRoom`, Laufzeitszenarien Crank/Bauchbinde/Titelscreen-
  Animation) genügt oder ein eigenes Artefakt unter `docs/architecture/`
  sinnvoll ist. Owner: Entwickler (Solo-Projekt); Re-Evaluierungs-Trigger:
  `/speckit-plan`-Lauf für diese Spec.
- **ADR erforderlich**: Open — Kandidat: Entscheidung, wie die erweiterte
  Kontext-/Pause-Ansicht (Tile-Übersicht + "Reset Frame", US5/US4)
  technisch realisiert wird. Hintergrund: Spec 004 stellte bereits fest,
  dass das Playdate-SDK maximal drei eigene System-Menü-Einträge erlaubt
  (`playdate.getSystemMenu()`) und dass `EditorRoom` dieses Limit bereits
  vollständig ausschöpft ("save + exit", "delete frame", "show grid");
  zusätzlich kann das native System-Menü keine eigene Grafik wie ein
  Tile-Raster rendern. Owner: Entwickler; Re-Evaluierungs-Trigger:
  SDK-Verifikation in der Planungsphase (Constitution Prinzip I), analog
  zur Entscheidung AD-029 in Spec 004 (Crank-Geste statt Menü-Eintrag für
  Sync).
- **Sicherheitsrelevante Architektur**: N/A — reine lokale UI- und
  Eingabe-Änderungen ohne Netzwerk-, Authentifizierungs- oder
  Datenspeicherungs-Bezug; keine Berührung der Sync-/Backend-Funktionalität
  aus Spec 004/005.
- **Risiken**: Applicable —
  - Menü-Slot-Knappheit (siehe ADR-Punkt oben) kann in der Planungsphase
    eine Konsolidierung bestehender Menüpunkte erzwingen und damit den
    Zugriffsweg auf "delete frame"/"show grid" verändern.
  - Tile-Anzahl > 120 (FR-013) ist bei umfangreichen, detailreichen
    Animationen real möglich und erfordert eine im UI klar kommunizierte
    Trunkierung, damit Nutzer die Gesamtzahl nicht mit der Anzahl
    sichtbarer Vorschauen verwechseln.
- **Technische Schuld**: N/A — kein bekannter Bezug zu bestehender
  technischer Schuld für dieses Feature.
