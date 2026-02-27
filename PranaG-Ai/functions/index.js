const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.notifyNewAlert = functions.firestore
  .document("users/{uid}/alerts/{alertId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    if (data.deleted === true) {
      return null;
    }

    const title = data.title || "PRANA-G Alert";
    const body = data.description || "New alert received.";

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.params.uid)
      .get();

    const tokensMap = userDoc.get("deviceTokens") || {};
    const tokens = Object.keys(tokensMap).filter((t) => tokensMap[t]);

    if (tokens.length === 0) {
      return null;
    }

    const payload = {
      notification: {
        title,
        body,
      },
      data: {
        alertId: context.params.alertId,
        cattleId: String(data.cattleId || ""),
        type: String(data.type || ""),
      },
    };

    const response = await admin.messaging().sendToDevice(tokens, payload, {
      priority: "high",
    });

    const tokensToRemove = [];
    response.results.forEach((result, index) => {
      const error = result.error;
      if (!error) {
        return;
      }
      const code = error.code || "";
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        tokensToRemove.push(tokens[index]);
      }
    });

    if (tokensToRemove.length > 0) {
      const updates = {};
      for (const token of tokensToRemove) {
        updates[`deviceTokens.${token}`] = admin.firestore.FieldValue.delete();
      }
      await admin
        .firestore()
        .collection("users")
        .doc(context.params.uid)
        .update(updates);
    }

    return null;
  });
