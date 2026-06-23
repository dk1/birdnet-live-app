# Modo Point Count

El Modo Point Count es el flujo de trabajo estacionario y cronometrado de BirdNET Live.

## Cómo abrirlo

Desde Inicio, toca la tarjeta **Modo Point Count** con el icono :material-map-marker:.

## Flujo de configuración

La configuración del Point Count consta de cuatro pasos.

### 1. Duración y ubicación

Elige:

- uno de los chips de duración disponibles
- GPS actual con :material-crosshairs-gps:
- coordenadas manuales con :material-map-marker-plus:
- sin ubicación con :material-map-marker-off:
- selector de mapa con :material-map:

La pantalla de configuración actualiza el GPS cuando vuelves del diálogo de permisos del sistema o de los ajustes de la app, de modo que un permiso de ubicación recién concedido debería actualizar las coordenadas sin reiniciar el asistente. Esta misma sección incluye también una tarjeta de clima. Si el acceso al clima está desactivado, la tarjeta solicita el consentimiento de **Permitir consulta del clima**; una vez activado, muestra una vista previa del sitio solo con un icono del tiempo, la temperatura y el viento. La misma instantánea en caché de Open-Meteo se reutiliza al guardar el Point Count.

### 2. Parámetros de inferencia

Elige los ajustes de análisis para esta Session, como la duración de ventana, la tasa de inferencia, el umbral de confianza y el modo del filtro de especies. Parten de tus ajustes globales, pero puedes adaptarlos a este conteo sin cambiar tus valores predeterminados.

### 3. Consejos de campo

Esta pantalla presenta una breve lista de comprobación dentro de la app para repasar antes de empezar.

### 4. Listo

La pantalla de listo resume la duración seleccionada y permite empezar con :material-play:.

## Pantalla del Point Count en vivo

La pantalla del Point Count en vivo se centra en un panel cronometrado.

### Barra superior

- :material-stop: — finaliza el Point Count anticipadamente
- :material-timer: — muestra el tiempo restante
- :material-tune: — abre los ajustes de Point Count

### Indicadores principales

- barra de progreso de cuenta atrás
- barra de información compacta con las detecciones actuales, el número de especies únicas y las detecciones totales
- vista del espectrograma
- lista de detecciones

## Después del conteo

Cuando finaliza el Point Count, BirdNET Live guarda la Session y abre el [Resumen de la Session](session-review.md).
