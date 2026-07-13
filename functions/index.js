// Redeploy forzado a Node 22 — 2026-07-08
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const pdfParse = require("pdf-parse");

admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

const CULQI_SECRET_KEY = defineSecret("CULQI_SECRET_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const PRECIO_SOLES = 29;
const DIAS_PREMIUM = 90;

function esAdmin(request) {
  return !!(
    request.auth &&
    request.auth.token &&
    request.auth.token.admin === true
  );
}

// ══════════════════════ Bloque 9: notificaciones ═══════════════════════

async function enviarNotificacionAUsuario(uid, { title, body, data }) {
  const userSnap = await db.collection("users").doc(uid).get();
  const tokens = (userSnap.data() || {}).fcmTokens || [];
  if (tokens.length === 0) return;

  try {
    const resp = await admin.messaging().sendEachForMulticast({
      notification: { title, body },
      data: data || {},
      tokens,
    });

    const invalidos = [];
    resp.responses.forEach((r, i) => {
      const codigo = r.error && r.error.code;
      if (
        !r.success &&
        (codigo === "messaging/invalid-registration-token" ||
          codigo === "messaging/registration-token-not-registered")
      ) {
        invalidos.push(tokens[i]);
      }
    });
    if (invalidos.length > 0) {
      await db
        .collection("users")
        .doc(uid)
        .update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidos),
        });
    }
  } catch (err) {
    logger.warn("Error enviando notificación push", { uid, err: String(err) });
  }
}

async function agregarFilaCsv(rutaArchivo, fila) {
  const file = bucket.file(rutaArchivo);
  const [existe] = await file.exists();

  const encabezado = "fecha,uid,correo,monto,estado,motivo,aprobadoPor\n";
  const lineaCsv =
    [
      fila.fecha,
      fila.uid,
      fila.correo,
      fila.monto,
      fila.estado,
      fila.motivo || "",
      fila.aprobadoPor || "",
    ]
      .map((v) => `"${String(v).replace(/"/g, '""')}"`)
      .join(",") + "\n";

  if (!existe) {
    await file.save(encabezado + lineaCsv, { contentType: "text/csv" });
  } else {
    const [contenidoActual] = await file.download();
    await file.save(contenidoActual.toString("utf8") + lineaCsv, {
      contentType: "text/csv",
    });
  }
}

