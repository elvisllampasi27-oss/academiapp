/**
 * Tests de specs/chatbot/requirements.md (R1) y
 * specs/contenido-explorar/requirements.md (T1.7) — el calendario global
 * que decide qué tema le toca a cada usuario cada día.
 *
 * Cómo correrlos: cd functions && npm install && npm test
 */

let mockUsersStore = {};
let mockCursosStore = []; // [{id, orden, nombre, temas: [{id, orden, titulo}]}]

jest.mock("firebase-functions/v2/https", () => ({
  onCall: (optsOrHandler, maybeHandler) =>
    typeof optsOrHandler === "function" ? optsOrHandler : maybeHandler,
  HttpsError: class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  },
}));
jest.mock("firebase-functions/v2/scheduler", () => ({
  onSchedule: (opts, handler) => handler,
}));
jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentCreated: (path, handler) => handler,
}));
jest.mock("firebase-functions/params", () => ({
  defineSecret: (name) => ({ value: () => `fake-${name}` }),
}));
jest.mock("firebase-functions", () => ({
  logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() },
}));
jest.mock("pdf-parse", () => jest.fn());

jest.mock("firebase-admin", () => {
  const makeUserDocRef = (uid) => ({
    id: uid,
    get: async () => ({ exists: !!mockUsersStore[uid], data: () => mockUsersStore[uid] }),
  });

  const temasCollection = (cursoId) => {
    let orderField = null;
    const curso = mockCursosStore.find((c) => c.id === cursoId) || { temas: [] };
    const api = {
      orderBy(field) {
        orderField = field;
        return api;
      },
      async get() {
        const sorted = [...curso.temas].sort(
          (a, b) => (a[orderField] || 0) - (b[orderField] || 0),
        );
        const docs = sorted.map((t) => ({ id: t.id, data: () => t }));
        return { docs, empty: docs.length === 0 };
      },
    };
    return api;
  };

  const cursosCollection = () => {
    let orderField = null;
    const api = {
      orderBy(field) {
        orderField = field;
        return api;
      },
      async get() {
        const sorted = [...mockCursosStore].sort(
          (a, b) => (a[orderField] || 0) - (b[orderField] || 0),
        );
        const docs = sorted.map((c) => ({
          id: c.id,
          data: () => c,
          ref: { collection: (name) => (name === "temas" ? temasCollection(c.id) : null) },
        }));
        return { docs, empty: docs.length === 0 };
      },
    };
    return api;
  };

  const mockDb = {
    collection: (name) => {
      if (name === "users") return { doc: (uid) => makeUserDocRef(uid) };
      if (name === "cursos") return cursosCollection();
      return { doc: () => ({ get: async () => ({ exists: false }) }) };
    },
  };

  return {
    initializeApp: () => {},
    firestore: Object.assign(() => mockDb, {
      Timestamp: { now: () => ({ toMillis: () => Date.now() }) },
      FieldValue: { serverTimestamp: () => ({ toMillis: () => Date.now() }) },
    }),
    storage: () => ({ bucket: () => ({ file: () => ({}) }) }),
    messaging: () => ({ sendEachForMulticast: jest.fn() }),
  };
});

const index = require("../index.js");

beforeEach(() => {
  mockUsersStore = {};
  mockCursosStore = [];
});

// ─────────────────────── procesarPreguntaChatVideo ────────────────────

describe("procesarPreguntaChatVideo", () => {
  test("R1: rechaza a un usuario no premium antes de llamar a Gemini", async () => {
    mockUsersStore.u1 = { plan: "free" };

    await expect(
      index.procesarPreguntaChatVideo({
        auth: { uid: "u1" },
        data: { cursoId: "c1", temaId: "t1", mensaje: "hola" },
      }),
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});

// ─────────────────────── obtenerEstadoCalendarioTema ───────────────────

describe("obtenerEstadoCalendarioTema", () => {
  test("R5: reporta 'no-premium' sin construir el calendario", async () => {
    mockUsersStore.u1 = { plan: "free" };

    const resultado = await index.obtenerEstadoCalendarioTema({
      auth: { uid: "u1" },
      data: { cursoId: "c1", temaId: "t1" },
    });

    expect(resultado.habilitadoHoy).toBe(false);
    expect(resultado.motivo).toBe("no-premium");
  });

  test("R4: reporta 'sin-ruta' si el usuario no tiene rutaIniciadaEn", async () => {
    mockUsersStore.u1 = { plan: "premium" }; // sin rutaIniciadaEn

    const resultado = await index.obtenerEstadoCalendarioTema({
      auth: { uid: "u1" },
      data: { cursoId: "c1", temaId: "t1" },
    });

    expect(resultado.motivo).toBe("sin-ruta");
  });

  test("R7: habilitadoHoy=true cuando el día lectivo coincide con el día asignado", async () => {
    // 1 solo curso, 1 solo tema -> le toca el día 1, siempre.
    mockCursosStore = [
      { id: "c1", orden: 1, nombre: "Curso 1", temas: [{ id: "t1", orden: 1, titulo: "Tema 1" }] },
    ];
    // rutaIniciadaEn = ahora mismo -> hoy es su día 1 (o muy cerca).
    mockUsersStore.u1 = {
      plan: "premium",
      rutaIniciadaEn: { toDate: () => new Date() },
    };

    const resultado = await index.obtenerEstadoCalendarioTema({
      auth: { uid: "u1" },
      data: { cursoId: "c1", temaId: "t1" },
    });

    expect(resultado.diaAsignado).toBe(1);
    expect(resultado.habilitadoHoy).toBe(true);
  });

  test("R6: reporta 'sin-programar' si el tema no está en el calendario", async () => {
    mockCursosStore = [{ id: "c1", orden: 1, nombre: "Curso 1", temas: [] }]; // sin temas
    mockUsersStore.u1 = {
      plan: "premium",
      rutaIniciadaEn: { toDate: () => new Date() },
    };

    const resultado = await index.obtenerEstadoCalendarioTema({
      auth: { uid: "u1" },
      data: { cursoId: "c1", temaId: "t1-no-existe" },
    });

    expect(resultado.motivo).toBe("sin-programar");
  });
});
