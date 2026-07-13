# Requirements — Autenticación y perfil (T1.1)

Extraído del comportamiento real de: `login.dart`, `singup.dart`, `complete_profile.dart`, `services/auth.dart`, `services/database.dart`.

Debe ser consistente con `specs/constitution.md` (en particular S2 y U4).

## Historias de usuario

1. Como visitante, quiero registrarme con correo/contraseña o con Google, para crear mi cuenta.
2. Como usuario nuevo, quiero completar mi perfil y elegir un plan, para empezar a usar la app.
3. Como usuario recurrente, quiero iniciar sesión y recuperar mi contraseña si la olvido.

## Criterios de aceptación (EARS)

- **R1.** CUANDO un usuario se registra con correo/contraseña con datos válidos (nombre, correo con formato válido, contraseña ≥6 caracteres, ambas contraseñas coinciden, carrera y fecha de nacimiento seleccionadas), EL SISTEMA DEBERÁ crear la cuenta en Firebase Auth y llevarlo a selección de plan, SIN escribir aún su documento en Firestore.
- **R2.** CUANDO el correo ingresado ya está en uso, EL SISTEMA DEBERÁ mostrar "Ya existe una cuenta con ese correo" sin crear la cuenta.
- **R3.** CUANDO el usuario elige un plan tras registrarse, EL SISTEMA DEBERÁ crear el documento de Firestore en una sola escritura atómica (perfil + plan), nunca en escrituras separadas.
- **R4.** CUANDO el usuario se registra con Google por primera vez, EL SISTEMA DEBERÁ llevarlo a completar perfil (si falta nombre) y luego a selección de plan (si falta plan), en ese orden.
- **R5.** CUANDO un usuario de Google ya tiene nombre y plan guardados, EL SISTEMA DEBERÁ llevarlo directo a Home, sin pasar por completar perfil ni selección de plan de nuevo.
- **R6.** CUANDO el usuario cancela el selector de cuenta de Google, EL SISTEMA NO DEBERÁ mostrar un error (no es una falla real).
- **R7.** CUANDO el inicio de sesión con correo/contraseña falla, EL SISTEMA DEBERÁ mostrar un mensaje específico según el código de error (cuenta inexistente, contraseña incorrecta, correo inválido), nunca un mensaje genérico.
- **R8.** CUANDO el usuario solicita recuperar contraseña, EL SISTEMA DEBERÁ enviar el correo de recuperación de Firebase Auth al correo indicado.
- **R9.** CUANDO el usuario presiona "Registrarse" o "Google" mientras la operación anterior sigue en curso, EL SISTEMA NO DEBERÁ disparar una segunda solicitud (protección de doble-tap).
- **R10.** CUANDO el usuario cierra sesión, EL SISTEMA DEBERÁ cerrar sesión tanto en Google Sign-In como en Firebase Auth, y remover el token push de ese dispositivo (regla U4 de la constitución).

## Trazabilidad con la constitución

- R3 cumple **S2** (el plan solo nace como `"free"` desde el cliente).
- R10 cumple **U4** (limpieza de token push al cerrar sesión).
