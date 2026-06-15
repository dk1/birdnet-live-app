# Modalità ARU

!!! note "Implementazione iniziale"
    La modalità ARU attualmente crea una Session di distribuzione programmata e recuperabile, registra i cicli pianificati, esegue inferenza live durante i cicli attivi, salva clip di rilevamento conservate quando è selezionata quella modalità di registrazione e mostra controlli di notifica in primo piano su Android. Il comportamento in background su iOS deve ancora essere validato sul campo.

La modalità ARU (Autonomous Recording Unit) è il flusso di lavoro per distribuzioni acustiche programmate in una posizione fissa.

## Flusso di configurazione attuale

- **Distribuzione e audio**: inserisci nome della distribuzione, ID ARU/stazione, osservatore, sito fisso, modalità di registrazione, formato di registrazione e regole di conservazione delle clip di rilevamento. La configurazione riusa il selettore microfono condiviso e mostra l'anteprima meteo quando la ricerca meteo è consentita.
- **Pianificazione**: scegli durata del ciclo, intervallo di ripetizione, come deve terminare la distribuzione e una soglia di arresto per batteria scarica. Puoi arrestare manualmente, dopo un numero fisso di cicli pianificati o a una data e ora fisse. I cicli regolari sono ancorati ai confini dell'orologio, quindi un ciclo di 10 minuti ogni ora parte all'ora esatta invece che relativamente al momento in cui hai avviato la configurazione. Il test di un minuto è attivo per impostazione predefinita, parte subito e non consuma il conteggio dei cicli pianificati.
- **Pronto**: controlla pianificazione e stima dello spazio audio, quindi avvia la distribuzione.

All'avvio viene salvata subito una Session `SessionType.aru` con metadati del programma ARU, così lo stato dei cicli potrà essere recuperato in seguito.

Le esportazioni JSON e ZIP includono i metadati della distribuzione ARU. Le esportazioni ZIP raggruppano i file di registrazione salvati per ciclo sotto `aru_cycles/`.

## Distribuzione attiva

La schermata ARU attiva mostra se la distribuzione è in attesa, in registrazione o completata. Il layout usa quattro schede: **Stato** per lo stato corrente della distribuzione e i rilevamenti, **Spettrogramma** per verificare che l'audio arrivi mantenendo i rilevamenti sotto, **Pianificazione** per i prossimi 10 orari di ciclo pianificati e **Riepilogo** per tempo trascorso, durata dell'audio registrato e totali dei rilevamenti. Su Android, le distribuzioni attive mostrano una notifica in primo piano con azioni Interrompi e Apri.

Interrompere una distribuzione apre Session Review per la distribuzione salvata quando i cicli sono raggruppati in una sessione. Quando la configurazione salva ogni ciclo come Session separata, l'interruzione apre la Session del ciclo più recente.

Su iOS questa implementazione iniziale deve essere trattata come flusso in primo piano finché audio pianificato e comportamento in background non saranno validati su iOS.

## Ancora pianificato

- Validazione del comportamento in background su iOS.
- Supporto completo per riproduzione e spettrogramma in Session Review per le registrazioni ARU segmentate.
