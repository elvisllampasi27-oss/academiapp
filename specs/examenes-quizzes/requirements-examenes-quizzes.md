# Requirements — Exámenes y Quizzes (T1.6)

Extraído del comportamiento real de: `obtenerExamen`, `enviarResultadoExamen`, `obtenerQuizTema`, `enviarResultadoQuiz`, `generarQuizAdmin` (index.js), `examen_sesion_page.dart`, `quiz_video_page.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S1, S2, D3).

## Historias de usuario

1. Como usuario, quiero rendir exámenes (modo práctica o modo admisión) y ver mi resultado.
2. Como usuario premium, quiero rendir quizzes por nivel de un tema, dentro del calendario que me toca.
3. Como admin, quiero generar quizzes con IA y revisarlos antes de publicarlos.

## Criterios de aceptación (EARS)

### Exámenes

- **R1.** CUANDO un examen es tipo "admisión" y el usuario no es premium, EL SISTEMA DEBERÁ rechazar el acceso (`permission-denied`).
- **R2.** CUANDO un usuario no premium ya completó un examen no-admisión hoy (hora de Lima), EL SISTEMA DEBERÁ rechazar un segundo intento el mismo día (`resource-exhausted`), salvo que el examen sea tipo admisión — ese límite no aplica ahí porque ya está bloqueado por R1.
- **R3.** CUANDO se envían respuestas de un examen, EL SISTEMA DEBERÁ calificarlas en el servidor comparando contra `respuestaCorrecta` almacenado, nunca confiar en un puntaje enviado por el cliente.
- **R4.** CUANDO el examen es categoría "admisión", EL SISTEMA DEBERÁ **omitir** `respuestaCorrecta` y `explicacion` de cada pregunta al devolver el examen al cliente (antes de que responda), para simular un examen real sin fugas de respuesta. *(Corregido en esta fase — antes se exponían siempre, contradiciendo el comentario de diseño en `examen_sesion_page.dart` que dice "no revela nada hasta el final".)*
- **R5.** CUANDO el examen es categoría distinta de "admisión" (modo práctica), EL SISTEMA SÍ DEBERÁ incluir `respuestaCorrecta`/`explicacion`, porque el modo práctica revela la respuesta apenas el alumno elige — es una funcionalidad intencional, no un descuido.

### Quizzes por tema

- **R6.** CUANDO un usuario no premium intenta acceder a un quiz por nivel, EL SISTEMA DEBERÁ rechazar (`permission-denied`).
- **R7.** CUANDO el quiz de un tema no corresponde al día lectivo asignado en el calendario del usuario, EL SISTEMA DEBERÁ rechazarlo (`failed-precondition`) — el video queda solo para repaso, no para quiz.
- **R8.** EL QUIZ por nivel SIEMPRE revela `respuestaCorrecta`/`explicacion` al cliente (no hay modo "oculto" para quiz, a diferencia de examen admisión) — comportamiento intencional para el feedback inmediato por pregunta.
- **R9.** CUANDO se envía el resultado de un quiz, EL SISTEMA DEBERÁ calificarlo en el servidor a partir de las respuestas reales enviadas (`respuestas: [...]`), releyendo las preguntas guardadas — NUNCA aceptar un `aciertos`/`total` precalculado por el cliente. *(Corregido en esta fase — antes se podía marcar "aprobado" cualquier nivel sin responder nada, llamando la función directo.)*
- **R10.** El progreso por nivel (`intentos`, `mejorPuntaje`, `aprobado`) es acumulativo: el mejor puntaje histórico se conserva aunque un intento posterior sea peor, y una vez aprobado queda aprobado (no se puede "desaprobar" con un mal intento después).

### Generación de quiz (admin)

- **R11.** CUANDO un admin genera un quiz con IA, EL SISTEMA DEBERÁ guardarlo en un campo `_borrador`, nunca visible directamente para alumnos hasta que el admin lo apruebe/edite desde el panel.
- **R12.** Solo un admin válido (custom claim) puede disparar la generación; requiere que el tema ya tenga transcripción o material — si no hay contenido, EL SISTEMA DEBERÁ rechazar con un mensaje que indique qué falta.

## Trazabilidad con la constitución

- R1, R6 refuerzan **S2** (gate por dato de servidor).
- R3, R9 cumplen **S2** y **D3** explícitamente — son las correcciones de esta fase.
- R11 cumple **S2** (contenido sensible no visible hasta aprobación explícita de un admin).
- R12 cumple **S1/S3**.

## Cambios de código de esta fase (no solo documentación)

A diferencia de los módulos T1.1-T1.5, este módulo sí generó cambios reales de código, entregados junto con este archivo:

1. `functions/index.js` — nueva función `ocultarRespuestasSiAdmision()`, aplicada en `obtenerExamen` (R4); `enviarResultadoQuiz` reescrita para calificar en servidor (R9).
2. `lib/quiz_video_page.dart` — ahora guarda y envía las respuestas reales (`_respuestas`) en vez de solo un contador de aciertos.

**Pendiente de tu parte:** reemplazar estos dos archivos en tu proyecto y volver a desplegar `functions` (`firebase deploy --only functions`). No se tocó nada de `examen_sesion_page.dart` ni de `enviarResultadoExamen` — ya calificaban correctamente en servidor.
