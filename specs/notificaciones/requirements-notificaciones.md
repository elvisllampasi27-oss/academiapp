# Requirements — Notificaciones push (T1.9)

Extraído del comportamiento real de: `enviarNotificacionAUsuario`, `notificarContenidoDiario` (index.js), `notificaciones_service.dart`.

Debe ser consistente con `specs/constitution.md` (en particular U1-U5, D5, D6).

## Historia de usuario

Como usuario premium, quiero recibir avisos de contenido nuevo y de refuerzo pendiente cada día, para mantener el ritmo de estudio sin tener que entrar a revisar manualmente.

## Criterios de aceptación (EARS)

- **R1.** EL ENVÍO de cualquier notificación (`enviarNotificacionAUsuario`) es el único punto central usado por todo el sistema — ningún módulo llama a Firebase Messaging directo, todos pasan por esta función.
- **R2.** CUANDO un usuario no tiene tokens FCM registrados, EL SISTEMA DEBERÁ omitir el envío silenciosamente (no es un error, es un estado válido — ej. usuario que rechazó permisos).
- **R3.** CUANDO Firebase Messaging reporta un token como inválido o no registrado, EL SISTEMA DEBERÁ removerlo de `fcmTokens` del usuario en la misma operación de envío.
- **R4.** CUANDO falla el envío completo (error de red, etc.), EL SISTEMA DEBERÁ registrar la falla con `logger.warn` y continuar (nunca debe tumbar la función que la llamó — pagos, quiz, etc. no dependen de que la notificación se entregue).
- **R5.** CADA MAÑANA a las 07:00 (America/Lima), EL SISTEMA DEBERÁ avisar a cada usuario premium con ruta iniciada cuántos temas nuevos le tocan hoy según el calendario global (T1.7), SOLO si tiene al menos 1 tema asignado ese día.
- **R6.** EL MISMO proceso diario DEBERÁ, además, avisar por separado (aviso de refuerzo, no bloqueante) si el usuario no aprobó el nivel básico de alguno de los temas de AYER — sin impedir que avance al contenido de hoy.
- **R7.** CUANDO un usuario no tiene `rutaIniciadaEn`, EL SISTEMA DEBERÁ excluirlo silenciosamente del envío diario (no se le puede calcular ni "hoy" ni "ayer" sin fecha de inicio).
- **R8.** Los títulos de temas de "ayer" se resuelven UNA sola vez por lote (no por usuario), para no repetir lecturas de Firestore idénticas al notificar a muchos usuarios el mismo día.

## Nota de consistencia

El recordatorio de vencimiento de premium (3 días antes) ya quedó especificado como **R6 dentro de `specs/premium/requirements.md` (T1.4)**, no se repite aquí; cuando se implemente, deberá usar el mismo `enviarNotificacionAUsuario` (R1) y el mismo patrón de idempotencia visto en R2-R4.

## Trazabilidad con la constitución

- R1 confirma **U5**.
- R2/R3 confirman **U2/U3**.
- R4 cumple **D5/D6**.
- R5-R8 son reglas de negocio propias de este job, no genéricas de la constitución.
