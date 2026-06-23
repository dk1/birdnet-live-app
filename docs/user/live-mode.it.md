# Modalità Live

La modalità Live è il modo più veloce per ascoltare tramite il microfono del telefono ed esaminare le rilevazioni man mano che appaiono in tempo reale.

## Come aprirla

Dalla schermata Home, tocca la scheda **Modalità Live** con l'icona :material-microphone:.

## Barra superiore

La barra superiore contiene tre elementi:

- :material-arrow-left: — esce dalla modalità Live
- testo di stato al centro — `Inizializzazione…`, `Caricamento modello…`, `Pronto`, `Identificazione delle specie…`, `In pausa` o `Errore`
- :material-tune: — apre la vista Impostazioni specifica di Live

## Pulsante di azione principale

Il grande pulsante circolare in basso al centro cambia stato:

- :material-microphone: — avvia l'ascolto
- :material-stop: — interrompe la Session attiva
- :material-play: — riprende da uno stato in pausa pronto a partire

## Cosa vedi durante l'ascolto

### Spettrogramma

Lo spettrogramma scorre continuamente mentre la cattura è attiva. Mostra il contenuto in frequenza nel tempo, usando la mappa colori, la dimensione FFT, l'intervallo di frequenza e la durata configurati nelle Impostazioni.

### Elenco delle rilevazioni

Le rilevazioni recenti compaiono sotto lo spettrogramma. Ogni riga può mostrare:

- immagine della specie
- nome comune
- nome scientifico facoltativo
- valore di confidenza

Tocca la riga di una specie per aprire il pannello dei dettagli della specie.

### Barra informativa della Session

La riga informativa compatta sotto lo spettrogramma riassume la Session corrente, ad esempio:

- rilevazioni attualmente visibili
- numero di specie uniche (`spp`)
- rilevazioni totali (`det`)
- durata trascorsa
- dimensione stimata della registrazione quando la registrazione è attiva

## Comportamento della registrazione

La registrazione si controlla in [Impostazioni](settings.md).

- **Completa** registra l'intera Session.
- **Solo rilevazioni** registra clip attorno alle rilevazioni.
- **Disattivata** disabilita la registrazione.

Quando interrompi la modalità Live, BirdNET Live salva la Session e apre il [Riepilogo sessione](session-review.md).
