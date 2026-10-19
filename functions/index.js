const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

initializeApp();

const db = getFirestore();
const auth = getAuth();
const ALLOWED_ROLES = new Set(["security_officer", "supervisor"]);

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in is required.");
  }

  const profile = await db.collection("users").doc(request.auth.uid).get();
  const data = profile.data();

  if (!profile.exists || data?.status !== "active" || data?.role !== "admin") {
    throw new HttpsError("permission-denied", "An active administrator account is required.");
  }

  return request.auth.uid;
}

exports.listAccountRequests = onCall(async (request) => {
  await requireAdmin(request);

  const snapshot = await db.collection("account_requests")
      .where("status", "==", "pending")
      .limit(100)
      .get();

  const requests = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      uid: doc.id,
      displayName: typeof data.displayName === "string" ? data.displayName : "",
      email: typeof data.email === "string" ? data.email : "",
      requestedRole: typeof data.requestedRole === "string" ? data.requestedRole : "",
      createdAt: data.createdAt?.toDate?.().toISOString() ?? null,
    };
  });

  requests.sort((a, b) => (a.createdAt ?? "").localeCompare(b.createdAt ?? ""));
  return { requests };
});

exports.decideAccountRequest = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = request.data?.uid;
  const decision = request.data?.decision;

  if (typeof uid !== "string" || uid.length < 10 || uid === adminUid) {
    throw new HttpsError("invalid-argument", "A valid applicant UID is required.");
  }
  if (decision !== "approve" && decision !== "reject") {
    throw new HttpsError("invalid-argument", "Decision must be approve or reject.");
  }

  const requestRef = db.collection("account_requests").doc(uid);
  const applicantAuth = await auth.getUser(uid).catch((error) => {
    if (error.code === "auth/user-not-found") return null;
    throw error;
  });

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Account request was not found.");
    }

    const data = snapshot.data();
    if (data.status !== "pending") {
      throw new HttpsError("failed-precondition", "This request has already been reviewed.");
    }

    if (decision === "approve") {
      if (!applicantAuth) {
        throw new HttpsError("not-found", "The applicant authentication account was not found.");
      }
      if (!ALLOWED_ROLES.has(data.requestedRole)) {
        throw new HttpsError("failed-precondition", "The requested role is not permitted.");
      }

      transaction.set(db.collection("users").doc(uid), {
        uid,
        displayName: String(data.displayName ?? ""),
        email: String(data.email ?? applicantAuth.email ?? ""),
        role: data.requestedRole,
        status: "active",
        createdAt: FieldValue.serverTimestamp(),
        approvedAt: FieldValue.serverTimestamp(),
        approvedBy: adminUid,
      });
    }

    transaction.update(requestRef, {
      status: decision === "approve" ? "approved" : "rejected",
      reviewedAt: FieldValue.serverTimestamp(),
      reviewedBy: adminUid,
    });
  });

  // Rejected accounts cannot sign in; remove their Auth account so they may
  // submit a fresh request later using the same email address.
  if (decision === "reject" && applicantAuth) {
    await auth.deleteUser(uid).catch((error) => {
      if (error.code !== "auth/user-not-found") throw error;
    });
  }

  return { success: true, status: decision === "approve" ? "approved" : "rejected" };
});