exports.procesarPagoCulqi = onCall(
  { secrets: [CULQI_SECRET_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = request.auth.uid;
    const tokenId = request.data && request.data.tokenId;
    if (!tokenId || typeof tokenId !== "string") {
      throw new HttpsError("invalid-argument", "Falta el token de pago.");
    }

    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};
    const email =
      userData.correo || request.auth.token.email || "sin-correo@academiapp.pe";

    const amountCents = PRECIO_SOLES * 100;
    let culqiResponse;

    try {
      const res = await fetch("https://api.culqi.com/v2/charges", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${CULQI_SECRET_KEY.value()}`,
        },
        body: JSON.stringify({
          amount: amountCents,
          currency_code: "PEN",
          email: email,
          source_id: tokenId,
          description: "Suscripcion Premium AcademiApp (30 dias)",
        }),
      });
      culqiResponse = await res.json();

      if (!res.ok) {
        logger.warn("Culqi rechazo el cargo", { uid, culqiResponse });
        throw new HttpsError(
          "failed-precondition",
          culqiResponse.user_message ||
            culqiResponse.merchant_message ||
            "Pago rechazado",
        );
      }
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("Error llamando a Culqi", err);
      throw new HttpsError(
        "internal",
        "No se pudo conectar con la pasarela de pago.",
      );
    }

    const premiumHasta = admin.firestore.Timestamp.fromMillis(
      Date.now() + DIAS_PREMIUM * 24 * 60 * 60 * 1000,
    );

    await db.collection("users").doc(uid).set(
      {
        plan: "premium",
        premium_hasta: premiumHasta,
        rutaIniciadaEn: admin.firestore.FieldValue.serverTimestamp(),
        // T-F (specs/premium/tasks.md): nuevo ciclo premium, se resetea el
        // aviso de "por vencer" para que pueda volver a enviarse en este
        // ciclo (regla R6.3, specs/premium/requirements.md).
        recordatorio_3d_enviado_en: null,
      },
      { merge: true },
    );

    await db.collection("pagos_culqi").add({
      uid,
      chargeId: culqiResponse.id,
      amount: amountCents,
      currency: "PEN",
      fecha: admin.firestore.FieldValue.serverTimestamp(),
    });

    await enviarNotificacionAUsuario(uid, {
      title: "¡Ya eres Premium! 🎉",
      body: "Tu pago se procesó correctamente. Disfruta todo sin límites.",
      data: { tipo: "pago_aprobado" },
    });

    return { ok: true, chargeId: culqiResponse.id };
  },
);

exports.aprobarPagoManual = onCall(async (request) => {
  if (!esAdmin(request)) {
    throw new HttpsError(
      "permission-denied",
      "Solo un administrador puede aprobar pagos.",
    );
  }
  const pagoId = request.data && request.data.pagoId;
  if (!pagoId) {
    throw new HttpsError("invalid-argument", "Falta el id del pago.");
  }

  const pagoRef = db.collection("pagos").doc(pagoId);
  const pagoSnap = await pagoRef.get();
  if (!pagoSnap.exists) {
    throw new HttpsError("not-found", "Ese pago ya no existe.");
  }
  const pago = pagoSnap.data();

  const userRef = db.collection("users").doc(pago.uid);
  const userSnap = await userRef.get();
  const correo = (userSnap.data() || {}).correo || "";

  const premiumHasta = admin.firestore.Timestamp.fromMillis(
    Date.now() + DIAS_PREMIUM * 24 * 60 * 60 * 1000,
  );

  await userRef.set(
    {
      plan: "premium",
      premium_hasta: premiumHasta,
      rutaIniciadaEn: admin.firestore.FieldValue.serverTimestamp(),
      // T-F (specs/premium/tasks.md): mismo reset que procesarPagoCulqi.
      recordatorio_3d_enviado_en: null,
    },
    { merge: true },
  );

  await agregarFilaCsv("historial_pagos_manuales.csv", {
    fecha: new Date().toISOString(),
    uid: pago.uid,
    correo,
    monto: pago.monto,
    estado: "aprobado",
    aprobadoPor: request.auth.uid,
  });

  // Antes se borraba el documento (y el comprobante en Storage) apenas se
  // aprobaba, dejando como único rastro una fila en un CSV sin la imagen.
  // Eso hacía imposible revisar después una decisión ("¿aprobamos un
  // comprobante que en realidad estaba mal?") porque la prueba ya no
  // existía. Ahora se conserva el documento con su estado actualizado y
  // el comprobante en Storage, para que el panel de administración pueda
  // mostrar el historial completo (pendientes, aprobados y rechazados)
  // con la imagen todavía disponible.
  await pagoRef.update({
    estado: "aprobado",
    resueltoPor: request.auth.uid,
    resueltoEn: admin.firestore.FieldValue.serverTimestamp(),
  });

  await enviarNotificacionAUsuario(pago.uid, {
    title: "¡Ya eres Premium! 🎉",
    body: "Tu pago por Yape fue aprobado. Disfruta todo sin límites.",
    data: { tipo: "pago_aprobado" },
  });

  return { ok: true };
});

exports.rechazarPagoManual = onCall(async (request) => {
  if (!esAdmin(request)) {
    throw new HttpsError(
      "permission-denied",
      "Solo un administrador puede rechazar pagos.",
    );
  }
  const pagoId = request.data && request.data.pagoId;
  const motivo = (request.data && request.data.motivo) || "sin especificar";
  if (!pagoId) {
    throw new HttpsError("invalid-argument", "Falta el id del pago.");
  }

  const pagoRef = db.collection("pagos").doc(pagoId);
  const pagoSnap = await pagoRef.get();
  if (!pagoSnap.exists) {
    throw new HttpsError("not-found", "Ese pago ya no existe.");
  }
  const pago = pagoSnap.data();

  const userSnap = await db.collection("users").doc(pago.uid).get();
  const correo = (userSnap.data() || {}).correo || "";

  await agregarFilaCsv("historial_pagos_manuales.csv", {
    fecha: new Date().toISOString(),
    uid: pago.uid,
    correo,
    monto: pago.monto,
    estado: "rechazado",
    motivo,
    aprobadoPor: request.auth.uid,
  });

  // Mismo cambio que en aprobarPagoManual: se conserva el documento y el
  // comprobante en Storage en vez de borrarlos, para poder revisar
  // después por qué se rechazó un comprobante específico.
  await pagoRef.update({
    estado: "rechazado",
    motivo,
    resueltoPor: request.auth.uid,
    resueltoEn: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

// Por si se aprobó o rechazó un comprobante por error (monto que en
// realidad no coincidía, captura de otro usuario, etc.). Solo tiene
// sentido sobre un pago YA resuelto (aprobado o rechazado) — para un
// pago pendiente no hay nada que revertir. Si el pago estaba aprobado,
// se le quita el Premium al usuario (no se toca su rutaIniciadaEn: su
// avance de estudio no tiene por qué perderse por un error de cobro). El
// pago vuelve a quedar "pendiente" para tomar la decisión correcta.
exports.revertirPagoManual = onCall(async (request) => {
  if (!esAdmin(request)) {
    throw new HttpsError(
      "permission-denied",
      "Solo un administrador puede revertir un pago.",
    );
  }
  const pagoId = request.data && request.data.pagoId;
  if (!pagoId) {
    throw new HttpsError("invalid-argument", "Falta el id del pago.");
  }

  const pagoRef = db.collection("pagos").doc(pagoId);
  const pagoSnap = await pagoRef.get();
  if (!pagoSnap.exists) {
    throw new HttpsError("not-found", "Ese pago ya no existe.");
  }
  const pago = pagoSnap.data();
  if (pago.estado === "pendiente") {
    throw new HttpsError(
      "failed-precondition",
      "Este pago todavía está pendiente, no hay nada que revertir.",
    );
  }

  if (pago.estado === "aprobado") {
    await db
      .collection("users")
      .doc(pago.uid)
      .set({ plan: "free", premium_hasta: null }, { merge: true });
  }

  await pagoRef.update({
    estado: "pendiente",
    revertidoPor: request.auth.uid,
    revertidoEn: admin.firestore.FieldValue.serverTimestamp(),
    motivo: admin.firestore.FieldValue.delete(),
  });

  return { ok: true };
});

exports.expirarPremiumVencidos = onSchedule(
  { schedule: "every day 03:00", timeZone: "America/Lima" },
  async () => {
    const ahora = admin.firestore.Timestamp.now();
    const snap = await db
      .collection("users")
      .where("plan", "==", "premium")
      .where("premium_hasta", "<=", ahora)
      .get();

    if (snap.empty) {
      logger.info("expirarPremiumVencidos: nadie vencio hoy");
      return;
    }

    const batch = db.batch();
    snap.forEach((doc) => {
      batch.update(doc.ref, { plan: "free", premium_hasta: null });
    });
    await batch.commit();
    logger.info(
      `expirarPremiumVencidos: ${snap.size} usuario(s) regresado(s) a free`,
    );

    // T-G (specs/premium/tasks.md, R6.6): aviso de "ya venció", distinto del
    // recordatorio de "vence en 3 días" que envía notificarPremiumPorVencer.
    // Va DESPUÉS del batch.commit() (los batches de Firestore no envían
    // notificaciones, solo escriben) y en un loop aparte para no atar el
    // éxito de la baja de plan al éxito del envío push.
    for (const doc of snap.docs) {
      try {
        await enviarNotificacionAUsuario(doc.id, {
          title: "Tu premium venció",
          body: "Renueva cuando quieras para recuperar el acceso completo.",
          data: { tipo: "premium_vencido" },
        });
      } catch (err) {
        logger.warn("expirarPremiumVencidos: fallo notificando vencimiento", {
          uid: doc.id,
          err: String(err),
        });
      }
    }
  },
);

// T-A a T-H (specs/premium/tasks.md), implementando R6.1-R6.5 de
// specs/premium/requirements.md: recordatorio de renovación 3 días antes
// de que venza el premium. Corre en paralelo a expirarPremiumVencidos, no
// la reemplaza ni depende de ella.
exports.notificarPremiumPorVencer = onSchedule(
  { schedule: "every day 08:30", timeZone: "America/Lima" },
  async () => {
    const ahora = admin.firestore.Timestamp.now();
    const en3Dias = admin.firestore.Timestamp.fromMillis(
      Date.now() + 3 * 24 * 60 * 60 * 1000,
    );

    // T-B: candidatos = premium, vencen entre ahora y dentro de 3 días.
    const snap = await db
      .collection("users")
      .where("plan", "==", "premium")
      .where("premium_hasta", "<=", en3Dias)
      .where("premium_hasta", ">", ahora)
      .get();

    if (snap.empty) {
      logger.info("notificarPremiumPorVencer: nadie por vencer en 3 dias");
      return;
    }

    let enviados = 0;
    for (const doc of snap.docs) {
      const data = doc.data();

      // T-C (R6.2): idempotencia — filtrado en memoria porque el índice
      // compuesto para agregar esta condición a la query todavía no existe
      // (ver T-J en tasks.md). Si se crea el índice más adelante, esta
      // condición puede moverse a la query de arriba.
      if (data.recordatorio_3d_enviado_en) continue;

      try {
        // T-D (R6.4): reutiliza el envío ya existente (multicast, limpieza
        // de tokens inválidos), sin lógica de mensajería nueva.
        await enviarNotificacionAUsuario(doc.id, {
          title: "Tu premium está por vencer",
          body: "Renueva en los próximos 3 días para no perder tu acceso.",
          data: { tipo: "premium_por_vencer" },
        });
        // T-E: se marca solo si el envío no lanzó excepción.
        await doc.ref.update({
          recordatorio_3d_enviado_en: admin.firestore.FieldValue.serverTimestamp(),
        });
        enviados++;
      } catch (err) {
        logger.warn("notificarPremiumPorVencer: fallo con un usuario", {
          uid: doc.id,
          err: String(err),
        });
      }
    }
    logger.info(`notificarPremiumPorVencer: ${enviados} recordatorio(s) enviado(s)`);
  },
);

// ══════════════════════════ Bloque 4b/4c ══════════════════════════════

async function elegirIdiomaTranscripcion(videoId) {
  const res = await fetch(
    `https://www.youtube.com/api/timedtext?type=list&v=${videoId}`,
  );
  if (!res.ok) return null;
  const xml = await res.text();
  const langs = [...xml.matchAll(/lang_code="([^"]+)"/g)].map((m) => m[1]);
  if (langs.length === 0) return null;
  const prioridad = ["es", "es-419", "es-ES", "en"];
  for (const lang of prioridad) {
    if (langs.includes(lang)) return lang;
  }
  return langs[0];
}

function decodificarEntidadesHtml(s) {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n/g, " ");
}

async function obtenerTranscripcionYoutube(videoId, idioma) {
  try {
    const url = `https://www.youtube.com/api/timedtext?lang=${idioma}&v=${videoId}`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const xml = await res.text();
    const textos = [...xml.matchAll(/<text[^>]*>([\s\S]*?)<\/text>/g)].map(
      (m) => decodificarEntidadesHtml(m[1]),
    );
    const transcripcion = textos.join(" ").replace(/\s+/g, " ").trim();
    return transcripcion.length > 0 ? transcripcion : null;
  } catch (err) {
    logger.warn("No se pudo obtener transcripcion de YouTube", {
      videoId,
      err: String(err),
    });
    return null;
  }
}

async function extraerTextoPdf(url) {
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    const buffer = Buffer.from(await res.arrayBuffer());
    const data = await pdfParse(buffer);
    return data.text.replace(/\s+/g, " ").trim();
  } catch (err) {
    logger.warn("No se pudo extraer texto del PDF", {
      url,
      err: String(err),
    });
    return null;
  }
}

