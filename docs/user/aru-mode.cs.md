# Režim ARU

!!! note "Předběžná implementace"
    Režim ARU nyní vytváří obnovitelnou naplánovanou Session nasazení, nahrává plánované cykly, spouští živou inferenci během aktivních cyklů, ukládá uchované detekční klipy při zvoleném režimu nahrávání a zobrazuje ovládání oznámení na popředí v Androidu. Chování na pozadí v iOS stále vyžaduje terénní ověření.

Režim ARU (Autonomous Recording Unit) je workflow pro plánovaná akustická nasazení na pevném místě.

## Aktuální postup nastavení

- **Nasazení a zvuk**: 
    - **Metadata**: Zadejte název nasazení, ID ARU/stanice a jméno pozorovatele.
    - **Poloha**: Zadejte souřadnice místa pomocí automatického zaměření GPS, manuálního zadání zeměpisné šířky a délky, nebo nastavení polohy přeskočte. Zeměpisná šířka a délka jsou vyžadovány, pokud používáte plánování vázané na polohu slunce.
    - **Formát nahrávání**: Zvolte mezi formáty FLAC (komprimovaný bezztrátový) a WAV (nekomprimovaný).
    - **Režim nahrávání**:
        - *Plný*: Nahrává celou dobu trvání každého aktivního cyklu.
        - *Pouze detekce*: Ukládá krátké zvukové klipy kolem detekovaných ptačích hlasů. Můžete si přizpůsobit kontext klipu (přidat 0 až 5 sekund vyrovnávací paměti zvuku před detekcí a po ní) a vybrat způsob vzorkování (*Vše*, *Top N* nebo *Chytré* vzorkování pro omezení spotřeby úložného prostoru).
        - *Vypnuto*: Spouští inferenci v reálném čase během cyklů a zaznamenává detekce, ale neukládá žádné zvukové soubory.
- **Plán**:
    - **Doba trvání a opakování**: Zvolte, jak dlouho každý aktivní nahrávací cyklus trvá a jak často se opakuje.
    - **Nahrávací okno (dielní vzorec)**: Zvolte možnost nahrávání 24/7 (*Kdykoli*) nebo omezte cykly na *Pouze den*, *Pouze noc* nebo specifická okna *Kolem východu slunce*, *Kolem západu slunce* nebo *Kolem východu a západu slunce*. Okna východu/západu slunce se počítají dynamicky na základě souřadnic nasazení.
    - **Konec plánu**: Zvolte, zda chcete nasazení zastavit ručně, zastavit po pevném počtu dokončených cyklů, nebo zastavit automaticky v určený den a čas.
    - **Správa baterie**: Nastavte prahovou hodnotu pro zastavení při vybité baterii (0–50 %), aby se nasazení pozastavilo a zabránilo se úplnému vybití baterie. Pokud je to nakonfigurováno, můžete nastavit prahovou hodnotu pro obnovení při vybité baterii pro automatické pokračování nahrávacích cyklů, jakmile se úroveň nabití baterie obnoví (např. pomocí solárního nabíjení).
    - **Testovací běh**: Volitelný jednominutový testovací cyklus je ve výchozím nastavení povolen pro okamžité ověření vstupu mikrofonu a inference po spuštění, aniž by se započítával do limitu plánovaných cyklů.
    - **Seskupování relací**: Nakonfigurujte, zda se má každý cyklus ukládat jako samostatná Session (doporučeno pro rychlejší načítání a modulární prohlížení), nebo zda se mají všechny cykly sloučit do jediné vícesegmentové Session.
- **Připraveno**: Zkontrolujte plán, odhadovanou spotřebu úložného prostoru a dielní omezení a poté spusťte nasazení.

Při spuštění se okamžitě uloží `SessionType.aru` Session s metadaty plánu ARU, aby bylo možné později obnovit stav cyklů.

Exporty JSON a ZIP obsahují metadata nasazení ARU. ZIP exporty přibalí uložené nahrávky jednotlivých cyklů pod `aru_cycles/`.

## Aktivní nasazení

Aktivní obrazovka ARU ukazuje, zda nasazení čeká, nahrává nebo je dokončeno. Rozložení používá čtyři karty:
- **Stav**: Zobrazuje aktuální stav nasazení, aktivní časovač plánu a seznam detekcí v reálném čase.
- **Audio**: Zobrazuje živě se posouvající spektrogram pro ověření zvukového vstupu s detekcemi pod ním.
- **Plán**: Zobrazuje dalších 10 plánovaných časů cyklů s vyznačením zarovnání k východu/západu slunce, pokud jsou aktivní dielní omezení.
- **Souhrn**: Shrnuje uplynulý čas, celkovou dobu nahraného zvuku a statistiky detekcí.

Na Androidu aktivní nasazení zobrazují oznámení na popředí s akcemi Zastavit a Otevřít.

Zastavení nasazení otevře Session Review. Pokud byly cykly seskupeny do jedné Session, otevře se tato kombinovaná Session; pokud byly uloženy jako samostatné Sessions, otevře se nejnovější dokončená Session cyklu.

Na pozadí v iOS by mělo být toto předběžné chování považováno za workflow na popředí, dokud nebude chování naplánovaného audia/pozadí v iOS ověřeno v terénu.

## Stále v plánu

- Terénní ověření chování na pozadí v iOS.
- Plná podpora přehrávání a spektrogramu v Session Review pro segmentované nahrávky ARU.
