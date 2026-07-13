# Constitución del proyecto — AcademiApp

Este documento reúne las reglas transversales que **todo módulo nuevo o modificado** debe respetar, sin importar qué tan chico sea el cambio. Se escribió una sola vez (Fase 0 de SDD) a partir de los patrones ya presentes en el código real del proyecto (`index.js`, `firestore.rules`, `storage.rules`, `notificaciones_service.dart`).

No reemplaza ni modifica el código existente — es la referencia contra la que se valida todo lo nuevo que se construya de aquí en adelante.

---

## 0. Inventario de módulos (T0.1)

| Módulo | Estado |
|---|---|
| Autenticación / perfil | Construido |
| Pagos Culqi | Construido |
| Pagos Yape + revisión admin | Construido |
| Premium (activación/expiración) | Construido |
| Chatbot IA (tutor) | Construido |
| Exámenes / Quizzes | Construido |
| Contenido / Explorar | Construido |
| Rendimiento y progreso | Construido |
| Notificaciones push | Construido |
| Panel de administración | Construido |
| Seguridad (Firestore/Storage rules) | Construido |
| Módulo(s) "próximamente" (bloques futuros) | Placeholder, sin definir |

---

## 1. Seguridad (T0.2)

- **S1.** Toda función callable DEBE validar `request.auth` antes de leer/escribir, y responder con `HttpsError("unauthenticated")` si falta.
- **S2.** Ningún campo de estado sensible (`plan`, aprobaciones, resultados, puntajes) se escribe directo desde el cliente: siempre a través de una Cloud Function con Admin SDK.
- **S3.** El rol admin se valida SIEMPRE vía `request.auth.token.admin == true` (custom claim), nunca vía un campo dentro del documento del usuario, PARA AUTORIZAR una acción (aprobar, rechazar, revertir, escribir contenido, etc.).
  - **Excepción documentada:** el campo `users/{uid}.esAdmin` es un espejo de solo-lectura del custom claim, usado únicamente para *listar* administradores en consultas `where` (Firestore no permite consultar custom claims). Nunca se usa para autorizar una acción, solo para saber a quién notificar.
  - Este campo espejo SOLO puede escribirse en el mismo lugar y momento en que se otorga o revoca el custom claim (`scripts/hacer_admin.js` y su contraparte `scripts/revocar_admin.js`), nunca de forma manual o independiente.
- **S4.** Toda acción de aprobación/rechazo/reversión hecha por un admin queda registrada con `uid` + timestamp de quién la ejecutó.
- **S5.** Toda colección de Firestore nueva debe declararse explícitamente en `firestore.rules`; lo no declarado queda denegado por defecto.
- **S6.** Toda subida a Storage valida tipo de contenido y tamaño máximo, además de autenticación.

## 2. Datos y auditoría (T0.3)

- **D1.** Toda fecha/hora de eventos del servidor se guarda con `FieldValue.serverTimestamp()`, nunca con una fecha enviada por el cliente.
- **D2.** Antes de leer o modificar un documento por su id, se verifica su existencia (`.exists`) y se responde `HttpsError("not-found")` si falta.
- **D3.** Toda transición de estado (aprobar, rechazar, expirar, notificar) verifica el estado actual antes de actuar, para que la operación sea idempotente y no se repita si se ejecuta dos veces.
- **D4.** Escrituras masivas sobre múltiples documentos usan `batch` (o transacción), no `updates` sueltos en loop.
- **D5.** Todo evento relevante se registra con `logger`: `info` (resultado normal), `warn` (fallo externo recuperable), `error` (fallo que interrumpe el flujo). Nunca un `catch` vacío.
- **D6.** Si depende de un servicio externo (Culqi, YouTube, Gemini) que puede fallar, el fallo se registra y el resto del flujo continúa cuando sea posible, en vez de abortar toda la función.

## 3. UX y notificaciones (T0.4)

- **U1.** Si el usuario niega el permiso de notificaciones, no se le vuelve a pedir insistentemente en la misma sesión.
- **U2.** Los tokens push se guardan como arreglo (`fcmTokens`), soportando múltiples dispositivos por usuario.
- **U3.** Al enviar una notificación, los tokens que Firebase reporte como inválidos se remueven automáticamente del arreglo del usuario.
- **U4.** Al cerrar sesión, el token del dispositivo actual se remueve del arreglo del usuario.
- **U5.** Toda notificación enviada usa `sendEachForMulticast` a `fcmTokens`, nunca un solo token fijo.
- **U6.** La paleta visual de cualquier UI nueva respeta el tema oscuro existente (fondo ~`#0A0A0A`/`#1A1A1A`, acento ámbar `#FFB800`), salvo que se decida explícitamente lo contrario.

---

## Cómo se usa este documento

Cada vez que se escriba un `requirements.md` nuevo (Fase 1, por módulo), sus criterios de aceptación deben ser consistentes con las reglas de arriba. Si un requisito nuevo choca con una regla de esta constitución, se discute y se actualiza este archivo primero — no se ignora en silencio.
