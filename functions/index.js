const { setGlobalOptions } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const axios = require("axios");

initializeApp();
setGlobalOptions({ maxInstances: 10 });

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// ── Banco de frases (mismo que la app) ───────────────────────────────────────
const FRASES = [
  {id:1,  frase:'Mereces sentirte bien.',                                              area:'identidad'},
  {id:2,  frase:'Eres un museo de todo lo que has amado.',                             area:'identidad'},
  {id:3,  frase:'La única forma es a través.',                                         area:'cambio'},
  {id:4,  frase:'El caos puede ser excelente.',                                        area:'cambio'},
  {id:5,  frase:'Ser vulnerable es lo más valiente que puedes hacer.',                 area:'identidad'},
  {id:6,  frase:'A partir de hoy, cada momento con tus amigos es sagrado.',            area:'vínculos'},
  {id:7,  frase:'Memento mori.',                                                       area:'tiempo'},
  {id:8,  frase:'Carpe diem.',                                                         area:'tiempo'},
  {id:9,  frase:'Déjalo ir.',                                                          area:'cambio'},
  {id:10, frase:'No te ahogues en tu propio amor.',                                    area:'amor'},
  {id:11, frase:'Confía en que tu corazón te ayudará a encontrar el amor de nuevo.',   area:'amor'},
  {id:12, frase:'No hay un mañana garantizado.',                                       area:'tiempo'},
  {id:13, frase:'Alguien piensa seguido en ti.',                                       area:'vínculos'},
  {id:14, frase:'La belleza en tu corazón te traerá cosas bellas.',                    area:'identidad'},
  {id:15, frase:'No tienes que estar de acuerdo con todo esto.',                       area:'identidad'},
  {id:16, frase:'Puedes ser fuerte y amable al mismo tiempo.',                         area:'identidad'},
  {id:17, frase:'El descanso también es productivo.',                                  area:'cuerpo'},
  {id:18, frase:'No todos los silencios necesitan llenarse.',                          area:'soledad'},
  {id:19, frase:'Extrañar es una forma de amar.',                                      area:'duelo'},
  {id:20, frase:'Tu ritmo no está roto.',                                              area:'identidad'},
  {id:21, frase:'Hay cosas que solo el tiempo puede decir.',                           area:'tiempo'},
  {id:22, frase:'No tienes que ganarte tu propio espacio.',                            area:'identidad'},
  {id:23, frase:'El miedo y el deseo suelen ser la misma cosa.',                       area:'miedo'},
  {id:24, frase:'Alguien guarda una foto tuya con cariño.',                            area:'vínculos'},
  {id:25, frase:'No toda herida necesita explicación.',                                area:'duelo'},
  {id:26, frase:'Puedes empezar de nuevo sin borrarte.',                               area:'cambio'},
  {id:27, frase:'Lo que evitas también te define.',                                    area:'identidad'},
  {id:28, frase:'Hay amor que todavía no has conocido.',                               area:'amor'},
  {id:29, frase:'No todo lo que se fue era tuyo.',                                     area:'duelo'},
  {id:30, frase:'Tus contradicciones también son válidas.',                            area:'identidad'},
  {id:31, frase:'El cuerpo sabe antes que la mente.',                                  area:'cuerpo'},
  {id:32, frase:'Mereces cosas que aún no sabes pedir.',                               area:'identidad'},
  {id:33, frase:'Algunos capítulos no tienen cierre y está bien.',                     area:'duelo'},
  {id:34, frase:'No tienes que entenderlo todo para seguir.',                          area:'cambio'},
  {id:35, frase:'La soledad a veces es un regalo que no pediste.',                     area:'soledad'},
  {id:36, frase:'Estás más cerca de lo que crees.',                                    area:'propósito'},
  {id:37, frase:'No todo amor que duele está mal.',                                    area:'amor'},
  {id:38, frase:'Amar sin perder es el verdadero reto.',                               area:'amor'},
  {id:39, frase:'El amor que buscas también te busca.',                                area:'amor'},
  {id:40, frase:'No confundas intensidad con profundidad.',                            area:'amor'},
  {id:50, frase:'Hay personas que llegan justo a tiempo.',                             area:'vínculos'},
  {id:57, frase:'El esfuerzo silencioso también cuenta.',                              area:'trabajo'},
  {id:59, frase:'Descansar no es rendirse.',                                           area:'trabajo'},
  {id:77, frase:'Tu cuerpo te ha traído hasta aquí.',                                  area:'cuerpo'},
  {id:97, frase:'La abundancia empieza por creer que la mereces.',                     area:'dinero'},
  {id:117,frase:'No tienes que ser consistente para ser auténtico.',                   area:'identidad'},
  {id:137,frase:'No todo final es una pérdida.',                                       area:'cambio'},
  {id:138,frase:'El cambio que temes ya está en camino.',                              area:'cambio'},
  {id:140,frase:'Soltar es a veces el acto más valiente.',                             area:'cambio'},
];

