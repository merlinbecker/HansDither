# Feature Specification: Absicherung des Backends gegen unbegrenzte/missbräuchliche Uploads

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-19

**Status**: Draft

**Input**: User description: "Ich muss das neue Backend für Hans-Dither absichern, denn obwohl es einen PIN-Schutz hat, könnte jemand mit Kenntnis der Architektur unbegrenzt Daten hochladen. Für die Absicherung des neuen Backends für Hans-Dither sind mehrere Prüfungen notwendig. Zwar gibt es eine PIN für den Zugang, aber die Architektur an sich ist anfällig dafür, dass jemand unendlich viele Inhalte hochladen könnte. Deshalb muss ich eine Begrenzung implementieren: Es dürfen maximal 12 Bilder von einem Gerät hochgeladen werden. Ist dieses Limit erreicht, muss eine Meldung den weiteren Upload blockieren. Zusätzlich muss ich die hochgeladenen Dateien validieren. Das bedeutet, ich muss prüfen, ob es sich um das korrekte 'Playdate PDI'-Format handelt und keine unzulässigen Dateitypen möglich sind. Auch die Dateigröße muss begrenzt werden; da diese Formate typischerweise klein sind, sollte alles über 300 Kilobyte abgelehnt werden. Schließlich muss ich sicherstellen, dass die hochgeladene JSON valide ist und dem definierten Schema entspricht. Wenn auch das nicht der Fall ist, wird der Upload ebenfalls abgelehnt."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Obergrenze für Uploads pro Gerät (Priority: P1)

Ein Gerät hat bereits 12 Bilder beim Backend hochgeladen. Versucht es, ein
weiteres (13.) Bild hochzuladen, lehnt das Backend diesen Upload ab und
informiert das Gerät mit einer eindeutigen Meldung, dass das Limit erreicht
ist — statt den Upload einfach anzunehmen und unbegrenzt weiter Speicher zu
belegen.

**Why this priority**: Adressiert direkt das im Feature-Wunsch benannte
Kernrisiko — ein Gerät (bzw. jemand mit Kenntnis der Architektur) könnte
sonst unbegrenzt Speicherplatz und Datenbankeinträge erzeugen. Ohne diese
Begrenzung sind alle anderen Härtungsmaßnahmen wirkungslos gegen das
Kernproblem "unbegrenzt hochladen".

**Independent Test**: Ein Testgerät lädt nacheinander 12 unterschiedliche
Bilder hoch (alle erfolgreich), versucht danach ein 13. hochzuladen und
erhält eine klare Ablehnung statt eines Erfolgs oder eines unklaren
Serverfehlers.

**Acceptance Scenarios**:

1. **Given** ein Gerät hat 11 Bilder hochgeladen, **When** es ein 12. Bild
   hochlädt, **Then** wird der Upload angenommen.
2. **Given** ein Gerät hat bereits 12 Bilder hochgeladen, **When** es
   versucht, ein weiteres NEUES Bild hochzuladen, **Then** wird der Upload
   abgelehnt und eine eindeutige "Limit erreicht"-Meldung zurückgegeben,
   ohne dass ein neuer Datensatz oder eine neue Datei entsteht.
3. **Given** ein Gerät hat bereits 12 Bilder hochgeladen, **When** es eines
   dieser 12 bereits bekannten Bilder erneut hochlädt (Aktualisierung/
   Re-Sync desselben Bildes), **Then** wird dieser Upload trotz erreichtem
   Limit angenommen, da kein zusätzlicher Speicherplatz-Slot entsteht.

---

### User Story 2 - Strengere Dateigrößenbegrenzung (Priority: P1)

Ein Gerät versucht, eine Bild- oder Positionsdatei hochzuladen, die deutlich
größer ist, als für dieses Dateiformat plausibel ist (über 300 Kilobyte).
Das Backend lehnt einen solchen Upload ab, bevor die Datei dauerhaft
gespeichert wird.

**Why this priority**: Selbst mit einer Obergrenze von 12 Bildern pro Gerät
(User Story 1) könnte ein einzelnes, überdimensioniertes Upload den Server
erheblich belasten (Speicherplatz, Übertragungszeit, Verarbeitungsaufwand).
Eine realistische Größengrenze ist damit eine ebenso grundlegende Schutz-
maßnahme gegen Ressourcen-Erschöpfung.