// Antes había un solo flag "contextoIaGenerado" que se marcaba true pase
// lo que pase (haya conseguido el transcript/PDF o no) — si el primer
// intento fallaba (video sin subtítulos todavía, timedtext caído, etc.)
// quedaba bloqueado para siempre, sin reintentar jamás. Ahora cada fuente
// (transcript, PDF) se rastrea por separado: si no se consiguió, se
// reintenta automáticamente pasadas REINTENTO_MS desde el último intento.
// Una vez conseguido, queda cacheado para siempre (no se vuelve a gastar
// cuota en algo que ya funcionó).
const REINTENTO_CONTEXTO_MS = 6 * 60 * 60 * 1000; // 6 horas
const GEMINI_CACHE_TTL_SEGUNDOS = 24 * 60 * 60; // 24 horas
const REINTENTO_CACHE_MS = 6 * 60 * 60 * 1000; // 6 horas (mismo patrón que transcript/PDF)

// Instrucción base del tutor, separada del contexto del tema (transcript +
// PDF), porque ahora el contexto va DENTRO del cache de Gemini y esta
// instrucción se manda junto con él al crear el cache — ya no se reenvía
// en cada mensaje del chat.
const SYSTEM_INSTRUCTION_BASE =
  "Eres AcademiBot, el tutor oficial de AcademiApp. Ayudas a " +
  "estudiantes que se preparan para ingresar a la universidad. " +
  "Responde basándote en el contenido de este tema (transcripción " +
  "del video y material de apoyo) que se te dio como contexto; si la " +
  "pregunta no se puede responder con ese contenido, dilo " +
  "honestamente en vez de inventar.\n\n" +
  "MÉTODO SOCRÁTICO: si el estudiante te pide resolver un ejercicio o " +
  "un problema paso a paso, NO des la respuesta final de inmediato. " +
  "Guíalo con una pregunta corta que lo haga pensar el siguiente " +
  "paso, dale una pista si se traba, y confirma cuando razone bien " +
  "antes de avanzar al siguiente paso. Si el estudiante insiste 2 o " +
  "más veces en que le des la respuesta directa, dásela sin más " +
  "resistencia — no lo hagas dar vueltas innecesariamente. Si la " +
  "pregunta es puramente conceptual o factual ('¿qué significa X?', " +
  "'¿cuál es la fórmula de Y?', '¿quién descubrió Z?'), respóndele " +
  "directo, sin rodeos — el método socrático es para razonar " +
  "ejercicios, no para trabar a alguien que solo pide una " +
  "definición.\n\n" +
  "IMPORTANTE — sobre tu acceso al contenido: si el estudiante te " +
  "pregunta si tienes acceso al video o al PDF de este tema, NO " +
  "respondas con la negación genérica de 'no tengo acceso a " +
  "archivos' que darías por defecto. Ya se te dio la transcripción " +
  "del video y/o el material del PDF como contexto: confirma que SÍ " +
  "los tienes y que los estás usando para responder.\n\n" +
  "Usa negritas con **texto** para conceptos clave. " +
  "Para matemáticas y física usa LaTeX: inline corto $formula$, " +
  "bloque largo $$formula$$. Sé motivador, breve y directo.";

function haceMasDe(timestamp, ms) {
  if (!timestamp) return true; // nunca se intentó -> "hace más de" cualquier cosa
  const millis = timestamp.toMillis ? timestamp.toMillis() : timestamp;
  return Date.now() - millis > ms;
}

// Crea (o recrea) el cache de contexto en Gemini para un tema: sube la
// transcripción + el PDF UNA sola vez y Google los guarda de su lado. En
// cada mensaje del chat, en vez de reenviar ese texto completo, solo se
// referencia el nombre del cache — se factura a una fracción del costo
// normal por token. Devuelve null si no hay suficiente contenido para que
// valga la pena cachear (Gemini exige un mínimo), o si la llamada falla;
// en ambos casos el llamador debe usar el modo de inyección directa como
// respaldo, para que el chat/quiz nunca se rompan por esto.
async function crearCacheGemini(cursoNombre, tema) {
  const contexto = [
    `Curso: ${cursoNombre || ""}`,
    `Tema: ${tema.titulo || ""}`,
    tema.transcripcion
      ? `Transcripción del video de este tema:\n${tema.transcripcion}`
      : "",
    tema.materialTexto
      ? `Material de apoyo (PDF) de este tema:\n${tema.materialTexto}`
      : "",
  ]
    .filter(Boolean)
    .join("\n\n");

  if (contexto.length < 4000) {
    // Muy poco contenido: Gemini puede rechazar el cache o no vale la
    // pena el overhead. Se sigue usando inyección directa para este tema.
    return null;
  }

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/cachedContents?key=${GEMINI_API_KEY.value()}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "models/gemini-2.5-flash",
          displayName: `tema-${(tema.titulo || "sin-titulo").slice(0, 60)}`,
          systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTION_BASE }] },
          contents: [{ role: "user", parts: [{ text: contexto }] }],
          ttl: `${GEMINI_CACHE_TTL_SEGUNDOS}s`,
        }),
      },
    );
    const data = await res.json();
    if (!res.ok) {
      logger.warn("No se pudo crear cache de Gemini para el tema", data);
      return null;
    }
    return { nombre: data.name, expira: data.expireTime };
  } catch (err) {
    logger.warn("Error creando cache de Gemini", { err: String(err) });
    return null;
  }
}

