// Ejecutar UNA sola vez, localmente con Node (esto NO es una Cloud
// Function, no se despliega):
//
//   cd functions
//   node scripts/hacer_admin.js TU_UID_AQUI
//
// Antes necesitas descargar tu clave de cuenta de servicio:
// Firebase Console > Configuración del proyecto > Cuentas de servicio >
// "Generar nueva clave privada". Guarda el archivo descargado como
// functions/scripts/serviceAccountKey.json
//
// IMPORTANTE: NUNCA subas serviceAccountKey.json a git. Agrégalo a
// .gitignore (functions/scripts/serviceAccountKey.json).
//
// Tu UID lo encuentras en Firebase Console > Authentication > Users,
// columna "User UID".

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
if (!uid) {
  console.error("Uso: node hacer_admin.js <UID>");
  process.exit(1);
}

admin
  .auth()
  .setCustomUserClaims(uid, { admin: true })
  .then(async () => {
    // También lo marcamos en Firestore (esAdmin: true) — los custom
    // claims no se pueden consultar con un "where" desde Cloud Functions,
    // así que el Bloque 9 (notificar a admins de pagos pendientes)
    // necesita este campo espejo para saber a quién avisar.
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .set({ esAdmin: true }, { merge: true });
    console.log(`Listo: ${uid} ahora tiene el claim admin=true.`);
    console.log(
      "El usuario debe CERRAR SESIÓN y volver a entrar en la app para " +
        "que el claim se refleje en el cliente (el token se refresca al " +
        "iniciar sesión de nuevo).",
    );
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
