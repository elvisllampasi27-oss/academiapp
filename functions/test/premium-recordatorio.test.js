/**
 * Tests de Fase 5 (specs/premium/requirements.md, R6 + specs/panel-admin
 * para el hallazgo de aprobarPagoManual). Cada test está comentado con el
 * requisito EARS que verifica, para que quede trazado igual que el resto
 * de la spec.
 *
 * Cómo correrlos:
 *   cd functions
 *   npm install        (instala jest, ya agregado a package.json)
 *   npm test
 *
 * Estrategia: en vez de un emulador de Firebase completo (más pesado de
 * configurar para un primer test), se mockea "firebase-admin" y los
 * wrappers de "firebase-functions" con una base de datos en memoria muy
 * simple. Esto prueba la LÓGICA real de index.js (nada de lo que se
 * verifica aquí está simulado, solo el almacenamiento) sin depender de
 * una conexión real a Firebase.
 */

// ── Mocks (deben declararse antes del require de index.js) ────────────
// Nota: las variables usadas dentro de jest.mock(...) deben empezar con
// "mock" — es una regla de Jest, no un estilo elegido.

let mockUsersStore = {};
let mockPagosStore = {};
const mockSendEachForMulticast = jest.fn();
const mockLoggerWarn = jest.fn();

function mockTs(millis) {
  return { toMillis: () => millis, toDate: () => new Date(millis) };
}
function mockMillisOf(v) {
  return v && typeof v.toMillis === "function" ? v.toMillis() : v;
}

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
      if (mockUsersStore[uid] && mockUsersStore[uid].__forzarErrorAlActualizar) {
        throw new Error("fallo simulado de escritura");
      }
      mockUsersStore[uid] = { ...mockUsersStore[uid], ...patch };
    },
    set: async (patch, opts) => {
      mockUsersStore[uid] =
        opts && opts.merge ? { ...mockUsersStore[uid], ...patch } : patch;
    },
  });

  const usersCollection = () => {
    const filters = [];
    const api = {
      where(field, op, value) {
        filters.push({ field, op, value });
        return api;
      },
      async get() {
        const docs = Object.keys(mockUsersStore)
          .filter((uid) =>
            filters.every((f) => {
              const actual = mockMillisOf(mockUsersStore[uid][f.field]);
              const wanted = mockMillisOf(f.value);
              if (f.op === "==") return mockUsersStore[uid][f.field] === f.value;
              if (f.op === "<=") return actual !== undefined && actual <= wanted;
              if (f.op === ">") return actual !== undefined && actual > wanted;
              throw new Error(`operador no soportado en el mock: ${f.op}`);
            }),
          )
          .map((uid) => ({
            id: uid,
            data: () => mockUsersStore[uid],
            ref: makeUserDocRef(uid),
          }));
        return {
          empty: docs.length === 0,
          size: docs.length,
          docs,
          forEach: (fn) => docs.forEach(fn),
        };
      },
      doc: (uid) => makeUserDocRef(uid),
    };
    return api;
  };

  const pagosCollection = () => ({
    doc: (id) => ({
      get: async () => ({
        exists: !!mockPagosStore[id],
        data: () => mockPagosStore[id],
      }),
      update: async (patch) => {
        mockPagosStore[id] = { ...mockPagosStore[id], ...patch };
      },
    }),
  });

  const genericCollection = () => ({
    add: async () => ({ id: "gen_1" }),
    doc: () => ({
      get: async () => ({ exists: false, data: () => undefined }),
      set: async () => {},
      update: async () => {},
    }),
  });

  const mockDb = {
    collection: (name) => {
      if (name === "users") return usersCollection();
      if (name === "pagos") return pagosCollection();
      return genericCollection();
    },
    batch: () => {
      const ops = [];
      return {
        update: (ref, patch) => ops.push(() => (mockUsersStore[ref.id] = { ...mockUsersStore[ref.id], ...patch })),
        commit: async () => ops.forEach((op) => op()),
      };
    },
  };

  return {
    initializeApp: () => {},
    firestore: Object.assign(() => mockDb, {
      Timestamp: {
        now: () => mockTs(Date.now()),
        fromMillis: (ms) => mockTs(ms),
      },
      FieldValue: {
        serverTimestamp: () => mockTs(Date.now()),
        arrayUnion: (...items) => ({ __op: "arrayUnion", items }),
        arrayRemove: (...items) => ({ __op: "arrayRemove", items }),
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

const DIA_MS = 24 * 60 * 60 * 1000;

beforeEach(() => {
  mockUsersStore = {};
  mockPagosStore = {};
  mockSendEachForMulticast.mockReset();
  mockSendEachForMulticast.mockImplementation(async ({ tokens }) => ({
    responses: tokens.map(() => ({ success: true })),
  }));
  mockLoggerWarn.mockReset();
});

// ─────────────────────── notificarPremiumPorVencer ────────────────────

describe("notificarPremiumPorVencer", () => {
  test("R6.1/R6.4: notifica a un usuario premium que vence en 2 días", async () => {
    mockUsersStore.u1 = {
      plan: "premium",
      premium_hasta: mockTs(Date.now() + 2 * DIA_MS),
      fcmTokens: ["tok1"],
      recordatorio_3d_enviado_en: null,
    };

    await index.notificarPremiumPorVencer();

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
    const payload = mockSendEachForMulticast.mock.calls[0][0];
    expect(payload.tokens).toEqual(["tok1"]);
    expect(payload.notification.title).toMatch(/por vencer/i);
    expect(mockUsersStore.u1.recordatorio_3d_enviado_en).toBeTruthy();
  });

  test("R6.2: no reenvía si el recordatorio de este ciclo ya se envió", async () => {
    mockUsersStore.u1 = {
      plan: "premium",
      premium_hasta: mockTs(Date.now() + 2 * DIA_MS),
      fcmTokens: ["tok1"],
      recordatorio_3d_enviado_en: mockTs(Date.now() - DIA_MS), // ya se envió antes
    };

    await index.notificarPremiumPorVencer();

    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });

  test("T-I: no notifica a quien ya venció hoy (eso lo hace expirarPremiumVencidos)", async () => {
    mockUsersStore.u1 = {
      plan: "premium",
      premium_hasta: mockTs(Date.now() - 1000), // ya venció
      fcmTokens: ["tok1"],
      recordatorio_3d_enviado_en: null,
    };

    await index.notificarPremiumPorVencer();

    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });

  test("R6.1: un fallo al marcar un usuario no detiene el envío a los demás", async () => {
    mockUsersStore.u1 = {
      plan: "premium",
      premium_hasta: mockTs(Date.now() + 2 * DIA_MS),
      fcmTokens: ["tok1"],
      recordatorio_3d_enviado_en: null,
      __forzarErrorAlActualizar: true, // simula que doc.ref.update() falla
    };
    mockUsersStore.u2 = {
      plan: "premium",
      premium_hasta: mockTs(Date.now() + 2 * DIA_MS),
      fcmTokens: ["tok2"],
      recordatorio_3d_enviado_en: null,
    };

    await index.notificarPremiumPorVencer();

    // u1 falló al marcar (doc.ref.update lanzó el error simulado), así
    // que su recordatorio_3d_enviado_en sigue en null, sin cambios.
    expect(mockUsersStore.u1.recordatorio_3d_enviado_en).toBeNull();
    // u2 sí se procesó normalmente pese al fallo de u1
    expect(mockUsersStore.u2.recordatorio_3d_enviado_en).toBeTruthy();
    expect(mockLoggerWarn).toHaveBeenCalled();
  });
});

// ─────────────────────────── expirarPremiumVencidos ───────────────────

describe("expirarPremiumVencidos", () => {
  test("R6.6: notifica 'venció' además de bajar el plan a free", async () => {
    mockUsersStore.u1 = {
      plan: "premium",
      premium_hasta: mockTs(Date.now() - 1000),
      fcmTokens: ["tok1"],
    };

    await index.expirarPremiumVencidos();

    expect(mockUsersStore.u1.plan).toBe("free");
    expect(mockUsersStore.u1.premium_hasta).toBeNull();
    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
    const payload = mockSendEachForMulticast.mock.calls[0][0];
    expect(payload.notification.title).toMatch(/venció/i);
  });
});

// ─────────────────────────── aprobarPagoManual ─────────────────────────

describe("aprobarPagoManual", () => {
  test("R6.3: resetea recordatorio_3d_enviado_en al aprobar la renovación", async () => {
    mockUsersStore.u1 = {
      correo: "alumno@correo.com",
      recordatorio_3d_enviado_en: mockTs(Date.now() - DIA_MS), // ciclo anterior
    };
    mockPagosStore.pago1 = { uid: "u1", monto: 29, estado: "pendiente" };

    await index.aprobarPagoManual({
      auth: { uid: "admin1", token: { admin: true } },
      data: { pagoId: "pago1" },
    });

    expect(mockUsersStore.u1.plan).toBe("premium");
    expect(mockUsersStore.u1.recordatorio_3d_enviado_en).toBeNull();
  });
});