async function asegurarContextoTema(cursoId, temaId) {
  const temaRef = db
    .collection("cursos")
    .doc(cursoId)
    .collection("temas")
    .doc(temaId);
  const temaSnap = await temaRef.get();
  if (!temaSnap.exists) {
    throw new HttpsError("not-found", "Tema no encontrado.");
  }
  const temaPublico = temaSnap.data();

  const premiumRef = temaRef.collection("premium").doc("contenido");
  const premiumSnap = await premiumRef.get();
  let premiumData = premiumSnap.exists ? premiumSnap.data() : {};

  const updates = {};

  // --- Transcript del video ---
  const faltaTranscripcion = !premiumData.transcripcion;
  const debeReintentarTranscripcion = haceMasDe(
    premiumData.transcripcionIntentadaEn,
    REINTENTO_CONTEXTO_MS,
  );
  if (temaPublico.videoId && faltaTranscripcion && debeReintentarTranscripcion) {
    updates.transcripcionIntentadaEn =
      admin.firestore.FieldValue.serverTimestamp();
    const idioma = await elegirIdiomaTranscripcion(temaPublico.videoId);
    if (idioma) {
      const transcripcion = await obtenerTranscripcionYoutube(
        temaPublico.videoId,
        idioma,
      );
      if (transcripcion) {
        updates.transcripcion = transcripcion.slice(0, 20000);
      } else {
        logger.warn("Transcript de YouTube vacío/no disponible aún", {
          cursoId,
          temaId,
          videoId: temaPublico.videoId,
        });
      }
    } else {
      logger.warn("Video sin subtítulos disponibles en YouTube todavía", {
        cursoId,
        temaId,
        videoId: temaPublico.videoId,
      });
    }
  }

  // --- Material PDF ---
  const pdfUrl =
    temaPublico.pdfUrl ||
    (Array.isArray(temaPublico.materiales) && temaPublico.materiales[0]
      ? temaPublico.materiales[0].url
      : null);
  const faltaMaterial = !premiumData.materialTexto;
  const debeReintentarMaterial = haceMasDe(
    premiumData.materialIntentadoEn,
    REINTENTO_CONTEXTO_MS,
  );
  if (pdfUrl && faltaMaterial && debeReintentarMaterial) {
    updates.materialIntentadoEn = admin.firestore.FieldValue.serverTimestamp();
    const textoPdf = await extraerTextoPdf(pdfUrl);
    if (textoPdf) {
      updates.materialTexto = textoPdf.slice(0, 20000);
    } else {
      logger.warn("No se pudo extraer texto del PDF (se reintentará luego)", {
        cursoId,
        temaId,
        pdfUrl,
      });
    }
  }

  if (Object.keys(updates).length > 0) {
    await premiumRef.set(updates, { merge: true });
    premiumData = { ...premiumData, ...updates };
  }

  // --- Cache de contexto en Gemini (para no reenviar transcript/PDF en
  // cada mensaje del chat ni en cada generación de quiz) ---
  const hayContenido = !!(premiumData.transcripcion || premiumData.materialTexto);
  const cacheVencido =
    !premiumData.geminiCacheName ||
    !premiumData.geminiCacheExpira ||
    new Date(premiumData.geminiCacheExpira).getTime() < Date.now();
  const debeReintentarCache = haceMasDe(
    premiumData.geminiCacheIntentadoEn,
    REINTENTO_CACHE_MS,
  );

  if (hayContenido && cacheVencido && debeReintentarCache) {
    const cacheUpdates = {
      geminiCacheIntentadoEn: admin.firestore.FieldValue.serverTimestamp(),
    };
    const cursoSnap = await db.collection("cursos").doc(cursoId).get();
    const cache = await crearCacheGemini(
      (cursoSnap.data() || {}).nombre,
      { titulo: temaPublico.titulo, ...premiumData },
    );
    if (cache) {
      cacheUpdates.geminiCacheName = cache.nombre;
      cacheUpdates.geminiCacheExpira = cache.expira;
    }
    await premiumRef.set(cacheUpdates, { merge: true });
    premiumData = { ...premiumData, ...cacheUpdates };
  }

  return { titulo: temaPublico.titulo, ...premiumData };
}


exports.prepararContextoTema = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const { cursoId, temaId } = request.data || {};
    if (!cursoId || !temaId) {
      throw new HttpsError("invalid-argument", "Falta cursoId o temaId.");
    }
    const tema = await asegurarContextoTema(cursoId, temaId);
    return {
      ok: true,
      tieneTranscripcion: !!tema.transcripcion,
      tieneMaterial: !!tema.materialTexto,
    };
  },
);

