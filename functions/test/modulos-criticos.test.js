/**
 * Tests de los dos módulos más riesgosos identificados en la Fase 1:
 *  - Pagos con Culqi (specs/pagos-culqi/requirements.md) — dinero real.
 *  - Exámenes: el fix de seguridad de T1.6 (specs/examenes-quizzes/
 *    requirements.md, R4/R5) — para que nadie lo rompa sin darse cuenta
 *    en un cambio futuro.
 *
 * Mismo enfoque que premium-recordatorio.test.js: se mockea
 * "firebase-admin" con una base de datos en memoria, así se prueba la
 * lógica real de index.js sin depender de Firebase de verdad.
 *
 * Cómo correrlos: cd functions && npm install && npm test
 */

let mockUsersStore = {};
const mockGenericStore = {}; // key: "coleccion/id" -> data
const mockSendEachForMulticast = jest.fn();
const mockLoggerWarn = jest.fn();
const mockFetch = jest.fn();

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
  logger: { info: jest.fn(), warn: (...a) => mockLoggerWarn(...a), error: jest.fn() },
}));
jest.mock("pdf-parse", () => jest.fn());

jest.mock("firebase-admin", () => {
  const makeUserDocRef = (uid) => ({
    id: uid,
    get: async () => ({
      exists: !!mockUsersStore[uid],
      data: () => mockUsersStore[uid],
    }),
    update: async (patch) => {
      mockUsersStore[uid] = { ...mockUsersStore[uid], ...patch };
    },
    set: async (patch, opts) => {
      mockUsersStore[uid] =
        opts && opts.merge ? { ...mockUsersStore[uid], ...patch } : patch;
    },
  });

  const usersCollection = () => ({
    doc: (uid) => makeUserDocRef(uid),
  });

  // Colección genérica: sirve para "examenes", "pagos_culqi", etc. — todo
  // lo que no necesita queries con where(), solo doc()/get()/set()/add().
  const genericCollection = (name) => ({
    doc: (id) => ({
      id,
      get: async () => ({
        exists: mockGenericStore[`${name}/${id}`] !== undefined,
        data: () => mockGenericStore[`${name}/${id}`],
      }),
      set: async (data) => {
        mockGenericStore[`${name}/${id}`] = data;
      },
      update: async (data) => {
        mockGenericStore[`${name}/${id}`] = {
          ...mockGenericStore[`${name}/${id}`],
          ...data,
        };
      },
    }),
    add: async (data) => {
      const id = `gen_${Object.keys(mockGenericStore).length}`;
      mockGenericStore[`${name}/${id}`] = data;
      return { id };
    },
  });

  const mockDb = {
    collection: (name) => (name === "users" ? usersCollection() : genericCollection(name)),
  };

  return {
    initializeApp: () => {},
    firestore: Object.assign(() => mockDb, {
      Timestamp: {
        now: () => ({ toMillis: () => Date.now() }),
        fromMillis: (ms) => ({ toMillis: () => ms }),
      },
      FieldValue: {
        serverTimestamp: () => ({ toMillis: () => Date.now() }),
      },
    }),
    storage: () => ({ bucket: () => ({ file: () => ({}) }) }),
    messaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
  };
});

global.fetch = mockFetch;

const index = require("../index.js");

beforeEach(() => {
  mockUsersStore = {};
  Object.keys(mockGenericStore).forEach((k) => delete mockGenericStore[k]);
  mockFetch.mockReset();
  mockSendEachForMulticast.mockReset();
  mockSendEachForMulticast.mockImplementation(async ({ tokens }) => ({
    responses: tokens.map(() => ({ success: true })),
  }));
  mockLoggerWarn.mockReset();
});

// ────────────────────────── procesarPagoCulqi ─────────────────────────

