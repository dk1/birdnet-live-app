# Polityka prywatności

**Ostatnia aktualizacja:** lipiec 2026

BirdNET Live szanuje Twoją prywatność. Ten dokument wyjaśnia, jak aplikacja obchodzi się z Twoimi danymi.

## Przetwarzanie na urządzeniu

Cała analiza dźwięku i identyfikacja gatunków ptaków odbywają się **w całości na Twoim urządzeniu**. Aplikacja korzysta z dwóch modeli sieci neuronowych działających lokalnie:

- **Klasyfikator dźwięku BirdNET+** — analizuje dźwięk z mikrofonu, aby identyfikować gatunki ptaków.
- **Geomodel BirdNET** — przewiduje, które gatunki są prawdopodobne w Twojej lokalizacji i porze roku.

Żadne dane dźwiękowe nigdy nie są przesyłane na zewnętrzne serwery.

## Zbieranie danych

BirdNET Live **nie** zbiera, nie przesyła ani nie udostępnia żadnych danych osobowych. Nie ma analityki, śledzenia ani telemetrii.

### Dane przechowywane lokalnie na Twoim urządzeniu:

| Rodzaj danych | Cel | Miejsce przechowywania |
|---------------|-----|------------------------|
| Nagrania audio | Identyfikacja ptaków, odtwarzanie, eksport | Pliki lokalne |
| Wyniki detekcji | Gatunki, pewność, znaczniki czasu | Lokalne pliki JSON sesji |
| Współrzędne GPS | Geotagowanie detekcji, trasy Survey, przewidywania geomodelu | Lokalne pliki JSON sesji |
| Metadane sesji | Historia sesji, przegląd, eksport | Lokalne pliki JSON sesji |
| Migawka pogody (opcjonalnie) | Jednorazowy zapis temperatury, opadów, wiatru, zachmurzenia i kodu pogody na sesję, gdy **Zezwalaj na wyszukiwanie pogody** jest włączone | Lokalne pliki JSON sesji |
| Ustawienia aplikacji | Preferencje użytkownika | SharedPreferences |

### Dołączone dane offline

Zdjęcia gatunków, opisy i dane taksonomiczne są **dołączone do aplikacji** i ładowane z lokalnych zasobów. Nie są wykonywane żadne żądania sieciowe w celu pobrania informacji o gatunkach.

## Zasoby zewnętrzne

Aplikacja może uzyskiwać dostęp do następujących zasobów zewnętrznych. Każdy zasób jest kontrolowany przez niezależny przełącznik w **Ustawienia → Prywatność**, a **wszystkie trzy są domyślnie wyłączone** przy nowej instalacji. Nic nie opuszcza Twojego urządzenia, dopóki nie wyrazisz zgody.

| Zasób | Cel | Kontrolowany przez | Wysyłane w każdym żądaniu |
|-------|-----|--------------------|---------------------------|
| Kafelki mapy (OpenStreetMap) | Mapa podkładowa dla wyboru lokalizacji, mapy na żywo Survey i mapy sesji | **Ustawienia → Prywatność → Zezwalaj na kafelki mapy** | Współrzędne kafelka `(z, x, y)` i user-agent BirdNET Live — bez PII |
| Odwrotne geokodowanie (OpenStreetMap Nominatim) | Zamiana współrzędnych GPS na czytelną nazwę miejsca (np. „Berlin, Niemcy”) do wyświetlenia sesji | **Ustawienia → Prywatność → Zezwalaj na wyszukiwanie nazw miejsc** | Szerokość/długość geograficzna sesji oraz user-agent BirdNET Live |
| Migawka pogody (Open-Meteo) | Jednorazowy zapis lokalnych warunków (temperatura, opady, wiatr, zachmurzenie, kod WMO) we współrzędnych nagrania i czasie zakończenia | **Ustawienia → Prywatność → Zezwalaj na wyszukiwanie pogody** | Szerokość/długość geograficzna sesji i znacznik czasu zakończenia oraz user-agent BirdNET Live |

Żądania kafelków mapy to standardowe żądania HTTPS GET do `tile.openstreetmap.org` z user-agentem BirdNET Live. Wysyłane są tylko współrzędne kafelka — żadnych danych umożliwiających identyfikację osoby.

