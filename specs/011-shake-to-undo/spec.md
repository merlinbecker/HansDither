# Feature Specification: Schüttel-Undo für die letzten 3 riskanten Aktionen

**Feature Branch**: `feature/0.3-addons` (bestehender Branch — kein `before_specify`-Hook, kein neuer Branch angelegt)

**Created**: 2026-09-02

**Status**: Draft — Ready for Clarification/Planning

**Input**: User description (wörtlich, inkl. Abbruch am Ende): "wir sollten eine undo funktion einbauen, und zwar für die jeweils letzten 3 aktionen: wenn man das playdaten schüttelt (einmal nach links und rechts) dann kommt ein dialog, ob man die letzte aktion rückgängig machen möchte. wenn man bestätigt, wird die aktion wieder rückg"

> Der Eingabetext bricht mitten im Wort ab. Angenommene Vervollständigung: „… wird die Aktion wieder **rückgängig gemacht**." Diese Annahme ist in der Sektion *Assumptions* festgehalten; der Originaltext wurde nicht stillschweigend repariert.

---

## Clarifications

### Session 2026-09-02

- Q: Was zählt als eine einzelne „Aktion" (der 3er-Verlauf speichert die letzten 3 davon)? → A: **Nur große Operationen.** Normales Setzen/Toggeln einzelner Pixel oder Tiles wird NICHT einzeln in den Undo-Verlauf aufgenommen.
- Q: Welche Operationen sollen per Schüttel-Undo rückgängig gemacht werden können? → A: **Nur riskante Operationen** — konkret: **Clear Screen**, **Frame löschen**, **90°-Pixel-Rotation** und **Pixel-Verschiebung** (per-Tile-Shift). Einzelne Pixel-/Tile-Edits sind nicht abgedeckt.

Beide Antworten verstärken sich: Die Undo-Funktion adressiert ausschließlich die vier potenziell großflächig zerstörerischen Operationen, nicht das feingranulare Malen. Das hält das Feature klein (Constitution IV — YAGNI, harte einfache Grenzen sind erwünscht).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Versehentliche riskante Operation sofort zurücknehmen (Priority: P1)

Als Nutzer habe ich gerade eine große Operation ausgelöst, die ich nicht wollte — z. B. „Clear Screen" auf dem aktiven Frame, eine 90°-Rotation im Pixel-View, eine Pixel-Verschiebung im Zoom-View oder das Löschen eines Frames in der Frame-Verwaltung. Ich schüttle das Playdate **einmal nach links und rechts**. Es erscheint ein modaler Dialog, der die betroffene Operation benennt und fragt, ob ich sie rückgängig machen möchte. Bestätige ich mit **A**, wird der Zustand von unmittelbar vor dieser Operation exakt wiederhergestellt. Lehne ich mit **B** ab, passiert nichts.

**Why this priority**: Die vier abgedeckten Operationen können viel Arbeit in einem Schritt vernichten. Ohne Rücknahme muss der Nutzer den Inhalt manuell rekonstruieren. Dies ist der Kernnutzen des Features und für sich allein ein sinnvolles MVP.

**Independent Test**: Im Tile-View „Clear Screen" auf einem Frame mit Inhalt auslösen → Frame ist leer. Gerät einmal links-rechts schütteln → Dialog „Clear Screen rückgängig machen? (A) Ja (B) Nein" erscheint. A drücken → der vorherige Frame-Inhalt ist vollständig zurück. Denselben Ablauf für Rotation, Pixel-Verschiebung und „Frame löschen" wiederholen.

**Acceptance Scenarios**:

1. **Given** ein Frame mit Inhalt und danach ausgeführtem „Clear Screen", **When** der Nutzer das Gerät links-rechts schüttelt und im Dialog A drückt, **Then** ist der Frame-Inhalt exakt wie vor „Clear Screen"
2. **Given** eine soeben ausgeführte 90°-Rotation im Pixel-View, **When** der Nutzer schüttelt und A drückt, **Then** ist das Pixel-Grid in der Ausrichtung von vor der Rotation
3. **Given** eine soeben ausgeführte Pixel-Verschiebung im Zoom-View, **When** der Nutzer schüttelt und A drückt, **Then** stehen der Quell-Tile und sein betroffener Nachbar wieder auf dem Stand von vor der Verschiebung
4. **Given** ein in der Frame-Verwaltung gelöschter Frame, **When** der Nutzer (zurück im Tile-View) schüttelt und A drückt, **Then** ist der Frame an seiner ursprünglichen Position mit seinem Inhalt wieder vorhanden
5. **Given** ein erschienener Undo-Dialog, **When** der Nutzer B drückt, **Then** schließt der Dialog ohne jede Zustandsänderung
6. **Given** ein soeben ausgeführtes normales Bemalen einzelner Pixel/Tiles (keine riskante Operation seither), **When** der Nutzer schüttelt, **Then** bezieht sich der Dialog auf die letzte davor liegende riskante Operation — oder es erscheint die Leer-Verlauf-Meldung, falls es keine gibt

