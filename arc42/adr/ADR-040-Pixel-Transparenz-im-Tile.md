# ADR-040: Pixel-Transparenz als `kColorClear` im Tile + 3-Zustands-Hash

## Status
✅ **Umgesetzt** (Spec 010, US2; 5. Runde 2026-09-01: B malt nicht mehr,
siehe Nachtrag) – `Source/PixelTransparency.lua`, `Source/PixelRoom.lua`,
`Source/ImageStoreCodec.lua` (`hashTile`, `imagesVisiblyEqual`)

## Kontext
Der fruehe data-model.md-Entwurf sah je Ebene ein zweites 375er-Array
`transparency` (0 = opak, 1 = transparent, 2 = leer) neben `positions`
vor. Zwei Anforderungen brechen dieses Modell:

1. **Pro Pixel, nicht pro Zelle**: der Nutzer setzt Transparenz
   ausschliesslich im PixelRoom (16×16-Raster). Ein per-Zelle-Wert kann
   „Pixel (6,5) transparent, (5,5) Tinte in derselben Zelle“ nicht
   ausdruecken (spec.md FR-006/FR-008, quickstart Szenario 2).
2. **Dedup**: spec.md Edge Case Z. 104 verlangt, dass zwei Tiles mit
   gleichem Ink-Muster aber unterschiedlichem Transparenzmuster **getrennt**
   dedupliziert werden — das geht nur, wenn Transparenz Teil des Tiles ist.

Zusaetzlich (3. Klarstellungsrunde): der „Nicht-Tinte“-Zustand ist
**ebenenabhaengig** — Ebene 1 toggelt Tinte ↔ **weiss** (ihr Hintergrund),
Ebenen 2–3 toggeln Tinte ↔ **transparent** (damit untere Ebenen
durchscheinen). Ebene 1 hat keinen Transparent-Zustand.

## Entscheidungs-Treiber
- **Constitution I/II**: Playdate-1-Bit-Bilder tragen nativ eine
  Transparenzmaske (`kColorClear`); kein eigenes Nebendaten-Format noetig.
- Die bestehende Sheet-Compose/Slice-Pipeline nutzt bereits
  `kColorClear`-Hintergruende und erhaelt transparente Pixel unveraendert.
- Alt-Tiles sind nur schwarz/weiss → jede Loesung muss fuer sie
  bit-identisch bleiben.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Transparenz als `kColorClear`-Pixel im Tile; `hashTile` auf 3 Klassen (schwarz/weiss/clear)** | pro Pixel; native Maske; Dedup trennt Varianten korrekt; kein Nebenarray | `hashTile`/`imagesVisiblyEqual` muessen von 2 auf 3 Klassen — kleiner, lokaler Eingriff |
| B: per-Zelle-`transparency`-Array (0/1/2) | einfaches Datenmodell, kompakt | kann keine gemischt-transparente Zelle; widerspricht der Dedup-Regel; ein B-Druck faerbt eine ganze 16×16-Zelle |
| C: separate Alpha-Ebene je Frame | „sauber“ getrennt | vierte Ebene je Frame; mehr Zustand; zusaetzliche Tilemap fuers Alpha; Perf-Kosten |

## Entscheidung
**Option A.** `PixelTransparency` fuehrt drei interne Codes
(`OPAQUE=0`, `TRANSPARENT=1`, `EMPTY=2`) und die Bruecke
`fromColor`/`toColor`/`sampleState` (schwarz ↔ OPAQUE, `kColorClear` ↔
TRANSPARENT, weiss ↔ EMPTY). `ImageStoreCodec.hashTile` und
`imagesVisiblyEqual` klassifizieren jeden Pixel als schwarz / weiss /
transparent. Kein `transparency`-Feld in `frames.json`.

`PixelRoom` nimmt den ebenenabhaengigen Off-State entgegen
(`setCurrentTile(tile, idx, offStateCode)` — Default `EMPTY` = Basisebene).
A toggelt Tinte ↔ Off-State, `buildTileImage` startet den Canvas in der
Off-State-Farbe. `ZoomRoom` und `EditorRoom.buildZoomContext`
(`activeLayerIsBase`) reichen den Zustand durch. Auf den oberen Ebenen
faellt eine geschriebene Weiss-Position (1) in
`EditorRoom.writeActiveLayerPosition` auf „absent“ (0) zusammen — der
Radierer bleibt ein Durchsicht-Radierer.

### Nachtrag 5. Runde (2026-09-01, aus dem Hardware-Test)
Im PixelRoom malt **nur A**. Die urspruengliche Zuweisung „B setzt den
Off-State direkt“ (FR-007 alt) ist zurueckgenommen:

- Auf Device wird mit A gemalt; ein eigener B-Malpfad war unerwuenscht.
- Die B-Halten-Zoom-Out-Geste (`getCrankTicks`, `update()`) hinterliess
  bei jedem Loslassen einen ungewollten `kColorClear`-Pixel im Tile,
  weil `BButtonDown` einen Strich startete.

`beginStroke()` verliert den `button`-Parameter und die
`strokeButton`-Zustandsvariable; `BButtonDown`/`BButtonUp` sind No-ops;
`moveCursor` malt einen laufenden Strich nur bei gehaltenem `kButtonA`
weiter. **Kein Pixelzustand wird unerreichbar** — der A-Toggle deckt
`Tinte ↔ Off-State` je Ebene ab, also erreicht A-auf-Tinte auf Ebene 2/3
direkt „transparent“. B bleibt der Zoom-Out-Modifier (B halten + Crank
zurueck). `spec.md` FR-007 lautet jetzt „B malt nicht in Pixel View“.
Tests: „B-Tipp folgenlos“ (obere + Basisebene), Radier-Strich startet via
A auf einer Tinte-Zelle; die B+Crank-Zoom-Out-Regression prueft jetzt auch
die `BButtonDown`-Geste (kein stray Pixel) (`tests/headless_tests.lua`,
371 Assertions, buildNumber 28).

### Begruendung
- pro Pixel + Dedup-treu in einem Zug, ohne Nebendaten.
- Fuer schwarz/weiss-Alt-Tiles ist der 3-Klassen-Hash identisch zum
  alten 2-Klassen-Hash → Alt-Bilder unveraendert.

### Konsequenzen
- **Positiv**: kein zweites Array je Ebene; `frames.json` bleibt schlank
  (`{layerIndex, name, positions[375], visible}`).
- **Negativ**: `ZoomRoom`s 24×24-Vorschau ist weiterhin 2-wertig — ein
  transparentes Tile einer oberen Ebene erscheint dort wie weiss (die
  eigentliche Transparenz-Bearbeitung passiert im PixelRoom, der das Tile
  3-wertig zurueckliest).
- Manuelle Simulator-Verifikation noetig fuer den PDI-Sheet-Roundtrip
  (`image:draw` ist im Headless-Mock ein No-op).

## Related
- [ADR-039: Feste 3-Ebenen-Struktur](ADR-039-Feste-3-Ebenen-Struktur.md)
- [specs/010-layer-management-with-transparency/research.md: R2](../../specs/010-layer-management-with-transparency/research.md)
- [specs/010-layer-management-with-transparency/spec.md: FR-006..FR-011, Edge Case „Layer 1 Transparency“](../../specs/010-layer-management-with-transparency/spec.md)
