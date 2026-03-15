// functions/index.js
// 
// ADD THIS TO YOUR EXISTING index.js in your Firebase Cloud Functions folder
// Run: npm install firebase-admin firebase-functions (if not already installed)

const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Only initialize if not already initialized (important if you have existing functions)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled function: Sends QOTD notification every day at 9:00 AM (WAT)
// West Africa Time is UTC+1, so 9AM WAT = 8AM UTC
// ─────────────────────────────────────────────────────────────────────────────
exports.sendQOTDNotification = functions.pubsub
  .schedule("0 8 * * *") // 8:00 AM UTC = 9:00 AM WAT every day
  .timeZone("UTC")
  .onRun(async (context) => {
    try {
      console.log("Starting QOTD notification job...");

      // 1. Get today's QOTD from Firestore
      const today = new Date();
      const dateString = today.toISOString().split("T")[0]; // "YYYY-MM-DD"

      const qotdDoc = await db
        .collection("question_of_the_day")
        .doc(dateString)
        .get();

      let notificationBody = "A new question is waiting for you! Can you answer it? 🧠";
      let questionPreview = "";

      if (qotdDoc.exists) {
        const qotdData = qotdDoc.data();
        // Truncate question text to 80 chars for notification preview
        questionPreview = qotdData.text
          ? qotdData.text.substring(0, 80) + (qotdData.text.length > 80 ? "..." : "")
          : "";
        if (questionPreview) {
          notificationBody = questionPreview;
        }
      }

      // 2. Get all user FCM tokens from Firestore
      const usersSnapshot = await db
        .collection("users")
        .where("fcmToken", "!=", null)
        .get();

      if (usersSnapshot.empty) {
        console.log("No users with FCM tokens found.");
        return null;
      }

      // 3. Build list of tokens (batch in groups of 500 — FCM limit)
      const tokens = [];
      usersSnapshot.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token && typeof token === "string") {
          tokens.push(token);
        }
      });

      console.log(`Sending QOTD notification to ${tokens.length} users...`);

      // 4. Send in batches of 500
      const batchSize = 500;
      const batches = [];

      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize);
        batches.push(batch);
      }

      let successCount = 0;
      let failureCount = 0;
      const invalidTokens = [];

      for (const batch of batches) {
        const message = {
          notification: {
            title: "🧠 Question of the Day",
            body: notificationBody,
          },
          data: {
            type: "qotd",          // Used by app to navigate to QOTD screen
            date: dateString,
          },
          android: {
            notification: {
              channelId: "qotd_channel",
              icon: "ic_launcher",
              color: "#4CAF7D",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
            priority: "high",
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
          tokens: batch,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        successCount += response.successCount;
        failureCount += response.failureCount;

        // Collect invalid/expired tokens to clean up
        response.responses.forEach((resp, index) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(batch[index]);
            }
          }
        });
      }

      console.log(`QOTD notification sent. Success: ${successCount}, Failed: ${failureCount}`);

      // 5. Clean up invalid tokens from Firestore
      if (invalidTokens.length > 0) {
        console.log(`Cleaning up ${invalidTokens.length} invalid tokens...`);
        const cleanupBatch = db.batch();

        for (const token of invalidTokens) {
          const userQuery = await db
            .collection("users")
            .where("fcmToken", "==", token)
            .get();

          userQuery.forEach((doc) => {
            cleanupBatch.update(doc.ref, {
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          });
        }

        await cleanupBatch.commit();
        console.log("Invalid tokens cleaned up.");
      }

      return null;
    } catch (error) {
      console.error("Error sending QOTD notification:", error);
      return null;
    }
  });


// ─────────────────────────────────────────────────────────────────────────────
// Optional: HTTP trigger to manually test the notification (remove in production)
// Call: https://your-region-your-project.cloudfunctions.net/testQOTDNotification
// ─────────────────────────────────────────────────────────────────────────────
exports.testQOTDNotification = functions.https.onRequest(async (req, res) => {
  try {
    // Get a single test token (first user with a token)
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

    await admin.messaging().send({
      notification: {
        title: "🧠 Question of the Day",
        body: "This is a test QOTD notification from PrepNG!",
      },
      data: {
        type: "qotd",
        date: new Date().toISOString().split("T")[0],
      },
      android: {
        notification: {
          channelId: "qotd_channel",
          color: "#4CAF7D",
        },
        priority: "high",
      },
      token: token,
    });

    res.status(200).send("Test notification sent successfully!");
  } catch (error) {
    console.error("Test notification error:", error);
    res.status(500).send(`Error: ${error.message}`);
  }
});