Żądania odwrotnego geokodowania wysyłają szerokość i długość geograficzną sesji do `nominatim.openstreetmap.org` przez HTTPS, wraz z user-agentem BirdNET Live zgodnie z [Zasadami korzystania z Nominatim](https://operations.osmfoundation.org/policies/nominatim/). Rozpoznana nazwa miejsca jest zapisywana lokalnie z sesją, więc każda sesja jest geokodowana tylko raz. Żadne żądanie nie jest wysyłane, jeśli sesja nie ma współrzędnych GPS lub urządzenie jest offline.

Żądania pogody wysyłają szerokość/długość geograficzną sesji i znacznik czasu zakończenia do `api.open-meteo.com` przez HTTPS, wraz z user-agentem BirdNET Live. [Open-Meteo](https://open-meteo.com/) to bezpłatna usługa, która nie wymaga konta ani klucza API. Zwrócona migawka pogody jest zapisywana lokalnie z sesją, a także zapisywana w eksporcie JSON, bloku `metadata.json` sesji oraz raporcie HTML.

**Przechowywanie:** żadna z powyższych usług zewnętrznych nie jest kontaktowana w celu *przesłania* ani *przechowywania* danych użytkownika. Zwrócone wartości (nazwa miejsca, migawka pogody) istnieją tylko w lokalnym rekordzie sesji na Twoim urządzeniu i trafiają wyłącznie do plików eksportu, które utworzysz w sposób jawny.

**Wycofanie zgody:** każdą z trzech usług możesz wyłączyć w dowolnym momencie w **Ustawienia → Prywatność**. Zapisane już lokalnie nazwy miejsc i migawki pogody pozostają dołączone do sesji, w których zostały zarejestrowane; usuń te sesje z Biblioteki sesji lub użyj **Ustawienia → Strefa zagrożenia → Wyczyść wszystkie dane**, aby usunąć te dane historyczne.

**Nie są wykonywane żadne inne żądania sieciowe.** Aplikacja działa w pełni offline.

## Linki zewnętrzne

BirdNET Live zawiera linki do witryn stron trzecich, które możesz otworzyć — na przykład strony **eBird**, **iNaturalist** i **Wikipedia** danego gatunku oraz link audio *„Posłuchaj tego gatunku na eBird”* w widoku gatunku, a także linki do witryny projektu BirdNET, kodu źródłowego, przewodnika użytkownika i strony darowizn na ekranie **O aplikacji**. Linki, które opuszczają aplikację, są oznaczone ikoną linku zewnętrznego (↗), abyś rozpoznał je przed dotknięciem.

Dopóki link jest tylko wyświetlany, nic nie jest wysyłane, i żaden link zewnętrzny nigdy nie otwiera się automatycznie — przeglądarka otwiera się dopiero, gdy go dotkniesz. Link otwiera się wtedy w domyślnej przeglądarce Twojego urządzenia i opuszczasz BirdNET Live. Miejsce docelowe jest prowadzone przez stronę trzecią i podlega **jej własnej** polityce prywatności i regulaminowi, a nie niniejszym. Takie witryny mogą niezależnie zbierać informacje o Twojej wizycie — na przykład Twój adres IP, dane urządzenia lub przeglądarki oraz sposób, w jaki korzystasz z ich stron — i ustawiać własne pliki cookie. Nie kontrolujemy treści ani praktyk dotyczących danych witryn zewnętrznych i nie ponosimy za nie odpowiedzialności; zapoznaj się z polityką prywatności każdej witryny.

## GPS i lokalizacja

Aplikacja używa lokalizacji GPS do:

- **Filtrowania gatunków** — przewidywania, które gatunki są prawdopodobne w Twojej lokalizacji.
- **Trybu Survey** — rejestrowania tras GPS i geotagowania detekcji wzdłuż transektu.
- **Trybu Point Count** — oznaczania miejsca obserwacji.

Dane GPS są przechowywane lokalnie i dołączane do eksportów tylko wtedy, gdy jawnie udostępnisz lub wyeksportujesz sesję. Dostęp do lokalizacji wymaga Twojej zgody i można go cofnąć w dowolnym momencie w ustawieniach systemu.

## Eksport danych

Dane sesji możesz eksportować w wielu formatach (Raven Selection Tables, CSV, JSON, GPX) i w **Ustawienia → Eksportuj → Formaty** zaznaczyć dowolną kombinację formatów naraz; wybrane formaty są pakowane razem do jednego pliku ZIP obok klipów audio i opcjonalnego samodzielnego raportu HTML. Eksporty są generowane lokalnie i udostępniane przez systemowy panel udostępniania. Aplikacja nie przesyła danych eksportu na żaden serwer.

## Usuwanie danych

Pojedyncze sesje i ich nagrania można usunąć z Biblioteki sesji. Aby z poziomu aplikacji wymazać lokalne sesje, nagrania, notatki głosowe, niestandardowe listy gatunków, preferencje i pamięci podręczne BirdNET Live, użyj **Ustawienia → Strefa zagrożenia → Wyczyść wszystkie dane**. Możesz też wyczyścić pamięć aplikacji BirdNET Live w ustawieniach systemu operacyjnego lub odinstalować aplikację.

## Kontakt

W sprawach dotyczących prywatności: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
