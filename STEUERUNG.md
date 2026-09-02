# Hans Dither – Räume & Steuerung

Referenz für jeden Room der App: was er tut, was man dort machen kann, die
komplette Tastenbelegung (inkl. der tastenlosen **Schüttelgeste**) und die
Einträge im Playdate-Systemmenü („Kontextmenü", erreichbar über die
⊞-Menütaste).

Stand: `Source/pdxinfo` buildNumber 32 · Spec 011 (Schüttel-Undo) enthalten.

---

## Navigationskarte

```
TitleRoom ──A──▶ SelectionRoom ──A auf Bild──▶ EditorRoom  (Tile View)
                       ▲                            │  ▲
                       │ „save + exit"              │  │ B halten + Kurbel vor / zurück
                       └────────────────────────────┘  │
                                                       ▼
                                                  ZoomRoom  (Zoom View)
                                                       │  ▲
                                     B halten + Kurbel  │  │ B halten + Kurbel zurück
                                     vor                ▼  │
                                                  PixelRoom  (Pixel View)

EditorRoom ──B halten + Kurbel zurück──▶ FrameManagementView ──B loslassen──▶ EditorRoom
```

- **TitleRoom** ist eine Einbahnstraße – nur vorwärts.
- **SelectionRoom** ist die Basis-Ebene: B führt dort *nicht* zurück.
- Aus dem Editor geht es nur über **„save + exit"** zurück zur Auswahl.
- Innerhalb der Zoomkette (Tile → Zoom → Pixel) navigiert **B halten + Kurbel**
  in beide Richtungen.

---

## Durchgehende Konzepte

### Systemmenü = „Kontextmenü"
Die Playdate-⊞-Taste öffnet das Systemmenü. Jeder Room registriert beim
Betreten **seine eigenen** bis zu drei freien Slots (bzw. räumt sie leer).
Die Slots sind unten je Room aufgeführt.

### Pause-Bild
Wird die ⊞-Taste in Tile-/Zoom-/Pixel-View gedrückt, zeigt die rechte
Menühälfte automatisch ein generiertes Übersichtsbild: Anzahl referenzierter
Kacheln, Frame-Anzahl und eine Vorschau der ersten bis zu 120 Kacheln.

### „Dirty-Flag"-Rendering
Alle Räume zeichnen nur nach einer Zustandsänderung neu; der letzte
Framebuffer bleibt sonst stehen.

### Beschleunigungssensor
Läuft nur in Tile-, Zoom- und Pixel-View (Start beim Betreten, Stopp beim
Rücksprung zur Auswahl). In Title-/Selection-Screen und FrameManagementView
ist er aus (Batterie). Er wird ausschließlich für die Schüttelgeste
(nächster Abschnitt) ausgewertet.

---

## Die Schüttelgeste – Undo für riskante Operationen

Die einzige Eingabe der App, die **keine Taste** benutzt. Sie nimmt eine der
letzten bis zu **3 riskanten Operationen** zurück.

