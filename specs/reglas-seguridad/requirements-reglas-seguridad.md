# Requirements — Reglas de seguridad (Firestore/Storage) (T1.11)

Consolidación de `firestore.rules` y `storage.rules`, cruzando lo ya especificado en T1.1-T1.10. Este módulo no describe una feature: describe quién puede hacer qué sobre cada colección/ruta, como referencia rápida.

Debe ser consistente con `specs/constitution.md` (en particular S1-S6).

## Tabla Firestore

| Colección | Cliente lee | Cliente escribe |
|---|---|---|
| `users/{uid}` | solo el dueño | `create` limitado (plan=free); `update` solo `fcmTokens` o repair de una sola vez (T1.1/T1.4) |
| `users/{uid}/progresoQuiz` | solo el dueño | NUNCA (solo Cloud Function, T1.6) |
| `users/{uid}/examenesResueltos` | solo el dueño | NUNCA (solo Cloud Function, T1.6) |
| `pagos/{id}` | dueño o admin | `create` (propio, `estado=pendiente`); resto solo Cloud Function (T1.3) |
| `cursos/{id}` | cualquier autenticado | NUNCA (solo admin, T1.10) |
| `cursos/{id}/temas/{id}` | cualquier autenticado | NUNCA (solo admin, T1.10) |
| `.../temas/{id}/premium/contenido` | admin o premium | solo admin (T1.5/T1.6/T1.10) |
| `examenesIndice/{id}` | cualquier autenticado | NUNCA (solo admin, T1.10) |
| `examenes/{id}` | NADIE (`false`) — solo vía `obtenerExamen` (Cloud Function, T1.6) | NUNCA (solo admin, T1.10) |
| (cualquier otra colección) | NADIE | NADIE (deny by default, S5) |

## Tabla Storage

| Ruta | Cliente lee | Cliente escribe |
|---|---|---|
| `comprobantes/{uid}/**` | solo el dueño | dueño, imagen, <10MB (T1.3) |
| `materiales/{cursoId}/**` | cualquiera (público) | solo admin |
| `examenes_imagenes/**` | cualquiera (público) | solo admin, jpg/png/svg, <5MB |

## Criterios de aceptación (EARS)

- **R1.** Toda colección con datos de un usuario específico limita lectura a `request.auth.uid == el dueño del documento`, salvo excepción explícita para admin (pagos, `users` con `allow list`).
- **R2.** Ninguna colección de "verdad de negocio" (plan, resultados, aprobaciones) permite escritura de cliente en su estado final — solo en su estado inicial seguro (`create`) o nunca.
- **R3.** Toda colección nueva que se agregue a futuro DEBE declararse explícitamente aquí; lo no declarado queda denegado, sin excepción.
- **R4.** Storage valida siempre tipo de contenido Y tamaño máximo, nunca solo autenticación.

## Trazabilidad con la constitución

Este módulo es la materialización ejecutable de las reglas S1-S6 de la constitución — cualquier `firestore.rules`/`storage.rules` nuevo debe poder mapearse a una fila de esta tabla antes de mezclarse a `main`.
