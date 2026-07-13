# Modelo de datos — Firestore (AcademiApp)

Documento de referencia a nivel de sistema completo, consolidando los campos de cada colección repartidos en los 11 `requirements.md`. Complementa `specs/architecture.md` (el "qué habla con qué") con el "qué se guarda dónde".

Convención: 🔒 = solo lo escribe una Cloud Function (Admin SDK), nunca el cliente. 🔓 = el cliente puede escribirlo directo (con reglas de Firestore de por medio).

## `users/{uid}`

| Campo | Tipo | Quién lo escribe | Notas |
|---|---|---|---|
| `uid` | string | 🔓 cliente, al crear cuenta | debe coincidir con el uid de Auth |
| `nombre`, `correo`, `carrera`, `fechaNacimiento` | string | 🔓 cliente, al crear cuenta | |
| `plan` | `"free"` \| `"premium"` | 🔓 create (solo `"free"`) / 🔒 resto | ver `specs/premium/requirements.md` |
| `premium_hasta` | Timestamp \| null | 🔒 | activado por Culqi/Yape, limpiado al expirar |
| `rutaIniciadaEn` | Timestamp | 🔒 | fecha de inicio del calendario personal del alumno |
| `ultimoExamenCompletado` | `{examenId, fecha}` | 🔒 | límite de 1 examen gratis/día para no-premium |
| `ultimo_bloque_examen_abierto` | — | 🔓 create únicamente | campo legado del repair de altas viejas |
| `fcmTokens` | string[] | 🔓 (arrayUnion/arrayRemove) | multi-dispositivo, ver `specs/notificaciones/requirements.md` |
| `esAdmin` | boolean | 🔒 solo vía `scripts/hacer_admin.js`/`revocar_admin.js` | espejo de solo-lectura del custom claim (ver constitution S3) |
| `recordatorio_3d_enviado_en` | Timestamp \| null | 🔒 | nuevo, ver `specs/premium/requirements.md` R6 |

### `users/{uid}/progresoQuiz/{cursoId_temaId}`
| Campo | Tipo | Notas |
|---|---|---|
| `cursoId`, `temaId`, `nombreCurso`, `tituloTema` | string | |
| `basico`, `intermedio`, `avanzado` | `{intentos, mejorPuntaje, aprobado, ultimaActualizacion}` | uno por nivel, acumulativo |

### `users/{uid}/examenesResueltos/{examenId}`
| Campo | Tipo | Notas |
|---|---|---|
| `titulo`, `categoria` | string | copiados del examen al momento de resolverlo |
| `aciertos`, `total` | number | calificado en servidor |
| `fecha` | Timestamp | |

## `pagos/{pagoId}` (Yape)

| Campo | Tipo | Notas |
|---|---|---|
| `uid` | string | dueño del pago |
| `monto` | number | |
| `estado` | `"pendiente"` \| `"aprobado"` \| `"rechazado"` | ver `specs/pagos-yape/requirements.md` |
| `resueltoPor`, `resueltoEn` | string, Timestamp | 🔒 quién aprobó/rechazó y cuándo |
| `motivo` | string | solo si `estado="rechazado"` |
| `revertidoPor`, `revertidoEn` | string, Timestamp | 🔒 si un admin revirtió la decisión |

*(el comprobante de pago en sí vive en Storage, no en este documento — ver `storage.rules`, ruta `comprobantes/{uid}/**`)*

## `pagos_culqi/{autoId}` — auditoría, solo lectura de admin/backend

| Campo | Tipo | Notas |
|---|---|---|
| `uid`, `chargeId`, `amount`, `currency`, `fecha` | — | un registro por cargo aprobado, nunca se edita |

## `cursos/{cursoId}`

| Campo | Tipo | Notas |
|---|---|---|
| `nombre`, `icono`, `orden` | string, string, number | catálogo público, solo admin escribe |

### `cursos/{cursoId}/temas/{temaId}`
| Campo | Tipo | Notas |
|---|---|---|
| `titulo`, `orden` | string, number | |
| `videoId` | string | id de YouTube |
| `pdfUrl` / `materiales[]` | string / array | material de apoyo |

### `cursos/{cursoId}/temas/{temaId}/premium/contenido` — gatillado por premium o admin
| Campo | Tipo | Notas |
|---|---|---|
| `transcripcion`, `transcripcionIntentadaEn` | string, Timestamp | cache del transcript de YouTube |
| `materialTexto`, `materialIntentadoEn` | string, Timestamp | texto extraído del PDF |
| `geminiCacheName`, `geminiCacheExpira`, `geminiCacheIntentadoEn` | string, string, Timestamp | cache de contexto en Gemini (TTL 24h) |
| `quiz_basico` / `quiz_intermedio` / `quiz_avanzado` | array de preguntas | aprobado, visible a alumnos |
| `quiz_basico_borrador` / etc. | array de preguntas | generado por IA, pendiente de aprobación del admin |

## `examenes/{examenId}` — privado, `allow read: if false`

| Campo | Tipo | Notas |
|---|---|---|
| `titulo`, `categoria`, `anio`, `duracionMinutos` | — | `categoria` incluye `"admision"` (trato especial, ver R4/R5 de examenes-quizzes) |
| `preguntas[]` | `{pregunta, opciones[], respuestaCorrecta, explicacion, imagenSvg?}` | solo accesible vía `obtenerExamen` (Cloud Function) |

## `examenesIndice/{examenId}` — público, metadata sin respuestas

| Campo | Tipo | Notas |
|---|---|---|
| `titulo`, `categoria`, `anio`, `orden`, `duracionMinutos`, `totalPreguntas` | — | nunca incluye `preguntas` ni `respuestaCorrecta` (por diseño, ver T1.10) |

## Ver también

- `specs/architecture.md` — vista de componentes y flujos.
- `specs/reglas-seguridad/requirements.md` — quién puede leer/escribir cada colección (permisos, no estructura).
- `firestore.rules` — la fuente de verdad ejecutable; este documento es descriptivo, no reemplaza las reglas.
