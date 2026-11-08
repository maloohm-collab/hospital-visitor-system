const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Close shifts on the server so the eight-hour limit is enforced even when
// the officer's phone is offline or the app has been closed.
exports.closeExpiredWorkShifts = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Asia/Amman",
    region: "us-central1",
    timeoutSeconds: 120,
  },
  async () => {
    const now = Timestamp.now();
    const cutoff = Timestamp.fromMillis(now.toMillis() - 8 * 60 * 60 * 1000);
    const expired = await db
      .collection("work_shifts")
      .where("status", "==", "active")
      .where("startedAt", "<=", cutoff)
      .limit(100)
      .get();

    for (const candidate of expired.docs) {
      const shiftRef = candidate.ref;
      await db.runTransaction(async (tx) => {
        const shiftSnapshot = await tx.get(shiftRef);
        if (!shiftSnapshot.exists) return;
        const shift = shiftSnapshot.data();
        if (shift.status !== "active" ||
            !(shift.startedAt instanceof Timestamp) ||
            shift.startedAt.toMillis() > cutoff.toMillis()) {
          return;
        }

        const pointerRef = db.collection("active_work_shifts").doc(shift.officerUid);
        const pointerSnapshot = await tx.get(pointerRef);
        const activeLocationId = shift.activeLocationId;
        let locationRef = null;
        let locationSnapshot = null;
        if (typeof activeLocationId === "string" && activeLocationId.length > 0) {
          locationRef = shiftRef.collection("locations").doc(activeLocationId);
          locationSnapshot = await tx.get(locationRef);
        }

        if (locationRef && locationSnapshot && locationSnapshot.exists &&
            locationSnapshot.data().status === "active") {
          tx.update(locationRef, {
            status: "completed",
            endedAt: FieldValue.serverTimestamp(),
          });
        }

        tx.update(shiftRef, {
          status: "completed",
          endedAt: FieldValue.serverTimestamp(),
          activeLocationId: null,
          activeLocationName: null,
        });

        if (pointerSnapshot.exists &&
            pointerSnapshot.data().shiftId === shiftRef.id) {
          tx.delete(pointerRef);
        }
      });
    }
  },
);