**Independent Test**: Ein Testgerät lädt eine Datei mit exakt 300 KB hoch
(wird angenommen) und danach eine Datei mit 301 KB (wird abgelehnt).

**Acceptance Scenarios**:

1. **Given** eine Bild- oder Positionsdatei ist 300 KB groß oder kleiner,
   **When** sie hochgeladen wird, **Then** wird der Upload hinsichtlich der
   Größe akzeptiert.
2. **Given** eine Bild- oder Positionsdatei überschreitet 300 KB, **When**
   sie hochgeladen wird, **Then** wird der Upload abgelehnt, mit einer
   Meldung, die auf die Größenüberschreitung hinweist.

---

### User Story 3 - Verlässliche Dateiformat-Validierung (Priority: P2)

Ein Gerät (oder ein manipulierter Client) versucht, eine Datei
hochzuladen, die nicht dem erwarteten Playdate-PDI-Bildformat entspricht —
etwa eine Datei mit falschem Inhalt, aber passender Dateiendung, oder ein
grundsätzlich unzulässiger Dateityp. Das Backend erkennt das anhand des
tatsächlichen Dateiinhalts (nicht nur des Dateinamens) und lehnt den Upload
ab.

**Why this priority**: Verhindert, dass beliebige Dateien unter dem
Deckmantel eines Bild-Uploads auf dem Server abgelegt werden — ein
klassisches Einfallstor für missbräuchliche oder schädliche Uploads.
Niedrigere Priorität als US1/US2, da diese Prüfung die Angriffsfläche
reduziert, aber (anders als das fehlende Limit) allein noch keine
unbegrenzte Ressourcen-Erschöpfung ermöglicht.

**Independent Test**: Ein Testgerät lädt eine Datei mit `.pdi`-Endung hoch,
deren Inhalt kein gültiges Playdate-PDI-Format ist (z. B. reiner Text oder
eine umbenannte Datei eines anderen Typs) — der Upload wird anhand des
tatsächlichen Inhalts abgelehnt, nicht anhand der Dateiendung akzeptiert.

**Acceptance Scenarios**:

1. **Given** eine hochgeladene Bilddatei hat die Endung `.pdi` und ist
   inhaltlich ein gültiges Playdate-PDI-Bild, **When** sie hochgeladen
   wird, **Then** wird sie als Bilddatei akzeptiert.
2. **Given** eine hochgeladene Datei hat die Endung `.pdi`, ist aber
   inhaltlich KEIN gültiges Playdate-PDI-Bild, **When** sie hochgeladen
   wird, **Then** wird der Upload abgelehnt.
3. **Given** eine hochgeladene Datei hat einen grundsätzlich unzulässigen
   Dateityp (z. B. eine ausführbare Datei), **When** sie hochgeladen wird,
   **Then** wird der Upload unabhängig von der angegebenen Dateiendung
   abgelehnt.

---

### User Story 4 - JSON-Schema-Validierung der Positionsdaten (Priority: P2)

Ein Gerät lädt zusammen mit dem Bild eine Positionsdatei (JSON) hoch, die
entweder kein gültiges JSON ist oder nicht der erwarteten Struktur
entspricht (z. B. fehlende Pflichtfelder, falsche Datentypen, eine falsche
Anzahl an Frame-Einträgen). Das Backend erkennt das und lehnt den Upload
ab, statt fehlerhafte Daten zu übernehmen.

**Why this priority**: Schützt die Datenintegrität nachgelagerter
Verarbeitungsschritte (z. B. Bild-Rendering für die Web-Ansicht) vor
fehlerhaften oder mutwillig manipulierten Positionsdaten. Ähnliche
Priorität wie US3 — beide sind Inhaltsprüfungen, die die Angriffsfläche
reduzieren, ohne allein das Kernproblem "unbegrenzt hochladen" zu lösen.

**Independent Test**: Ein Testgerät lädt eine syntaktisch ungültige
JSON-Datei hoch (wird abgelehnt) sowie eine syntaktisch gültige, aber dem
Schema widersprechende JSON-Datei (z. B. ohne das erforderliche
Frame-Datenfeld) hoch (wird ebenfalls abgelehnt).

**Acceptance Scenarios**:

1. **Given** die hochgeladene Positionsdatei ist syntaktisch kein gültiges
   JSON, **When** sie hochgeladen wird, **Then** wird der Upload mit einem
   entsprechenden Hinweis abgelehnt.
