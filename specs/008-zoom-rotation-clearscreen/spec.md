# Feature Specification: Zoom-Room-Performance, Pixel-Rotation und vereinfachte Frame-Verwaltung

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-22

**Status**: Implementiert (auf echter Hardware validiert — siehe quickstart.md/tasks.md T005/T010/T015)

**Input**: User description: "Für das Projekt „Hans-Dither" müssen wir drei konkrete Anpassungen vornehmen: die Performance des Zoom Rooms verbessern, eine Rotationsfunktion für einzelne Pixel-Grids einführen und die Verwaltung von Frames vereinfachen. Der Zoom Room funktioniert, aber er ruckelt so stark, dass eine präzise Bedienung und das Setzen von Pixeln kaum möglich sind. Dadurch wird der Raum nicht so genutzt, wie er sollte. Ich vermute, dass hier zu viele Ressourcen verbraucht oder zu viele Berechnungen gleichzeitig durchgeführt werden. Wir müssen der Ursache auf den Grund gehen. Eine mögliche Lösung könnte sein, das Rendering so anzupassen, dass nicht bei jeder Interaktion der gesamte Screen neu gezeichnet wird, sondern nur die betroffenen Bereiche. Allerdings habe ich das Gefühl, dass es noch ein tieferliegendes Problem gibt, das die Navigation blockiert. Die Nutzbarkeit des Zoom Rooms muss also unbedingt verbessert werden. Zweitens, für den Pixel Room auf der untersten Ebene wünsche ich mir eine neue Funktion: Die erstellten Pixel-Bilder sollen sich um 90 Grad im Uhrzeigersinn drehen lassen. Technisch bedeutet das, dass bei einer vollen Umdrehung des Cranks die Position der Pixel entsprechend neu berechnet wird. Dies ermöglicht es, gedrehte Versionen eines Elements zu erstellen, ohne dass es zu Auflösungsproblemen kommt. Die dritte Anpassung betrifft die Verwaltung der Frames. Die ursprüngliche Idee, was bei versehentlich bemalten Frames passieren soll, lassen wir vorerst fallen. Stattdessen entfernen wir die Funktion 'Reset Frame' komplett. Ersetzt wird sie durch einen einfachen Befehl: 'Clear Screen'. Dieser Befehl nullt den Inhalt des aktuell aktiven Frames, sodass man von vorne beginnen kann."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Zoom Room ohne Ruckeln und Blockaden nutzen (Priority: P1)

Als Nutzer bewege ich den Cursor und male Pixel im Zoom Room, ohne dass die
Bedienung ruckelt, spürbar nachhinkt oder ganz blockiert — Cursorbewegung
und Pixel-Setzen fühlen sich dort genauso reaktionsschnell an wie im
Tile-Editor.

**Why this priority**: Ohne flüssige Bedienung ist der Zoom Room in der
Praxis kaum nutzbar für präzises Pixel-Arbeiten — genau das im Feature-Wunsch
benannte Kernproblem. Ohne diese Behebung bleibt der Raum unattraktiv,
unabhängig davon, welche weiteren Funktionen ergänzt werden.

**Independent Test**: Im Zoom Room den Cursor wiederholt in alle Richtungen
bewegen (auch bei gehaltener Richtungstaste über mehrere Sekunden) und dabei
Zellen malen — Bewegung und Malen bleiben durchgängig reaktionsschnell, ohne
Hänger, Aussetzer oder verlorene Eingaben.

**Acceptance Scenarios**:

1. **Given** der Zoom Room ist aktiv, **When** der Nutzer den Cursor bewegt
   oder eine Zelle malt, **Then** reagiert das System ohne wahrnehmbare
   Verzögerung — vergleichbar mit dem Tile-Editor.
2. **Given** der Nutzer hält eine Richtungstaste im Zoom Room gedrückt
   (Cursor-Wiederholung), **When** die Wiederholung über mehrere Sekunden
   läuft, **Then** bleibt die Bewegung durchgängig flüssig und blockiert zu
   keinem Zeitpunkt.
