# Requirements — Contenido / Explorar + calendario de temas (T1.7)

Extraído del comportamiento real de: `construirCalendarioGlobal`, `diaLectivoActual`, `fechaLimaYMD`, `obtenerEstadoCalendarioTema` (index.js), `explorar.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S2).

## Historia de usuario

Como usuario premium, quiero que mis temas se desbloqueen según un calendario compartido (no arbitrario), para avanzar de forma ordenada y con acceso a repaso de lo ya visto.

## Criterios de aceptación (EARS)

- **R1.** EL CALENDARIO de temas es GLOBAL (mismo para todos los usuarios, construido a partir del orden de cursos y temas en Firestore), no individual — lo único individual por usuario es SU fecha de inicio (`rutaIniciadaEn`) y por lo tanto qué día lectivo le toca hoy.
- **R2.** EL CALENDARIO reparte 3 cursos por día, distribuyendo los temas en "rondas": todos los cursos avanzan un tema por ronda antes de pasar a la siguiente.
- **R3.** EL DÍA LECTIVO se cuenta en huso horario de Lima y EXCLUYE los domingos (no cuentan como día lectivo, aunque sí transcurren en el calendario real).
- **R4.** CUANDO un usuario no tiene `rutaIniciadaEn` todavía, EL SISTEMA DEBERÁ reportar el motivo "sin-ruta" en vez de calcular un día lectivo inválido.
- **R5.** CUANDO un usuario no es premium, EL SISTEMA DEBERÁ reportar "no-premium" sin llegar a construir el calendario (evita trabajo innecesario para quien de todas formas no tiene acceso).
- **R6.** CUANDO un tema no tiene día asignado en el calendario (curso/tema fuera de la rotación, ej. contenido nuevo aún no programado), EL SISTEMA DEBERÁ reportar "sin-programar".
- **R7.** CUANDO el día lectivo actual del usuario coincide con el día asignado del tema, EL SISTEMA DEBERÁ marcarlo `habilitadoHoy=true` (acceso a quiz); en cualquier otro día (pasado o futuro), el video queda visible solo para repaso, sin quiz.
- **R8.** El catálogo de cursos y temas (metadata pública: título, video) es legible por cualquier usuario autenticado, sea o no premium (regla ya definida en `firestore.rules`, no se repite lógica aquí).

## Trazabilidad con la constitución

- R5 refuerza **S2** (mismo patrón de gate por dato de servidor visto en T1.4/T1.5).
- R1-R3 documentan una regla de negocio no trivial (huso horario + exclusión de domingos) que sin este documento vive solo en el código y es fácil de romper sin darse cuenta al modificarlo.