exports.procesarPreguntaChatVideo = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = request.auth.uid;
    const userSnap = await db.collection("users").doc(uid).get();
    const plan = (userSnap.data() || {}).plan;
    if (plan !== "premium") {
      throw new HttpsError(
        "permission-denied",
        "El chat con tutor IA es una función Premium.",
      );
    }

    const { cursoId, temaId, mensaje, historial } = request.data || {};
    if (!cursoId || !temaId || !mensaje) {
      throw new HttpsError("invalid-argument", "Faltan datos del mensaje.");
    }

    const tema = await asegurarContextoTema(cursoId, temaId);
    const cursoSnap = await db.collection("cursos").doc(cursoId).get();
    const curso = cursoSnap.data() || {};

    const cacheDisponible =
      tema.geminiCacheName &&
      tema.geminiCacheExpira &&
      new Date(tema.geminiCacheExpira).getTime() > Date.now();

    const contents = [
      ...(Array.isArray(historial) ? historial : []).map((h) => ({
        role: h.isUser ? "user" : "model",
        parts: [{ text: h.text }],
      })),
      { role: "user", parts: [{ text: mensaje }] },
    ];

    // Cuerpo de la request a Gemini: si hay cache, se referencia por nombre
    // y NO se reenvía transcript/PDF/systemInstruction (ya están en el
    // cache, se factura a una fracción del costo normal). Si no hay cache
    // (contenido muy corto, o falló su creación), se cae al modo anterior:
    // reenviar todo el contexto en systemInstruction en cada mensaje.
    let requestBody;
    if (cacheDisponible) {
      requestBody = { contents, cachedContent: tema.geminiCacheName };
    } else {
      const contexto = [
        `Curso: ${curso.nombre || ""}`,
        `Tema: ${tema.titulo || ""}`,
        tema.transcripcion
          ? `Transcripción del video de este tema:\n${tema.transcripcion}`
          : "No hay transcripción disponible para este video todavía.",
        tema.materialTexto
          ? `Material de apoyo (PDF) de este tema:\n${tema.materialTexto}`
          : "",
      ]
        .filter(Boolean)
        .join("\n\n");
      requestBody = {
        contents,
        systemInstruction: {
          parts: [{ text: `${SYSTEM_INSTRUCTION_BASE}\n\n${contexto}` }],
        },
      };
    }

    try {
      const res = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/" +
          `gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY.value()}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(requestBody),
        },
      );
      const data = await res.json();
      if (!res.ok) {
        logger.error("Error de Gemini", data);
        throw new HttpsError(
          "internal",
          "No se pudo obtener respuesta del tutor IA.",
        );
      }
      const texto =
        data.candidates &&
        data.candidates[0] &&
        data.candidates[0].content &&
        data.candidates[0].content.parts &&
        data.candidates[0].content.parts[0]
          ? data.candidates[0].content.parts[0].text
          : "Lo siento, no pude procesar eso.";
      return { ok: true, respuesta: texto };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("Error llamando a Gemini", err);
      throw new HttpsError("internal", "No se pudo conectar con el tutor IA.");
    }
  },
);

// ══════════════════════════ Bloque 4c: quiz ═══════════════════════════

async function generarPreguntasNivel(contenidoTexto, tituloTema, nivel, cachedContentName) {
  const cantidad = 10;
  const descripcionNivel = {
    basico:
      "preguntas básicas de definición y reconocimiento directo del contenido",
    intermedio:
      "preguntas de aplicación que combinan 2 o más conceptos del tema",
    avanzado:
      "preguntas de análisis o resolución de problemas complejos, nivel " +
      "examen de admisión",
  }[nivel];

  const instruccionesFormato =
    "Responde SOLO con un array JSON (sin texto adicional, sin markdown), " +
    "con este formato exacto:\n" +
    '[{"pregunta": "...", "opciones": ["...", "...", "...", "..."], ' +
    '"respuestaCorrecta": 0, "explicacion": "..."}]\n' +
    '"respuestaCorrecta" es el índice (0 a 3) de la opción correcta ' +
    'dentro de "opciones". ' +
    "Si el tema requiere notación matemática o física (fórmulas, " +
    "ecuaciones, exponentes, fracciones, símbolos), escríbela en LaTeX " +
    "envuelta en signos de dólar simple, por ejemplo $x^2 + 3x = 0$ — " +
    "tanto en \"pregunta\" como en \"opciones\" y \"explicacion\". Si el " +
    "tema no es de matemáticas/física, escribe todo en texto normal sin " +
    "usar signos de dólar.";

  // Con cache: el contenido del tema ya está subido a Gemini, así que el
  // prompt solo pide generar las preguntas sobre "el contenido dado"
  // (referenciado por el cache), sin reenviar contenidoTexto de nuevo.
  // Sin cache (tema con poco contenido, o cache no disponible): se cae al
  // modo anterior, con contenidoTexto embebido directo en el prompt.
  let requestBody;
  if (cachedContentName) {
    const prompt =
      `Genera exactamente ${cantidad} preguntas de opción múltiple de ` +
      `nivel ${nivel} (${descripcionNivel}) sobre el tema "${tituloTema}", ` +
      "basadas ÚNICAMENTE en el contenido del tema que se te dio como " +
      `contexto.\n\n${instruccionesFormato}`;
    requestBody = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      cachedContent: cachedContentName,
      generationConfig: { responseMimeType: "application/json" },
    };
  } else {
    const prompt =
      `Genera exactamente ${cantidad} preguntas de opción múltiple de nivel ` +
      `${nivel} (${descripcionNivel}) sobre el tema "${tituloTema}", basadas ` +
      `ÚNICAMENTE en el siguiente contenido:\n\n${contenidoTexto}\n\n` +
      instruccionesFormato;
    requestBody = {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" },
    };
  }

  const res = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/" +
      `gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY.value()}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
    },
  );
  const data = await res.json();
  if (!res.ok) {
    logger.error("Error de Gemini generando quiz", data);
    throw new HttpsError("internal", "No se pudo generar el quiz.");
  }
  const texto =
    data.candidates &&
    data.candidates[0] &&
    data.candidates[0].content &&
    data.candidates[0].content.parts &&
    data.candidates[0].content.parts[0]
      ? data.candidates[0].content.parts[0].text
      : "[]";

  let preguntas;
  try {
    preguntas = JSON.parse(texto);
  } catch (err) {
    logger.error("No se pudo parsear el JSON del quiz", {
      texto,
      err: String(err),
    });
    throw new HttpsError(
      "internal",
      "El tutor IA devolvió un formato inválido.",
    );
  }

  if (!Array.isArray(preguntas) || preguntas.length === 0) {
    throw new HttpsError("internal", "No se generaron preguntas válidas.");
  }

  return preguntas;
}

// ══════════════════ Motor de calendario / avance secuencial ═══════════

function fechaLimaYMD(date) {
  const limaMs = date.getTime() - 5 * 60 * 60 * 1000;
  const d = new Date(limaMs);
  return {
    y: d.getUTCFullYear(),
    m: d.getUTCMonth(),
    day: d.getUTCDate(),
    dow: d.getUTCDay(),
  };
}

function diaLectivoActual(fechaInicioTimestamp) {
  const inicio = fechaInicioTimestamp.toDate
    ? fechaInicioTimestamp.toDate()
    : new Date(fechaInicioTimestamp);
  const ahora = new Date();
  const msPorDia = 24 * 60 * 60 * 1000;

  const iniYmd = fechaLimaYMD(inicio);
  const finYmd = fechaLimaYMD(ahora);
  let cursorMs = Date.UTC(iniYmd.y, iniYmd.m, iniYmd.day);
  const finMs = Date.UTC(finYmd.y, finYmd.m, finYmd.day);

  let contador = 0;
  while (cursorMs <= finMs) {
    const dow = new Date(cursorMs).getUTCDay();
    if (dow !== 0) contador++;
    cursorMs += msPorDia;
  }
  return contador;
}