3. **Given** der Nutzer bewegt sich mit gehaltener A-Taste (malender Strich)
   über mehrere Zellen, **When** die Bewegung erfolgt, **Then** werden alle
   überstrichenen Zellen korrekt gesetzt, ohne dass Eingabe oder Anzeige ins
   Stocken geraten.
4. **Given** eine Nutzungsabfolge, bei der die Navigation im Zoom Room zuvor
   vollständig blockiert wirkte, **When** dieselbe Abfolge nach der
   Behebung wiederholt wird, **Then** bleibt die Navigation durchgängig
   reaktionsfähig.

---

### User Story 2 - Pixelbild im Pixel Room per Crank-Volldrehung rotieren (Priority: P2)

Als Nutzer drehe ich im Pixel Room den Crank eine volle Umdrehung vorwärts,
um das aktuelle 16×16-Pixelbild um 90° im Uhrzeigersinn zu drehen — so
entstehen gedrehte Varianten eines Elements, ohne dass ich sie manuell neu
zeichnen oder Auflösung einbüßen muss.

**Why this priority**: Wertvolle neue Gestaltungsfunktion, aber unabhängig
vom dringenderen Performance-Problem nutzbar; baut auf einem bereits
funktionierenden Pixel Room auf.

**Independent Test**: Im Pixel Room ein asymmetrisches Muster zeichnen, den
Crank eine volle Umdrehung vorwärts drehen — das Muster erscheint um 90° im
Uhrzeigersinn gedreht, jedes Pixel an seiner rechnerisch korrekten neuen
Position, ohne Pixelverlust oder Verzerrung.

**Acceptance Scenarios**:

1. **Given** im Pixel Room ist ein Pixelmuster gezeichnet, **When** der
   Nutzer den Crank eine volle 360°-Umdrehung vorwärts dreht, **Then** wird
   das gesamte 16×16-Bild exakt um 90° im Uhrzeigersinn gedreht — jedes
   Pixel an seiner neu berechneten Position, ohne Auflösungsverlust.
2. **Given** der Nutzer dreht den Crank nur teilweise (z. B. 180°), **When**
   keine volle Umdrehung erreicht wurde, **Then** bleibt das Bild
   unverändert (keine Zwischen-Rotation).
3. **Given** der Nutzer dreht den Crank vier volle Umdrehungen vorwärts
   hintereinander, **When** alle vier Drehungen verarbeitet wurden, **Then**
   entspricht das Ergebnis wieder exakt dem Ausgangsbild (4 × 90° = 360°).
4. **Given** eine Rotation wurde durchgeführt, **When** der Nutzer
   anschließend aus dem Pixel Room herauszoomt, **Then** wird das gedrehte
   Bild wie jede andere Änderung über den bestehenden Dedup-Commit-Pfad
   übernommen.

---

### User Story 3 - Aktiven Frame per "Clear Screen" leeren (Priority: P3)

Als Nutzer wähle ich im Systemmenü des Editors "Clear Screen", um den
Inhalt des aktuell aktiven Frames vollständig auf Weiß zurückzusetzen und
von vorne zu beginnen — ohne dass andere Frames davon betroffen sind.

**Why this priority**: Einfache, klar begrenzte Vereinfachung der
Fehlerkorrektur; weniger dringend als Performance und Rotation, aber schnell
und risikoarm umsetzbar.

**Independent Test**: In einem Frame ein Muster malen, "Clear Screen"
auswählen — der Frame ist vollständig weiß; ein anderer Frame (z. B. der
vorherige) bleibt unverändert.

**Acceptance Scenarios**:

1. **Given** der aktive Frame enthält gezeichnete Inhalte, **When** der
   Nutzer "Clear Screen" im Systemmenü auswählt, **Then** wird jede Zelle
   des aktiven Frames auf Weiß zurückgesetzt.
2. **Given** mehrere Frames existieren, **When** "Clear Screen" auf dem
   aktiven Frame ausgeführt wird, **Then** bleiben alle anderen Frames
   unverändert.
