/**
 * Tests de specs/pagos-yape/requirements.md (T1.3) — el flujo de
 * aprobar/rechazar/revertir pagos manuales por Yape.
 *
 * Mismo enfoque que los archivos anteriores: se mockea "firebase-admin"
 * con una base de datos en memoria, así se prueba la lógica real de
 * index.js sin depender de Firebase de verdad.
 *
 * Cómo correrlos: cd functions && npm install && npm test
 */

let mockUsersStore = {};
let mockPagosStore = {};
const mockSendEachForMulticast = jest.fn();

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
    set: async (patch, opts) => {
      mockUsersStore[uid] =
        opts && opts.merge ? { ...mockUsersStore[uid], ...patch } : patch;
    },
  });
  const makePagoDocRef = (id) => ({
    id,
    get: async () => ({ exists: !!mockPagosStore[id], data: () => mockPagosStore[id] }),
    update: async (patch) => {
      mockPagosStore[id] = { ...mockPagosStore[id], ...patch };
    },
  });

  const mockDb = {
    collection: (name) => {
      if (name === "users") return { doc: (uid) => makeUserDocRef(uid) };
      if (name === "pagos") return { doc: (id) => makePagoDocRef(id) };
      return { doc: () => ({ get: async () => ({ exists: false }) }), add: async () => ({ id: "gen" }) };
    },
  };

  return {
    initializeApp: () => {},
    firestore: Object.assign(() => mockDb, {
      Timestamp: { fromMillis: (ms) => ({ toMillis: () => ms }) },
      FieldValue: {
        serverTimestamp: () => ({ toMillis: () => Date.now() }),
        delete: () => ({ __op: "delete" }),
      },
    }),
    storage: () => ({
      bucket: () => ({
        file: () => ({
          exists: async () => [false],
          save: async () => {},
          download: async () => [Buffer.from("")],
        }),
      }),
    }),
    messaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
  };
});

const index = require("../index.js");

const admin = { uid: "admin1", token: { admin: true } };
const noAdmin = { uid: "u_cualquiera", token: {} };

beforeEach(() => {
  mockUsersStore = {};
  mockPagosStore = {};
  mockSendEachForMulticast.mockReset();
  mockSendEachForMulticast.mockImplementation(async ({ tokens }) => ({
    responses: tokens.map(() => ({ success: true })),
  }));
});

describe("aprobarPagoManual", () => {
  test("R9: rechaza si quien llama no es admin", async () => {
    mockPagosStore.p1 = { uid: "u1", estado: "pendiente", monto: 29 };
    await expect(
      index.aprobarPagoManual({ auth: noAdmin, data: { pagoId: "p1" } }),
    ).rejects.toMatchObject({ code: "permission-denied" });
    expect(mockPagosStore.p1.estado).toBe("pendiente"); // no cambió
  });

  test("R3: aprobar activa premium, registra quién y cuándo, y notifica", async () => {
    mockUsersStore.u1 = { correo: "a@a.com", fcmTokens: ["tok1"] };
    mockPagosStore.p1 = { uid: "u1", estado: "pendiente", monto: 29 };

    const resultado = await index.aprobarPagoManual({
      auth: admin,
      data: { pagoId: "p1" },
    });

    expect(resultado.ok).toBe(true);
    expect(mockUsersStore.u1.plan).toBe("premium");
    expect(mockPagosStore.p1.estado).toBe("aprobado");
    expect(mockPagosStore.p1.resueltoPor).toBe("admin1"); // S4: quién lo resolvió
    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
  });
});

describe("rechazarPagoManual", () => {
  test("R4: rechazar marca el pago como rechazado, sin tocar el plan", async () => {
    mockUsersStore.u1 = { correo: "a@a.com" };
    mockPagosStore.p1 = { uid: "u1", estado: "pendiente", monto: 29 };

    await index.rechazarPagoManual({
      auth: admin,
      data: { pagoId: "p1", motivo: "comprobante ilegible" },
    });

    expect(mockPagosStore.p1.estado).toBe("rechazado");
    expect(mockPagosStore.p1.motivo).toBe("comprobante ilegible");
    expect(mockUsersStore.u1.plan).toBeUndefined(); // nunca se tocó
  });
});

describe("revertirPagoManual", () => {
  test("R5: revertir un pago aprobado quita el premium y lo vuelve a pendiente", async () => {
    mockUsersStore.u1 = { plan: "premium", premium_hasta: { toMillis: () => 123 } };
    mockPagosStore.p1 = { uid: "u1", estado: "aprobado" };

    await index.revertirPagoManual({ auth: admin, data: { pagoId: "p1" } });

    expect(mockUsersStore.u1.plan).toBe("free");
    expect(mockUsersStore.u1.premium_hasta).toBeNull();
    expect(mockPagosStore.p1.estado).toBe("pendiente");
    expect(mockPagosStore.p1.revertidoPor).toBe("admin1");
  });

  test("R6: revertir un pago rechazado lo vuelve a pendiente SIN tocar el plan", async () => {
    mockUsersStore.u1 = { plan: "free" }; // nunca llegó a ser premium por este pago
    mockPagosStore.p1 = { uid: "u1", estado: "rechazado", motivo: "algo" };

    await index.revertirPagoManual({ auth: admin, data: { pagoId: "p1" } });

    expect(mockUsersStore.u1.plan).toBe("free"); // sin cambios
    expect(mockPagosStore.p1.estado).toBe("pendiente");
  });

  test("R7: revertir un pago todavía pendiente se rechaza (no hay nada que revertir)", async () => {
    mockPagosStore.p1 = { uid: "u1", estado: "pendiente" };

    await expect(
      index.revertirPagoManual({ auth: admin, data: { pagoId: "p1" } }),
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});
