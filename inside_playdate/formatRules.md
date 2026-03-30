# Markdown Formatierungsregeln für Playdate-Dokumentation

Diese Regeln sorgen für eine konsistente, lesbare und strukturierte Dokumentation der Playdate SDK-Abschnitte.

## 1. Überschriften
- Hauptabschnitte (z.B. "7.16 Display", "7.32 UI Components") als `###` (h3) Markdown-Header.
- **Fettgedruckte Funktionsnamen** unterhalb der Hauptüberschrift werden als eigene `###` (h3) Markdown-Header formatiert.
- Keine weiteren Überschriftenebenen verwenden, außer wenn für die Lesbarkeit zwingend nötig.

## 2. Funktionsdokumentation
- Funktionsnamen und Properties als eigene `###`-Header, z.B. `### playdate.ui.crankIndicator:draw([xOffset, yOffset])`.
- Direkt darunter folgt die Beschreibung und ggf. Parameter-/Rückgabewerte.

## 3. Links und Bilder
- Alle externen und internen Links entfernen.
- Bilder und Grafiken entfernen.
- Wichtige Hinweise aus Link- oder Bildunterschriften als normalen Text übernehmen.

## 4. Tabellen
- Tabellen entfernen und relevante Informationen als Fließtext oder Aufzählung übernehmen.

## 5. Codebeispiele
- Codebeispiele in Markdown-Codeblöcken mit passender Sprache (z.B. ```lua) formatieren.
- Beispielcode möglichst kompakt und verständlich halten.

## 6. Hinweise und Tipps
- Wichtige Hinweise als **Important:** oder _Hinweis:_ im Fließtext hervorheben.

## 7. Allgemeine Lesbarkeit
- Keine Information entfernen, aber unnötige Formatierungen, Links und Bilder weglassen.
- Klar strukturierte Abschnitte, kurze Sätze, konsistente Formatierung.

---

Diese Regeln gelten für alle modularisierten Playdate-Dokumentationsdateien im Ordner `inside_playdate/`.
