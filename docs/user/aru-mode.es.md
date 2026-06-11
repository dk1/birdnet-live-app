# Modo ARU

!!! note "Implementación inicial"
    El modo ARU actualmente crea una sesión de despliegue programada y recuperable, y sigue los ciclos de grabación planificados. La grabación de audio por ciclo y las notificaciones en primer plano de Android ya están conectadas en esta versión inicial; la inferencia, los clips solo de detección y la reproducción completa en revisión siguen en desarrollo.

El modo ARU (Autonomous Recording Unit) es el flujo de trabajo para despliegues acústicos programados en una ubicación fija.

## Configuración actual

- **Despliegue y audio**: Introduzca nombre de despliegue, ID de ARU/estación, observador, ubicación fija y modo de grabación. La configuración reutiliza el selector de micrófono compartido y muestra la vista previa del clima cuando la búsqueda meteorológica está permitida. La grabación de clips solo de detección y los controles de retención de clips permanecen ocultos hasta que la inferencia programada esté conectada de extremo a extremo.
- **Horario**: Elija duración del ciclo, intervalo de repetición, cómo debe finalizar el despliegue y un umbral de parada por batería baja. Puede detener manualmente, detener tras un número fijo de ciclos o detener en una fecha y hora fijas. El ciclo de prueba opcional de un minuto sigue planificado, pero permanece oculto hasta que funcione de extremo a extremo.
- **Listo**: Revise el horario y el almacenamiento de audio estimado, luego inicie el despliegue.

Al iniciar, se guarda inmediatamente una sesión `SessionType.aru` con metadatos del horario ARU para poder recuperar el estado de los ciclos más tarde.

Las exportaciones JSON y ZIP incluyen metadatos del despliegue ARU. Si una versión posterior guarda archivos de grabación por ciclo en la sesión, la exportación ZIP empaqueta esos archivos en `aru_cycles/`.

## Despliegue activo

La pantalla ARU activa muestra si el despliegue está esperando, grabando o completado. El diseño ahora sigue a Survey: fila de estado compacta, pestañas superiores para horario, espectrograma en vivo y resumen, una barra de estadísticas y un panel persistente de detecciones debajo. El panel muestra detecciones del ciclo actual durante la grabación y detecciones recientes del despliegue mientras espera. En Android, los despliegues activos muestran una notificación en primer plano con acciones Detener y Abrir.

En iOS, esta implementación inicial debe tratarse como un flujo en primer plano hasta que el audio programado y el comportamiento en segundo plano se validen en iOS.

## Aún planificado

- Inferencia y creación de clips solo de detección durante los ciclos de grabación programados.
- Validación del comportamiento en segundo plano en iOS.
- Soporte completo de reproducción y espectrograma en Session Review para grabaciones ARU segmentadas.
