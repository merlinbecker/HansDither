# Quickstart: Validierung Backend-Sync (Playdate-Seite)

**Feature**: 004-backend-sync | **Purpose**: End-to-End-Validierung des Crank-Sync-Workflows gegen das bestehende Backend (Spec 005)

---

## Vorbereitung

### Voraussetzungen
- [ ] Playdate SDK installiert (`pdc` im PATH, verifiziert: v3.0.6)
- [ ] Lua-Interpreter für Headless-Tests (`lua tests/headless_tests.lua`)
- [ ] Backend erreichbar (entweder `https://www.hans-dither.de` oder lokale PHP-Testinstanz, siehe `backend/TESTING.md`)
- [ ] Ein Test-Image bereits im Editor erstellt und gespeichert (mind. 1 Frame)
- [ ] QR-Scanner-fähiges Zweitgerät (Smartphone) für den Pairing-Flow

### Constitution-Gate (Prinzip V, vor jeder Abschlussmeldung)
1. `lua tests/headless_tests.lua` → MUSS mit "ALLE TESTS BESTANDEN" enden
2. `pdc Source "Hans Dither.pdx"` → MUSS fehlerfrei durchlaufen

---

## Validierungsszenarien

### Szenario 1: Crank-Hinweis erscheint bei Bildauswahl (FR-002a)
**Ziel**: Sync-Einstiegspunkt ist entdeckbar

**Schritte**:
1. Playdate-Simulator starten, SelectionRoom öffnen
2. Ein Bild in der Gridview selektieren (Cursor bewegen)

**Erwartet**: Text "crank to sync" + `crankIndicator`-Icon erscheinen; verschwinden, wenn kein Bild selektiert ist (z. B. leere Grid-Zelle)

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 2: Crank-Geste löst Pairing aus (US1, FR-002–FR-004)
**Ziel**: Erstverknüpfung per QR-Code

**Voraussetzung**: Kein `sync/state` vorhanden (Datastore-Datei ggf. manuell löschen für Testreset)

**Schritte**:
1. Bild selektieren
2. Kurbel zwei volle Umdrehungen im Uhrzeigersinn drehen (im Simulator: Crank-Slider ziehen)
3. QR-Code + 4-stellige PIN werden angezeigt

**Erwartet**: QR-Code kodiert `https://www.hans-dither.de/?uid={UID}`; PIN besteht aus genau 4 Ziffern

**Prüfungen**:
- [ ] QR-Code mit externem Scanner lesbar
- [ ] `sync/state` enthält `uid`, `pin`, `paired=false`

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 3: Pairing im Browser abschließen (US1, FR-004a)
**Ziel**: Verknüpfung serverseitig herstellen

**Voraussetzung**: Szenario 2 erfolgreich

**Schritte**:
1. QR-Code mit Smartphone scannen → Backend-URL öffnet sich, leitet zu `/pair?uid=...` weiter (da UID unbekannt)
2. Auf dem Playdate angezeigte PIN im Browser-Formular eingeben, bestätigen

**Erwartet**: Backend zeigt "Verknüpfung erfolgreich hergestellt"

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 4: Playdate erkennt abgeschlossenes Pairing (FR-006a)
**Ziel**: Statusprüfung ohne erneute Nutzereingabe

**Voraussetzung**: Szenario 3 erfolgreich

**Schritte**:
1. Auf dem Playdate warten bzw. erneut ein Bild selektieren (Status-Poll gemäß contracts/sync-protocol.md Schritt A)

**Erwartet**: Verknüpfungsstatus wechselt zu "verknüpft mit Backend-URL" (FR-012); `sync/state.paired = true`

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 5: Einzelbild-Upload per Crank-Geste (US2, FR-006/FR-007)
**Ziel**: Genau ein Bild wird ohne erneute PIN-Eingabe hochgeladen

**Voraussetzung**: Szenario 4 erfolgreich (verknüpft)

**Schritte**:
1. Test-Bild selektieren
2. Kurbel zwei volle Umdrehungen im Uhrzeigersinn drehen
3. Upload-Fortschritt beobachten (FR-015)

