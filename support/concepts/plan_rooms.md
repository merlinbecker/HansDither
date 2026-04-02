# Plan für das Raumkonzept

## Szenenbasierter Ablauf

### Räume
1. **StartRaum**
   - Platzhalter: "Willkommen im StartRaum"
   - Datei: `StartRaum.lua`
2. **ZweiterRaum**
   - Platzhalter: "Willkommen im ZweitenRaum"
   - Datei: `ZweiterRaum.lua`
3. **DritterRaum**
   - Platzhalter: "Willkommen im DrittenRaum"
   - Datei: `DritterRaum.lua`

### Ablauf
- Das Spiel beginnt im **StartRaum**.
- Mit dem **A-Knopf** wechselt der Spieler in den nächsten Raum:
  - **StartRaum** → **ZweiterRaum** → **DritterRaum** → **StartRaum** (zyklisch).

### To-Do
- [ ] Lua-Dateien für jeden Raum erstellen.
- [ ] Platzhaltertexte in den jeweiligen Dateien einfügen.
- [ ] Logik für den Raumwechsel mit dem A-Knopf implementieren.
