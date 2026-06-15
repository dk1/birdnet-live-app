# Modo ARU

!!! note "Implementación inicial"
    El modo ARU actualmente crea una Session de despliegue programada y recuperable, graba ciclos programados, ejecuta inferencia en vivo durante los ciclos activos, guarda clips de detección retenidos cuando se selecciona ese modo de grabación y muestra controles de notificación en primer plano en Android. El comportamiento en segundo plano en iOS aún necesita validación de campo.

El modo ARU (Autonomous Recording Unit) es el flujo de trabajo para despliegues acústicos programados en una ubicación fija.

## Flujo de configuración actual

- **Despliegue y audio**: Introduzca nombre de despliegue, ID de ARU/estación, observador, ubicación fija, modo de grabación, formato de grabación y reglas de retención de clips de detección. La configuración reutiliza el selector de micrófono compartido y muestra la vista previa del clima cuando la búsqueda meteorológica está permitida.
- **Horario**: Elija duración del ciclo, intervalo de repetición, cómo debe terminar el despliegue y un umbral de parada por batería baja. Puede detener manualmente, detener después de un número fijo de ciclos programados o detener en una fecha y hora fijas. Los ciclos regulares se anclan a límites del reloj, por lo que un ciclo de 10 minutos cada hora empieza a la hora exacta en lugar de ser relativo al momento en que inició la configuración. La prueba de un minuto está activada de forma predeterminada, empieza inmediatamente y no consume el recuento de ciclos programados.
- **Listo**: Revise el horario y el almacenamiento de audio estimado, luego inicie el despliegue.

Al iniciar, se guarda inmediatamente una Session `SessionType.aru` con metadatos del horario ARU para poder recuperar el estado de los ciclos más tarde.

Las exportaciones JSON y ZIP incluyen metadatos del despliegue ARU. Las exportaciones ZIP agrupan los archivos de grabación por ciclo guardados en `aru_cycles/`.

## Despliegue activo

La pantalla ARU activa muestra si el despliegue está esperando, grabando o completado. Su diseño usa cuatro pestañas: **Estado** para el estado actual del despliegue y las detecciones, **Espectrograma** para comprobar que llega audio mientras mantiene las detecciones debajo, **Horario** para los próximos 10 horarios de ciclo programados y **Resumen** para tiempo transcurrido, duración de audio grabado y totales de detecciones. En Android, los despliegues activos muestran una notificación en primer plano con acciones Detener y Abrir.

Al detener un despliegue se abre Session Review para el despliegue guardado cuando los ciclos están agrupados en una sesión. Cuando la configuración guarda cada ciclo como una Session separada, al detener se abre la Session del ciclo más reciente.

En iOS, esta implementación inicial debe tratarse como un flujo en primer plano hasta que el audio programado y el comportamiento en segundo plano se validen en iOS.

## Aún planificado

- Validación del comportamiento en segundo plano en iOS.
- Soporte completo de reproducción y espectrograma en Session Review para grabaciones ARU segmentadas.