async function construirCalendarioGlobal() {
  const CURSOS_POR_DIA = 3;

  const cursosSnap = await db.collection("cursos").orderBy("orden").get();
  const cursos = cursosSnap.docs;

  const temasPorCurso = [];
  for (const cursoDoc of cursos) {
    const temasSnap = await cursoDoc.ref
      .collection("temas")
      .orderBy("orden")
      .get();
    temasPorCurso.push(temasSnap.docs.map((d) => d.id));
  }

  const totalCursos = cursos.length;
  const diasPorRonda = Math.ceil(totalCursos / CURSOS_POR_DIA);
  const maxTemas = temasPorCurso.reduce(
    (max, temas) => Math.max(max, temas.length),
    0,
  );

  const calendario = {};

  for (let ronda = 0; ronda < maxTemas; ronda++) {
    for (let c = 0; c < totalCursos; c++) {
      const temaId = temasPorCurso[c][ronda];
      if (!temaId) continue;

      const diaDentroDeRonda = Math.floor(c / CURSOS_POR_DIA) + 1;
      const diaAsignado = ronda * diasPorRonda + diaDentroDeRonda;

      const cursoId = cursos[c].id;
      if (!calendario[cursoId]) calendario[cursoId] = {};
      calendario[cursoId][temaId] = diaAsignado;
    }
  }

  return calendario;
}

exports.obtenerEstadoCalendarioTema = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() || {};

  if (userData.plan !== "premium") {
    return { ok: true, habilitadoHoy: false, motivo: "no-premium" };
  }
  if (!userData.rutaIniciadaEn) {
    return { ok: true, habilitadoHoy: false, motivo: "sin-ruta" };
  }

  const { cursoId, temaId } = request.data || {};
  if (!cursoId || !temaId) {
    throw new HttpsError("invalid-argument", "Falta cursoId o temaId.");
  }

  const calendario = await construirCalendarioGlobal();
  const diaAsignado = calendario[cursoId] && calendario[cursoId][temaId];
  if (!diaAsignado) {
    return { ok: true, habilitadoHoy: false, motivo: "sin-programar" };
  }

  const diaActual = diaLectivoActual(userData.rutaIniciadaEn);

  return {
    ok: true,
    habilitadoHoy: diaActual === diaAsignado,
    diaAsignado,
    diaActual,
  };
});

// La generación con IA ya NO ocurre cuando el alumno abre el quiz — la
// dispara un admin desde el panel de control (generarQuizAdmin) y queda
// en un campo "_borrador" hasta que el mismo admin la aprueba
// (aprobarQuizAdmin, o directo desde el panel vía Firestore ya que las
// reglas le dan permiso de escritura ahí). Este endpoint es de solo
// lectura: si no hay nada aprobado todavía, avisa en vez de generar al
// vuelo — así nunca le llega a un alumno una pregunta sin revisar.
exports.obtenerQuizTema = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  if ((userSnap.data() || {}).plan !== "premium") {
    throw new HttpsError(
      "permission-denied",
      "El quiz por nivel es una función Premium.",
    );
  }

  const { cursoId, temaId, nivel } = request.data || {};
  const nivelesValidos = ["basico", "intermedio", "avanzado"];
  if (!cursoId || !temaId || !nivelesValidos.includes(nivel)) {
    throw new HttpsError("invalid-argument", "Datos inválidos para el quiz.");
  }

  const userData = userSnap.data() || {};
  if (!userData.rutaIniciadaEn) {
    throw new HttpsError(
      "failed-precondition",
      "Tu ruta de estudio todavía no se ha iniciado.",
    );
  }
  const calendario = await construirCalendarioGlobal();
  const diaAsignado = calendario[cursoId] && calendario[cursoId][temaId];
  const diaActual = diaLectivoActual(userData.rutaIniciadaEn);
  if (!diaAsignado || diaActual !== diaAsignado) {
    throw new HttpsError(
      "failed-precondition",
      "El quiz de este tema no está habilitado hoy. Este video queda " +
        "disponible solo para repaso.",
    );
  }

  const premiumRef = db
    .collection("cursos")
    .doc(cursoId)
    .collection("temas")
    .doc(temaId)
    .collection("premium")
    .doc("contenido");
  const premiumSnap = await premiumRef.get();
  const campo = `quiz_${nivel}`;
  const preguntas = premiumSnap.exists
    ? premiumSnap.data()[campo]
    : null;

  if (!Array.isArray(preguntas) || preguntas.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Este quiz todavía no está disponible — vuelve a intentarlo más " +
        "tarde.",
    );
  }

  return { ok: true, preguntas };
});

// Solo admin: dispara la generación con Gemini y la deja en un campo
// "_borrador" (NO visible para alumnos todavía). El admin la revisa en
// el panel y recién ahí la aprueba/edita.
exports.generarQuizAdmin = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    if (!request.auth || request.auth.token.admin !== true) {
      throw new HttpsError(
        "permission-denied",
        "Solo un administrador puede generar el quiz.",
      );
    }

    const { cursoId, temaId, nivel } = request.data || {};
    const nivelesValidos = ["basico", "intermedio", "avanzado"];
    if (!cursoId || !temaId || !nivelesValidos.includes(nivel)) {
      throw new HttpsError("invalid-argument", "Datos inválidos.");
    }

    const contenido = await asegurarContextoTema(cursoId, temaId);
    const contextoTexto = [
      contenido.transcripcion
        ? `Transcripción del video:\n${contenido.transcripcion}`
        : "",
      contenido.materialTexto
        ? `Material de apoyo (PDF):\n${contenido.materialTexto}`
        : "",
    ]
      .filter(Boolean)
      .join("\n\n");

    if (!contextoTexto) {
      throw new HttpsError(
        "failed-precondition",
        "Este tema todavía no tiene transcripción ni material — " +
          "agrégalos primero desde 'Cursos y Temas' (sube el video/PDF, " +
          "espera unos segundos, y vuelve a intentar).",
      );
    }

    const preguntas = await generarPreguntasNivel(
      contextoTexto,
      contenido.titulo,
      nivel,
      contenido.geminiCacheName &&
        contenido.geminiCacheExpira &&
        new Date(contenido.geminiCacheExpira).getTime() > Date.now()
        ? contenido.geminiCacheName
        : null,
    );

    const premiumRef = db
      .collection("cursos")
      .doc(cursoId)
      .collection("temas")
      .doc(temaId)
      .collection("premium")
      .doc("contenido");
    await premiumRef.set(
      { [`quiz_${nivel}_borrador`]: preguntas },
      { merge: true },
    );

    return { ok: true, preguntas };
  },
);

