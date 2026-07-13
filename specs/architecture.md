# Arquitectura general — AcademiApp

Documento de referencia a nivel de sistema completo (no de un módulo). Complementa `specs/constitution.md` con la vista de "qué habla con qué".

## Componentes

| Componente                     | Tecnología                            | Responsabilidad                                                                                                                                                    |
| ------------------------------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| App móvil                      | Flutter (Dart)                        | UI, navegación, llama a Cloud Functions vía `cloud_functions`, lee Firestore directo para datos propios del usuario (progresoQuiz, examenesResueltos, rendimiento) |
| Panel admin                    | HTML/JS estático (`admin_panel.html`) | Gestión de cursos/temas/exámenes/quizzes/pagos, corre en el navegador, usa el SDK de Firebase directo                                                              |
| Cloud Functions                | Node.js 22, `firebase-functions` v6   | Toda la lógica de negocio sensible: pagos, gates de premium, calificación de exámenes/quiz, notificaciones, generación con IA                                      |
| Firestore                      | Base de datos NoSQL                   | Estado de usuarios, cursos/temas, pagos, progreso, exámenes                                                                                                        |
| Storage                        | Almacenamiento de archivos            | Comprobantes de Yape, materiales (PDF), imágenes de exámenes                                                                                                       |
| Culqi                          | API externa de pagos                  | Procesa cargos con tarjeta                                                                                                                                         |
| Gemini                         | API externa de IA (Google)            | Tutor IA (chat), generación de quizzes, cache de contexto                                                                                                          |
| YouTube                        | API pública                           | Transcripciones automáticas de los videos de cada tema                                                                                                             |
| FCM (Firebase Cloud Messaging) | Notificaciones push                   | Recordatorios, avisos de pago, contenido diario                                                                                                                    |

## Regla de oro (ya estaba implícita, ahora explícita)

**El cliente (Flutter o el panel admin) nunca habla directo con Culqi, Gemini o YouTube.** Todo pasa por Cloud Functions. Esto es lo que hace posible que las reglas de seguridad (S1-S6 de la constitución) se puedan hacer cumplir — si el cliente hablara directo con Culqi, no habría forma de validar el monto o el usuario antes de cobrar.

## Flujo típico (ejemplo: pagar con Culqi)

1. App Flutter obtiene un `tokenId` de la SDK de Culqi (vía WebView, `culqi_checkout_page.dart`).
2. App Flutter llama a `procesarPagoCulqi` (Cloud Function) con ese token.
3. Cloud Function llama a la API de Culqi con el `CULQI_SECRET_KEY` (nunca expuesto al cliente).
4. Si Culqi aprueba, Cloud Function escribe en Firestore (`users`, `pagos_culqi`) y envía notificación push vía FCM.
5. App Flutter recibe la respuesta de la Cloud Function y actualiza la UI.

## Dónde está cada pieza en el repo

```
app_movil/
├── lib/                  → App Flutter (cliente)
│   └── admin_panel.html  → Panel admin (vive aquí por conveniencia, pero
│                            se sirve/abre independiente de la app móvil)
├── functions/
│   ├── index.js          → TODAS las Cloud Functions
│   └── scripts/          → Scripts de administración (hacer_admin.js, etc.)
├── firestore.rules       → Reglas de acceso a Firestore
├── storage.rules         → Reglas de acceso a Storage
└── specs/                → Toda la documentación SDD de este proyecto
```

## Ver también

- `specs/constitution.md` — reglas transversales de seguridad/datos/UX.
- `specs/reglas-seguridad/requirements.md` — tabla detallada de permisos por colección.
- `specs/*/requirements.md` — comportamiento específico de cada módulo.