function seleccionarFrase(cola) {
  if (!cola || cola.length === 0) {
    // Cola vacía: selección aleatoria
    return FRASES[Math.floor(Math.random() * FRASES.length)];
  }
  const id = cola[0];
  return FRASES.find((f) => f.id === id) ?? FRASES[Math.floor(Math.random() * FRASES.length)];
}

async function enviarATodos(tokens, notification, data) {
  if (!tokens || tokens.length === 0) return;
  const mensajes = tokens.map((token) => ({ token, notification, data }));
  const resultado = await getMessaging().sendEach(mensajes);
  return resultado;
}

async function llamarClaude(prompt, apiKey, maxTokens = 200) {
  const response = await axios.post(
    "https://api.anthropic.com/v1/messages",
    {
      model: "claude-haiku-4-5-20251001",
      max_tokens: maxTokens,
      messages: [{ role: "user", content: prompt }],
    },
    {
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
    }
  );
  return response.data.content[0].text;
}

async function generarLecturaUsuario(nombre, signoSolar, signoLunar, ascendente, fraseBase, apiKey) {
  const aperturas = ["Estás","Tiendes a","Hoy","Ese","Lo que sientes","Lo que buscas",
    "Tu cuerpo","Hay una parte de ti que","Te pesa","Ya lo sabes","Llevas","Algo en ti","Sigues"];
  const apertura = aperturas[Math.floor(Math.random() * aperturas.length)];

  const prompt = `Eres la voz de una app de astrología.

Frase base: "${fraseBase}"

Escribe 1-2 oraciones que expandan esa frase. Habla en imperativo directo ("acepta", "mira", "suelta"), no en segunda persona descriptiva.

Reglas:
- No menciones signos zodiacales ni planetas
- Usa lenguaje general, nunca asumas el contexto específico del usuario
- Sin guiones (— o -)
- PROHIBIDO usar listas o enumeraciones
- No repitas palabras clave de la frase base
- Empieza con: "${apertura}"

Responde SOLO con JSON: {"frase": "...", "parrafo": "..."}`;

  const texto = await llamarClaude(prompt, apiKey);
  try {
    const json = JSON.parse(texto.match(/\{[\s\S]*\}/)?.[0] ?? "{}");
    return { frase: json.frase ?? fraseBase, parrafo: json.parrafo ?? "" };
  } catch {
    return { frase: fraseBase, parrafo: "" };
  }
}

