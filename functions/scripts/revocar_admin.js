// Ejecutar UNA sola vez, localmente con Node (esto NO es una Cloud
// Function, no se despliega):
//
//   cd functions
//   node scripts/revocar_admin.js UID_A_REVOCAR
//
// Contraparte de hacer_admin.js: quita el custom claim admin=true Y el
// campo espejo esAdmin en Firestore EN LA MISMA OPERACIÓN, para que
// nunca queden desincronizados (ver constitution.md, regla S3).
//
// Requiere el mismo functions/scripts/serviceAccountKey.json que usa
// hacer_admin.js (NUNCA subir ese archivo a git).

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];
if (!uid) {
  console.error("Uso: node revocar_admin.js <UID>");
  process.exit(1);
}

admin
  .auth()
  .setCustomUserClaims(uid, { admin: false })
  .then(async () => {
    // Espejo en Firestore: se quita en la misma operación que el claim,
    // igual que hacer_admin.js lo escribe al otorgarlo (regla S3).
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .set({ esAdmin: false }, { merge: true });
    console.log(`Listo: ${uid} ya no tiene el claim admin.`);
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
