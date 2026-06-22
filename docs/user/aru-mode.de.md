# ARU-Modus

!!! note "Frühe Implementierung"
    Der ARU-Modus erstellt derzeit eine wiederherstellbare geplante ARU-Aufstellung, zeichnet geplante Zyklen auf, führt Live-Inferenz während aktiver Zyklen aus, speichert aufbewahrte Detektionsclips, wenn dieser Aufnahmemodus gewählt ist, und zeigt unter Android Vordergrundbenachrichtigungen. Das iOS-Hintergrundverhalten muss noch im Feld validiert werden.

Der ARU-Modus (Autonomous Recording Unit) ist der feste Standort-Workflow für geplante akustische Aufstellungen.

## Aktueller Setup-Ablauf

- **Aufstellung und Audio**: 
    - **Metadaten**: Geben Sie einen Aufstellungsnamen, eine ARU-/Stations-ID und einen Beobachternamen ein.
    - **Standort**: Geben Sie die Standortkoordinaten über eine automatische GPS-Erfassung, eine manuelle Eingabe von Breitengrad/Längengrad ein oder überspringen Sie die Standorteinrichtung. Breitengrad und Längengrad sind erforderlich, wenn Sie eine sonnenbezogene Zeitplanung verwenden.
    - **Aufnahmeformat**: Wählen Sie zwischen den Formaten FLAC (komprimiert verlustfrei) und WAV (unkomprimiert).
    - **Aufnahmemodus**:
        - *Vollständig*: Zeichnet die gesamte Dauer jedes aktiven Zyklus auf.
        - *Nur Detektionen*: Speichert kurze Audio-Clips um erkannte Vogelstimmen herum. Sie können den Clip-Kontext anpassen (Hinzufügen von 0 bis 5 Sekunden Puffer vor und nach der Erkennung) und die Erfassungsmethode wählen (*Alle*, *Top N* oder *Smart*, um den Speicherplatzbedarf zu begrenzen).
        - *Aus*: Führt Live-Inferenz während der Zyklen aus und protokolliert Erkennungen, speichert jedoch keine Audiodateien.
- **Zeitplan**:
    - **Dauer und Wiederholung**: Wählen Sie aus, wie lange jeder aktive Aufnahmezyklus dauert und wie oft er sich wiederholt.
    - **Aufnahmefenster (Diel-Muster)**: Wählen Sie, ob Sie rund um die Uhr aufnehmen möchten (*Jederzeit*) oder schränken Sie die Zyklen auf *Nur Tag*, *Nur Nacht* oder spezifische Zeitfenster *Um den Sonnenaufgang*, *Um den Sonnenuntergang* oder *Um Sonnenaufgang und Sonnenuntergang* ein. Die Sonnenaufgangs- und Sonnenuntergangsfenster werden dynamisch basierend auf den Koordinaten der Aufstellung berechnet.
    - **Ende des Zeitplans**: Wählen Sie, ob Sie die Aufstellung manuell beenden, nach einer festen Anzahl abgeschlossener Zyklen stoppen oder automatisch zu einem bestimmten Datum und einer bestimmten Uhrzeit stoppen möchten.
    - **Akkumanagement**: Legen Sie einen Schwellenwert für den Stopp bei niedrigem Akkustand (0-50%) fest, um die Aufstellung zu pausieren und eine vollständige Entladung des Akkus zu verhindern. Falls konfiguriert, können Sie einen Schwellenwert für die Wiederaufnahme bei niedrigem Akkustand festlegen, um Aufnahmezyklen automatisch fortzusetzen, wenn sich der Akkustand wieder erholt (z. B. durch Solarladung).
    - **Testlauf**: Ein optionaler einminütiger Testzyklus ist standardmäßig aktiviert, um die Mikrofoneingabe und Inferenz sofort nach dem Start zu überprüfen, ohne auf das geplante Zykluslimit angerechnet zu werden.
    - **Session-Gruppierung**: Konfigurieren Sie, ob jeder Zyklus als separate Session gespeichert werden soll (empfohlen für schnellere Ladezeiten und modulare Betrachtung) oder ob alle Zyklen in einer einzigen, mehrteiligen Session zusammengefasst werden sollen.
- **Bereit**: Überprüfen Sie den Zeitplan, den geschätzten Audiospeicherverbrauch und die Diel-Einschränkungen und starten Sie dann die Aufstellung.

Beim Start wird sofort eine `SessionType.aru`-Session mit ARU-Zeitplanmetadaten gespeichert, damit der Zyklusstatus später wiederhergestellt werden kann.

JSON- und ZIP-Exporte enthalten ARU-Aufstellungsmetadaten. ZIP-Exporte bündeln gespeicherte Aufnahmedateien pro Zyklus unter `aru_cycles/`.

## Aktive Aufstellung

Der aktive ARU-Bildschirm zeigt, ob die Aufstellung wartet, aufnimmt oder abgeschlossen ist. Das Layout verwendet vier Tabs:
- **Status**: Zeigt den aktuellen Aufstellungsstatus, den aktiven Zeitplan-Timer und eine Liste der Echtzeit-Detektionen.
- **Audio**: Zeigt ein live scrollendes Spektrogramm an, um den Audioeingang zu überprüfen, während die Detektionen unten sichtbar bleiben.
- **Plan**: Listet die nächsten 10 geplanten Zykluszeiten auf und zeigt die Ausrichtung an Sonnenaufgang/Sonnenuntergang an, wenn Diel-Einschränkungen aktiv sind.
- **Übersicht**: Fasst die verstrichene Zeit, die gesamte aufgezeichnete Audiodauer und die Detektionsstatistiken zusammen.

Unter Android zeigen aktive Aufstellungen eine Vordergrundbenachrichtigung mit Stopp- und Öffnen-Aktionen.

Beim Stoppen einer Aufstellung wird Session Review geöffnet. Wenn Zyklen in einer Session gruppiert sind, wird diese kombinierte Session geöffnet. Wenn jeder Zyklus als eigene Session gespeichert wird, öffnet das Stoppen die neueste Zyklus-Session.

Unter iOS sollte diese frühe Implementierung als Vordergrund-Workflow behandelt werden, bis geplantes Audio- und Hintergrundverhalten auf iOS validiert wurde.

## Noch geplant

- Validierung des iOS-Hintergrundverhaltens.
- Vollständige Session Review-Wiedergabe und Spektrogramm-Unterstützung für segmentierte ARU-Aufnahmen.