2. **Given** die hochgeladene Positionsdatei ist syntaktisch gültiges JSON,
   entspricht aber nicht dem definierten Schema (z. B. fehlendes
   Pflichtfeld, falscher Datentyp, unzulässige Array-Länge), **When** sie
   hochgeladen wird, **Then** wird der Upload abgelehnt.
3. **Given** die hochgeladene Positionsdatei ist gültiges JSON UND
   entspricht dem definierten Schema, **When** sie hochgeladen wird,
   **Then** wird sie als Positionsdatei akzeptiert.

---

### Edge Cases

- Was passiert, wenn zwei Upload-Anfragen desselben Geräts nahezu
  gleichzeitig eintreffen, während bereits 11 Bilder gespeichert sind
  (Race Condition)? Das System MUSS verhindern, dass durch die
  Gleichzeitigkeit mehr als 12 Bilder entstehen — eine der beiden Anfragen
  muss abgelehnt werden.
- Was passiert bei einer Datei, die exakt 300 KB groß ist? Sie gilt noch
  als zulässig (siehe Acceptance Scenario US2-1, Grenze ist inklusiv).
- Was passiert, wenn eine hochgeladene Datei zwar unter 300 KB liegt, aber
  inhaltlich beschädigt oder kein valides Format ist? Die Format-Prüfung
  (US3/US4) greift unabhängig von der Größenprüfung — beide Prüfungen
  müssen bestanden werden.
- Was passiert, wenn der PIN-geschützte Login erfolgreich war, das Gerät
  aber danach eine ungültige Datei sendet? Die Authentifizierung (bestehend,
  nicht Teil dieser Spec) bleibt unberührt; die Ablehnung erfolgt auf
  Datei-/Limit-Ebene, unabhängig vom Login-Status.
- Was passiert, wenn ein Gerät sein Limit erreicht hat und versucht, ein
  bereits hochgeladenes Bild zu LÖSCHEN und danach ein neues hochzuladen?
  Außerhalb des Scopes dieser Spec — es existiert aktuell keine
  Lösch-Funktion für hochgeladene Bilder (nur lokale Lösch-/Reset-Aktionen
  auf dem Gerät selbst); falls eine serverseitige Löschfunktion in Zukunft
  entsteht, müsste sie das Limit entsprechend verringern.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUSS die Anzahl unterschiedlicher, aktuell
  gespeicherter Bilder pro Gerät (UID) auf maximal 12 begrenzen.
- **FR-002**: System MUSS einen Upload-Versuch für ein NEUES (13.) Bild
  ablehnen, wenn das Gerät das Limit aus FR-001 bereits erreicht hat, und
  dabei eine eindeutige, vom Nutzer verständliche Meldung liefern.
- **FR-003**: System MUSS das Aktualisieren (Re-Sync) eines BEREITS
  hochgeladenen, dem Gerät bekannten Bildes auch bei erreichtem Limit
  weiterhin zulassen, da dabei kein zusätzlicher Speicherplatz-Slot
  entsteht.
- **FR-004**: System MUSS jede als Bilddatei hochgeladene Datei anhand
  ihres tatsächlichen Inhalts (nicht nur Dateiname/Endung) als gültiges
  Playdate-PDI-Format verifizieren, bevor sie dauerhaft gespeichert wird.
- **FR-005**: System MUSS Uploads mit Dateien, die kein gültiges
  Playdate-PDI-Format sind, ablehnen — unabhängig von der angegebenen
  Dateiendung oder dem angegebenen Inhaltstyp.
- **FR-006**: System MUSS jede hochgeladene Bild- sowie Positionsdatei
  einzeln auf maximal 300 Kilobyte begrenzen; Dateien darüber werden
  abgelehnt, bevor sie dauerhaft gespeichert werden.
- **FR-007**: System MUSS die hochgeladene Positionsdatei als syntaktisch
  gültiges JSON validieren.
- **FR-008**: System MUSS die hochgeladene Positionsdatei zusätzlich gegen
  das definierte Struktur-Schema validieren (u. a. erforderliche Felder,
  erwartete Datentypen, zulässige Wertebereiche/Array-Längen für
  Frame-Daten).
- **FR-009**: System MUSS einen Upload ablehnen, wenn die Positionsdatei
  entweder kein gültiges JSON ist ODER nicht dem Schema aus FR-008
  entspricht.
