# Tasks — Recordatorio de vencimiento de premium

Fase 3 de SDD para R6 de `specs/premium/requirements.md`, siguiendo las decisiones de `specs/premium/design.md`. Cada tarea queda trazada a un requisito y a una decisión de diseño, para que la Fase 4 (Implement) no tenga que volver a decidir nada — solo escribir código.

## Tareas

- [ ] **T-A** (→ R6.1, diseño §3) Agregar el campo `recordatorio_3d_enviado_en: null` por defecto conceptualmente (no requiere migración de datos existentes — los usuarios sin el campo se tratan como `null` al leer con `data.recordatorio_3d_enviado_en || null`).

- [ ] **T-B** (→ R6.1, diseño §5) Escribir la query de candidatos en `notificarPremiumPorVencer`: `plan=="premium"`, `premium_hasta` entre ahora y ahora+3 días. Verificar en Firebase Console/logs si pide crear un índice compuesto; si lo pide, crearlo antes de continuar con T-C.

- [ ] **T-C** (→ R6.2, diseño §5) Dentro del loop de candidatos, filtrar (en memoria si no se pudo en la query) los que ya tienen `recordatorio_3d_enviado_en != null` — no enviarles de nuevo.

- [ ] **T-D** (→ R6.4, diseño §6) Por cada candidato restante, llamar `enviarNotificacionAUsuario(uid, {...})` con el mensaje de recordatorio — reutilizar la función existente, no escribir lógica de mensajería nueva.

- [ ] **T-E** (→ R6.1, diseño §6) Envolver el envío + la escritura de `recordatorio_3d_enviado_en` de cada usuario en un `try/catch` individual (diseño §7); en el `catch`, `logger.warn` con `uid` y el error, y continuar el loop (no usar `return`/`throw` que corte a los demás).

- [ ] **T-F** (→ R6.3, diseño §4) En `procesarPagoCulqi` (T1.2) y `aprobarPagoManual` (T1.3): agregar `recordatorio_3d_enviado_en: null` al mismo objeto que ya escriben `plan: "premium"` y `premium_hasta`. Dos ediciones puntuales, no funciones nuevas.

- [ ] **T-G** (→ R6.6, diseño §8) Dentro de `expirarPremiumVencidos`, después de bajar a cada usuario a `plan: "free"` en el batch, agregar una llamada a `enviarNotificacionAUsuario` con el mensaje de "tu premium venció" — fuera del `batch` (los batches de Firestore no envían notificaciones, son solo escritura), en un loop `for` aparte sobre los mismos documentos ya obtenidos en el `snap`.

- [ ] **T-H** (→ R6.5, diseño §5) Definir el schedule de `notificarPremiumPorVencer`: `{ schedule: "every day 08:30", timeZone: "America/Lima" }`.

- [ ] **T-I** (verificación cruzada, no un requisito individual) Revisar que `notificarPremiumPorVencer` y `expirarPremiumVencidos` nunca notifiquen al mismo usuario el mismo día por error de solape en la ventana de 3 días (un usuario que vence hoy no debería recibir "te vence en 3 días" — ya lo evita la condición `premium_hasta > ahora` de T-B, pero se confirma con un test específico en Fase 5).

- [ ] **T-J** Actualizar `firestore.indexes.json` si T-B determinó que hace falta un índice compuesto, y agregarlo al próximo `firebase deploy --only firestore:indexes`.

## Orden sugerido de implementación

T-A → T-B → T-C → T-D → T-E → T-H (la función nueva completa) → T-F (los dos módulos existentes que renuevan) → T-G (el módulo existente que expira) → T-I (verificación) → T-J (si aplica).

## Trazabilidad

Todas las tareas trazan a `specs/premium/requirements.md` (R6.1-R6.6) y a las decisiones numeradas de `specs/premium/design.md`. Ninguna tarea introduce una decisión nueva no cubierta por esos dos documentos — si durante la Fase 4 aparece una decisión no prevista aquí, se vuelve primero a `design.md` a documentarla, no se decide "sobre la marcha" en el código.
