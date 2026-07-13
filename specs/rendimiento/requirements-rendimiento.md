# Requirements — Rendimiento y progreso (T1.8)

Extraído del comportamiento real de: `rendimiento_page.dart`, `home.dart` (gate de acceso), colecciones `progresoQuiz` y `examenesResueltos`.

Debe ser consistente con `specs/constitution.md`.

## Historia de usuario

Como usuario premium, quiero ver un resumen de mi desempeño (quizzes aprobados por nivel, historial y promedio de exámenes), calculado en tiempo real sobre mis propios datos.

## Criterios de aceptación (EARS)

- **R1.** El acceso a la pantalla de Rendimiento se gatea en el cliente (`home.dart`) por `plan=="premium"`; si no es premium, se muestra un paywall en vez de la pantalla.
- **R2.** EL RESUMEN se calcula en el cliente, en tiempo real (stream), a partir de dos colecciones propias del usuario: `progresoQuiz` y `examenesResueltos` — no requiere ninguna Cloud Function adicional.
- **R3.** "Temas con Básico" y "Temas con Avanzado" cuentan temas donde el nivel correspondiente tiene `aprobado==true` en `progresoQuiz`.
- **R4.** "Promedio de exámenes" se calcula como el promedio de (aciertos/total) por examen rendido, expresado en porcentaje; si no hay exámenes rendidos, se muestra "—" en vez de 0%.
- **R5.** El progreso se agrupa visualmente por curso (`nombreCurso`), y cada tema muestra 3 indicadores (Básico/Intermedio/Avanzado) coloreados según si están aprobados.
- **R6.** CUANDO el usuario no tiene ningún progreso o examen todavía, EL SISTEMA DEBERÁ mostrar un mensaje vacío orientador en vez de una lista en blanco.

## Nota menor (no bloqueante)

El gate de R1 es solo de UI/navegación — `firestore.rules` permite a cualquier usuario autenticado leer su *propia* `progresoQuiz`/`examenesResueltos` sin importar su plan. No es un riesgo real (nunca expone datos de otro usuario, solo los propios sin pagar por verlos presentados), pero queda anotado por transparencia. A diferencia del hallazgo de T1.6, aquí no amerita corrección.

## Trazabilidad con la constitución

- R1 es un patrón de gate ya visto (S2, aunque aquí es solo cosmético).
- El resto son reglas de presentación, sin escritura de datos nueva.
