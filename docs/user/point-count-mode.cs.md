# Režim Point Count

Režim Point Count je časovaný stacionární pracovní postup v BirdNET Live.

## Jak jej otevřít

Na domovské obrazovce klepněte na kartu **Point Count** s ikonou :material-map-marker:.

## Postup nastavení

Nastavení Point Count má čtyři kroky.

### 1. Doba trvání a poloha

Vyberte:

- jeden z dostupných čipů doby trvání
- aktuální GPS pomocí :material-crosshairs-gps:
- ruční souřadnice pomocí :material-map-marker-plus:
- žádnou polohu pomocí :material-map-marker-off:
- výběr na mapě pomocí :material-map:

Obrazovka nastavení obnoví GPS, když se vrátíte ze systémového dialogu oprávnění nebo z nastavení aplikace, takže nově udělené oprávnění k poloze by mělo souřadnice aktualizovat bez restartu průvodce. Tatáž sekce obsahuje i kartu počasí. Pokud je přístup k počasí vypnutý, karta požádá o souhlas **Povolit vyhledání počasí**; po zapnutí zobrazí náhled místa s ikonou počasí, teplotou a pouze větrem. Stejný uložený snímek z Open-Meteo se znovu použije při uložení point countu.

### 2. Parametry inference

Zvolte nastavení analýzy pro tuto session, například dobu okna, rychlost inference, práh spolehlivosti a režim filtru druhů. Vycházejí z vašich globálních nastavení, ale lze je pro tento count upravit beze změny výchozích hodnot.

### 3. Terénní tipy

Tato obrazovka nabízí krátký kontrolní seznam v aplikaci, který je dobré projít před spuštěním.

### 4. Připraveno

Obrazovka připravenosti shrnuje zvolenou dobu trvání a umožní začít pomocí :material-play:.

## Živá obrazovka Point Count

Živá obrazovka point countu se soustředí na časovaný panel.

### Horní lišta

- :material-stop: — předčasné ukončení point countu
- :material-timer: — zobrazení zbývajícího času
- :material-tune: — otevření nastavení Point Count

### Hlavní ukazatele

- ukazatel průběhu odpočtu
- kompaktní informační lišta s aktuálními detekcemi, počtem jedinečných druhů a celkovým počtem detekcí
- zobrazení spektrogramu
- seznam detekcí

## Po sčítání

Když point count skončí, BirdNET Live session uloží a otevře [Přehled Session](session-review.md).