- **FR-010**: System MUSS bei jeder Ablehnung (Limit erreicht, Datei zu
  groß, ungültiges Bildformat, ungültiges/schemawidriges JSON) eine
  Meldung liefern, die den jeweiligen Ablehnungsgrund erkennbar
  unterscheidet, statt eines generischen Fehlers.
- **FR-011**: System MUSS verhindern, dass gleichzeitige (parallele)
  Upload-Anfragen desselben Geräts das Limit aus FR-001 überschreiten.

### Key Entities *(include if feature involves data)*

- **Bild-Kontingent pro Gerät**: Die Anzahl der einem Gerät (UID)
  zugeordneten, unterschiedlichen gespeicherten Bilder; harte Obergrenze
  12; wird bei jedem NEUEN Upload geprüft, bei Aktualisierungen bestehender
  Bilder nicht erhöht.
- **Hochgeladene Bilddatei**: Binärdatei im Playdate-PDI-Format, die ein
  Bild repräsentiert; maximal 300 KB; muss inhaltlich als gültiges
  PDI-Format erkennbar sein.
- **Positionsdatei**: JSON-strukturierte Metadaten zu einem Bild (u. a.
  Frame-Anzahl, Tile-Positionsdaten je Frame); maximal 300 KB; muss
  syntaktisch gültig sein und dem definierten Schema entsprechen.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Kein Gerät kann mehr als 12 unterschiedliche Bilder
  gleichzeitig auf dem Server gespeichert haben — verifizierbar durch
  beliebig viele Upload-Versuche desselben Geräts, inklusive gleichzeitiger
  Anfragen.
- **SC-002**: 100 % der Uploads mit einer Datei, die kein gültiges
  Playdate-PDI-Format ist, werden abgelehnt, bevor die Datei dauerhaft
  gespeichert wird.
- **SC-003**: 100 % der Uploads mit einer Bild- oder Positionsdatei über
  300 KB werden abgelehnt.
- **SC-004**: 100 % der Uploads mit ungültigem oder nicht schema-
  konformem JSON werden abgelehnt.
- **SC-005**: Jede Ablehnung liefert eine für den Nutzer erkennbar
  unterscheidbare Begründung (Limit vs. Größe vs. Format vs. Schema) statt
  einer generischen Fehlermeldung.
- **SC-006**: Das Aktualisieren (Re-Sync) eines bereits hochgeladenen
  Bildes bleibt bei erreichtem Limit für 100 % der Testfälle weiterhin
  möglich — bestehende Nutzer verlieren keine Funktionalität.

## Assumptions

- Das 12er-Limit (FR-001) zählt UNTERSCHIEDLICHE Bilder pro Gerät; das
  Aktualisieren (Re-Sync) eines bereits bekannten Bildes zählt nicht als
  neuer Upload — konsistent mit der bereits bestehenden
  Update-in-place-Funktionalität für erneute Synchronisationen desselben
  Bildes.
- Die 300-KB-Grenze (FR-006) gilt JE Einzeldatei (Bilddatei bzw.
  Positionsdatei getrennt), nicht als Summe beider Dateien.
- Das Struktur-Schema für die Positionsdatei (FR-008) orientiert sich an
  der bereits an anderer Stelle im Projekt definierten Datenstruktur für
  Bild-Frame-Daten (Frame-Anzahl, Rastergröße, Tile-Positionsangaben je
  Frame); die exakte Validierungstiefe wird in der Planungsphase mit dem
  tatsächlichen Ist-Zustand des Backends abgeglichen.
- Bereits bestehende Sicherheitsmaßnahmen (PIN-Schutz beim Login,
  Login-Rate-Limiting, HTTPS-Erzwingung) bleiben unverändert und sind
  nicht Gegenstand dieser Spec — sie werden vorausgesetzt, nicht neu
  bewertet.
- Die neuen/verschärften Grenzen (12-Bilder-Limit, 300-KB-Größe,
  Format-/Schema-Validierung) gelten für NEUE Upload-Anfragen ab
  Inkrafttreten dieser Änderung. Bereits vorhandene, älteren Grenzen
  entsprechende Bilder werden dadurch nicht rückwirkend gelöscht oder
  invalidiert (kein Datenverlust für Bestandsnutzer).
