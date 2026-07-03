# Quickstart: Validierung Start- und Auswahlscreen

**Feature**: 002-start-selection-screen | **Date**: 2026-07-03

Manuelle Simulator-Szenarien. Referenzen: [contracts/selection-ui.md](contracts/selection-ui.md), [data-model.md](data-model.md). Voraussetzung: Spec 001 (ImageStore) implementiert; Editor-Anbindung ggf. noch als Stub.

## Voraussetzungen

- Build `pdc Source HansDither.pdx`, Start im Playdate Simulator.
- Für Mengen-Szenarien: ≥ 12 Bilder über den Debug-Einstieg aus Spec 001 (T011) oder die UI anlegen.

## Szenario 1: Startscreen-Texte und Hintergrund (SC-005, FR-001..FR-003, US1/US2)

1. Frische Installation (Datenordner leeren), App starten.
2. **Erwartet**: Dither-Hintergrund; Texte "Hans Dither, 1 bit Pixel 'n Tile Editor" und "Version 0.3.0 - still under development - Press A"; A führt zum Auswahlscreen mit Neu-Eintrag.
3. Ein Bild anlegen/bearbeiten, App neu starten.
4. **Erwartet**: Startscreen zeigt dieses Bild als Hintergrund; Panels bleiben lesbar.

## Szenario 2: 3×3-Raster, Maskierung, Scrollen (SC-002, SC-003, FR-005..FR-007, US3)

1. 12+ Bilder anlegen; Auswahlscreen öffnen.
2. **Erwartet**: 9 Kreise sichtbar, Inhalte als unskalierte, kreisförmig maskierte Ausschnitte (Bildmitte); Reihenfolge = zuletzt bearbeitet zuerst.
3. Per D-Pad nach unten über die dritte Zeile hinaus navigieren, bis zum Ende (Neu-Eintrag) und zurück zum Anfang.
4. **Erwartet**: Zeilenweises Nachscrollen; alle Bilder erreichbar (bei 30 Bildern in < 30 s); Navigation stoppt am Anfang; keine leeren/verzerrten Zellen.

## Szenario 3: Direkter Einstieg in den Editor (SC-001, FR-008, US1)

1. Bild markieren, A drücken.
2. **Erwartet**: Editor öffnet direkt mit diesem Bild (bzw. Stub-Log vor Spec 003) — kein Zwischenscreen; vom Startscreen aus max. 3 Eingaben.

## Szenario 4: Neu, Kopieren, Löschen (SC-004, FR-009..FR-013, US4)

1. Menü → "new image": Name eingeben; danach Abbruch-Variante testen (Keyboard schließen ohne Bestätigung).
2. **Erwartet**: Mit Name → Editor mit neuem leeren Bild; bei Abbruch → keine Anlage, Raster unverändert. Kollisionsname → Hinweis + erneute Eingabe.
3. Menü → "copy image" auf einem Bild.
4. **Erwartet**: Kopie mit Suffix-Namen erscheint; Original unverändert; Kopie unabhängig editierbar.
5. Menü → "delete image": einmal mit B abbrechen, einmal mit A bestätigen.
6. **Erwartet**: B → nichts gelöscht; A → Eintrag verschwindet, Raster rückt nach, Selektionsregel greift; keine Geistereinträge (SC-004).

## Szenario 5: Leerzustand und Grenzfälle (FR-011, FR-012, Edge Cases)

1. Alle Bilder löschen.
2. **Erwartet**: Raster zeigt nur den Neu-Eintrag (selektiert); Startscreen fällt auf Dither-Hintergrund zurück.
3. Bei geschlossener App `preview.pdi` eines Bildes löschen; App starten.
4. **Erwartet**: Betroffener Kreis zeigt Platzhalter; Auswahl/Öffnen funktioniert weiter.
5. Während des Bestätigungsdialogs D-Pad/A/B-Kombinationen und Crank testen.
6. **Erwartet**: Nur A (löschen) und B (abbrechen) wirken; keine Navigation im Hintergrund.

## Szenario 6: R-13-Beobachtung (Performance)

1. Mit 30 Bildern Auswahlscreen öffnen und schnell durchscrollen.
2. **Erwartet**: Kein spürbares Ruckeln (Thumbnail-Cache greift); erster Aufbau der Sichtzellen ggf. kurz, danach flüssig. Auffälligkeiten hier notieren und ggf. in arc42 Kap. 11 (R-13) nachtragen.

---

## Validierung

### Durchgeführte Tests (Implementierungsstand: 2026-07-03)

| Szenario | Status | Datum | Befund |
|---|---|---|---|
| **Szenario 1** (Startscreen + Hintergrund) | ⏳ pending | - | Textanpassung und Hintergrund-Ladung implementiert, Test im Simulator ausstehend |
| **Szenario 2** (3×3-Raster, Scrollen) | ⏳ pending | - | Gridview + Thumbnail-Cache implementiert, Test ausstehend |
| **Szenario 3** (Direkter Editor-Einstieg) | ⏳ pending | - | Navigation + Stub-Übergabe implementiert, Test ausstehend |
| **Szenario 4** (Verwaltung) | ⏳ pending | - | Systemmenü + Dialoge implementiert, Test ausstehend |
| **Szenario 5** (Grenzfälle) | ⏳ pending | - | Grundlegende Fehlerbehandlung implementiert, Test ausstehend |
| **Szenario 6** (Performance) | ⏳ pending | - | Thumbnail-Cache implementiert, Performance-Test ausstehend |

### Implementierungsstatus

- ✅ **Phase 1 + 2 (Setup + Foundational)**: Abschlossen
- ✅ **US1 (P1, Direkter Einstieg)**: Abschlossen (bis auf Validierung)
- ✅ **US3 (P2, 3×3-Raster)**: Abschlossen (bis auf Validierung)
- ✅ **US4 (P2, Verwaltung)**: Abschlossen (bis auf Validierung)
- ✅ **US2 (P3, Hintergrund)**: Abschlossen (bis auf Validierung)
- ⏳ **Phase 7 (Polish)**: Ausstehend
