# Plan: Pulp-kompatibles Speichern und Laden des TileRoom

## Ziel

Der TileRoom soll so speichern, dass die erzeugte JSON-Datei mit Pulp und auf Playdate in Pulp ladbar bleibt.
Dabei darf nicht mehr das bisher reduzierte Eigenformat geschrieben werden. Stattdessen muss beim Speichern eine kompatible Pulp-Datei entstehen, bei der nur die Raumdaten und die direkt davon betroffenen Tile-/Frame-Daten angepasst werden.

Wichtig:

- Vorhandene Attribute aus einer bereits kompatiblen Datei muessen erhalten bleiben.
- Auch Attribute, die das Programm selbst nicht nutzt, muessen korrekt gesetzt oder unveraendert mitgeschrieben werden.
- Es soll nicht die komplette Datei neu erfunden werden, sondern ein bestehendes kompatibles Dokument gezielt aktualisiert werden.

## Beobachtungen aus dem aktuellen Stand

### Funktionierendes Referenzformat

`pulp/Hans Dither.json` ist ein gueltiges Beispiel fuer das Format, das Pulp versteht.
Die Datei enthaelt deutlich mehr als nur `version`, `name`, `rooms`, `tiles` und `frames`, zum Beispiel auch:

- Metadaten wie `card`, `icon`, `song`, `wrap`, `intro`, `author`, `buildNumber`, `versionString`, `background`
- Pulp-Editor-Daten wie `editor`
- weitere Sammlungen wie `songs`, `sounds`, `scripts`, `player`, `font`
- Tile-Attribute, die ueber das aktuelle Programm hinausgehen, z. B. `fps`, `btype`, `solid`, `script`, `says`
- Room-Attribute, z. B. `song`, `exits`, `script`

### Altes Speicherformat

`support/old_saves/Videopoker.json` zeigt das bisherige Programmformat. Es ist naehere an Pulp als das aktuelle Runtime-Save, aber immer noch nicht vollstaendig genug und hat andere Defaults.

### Aktuelle Runtime-Speicherung

Die aktuelle Implementierung in `Source/TileRoom.lua` schreibt beim Speichern ein stark reduziertes Objekt:

- `version`
- `name`
- `rooms`
- `tiles`
- `frames`

Damit gehen viele Pulp-relevante Attribute verloren. Ausserdem werden Tile-Definitionen aktuell mit wenigen Default-Feldern neu aufgebaut, wodurch eventuell vorhandene Eigenschaften aus Pulp ueberschrieben werden.

## Kernproblem

Die Speicherung muss von einem "Neuaufbau eines Minimalformats" auf ein "gezieltes Aktualisieren eines bestaetigt kompatiblen Quelldokuments" umgestellt werden.

Praktisch bedeutet das:

1. Beim Laden muss neben der internen Arbeitsstruktur auch die vollstaendige Originaldatei erhalten bleiben.
2. Beim Speichern darf nicht blind `gameData` serialisiert werden.
3. Stattdessen muss aus einer kompatiblen Basisdatei ein neues Ausgabeobjekt entstehen, in dem nur die benoetigten Bereiche aktualisiert werden.

## Geplante Strategie

### 1. Zwei Datenebenen trennen

Es soll kuenftig zwei Ebenen geben:

- `gameData` als interne Arbeitsdarstellung fuer den Editor
- `pulpDocument` als vollstaendige, kompatible JSON-Struktur, die spaeter geschrieben wird

`gameData` bleibt fuer TileRoom, LoadRoom und Migration zustaendig.
`pulpDocument` dient als Quelle fuer alle Attribute, die erhalten bleiben muessen.

### 2. Beim Laden eine vollstaendige Pulp-Basis merken

Beim Laden eines Spiels sind drei Faelle zu unterscheiden:

1. Die Datei ist bereits im Pulp-Format.
   Dann wird die geladene Datei sowohl als Arbeitsbasis fuer `gameData` als auch als `pulpDocument` verwendet.

2. Die Datei ist ein altes Eigenformat.
   Dann wird sie weiterhin in eine interne Arbeitsdarstellung migriert, aber zusaetzlich muss fuer spaeter eine kompatible Pulp-Basis erzeugt werden.

3. Es wird ein komplett neues Spiel erzeugt.
   Dann braucht es ebenfalls ein vollstaendiges Pulp-Grunddokument mit sauberen Defaults.

Fuer Fall 2 und 3 darf diese Basis nicht minimal sein. Sie muss alle von Pulp benoetigten Bereiche enthalten.

### 3. Kompatible Basisdatei nicht hart neu modellieren, sondern von Beispielstruktur ableiten

Die robusteste Variante ist:

- eine vollstaendige Pulp-Grundstruktur aus einem bestaetigt kompatiblen Template abzuleiten
- nur spielbezogene Werte gezielt auszutauschen

Moegliche Quelle:

- eine interne Template-Struktur nach Vorbild von `pulp/Hans Dither.json`

Wichtig dabei:

- keine Hans-Dither-spezifischen Inhalte blind uebernehmen, wenn sie spielbezogen sind
- aber die Form und Vollstaendigkeit der Felder als Referenz nutzen

### 4. Speicherung als Merge statt als Neuaufbau

Der Speichervorgang soll kuenftig so ablaufen:

1. Aktuelle Tilemap in `gameData.rooms[currentRoomIndex]` synchronisieren.
2. Verwendete Tiles weiterhin kompaktisieren, sofern das fuer die interne Logik gewuenscht bleibt.
3. Aus `pulpDocument` oder einer kompatiblen Vorlage ein Ausgabeobjekt ableiten.
4. Nur folgende Bereiche gezielt aktualisieren:
   - `rooms`
   - `tiles`
   - `frames`
   - direkt abhaengige Felder wie `player.room`, falls noetig
   - spielbezogene Metadaten wie `name`, falls vom Editor verwaltet
5. Alle uebrigen vorhandenen Felder unveraendert beibehalten.
6. Das gemergte Dokument schreiben.

Dadurch bleiben unbekannte oder vom Benutzer in Pulp gesetzte Attribute erhalten.

### 5. Raumdaten nur punktuell ersetzen

Besonders wichtig ist, dass nicht pauschal alle Room-Objekte neu mit Minimalfeldern erzeugt werden.
Stattdessen:

- existiert der Raum bereits in `pulpDocument.rooms`, dann werden nur seine Tile-Daten und explizit verwaltete Felder aktualisiert
- z. B. `id`, `name`, `tiles`
- Felder wie `song`, `exits`, `script` bleiben erhalten, sofern das Programm sie nicht bewusst aendern soll

Bei neu angelegten Raeumen muessen fehlende Pflichtfelder mit Pulp-kompatiblen Defaults angelegt werden, zum Beispiel:

- `id`
- `name`
- `song`
- `exits`
- `tiles`
- `script`

### 6. Tile-Definitionen ebenso merge-basiert behandeln

Dasselbe gilt fuer `tiles`:

- fuer bereits vorhandene Tiles bestehende Tile-Objekte nach `id` wiederverwenden
- nur technisch notwendige Inhalte aktualisieren, z. B. `frames` oder `name`, wenn das Programm diese bewusst verwaltet
- vorhandene Pulp-Felder wie `fps`, `type`, `btype`, `solid`, `script`, `says` nicht verlieren

Fuer neu erzeugte Tiles muessen sinnvolle Pulp-Defaults gesetzt werden.

### 7. Frames gezielt neu aufbauen

`frames` sind die am ehesten rein technisch erzeugbaren Daten. Diese koennen aus den aktuellen Tile-Bildern neu erzeugt werden.
Hier ist ein Neuaufbau eher unkritisch, solange:

- `id` stabil und konsistent bleibt
- `tiles[].frames` korrekt auf die Frame-IDs verweisen

### 8. Eigene Hilfsfunktion fuer Pulp-kompatibles Output-Dokument

Empfohlen ist eine dedizierte Funktion, sinngemaess:

- `buildPulpSaveDocument(gameData, existingPulpDocument)`

Verantwortung dieser Funktion:

- kompatible Top-Level-Struktur sicherstellen
- existierende Werte aus `existingPulpDocument` bewahren
- nur die relevanten Bereiche aktualisieren
- Defaults fuer neue Rooms/Tiles/sonstige Pflichtfelder setzen

So bleibt die Save-Logik in `TileRoom:saveToFile()` uebersichtlich.

## Konkrete Umsetzungsschritte

1. Ladepfad analysieren und erweitern:
   - feststellen, ob bereits ein vollstaendiges Pulp-Dokument vorliegt
   - dieses Dokument in einer separaten Variable behalten

2. Neue Hilfsstrukturen einfuehren:
   - `pulpDocument` oder aehnlich
   - Hilfsfunktionen fuer Default-Room, Default-Tile und Default-Top-Level-Felder

3. Save-Pfad umbauen:
   - bisheriges minimales `gameData` nicht direkt schreiben
   - stattdessen Merge-Dokument erzeugen und dieses speichern

4. Room-Merge implementieren:
   - vorhandene Room-Attribute bewahren
   - nur `tiles` und bewusst gepflegte Felder aendern

5. Tile-Merge implementieren:
   - vorhandene Tile-Attribute bewahren
   - neue Tiles mit vollstaendigen Defaults erzeugen

6. Top-Level-Felder absichern:
   - fehlende Pflichtfelder aus kompatibler Vorlage oder Defaults auffuellen
   - vorhandene Felder nicht loeschen

7. Testfaelle pruefen:
   - Laden und erneutes Speichern einer alten `Videopoker.json`
   - Laden und erneutes Speichern einer bereits kompatiblen Datei
   - Sicherstellen, dass benutzerseitig in Pulp gesetzte Felder nach dem Speichern erhalten bleiben

## Wichtige Designentscheidung

Die zentrale Regel fuer die Umsetzung lautet:

> Bestehende kompatible JSON-Datei als Quelle der Wahrheit fuer unbekannte oder nicht vom Editor verwaltete Felder behandeln.

Das verhindert, dass beim Speichern Informationen verloren gehen, die Pulp benoetigt oder die spaeter in Pulp bearbeitet wurden.

## Risiken

- Wenn Tile- oder Room-IDs beim Speichern instabil werden, koennen Referenzen in anderen Bereichen inkonsistent werden.
- Wenn bei neuen Objekten unvollstaendige Defaults gesetzt werden, bleibt die Datei formal weiterhin inkompatibel.
- Wenn `tiles` oder `rooms` komplett ersetzt statt gemergt werden, gehen Pulp-spezifische Attribute erneut verloren.

## Ergebnis der geplanten Aenderung

Nach dem Umbau soll gelten:

- alte Dateien koennen weiterhin geladen werden
- gespeicherte Dateien entsprechen dem Pulp-kompatiblen Format
- vorhandene, nicht vom Programm genutzte Attribute bleiben erhalten
- beim Speichern werden im Wesentlichen nur Raumdaten und direkt betroffene Tile-/Frame-Daten aktualisiert