### Ausführen
Das Playdate **einmal kurz und deutlich nach links und wieder nach rechts
kippen** (Bewegung entlang der Längsachse, wie ein „Nein"-Schütteln). Es
zählt nur die *Sequenz* links→rechts – bloßes Rütteln oder eine einseitige
Bewegung löst nichts aus. Zwischen zwei Erkennungen liegt eine kurze
Abklingzeit (~1,2 s). Die genaue Bewegungsstärke wird noch auf echter
Hardware feinjustiert.

### Wo sie wirkt

| Room | Schüttelgeste |
|---|---|
| **Tile View** (EditorRoom) | aktiv |
| **Zoom View** (ZoomRoom) | aktiv – bei „(A) Ja" wird committet und in den Tile View gewechselt |
| **Pixel View** (PixelRoom) | aktiv – bei „(A) Ja" wird committet und in den Tile View gewechselt |
| **FrameManagementView** | **inaktiv** (B ist durch die Halte-Eintrittsgeste belegt); ein hier gelöschter Frame ist trotzdem rücknehmbar, sobald man zurück im Tile View ist |
| Title- / SelectionRoom | inaktiv |

Während eines Lade- oder Speichervorgangs im Editor ist die Geste ebenfalls
gesperrt.

### Was passiert beim Schütteln

- **Gibt es eine rücknehmbare Operation** → modaler Dialog „Undo
  &lt;Operation&gt;?".
- **Gibt es keine** → nur eine kurze Statuszeile („Nothing to undo" bzw.
  „cannot undo – frame limit", wenn ein Frame-Undo an der 12-Frame-Grenze
  scheitert), **kein Dialog**.

### Der Dialog

| Eingabe | Wirkung |
|---|---|
| **A** | Ja – Operation rückgängig machen, Dialog schließen |
| **B** | Nein – Dialog schließen, nichts ändern |
| D-Pad / Kurbel / A-Strich | wirkungslos – der Dialog schluckt alle übrigen Eingaben, es passiert keine Editier-Aktion und kein Raumwechsel |
| erneutes Schütteln | wirkungslos |

### Rücknehmbare Operationen (der 3er-Verlauf)

| Operation | ausgelöst in / durch |
|---|---|
| **Clear Screen** | Tile View, Systemmenü „clear screen" |
| **Frame löschen** | FrameManagementView, 2× A auf dem markierten Frame |
| **90°-Pixel-Rotation** | Pixel View, volle Kurbeldrehung ohne B |
| **Pixel-Verschiebung** | Zoom View, B halten + D-Pad – **eine ganze B-Halte-Geste = ein Undo-Schritt** |

Normales Malen einzelner Pixel oder Kacheln wird **nicht** erfasst. Der
Verlauf hält nur die letzten 3 dieser Operationen (die vierte verdrängt die
älteste); es sind also bis zu 3 Undos hintereinander möglich. Beim Laden
eines anderen Bildes oder beim Verlassen des Editors ist der Verlauf leer.
Kein Redo.

---

## 1. TitleRoom – Startscreen

**Zweck:** Splash-Screen. Zeigt das zuletzt bearbeitete Bild als Hintergrund
(sonst ein Dither-Grau), darüber Titel-, Build- und Versionszeile, unten
„Press A".

**Was man tun kann:** nur weiter zum Auswahlscreen.

| Eingabe | Wirkung |
|---|---|
| **A** | weiter zum SelectionRoom |
| alle anderen | keine |

**Systemmenü:** keine eigenen Einträge.

---

## 2. SelectionRoom – Bild-Auswahl (Hub der App)

**Zweck:** 3×3-Kreisraster aller gespeicherten Bilder plus ein „+ New
Image"-Eintrag. Endloses vertikales Scrollen. Der selektierte Eintrag zeigt
einen doppelten Ring und einen leicht hin- und herschwenkenden
Bildausschnitt; unten links steht sein Name.

**Was man tun kann:** Bild auswählen und öffnen, neues Bild anlegen, Bild
kopieren, Bild löschen, ein Bild per Kurbel-Geste zum Backend synchronisieren.

### Steuerung

| Eingabe | Wirkung |
|---|---|
| **D-Pad hoch/runter** | Auswahl eine Rasterzeile nach oben/unten |
| **D-Pad links/rechts** | Auswahl eine Spalte nach links/rechts (kein Zeilenumbruch) |
| **A** auf einem Bild | Editor mit diesem Bild öffnen |
| **A** auf „+ New Image" | Bildschirmtastatur für den Namen öffnen |
| **B** | schließt einen offenen Dialog / bricht die Namenseingabe ab; sonst wirkungslos (kein Rücksprung zum Titel) |
| **Kurbel im Uhrzeigersinn, kumuliert ≥ 720°** (bei selektiertem Bild) | Sync dieses Bildes zum Backend startet |

### Namenseingabe (SDK-Tastatur)
Das Raster bleibt sichtbar, unten läuft die Eingabezeile mit. **OK** übernimmt
den Namen (bei Kollision automatisch Suffix `-1`, `-2`, …) und öffnet direkt
den Editor. **B** bricht ab.

### Lösch-Bestätigung

| Taste | Wirkung |
|---|---|
| **A** | Bild endgültig löschen |
| **B** | abbrechen |

### Sync-Ergebnisscreen (nach erfolgreichem Upload)
Vollbild-QR-Code + PIN zur Ansicht im Web. **B** schließt ihn.

### Systemmenü

| Eintrag | Wirkung |
|---|---|
| **new image** | wie „A" auf „+ New Image" – Namenstastatur |
| **copy image** | dupliziert das selektierte Bild, selektiert die Kopie |
| **delete image** | öffnet die Lösch-Bestätigung für das selektierte Bild |

`copy`/`delete` wirken nur, wenn ein Bild (kein „+ New Image") selektiert ist.

---

## 3. EditorRoom – „Tile View" (Haupteditor)

**Zweck:** 25×15-Raster aus 16×16-Kacheln auf den vollen 400×240 Pixeln. Die
Hauptarbeitsfläche: Kacheln setzen/löschen, Ebenen und Animationsframes
wechseln, in die Zoomstufen einsteigen.

**Datenmodell:** Jeder Frame hat **fest 3 Ebenen**. Editiert wird immer nur die
**aktive Ebene** (Indikator in der Bauchbinde). Der „Nicht-Tinte"-Zustand ist
Weiß auf Ebene 1 und transparent auf den Ebenen 2–3.

**Was man tun kann:** malen/radieren, aktive Kachel per Pipette oder
Tile-Picker wählen, Ebene wechseln, Frame wechseln/anlegen, Zoomstufe öffnen,
Frame-Verwaltung öffnen, aktive Ebene leeren (Clear Screen), Gitter ein-/
ausblenden, speichern & verlassen, riskante Operation per Schütteln
zurücknehmen.

### Steuerung

| Eingabe | Wirkung |
|---|---|
| **D-Pad** (kurz / gehalten) | Cursor eine Kachel weiter; Halten wiederholt |
| **A** | Strich beginnen: die Cursor-Zelle toggelt zwischen *aktiver Kachel* und Weiß (Radierer). Ohne gewählte aktive Kachel: toggelt zwischen Weiß und Schwarz |
| **A gehalten + D-Pad** | malt denselben Strichwert in die überstrichenen Zellen weiter |
| **B (kurzer Tipp)** | Pipette: Kachel unter dem Cursor wird aktive Kachel; auf Weiß = Abwahl. Kurz „Tile N picked" |
| **B halten + hoch / runter** | aktive Ebene +1 / −1 (Umlauf 1→2→3→1) |
| **B halten + links / rechts** | Frame zurück / vor. **Rechts am letzten Frame** legt einen neuen Frame an (tiefe Kopie, max. 12) |
| **B halten + Kurbel vorwärts** | Zoom hinein → Zoom View |
| **B halten + Kurbel rückwärts** | Frame-Verwaltung öffnen |
| **Kurbel ohne B** | Tile-Picker-Overlay: je ca. 30° Netto-Drehung eine referenzierte Kachel weiter (Umlauf); blendet 1,5 s nach der letzten Drehung aus. Landet die Auswahl auf Weiß = Abwahl |
| **Schütteln (links-rechts)** | öffnet den Undo-Dialog für die letzte riskante Operation (Clear Screen / Frame löschen / Rotation / Pixel-Verschiebung); gibt es keine, erscheint nur eine kurze Meldung. Details: Abschnitt „Die Schüttelgeste" |

Während eines Lade-/Speichervorgangs sind alle Editier-Eingaben gesperrt –
auch die Schüttelgeste.

### Systemmenü

| Eintrag | Wirkung |
|---|---|
| **save + exit** | Bild speichern, zurück zur Auswahl |
| **clear screen** | leert die **aktive Ebene** des aktuellen Frames (trotz Namen nicht den ganzen Frame). Per Schütteln rücknehmbar |
| **show grid** | Häkchen: Kachel-Gitterlinien ein-/ausblenden |

---

## 4. ZoomRoom – „Zoom View" (mittlere Zoomstufe)

**Zweck:** 3×3-Kachel-Ausschnitt um die Editor-Cursorkachel, als 24×24-Zellen-
Malraster (jede Zelle = 2 native Pixel, dargestellt als vier
5×5-Subpixel-Quadranten). Für gröbere Pixelarbeit als der Pixel View, aber
feiner als der Tile View.

**Was man tun kann:** 2-Pixel-Zellen setzen/löschen, den Pixelinhalt einer
Kachel um 1 nativen Pixel in die Nachbarkachel schieben, tiefer in den Pixel
View zoomen, zurück in den Tile View committen, riskante Operation per
Schütteln zurücknehmen.

### Steuerung

| Eingabe | Wirkung |
|---|---|
| **D-Pad** (kurz / gehalten) | Zoom-Cursor eine Zelle weiter; Halten wiederholt |
| **A** | Strich beginnen: Zelle unter dem Cursor invertieren |
| **A gehalten + D-Pad** | malt denselben Strichwert weiter |
| **B halten + D-Pad** | **Pixel-Verschiebung**: der Inhalt der Cursor-Zelle wandert 1 nativen Pixel in Richtung der Pfeiltaste in die Nachbarkachel und bleibt dort (2-Kachel-Streifen, kein Wrap). Wiederholtes Drücken schiebt Spalte für Spalte weiter |
| **B loslassen** | schließt die laufende Verschiebe-Geste ab (= **ein** Undo-Schritt für die ganze Geste) |
| **B halten + Kurbel vorwärts** | Zoom hinein → Pixel View |
| **B halten + Kurbel rückwärts** | offene Zell-Edits committen, zurück in den Tile View |
| **Schütteln (links-rechts)** | Undo-Dialog; „(A) Ja" committet die offenen Edits und wechselt in den Tile View. Details: Abschnitt „Die Schüttelgeste" |

### Systemmenü
Keine eigenen Einträge – das Menü ist im Zoom View leer.

---

## 5. PixelRoom – „Pixel View" (innerste Zoomstufe)

**Zweck:** genau **eine** Kachel mit echten 16×16 Pixeln in einem großen
Malraster. Die feinste Bearbeitungsstufe, plus 90°-Rotation der Kachel.

**Was man tun kann:** einzelne Pixel setzen/radieren/transparent schalten, die
Kachel per Kurbel um 90° drehen, den ganzen Kachelinhalt invertieren, die
Bearbeitung optional auf *alle* Verwendungen dieser Kachel wirken lassen,
zurück in den Zoom View committen, Rotation per Schütteln zurücknehmen.

**3-Zustands-Malen:** Auf **Ebene 1** toggelt ein A-Strich Tinte ↔ Weiß. Auf
**Ebene 2–3** durchläuft er den Zyklus Tinte → Weiß → transparent → Tinte
(A auf Tinte radiert dort also direkt nach transparent).

### Steuerung

| Eingabe | Wirkung |
|---|---|
| **D-Pad** (kurz / gehalten) | Pixel-Cursor eine Zelle weiter; Halten wiederholt |
| **A** | Strich beginnen: Zustand der Cursor-Zelle einen Schritt weiterschalten (siehe 3-Zustands-Malen) |
| **A gehalten + D-Pad** | malt denselben Strichwert weiter |
| **B** | malt **nicht**. Einzelner B-Tipp: folgenlos |
| **B halten + Kurbel rückwärts** | offene Edits committen, Zoom heraus → Zoom View |
| **Kurbel ohne B** | Rotation: eine volle 360°-Drehung dreht die Kachel um 90° (Drehrichtung = Kurbelrichtung); Teildrehungen wirken nicht. Per Schütteln rücknehmbar |
| **Schütteln (links-rechts)** | Undo-Dialog (nimmt u. a. die Rotation zurück); „(A) Ja" committet und wechselt in den Tile View. Details: Abschnitt „Die Schüttelgeste" |

### Systemmenü

| Eintrag | Wirkung |
|---|---|
| **All Similar** | Häkchen: ist es gesetzt, wirken die Änderungen dieser Kachel **in-place auf alle Verwendungen** derselben Kachel über alle Frames hinweg (statt wie sonst eine neue, deduplizierte Kachel zu erzeugen) |
| **Invert** | vertauscht für die ganze Kachel der aktiven Ebene Tinte ↔ „Nicht-Tinte" (Weiß auf Ebene 1, transparent auf Ebene 2–3) |

---

## 6. FrameManagementView – Frame-Verwaltung

**Zweck:** Liste **aller** Animationsframes. Frames neu anordnen und löschen,
damit die Animation steuerbar bleibt. **Keine** Ebenen-Verwaltung – Ebenen
sind eine feste 3er-Struktur pro Frame.

**Erreichbar aus:** Tile View, **B halten + Kurbel rückwärts**.

**Was man tun kann:** einen Frame markieren, den markierten Frame verschieben,
den markierten Frame löschen (mindestens 1 Frame bleibt), zurück in den Tile
View.

### Steuerung

| Eingabe | Wirkung |
|---|---|
| **D-Pad hoch / runter** | Listen-Cursor bewegen (hebt eine bestehende Markierung auf) |
| **A** auf unmarkiertem Frame | diesen Frame markieren |
| **A** auf dem markierten Frame | markierten Frame **löschen** (abgelehnt, wenn nur noch 1 Frame übrig ist) – der zweite A-Druck ist die Zwei-Schritt-Bestätigung |
| **D-Pad links / rechts** | markierten Frame eine Position früher / später (an den Enden geklemmt; Cursor und Markierung folgen) |
| **B loslassen** | zurück in den Tile View (`currentFrame` wird in die evtl. kürzere/umsortierte Sequenz geklemmt) |

Ein hier gelöschter Frame ist per **Schütteln im Tile View** wieder
herstellbar – die Geste selbst ist in dieser Ansicht inaktiv (B ist durch die
Halte-Eintrittsgeste belegt).

### Systemmenü
Keine eigenen Einträge – das Menü ist in der Frame-Verwaltung leer.

---

## Kurzreferenz: „Wie komme ich …"

| Ziel | Weg |
|---|---|
| … vom Start in die Auswahl | **A** im TitleRoom |
| … von der Auswahl in den Editor | **A** auf einem Bild |
| … zurück aus dem Editor | Systemmenü **„save + exit"** |
| … in den Zoom View | Tile View: **B halten + Kurbel vorwärts** |
| … in den Pixel View | Zoom View: **B halten + Kurbel vorwärts** |
| … aus dem Pixel View heraus | **B halten + Kurbel rückwärts** |
| … aus dem Zoom View in den Tile View | **B halten + Kurbel rückwärts** |
| … in die Frame-Verwaltung | Tile View: **B halten + Kurbel rückwärts** |
| … einen neuen Frame anlegen | Tile View: **B halten + rechts** am letzten Frame |
| … die Ebene wechseln | Tile View: **B halten + hoch/runter** |
| … eine Kachel als Pinsel wählen | Tile View: **B kurz** (Pipette) oder **Kurbel ohne B** (Picker) |
| … eine riskante Aktion zurücknehmen | **Schütteln** (links-rechts), dann **A** |
| … ein Bild ins Web synchronisieren | Auswahl: Bild selektieren, **Kurbel im Uhrzeigersinn ≥ 720°** |
