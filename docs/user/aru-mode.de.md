# ARU-Modus

!!! note "Frühe Implementierung"
    Der ARU-Modus erstellt derzeit eine wiederherstellbare geplante Einsatz-Session und verfolgt geplante Aufnahmezyklen. Zyklus-Audioaufnahme und Android-Vordergrundbenachrichtigungen sind in dieser frühen Version angebunden; Inferenz, reine Detektionsclips und vollständige Review-Wiedergabe sind noch in Entwicklung.

Der ARU-Modus (Autonomous Recording Unit) ist der feste Standort-Workflow für geplante akustische Einsätze.

## Aktueller Setup-Ablauf

- **Einsatz und Audio**: Einsatzname, ARU-/Stations-ID, Beobachtername, festen Standort und Aufnahmemodus eingeben. Das Setup verwendet die gemeinsame Mikrofonauswahl und zeigt die Wettervorschau, wenn Wetterabfragen erlaubt sind. Reine Detektionsclip-Aufnahme und Clip-Aufbewahrungsoptionen bleiben ausgeblendet, bis geplante Inferenz vollständig angebunden ist.
- **Zeitplan**: Zyklusdauer, Wiederholungsintervall, Einsatzende und Stopp bei niedrigem Akku wählen. Sie können manuell stoppen, nach einer festen Anzahl von Zyklen stoppen oder zu einem festen Datum und Zeitpunkt stoppen. Der optionale einminütige Testzyklus ist weiter geplant, bleibt aber verborgen, bis er Ende zu Ende funktioniert.
- **Bereit**: Zeitplan und geschätzten Audiospeicher prüfen, dann den Einsatz starten.

Beim Start wird sofort eine `SessionType.aru`-Session mit ARU-Zeitplanmetadaten gespeichert, damit der Zyklusstatus später wiederhergestellt werden kann.

JSON- und ZIP-Exporte enthalten ARU-Einsatzmetadaten. Wenn eine spätere Version pro Zyklus Aufnahmedateien in der Session speichert, bündelt der ZIP-Export diese Dateien unter `aru_cycles/`.

## Aktiver Einsatz

Der aktive ARU-Bildschirm zeigt, ob der Einsatz wartet, aufnimmt oder abgeschlossen ist. Das Layout folgt jetzt Survey: kompakte Statuszeile, obere Tabs für Zeitplan, Live-Spektrogramm und Übersicht, eine Statistikleiste und darunter eine durchgehende Detektionsliste. Die Liste zeigt während der Aufnahme Detektionen des aktuellen Zyklus und beim Warten die letzten Detektionen des Einsatzes. Unter Android zeigen aktive Einsätze eine Vordergrundbenachrichtigung mit Stopp- und Öffnen-Aktionen.

Unter iOS sollte diese frühe Implementierung als Vordergrund-Workflow behandelt werden, bis geplantes Audio- und Hintergrundverhalten auf iOS validiert wurde.

## Noch geplant

- Inferenz und reine Detektionsclip-Erstellung während geplanter Aufnahmezyklen.
- Validierung des iOS-Hintergrundverhaltens.
- Vollständige Session Review-Wiedergabe und Spektrogramm-Unterstützung für segmentierte ARU-Aufnahmen.