---

### User Story 2 - Bis zu drei riskante Operationen nacheinander zurücknehmen (Priority: P2)

Als Nutzer möchte ich mehrere Fehlgriffe hintereinander korrigieren können. Nach einer Bestätigung ist genau die jüngste riskante Operation zurückgenommen; schüttle ich erneut, kann ich die nächstältere zurücknehmen — insgesamt bis zu drei. Eine vierte riskante Operation verdrängt die älteste aus dem Verlauf, sodass immer nur die letzten drei zurücknehmbar sind.

**Why this priority**: Erhöht den Nutzwert deutlich, ist aber nicht MVP-kritisch — schon ein einzelner Undo-Schritt (US1) liefert Wert. Die Tiefe 3 ist eine bewusste harte Grenze (analog zum 12-Frame-Cap).

**Independent Test**: Drei riskante Operationen nacheinander ausführen (z. B. Clear Screen, dann Rotation, dann Pixel-Verschiebung). Dreimal je „Schütteln + A" → nach dem dritten Undo ist der Zustand wie vor allen drei Operationen. Ein viertes „Schütteln" zeigt die Leer-Verlauf-Meldung. Anschließend eine vierte riskante Operation ausführen, dann eine fünfte → nur die vierte und fünfte (plus die noch vorhandene) sind zurücknehmbar, die ursprünglich älteste nicht mehr.

**Acceptance Scenarios**:

1. **Given** drei riskante Operationen seit dem letzten Undo, **When** der Nutzer dreimal „Schütteln + A" ausführt, **Then** ist jede der drei Operationen in umgekehrter Reihenfolge zurückgenommen und der Zustand entspricht dem vor der ersten
2. **Given** ein Verlauf mit bereits drei Einträgen, **When** eine vierte riskante Operation ausgeführt wird, **Then** enthält der Verlauf die Einträge 2, 3 und 4; Eintrag 1 ist nicht mehr zurücknehmbar
3. **Given** ein leerer Verlauf, **When** der Nutzer schüttelt, **Then** erscheint kein Bestätigungsdialog, sondern eine kurze Meldung, und es ändert sich nichts

---

### User Story 3 - Sicherer, verständlicher Undo-Dialog (Priority: P3)

Als Nutzer möchte ich vor dem Rückgängigmachen sehen, was genau zurückgenommen wird, und ich möchte nicht, dass das Schütteln oder das Bedienen des Dialogs versehentlich im Editor malt, zoomt oder den Frame wechselt.

**Why this priority**: Verlässlichkeit und Klarheit runden das Feature ab. Ohne diese Eigenschaften bleibt es benutzbar, aber fehleranfällig — daher niedrigere Priorität als der Kernnutzen.

**Independent Test**: Undo-Dialog im Zoom-View öffnen. Bei offenem Dialog A, B, alle D-Pad-Richtungen und die Crank betätigen → weder wird gemalt/gezoomt noch bewegt sich der Cursor oder wechselt der Frame/Room; nur A bzw. B wirken auf den Dialog. Dialogtext nennt die konkrete Operation. Bei offenem Dialog erneut schütteln → keine Wirkung.

**Acceptance Scenarios**:

1. **Given** ein offener Undo-Dialog, **When** der Nutzer die Crank dreht oder D-Pad/andere Tasten drückt, **Then** verarbeitet ausschließlich der Dialog diese Eingaben; keine Mal-, Zoom-, Cursor- oder Frame-/Room-Aktion wird ausgelöst
2. **Given** ein offener Undo-Dialog, **When** der Nutzer erneut schüttelt, **Then** wird die zweite Geste ignoriert
3. **Given** eine erkannte Schüttel-Geste mit nicht-leerem Verlauf, **When** der Dialog erscheint, **Then** benennt sein Text die betroffene Operation (z. B. „Clear Screen", „Frame löschen", „Rotation", „Pixel-Verschiebung")
4. **Given** normales Halten und Bedienen des Geräts über zwei Minuten ohne bewusstes Schütteln, **When** keine Links-Rechts-Bewegung über dem Schwellwert auftritt, **Then** erscheint kein Undo-Dialog (kein Fehlalarm)

---

### Edge Cases

