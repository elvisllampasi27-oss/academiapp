# Requirements — Premium (activación, expiración, vigencia) (T1.4)

Extraído del comportamiento real de: `expirarPremiumVencidos`, `procesarPagoCulqi`, `aprobarPagoManual`, `revertirPagoManual` (index.js), y de los gates premium repartidos en `procesarPreguntaChatVideo`, `obtenerEstadoCalendarioTema`, `obtenerQuizTema`, `enviarResultadoQuiz`, `obtenerExamen`.

Debe ser consistente con `specs/constitution.md` (en particular S2, D3, D4, U2, U3, U5).

## Historia de usuario

Como usuario premium, quiero que mi acceso se mantenga activo mientras mi plan no venza, y que se me quite automáticamente cuando venza. Además, quiero recibir un aviso antes de que expire, para poder renovar a tiempo.

## Criterios de aceptación (EARS)

- **R1.** La activación de `plan="premium"` con `premium_hasta = ahora + 90 días` ocurre SOLO por dos caminos: pago aprobado por Culqi (T1.2) o pago manual aprobado por un admin (T1.3). Nunca por escritura directa del cliente.
- **R2.** CUANDO se ejecuta la función programada diaria (03:00 America/Lima) y existen usuarios con `plan="premium"` y `premium_hasta <= ahora`, EL SISTEMA DEBERÁ regresarlos a `plan="free"` con `premium_hasta=null`, en una sola operación batch.
- **R3.** CUANDO no hay ningún usuario vencido ese día, EL SISTEMA DEBERÁ registrar el resultado en logs y terminar sin error (no es una falla, es el caso normal).
- **R4.** Cualquier función que otorgue un beneficio exclusivo premium (tutor IA, quizzes por tema, exámenes tipo admisión, sin límite diario de exámenes) DEBE verificar `userData.plan === "premium"` antes de otorgar el beneficio, nunca confiar en un valor que venga del cliente.
- **R5.** CUANDO un admin revierte un pago aprobado (T1.3, R5), la baja a `plan="free"` ocurre inmediata, fuera del ciclo diario de `expirarPremiumVencidos` (no espera al día siguiente).

### R6 — NUEVO, no implementado aún (backlog de esta fase)

- **R6.1.** CUANDO faltan exactamente 3 días para que `premium_hasta` de un usuario venza (y su plan sigue siendo `"premium"`), EL SISTEMA DEBERÁ enviarle una notificación push de recordatorio de renovación.
- **R6.2.** CUANDO un usuario ya recibió el recordatorio de 3 días para su ciclo premium actual, EL SISTEMA NO DEBERÁ reenviarlo (idempotencia, vía un campo `recordatorio_3d_enviado_en`).
- **R6.3.** CUANDO el usuario renueva su premium (por Culqi o Yape, R1), EL SISTEMA DEBERÁ resetear `recordatorio_3d_enviado_en` a `null`, para que el próximo ciclo pueda volver a notificar.
- **R6.4.** El envío usa el mismo mecanismo que el resto del sistema: `sendEachForMulticast` sobre el arreglo `fcmTokens` del usuario (regla U5), no un solo token.
- **R6.5.** CUANDO falla el envío a un usuario puntual (token inválido, error de red), EL SISTEMA DEBERÁ registrarlo con `logger.warn` y continuar con el resto del batch, sin interrumpirlo (regla D6).
- **R6.6.** CUANDO el usuario ya venció (no le tocaba recordatorio, le tocaba expiración), EL SISTEMA DEBERÁ enviar una notificación distinta de "tu premium venció", como parte de `expirarPremiumVencidos` (R2), no de este recordatorio de 3 días.

## Trazabilidad con la constitución

- R2 cumple **D4**.
- R1, R5 cumplen **S2** y **D3**.
- R6.2, R6.3 cumplen **D3** (idempotencia).
- R6.4 cumple **U2/U5** (multi-dispositivo, multicast).
- R6.5 cumple **D5/D6**.

## Nota de alcance

El detalle de qué bloquea cada función específica (ej. límite de 1 examen gratis/día, examen tipo "admisión" exclusivo premium) pertenece a **T1.6 — Exámenes**, no aquí. Este documento solo especifica la regla general de activación/expiración/gate (R1-R5) y la feature pendiente de construir (R6).
