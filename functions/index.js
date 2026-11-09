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


// Apply each security officer's personal archive retention policy.
// This hides expired references in that officer's archive only; published
// roster documents remain intact for supervisors, administration and others.
exports.cleanupPersonalDutyRosterArchives = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Asia/Amman",
    region: "us-central1",
    timeoutSeconds: 300,
  },
  async () => {
    const now = Timestamp.now();
    const officers = await db
      .collection("users")
      .where("role", "in", ["security_officer", "supervisor"])
      .where("status", "==", "active")
      .get();
    const publishedRosters = await db
      .collection("daily_duty_rosters")
      .where("status", "==", "published")
      .get();

    for (const officer of officers.docs) {
      const preferences = officer.ref.collection("duty_roster_preferences");
      const settingsSnapshot = await preferences.doc("settings").get();
      if (!settingsSnapshot.exists) continue;
      const settings = settingsSnapshot.data() || {};
      if (settings.autoDeleteEnabled !== true) continue;

      const retentionDays = Number(settings.retentionDays);
      if (!Number.isInteger(retentionDays) || retentionDays < 1 || retentionDays > 3650) continue;
      const cutoffMillis = now.toMillis() - (22 * 60 * 60 * 1000) - retentionDays * 24 * 60 * 60 * 1000;
      const existingPreferences = await preferences.get();
      const hiddenIds = new Set(existingPreferences.docs.map((doc) => doc.id));
      const expired = [];

      for (const rosterDoc of publishedRosters.docs) {
        const roster = rosterDoc.data() || {};
        const shifts = roster.shifts || {};
        for (const shift of ["A", "B", "C"]) {
          const block = shifts[shift];
          if (!block || typeof block !== "object") continue;
          const published = block.status === "published" ||
            (block.status == null && roster.status === "published");
          if (!published) continue;
          const publishedAt = block.publishedAt instanceof Timestamp
            ? block.publishedAt
            : roster.updatedAt instanceof Timestamp ? roster.updatedAt : null;
          if (!publishedAt || publishedAt.toMillis() > cutoffMillis) continue;

          const preferenceId = rosterDoc.id + "_" + shift;
          if (hiddenIds.has(preferenceId)) continue;
          expired.push({
            ref: preferences.doc(preferenceId),
            rosterKey: rosterDoc.id,
            shift,
          });
        }
      }

      for (let start = 0; start < expired.length; start += 400) {
        const batch = db.batch();
        for (const item of expired.slice(start, start + 400)) {
          batch.set(item.ref, {
            ownerUid: officer.id,
            rosterKey: item.rosterKey,
            shift: item.shift,
            action: "hidden",
            reason: "automatic",
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    }
  },
);


// Hide expired staff-message archive entries for each account independently.
// The shared message and its other recipients' copies remain untouched.
exports.cleanupPersonalStaffMessageArchives = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Asia/Amman",
    region: "us-central1",
    timeoutSeconds: 300,
  },
  async () => {
    const now = Timestamp.now();
    const users = await db.collection("users")
      .where("status", "==", "active")
      .get();

    for (const user of users.docs) {
      const settingsSnap = await db.collection("message_archive_preferences")
        .doc(user.id).get();
      if (!settingsSnap.exists) continue;
      const settings = settingsSnap.data() || {};
      if (settings.autoDeleteEnabled !== true) continue;
      const days = Number(settings.retentionDays);
      if (!Number.isInteger(days) || days < 1 || days > 3650) continue;

      const [sent, received] = await Promise.all([
        db.collection("staff_messages").where("senderUid", "==", user.id).get(),
        db.collection("staff_messages").where("recipientUid", "==", user.id).get(),
      ]);
      const unique = new Map();
      for (const doc of sent.docs) unique.set(doc.id, doc);
      for (const doc of received.docs) unique.set(doc.id, doc);

      const cutoff = now.toMillis() - (24 + days * 24) * 60 * 60 * 1000;
      const batch = db.batch();
      let writes = 0;
      for (const doc of unique.values()) {
        const message = doc.data() || {};
        if (!(message.createdAt instanceof Timestamp)) continue;
        if (message.createdAt.toMillis() > cutoff) continue;
        const hiddenFor = Array.isArray(message.hiddenFor) ? message.hiddenFor : [];
        if (hiddenFor.includes(user.id)) continue;
        batch.update(doc.ref, { hiddenFor: FieldValue.arrayUnion(user.id) });
        writes += 1;
        if (writes === 400) {
          await batch.commit();
          writes = 0;
        }
      }
      if (writes > 0) await batch.commit();
    }
  },
);
