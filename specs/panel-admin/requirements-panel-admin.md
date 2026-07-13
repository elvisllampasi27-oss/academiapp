# Requirements — Panel de administración (T1.10)

Extraído del comportamiento real de: `admin_panel.html`, `admin_pagos_pendientes_page.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S3, S5, D4).

## Historia de usuario

Como admin, quiero gestionar cursos/temas, subir y curar exámenes, revisar quizzes generados por IA, y aprobar/rechazar pagos manuales, todo desde un panel web.

## Criterios de aceptación (EARS)

- **R1.** El panel es una página web estática (`admin_panel.html`) que usa el SDK de Firebase directo desde el navegador, protegida por las mismas `firestore.rules` (custom claim admin) — no por una contraseña propia del panel.
- **R2.** CUANDO se sube un examen nuevo, EL SISTEMA DEBERÁ escribir en DOS colecciones en un solo batch: `examenes` (privada, con preguntas y `respuestaCorrecta` — solo accesible vía Cloud Function, regla "allow read: if false") y `examenesIndice` (pública, solo metadata sin preguntas ni respuestas) — nunca deben quedar desincronizadas.
- **R3.** CUANDO se elimina un examen, EL SISTEMA DEBERÁ eliminar su documento en ambas colecciones (`examenes` + `examenesIndice`) **en un solo batch**, igual que la creación (R2). *(Corregido — antes eran dos `deleteDoc` secuenciales.)*
- **R4.** CUANDO un admin genera un quiz con IA desde el panel (`generarQuizAdmin`), EL SISTEMA DEBERÁ guardarlo en un campo `_borrador` dentro de `cursos/{cursoId}/temas/{temaId}/premium` — invisible para alumnos hasta que el mismo admin lo apruebe/edite.
- **R5.** La aprobación/edición del borrador de quiz se hace por escritura DIRECTA a Firestore desde el panel (no una Cloud Function dedicada), amparada en que `firestore.rules` ya da permiso de escritura ahí a `request.auth.token.admin==true`.
- **R6.** El panel reutiliza las mismas Cloud Functions ya especificadas en T1.3 (`aprobarPagoManual`, `rechazarPagoManual`, `revertirPagoManual`) para la revisión de pagos — no duplica esa lógica.
- **R7.** El dashboard del panel puede listar/contar toda la colección `users` (`allow list` para admins, ya definido en `firestore.rules`), para métricas generales.

## Hallazgo menor — corregido

En R3, la eliminación de examen hacía dos `deleteDoc` **secuenciales**, no un batch — si el segundo fallaba (ej. corte de red entre ambas), podía quedar un examen huérfano en una sola colección. Se corrigió: ahora ambos `deleteDoc` van dentro de un `writeBatch`, igual que R2 (creación). Archivo modificado: `lib/admin_panel.html`, función `eliminarExamen`.

## Trazabilidad con la constitución

- R2 cumple **D4** (batch).
- R3 debería cumplir D4 y no lo hace del todo (hallazgo menor arriba).
- R4 cumple **S2**.
- R5 documenta la excepción ya conocida de **S3** (igual que T1.3/R10 — escritura directa amparada en custom claim, no en Cloud Function).