describe("procesarPagoCulqi", () => {
  const request = (data) => ({
    auth: { uid: "u1", token: { email: "alumno@correo.com" } },
    data,
  });

  test("R8: rechaza sin autenticación, antes de llamar a Culqi", async () => {
    await expect(
      index.procesarPagoCulqi({ auth: null, data: { tokenId: "tok_1" } }),
    ).rejects.toMatchObject({ code: "unauthenticated" });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  test("R7: rechaza si falta tokenId, antes de llamar a Culqi", async () => {
    await expect(index.procesarPagoCulqi(request({}))).rejects.toMatchObject({
      code: "invalid-argument",
    });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  test("R2/R3/R6: pago aprobado activa premium, audita el cargo y notifica", async () => {
    mockUsersStore.u1 = { fcmTokens: ["tok1"] };
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ id: "ch_test123" }),
    });

    const resultado = await index.procesarPagoCulqi(request({ tokenId: "tok_1" }));

    expect(resultado.ok).toBe(true);
    expect(mockUsersStore.u1.plan).toBe("premium");
    expect(mockUsersStore.u1.premium_hasta).toBeTruthy();
    // R3: auditoría en colección separada, no en el doc del usuario.
    const cargos = Object.entries(mockGenericStore).filter(([k]) =>
      k.startsWith("pagos_culqi/"),
    );
    expect(cargos.length).toBe(1);
    expect(cargos[0][1].chargeId).toBe("ch_test123");
    // R6: notificación de confirmación.
    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
  });

  test("R4: pago rechazado por Culqi no activa premium", async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      json: async () => ({ user_message: "Fondos insuficientes" }),
    });

    await expect(index.procesarPagoCulqi(request({ tokenId: "tok_1" }))).rejects.toMatchObject({
      code: "failed-precondition",
      message: "Fondos insuficientes",
    });
    expect(mockUsersStore.u1).toBeUndefined(); // nunca se llegó a escribir
  });

  test("R5: falla de red con Culqi no expone el error interno ni activa premium", async () => {
    mockFetch.mockRejectedValue(new Error("ECONNRESET"));

    await expect(index.procesarPagoCulqi(request({ tokenId: "tok_1" }))).rejects.toMatchObject({
      code: "internal",
    });
    expect(mockUsersStore.u1).toBeUndefined();
  });
});

// ────────────────── obtenerExamen (fix de seguridad T1.6) ─────────────

describe("obtenerExamen — fix de seguridad (specs/examenes-quizzes/requirements.md R4/R5)", () => {
  const preguntaConRespuesta = {
    pregunta: "¿2+2?",
    opciones: ["3", "4", "5", "6"],
    respuestaCorrecta: 1,
    explicacion: "2+2=4",
  };

  test("R4: examen tipo admisión NO expone respuestaCorrecta/explicacion", async () => {
    mockUsersStore.u1 = { plan: "premium" };
    mockGenericStore["examenes/exam1"] = {
      titulo: "Simulacro admisión",
      categoria: "admision",
      preguntas: [preguntaConRespuesta],
    };

    const resultado = await index.obtenerExamen({
      auth: { uid: "u1" },
      data: { examenId: "exam1" },
    });

    expect(resultado.examen.preguntas[0]).not.toHaveProperty("respuestaCorrecta");
    expect(resultado.examen.preguntas[0]).not.toHaveProperty("explicacion");
    expect(resultado.examen.preguntas[0].pregunta).toBe("¿2+2?"); // el resto sí viaja
  });

  test("R5: examen modo práctica SÍ expone respuestaCorrecta/explicacion (a propósito)", async () => {
    mockUsersStore.u1 = { plan: "free" };
    mockGenericStore["examenes/exam2"] = {
      titulo: "Práctica ordinaria",
      categoria: "ordinario",
      preguntas: [preguntaConRespuesta],
    };

    const resultado = await index.obtenerExamen({
      auth: { uid: "u1" },
      data: { examenId: "exam2" },
    });

    expect(resultado.examen.preguntas[0].respuestaCorrecta).toBe(1);
    expect(resultado.examen.preguntas[0].explicacion).toBe("2+2=4");
  });

  test("R1: examen admisión rechaza a usuario no premium, antes de devolver nada", async () => {
    mockUsersStore.u1 = { plan: "free" };
    mockGenericStore["examenes/exam1"] = {
      titulo: "Simulacro admisión",
      categoria: "admision",
      preguntas: [preguntaConRespuesta],
    };

    await expect(
      index.obtenerExamen({ auth: { uid: "u1" }, data: { examenId: "exam1" } }),
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});