// Progreso del alumno por curso: cuántos temas tiene disponibles hasta
// hoy según SU calendario individual (no cambia nada del ritmo por
// alumno) y cuántos quizzes básicos ya aprobó. Reemplaza la idea de
// mostrar un número de "semana" abstracto por algo concreto y accionable.
exports.obtenerProgresoCursos = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() || {};
  const diaActual = userData.rutaIniciadaEn
    ? diaLectivoActual(userData.rutaIniciadaEn)
    : 0;

  const calendario = await construirCalendarioGlobal();

  const [cursosSnap, progresoSnap] = await Promise.all([
    db.collection("cursos").orderBy("orden").get(),
    db.collection("users").doc(uid).collection("progresoQuiz").get(),
  ]);

  const aprobadosBasico = new Set();
  progresoSnap.forEach((d) => {
    const data = d.data();
    if (data.basico && data.basico.aprobado) aprobadosBasico.add(d.id);
  });

  const resultado = {};
  const temasHoy = [];
  for (const cursoDoc of cursosSnap.docs) {
    const cursoId = cursoDoc.id;
    const cursoData = cursoDoc.data();
    const temasSnap = await db
      .collection("cursos")
      .doc(cursoId)
      .collection("temas")
      .orderBy("orden")
      .get();

    let temasTotal = 0;
    let temasDisponibles = 0;
    let quizzesAprobados = 0;
    const temas = {};

    for (const temaDoc of temasSnap.docs) {
      const temaId = temaDoc.id;
      temasTotal++;
      const diaAsignado = calendario[cursoId] && calendario[cursoId][temaId];
      const disponible = !!diaAsignado && diaActual >= diaAsignado;
      const aprobado = aprobadosBasico.has(`${cursoId}_${temaId}`);
      if (disponible) temasDisponibles++;
      if (disponible && aprobado) quizzesAprobados++;
      temas[temaId] = { disponible, aprobado };

      if (diaAsignado === diaActual) {
        temasHoy.push({
          cursoId,
          temaId,
          nombreCurso: cursoData.nombre || "",
          tituloTema: temaDoc.data().titulo || "",
        });
      }
    }

    resultado[cursoId] = {
      nombre: cursoData.nombre || "",
      icono: cursoData.icono || "📚",
      temasTotal,
      temasDisponibles,
      quizzesAprobados,
      temas,
    };
  }

  return { ok: true, diaActual, temasHoy, cursos: resultado };
});

exports.enviarResultadoQuiz = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const uid = request.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  if ((userSnap.data() || {}).plan !== "premium") {
    throw new HttpsError(
      "permission-denied",
      "El quiz por nivel es una función Premium.",
    );
  }

  const { cursoId, temaId, nivel, respuestas } = request.data || {};
  const nivelesValidos = ["basico", "intermedio", "avanzado"];
  if (
    !cursoId ||
    !temaId ||
    !nivelesValidos.includes(nivel) ||
    !Array.isArray(respuestas)
  ) {
    throw new HttpsError("invalid-argument", "Datos inválidos.");
  }

  // Fix (T1.6/R-seguridad): antes se recibía "aciertos"/"total" ya
  // calculados por el cliente y se guardaban tal cual — cualquiera podía
  // llamar a esta función directo y marcarse "aprobado" sin responder
  // nada. Ahora se recalifica en servidor, releyendo las mismas preguntas
  // que sirvió obtenerQuizTema (mismo documento, misma fuente).
  const premiumRefCalificar = db
    .collection("cursos")
    .doc(cursoId)
    .collection("temas")
    .doc(temaId)
    .collection("premium")
    .doc("contenido");
  const premiumSnapCalificar = await premiumRefCalificar.get();
  const preguntasReales = premiumSnapCalificar.exists
    ? premiumSnapCalificar.data()[`quiz_${nivel}`]
    : null;
  if (!Array.isArray(preguntasReales) || preguntasReales.length === 0) {
    throw new HttpsError("failed-precondition", "Este quiz ya no está disponible.");
  }

  let aciertos = 0;
  preguntasReales.forEach((p, i) => {
    if (respuestas[i] === p.respuestaCorrecta) aciertos++;
  });
  const total = preguntasReales.length;

  const aprobado = aciertos >= total;

  const progresoRef = db
    .collection("users")
    .doc(uid)
    .collection("progresoQuiz")
    .doc(`${cursoId}_${temaId}`);

  const progresoSnap = await progresoRef.get();
  const progresoActual = progresoSnap.exists ? progresoSnap.data() : {};
  const nivelActual = progresoActual[nivel] || {
    intentos: 0,
    mejorPuntaje: 0,
    aprobado: false,
  };

  const nuevoNivel = {
    intentos: (nivelActual.intentos || 0) + 1,
    mejorPuntaje: Math.max(nivelActual.mejorPuntaje || 0, aciertos),
    aprobado: nivelActual.aprobado || aprobado,
    ultimaActualizacion: admin.firestore.FieldValue.serverTimestamp(),
  };

  let nombreCurso = progresoActual.nombreCurso;
  let tituloTema = progresoActual.tituloTema;
  if (!nombreCurso || !tituloTema) {
    const [cursoSnap, temaSnap] = await Promise.all([
      db.collection("cursos").doc(cursoId).get(),
      db
        .collection("cursos")
        .doc(cursoId)
        .collection("temas")
        .doc(temaId)
        .get(),
    ]);
    nombreCurso = cursoSnap.exists ? cursoSnap.data().nombre : "";
    tituloTema = temaSnap.exists ? temaSnap.data().titulo : "";
  }

  await progresoRef.set(
    { cursoId, temaId, nombreCurso, tituloTema, [nivel]: nuevoNivel },
    { merge: true },
  );

  return {
    ok: true,
    aprobado,
    progreso: { ...progresoActual, [nivel]: nuevoNivel },
  };
});

// ══════════════════════ Bloque 5: exámenes ═════════════════════════════

// Fix (T1.6/R-seguridad): el modo "admisión" de examen_sesion_page.dart
// está diseñado para simular un examen real y NO revelar respuestas hasta
// el final (a diferencia del modo "práctica", que sí las revela apenas el
// alumno elige). Antes de este fix, obtenerExamen devolvía el examen
// completo con respuestaCorrecta/explicacion incluidas SIEMPRE, sin
// distinguir categoría — rompiendo esa garantía para "admisión" (se podía
// ver la respuesta inspeccionando la red antes de responder). En
// "práctica" no se tocan estos campos: ahí exponerlos es intencional.
function ocultarRespuestasSiAdmision(examen) {
  if (examen.categoria !== "admision") return examen;
  const preguntas = (examen.preguntas || []).map((p) => {
    const { respuestaCorrecta, explicacion, ...resto } = p;
    return resto;
  });
  return { ...examen, preguntas };
}

function esMismoDiaLima(fecha1, fecha2) {
  const d1 = fecha1.toDate ? fecha1.toDate() : new Date(fecha1);
  const d2 = fecha2.toDate ? fecha2.toDate() : new Date(fecha2);
  const y1 = fechaLimaYMD(d1);
  const y2 = fechaLimaYMD(d2);
  return y1.y === y2.y && y1.m === y2.m && y1.day === y2.day;
}

