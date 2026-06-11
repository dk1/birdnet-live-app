# Modalità ARU

!!! note "Implementazione iniziale"
    La modalità ARU attualmente crea una sessione di distribuzione programmata e recuperabile e segue i cicli di registrazione pianificati. La registrazione audio per ciclo e le notifiche Android in primo piano sono collegate in questa versione iniziale; inferenza, clip solo per rilevazioni e riproduzione completa in revisione sono ancora in sviluppo.

La modalità ARU (Autonomous Recording Unit) è il flusso di lavoro per distribuzioni acustiche programmate in una posizione fissa.

## Configurazione attuale

- **Distribuzione e audio**: inserisci nome della distribuzione, ID ARU/stazione, osservatore, sito fisso e modalità di registrazione. La configurazione riusa il selettore microfono condiviso e mostra l'anteprima meteo quando la ricerca meteo è consentita. La registrazione di clip solo per rilevazioni e i controlli di conservazione delle clip restano nascosti finché l'inferenza pianificata non è collegata end to end.
- **Programma**: scegli durata del ciclo, intervallo di ripetizione, come deve terminare la distribuzione e una soglia di arresto per batteria scarica. Puoi interrompere manualmente, interrompere dopo un numero fisso di cicli o interrompere a data e ora fisse. Il ciclo di prova opzionale di un minuto è ancora previsto, ma resta nascosto finché non funziona end to end.
- **Pronto**: controlla il programma e l'archiviazione audio stimata, poi avvia la distribuzione.

All'avvio viene salvata subito una sessione `SessionType.aru` con metadati del programma ARU, così lo stato dei cicli potrà essere recuperato in seguito.

Le esportazioni JSON e ZIP includono i metadati della distribuzione ARU. Se una versione successiva salva file di registrazione per ciclo nella sessione, l'esportazione ZIP raggruppa quei file sotto `aru_cycles/`.

## Distribuzione attiva

La schermata ARU attiva mostra se la distribuzione è in attesa, in registrazione o completata. Il layout ora segue Survey: riga di stato compatta, schede superiori per programma, spettrogramma live e riepilogo, una barra statistiche e sotto un feed persistente delle rilevazioni. Il feed mostra le rilevazioni del ciclo corrente durante la registrazione e le rilevazioni recenti della distribuzione durante l'attesa. Su Android, le distribuzioni attive mostrano una notifica in primo piano con azioni Interrompi e Apri.

Su iOS, questa implementazione iniziale deve essere considerata un flusso in primo piano finché l'audio programmato e il comportamento in background non saranno validati su iOS.

## Ancora pianificato

- Inferenza e creazione di clip solo per rilevazioni durante i cicli di registrazione programmati.
- Validazione del comportamento in background su iOS.
- Supporto completo per riproduzione e spettrogramma in Session Review per le registrazioni ARU segmentate.
