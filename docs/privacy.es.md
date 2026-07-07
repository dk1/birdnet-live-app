# Política de Privacidad

**Última actualización:** Julio 2026

BirdNET Live respeta su privacidad. Este documento explica cómo la aplicación maneja sus datos.

## Procesamiento en el dispositivo

Todo el análisis de audio y la identificación de especies de aves ocurren **completamente en su dispositivo**. La app usa dos modelos de redes neuronales que se ejecutan localmente:

- **Clasificador de audio BirdNET+** — analiza el audio del micrófono para identificar especies de aves.
- **Geomodelo BirdNET** — predice qué especies son probables en su ubicación y época del año.

Ningún dato de audio se transmite jamás a servidores externos.

## Recopilación de datos

BirdNET Live **no** recopila, transmite ni comparte ningún dato personal. No hay analítica, ni seguimiento, ni telemetría.

### Datos almacenados localmente en su dispositivo:

| Tipo de dato | Propósito | Almacenamiento |
|--------------|-----------|----------------|
| Grabaciones de audio | Identificación de aves, reproducción, exportación | Archivos locales |
| Resultados de detección | Especies, confianza, marcas de tiempo | Archivos JSON de sesión locales |
| Coordenadas GPS | Geoetiquetado de detecciones, trazas de Survey, predicciones del geomodelo | Archivos JSON de sesión locales |
| Metadatos de sesión | Historial de sesiones, revisión, exportación | Archivos JSON de sesión locales |
| Instantánea meteorológica (opcional) | Captura puntual de temperatura, precipitación, viento, nubosidad y código del tiempo por sesión cuando **Permitir consulta meteorológica** está activo | Archivos JSON de sesión locales |
| Ajustes de la app | Preferencias del usuario | SharedPreferences |

### Datos offline integrados

Las imágenes, descripciones y datos taxonómicos de las especies están **integrados en la app** y se cargan desde recursos locales. No se realizan solicitudes de red para obtener información de especies.

## Recursos Externos

La app puede acceder a los siguientes recursos externos. Cada recurso está controlado por un interruptor independiente bajo **Ajustes → Privacidad**, y **los tres están desactivados por defecto** en una instalación nueva. Nada sale de su dispositivo hasta que usted lo permita.

| Recurso | Propósito | Controlado por | Enviado en cada solicitud |
|---------|-----------|----------------|---------------------------|
| Mosaicos de mapa (OpenStreetMap) | Mapa base para el selector de ubicación, el mapa en vivo de Survey y el mapa de la sesión | **Ajustes → Privacidad → Permitir mosaicos de mapa** | Coordenadas de mosaico `(z, x, y)` y el user-agent de BirdNET Live — sin PII |
| Geocodificación inversa (OpenStreetMap Nominatim) | Resolver coordenadas GPS en un nombre de lugar legible (p. ej. “Madrid, España”) para mostrar en la sesión | **Ajustes → Privacidad → Permitir búsqueda de nombre de lugar** | La latitud/longitud de la sesión, más el user-agent de BirdNET Live |
| Instantánea meteorológica (Open-Meteo) | Captura puntual de las condiciones locales (temperatura, precipitación, viento, nubosidad, código WMO) en las coordenadas de grabación y la hora de fin | **Ajustes → Privacidad → Permitir consulta meteorológica** | La latitud/longitud de la sesión y la marca temporal de fin, más el user-agent de BirdNET Live |

Las solicitudes de mosaicos de mapa son solicitudes HTTPS GET estándar a `tile.openstreetmap.org` con el user-agent de BirdNET Live. Solo se envían las coordenadas del mosaico — sin información de identificación personal.

