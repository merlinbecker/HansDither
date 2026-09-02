# 1. Einfuehrung und Ziele

## 1.1 Aufgabenstellung
Hans Dither ist ein minimalistischer 1-Bit-Pixel- und Tile-Editor fuer die Playdate-Konsole. Pixelart wird direkt auf dem Geraet erstellt, animiert und gespeichert. Das System soll:

- das Erstellen und Animieren einfacher 1-Bit-Grafik direkt auf der Hardware ermoeglichen: 25x15-Raster aus 16x16-Tiles, bis zu 12 Animationsframes, 3 feste Ebenen je Frame mit Pixel-Transparenz,
- den Editierfluss ueber D-Pad, A/B und Crank effizient machen — mit drei ineinander verschachtelten Zoomstufen (Tile-, Zoom-, Pixel-View),
- Bilder verlustfrei im nativen Playdate-Format speichern und laden (per Hash deduplizierte PDI-Tilemap + Positions-JSON je Frame),
- einzelne Bilder optional per Kurbelgeste zu einem einfachen Web-Backend synchronisieren.

Das Projekt adressiert bewusst einen Lern- und Kreativkontext: Pixelart-Entwicklung direkt auf Hardware, mit reduzierten Mitteln und klaren Interaktionen.

### Entwicklungsstand
Stand dieser Dokumentation: **v0.4** (`Source/pdxinfo`), Feature-Specs 001–011 umgesetzt (`specs/`). Die arc42 spiegelt den Codestand nach Spec 011 wider und wird je Umsetzungsschnitt gepflegt (Constitution III). Kap. 9 (Architekturentscheidungen) und die „Historischen Begriffe" in Kap. 12 halten den Weg von der Pulp-Aera (bis v0.2) bewusst fest.

Die Architektur wurde mit dem Planungsschnitt **v0.3.0** (AD-016 bis AD-020 in Kapitel 9) grundlegend neu ausgerichtet; die vorherigen Konzepte gelten nicht mehr:

- **Aufloesung:** native 400x240 mit 16x16-Tiles — kein dualer „Pulp-Arbeitsraum" (200x120 / 8x8) und kein Anzeige-Scaling mehr (AD-016).
- **Speicherformat:** PDI-Tilemap (per FNV-1a deduplizierte Tiles) + `frames.json` (375 Tile-Indizes je Frame, seit Spec 010 verschachtelt nach 3 Ebenen, Version „1.1") + `preview.pdi`. Das Pulp-JSON-Dokument samt Merge-Logik entfaellt (AD-017).
- **Struktur:** flache „Bilder" statt der zweistufigen Games/Rooms-Hierarchie; direkter Editor-Einstieg ueber den 3x3-Kreis-Auswahlscreen mit endlosem Scrollen (AD-018).
- **Animation & Ebenen:** bis zu 12 Frames (Kopie-Semantik); 3 feste Ebenen je Frame mit `kColorClear`-Pixel-Transparenz (Spec 010, AD-039/AD-040). B+Crank zoomt durch die drei Zoomstufen, B+D-Pad waehlt Ebene bzw. Frame (AD-042).
- **Governance:** SDK-first und native Formate sind in der Projekt-Constitution (`.specify/memory/constitution.md`) verankert.
- **Sync (optional):** einzelne Bilder lassen sich per Kurbelgeste im Auswahlscreen zu einem eigenen, minimalen PHP/MySQL-Web-Backend hochladen (Spec 004/005/007/009); der Editier-Kern funktioniert vollstaendig offline.

### Quellen im Projekt
- README (Projektidee, Bedienung, Zielsetzung)
- Source/pdxinfo (Metadaten)
- support/devlogs/01-noMoreExcuses.md (Motivation und Kontext)
- STEUERUNG.md (vollstaendige, tastengenaue Bedienreferenz je Room inkl. Systemmenue-Eintraegen und Schuettelgeste; aus dem Quellcode abgeleitet)

## 1.2 Qualitaetsziele
Die wichtigsten Qualitaetsziele fuer die Architektur sind:

| Prioritaet | Qualitaetsziel | Beschreibung |
|---|---|---|
| 1 | Verlustfreie Persistenz | Bilder duerfen bei Save/Load nicht verloren gehen; Tile-, Frame- und Ebenen-Zuordnungen bleiben konsistent, auch bei der Tile-Deduplizierung und -Bereinigung vor dem Speichern (Spec 009). |
| 2 | Direkte Bedienbarkeit | Kernaktionen (Navigieren, Pixel/Tile setzen und loeschen, Bildauswahl, Zoomstufe/Ebene/Frame wechseln) sind mit wenigen Eingaben erreichbar; die Steuerung bleibt ueber die drei Zoomstufen konsistent. |
| 3 | Native Datenintegritaet | Das Speicherformat ist rein nativ (PDI + Positions-JSON), ohne Fremdformat-Bindung; ein Round-Trip Save→Load reproduziert Pixelinhalt, Ebenen und Frames exakt (Constitution II, AD-017). |
| 4 | Wartbarkeit | Room-Logik bleibt modular getrennt (Title / Selection / Editor / Zoom / Pixel / FrameManagement), damit Features isoliert erweiterbar sind. |
| 5 | Performantes Redraw | Rendern bleibt auf Playdate-Hardware fluessig: zustandsbasiertes Redraw, einfache Datenstrukturen, Hintergrund-Cache im Zoom-View (AD-035). |
| 6 | SDK-Konformitaet | Vor jeder Eigenimplementierung wird geprueft, ob das SDK die Funktion bietet; begruendete Abweichungen (z. B. Schuettel-Erkennung ohne SDK-Shake-Ereignis, AD-044) werden in Kapitel 9 dokumentiert (Constitution I). |

## 1.3 Stakeholder

| Rolle | Kontakt | Erwartungshaltung |
|---|---|---|
| Projektautor/Entwickler | Merlin Becker | Schnell iterierbare Codebasis, Lernbarkeit, einfache Erweiterung von Editorfeatures. |
| Spieler/Kreative | Endnutzer auf Playdate | Einfache, robuste Bedienung zum Pixeln, Animieren und Speichern von Arbeiten. |
| Playdate-SDK-Oekosystem | indirekt (Toolchain/Format) | Interaktionen und Formate bleiben SDK-konform; die exportierte Tilemap folgt der SDK-Namenskonvention (Spec 009). |
| Backend-Betrieb (Sync) | Merlin Becker (Self-Hosting, all-inkl.com) | Einfacher PHP/MySQL-Dienst, geringe Last, keine Secrets im Client-Repo. |
| Wartende Mitentwickler (optional) | spaeteres Projektumfeld | Nachvollziehbare Raumaufteilung und dokumentierte Entscheidungen. |
