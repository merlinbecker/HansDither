<!--
Sync Impact Report
- Version change: 1.2.0 → 1.3.0
- Modified principles: V. Testpflicht (NICHT VERHANDELBAR) — Gate 2
  materiell erweitert, kein Titel-/Nummernwechsel
- Added sections: keine neue Section (bestehendes Gate 2 innerhalb
  Prinzip V erweitert)
- Removed sections: keine
- Modified sections:
  - Prinzip V, Gate 2: `Source/pdxinfo`s `buildNumber` MUSS vor jedem
    `pdc`-Build, der eine Code-Änderung gegen Simulator/Hardware testet,
    um genau 1 erhöht werden — nicht nur bei Releases. Blockierklausel
    und Begründung entsprechend ergänzt (nachvollziehbare Testläufe).
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md (Constitution Check generisch, kompatibel)
  - ✅ .specify/templates/spec-template.md (keine constitution-spezifischen Pflichtabschnitte nötig)
  - ✅ .specify/templates/tasks-template.md (Verifikationsphase deckt Build-Gate bereits ab; buildNumber-Schritt ist Teil des bestehenden Gate-2-Tasks, kein neuer Task-Typ nötig)
- Follow-up TODOs: keine
-->

# Hans Dither Constitution

## Core Principles

### I. SDK-First (NICHT VERHANDELBAR)

Das offizielle Playdate SDK MUSS maximal ausgenutzt werden. Vor jeder
Eigenimplementierung MUSS geprüft werden, ob das SDK die Funktion bereits
bietet oder ob sie sich mit SDK-Mitteln (CoreLibs: graphics, sprites,
imagetable, tilemap, animation, ui, crank, timer, datastore, file, json)
abbilden lässt. Es DARF nur Code außerhalb des SDK entstehen, wenn das SDK
die Funktion nachweislich nicht abdeckt; diese Abweichung MUSS begründet
werden. Jede wesentliche SDK-Nutzung und jede Entscheidung für oder gegen
eine SDK-Funktion MUSS in der arc42-Dokumentation benannt werden
(insbesondere Kapitel 4 Lösungsstrategie und Kapitel 9
Architekturentscheidungen).

Begründung: So wenig wie möglich außerhalb des SDK zu coden reduziert
Wartungsaufwand, Fehlerquellen und Performance-Risiken auf der begrenzten
Zielhardware und hält das Projekt nahe an der offiziellen Plattform.

### II. Native Formate & PDI

Hans Dither hält sich an die nativen Playdate-Formate. Konkret:

- Zielauflösung ist nativ 400×240 Pixel; ein Tile ist 16×16 Pixel.
- Persistenz erfolgt NICHT mehr im Pulp-JSON-Format. Das Speicherformat
  ist eine PDI-Tilemap (deduplizierte Tiles als PDI/Imagetable) plus eine
  JSON-Datei mit den Positionen der 16×16-Tiles je Animationsframe.
- Tiles MÜSSEN vor dem Speichern via Hashing dedupliziert werden; kein
  Tile wird doppelt abgelegt.
- Neue Datenformate MÜSSEN PDI-fähig sein oder auf SDK-Serialisierung
  (playdate.datastore / playdate.json) aufbauen.

Begründung: Native Formate laden schnell über SDK-Funktionen, vermeiden
eigene Parser und machen den Editor unabhängig vom Pulp-Ökosystem.

### III. Architekturdokumentation in arc42

Die Architektur wird in `arc42/` auf Deutsch gepflegt. Jede
Architekturentscheidung (insbesondere SDK-Nutzung, Formatentscheidungen,
Modulschnitte) MUSS als Architekturentscheidung in Kapitel 9 festgehalten
werden. Bei Änderungen am Systemverhalten MÜSSEN die betroffenen
arc42-Kapitel im selben Änderungsschnitt aktualisiert werden, sodass die
Dokumentation den Ist-Zustand des Codes beschreibt.

Begründung: Als Einzelentwickler-Lernprojekt ist die arc42-Doku das
Gedächtnis des Projekts; veraltete Doku verliert ihren Zweck.

### IV. Einfachheit vor Ausbau

Features werden in kleinen, klar begrenzten Inkrementen entwickelt
(YAGNI). Harte, einfache Grenzen sind erlaubt und erwünscht (z. B. maximal
12 Animationsframes). Komplexität, die nicht direkt einem Editor-Workflow
dient, MUSS vermieden oder begründet werden. Bestehende bewährte Muster
(Room-Architektur mit switchRoom, zustandsbasiertes Redraw via
needsRedraw, Coroutine-basierte Langläufer mit Fortschrittsanzeige)
SOLLEN wiederverwendet statt neu erfunden werden.

Begründung: Einzelentwicklung mit begrenzter Zeit; Lesbarkeit und
Iterationsgeschwindigkeit schlagen Feature-Vollständigkeit.

### V. Testpflicht (NICHT VERHANDELBAR)

Jede Implementierungsänderung an `Source/*.lua` MUSS vor Abschluss durch
zwei Gates verifiziert werden, unabhängig davon, welcher Agent oder
welches Harness (Claude Code, GitHub Copilot, andere Speckit-Clients)
die Änderung ausführt:

1. Headless-Tests: `lua tests/headless_tests.lua` — MUSS mit
   "ALLE TESTS BESTANDEN" enden.
