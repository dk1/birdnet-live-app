# Režim ARU

!!! note "Raná implementace"
    Režim ARU nyní vytváří obnovitelnou naplánovanou relaci nasazení a sleduje plánované nahrávací cykly. Zvukové nahrávání cyklů a oznámení na popředí v Androidu jsou v této rané verzi zapojeny; inference, klipy pouze pro detekce a plné přehrávání v kontrole jsou stále ve vývoji.

Režim ARU (Autonomous Recording Unit) je workflow pro plánovaná akustická nasazení na pevném místě.

## Aktuální nastavení

- **Nasazení a zvuk**: Zadejte název nasazení, ID ARU/stanice, jméno pozorovatele, pevnou lokalitu a režim nahrávání. Nastavení používá společný výběr mikrofonu a při povoleném počasí zobrazuje náhled počasí. Nahrávání klipů pouze pro detekce a volby uchování klipů zůstávají skryté, dokud nebude naplánovaná inference zapojena end to end.
- **Plán**: Vyberte délku cyklu, interval opakování, způsob ukončení nasazení a zastavení při nízké baterii. Můžete zastavit ručně, po pevném počtu cyklů nebo v pevné datum a čas. Volitelný jednominutový testovací cyklus je stále plánovaný, ale zůstává skrytý, dokud nebude fungovat end to end.
- **Připraveno**: Zkontrolujte plán a odhad úložiště zvuku, potom spusťte nasazení.

Při spuštění se okamžitě uloží relace `SessionType.aru` s metadaty plánu ARU, aby bylo možné později obnovit stav cyklů.

Exporty JSON a ZIP obsahují metadata nasazení ARU. Pokud pozdější verze uloží do relace nahrávací soubory po cyklech, ZIP export tyto soubory přibalí pod `aru_cycles/`.

## Aktivní nasazení

Aktivní obrazovka ARU ukazuje, zda nasazení čeká, nahrává nebo je dokončeno. Rozložení nyní odpovídá Survey: kompaktní stavový řádek, horní karty pro plán, živý spektrogram a souhrn, statistický pruh a trvalý seznam detekcí dole. Seznam při nahrávání zobrazuje detekce aktuálního cyklu a při čekání poslední detekce nasazení. Na Androidu aktivní nasazení zobrazují oznámení na popředí s akcemi Zastavit a Otevřít.

Na iOS je třeba tuto ranou implementaci považovat za workflow na popředí, dokud nebude naplánovaný zvuk a chování na pozadí na iOS ověřeno.

## Stále plánováno

- Inference a vytváření klipů pouze pro detekce během plánovaných nahrávacích cyklů.
- Ověření chování na pozadí v iOS.
- Plná podpora přehrávání a spektrogramu v Session Review pro segmentované nahrávky ARU.
