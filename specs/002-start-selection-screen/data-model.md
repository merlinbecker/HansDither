# Data Model: Start- und Auswahlscreen

**Feature**: 002-start-selection-screen | **Date**: 2026-07-03

Dieses Feature persistiert nichts selbst — alle Daten kommen aus dem `ImageStore`-Contract (Spec 001). Hier ist das UI-Zustandsmodell der beiden Rooms beschrieben.

## SelectionRoom-Zustand

| Feld | Typ | Regeln |
|---|---|---|
| `entries` | array | Ergebnis von `ImageStore.listImages()` (lastEdited absteigend) **plus** virtuellem Abschlusseintrag `{kind="new"}` (FR-012/FR-013) |
| `gridview` | playdate.ui.gridview | 3 Spalten; Zeilen = `⌈#entries / 3⌉`; Zellgröße ≈ 133×80; Sichtfenster 3×3 |
| `selectedIndex` | number | 1..#entries; Mapping Index ↔ (row, col): `row = ⌈i/3⌉`, `col = ((i-1) % 3) + 1` |
| `thumbCache` | table | `id → maskiertes Kreis-Thumbnail (image)`; Platzhalter-Image bei defektem Preview; invalidiert bei entered()/Neu/Kopieren/Löschen (research.md R3) |
| `confirmingDelete` | boolean/table | nil oder `{id, name}`; blockiert während des Dialogs alle anderen Eingaben |
| `pendingAction` | string/nil | Keyboard-Flow-Zustand für "Neu" (Muster aus bisherigem GameRoom); verhindert Doppel-Trigger |
| `needsRedraw` | boolean | bestehendes Redraw-Muster |

### Eintragstypen

- **Bildeintrag**: `{kind="image", id, name, frameCount, lastEdited}` — direkt aus dem Index (Contract C-01).
- **Neu-Eintrag**: `{kind="new"}` — letzter Eintrag; rendert als leerer Kreis mit "+"; A löst den Keyboard-Flow aus; er ist Ziel der Menüaktion "new image" gleichermaßen.

### Zustandsübergänge SelectionRoom

```text
entered()          → entries neu laden, thumbCache leeren, Menüeinträge (3) registrieren
D-Pad              → selectedIndex bewegen (Zeilenende: Stopp links/rechts;
                     vertikal über Fensterrand → gridview:scrollToCell)
A auf Bildeintrag  → switchRoom(Editor) mit id  [Anbindung Spec 003; bis dahin Stub]
A auf Neu-Eintrag  → Keyboard öffnen → Name → ImageStore.createImage
                     → "name-taken": Hinweis + Tastatur erneut  → Erfolg: Editor öffnen
B                  → switchRoom(TitleRoom)
Menü "delete"      → confirmingDelete = {id,name}   [nur auf Bildeintrag]
  A                → deleteImage → entries/Cache/Selektion aktualisieren → Dialog zu
  B                → Dialog zu, nichts löschen
Menü "copy"        → copyImage(id) → entries/Cache aktualisieren, Kopie selektieren
Menü "new"         → wie A auf Neu-Eintrag
Keyboard aktiv / confirmingDelete / laufende Aktion → alle übrigen Eingaben blockiert
```

### Selektionsregel nach Löschen

Nach `deleteImage`: Selektion bleibt auf gleicher Position (nachrückender Eintrag); war der letzte Listeneintrag selektiert, rückt sie auf den neuen letzten (ggf. der Neu-Eintrag). Leere Liste ⇒ nur Neu-Eintrag, selektiert (Edge Case "letztes Bild gelöscht").

## TitleRoom-Zustand (Änderungen)

| Feld | Typ | Regeln |
|---|---|---|
| `backgroundImage` | image/nil | `ImageStore.getLastEditedPreview()` bei entered(); nil ⇒ Bayer-Dither-Fallback (FR-002) |
| `metadataRows` | array | besteht; Version aus `playdate.metadata` — erfordert `Source/pdxinfo` version=0.3.0 (FR-001) |

Textinhalte (FR-001): Titelzeile "Hans Dither, 1 bit Pixel 'n Tile Editor"; Fußzeile "Version 0.3.0 - still under development - Press A" (Version aus Metadaten interpoliert).

## Geometrie (Richtwerte, final im Simulator justieren)

- Raster: 3 Spalten × 3 sichtbare Zeilen; Zelle ≈ 133×80 px (3×133 = 399, 3×80 = 240).
- Kreis: ⌀ ≈ 72 px, zentriert in der Zelle; Selektionsring +3 px Stärke.
- Thumbnail-Ausschnitt: preview.pdi (400×240) unskaliert, Bildmitte auf Kreismitte (Clarification).
