# Modalità Point Count

La modalità Point Count è il flusso di lavoro stazionario a tempo di BirdNET Live.

## Come aprirla

Dalla Home, tocca la scheda **Modalità Point Count** con l'icona :material-map-marker:.

## Flusso di configurazione

La configurazione del Point Count si articola in quattro passaggi.

### 1. Durata e posizione

Scegli:

- uno dei chip di durata disponibili
- GPS attuale con :material-crosshairs-gps:
- coordinate manuali con :material-map-marker-plus:
- nessuna posizione con :material-map-marker-off:
- selettore sulla mappa con :material-map:

La schermata di configurazione aggiorna il GPS quando torni dalla finestra di
autorizzazione di sistema o dalle impostazioni dell'app, così un'autorizzazione
alla posizione appena concessa dovrebbe aggiornare le coordinate senza riavviare
la procedura guidata. La stessa sezione include anche una scheda meteo. Se
l'accesso al meteo è disattivato, la scheda chiede il consenso **Consenti
ricerca meteo**; una volta abilitato, mostra un'anteprima del sito con un'icona
meteo, solo temperatura e vento. Lo stesso snapshot di Open-Meteo memorizzato
nella cache viene riutilizzato quando il Point Count viene salvato.

### 2. Parametri di inferenza

Scegli impostazioni di analisi specifiche per la Session, come durata della
finestra, frequenza di inferenza, soglia di confidenza e modalità del filtro
specie. Partono dalle tue impostazioni globali, ma possono essere regolate per
questo conteggio senza modificare i valori predefiniti.

### 3. Consigli sul campo

Questa schermata presenta una breve lista di controllo in-app da seguire prima di iniziare.

### 4. Pronto

La schermata di pronto riassume la durata selezionata e ti consente di iniziare con :material-play:.

## Schermata del Point Count in tempo reale

La schermata del Point Count in tempo reale è incentrata su una dashboard a tempo.

### Barra superiore

- :material-stop: — termina il Point Count in anticipo
- :material-timer: — mostra il tempo rimanente
- :material-tune: — apre le impostazioni Point Count

### Indicatori principali

- barra di avanzamento del conto alla rovescia
- barra informativa compatta con rilevazioni attuali, numero di specie uniche e rilevazioni totali
- vista dello spettrogramma
- elenco delle rilevazioni

## Dopo il conteggio

Al termine del Point Count, BirdNET Live salva la Session e apre il [Riepilogo sessione](session-review.md).