2. Build: `Source/pdxinfo` — `buildNumber` MUSS zuerst um genau 1 erhöht
   werden; erst danach MUSS `pdc Source "Hans Dither.pdx"` fehlerfrei
   durchlaufen. Das gilt für JEDE Code-Änderung, die einen Build-/
   Simulator-/Hardware-Testlauf durchläuft — nicht nur für Releases —,
   damit einzelne Testläufe anhand der `buildNumber` unterscheidbar
   bleiben.

Fehlschlagende Tests oder Builds BLOCKIEREN den Abschluss: Eine
Implementierungs-Task DARF NICHT als erledigt markiert, ein Commit DARF
NICHT erstellt und ein Feature DARF NICHT als fertig gemeldet werden,
solange eines der Gates rot ist oder die `buildNumber` nicht erhöht
wurde. Wer ein Gate nicht ausführen kann (z. B. fehlender
Lua-Interpreter), MUSS das explizit als offenen Punkt ausweisen statt
Erfolg zu melden.

Neue Raum- und Modullogik SOLL headless-testbar gehalten werden:
Standard-Lua-Syntax (keine pdc-Erweiterungen wie `+=`), SDK-Zugriffe
über mockbare Aufrufe, Logik von Rendering getrennt. Wer einen Bug
behebt, SOLL einen Testfall ergänzen, der die Fehlerklasse künftig
abfängt.

Begründung: Die v0.3.0-Neuschreibung hat gezeigt, dass plausible, aber
nicht existierende SDK-APIs erst zur Laufzeit crashen. Die strikten
Mocks der Headless-Tests fangen genau diese Fehlerklasse vor dem
Simulator-Lauf ab; das Gate gilt zentral in der Constitution, damit es
für alle Harnesses gleichermaßen verbindlich ist. Die verpflichtende
`buildNumber`-Erhöhung (Spec 009) macht einzelne Simulator-/Hardware-
Testläufe nachvollziehbar auseinanderhaltbar — ohne sie lässt sich im
Nachhinein nicht rekonstruieren, welcher Build welchem Testergebnis
zugrunde lag.

## Technische Randbedingungen

- Sprache/Runtime: Lua auf Playdate (Device und Simulator), Build über
  das offizielle Playdate SDK (`pdc`).
- Eingaben: D-Pad, A/B-Buttons und Crank sind die einzigen
  Eingabegeräte; jede Funktion MUSS damit erreichbar sein.
- Persistenz: Die Kern-Zeichenpersistenz (Speichern/Laden von Hans-Dither-
  Projekten im Editor) erfolgt ausschließlich über `playdate.file` /
  `playdate.datastore` unter dem App-Datenverzeichnis und MUSS vollständig
  offline funktionieren; sie hat keine Netzwerkabhängigkeit.
- Netzwerk (Sync-Ausnahme): Netzwerkkommunikation (`playdate.net`) ist
  ausschließlich für das explizit als solches spezifizierte Backend-
  Sync-Feature erlaubt (Export/Upload von Zeichnungen an ein Web-Backend,
  siehe Spec 004). Das Sync-Feature MUSS optional und additiv bleiben:
  alle Kern-Editor-Funktionen (Zeichnen, Speichern, Laden, Anzeigen)
  MÜSSEN ohne Netzwerkverbindung vollständig nutzbar sein. Jede weitere
  Netzwerknutzung außerhalb des Sync-Kontexts MUSS gesondert begründet
  und als ADR dokumentiert werden.
- Performance: Interaktionen müssen auf der Zielhardware flüssig bleiben;
  langlaufende Save/Load-Operationen laufen kooperativ (Coroutine +
  Fortschrittsanzeige), nicht blockierend in einem Frame.
- Dokumentationssprache: Deutsch für arc42; Code-Bezeichner und
  UI-Texte Englisch.

## Entwicklungs-Workflow

- Änderungen folgen dem Spec-Kit-Ablauf: Constitution → Spec → Plan →
  Tasks → Implementierung.
- Jede Feature-Spezifikation MUSS gegen die Prinzipien I–V geprüft
  werden (Constitution Check im Plan); Verstöße erfordern eine explizit
  dokumentierte Begründung oder eine Anpassung des Designs.
- Verifikation erfolgt zweistufig: automatisiert über die Test-Gates aus
  Prinzip V (Headless-Tests + pdc-Build, blockierend) und manuell
  mindestens im Playdate Simulator; hardware-nahe Funktionen
  (Crank-Feinverhalten, Performance) werden zusätzlich auf dem Gerät
  geprüft.
- arc42 wird im selben Feature-Branch mitgezogen (Prinzip III).

## Governance

Diese Constitution hat Vorrang vor allen anderen Projektpraktiken.
Änderungen an der Constitution erfordern: (1) dokumentierte Begründung,
(2) Versionserhöhung nach semantischer Versionierung (MAJOR:
Prinzip-Entfernung oder -Umdeutung; MINOR: neues Prinzip oder wesentliche
Erweiterung; PATCH: Klarstellungen), (3) Prüfung der abhängigen Templates
unter `.specify/templates/` auf Konsistenz. Reviews von Plans und Specs
MÜSSEN die Einhaltung der Prinzipien verifizieren; nicht begründbare
Komplexität wird abgelehnt.

**Version**: 1.3.0 | **Ratified**: 2026-07-03 | **Last Amended**: 2026-08-09