**Erwartet**: Keine PIN-Abfrage; nach Abschluss erscheint erneut der QR-Code (FR-007a)

**Prüfungen**:
- [ ] Backend-Log/DB zeigt neuen Image-Eintrag unter der Test-UID
- [ ] Hochgeladene PDI/JSON entsprechen exakt dem lokalen Original (Byte-Vergleich)

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 6: Ergebnis im Backend sichtbar (US2 AC4, SC-002)
**Ziel**: Hochgeladenes Bild ist über den Post-Upload-QR erreichbar

**Voraussetzung**: Szenario 5 erfolgreich

**Schritte**:
1. Post-Upload-QR-Code scannen → Backend-Login mit PIN im Browser
2. Images-Liste öffnen

**Erwartet**: Neues Bild erscheint innerhalb von 5 Sekunden (SC-002) mit Vorschau-PNG

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 7: Kurbel eingeklappt (Edge Case)
**Ziel**: Nutzer wird zum Ausklappen aufgefordert

**Schritte**:
1. Bild selektieren, Kurbel im Simulator einklappen (`isCrankDocked` simulieren)

**Erwartet**: System-Crank-Alert erscheint zusätzlich zum "crank to sync"-Hinweis

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 8: Unvollständige Drehung / Richtungswechsel (Edge Case)
**Ziel**: Kein versehentliches Auslösen

**Schritte**:
1. Bild selektieren, Kurbel nur 300° drehen, dann stoppen
2. Kurbel 400° im Uhrzeigersinn, dann 200° zurück drehen

**Erwartet**: Sync wird in beiden Fällen NICHT ausgelöst; Akkumulator setzt bei signifikantem Richtungswechsel zurück

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 9: Verknüpfung zurücksetzen (FR-013)
**Ziel**: Gegen-Uhrzeigersinn-Geste setzt Pairing zurück

**Voraussetzung**: Szenario 4 erfolgreich (verknüpft)

**Schritte**:
1. Bild selektieren, Kurbel zwei volle Umdrehungen gegen den Uhrzeigersinn drehen
2. Bestätigungsschritt bestätigen

**Erwartet**: `sync/state` zurückgesetzt; nächste Crank-Sync-Geste generiert neue PIN und zeigt neuen QR-Code (zurück zu Szenario 2)

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 10: Netzwerkfehler während Upload (Edge Case, SC-006)
**Ziel**: Playdate-Bedienung bleibt nicht blockiert

**Schritte**:
1. Upload starten (Szenario 5), WLAN/Netzwerk während der Übertragung trennen

**Erwartet**: Fehler "Backend nicht erreichbar", Upload kann später wiederholt werden; UI bleibt bedienbar (D-Pad/A/B reagieren weiter)

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 11: Zurückgesetzte Verknüpfung im Backend (Edge Case)
**Ziel**: Playdate erkennt ungültig gewordene lokale PIN

**Schritte**:
1. Verknüpfung im Backend (z. B. über eine neue Verknüpfung derselben UID mit neuer PIN) invalidieren
2. Crank-Sync-Geste auf dem Playdate ausführen

**Erwartet**: Fehler "Nicht autorisiert – bitte erneut verknüpfen"; Nutzer wird zum Pairing-Flow (Szenario 2) geleitet

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

## Performance (SC-001, SC-005)

- [ ] Szenario 2+3+4 (vollständiges Pairing) < 2 Minuten (SC-001)
- [ ] Ohne Anleitung: Pairing + erster Upload < 5 Minuten (SC-005)

---

## Befunde und Notes

| Datum | Szenario | Status | Befund | Owner | Follow-up |
|---|---|---|---|---|---|
| 2026-07-18 | Alle | Offen | Initialer Validierungsplan (Planungsphase) | - | - |

---

## Abhängigkeiten

- Spec 001: PDI-/JSON-Format der Testdateien
- Spec 005: Backend-Endpunkte (`/login`, `/upload`, `/?uid=`), bereits deployt/deploybar via `backend/deploy.sh`
- `backend/TESTING.md`: lokale Backend-Testinstanz als Alternative zu www.hans-dither.de