exports.obtenerExamen = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const { examenId } = request.data || {};
  if (!examenId) {
    throw new HttpsError("invalid-argument", "Falta examenId.");
  }

  const examenSnap = await db.collection("examenes").doc(examenId).get();
  if (!examenSnap.exists) {
    throw new HttpsError("not-found", "Examen no encontrado.");
  }
  const examen = examenSnap.data();

  const uid = request.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() || {};
  const esPremium = userData.plan === "premium";

  if (examen.categoria === "admision" && !esPremium) {
    throw new HttpsError(
      "permission-denied",
      "Los exámenes tipo admisión son una función Premium.",
    );
  }

  if (!esPremium && examen.categoria !== "admision") {
    const ultimo = userData.ultimoExamenCompletado;
    if (
      ultimo &&
      ultimo.examenId !== examenId &&
      ultimo.fecha &&
      esMismoDiaLima(ultimo.fecha, new Date())
    ) {
      throw new HttpsError(
        "resource-exhausted",
        "Ya completaste tu examen gratis de hoy. Vuelve mañana o " +
          "actualiza a Premium para no tener límite.",
      );
    }
  }

  return {
    ok: true,
    examen: ocultarRespuestasSiAdmision({ id: examenSnap.id, ...examen }),
  };
});

exports.enviarResultadoExamen = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const uid = request.auth.uid;
  const { examenId, respuestas } = request.data || {};
  if (!examenId || !Array.isArray(respuestas)) {
    throw new HttpsError("invalid-argument", "Datos inválidos.");
  }

  const examenSnap = await db.collection("examenes").doc(examenId).get();
  if (!examenSnap.exists) {
    throw new HttpsError("not-found", "Examen no encontrado.");
  }
  const examen = examenSnap.data();
  const preguntas = examen.preguntas || [];

  let aciertos = 0;
  preguntas.forEach((p, i) => {
    if (respuestas[i] === p.respuestaCorrecta) aciertos++;
  });
  const total = preguntas.length;

  await db
    .collection("users")
    .doc(uid)
    .collection("examenesResueltos")
    .doc(examenId)
    .set(
      {
        titulo: examen.titulo || "",
        categoria: examen.categoria || "",
        aciertos,
        total,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() || {};
  if (userData.plan !== "premium" && examen.categoria !== "admision") {
    await db
      .collection("users")
      .doc(uid)
      .set(
        {
          ultimoExamenCompletado: {
            examenId,
            fecha: admin.firestore.Timestamp.now(),
          },
        },
        { merge: true },
      );
  }

  return { ok: true, aciertos, total };
});

// ══════════════════════ Bloque 9: notificaciones ═══════════════════════

exports.notificarAdminNuevoPago = onDocumentCreated(
  "pagos/{pagoId}",
  async (event) => {
    const pago = event.data.data();
    if (!pago || pago.estado !== "pendiente") return;

    const adminsSnap = await db
      .collection("users")
      .where("esAdmin", "==", true)
      .get();
    if (adminsSnap.empty) return;

    await Promise.all(
      adminsSnap.docs.map((d) =>
        enviarNotificacionAUsuario(d.id, {
          title: "Nuevo pago Yape pendiente",
          body: `S/ ${pago.monto} por revisar en el panel de administración.`,
          data: { tipo: "pago_pendiente" },
        }),
      ),
    );
  },
);

exports.notificarContenidoDiario = onSchedule(
  { schedule: "every day 07:00", timeZone: "America/Lima" },
  async () => {
    const usersSnap = await db
      .collection("users")
      .where("plan", "==", "premium")
      .get();
    if (usersSnap.empty) return;

    const calendario = await construirCalendarioGlobal();

    // Índice inverso día -> [{cursoId, temaId}], para no recorrer todo
    // el calendario por cada usuario en el loop de abajo.
    const temasPorDia = {};
    for (const cursoId in calendario) {
      for (const temaId in calendario[cursoId]) {
        const dia = calendario[cursoId][temaId];
        if (!temasPorDia[dia]) temasPorDia[dia] = [];
        temasPorDia[dia].push({ cursoId, temaId });
      }
    }

    // Títulos de los temas de "ayer" de cada usuario, resueltos una sola
    // vez (no por usuario) para armar el mensaje de refuerzo sin leer los
    // mismos documentos de tema una y otra vez.
    const diasAyerUnicos = [
      ...new Set(
        usersSnap.docs
          .map((d) => d.data().rutaIniciadaEn)
          .filter(Boolean)
          .map((ts) => diaLectivoActual(ts) - 1)
          .filter((dia) => dia >= 1),
      ),
    ];
    const titulosPorTema = {};
    for (const dia of diasAyerUnicos) {
      for (const { cursoId, temaId } of temasPorDia[dia] || []) {
        const key = `${cursoId}_${temaId}`;
        if (titulosPorTema[key]) continue;
        const temaSnap = await db
          .collection("cursos")
          .doc(cursoId)
          .collection("temas")
          .doc(temaId)
          .get();
        titulosPorTema[key] = temaSnap.exists
          ? temaSnap.data().titulo
          : "un tema";
      }
    }

    for (const userDoc of usersSnap.docs) {
      const userData = userDoc.data();
      if (!userData.rutaIniciadaEn) continue;

      const diaActual = diaLectivoActual(userData.rutaIniciadaEn);
      let temasHoy = 0;
      for (const cursoId in calendario) {
        for (const temaId in calendario[cursoId]) {
          if (calendario[cursoId][temaId] === diaActual) temasHoy++;
        }
      }
      if (temasHoy > 0) {
        await enviarNotificacionAUsuario(userDoc.id, {
          title: "📚 Hoy tienes contenido nuevo",
          body:
            `${temasHoy} tema${temasHoy > 1 ? "s" : ""} esperándote. ` +
            "¡No pierdas tu racha!",
          data: { tipo: "contenido_hoy" },
        });
      }

      // --- Señal de refuerzo (NO bloqueante): si el nivel básico de algún
      // tema de ayer todavía no fue aprobado, se lo recordamos aparte. El
      // alumno puede avanzar igual al contenido de hoy — esto es solo un
      // aviso, el calendario sigue corriendo para que nadie se quede sin
      // ver el temario completo antes del examen.
      const temasAyer = temasPorDia[diaActual - 1] || [];
      if (temasAyer.length > 0) {
        const progresoRefs = temasAyer.map(({ cursoId, temaId }) =>
          db
            .collection("users")
            .doc(userDoc.id)
            .collection("progresoQuiz")
            .doc(`${cursoId}_${temaId}`),
        );
        const progresoSnaps = await db.getAll(...progresoRefs);

        const pendientes = temasAyer.filter((_, i) => {
          const data = progresoSnaps[i].exists
            ? progresoSnaps[i].data()
            : null;
          return !(data && data.basico && data.basico.aprobado);
        });

        if (pendientes.length > 0) {
          const nombres = pendientes
            .map(
              ({ cursoId, temaId }) => titulosPorTema[`${cursoId}_${temaId}`],
            )
            .filter(Boolean);
          const detalle =
            nombres.length === 1 ? nombres[0] : `${nombres.length} temas de ayer`;
          await enviarNotificacionAUsuario(userDoc.id, {
            title: "📌 Antes de seguir, repasa esto",
            body:
              `Aún no apruebas el nivel básico de ${detalle}. Un repaso ` +
              "rápido te ayudará con lo nuevo de hoy.",
            data: { tipo: "refuerzo_pendiente" },
          });
        }
      }
    }
  },
);
