/**
 * Tests de specs/reglas-seguridad/requirements.md — prueban firestore.rules
 * DE VERDAD, contra el Emulador de Firestore (no un mock en memoria como
 * los demás archivos de test).
 *
 * REQUISITOS para correr esto:
 *   1. Java instalado (el emulador de Firestore corre sobre Java).
 *   2. npm install (ya incluye @firebase/rules-unit-testing).
 *
 * Cómo correrlos (desde functions/):
 *   npm run test:rules
 *
 * Eso levanta el emulador, corre este archivo, y lo apaga solo —
 * no necesitas tener el emulador corriendo tú mismo aparte.
 */

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const fs = require("fs");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "academiapp-test-rules",
    firestore: {
      rules: fs.readFileSync("../firestore.rules", "utf8"),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ────────────────────────────── users/{uid} ────────────────────────────

describe("users/{uid}", () => {
  test("un usuario SÍ puede leer su propio documento", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("u1").set({ plan: "free" });
    });
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertSucceeds(u1.collection("users").doc("u1").get());
  });

  test("un usuario NO puede leer el documento de otro usuario", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("u2").set({ plan: "free" });
    });
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(u1.collection("users").doc("u2").get());
  });

  test("create SOLO se permite con plan='free' (S2)", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      u1
        .collection("users")
        .doc("u1")
        .set({ uid: "u1", plan: "premium", premium_hasta: null, ultimo_bloque_examen_abierto: null }),
    );
    await assertSucceeds(
      u1
        .collection("users")
        .doc("u1")
        .set({ uid: "u1", plan: "free", premium_hasta: null, ultimo_bloque_examen_abierto: null }),
    );
  });

  test("el cliente NO puede subirse el plan a premium con un update directo (S2)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("u1").set({ plan: "free", premium_hasta: null });
    });
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      u1.collection("users").doc("u1").update({ plan: "premium" }),
    );
  });

  test("el cliente SÍ puede actualizar solo su fcmTokens (U2)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("u1").set({ plan: "free" });
    });
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertSucceeds(
      u1.collection("users").doc("u1").update({ fcmTokens: ["tok1"] }),
    );
  });

  test("un admin SÍ puede listar la colección users completa (dashboard)", async () => {
    const adminCtx = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertSucceeds(adminCtx.collection("users").get());
  });

  test("un usuario normal NO puede listar la colección users completa", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(u1.collection("users").get());
  });
});

// ─────────────────────── progresoQuiz / examenesResueltos ──────────────

describe("users/{uid}/progresoQuiz y examenesResueltos", () => {
  test("nadie desde el cliente puede escribir en progresoQuiz (solo Cloud Function)", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      u1
        .collection("users")
        .doc("u1")
        .collection("progresoQuiz")
        .doc("c1_t1")
        .set({ basico: { aprobado: true } }),
    );
  });
});

// ──────────────────────────────── pagos ─────────────────────────────────

describe("pagos/{pagoId}", () => {
  test("un usuario SÍ puede crear su propio pago en estado pendiente", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertSucceeds(
      u1.collection("pagos").doc("p1").set({ uid: "u1", monto: 29, estado: "pendiente" }),
    );
  });

  test("un usuario NO puede crear un pago ya 'aprobado' (saltarse la revisión del admin)", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      u1.collection("pagos").doc("p1").set({ uid: "u1", monto: 29, estado: "aprobado" }),
    );
  });

  test("un usuario NO puede crear un pago a nombre de otro uid", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(
      u1.collection("pagos").doc("p1").set({ uid: "otro-usuario", monto: 29, estado: "pendiente" }),
    );
  });
});

// ─────────────────────────────── examenes ────────────────────────────────

describe("examenes/{examenId}", () => {
  test("NADIE puede leer la colección examenes directo, ni el propio admin (allow read: if false)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("examenes").doc("e1").set({ titulo: "Examen 1" });
    });
    const adminCtx = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertFails(adminCtx.collection("examenes").doc("e1").get());
  });
});

// ─────────────────────────────── cursos ─────────────────────────────────

describe("cursos/{cursoId}", () => {
  test("cualquier usuario autenticado puede leer el catálogo de cursos", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("cursos").doc("c1").set({ nombre: "Curso 1" });
    });
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertSucceeds(u1.collection("cursos").doc("c1").get());
  });

  test("un usuario normal NO puede editar el catálogo de cursos", async () => {
    const u1 = testEnv.authenticatedContext("u1").firestore();
    await assertFails(u1.collection("cursos").doc("c1").set({ nombre: "Hackeado" }));
  });

  test("un admin SÍ puede editar el catálogo de cursos", async () => {
    const adminCtx = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertSucceeds(adminCtx.collection("cursos").doc("c1").set({ nombre: "Curso 1" }));
  });
});
