# Requirements — Chatbot con IA (tutor) (T1.5)

Extraído del comportamiento real de: `procesarPreguntaChatVideo`, `prepararContextoTema`, `asegurarContextoTema`, `crearCacheGemini` (index.js), `chatbot_page.dart`, `chat_service.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S1, S2, D5, D6).

## Historia de usuario

Como usuario premium, quiero chatear con un tutor IA sobre el tema de un video, que conozca el contenido real de ese video/PDF y me guíe a razonar en vez de solo darme la respuesta.

## Criterios de aceptación (EARS)

- **R1.** CUANDO un usuario no premium intenta usar el chat, EL SISTEMA DEBERÁ rechazar con `permission-denied` antes de contactar a Gemini (protege costo de API, no solo UX).
- **R2.** CUANDO se solicita el contexto de un tema por primera vez y tiene video de YouTube, EL SISTEMA DEBERÁ intentar obtener su transcripción, priorizando idioma `es > es-419 > es-ES > en >` cualquier otro disponible.
- **R3.** CUANDO la transcripción o el PDF no están disponibles todavía (ej. video sin subtítulos aún), EL SISTEMA NO DEBERÁ reintentar en cada mensaje: espera al menos 6 horas desde el último intento antes de reintentar.
- **R4.** CUANDO hay contenido suficiente (transcripción y/o PDF) y no existe un cache vigente en Gemini, EL SISTEMA DEBERÁ crear un cache de contexto (TTL 24h) para no reenviar el texto completo en cada mensaje del chat.
- **R5.** CUANDO el contenido del tema es menor a 4000 caracteres, EL SISTEMA NO DEBERÁ intentar crear cache (no vale el overhead) y DEBERÁ usar inyección directa del contexto en cada mensaje.
- **R6.** CUANDO falla la creación del cache de Gemini, EL SISTEMA DEBERÁ caer a inyección directa del contexto sin interrumpir el chat (el usuario nunca ve ese fallo).
- **R7.** CUANDO el estudiante pide resolver un ejercicio paso a paso, EL SISTEMA DEBERÁ guiarlo con preguntas (método socrático) en vez de dar la respuesta final de inmediato, SALVO que el estudiante insista 2+ veces, en cuyo caso EL SISTEMA DEBERÁ darla directo.
- **R8.** CUANDO la pregunta es puramente conceptual/factual, EL SISTEMA DEBERÁ responder directo, sin aplicar el método socrático.
- **R9.** CUANDO Gemini responde con error o timeout, EL SISTEMA DEBERÁ responder "No se pudo conectar con el tutor IA" sin exponer el error interno, y registrar el detalle en logs.
- **R10.** CUANDO falta `cursoId`, `temaId` o `mensaje` en la solicitud, EL SISTEMA DEBERÁ rechazar con `invalid-argument` antes de llamar a Gemini.

## Trazabilidad con la constitución

- R1 refuerza **S2** (gate por dato de servidor, no del cliente) — mismo patrón que T1.4/R4.
- R3 cumple **D6** (servicio externo, reintento sin bloquear).
- R6 cumple **D6** explícitamente (fallback quirúrgico).
- R9 cumple **D5**.
