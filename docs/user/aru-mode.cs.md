# Režim ARU

!!! note "Raná implementace"
    Režim ARU nyní vytváří obnovitelnou naplánovanou Session nasazení, nahrává plánované cykly, spouští živou inferenci během aktivních cyklů, ukládá uchované detekční klipy při zvoleném režimu nahrávání a zobrazuje ovládání oznámení na popředí v Androidu. Chování na pozadí v iOS stále vyžaduje terénní ověření.

Režim ARU (Autonomous Recording Unit) je workflow pro plánovaná akustická nasazení na pevném místě.

## Aktuální nastavení

- **Nasazení a zvuk**: Zadejte název nasazení, ID ARU/stanice, jméno pozorovatele, pevnou lokalitu, režim nahrávání, formát nahrávání a pravidla uchování detekčních klipů. Nastavení používá společný výběr mikrofonu a při povoleném počasí zobrazuje náhled počasí.
- **Plán**: Vyberte délku cyklu, interval opakování, způsob ukončení nasazení a zastavení při nízké baterii. Můžete zastavit ručně, po pevném počtu plánovaných cyklů nebo v pevné datum a čas. Pravidelné cykly jsou zarovnané na hranice nástěnných hodin, takže desetiminutový cyklus každou hodinu začne v celou hodinu, ne relativně k okamžiku spuštění nastavení. Jednominutový test je ve výchozím stavu zapnutý, začne okamžitě a nespotřebuje počet plánovaných cyklů.
- **Připraveno**: Zkontrolujte plán a odhad úložiště zvuku, potom spusťte nasazení.

Při spuštění se okamžitě uloží `SessionType.aru` Session s metadaty plánu ARU, aby bylo možné později obnovit stav cyklů.

Exporty JSON a ZIP obsahují metadata nasazení ARU. ZIP exporty přibalí uložené nahrávky jednotlivých cyklů pod `aru_cycles/`.

## Aktivní nasazení

Aktivní obrazovka ARU ukazuje, zda nasazení čeká, nahrává nebo je dokončeno. Rozložení používá čtyři karty: **Stav** pro aktuální stav nasazení a detekce, **Spektrogram** pro kontrolu příchozího zvuku s detekcemi pod ním, **Plán** pro dalších 10 plánovaných časů cyklů a **Souhrn** pro uplynulý čas, dobu nahraného zvuku a počty detekcí. Na Androidu aktivní nasazení zobrazují oznámení na popředí s akcemi Zastavit a Otevřít.

Zastavení nasazení otevře Session Review pro uložené nasazení, když jsou cykly seskupené do jedné Session. Když nastavení ukládá každý cyklus jako samostatnou Session, zastavení otevře nejnovější Session cyklu.

Na iOS je třeba tuto ranou implementaci považovat za workflow na popředí, dokud nebude plánovaný zvuk a chování na pozadí na iOS ověřeno.

## Stále plánováno

- Ověření chování na pozadí v iOS.
- Plná podpora přehrávání a spektrogramu v Session Review pro segmentované nahrávky ARU.
