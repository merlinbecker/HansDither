<!--
Sync Impact Report
- Version change: (Template, unversioniert) → 1.0.0
- Modified principles: alle Platzhalter ersetzt (Erstausfüllung des Templates)
- Added sections:
  - I. SDK-First (NICHT VERHANDELBAR)
  - II. Native Formate & PDI
  - III. Architekturdokumentation in arc42
  - IV. Einfachheit vor Ausbau
  - Technische Randbedingungen
  - Entwicklungs-Workflow
  - Governance (konkretisiert)
- Removed sections: keine (Template-Kommentare entfernt)
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md (Constitution Check ist generisch, kompatibel)
  - ✅ .specify/templates/spec-template.md (keine constitution-spezifischen Pflichtabschnitte nötig)
  - ✅ .specify/templates/tasks-template.md (keine neuen Task-Kategorien erforderlich)
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

## Technische Randbedingungen

- Sprache/Runtime: Lua auf Playdate (Device und Simulator), Build über
  das offizielle Playdate SDK (`pdc`).
- Eingaben: D-Pad, A/B-Buttons und Crank sind die einzigen
  Eingabegeräte; jede Funktion MUSS damit erreichbar sein.
- Persistenz: ausschließlich über `playdate.file` / `playdate.datastore`
  unter dem App-Datenverzeichnis; keine Netzwerkabhängigkeiten.
- Performance: Interaktionen müssen auf der Zielhardware flüssig bleiben;
  langlaufende Save/Load-Operationen laufen kooperativ (Coroutine +
  Fortschrittsanzeige), nicht blockierend in einem Frame.
- Dokumentationssprache: Deutsch für arc42; Code-Bezeichner und
  UI-Texte Englisch.

## Entwicklungs-Workflow

- Änderungen folgen dem Spec-Kit-Ablauf: Constitution → Spec → Plan →
  Tasks → Implementierung.
- Jede Feature-Spezifikation MUSS gegen die Prinzipien I–IV geprüft
  werden (Constitution Check im Plan); Verstöße erfordern eine explizit
  dokumentierte Begründung oder eine Anpassung des Designs.
- Verifikation erfolgt mindestens im Playdate Simulator; hardware-nahe
  Funktionen (Crank-Feinverhalten, Performance) werden zusätzlich auf
  dem Gerät geprüft.
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

**Version**: 1.0.0 | **Ratified**: 2026-07-03 | **Last Amended**: 2026-07-03
