const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();
setGlobalOptions({ maxInstances: 10 });

// Se dispara cuando se crea una carta nueva en venus_cartas/{uid}/cartas/{cartaId}
exports.notificarCarta = onDocumentCreated(
  "venus_cartas/{uid}/cartas/{cartaId}",
  async (event) => {
    const uid = event.params.uid;
    const carta = event.data.data();

    if (!carta) return;

    // Obtener el token FCM del destinatario
    const db = getFirestore();
    const userDoc = await db.collection("usuarios").doc(uid).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return;

    const esFoto = !!carta.imagenUrl;
    const remitente = carta.de ?? "tu pareja";

    await getMessaging().send({
      token,
      notification: {
        title: remitente,
        body: esFoto ? "te envió una foto" : "te envió una carta",
      },
      data: { tipo: "venus" },
    });
  }
);
