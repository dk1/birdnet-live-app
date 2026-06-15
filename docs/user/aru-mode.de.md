# ARU-Modus

!!! note "Frühe Implementierung"
    Der ARU-Modus erstellt derzeit eine wiederherstellbare geplante Einsatz-Session, zeichnet geplante Zyklen auf, führt Live-Inferenz während aktiver Zyklen aus, speichert aufbewahrte Detektionsclips, wenn dieser Aufnahmemodus gewählt ist, und zeigt unter Android Vordergrundbenachrichtigungen. Das iOS-Hintergrundverhalten muss noch im Feld validiert werden.

Der ARU-Modus (Autonomous Recording Unit) ist der feste Standort-Workflow für geplante akustische Einsätze.

## Aktueller Setup-Ablauf

- **Einsatz und Audio**: Einsatzname, ARU-/Stations-ID, Beobachtername, festen Standort, Aufnahmemodus, Aufnahmeformat und Regeln zur Aufbewahrung von Detektionsclips eingeben. Das Setup verwendet die gemeinsame Mikrofonauswahl und zeigt die Wettervorschau, wenn Wetterabfragen erlaubt sind.
- **Zeitplan**: Zyklusdauer, Wiederholungsintervall, Einsatzende und Stopp bei niedrigem Akku wählen. Sie können manuell stoppen, nach einer festen Anzahl geplanter Zyklen stoppen oder zu einem festen Datum und Zeitpunkt stoppen. Regelmäßige Zyklen werden an Uhrzeitgrenzen ausgerichtet, sodass ein 10-minütiger Zyklus jede Stunde zur vollen Stunde startet und nicht relativ zum Start des Setups. Der einminütige Testlauf ist standardmäßig aktiviert, startet sofort und verbraucht keinen geplanten Zyklus.
- **Bereit**: Zeitplan und geschätzten Audiospeicher prüfen, dann den Einsatz starten.

Beim Start wird sofort eine `SessionType.aru`-Session mit ARU-Zeitplanmetadaten gespeichert, damit der Zyklusstatus später wiederhergestellt werden kann.

JSON- und ZIP-Exporte enthalten ARU-Einsatzmetadaten. ZIP-Exporte bündeln gespeicherte Aufnahmedateien pro Zyklus unter `aru_cycles/`.

## Aktiver Einsatz

Der aktive ARU-Bildschirm zeigt, ob der Einsatz wartet, aufnimmt oder abgeschlossen ist. Das Layout verwendet vier Tabs: **Status** für aktuellen Einsatzstatus und Detektionen, **Spektrogramm** zur Prüfung eingehenden Audios mit Detektionen darunter, **Zeitplan** für die nächsten 10 geplanten Zykluszeiten und **Übersicht** für verstrichene Zeit, aufgezeichnete Audiodauer und Detektionszahlen. Unter Android zeigen aktive Einsätze eine Vordergrundbenachrichtigung mit Stopp- und Öffnen-Aktionen.

Beim Stoppen eines Einsatzes wird Session Review für den gespeicherten Einsatz geöffnet, wenn Zyklen in einer Session gruppiert sind. Wenn jeder Zyklus als eigene Session gespeichert wird, öffnet das Stoppen die neueste Zyklus-Session.

Unter iOS sollte diese frühe Implementierung als Vordergrund-Workflow behandelt werden, bis geplantes Audio- und Hintergrundverhalten auf iOS validiert wurde.

## Noch geplant

- Validierung des iOS-Hintergrundverhaltens.
- Vollständige Session Review-Wiedergabe und Spektrogramm-Unterstützung für segmentierte ARU-Aufnahmen.