3. **Given** der Nutzer öffnet das Systemmenü des Editors, **When** er die
   verfügbaren Einträge betrachtet, **Then** existiert kein Eintrag
   "Reset Frame" mehr — stattdessen "Clear Screen".
4. **Given** der aktive Frame ist bereits vollständig weiß, **When**
   "Clear Screen" ausgeführt wird, **Then** bleibt der Frame unverändert
   (weiterhin vollständig weiß).

---

### Edge Cases

- Was passiert, wenn der Nutzer im Pixel Room mitten in einer Teildrehung
  (< 360°, ohne B) B drückt, um herauszuzoomen? Rotations-Akkumulator (ohne
  B) und Zoom-Akkumulator (mit B) bleiben getrennt, analog zum bestehenden
  Muster in EditorRoom (pro Aufruf genau eine Crank-Lese-API, CR-01) — eine
  unvollständige Rotation geht nicht in die Zoom-Zählung ein.
- Was passiert bei einer vollen Rückwärtsdrehung im Pixel Room? Das Bild
  wird symmetrisch um 90° gegen den Uhrzeigersinn gedreht (siehe
  Assumptions).
- Was passiert mit bestehender Zoom-Room-Funktionalität (Rasteranzeige,
  Subpixel-Darstellung, Invert, "All Similar", Out-of-Bounds-Verhalten,
  Dedup-Commit) nach der Performance-Behebung? Sie MUSS unverändert
  funktionieren — die Behebung darf keine Regressionen verursachen.
- Was passiert, wenn "Clear Screen" auf dem letzten verbleibenden Frame
  ausgeführt wird? Nur der Frame-Inhalt wird geleert; die Frame-Anzahl
  bleibt unverändert (kein Frame wird gelöscht).
- Was passiert mit bestehenden Prüfungen/Tests, die sich auf "Reset Frame"
  beziehen (z. B. Systemmenü-Inhalt)? Sie müssen durch entsprechende
  "Clear Screen"-Prüfungen ersetzt werden (Teil der Umsetzung, nicht dieser
  Spec).

## Requirements *(mandatory)*

### Functional Requirements

**Zoom Room Performance**

- **FR-001**: System MUSS die Ursache(n) für spürbares Ruckeln und/oder
  blockierende Navigation im Zoom Room ermitteln und beheben, sodass sich
  Cursorbewegung und Pixel-Malen dort so reaktionsschnell anfühlen wie im
  Tile-Editor.
- **FR-002**: System DARF bei Interaktionen, die nur einen Teil des
  24×24-Rasters betreffen (z. B. eine einzelne Cursorbewegung oder ein
  einzelner Zellen-Anstrich), NICHT das gesamte Zoom-Room-Bild neu
  berechnen bzw. zeichnen — nur der tatsächlich betroffene Bereich MUSS
  aktualisiert werden.
- **FR-003**: Die Navigation im Zoom Room DARF bei normaler durchgängiger
  Nutzung (gehaltene Richtungstaste, gleichzeitiges Malen, Rein-/
  Rauszoomen) NICHT hängenbleiben oder unreagibel werden.
- **FR-004**: Alle bestehenden Zoom-Room-Funktionen (Rasteranzeige,
  Subpixel-Darstellung, Invert, "All Similar", Out-of-Bounds-Verhalten,
  Dedup-Commit-Pfad) MÜSSEN nach der Performance-Behebung unverändert
  funktionieren.

**Pixel-Rotation**

- **FR-005**: Im Pixel Room MUSS eine volle (360°) Vorwärtsdrehung des
  Cranks das aktuelle 16×16-Pixelbild um genau 90° im Uhrzeigersinn drehen,
  wobei jedes Pixel exakt — ohne Resampling oder Auflösungsverlust — an
  seine neu berechnete Position verschoben wird.
- **FR-006**: Eine volle Rückwärtsdrehung des Cranks MUSS das Bild
  symmetrisch um 90° gegen den Uhrzeigersinn drehen.
- **FR-007**: Teildrehungen (< 360°) DÜRFEN KEINE sichtbare Rotation
  auslösen; erst eine vollständige Umdrehung MUSS die Rotation anwenden.