Las solicitudes de geocodificación inversa envían la latitud y longitud de la sesión a `nominatim.openstreetmap.org` por HTTPS, junto con el user-agent de BirdNET Live tal como exige la [Política de uso de Nominatim](https://operations.osmfoundation.org/policies/nominatim/). El nombre de lugar resuelto se almacena localmente con la sesión, de modo que una sesión solo se geocodifica una vez. No se realiza ninguna solicitud si la sesión no tiene coordenadas GPS o el dispositivo está sin conexión.

Las solicitudes meteorológicas envían la latitud/longitud de la sesión y la marca temporal de fin a `api.open-meteo.com` por HTTPS, junto con el user-agent de BirdNET Live. [Open-Meteo](https://open-meteo.com/) es un servicio gratuito y no requiere ni cuenta ni clave API. La instantánea meteorológica devuelta se almacena localmente con la sesión y también se escribe en la exportación JSON, en el bloque `metadata.json` por sesión y en el informe HTML.

**Retención:** ninguno de los servicios de terceros anteriores es contactado para *subir* o *almacenar* datos del usuario. Los valores devueltos (nombre del lugar, instantánea meteorológica) viven solo dentro del registro local de la sesión en su dispositivo, y solo viajan a los archivos de exportación que usted produzca explícitamente.

**Revocación:** puede desactivar cualquiera de los tres servicios en cualquier momento bajo **Ajustes → Privacidad**. Los nombres de lugar e instantáneas meteorológicas ya almacenados localmente permanecen adjuntos a las sesiones donde se capturaron; elimine esas sesiones desde Session Library o use **Ajustes → Zona de peligro → Borrar todos los datos** para eliminar esos datos históricos.

**No se realizan otras solicitudes de red.** La app funciona completamente sin conexión.

## Enlaces externos

BirdNET Live incluye enlaces a sitios web de terceros que usted puede abrir — por ejemplo, las páginas de **eBird**, **iNaturalist** y **Wikipedia** de una especie y el enlace de audio *«Escucha esta especie en eBird»* en la vista de especie, además de enlaces al sitio del proyecto BirdNET, el código fuente, la guía de usuario y la página de donaciones en la pantalla **Acerca de**. Los enlaces que salen de la app están marcados con un icono de enlace externo (↗) para que pueda reconocerlos antes de tocarlos.

Mientras un enlace solo se muestra no se envía nada, y ningún enlace externo se abre automáticamente: el navegador se abre solo cuando usted lo toca. Al hacerlo, el enlace se abre en el navegador predeterminado de su dispositivo y sale de BirdNET Live. El destino lo gestiona un tercero y se rige por **su propia** política de privacidad y condiciones, no por esta. Esos sitios pueden recopilar de forma independiente información sobre su visita —por ejemplo su dirección IP, datos del dispositivo o del navegador y su forma de interactuar con sus páginas— y establecer sus propias cookies. No controlamos ni nos responsabilizamos del contenido ni de las prácticas de datos de los sitios externos; le recomendamos revisar la política de privacidad de cada sitio.

## GPS y Ubicación

La app usa la ubicación GPS para:

- **Filtrado de especies** — predecir qué especies son probables en su ubicación.
- **Modo Survey** — registrar trazas GPS y geoetiquetar detecciones a lo largo de un transecto.
- **Modo Point count** — etiquetar la ubicación de la observación.

Los datos GPS se almacenan localmente y se incluyen en las exportaciones solo cuando usted comparte o exporta explícitamente una sesión. El acceso a la ubicación requiere su permiso y puede revocarse en cualquier momento desde los ajustes del sistema.

## Exportación de datos

Puede exportar los datos de sesión en varios formatos (Raven Selection Tables, CSV, JSON, GPX) y marcar cualquier combinación de formatos a la vez bajo **Ajustes → Exportar → Formatos**; los formatos seleccionados se agrupan en un único ZIP junto con los clips de audio y el informe HTML autónomo opcional. Las exportaciones se generan localmente y se comparten mediante la hoja de compartir del sistema. La app no sube los datos de exportación a ningún servidor.

## Eliminación de datos

Las sesiones individuales y sus grabaciones pueden eliminarse desde Session Library. Para borrar desde dentro de la app las sesiones locales, grabaciones, notas de voz, listas de especies personalizadas, preferencias y cachés de BirdNET Live, use **Ajustes → Zona de peligro → Borrar todos los datos**. También puede borrar el almacenamiento de la app BirdNET Live en los ajustes de su sistema operativo o desinstalar la app.

## Contacto

Para preguntas sobre privacidad: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
