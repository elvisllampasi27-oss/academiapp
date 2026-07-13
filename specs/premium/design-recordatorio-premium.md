# Design — Recordatorio de vencimiento de premium

Diseño técnico (Fase 2 de SDD) para el requisito **R6** de `specs/premium/requirements.md` (T1.4). Este documento responde al "cómo" técnico; el "qué/por qué" ya quedó fijado en ese requirements.md — si algo aquí contradice ese archivo, gana el requirements.md y se corrige este documento.

## Resumen

Un job diario nuevo revisa qué usuarios premium están a 3 días de que les venza el plan y les envía un recordatorio push, sin duplicar el envío ni interferir con el job de expiración que ya existe.

## Decisiones técnicas

1. **Nueva Cloud Function programada**: `notificarPremiumPorVencer`, agregada junto a `expirarPremiumVencidos` en el mismo bloque de `index.js` — no la reemplaza, corre en paralelo, en su propio `onSchedule`.
2. **Horario**: `every day 08:30`, `timeZone: "America/Lima"` — 30 minutos después de `notificarContenidoDiario` (07:00), para no competir por cuota de envío de FCM en el mismo minuto exacto.
3. **Campo nuevo en `users/{uid}`**: `recordatorio_3d_enviado_en: Timestamp | null`.
4. **Reset del campo al renovar** (cumple R6.3): se agrega `recordatorio_3d_enviado_en: null` al mismo objeto que ya escriben `procesarPagoCulqi` (T1.2, línea del `set` con `plan: "premium"`) y `aprobarPagoManual` (T1.3) al activar premium. No es una función aparte — es un campo más en una escritura que ya existe.
5. **Query de candidatos**: `users.where("plan","==","premium").where("premium_hasta","<=", ahora+3días).where("premium_hasta",">", ahora)`. El filtro `recordatorio_3d_enviado_en == null` se intenta en la misma query; si Firestore exige un índice compuesto que todavía no existe, se resuelve en Fase 4 (el propio `firebase deploy`/log de la función da el enlace para crearlo, o se filtra en memoria como respaldo mientras tanto).
6. **Envío**: reutiliza `enviarNotificacionAUsuario` sin modificarla — ya cumple U2 (multi-dispositivo), U3 (limpieza de tokens inválidos) y U5 (multicast) automáticamente.
7. **Manejo de errores**: try/catch por usuario dentro del loop, mismo patrón que ya usa `expirarPremiumVencidos` — un fallo individual no debe cortar el resto del batch.
8. **R6.6 (aviso de vencimiento, no de recordatorio)**: se agrega una llamada a `enviarNotificacionAUsuario` DENTRO de `expirarPremiumVencidos` (función ya existente), en el mismo `batch.forEach`, con mensaje distinto ("tu premium venció"). Es una modificación a código existente, no una función nueva — se documenta aquí porque nace del mismo requisito R6.

## Flujo (diagrama de la conversación)

```
Job diario 08:30 (Lima)
        ↓
Filtrar candidatos (premium, vence en 3 días, sin aviso previo)
        ↓
Enviar recordatorio (push a fcmTokens del usuario)
        ↓
Marcar enviado (recordatorio_3d_enviado_en)
```

En paralelo, sin relación de dependencia con lo anterior:

```
Culqi/Yape aprueba pago (T1.2/T1.3, ya existente)
        ↓
Resetea recordatorio_3d_enviado_en = null
```

## Archivos que se van a tocar en la Fase 4 (Implement)

| Archivo | Tipo de cambio |
|---|---|
| `functions/index.js` | Agrega `notificarPremiumPorVencer` (función nueva); modifica `expirarPremiumVencidos` (agrega notificación de vencido); modifica `procesarPagoCulqi` y `aprobarPagoManual` (agrega reset del campo) |
| `firestore.indexes.json` | Posible índice compuesto nuevo para la query de candidatos (se confirma en Fase 4) |

No se toca ningún archivo de Flutter — esta feature es 100% backend/notificaciones, no tiene UI nueva.

## Trazabilidad

Este diseño implementa R6.1 a R6.6 de `specs/premium/requirements.md`, cumpliendo D3/D5/D6 (idempotencia, logging, tolerancia a fallos externos) y U2/U3/U5 (mensajería) de `specs/constitution.md`.