- **FR-008**: Die Rotation MUSS als Teil des bearbeitbaren Arbeitsbilds des
  Tiles behandelt werden und beim Verlassen des Pixel Room über den
  bestehenden Dedup-Commit-Pfad übernommen werden — wie jede andere
  Pixel-Änderung.
- **FR-009**: Die Rotationsfunktion MUSS ausschließlich im Pixel Room
  verfügbar sein und sich auf genau das aktuell geöffnete 16×16-Tile
  beziehen (nicht auf Zoom Room oder Editor).
- **FR-010**: Die Rotations-Eingabe (Crank ohne B) DARF die bestehende
  B+Crank-Zoom-Out-Geste im Pixel Room NICHT beeinträchtigen oder
  verfälschen.

**Vereinfachte Frame-Verwaltung**

- **FR-011**: System MUSS die Funktion "Reset Frame" vollständig entfernen
  — sie DARF über kein Menü und keine Eingabe mehr erreichbar sein.
- **FR-012**: System MUSS eine neue Funktion "Clear Screen" bereitstellen,
  die jede Zelle des aktuell aktiven Frames auf den weißen Grundzustand
  zurücksetzt.
- **FR-013**: "Clear Screen" DARF ausschließlich den aktuell aktiven Frame
  verändern; alle anderen Frames MÜSSEN unverändert bleiben.
- **FR-014**: "Clear Screen" MUSS über das Systemmenü des Editors
  erreichbar sein, an der Stelle, an der zuvor "Reset Frame" angeboten
  wurde.
- **FR-015**: Die Frame-Anzahl und -Reihenfolge DÜRFEN sich durch
  "Clear Screen" NICHT ändern — nur der Inhalt des aktiven Frames wird
  beeinflusst.

### Key Entities

- **Zoom-Room-Redraw-Bereich**: Der durch eine Interaktion tatsächlich
  veränderte Teil des 24×24-Rasters — Grundlage für die partielle statt
  vollständigen Neuzeichnung.
- **Pixel-Tile (Pixel Room)**: Das aktuell im Pixel Room geöffnete
  16×16-Pixelbild; Ziel der Rotation.
- **Rotations-Akkumulator**: Konzeptioneller Zähler, der volle
  360°-Kurbeldrehungen erkennt, bevor eine Rotation ausgelöst wird (analog
  zum bestehenden Frame-Navigations-Akkumulator).
- **Aktiver Frame**: Der gerade bearbeitete Animationsframe; Ziel von
  "Clear Screen".
- **Weißer Grundzustand**: Der leere/weiße Ausgangszustand einer Zelle bzw.
  eines Tiles, wie er auch beim Schwarz/Weiß-Toggle als Basis dient.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cursorbewegung und Pixel-Malen im Zoom Room reagieren auf
  Zielhardware ohne wahrnehmbare Verzögerung — genauso flüssig wie im
  Tile-Editor (keine spürbaren Aussetzer bei kontinuierlicher Nutzung über
  mehrere Sekunden).
- **SC-002**: Bei mindestens 20 aufeinanderfolgenden Cursor-Bewegungen
  inklusive gehaltener Richtungstaste im Zoom Room tritt in 100 % der
  Testdurchläufe keine Navigationsblockade auf.
- **SC-003**: Eine volle Vorwärtsdrehung des Cranks im Pixel Room dreht das
  Bild in 100 % der Testfälle exakt um 90° im Uhrzeigersinn, ohne
  Pixelverlust.
- **SC-004**: Vier aufeinanderfolgende volle Vorwärtsdrehungen ergeben in
  100 % der Testfälle wieder exakt das Ausgangsbild (Rundlauf-Nachweis
  über 360°).
- **SC-005**: Nutzer können eine gedrehte Variante eines Tiles mit einer
  einzigen physischen Aktion (eine Kurbelumdrehung) erzeugen, ohne ein
  einziges Pixel manuell neu zu setzen.
- **SC-006**: "Clear Screen" leert den aktiven Frame in einer einzigen
  Aktion vollständig; in 100 % der Testfälle bleiben dabei alle anderen
  Frames unverändert.
