# Režim Live

Režim Live je nejrychlejší způsob, jak poslouchat přes mikrofon telefonu a sledovat detekce v reálném čase, jak se objevují.

## Jak jej otevřít

Na domovské obrazovce klepněte na kartu **Live** s ikonou :material-microphone:.

## Horní lišta

Horní lišta obsahuje tři prvky:

- :material-arrow-left: — opuštění režimu Live
- středový text stavu — `Inicializace`, `Načítání modelu`, `Připraveno`, `Identifikace druhů`, `Pozastaveno` nebo `Chyba`
- :material-tune: — otevření zobrazení Nastavení specifického pro Live

## Hlavní akční tlačítko

Velké kruhové tlačítko dole uprostřed mění stav:

- :material-microphone: — spustit poslech
- :material-stop: — zastavit aktivní session
- :material-play: — pokračovat ze stavu pozastaveno-připraveno

## Co vidíte při poslechu

### Spektrogram

Spektrogram se nepřetržitě posouvá, dokud je snímání aktivní. Zobrazuje frekvenční obsah v čase a používá barevnou paletu, velikost FFT, frekvenční rozsah a dobu trvání nastavené v Nastavení.

### Seznam detekcí

Nedávné detekce se objevují pod spektrogramem. Každý řádek může zobrazovat:

- obrázek druhu
- běžný název
- volitelný vědecký název
- hodnotu spolehlivosti

Klepnutím na řádek druhu otevřete překryvný panel s podrobnostmi o druhu.

### Informační lišta session

Kompaktní informační řádek pod spektrogramem shrnuje aktuální session, například:

- aktuálně zobrazené detekce
- počet jedinečných druhů (`spp`)
- celkový počet detekcí (`det`)
- uplynulou dobu
- odhadovanou velikost nahrávky, je-li nahrávání zapnuté

## Chování nahrávání

Nahrávání se ovládá v [Nastavení](settings.md).

- **Úplný** zaznamená celou session.
- **Jen detekce** zaznamenává klipy kolem detekcí.
- **Vypnuto** nahrávání zakáže.

Když režim Live zastavíte, BirdNET Live session uloží a otevře [Přehled Session](session-review.md).