- **Bekannte Grenze dieser Spec (bewusst nicht adressiert)**: Die vier
  Maßnahmen verhindern unbegrenztes Hochladen durch EIN bereits verknüpftes
  Gerät. Sie verhindern NICHT, dass jemand das Pro-Gerät-Limit durch
  wiederholtes Neu-Verknüpfen (viele unterschiedliche Geräte-Kennungen)
  umgeht — dieses Risiko ist außerhalb des Scopes dieser Spec und bleibt
  als offener Punkt dokumentiert (siehe Architecture Governance). Ebenfalls
  außerhalb des Scopes: Begrenzung der Upload-HÄUFIGKEIT pro Zeiteinheit
  sowie inhaltliche/anstößigkeitsbezogene Prüfung der Bildinhalte selbst.

---

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Applicable — Backend-Bausteinsicht
  (Upload-Verarbeitung/Validierung wird um Zähl-, Größen- und
  Schema-Prüfung erweitert), Qualitätsmerkmale (Sicherheit/Robustheit,
  Verfügbarkeit/Ressourcenschutz gegen Speicher-Erschöpfung).
- **Qualitätsszenarien**: Applicable —
  - Ressourcenschutz: "Versucht ein Gerät, ein 13. Bild hochzuladen, lehnt
    das System den Upload mit eindeutiger Meldung ab, ohne einen neuen
    Datensatz/eine neue Datei anzulegen" (SC-001).
  - Robustheit: "Lädt ein Client eine Datei über 300 KB oder mit
    ungültigem/schemawidrigem Inhalt hoch, wird sie abgelehnt, bevor sie
    dauerhaft gespeichert wird" (SC-002/SC-003/SC-004).
- **Erwartete Evidenz unter `docs/architecture/`**: Applicable — das
  bestehende `docs/architecture/security-review-backend.md` (aus Spec 005)
  MUSS um die vier neuen/verschärften Maßnahmen aktualisiert werden:
  Upload-Obergrenze pro Gerät (neu), Dateigröße 300 KB (verschärft
  gegenüber der aktuell dort dokumentierten 10-MB-Grenze), PDI-Format-
  Validierung (dort bereits als S-04 gelistet — in der Planungsphase zu
  verifizieren, ob der bestehende Mechanismus den FR-004/FR-005-Anforderungen
  bereits genügt oder erweitert werden muss), JSON-Schema-Validierung
  (neu, bisher laut Sicherheitsreview nur generische JSON-Gültigkeit ohne
  Schema-Prüfung). Owner: Entwickler; Re-Evaluierungs-Trigger:
  `/speckit-plan`-Lauf für diese Spec.
- **ADR erforderlich**: Open — Kandidat: technischer Ansatz für den
  Race-Condition-sicheren Zähl-Check aus FR-011 (z. B. Datenbank-
  Constraint/Transaktion vs. Anwendungslogik mit Sperre). Owner:
  Entwickler; Re-Evaluierungs-Trigger: SDK-/Implementierungs-Verifikation
  in der Planungsphase (Constitution Prinzip I, analog zu bisherigen
  ADR-Entscheidungen in Spec 004/005).
- **Sicherheitsrelevante Architektur**: Ja — direkte Erweiterung der in
  Spec 005 dokumentierten Sicherheitsmaßnahmen (`docs/architecture/
  security-review-backend.md`); alle vier Maßnahmen sind Kernbestandteil
  der Bedrohungsabwehr für den Upload-Pfad. Sofern ein dediziertes
  Secure-Architecture-Preset im Projekt verfügbar wird, ist es auf diese
  Spec anzuwenden; aktuell wird die Sicherheitsbewertung inline über die
  bestehende `docs/architecture/security-review-backend.md`-Evidenz
  geführt.
- **Risiken**: Applicable —
  - Residualrisiko Multi-Geräte-Umgehung (Sybil-artiges wiederholtes
    Neu-Verknüpfen umgeht das Pro-Gerät-Limit) — bewusst außerhalb des
    Scopes, siehe Assumptions; zu beobachten, falls Missbrauch auftritt.
  - Race Conditions bei nahezu gleichzeitigen Upload-Anfragen knapp am
    Limit (FR-011) — erfordert sorgfältige Implementierung
    (Transaktions-/Sperrverhalten), sonst könnte das Limit knapp
    überschritten werden.
- **Technische Schuld**: N/A — diese Spec baut bestehende Deckungslücken
  ab (fehlendes Upload-Limit, zu großzügige 10-MB-Grenze, fehlende
  JSON-Schema-Prüfung) statt neue technische Schuld zu erzeugen.