- **SC-007**: Die Funktion "Reset Frame" ist nach dieser Änderung an
  keiner Stelle der Benutzeroberfläche mehr auffindbar oder auslösbar.

## Assumptions

- Der genaue Ursachenbefund für das Ruckeln bzw. die Navigationsblockade im
  Zoom Room (Vermutung des Projektinhabers: vollständiges Neuzeichnen pro
  Interaktion, ggf. weitere tieferliegende Ursache) wird in der
  Planungsphase (research.md) verifiziert; diese Spec definiert die
  beobachtbare Erfolgsschwelle (flüssige, nicht blockierende Bedienung),
  nicht die konkrete technische Lösung.
- Eine "volle Umdrehung" des Cranks wird analog zum bereits etablierten
  Muster der Frame-Navigation (Spec 006, signierter Grad-Akkumulator bis
  ±360°) verstanden, um Konsistenz mit bestehendem Verhalten zu wahren
  (Constitution IV).
- Rückwärtsdrehung rotiert symmetrisch gegen den Uhrzeigersinn; die Notiz
  spezifiziert nur die Vorwärtsrichtung (im Uhrzeigersinn) explizit — die
  Rückwärtssymmetrie ist eine Annahme in Anlehnung an bestehende
  bidirektionale Crank-Muster (Frame-Navigation, Zoomkette).
- Der "weiße Grundzustand" für "Clear Screen" entspricht dem bereits
  bestehenden leeren/weißen Basiszustand, wie er auch beim
  Schwarz/Weiß-Toggle (Spec 003) verwendet wird.
- "Clear Screen" ersetzt "Reset Frame" in der Funktion; die exakte
  Menü-Anordnung/-Reihenfolge wird in der Planungsphase festgelegt.
- Eine Bestätigungsabfrage vor "Clear Screen" ist NICHT vorgesehen —
  konsistent mit den bestehenden, ebenfalls unbestätigten Menüpunkten
  ("reset frame", "save + exit"); der Projektinhaber lässt die
  ursprüngliche Schutzidee für versehentlich bemalte Frames bewusst
  fallen.
- Die seit Spec 006 im Code unbenutzte Funktion `deleteCurrentFrame()`
  sowie die durch diese Änderung neu unbenutzt werdende
  `resetCurrentFrameToPrevious()` werden in der Planungsphase bewertet
  (Entfernen vs. Belassen als toter Code, Constitution IV).
- Dieses Feature baut auf Spec 003 (Zoom Room/Pixel-Room-Definition) und
  Spec 006 (Crank-Volldrehungs-Muster, Einführung von "Reset Frame", die
  hiermit rückgängig gemacht wird) auf.

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Applicable — Laufzeitsicht (arc42
  Kap. 6: neue Rotations-Laufzeitszenarien im Pixel Room, verändertes
  Redraw-Verhalten im Zoom Room, neuer "Clear Screen"-Ablauf im Editor),
  Bausteinsicht (Kap. 5: ZoomRoom-Rendering-Baustein, PixelRoom-
  Rotationslogik, EditorRoom-Systemmenü), Qualitätsmerkmale (Kap. 10:
  Reaktionsfähigkeit/Performance im Zoom Room als neues bzw. verschärftes
  Qualitätsziel), Technische Schuld (Kap. 11: Umgang mit
  `resetCurrentFrameToPrevious()`/`deleteCurrentFrame()` nach Entfernen
  ihres Menü-Aufrufers).
- **Qualitätsszenarien**: Applicable —
  - Reaktionsfähigkeit: "Bewegt der Nutzer den Cursor oder malt er im Zoom
    Room, reagiert das System ohne wahrnehmbare Verzögerung, auch bei
    gehaltener Richtungstaste über mehrere Sekunden" (SC-001/SC-002).
  - Korrektheit: "Dreht der Nutzer den Crank im Pixel Room eine volle
    Umdrehung, wird das 16×16-Bild exakt um 90° gedreht, ohne Pixel- oder
    Auflösungsverlust; vier Drehungen ergeben wieder das Original"
    (SC-003/SC-004).