// ── Paso 1: Genera lecturas a las 5am y asigna hora aleatoria de envío ────────
exports.generarLecturasDiarias = onSchedule(
  {
    schedule: "0 5 * * *",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 540,
  },
  async () => {
    const db = getFirestore();
    const apiKey = ANTHROPIC_API_KEY.value();
    const hoy = new Date();
    const fechaKey = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, "0")}-${String(hoy.getDate()).padStart(2, "0")}`;

    const usuariosSnap = await db.collection("usuarios").get();

    for (const userDoc of usuariosSnap.docs) {
      try {
        const uid = userDoc.id;
        const datos = userDoc.data();
        if (!datos?.fcmTokens?.length && !datos?.fcmToken) continue;

        const lecturaRef = db.collection("usuarios").doc(uid).collection("lecturas").doc(fechaKey);
        const lecturaSnap = await lecturaRef.get();

        let fraseBase;

        if (lecturaSnap.exists && lecturaSnap.data()?.fraseBase) {
          fraseBase = lecturaSnap.data().fraseBase;
        } else {
          const cola = Array.isArray(datos?.frasesQueue) ? [...datos.frasesQueue] : [];
          const fraseObj = seleccionarFrase(cola);
          fraseBase = fraseObj.frase;
          await db.collection("usuarios").doc(uid).update({ frasesQueue: cola.slice(1) });

          const resultado = await generarLecturaUsuario(
            datos?.nombre ?? "",
            datos?.signoSolar ?? "",
            datos?.signoLunar ?? "",
            datos?.ascendente ?? "",
            fraseBase,
            apiKey
          );
          await lecturaRef.set({ texto: JSON.stringify(resultado), fraseBase, areaFrase: fraseObj.area });
        }

        // Hora aleatoria entre 8am y 9pm CDMX = horas 8-21
        const horaEnvio = 8 + Math.floor(Math.random() * 14); // 8 a 21
        await db.collection("notificacionesPendientes").doc(uid).set({
          uid,
          fechaKey,
          fraseBase,
          horaEnvio,
          enviado: false,
        });
      } catch (e) {
        console.error(`Error generando lectura para ${userDoc.id}:`, e.message);
      }
    }
  }
);

// ── Paso 2: Cada hora revisa quién debe recibir su notificación ───────────────
exports.enviarNotificacionesPendientes = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    timeoutSeconds: 120,
  },
  async () => {
    const db = getFirestore();
    const ahoraHora = parseInt(
      new Date().toLocaleString("en-US", { timeZone: "America/Mexico_City", hour: "numeric", hour12: false })
    );

    const pendientesSnap = await db.collection("notificacionesPendientes")
      .where("enviado", "==", false)
      .where("horaEnvio", "==", ahoraHora)
      .get();

    for (const doc of pendientesSnap.docs) {
      try {
        const { uid, fraseBase, fechaKey } = doc.data();
        const userDoc = await db.collection("usuarios").doc(uid).get();
        const userData = userDoc.data();
        const tokens = userData?.fcmTokens ?? (userData?.fcmToken ? [userData.fcmToken] : []);
        if (!tokens.length) continue;

        await enviarATodos(
          tokens,
          { title: "tus astros de hoy", body: fraseBase },
          { tipo: "lectura_diaria", fecha: fechaKey }
        );

        await doc.ref.update({ enviado: true });
      } catch (e) {
        console.error(`Error enviando notificación a ${doc.data().uid}:`, e.message);
      }
    }
  }
);

// ── Notificación de carta Venus ───────────────────────────────────────────────
exports.notificarCarta = onDocumentCreated(
  "venus_cartas/{uid}/cartas/{cartaId}",
  async (event) => {
    const uid = event.params.uid;
    const carta = event.data.data();
    if (!carta) return;

    const db = getFirestore();
    const userDoc = await db.collection("usuarios").doc(uid).get();
    const userData = userDoc.data();
    const tokens = userData?.fcmTokens ?? (userData?.fcmToken ? [userData.fcmToken] : []);
    if (!tokens.length) return;

    const nombreRemitente = (carta.de ?? "Tu pareja").split(" ")[0];

    await enviarATodos(
      tokens,
      { title: "venus", body: `${nombreRemitente} te ha enviado una carta de amor 💌` },
      { tipo: "venus" }
    );
  }
);

// ── Notificación de solicitud de amistad ──────────────────────────────────────
exports.notificarSolicitudAmistad = onDocumentCreated(
  "solicitudes/{solicitudId}",
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const destinatarioUid = data.para;
    const remitenteUid    = data.de;
    if (!destinatarioUid || !remitenteUid) return;

    const db = getFirestore();
    const [destinatarioDoc, remitenteDoc] = await Promise.all([
      db.collection("usuarios").doc(destinatarioUid).get(),
      db.collection("usuarios").doc(remitenteUid).get(),
    ]);

    const destData = destinatarioDoc.data();
    const tokens = destData?.fcmTokens ?? (destData?.fcmToken ? [destData.fcmToken] : []);
    if (!tokens.length) return;

    const nombreRemitente = (remitenteDoc.data()?.nombre ?? "Alguien").split(" ")[0];

    await enviarATodos(
      tokens,
      { title: "nueva solicitud", body: `${nombreRemitente} quiere agregarte` },
      { tipo: "solicitud_amistad", uid: remitenteUid }
    );
  }
);

// ── Notificación de solicitud Venus ──────────────────────────────────────────
exports.notificarSolicitudVenus = onDocumentWritten(
  "usuarios/{uid}",
  async (event) => {
    const antes  = event.data.before.data();
    const despues = event.data.after.data();
    if (!despues) return;

    const enlaceAntes  = antes?.venusEnlace;
    const enlaceDespues = despues.venusEnlace;

    // Solo nos interesa cuando el estado pasa a "pendiente_recibida" por primera vez
    const eraOtroEstado = !enlaceAntes || enlaceAntes.estado !== "pendiente_recibida";
    const ahoraEsPendiente = enlaceDespues?.estado === "pendiente_recibida";
    if (!eraOtroEstado || !ahoraEsPendiente) return;

    const tokens = despues.fcmTokens ?? (despues.fcmToken ? [despues.fcmToken] : []);
    if (!tokens.length) return;

    const remitenteUid = enlaceDespues.uid;
    const nombreRemitente = (enlaceDespues.nombre ?? "Alguien").split(" ")[0];

    await enviarATodos(
      tokens,
      { title: "venus", body: `${nombreRemitente} quiere conectar contigo en venus` },
      { tipo: "solicitud_venus", uid: remitenteUid }
    );
  }
);

// ── Wipe diario de imágenes de cartas leídas ──────────────────────────────────
exports.limpiarImagenesCartas = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "America/Mexico_City",
    region: "us-central1",
    timeoutSeconds: 120,
  },
  async () => {
    const db     = getFirestore();
    const bucket = getStorage().bucket();

    const usuariosSnap = await db.collection("venus_cartas").get();

    for (const usuarioDoc of usuariosSnap.docs) {
      const cartasSnap = await usuarioDoc.ref
        .collection("cartas")
        .where("leida", "==", true)
        .get();

      for (const cartaDoc of cartasSnap.docs) {
        const { imagenUrl } = cartaDoc.data();

        if (imagenUrl) {
          try {
            const match = imagenUrl.match(/\/o\/(.+?)\?/);
            if (match) {
              const filePath = decodeURIComponent(match[1]);
              await bucket.file(filePath).delete();
            }
          } catch (e) {
            console.error(`Error borrando imagen ${imagenUrl}:`, e.message);
          }
        }

        await cartaDoc.ref.delete();
      }
    }
  }
);

// ── Debug: enviar notificación de prueba al usuario actual ────────────────────
exports.enviarNotifDebug = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sin sesión");

    const tipo = request.data?.tipo ?? "diaria";
    const db = getFirestore();
    const userDoc = await db.collection("usuarios").doc(uid).get();
    const userData = userDoc.data();
    const tokens = userData?.fcmTokens ?? (userData?.fcmToken ? [userData.fcmToken] : []);

    if (!tokens.length) throw new HttpsError("not-found", "Sin token FCM registrado");

    const mensajes = {
      diaria:   { title: "tus astros de hoy ✦",  body: "esta es una notificación de prueba de lectura diaria" },
      venus:    { title: "venus ♀",               body: "alguien quiere conectar contigo en venus" },
      carta:    { title: "venus",                 body: "tu pareja te ha enviado una carta 💌" },
    };

    const notif = mensajes[tipo] ?? mensajes.diaria;
    const resultado = await enviarATodos(tokens, notif, { tipo, debug: "true" });

    const exitosos = resultado?.successCount ?? resultado?.responses?.filter(r => r.success)?.length ?? 0;
    const fallidos = resultado?.failureCount ?? resultado?.responses?.filter(r => !r.success)?.length ?? 0;

    return { tokens: tokens.length, exitosos, fallidos };
  }
);
