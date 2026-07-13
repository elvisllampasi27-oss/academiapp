# Requirements — Pagos con Culqi (T1.2)

Extraído del comportamiento real de: `procesarPagoCulqi` (index.js), `culqi_checkout_page.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S1, S5, D1, D2, U5).

⚠️ **Nota abierta (pendiente de confirmar con el equipo):** la constante `DIAS_PREMIUM = 90` otorga 90 días de premium, pero el texto enviado a Culqi como descripción del cargo dice "Suscripcion Premium AcademiApp (30 dias)" — el comprobante que ve el usuario no coincide con la duración real otorgada. Este documento asume que **90 días es el comportamiento correcto** (lo que efectivamente hace el código hoy). Si la intención real era 30 días, hay que corregir `DIAS_PREMIUM` y no el texto.

## Historia de usuario

Como usuario, quiero pagar mi plan premium con tarjeta vía Culqi, para obtener acceso premium inmediato.

## Criterios de aceptación (EARS)

- **R1.** CUANDO un usuario autenticado envía un `tokenId` de Culqi válido, EL SISTEMA DEBERÁ cobrar S/29 (2900 céntimos, PEN) contra la API de Culqi usando ese token.
- **R2.** CUANDO Culqi aprueba el cargo, EL SISTEMA DEBERÁ activar `plan = "premium"` con `premium_hasta = ahora + 90 días`, en una sola escritura con merge sobre el documento del usuario.
- **R3.** CUANDO Culqi aprueba el cargo, EL SISTEMA DEBERÁ registrar el cargo (`chargeId`, monto, moneda, fecha de servidor) en la colección de auditoría `pagos_culqi`, independiente del documento del usuario.
- **R4.** CUANDO Culqi rechaza el cargo, EL SISTEMA DEBERÁ devolver al cliente el mensaje de Culqi (`user_message` o `merchant_message`) y NO DEBERÁ modificar el plan del usuario.
- **R5.** CUANDO la llamada a la API de Culqi falla por un problema de red o del servicio (no un rechazo de pago), EL SISTEMA DEBERÁ responder "No se pudo conectar con la pasarela de pago" sin exponer el error interno, y NO DEBERÁ modificar el plan del usuario.
- **R6.** CUANDO el pago se aprueba y activa, EL SISTEMA DEBERÁ notificar al usuario por push ("¡Ya eres Premium!") como confirmación.
- **R7.** CUANDO falta el `tokenId` o no es un string, EL SISTEMA DEBERÁ rechazar la solicitud con `invalid-argument` antes de llamar a Culqi.
- **R8.** CUANDO el usuario no está autenticado, EL SISTEMA DEBERÁ rechazar con `unauthenticated` antes de intentar cualquier cargo.

## Trazabilidad con la constitución

- R2, R3 cumplen **D1** (`serverTimestamp`) y **D2**.
- R3 cumple **S5** (colección declarada, no libre).
- R6 cumple **U5** (notificación vía `enviarNotificacionAUsuario`, no token fijo).
- R8 cumple **S1**.