- **Erwartete Evidenz unter `docs/architecture/`**: N/A — `docs/architecture/`
  wird in diesem Projekt bisher ausschließlich für das Backend-
  Sicherheitsreview genutzt (Spec 005/007, `security-review-backend.md`);
  diese Spec betrifft ausschließlich die On-Device-Editor-Logik (Lua, kein
  Backend-/Netzwerk-Bezug). Re-Evaluierungs-Trigger: falls im Rahmen der
  Umsetzung doch Backend-/Netzwerk-Berührungspunkte entstehen (aktuell
  nicht erwartet). Stattdessen erwartete Evidenz in `arc42/`: aktualisierte
  Kapitel 05 (Bausteinsicht: ZoomRoom/PixelRoom/EditorRoom), 06
  (Laufzeitsicht: Rotations- und Clear-Screen-Szenarien, überarbeitetes
  Zoom-Room-Redraw-Szenario), 09 (Architekturentscheidungen:
  Redraw-Strategie, Rotationsmechanik, Menü-Ersetzung), 10
  (Qualitätsanforderungen), 11 (Risiken/Technische Schuld), 12 (Glossar:
  "reset frame"-Eintrag entfernen/ersetzen durch "clear screen") — im
  selben Änderungsschnitt (Constitution III). Owner: Entwickler;
  Re-Evaluierungs-Trigger: `/speckit-plan`-Lauf für diese Spec.
- **ADR erforderlich**: Ja — Kandidaten: (1) technischer Ansatz zur
  Behebung der Zoom-Room-Performance/Navigationsblockade (z. B. partielles
  Redraw vs. andere Optimierung, abhängig vom Ursachenbefund aus der
  Planungsphase), (2) Ersetzung von "Reset Frame" durch "Clear Screen" im
  Systemmenü (reversiert/ersetzt das AD-032-Verhalten aus Spec 006). Owner:
  Entwickler; Re-Evaluierungs-Trigger: Planungsphase (research.md), analog
  zum bisherigen ADR-Vorgehen (ADR-031/032 aus Spec 006).
- **Sicherheitsrelevante Architektur**: N/A — rein lokale
  Editor-Funktionalität ohne Netzwerk-, Persistenzformat- oder
  Berechtigungsänderung; kein Bezug zum Backend-Sync-Feature (Spec
  004/005/007). Re-Evaluierungs-Trigger: falls Rotation/Clear-Screen
  künftig Auswirkungen auf das Speicherformat (Spec 001) über die reine
  Pixel-/Frame-Inhaltsänderung hinaus haben sollten (aktuell nicht
  erwartet).
- **Risiken**: Applicable —
  - Der genaue Ursachenbefund für die Zoom-Room-Navigationsblockade ist
    zum Zeitpunkt dieser Spec noch offen (Vermutung des Projektinhabers,
    keine bestätigte Diagnose) — Scope-/Aufwandsrisiko, falls die Ursache
    tiefer liegt als reines Redraw-Verhalten. Owner: Entwickler;
    Re-Evaluierungs-Trigger: Root-Cause-Analyse in der Planungsphase.
  - Entfernen von "Reset Frame" ohne Ersatz-Schutzfunktion für
    versehentlich bemalte Frames ist eine bewusste, vom Projektinhaber
    getroffene Entscheidung (siehe Assumptions) — das Restrisiko für
    Datenverlust bei Fehlbedienung wird akzeptiert, nicht mitigiert.
- **Technische Schuld**: Applicable — `resetCurrentFrameToPrevious()`
  verliert ihren einzigen Aufrufer (analog zu `deleteCurrentFrame()` seit
  Spec 006/AD-032) und wird zu totem Code, sofern nicht aktiv entfernt;
  die Entscheidung "entfernen vs. belassen" ist in der Planungsphase zu
  treffen und zu dokumentieren (Constitution IV: Einfachheit vor Ausbau
  spricht für Entfernen statt Ansammeln toten Codes).