- **Leerer Verlauf**: Schütteln bei leerem Verlauf → kurze Meldung („Keine Aktion zum Rückgängigmachen"), kein Dialog, keine Änderung
- **Doppel-Schütteln**: Eine zweite Schüttel-Geste bei bereits offenem Dialog wird ignoriert (nicht als „Nein" gewertet, nicht als zweiter Undo)
- **Verlaufseintrag verweist auf gelöschten Frame**: z. B. „Clear Screen" auf Frame 2, danach Frame 2 gelöscht. Beim Undo wird der ungültige Eintrag übersprungen und verworfen; bleibt kein gültiger Eintrag, verhält sich das System wie bei leerem Verlauf
- **Wiedereinfügen sprengt das Frame-Limit**: Undo von „Frame löschen", während inzwischen wieder 12 Frames existieren → Undo wird abgelehnt, der Eintrag verworfen, der Nutzer erhält eine Meldung
- **Undo navigiert zum Ort der Wirkung**: Betrifft der Undo einen anderen Frame/Room als den aktuell sichtbaren, springt die Ansicht dorthin, damit das Ergebnis sichtbar ist
- **Geste außerhalb der Editor-Views**: Schütteln in Title-, Selection- oder Frame-Verwaltungs-View hat keine Wirkung
- **Normales Malen dazwischen**: Zwischen zwei riskanten Operationen ausgeführtes Pixel-/Tile-Malen erzeugt keinen Eintrag und ändert den Verlauf nicht; ein Undo kann das zwischenzeitliche Malen daher nicht zurücknehmen (bewusst — siehe Clarifications)
- **Rotation in 90°-Schritten**: Eine ausgeführte Rotation = ein Verlaufseintrag = ein Undo-Schritt (eine volle Drehung braucht bis zu vier separate Rotationen und damit vier Undos)
- **Gepufferte Pixel-Verschiebung**: Eine abgeschlossene Verschiebe-Geste (gemäß ADR-043 gepuffert bis zum Loslassen von B) zählt als eine Aktion; die genaue Abgrenzung zwischen „ein Tastendruck" und „eine Geste" ist ein offener Planungspunkt (siehe *Audit Evidence Applicability → Open*)
- **Bildwechsel / Editor verlassen**: Der Verlauf ist danach leer (reiner Sitzungszustand)
- **Speichern**: Leert den Verlauf nicht; ein nach dem Speichern ausgeführter Undo erzeugt lediglich wieder ungespeicherte Änderungen

---

## Requirements *(mandatory)*

### Functional Requirements

#### Verlaufsmodell (headless-testbar — Constitution V, Gate 1)

- **FR-001**: Das System MUSS einen geordneten Undo-Verlauf führen, der genau die letzten **3** riskanten Operationen enthält; eine vierte riskante Operation verdrängt die älteste (FIFO-Verdrängung)
- **FR-002**: Als riskante Operation MÜSSEN ausschließlich erfasst werden: **Clear Screen**, **Frame löschen**, **90°-Pixel-Rotation**, **Pixel-Verschiebung** (per-Tile-Shift). Das Setzen/Toggeln einzelner Pixel oder Tiles erzeugt KEINEN Verlaufseintrag
- **FR-003**: Ein Verlaufseintrag MUSS alle Daten enthalten, die zur exakten Wiederherstellung des Zustands vor der Operation nötig sind (betroffener Frame und Layer, plus vorheriger Inhalt bzw. der gelöschte Frame samt Position)
- **FR-004**: Ein bestätigtes Undo MUSS genau den jüngsten **gültigen** Verlaufseintrag anwenden und ihn danach aus dem Verlauf entfernen
- **FR-005**: Nach einem Undo MUSS der resultierende Zustand exakt dem Zustand unmittelbar vor der zurückgenommenen Operation entsprechen — bezogen auf Pixel-/Tile-Inhalt, Frame-Anzahl und -Reihenfolge sowie den aktiven Frame/Layer, soweit von der Operation betroffen
- **FR-006**: Ein Verlaufseintrag, der auf einen nicht mehr existierenden Frame verweist, MUSS beim Undo übersprungen und verworfen werden; bleibt danach kein gültiger Eintrag, MUSS sich das System wie bei leerem Verlauf verhalten (FR-009)
- **FR-007**: Das System MUSS das Wiedereinfügen eines gelöschten Frames ablehnen, wenn dadurch die harte Obergrenze von 12 Frames überschritten würde; der Eintrag wird verworfen und dem Nutzer wird mitgeteilt, dass diese Operation nicht rückgängig gemacht werden kann
- **FR-008**: Der Undo-Verlauf MUSS reiner Sitzungszustand sein: NICHT in das PDI-/JSON-Speicherformat geschrieben, geleert beim Laden eines anderen Bildes und beim Verlassen des Editors zur Auswahl. Speichern DARF den Verlauf NICHT leeren
- **FR-009**: Bei leerem Verlauf MUSS eine ausgelöste Undo-Anforderung ohne jede Zustandsänderung enden und eine kurze Rückmeldung anzeigen; es DARF kein Bestätigungsdialog erscheinen

#### Schüttel-Geste & Bestätigungsdialog (Simulator-/Hardware-Integration; Dialog-/Modalitätslogik teils headless-testbar)

- **FR-010**: Das System MUSS im Tile-, Zoom- und Pixel-View eine Links-Rechts-Schüttelbewegung des Geräts als Undo-Anforderung erkennen. In Title-, Selection- und Frame-Verwaltungs-View DARF die Geste NICHT ausgewertet werden
- **FR-011**: Die Gestenerkennung MUSS einen Bewegungsschwellwert und eine Entprellung verwenden, sodass normales Halten und Bedienen des Geräts die Geste nicht auslöst
- **FR-012**: Bei erkannter Geste und nicht-leerem Verlauf MUSS ein Bestätigungsdialog erscheinen, dessen Text die betroffene Operation benennt, mit den Optionen „(A) Ja" und „(B) Nein"
- **FR-013**: Der Bestätigungsdialog MUSS vollständig modal sein: solange er offen ist, MÜSSEN A, B, D-Pad und Crank-Bewegung ausschließlich vom Dialog verarbeitet werden; es DARF keine Mal-, Zoom-, Cursor- oder Frame-/Room-Aktion ausgelöst werden
- **FR-014**: „(A) Ja" MUSS das Undo gemäß FR-004/FR-005 ausführen und den Dialog schließen; „(B) Nein" MUSS den Dialog ohne Zustandsänderung schließen
- **FR-015**: Eine erneut erkannte Schüttel-Geste bei bereits offenem Dialog MUSS ignoriert werden
- **FR-016**: Betrifft ein Undo einen anderen Frame oder Room als den aktuell sichtbaren, MUSS das System dorthin navigieren, damit das Ergebnis für den Nutzer sichtbar ist
- **FR-017**: Das Accelerometer MUSS beim Betreten der Editor-Views aktiviert und beim Verlassen wieder deaktiviert werden (Batterieschonung)

#### SDK-First & Architekturdokumentation (Constitution I und III)

- **FR-018**: Die Schüttel-Erkennung MUSS auf der Accelerometer-Funktion des Playdate SDK aufsetzen. Da das SDK kein fertiges Shake-Ereignis bereitstellt, MUSS die dafür nötige Eigenlogik als Architekturentscheidung dokumentiert und begründet werden (arc42 Kap. 4 Lösungsstrategie und Kap. 9 Architekturentscheidungen); die Aktivierung des Accelerometers ist eine **neue Plattformfähigkeit** dieses Projekts und MUSS in Kap. 2 (Randbedingungen) bzw. Kap. 8 (Querschnittliche Konzepte) vermerkt werden
- **FR-019**: Der Bestätigungsdialog SOLL das bestehende modale Bestätigungsmuster aus `SelectionRoom` (Löschbestätigung: „(A) …", „(B) …", Blockade von Navigation/Crank) wiederverwenden statt ein neues Muster einzuführen (Constitution IV — bewährte Muster wiederverwenden)

### Key Entities *(include if feature involves data)*

- **Undo-Verlauf**: Geordnete Liste mit maximal 3 Verlaufseinträgen; jüngster Eintrag zuerst zurücknehmbar; FIFO-Verdrängung beim Überlauf; reiner Sitzungszustand, nicht persistiert
- **Verlaufseintrag**: Beschreibt eine zurücknehmbare riskante Operation — Operationstyp (Clear Screen / Frame löschen / Rotation / Pixel-Verschiebung), betroffener Frame und Layer, sowie die zur Wiederherstellung nötigen Daten (vorheriger Frame-/Tile-Inhalt bzw. gelöschter Frame + Ursprungsposition). Kann durch spätere Struktur-Änderungen ungültig werden
- **Schüttel-Geste**: Eine bewusste Links-Rechts-Bewegung des Geräts oberhalb eines Bewegungsschwellwerts, entprellt, die eine Undo-Anforderung erzeugt
- **Undo-Bestätigungsdialog**: Modaler Ja/Nein-Dialog in den Editor-Views; benennt die betroffene Operation; schluckt alle Eingaben außer A (Ja) und B (Nein)
- **Riskante Operation**: Sammelbegriff für die vier abgedeckten Operationen aus Spec 008 (Clear Screen, 90°-Rotation) und Spec 010 (Frame löschen, Pixel-Verschiebung)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nach jeder der vier riskanten Operationen kann der Nutzer sie mit „Schütteln + Bestätigen" vollständig rückgängig machen; der wiederhergestellte Zustand ist zu 100 % identisch mit dem Zustand vor der Operation (Pixel-/Tile-Inhalt, Frame-Anzahl, Frame-Reihenfolge)
- **SC-002**: Der Verlauf hält zu jedem Zeitpunkt höchstens die letzten 3 riskanten Operationen; nach 3 aufeinanderfolgenden Undos ohne neue riskante Operation ist der Verlauf leer
- **SC-003**: Normales Pixel-/Tile-Malen erzeugt keinen Verlaufseintrag: unmittelbar nach beliebig vielen Mal-Aktionen bezieht sich ein „Schütteln + Bestätigen" auf die zuletzt davor liegende riskante Operation bzw. meldet einen leeren Verlauf
- **SC-004**: Bei leerem Verlauf zeigt die Schüttel-Geste innerhalb von 1 s eine kurze Rückmeldung und keinen Bestätigungsdialog; es wird nichts verändert
- **SC-005**: Während der Undo-Dialog offen ist, löst in 0 von beliebig vielen Testeingaben (A, B, D-Pad, Crank) eine Mal-, Zoom-, Cursor- oder Frame-/Room-Aktion aus; nur A und B wirken
- **SC-006**: Bei bewussten Links-Rechts-Schüttelbewegungen wird die Geste in mindestens **9 von 10** Versuchen erkannt; bei normalem Halten/Bedienen über 2 Minuten tritt kein Fehlalarm auf. (Der konkrete Bewegungsschwellwert, der diese Quote erreicht, ist ein Hardware-Tuning-Parameter — siehe Audit *Open*)
- **SC-007**: Ein wiederhergestellter Zustand bleibt beim anschließenden Speichern und erneuten Laden erhalten (der Undo wirkt auf denselben Inhalt, den auch das Speicherformat abbildet)
- **SC-008**: Der Undo-Verlauf ist nach dem Laden eines anderen Bildes bzw. nach dem Verlassen des Editors zur Auswahl garantiert leer

## Assumptions

- **Eingabetext**: wörtlich übernommen inkl. Abbruch; angenommene Vervollständigung „… wird die Aktion wieder **rückgängig gemacht**"
- **Ein Bestätigen = ein Undo**: Ein „(A) Ja" macht genau die jüngste riskante Operation rückgängig. Für tiefere Rücknahme schüttelt der Nutzer erneut (bis zu 3×) — das ist die einfachste Lesart von „ob man die **letzte** Aktion rückgängig machen möchte"
- **Kein Redo**: Nicht angefragt, daher außerhalb des Scope (Constitution IV — YAGNI)
- **Geltungsbereich der Geste**: nur Tile-, Zoom- und Pixel-View; nicht Title-, Selection- oder Frame-Verwaltungs-View
- **Reiner Sitzungszustand**: Der Verlauf liegt nur im RAM, wird nicht in PDI/JSON persistiert → das native Speicherformat (Constitution II) bleibt unverändert
- **Verlaufs-Lebensdauer**: geleert beim Laden eines anderen Bildes und beim Verlassen des Editors; Speichern leert ihn nicht; Room-Wechsel (Tile↔Zoom↔Pixel) und Frame-Wechsel leeren ihn nicht
- **Sichtbarkeit**: Ein Undo darf die Ansicht zum betroffenen Frame/Room umschalten, damit das Ergebnis sichtbar ist
- **„Riskante Operationen" = genau vier**: Clear Screen (Spec 008), Frame löschen (Frame-Verwaltung, Spec 010), 90°-Pixel-Rotation (Spec 008), Pixel-Verschiebung (Spec 010 / ADR-043). **Frame umsortieren** und **Frame hinzufügen** sind NICHT abgedeckt (nicht zerstörerisch bzw. manuell trivial umkehrbar)
- **Pixel-Verschiebung als Einheit**: Eine abgeschlossene, gemäß ADR-043 gepufferte Verschiebe-Geste gilt als eine Aktion; die exakte Abgrenzung ist ein offener Planungspunkt
- **Accelerometer-Lebenszyklus**: wird beim Betreten der Editor-Views gestartet und beim Verlassen gestoppt. Dies ist eine **neue Plattformfähigkeit** — Spec 010 ging noch von „keine neuen Plattformfähigkeiten nötig" aus; das gilt mit diesem Feature nicht mehr
- **Dialog-Muster**: Wiederverwendung des bestehenden `SelectionRoom`-Bestätigungsdialogs (A = Ja, B = Nein, Blockade von Navigation/Crank)
- **Dialogtext**: benennt die betroffene Operation
- **Leerer Verlauf**: kurze Meldung statt Dialog
- **Doppel-Schütteln bei offenem Dialog**: ignoriert
- **Abhängigkeiten**: Spec 008 (Clear Screen, Rotation) ist umgesetzt; Spec 010 (Frame-Verwaltung „Frame löschen", Pixel-Verschiebung / ADR-043) muss vor bzw. mit diesem Feature vorliegen — zwei der vier zurücknehmbaren Operationen stammen daraus. Aktueller Stand laut Spec 010: „US1–US4 implementiert und grün auf `feature/0.3-addons`"

---

## Architecture Governance & Technical Debt

### Architecture Applicability

- **Betroffene Aspekte**: Laufzeitverhalten (neuer modaler Dialogfluss; Accelerometer-Polling und Gestenerkennung in den Editor-Views; Re-Compositing nach einem Undo), Bausteinsicht (neuer Undo-Verlauf-Baustein + Schüttel-Detektor; Einklinken in Clear Screen, Rotation, Pixel-Verschiebung und „Frame löschen"), Qualitätsmerkmale (Usability, Robustheit/Fehlererholung, Performance, Batterie). **Nicht betroffen**: Kontextabgrenzung (keine neue externe Schnittstelle), Verteilungssicht (keine Build-/Paketierungsänderung), Datenformate (Verlauf ist In-Memory, keine PDI-/JSON-Änderung)
- **Architekturziele & Randbedingungen mit Bezug zum Feature**:
  - *SDK-First (Constitution I)*: Accelerometer ist eine SDK-Primitive; ein Shake-Ereignis bietet das SDK nicht → begründete Eigenlogik, in arc42 zu benennen
  - *Native Formate (Constitution II)*: bleibt unberührt, da der Verlauf nicht persistiert wird — explizit als Entwurfsentscheidung festgehalten
  - *Einfachheit (Constitution IV)*: harte Obergrenze von 3 Einträgen und exakt 4 abgedeckte Operationstypen; Wiederverwendung des `SelectionRoom`-Dialogmusters
  - *arc42 (Constitution III)*: betroffene Kapitel sind 2, 4, 5, 6, 8, 9, 10, 11 (Aktualisierung in `/speckit-plan`, nicht hier)
- **Qualitätsszenarien** (dort, wo sie Abnahme/Design materiell beeinflussen):
  - *Robustheit*: Nach versehentlichem „Clear Screen" stellt „Schütteln + Bestätigen" den Frame-Inhalt in unter 1 s vollständig wieder her
  - *Performance*: Accelerometer-Polling + Gestenerkennung kosten pro Tick so wenig, dass die im Zoom-View (Spec 008) mühsam erreichte flüssige Bedienung messbar nicht schlechter wird
  - *Speicher*: Bis zu 3 Verlaufs-Snapshots (worst case je ein Frame mit 25×15 Zellen × 3 Layern bzw. ein gelöschter Frame) bleiben innerhalb eines noch festzulegenden RAM-Budgets; Mechanik (Voll-Snapshot vs. inverse Delta / Tile-Index-Referenzen) ist Planungsgegenstand
- **Architektur-Evidenz unter `docs/architecture/`**: **erforderlich**, umgesetzt über die Projektkonvention `arc42/09-architekturentscheidungen.md` + `arc42/adr/` (Constitution III schreibt `arc42/` vor; die Preset-Vorgabe `docs/architecture/` wird durch diesen etablierten Pfad erfüllt — dokumentierte Abweichung mit Begründung)
- **ADR erforderlich**: ja — drei ADRs:
  1. **„Schüttel-Gesten-Erkennung über Accelerometer"** — SDK bietet kein Shake-Event; Eigenlogik auf `playdate.readAccelerometer()` mit Schwellwert + Entprellung + Links-Rechts-Sequenz; Accelerometer nur in Editor-Views aktiv (Batterie)
  2. **„Undo-Modell: fixer 3-Schritt-Verlauf, nur riskante Operationen, reiner Sitzungszustand"** — Auswahl der vier Operationstypen; Voll-Snapshot vs. inverse Delta je Typ; keine Persistenz; harte Obergrenze 3 (analog 12-Frame-Cap)
  3. **„Modaler Undo-Bestätigungsdialog in den Editor-Views"** — Wiederverwendung des `SelectionRoom`-Bestätigungsmusters; schluckt A/B/D-Pad/Crank; A = Ja, B = Nein
- **Sicherheitsrelevante Architektur betroffen?**: **Nein** — rein lokale In-Memory-Funktion, kein Netzwerk, keine Secrets, keine Persistenz, keine neue Angriffsfläche. Der secure-architecture-Preset ist **N/A** (Begründung siehe *Audit Evidence Applicability*)
- **Begründete `N/A`-Entscheidungen**: Kontextabgrenzung (arc42 Kap. 3) und Verteilungssicht (Kap. 7) — siehe *Audit Evidence Applicability*

### Existing Dependencies & Compatibility

- **Spec 008 (Zoom-Performance, Pixel-Rotation, Clear Screen)** — liefert zwei der vier zurücknehmbaren Operationen (Clear Screen, 90°-Rotation)
- **Spec 010 (Layer-Management, Pixel-Verschiebung, Frame-Verwaltung)** — liefert die anderen zwei (Frame löschen in der `FrameManagementView`, Pixel-Verschiebung gemäß ADR-043); MUSS vor bzw. gemeinsam mit diesem Feature vorliegen
- **Bestehendes Room-/View-System** — Tile-, Zoom-, Pixel-View existieren; dieses Feature klinkt die Verlaufserfassung in die vier Operationspfade ein und ergänzt einen modalen Dialog je Editor-View
- **`SelectionRoom`-Bestätigungsdialog** — bestehendes Muster, das wiederverwendet wird
- **Playdate SDK** — Accelerometer-API (`playdate.startAccelerometer` / `readAccelerometer`) wird **neu** genutzt; alle anderen benötigten Fähigkeiten (Eingaben, Rendering) sind bereits im Einsatz

### Technical Debt & Risk Mitigation

- **Risiko: Fehlalarm der Schüttel-Geste** (Auslösen beim Laufen, Ablegen, hektischen Bewegungen)
  - *Mitigation*: Bewegungsschwellwert + erzwungene Links-Rechts-Sequenz + Entprellung; der Bestätigungsdialog als zweite Sicherung; Verifikation auf echter Hardware
- **Risiko: Accelerometer-Polling verschlechtert die Zoom-View-FPS** (Spec 008 hat diesen View mühsam flüssig bekommen)
  - *Mitigation*: leichtgewichtige Gestenerkennung; FPS-Messung auf Hardware; ggf. reduzierte Polling-Rate; Accelerometer nur in Editor-Views aktiv
- **Risiko: Snapshot-Speicher bei Undo von „Frame löschen"** — bis zu 3 volle Frames (25×15 Zellen × 3 Layer) im RAM
  - *Mitigation*: statt Bilddaten möglichst nur Tile-Index-Positionen + Referenzen auf bereits vorhandene Tiles kopieren; RAM-Budget in `/speckit-plan` festlegen und messen
- **Risiko: Verlaufseinträge werden durch spätere Struktur-Änderungen ungültig** (z. B. Ziel-Frame inzwischen gelöscht, Tile-Indizes durch Speichern/Bereinigung verschoben — Spec 009)
  - *Mitigation*: ungültige Einträge beim Undo überspringen und verwerfen; klare Nutzer-Meldung; Verlauf bei Bildwechsel ohnehin leeren
- **Risiko: Modaler Dialog kollidiert mit belegten Eingaben** in den Editor-Views (A = malen, B = Zoom-Out-Modifier, Crank = Zoom-Kette / Frame-Verwaltung)
  - *Mitigation*: FR-013 schreibt vollständige Modalität vor (alle Eingaben werden geschluckt, keine Room-Transition bei offenem Dialog); als Akzeptanzkriterium (SC-005) verankert

---

## Audit Evidence Applicability

Jeder anwendbare Checkpoint braucht konkrete Markdown-Evidenz; `N/A` braucht eine kurze Begründung; `Open` braucht Owner, Follow-up und Re-Evaluations-Trigger. Die eigentlichen arc42-Edits erfolgen in `/speckit-plan` (Memory-Regel „arc42 während Planung").

| Checkpoint | Status | Evidenz / Begründung / Follow-up |
|---|---|---|
| arc42 Kap. 2 — Randbedingungen | Applicable | `arc42/02-randbedingungen.md`: Accelerometer-Nutzung als neue Plattformfähigkeit ergänzen. Owner: `/speckit-plan` |
| arc42 Kap. 3 — Kontextabgrenzung | N/A | Keine neue externe Schnittstelle; das Accelerometer ist Hardware innerhalb des bereits abgegrenzten Geräte-Kontexts. Re-Evaluations-Trigger: falls die Geste über eine zusätzliche externe Anbindung (z. B. Simulator-Sondertaste als eigener Kanal) realisiert wird |
| arc42 Kap. 4 — Lösungsstrategie | Applicable | `arc42/04-loesungsstrategie.md`: Begründung der Shake-Eigenlogik auf SDK-Accelerometer + Undo-Snapshot-Strategie. Owner: `/speckit-plan` |
| arc42 Kap. 5 — Bausteinsicht | Applicable | `arc42/05-bausteinsicht.md`: neuer Undo-Verlauf-Baustein + Schüttel-Detektor + Einbindepunkte in die vier Operationen. Owner: `/speckit-plan` |
| arc42 Kap. 6 — Laufzeitsicht | Applicable | `arc42/06-laufzeitsicht.md`: Sequenz „Schütteln → Dialog → Bestätigen/Abbrechen → Zustandswiederherstellung / Navigation". Owner: `/speckit-plan` |
| arc42 Kap. 7 — Verteilungssicht | N/A | Keine Änderung an Build, Paketierung oder Deployment. Re-Evaluations-Trigger: falls Accelerometer-Kalibrier-/Konfigurationsdaten persistiert werden müssten |
| arc42 Kap. 8 — Querschnittliche Konzepte | Applicable | `arc42/08-querschnittliche-konzepte.md`: Eingabe-/Modalitätskonzept um den vollständig modalen Undo-Dialog und den Accelerometer-Lebenszyklus erweitern. Owner: `/speckit-plan` |
| arc42 Kap. 9 — Architekturentscheidungen (+ `arc42/adr/`) | Applicable | Drei ADRs anlegen (Schüttel-Erkennung; Undo-Modell; modaler Undo-Dialog) in `arc42/09-architekturentscheidungen.md` + `arc42/adr/`. Owner: `/speckit-plan` |
| arc42 Kap. 10 — Qualitätsanforderungen | Applicable | `arc42/10-qualitaetsanforderungen.md`: Qualitätsszenarien Robustheit / Performance / Speicher (siehe oben). Owner: `/speckit-plan` |
| arc42 Kap. 11 — Risiken & technische Schulden | Applicable | `arc42/11-risiken-und-technische-schulden.md`: fünf Risikoeinträge aus *Technical Debt & Risk Mitigation*. Owner: `/speckit-plan` |
| `docs/architecture/` Evidenzpfad (Preset-Vorgabe) | Applicable | Umgesetzt über `arc42/09` + `arc42/adr/` gemäß Constitution III (Pfad `arc42/` statt `docs/architecture/`); dokumentierte, begründete Abweichung |
| Secure-Architecture-Preset (iSAQB) | N/A | Rein lokale In-Memory-Funktion: kein Netzwerk, keine Secrets, keine Persistenz, keine neue Angriffsfläche, keine Rechte-/Vertraulichkeitsaspekte. Re-Evaluations-Trigger: falls der Undo-Verlauf je auf Platte oder ins Backend geschrieben wird |
| Constitution V — Gate 1 (`lua tests/headless_tests.lua`) | Applicable | Neue Headless-Tests für das Verlaufsmodell (FR-001…FR-009) in `tests/headless_tests.lua`; Lauf endet mit „ALLE TESTS BESTANDEN". Owner: `/speckit-tasks` + `/speckit-implement` |
| Constitution V — Gate 2 (`buildNumber` +1, dann `pdc`) | Applicable | `Source/pdxinfo` `buildNumber` 30 → 31 vor dem ersten Testbuild; `pdc Source "Hans Dither.pdx"` fehlerfrei. Owner: `/speckit-implement` |
| Manuelle Simulator-/Hardware-Integration | Applicable | Schüttel-Erkennung, Schwellwert, Fehlalarm-Freiheit, FPS im Zoom-View, Dialog-Modalität auf echter Hardware prüfen (separate Testphase, analog Spec 010 Phase 7). Owner: `/speckit-tasks` |

### Open

| Thema | Status | Owner | Follow-up | Re-Evaluations-Trigger |
|---|---|---|---|---|
| Granularität der Pixel-Verschiebung: zählt eine Verschiebe-Geste (bis B losgelassen) als ein Verlaufseintrag, oder feiner? | **Resolved (Plan 2026-09-02)** | `/speckit-plan` | Aufgelöst in `research.md` **R4**: ein „B-Halte-Run" = ein Eintrag (Snapshot beim Run-Start, weitere Shifts erweitern denselben Eintrag). `data-model.md` §4. | — |
| Wiederherstellungs-Mechanik je Operationstyp: Voll-Snapshot vs. inverse Delta vs. Tile-Index-Referenzen (RAM-Budget) | **Resolved (Plan 2026-09-02)** | `/speckit-plan` | Aufgelöst in `research.md` **R2/R3** + `data-model.md` §2: Voll-Snapshot je betroffener Zelle (vorheriger Index **und** vorheriges 16×16-Bild als Referenz); Frame löschen = tiefe Kopie. RAM-Budget < ~100 KB für 3 Einträge dokumentiert. Speicher-Umnummerierung geprüft: trifft die Live-`imageData` nicht. | Bei Hardware-Speichermessung |
| Verhalten der Schüttel-Geste in der `FrameManagementView` | **Resolved (Plan 2026-09-02)** | `/speckit-plan` | Aufgelöst in `research.md` **R6**: Geste dort nicht aktiv (B durch Halte-Geste belegt); der `deleteFrame`-Eintrag entsteht bei `deleteMarked()`, der Dialog erst nach Rückkehr in den Tile View. | — |
| Konkreter Bewegungsschwellwert der Schüttel-Erkennung, der die SC-006-Quote (9/10, fehlalarm­frei) erreicht | **Open** | Hardware-Test | Start-Parameter `T ≈ 0.85 g`, `W ≈ 500 ms`, `R ≈ 1200 ms` (`ShakeDetector`); Endwerte nach erstem Gerätetest in ADR-044 eintragen | Phase „Manuelle Hardware-Integration"; erneut bei Nutzer-Feedback zu Fehlauslösung |
| Verhalten der Geste in der `FrameManagementView` selbst (dort wird „Frame löschen" ausgelöst, B ist aber durch Halten belegt) | `/speckit-plan`-Autor | Klären, ob die Geste erst nach Rückkehr in den Tile-View greift (aktuelle Annahme) oder auch dort | Design der Dialog-Einbindung |

---

## Status Summary

**Draft, zwei Clarifications geklärt** (Session 2026-09-02): (1) nur „große" Operationen zählen als Aktion — feingranulares Malen wird nicht erfasst; (2) abgedeckt sind genau vier riskante Operationen (Clear Screen, Frame löschen, 90°-Rotation, Pixel-Verschiebung). Das Feature ist bewusst klein gehalten (Constitution IV).

**Offen für `/speckit-plan`**: arc42-Kapitel 2/4/5/6/8/9/10/11 aktualisieren, drei ADRs anlegen, die vier *Open*-Punkte (Pixel-Verschiebungs-Granularität, Wiederherstellungs-Mechanik/RAM-Budget, Erkennungsraten-Zielwert, Gesten-Verhalten in der `FrameManagementView`) auflösen.

**Nächster Schritt**: `/speckit-clarify` (optional — die vier *Open*-Punkte sind eher Planungs- als Scope-Fragen) oder direkt `/speckit-plan`.
