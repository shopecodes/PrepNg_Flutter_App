// functions/index.js

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// ── Helper: get today's date string in WAT (UTC+1) ─────────────────────────
function getWATDateString() {
  const now = new Date();
  // Shift to WAT = UTC+1
  const wat = new Date(now.getTime() + 60 * 60 * 1000);
  return wat.toISOString().split("T")[0]; // "YYYY-MM-DD"
}

// ── Helper: read question text regardless of field name ────────────────────
// Handles 'question', 'text', 'questionText' — whichever your upload script used
function getQuestionText(data) {
  return data?.question ?? data?.text ?? data?.questionText ?? null;
}

// ── Sends QOTD notification every day at 9:00 AM WAT (8AM UTC) ────────────
exports.sendQOTDNotification = onSchedule(
  { schedule: "0 8 * * *", timeZone: "UTC" },
  async () => {
    try {
      console.log("Starting QOTD notification job...");

      const dateString = getWATDateString();
      console.log(`Looking up QOTD for WAT date: ${dateString}`);

      const qotdDoc = await db
        .collection("question_of_the_day")
        .doc(dateString)
        .get();

      let notificationBody =
        "A new question is waiting for you! Can you answer it? 🧠";

      if (qotdDoc.exists) {
        const text = getQuestionText(qotdDoc.data());
        if (text) {
          notificationBody =
            text.substring(0, 80) + (text.length > 80 ? "..." : "");
        } else {
          console.warn(
            `QOTD doc ${dateString} exists but has no question text field.`
          );
        }
      } else {
        console.warn(`No QOTD document found for ${dateString}.`);
      }

      const usersSnapshot = await db
        .collection("users")
        .where("fcmToken", "!=", null)
        .get();

      if (usersSnapshot.empty) {
        console.log("No users with FCM tokens found.");
        return;
      }

      const tokens = [];
      usersSnapshot.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token && typeof token === "string") tokens.push(token);
      });

      console.log(`Sending to ${tokens.length} users...`);

      const batchSize = 500;
      let successCount = 0;
      let failureCount = 0;
      const invalidTokens = [];

      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize);
        const message = {
          notification: {
            title: "🧠 Question of the Day",
            body: notificationBody,
          },
          data: { type: "qotd", date: dateString },
          android: {
            notification: {
              channelId: "qotd_channel",
              color: "#4CAF7D",
            },
            priority: "high",
          },
          apns: { payload: { aps: { sound: "default", badge: 1 } } },
          tokens: batch,
        };

        const response = await getMessaging().sendEachForMulticast(message);
        successCount += response.successCount;
        failureCount += response.failureCount;

        response.responses.forEach((resp, index) => {
          if (!resp.success) {
            const code = resp.error?.code;
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(batch[index]);
            }
          }
        });
      }

      console.log(`Done. Success: ${successCount}, Failed: ${failureCount}`);

      // Clean up invalid tokens
      if (invalidTokens.length > 0) {
        const cleanupBatch = db.batch();
        for (const token of invalidTokens) {
          const q = await db
            .collection("users")
            .where("fcmToken", "==", token)
            .get();
          q.forEach((doc) => {
            cleanupBatch.update(doc.ref, { fcmToken: FieldValue.delete() });
          });
        }
        await cleanupBatch.commit();
        console.log(`Cleaned up ${invalidTokens.length} invalid tokens.`);
      }
    } catch (error) {
      console.error("Error sending QOTD notification:", error);
    }
  }
);

// ── HTTP test endpoint ─────────────────────────────────────────────────────
// Usage:
//   Default (WAT today):  GET https://.../testQOTDNotification
//   Specific date:        GET https://.../testQOTDNotification?date=2026-03-28
exports.testQOTDNotification = onRequest(async (req, res) => {
  try {
    // Use ?date= param if provided, otherwise fall back to WAT today
    const dateString = req.query.date || getWATDateString();

    // Validate format YYYY-MM-DD
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateString)) {
      res.status(400).send("Invalid date format. Use YYYY-MM-DD e.g. ?date=2026-03-28");
      return;
    }

    // Fetch the QOTD doc for that date so the notification body is real
    const qotdDoc = await db
      .collection("question_of_the_day")
      .doc(dateString)
      .get();

    let notificationBody = "This is a test QOTD notification from PrepNG!";
    if (qotdDoc.exists) {
      const text = getQuestionText(qotdDoc.data());
      if (text) {
        notificationBody = text.substring(0, 80) + (text.length > 80 ? "..." : "");
      }
    } else {
      console.warn(`No QOTD document found for ${dateString} — sending generic body.`);
    }

    const usersSnapshot = await db
      .collection("users")
      .where("fcmToken", "!=", null)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      res.status(404).send("No users with FCM tokens found.");
      return;
    }

    const token = usersSnapshot.docs[0].data().fcmToken;

    await getMessaging().send({
      notification: {
        title: "🧠 Question of the Day",
        body: notificationBody,
      },
      data: {
        type: "qotd",
        date: dateString,
      },
      android: {
        notification: { channelId: "qotd_channel", color: "#4CAF7D" },
        priority: "high",
      },
      token: token,
    });

    res.status(200).send(`Test notification sent for date: ${dateString}`);
  } catch (error) {
    console.error("Test notification error:", error);
    res.status(500).send(`Error: ${error.message}`);
  }
});

// ── Paystack Webhook ────────────────────────────────────────────────────────
exports.paystackWebhook = onRequest(async (req, res) => {
  try {
    const crypto = require("crypto");
    const { defineSecret } = require("firebase-functions/params");
    const paystackSecret = defineSecret("PAYSTACK_SECRET_KEY");
    const secret = paystackSecret.value();

    const hash = crypto
      .createHmac("sha512", secret)
      .update(JSON.stringify(req.body))
      .digest("hex");

    if (hash !== req.headers["x-paystack-signature"]) {
      console.warn("Invalid Paystack signature");
      return res.status(401).send("Unauthorized");
    }

    const event = req.body;
    if (event.event !== "charge.success") {
      console.log(`Ignoring event: ${event.event}`);
      return res.status(200).send("OK");
    }

    const data = event.data;
    const reference = data.reference;
    const metadata = data.metadata || {};
    const subjectId = metadata.subjectId;
    const subjectName = metadata.subjectName;
    const userId = metadata.userId;

    console.log(`charge.success — ref: ${reference}, userId: ${userId}, subjectId: ${subjectId}`);

    if (!subjectId || !userId) {
      console.error("Missing subjectId or userId in metadata");
      return res.status(200).send("OK");
    }

    const existing = await db
      .collection("user_subjects")
      .where("paymentReference", "==", reference)
      .limit(1)
      .get();

    if (!existing.empty) {
      console.log(`Already saved — skipping duplicate: ${reference}`);
      return res.status(200).send("OK");
    }

    await db.collection("user_subjects").add({
      userId: userId,
      subjectId: subjectId,
      subjectName: subjectName || null,
      amount: 500,
      paymentReference: reference,
      paymentMode: "LIVE",
      purchaseDate: FieldValue.serverTimestamp(),
      source: "webhook",
    });

    console.log(`Subject unlocked via webhook: ${subjectId} for user: ${userId}`);
    return res.status(200).send("OK");
  } catch (error) {
    console.error("Webhook error:", error);
    return res.status(200).send("OK");
  }
});