# Requirements — Pagos manuales por Yape + revisión admin (T1.3)

Extraído del comportamiento real de: `aprobarPagoManual`, `rechazarPagoManual`, `revertirPagoManual`, `notificarAdminNuevoPago` (index.js), `yape_payment_page.dart`, `admin_pagos_pendientes_page.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S2, S3, S4, D3, D5).

## Historia de usuario

Como usuario sin tarjeta, quiero subir mi comprobante de Yape para que un admin lo revise y me active el premium.

## Criterios de aceptación (EARS)

- **R1.** CUANDO un usuario sube un comprobante de Yape, EL SISTEMA DEBERÁ crear el pago en estado "pendiente" (el cliente no puede crearlo en otro estado).
- **R2.** CUANDO se crea un pago pendiente, EL SISTEMA DEBERÁ notificar a todos los administradores con el monto a revisar.
- **R3.** CUANDO un admin aprueba un pago pendiente, EL SISTEMA DEBERÁ activar `plan="premium"` con `premium_hasta = ahora + 90 días`, registrar la aprobación (uid+timestamp) en el pago, dejar constancia en el CSV de historial, y notificar al usuario.
- **R4.** CUANDO un admin rechaza un pago pendiente, EL SISTEMA DEBERÁ marcar el pago como "rechazado" con motivo y quién lo resolvió, SIN modificar el plan del usuario.
- **R5.** CUANDO un admin revierte un pago ya aprobado, EL SISTEMA DEBERÁ devolver al usuario a `plan="free"` (sin tocar su progreso de estudio) y regresar el pago a estado "pendiente" para re-decidir.
- **R6.** CUANDO un admin revierte un pago ya rechazado, EL SISTEMA DEBERÁ regresar el pago a "pendiente" SIN tocar el plan del usuario (nunca estuvo premium por ese pago).
- **R7.** CUANDO se intenta revertir un pago que todavía está "pendiente", EL SISTEMA DEBERÁ rechazar la operación (no hay nada que revertir).
- **R8.** CUANDO se aprueba, rechaza o revierte un pago, EL SISTEMA DEBERÁ conservar el documento del pago y el comprobante en Storage (nunca borrarlos), para mantener historial auditable.
- **R9.** CUALQUIERA de las acciones aprobar/rechazar/revertir SOLO puede ejecutarla un admin válido vía custom claim (`request.auth.token.admin`); de lo contrario EL SISTEMA DEBERÁ rechazar con `permission-denied`.
- **R10.** EL LISTADO de administradores a notificar (R2) usa el campo espejo `users.esAdmin`, no el custom claim directamente (Firestore no permite `where` sobre custom claims). Este campo espejo SOLO se escribe junto con el custom claim, desde `scripts/hacer_admin.js` (otorgar) o `scripts/revocar_admin.js` (revocar) — ver excepción documentada en constitution.md S3.

## Trazabilidad con la constitución

- R1 cumple **S2**.
- R3/R4/R5/R6 cumplen **D3** (idempotencia por verificación de estado) y **S4** (registro de quién resolvió).
- R8 refuerza **D5** (auditoría, no se pierde evidencia).
- R9 cumple **S3**.
- R10 documenta la excepción de S3 y cierra el hallazgo detectado durante esta fase (antes parecía una inconsistencia; es un espejo intencional, ahora con su script de revocación simétrico `revocar_admin.js`).
