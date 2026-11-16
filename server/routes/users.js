const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getAuth, getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();
const memberIdsRouter = express.Router();

const MAX_AVATAR_BYTES = 800 * 1024;

const ALLOWED = [
  "fullName",
  "bio",
  "gender",
  "photoUrl",
  "phoneCountry",
  "officeTiming",
  "officeNumber",
  "country",
  "department",
  "university",
  "enrollmentYear",
  "phone",
];

function sendError(res, status, error, message) {
  return res.status(status).json({ error, message });
}

function normalizeMemberId(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "");
}

function profileFromDoc(uid, data) {
  const d = data || {};
  return {
    uid,
    fullName: d.fullName || "",
    email: d.email || "",
    phone: d.phone || "",
    role: d.role || "student",
    memberId: d.memberId || d.studentId || d.teacherMemberId || "",
    photoUrl: d.photoUrl || "",
    phoneCountry: d.phoneCountry || "US",
    gender: d.gender || "",
    bio: d.bio || "",
    officeTiming: d.officeTiming || "",
    officeNumber: d.officeNumber || "",
    country: d.country || "",
    department: d.department || "",
    university: d.university || "",
    enrollmentYear: d.enrollmentYear || "",
    connectedTeacherId: d.connectedTeacherId || null,
    connectedTeacherEmail: d.connectedTeacherEmail || null,
    connectedTeacherName: d.connectedTeacherName || null,
  };
}

function avatarUrl(userId) {
  return "firestore://users/" + userId + "/avatar/current";
}

function contentTypeFor(fileName) {
  const lower = String(fileName || "").toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  return "image/jpeg";
}

function decodeBase64(raw) {
  const value = String(raw || "").trim();
  if (!value) return null;
  const cleaned = value.replace(/^data:[^;]+;base64,/, "");
  try {
    return Buffer.from(cleaned, "base64");
  } catch (_) {
    return null;
  }
}

function bufferFromFirestoreBytes(raw) {
  if (!raw) return null;
  if (Buffer.isBuffer(raw)) return raw;
  if (raw instanceof Uint8Array) return Buffer.from(raw);
  if (typeof raw.toBuffer === "function") {
    try {
      return raw.toBuffer();
    } catch (_) {}
  }
  if (typeof raw === "string") {
    try {
      return Buffer.from(raw, "base64");
    } catch (_) {
      return null;
    }
  }
  return null;
}

async function readUserProfile(uid) {
  const snap = await getDb().collection("users").doc(uid).get();
  if (!snap.exists) return null;
  return profileFromDoc(uid, snap.data());
}

async function matchTeacherField(field, value) {
  const snapshot = await getDb()
    .collection("users")
    .where(field, "==", value)
    .limit(8)
    .get();
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    if (String(data.role || "").toLowerCase() === "teacher") {
      return profileFromDoc(doc.id, data);
    }
  }
  return null;
}

async function findTeacher(query) {
  const needle = String(query || "").trim();
  if (!needle) return null;
  const lower = needle.toLowerCase();

  if (needle.includes("@")) {
    const byProfile =
      (await matchTeacherField("emailLower", lower)) ||
      (await matchTeacherField("email", lower));
    if (byProfile) return byProfile;

    const courses = await getDb()
      .collection("courses")
      .where("teacherEmail", "==", lower)
      .limit(1)
      .get();
    if (courses.empty) return null;
    const teacherId = courses.docs[0].data().teacherId;
    if (!teacherId) return null;
    return readUserProfile(teacherId);
  }

  return (
    (await matchTeacherField("memberIdLower", lower)) ||
    (await matchTeacherField("nameLower", lower))
  );
}

async function deleteCourseTree(courseRef) {
  const files = await courseRef.collection("files").get();
  for (const file of files.docs) {
    const chunks = await file.ref.collection("chunks").get();
    for (const chunk of chunks.docs) {
      await chunk.ref.delete();
    }
    await file.ref.delete();
  }
  await courseRef.delete();
}

// GET /api/users/me
router.get("/me", requireAuth, async (req, res) => {
  try {
    const profile = await readUserProfile(req.uid);
    if (!profile) {
      return sendError(res, 404, "not-found", "Profile not found.");
    }
    return res.json({ user: profile });
  } catch (err) {
    console.error("get me error", err.message);
    return sendError(res, 500, "read-failed", "Could not load profile.");
  }
});

// PATCH /api/users/me
router.patch("/me", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const updates = {};
    for (const key of ALLOWED) {
      if (Object.prototype.hasOwnProperty.call(body, key)) {
        updates[key] = body[key];
      }
    }
    if (Object.keys(updates).length === 0) {
      return sendError(res, 400, "no-fields", "No allowed profile fields to update.");
    }

    if (updates.fullName != null) {
      updates.fullName = String(updates.fullName).trim();
      updates.nameLower = updates.fullName.toLowerCase();
    }
    if (updates.phone != null) {
      updates.phone = String(updates.phone).trim();
    }

    updates.updatedAt = FieldValue.serverTimestamp();
    const ref = getDb().collection("users").doc(req.uid);
    await ref.set(updates, { merge: true });
    const profile = await readUserProfile(req.uid);
    return res.json({ user: profile });
  } catch (err) {
    console.error("patch me error", err.message);
    return sendError(res, 500, "update-failed", "Could not update profile.");
  }
});

// POST /api/users/me/avatar  body: { dataBase64, fileName }
router.post("/me/avatar", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const fileName = String(body.fileName || "avatar.jpg").trim() || "avatar.jpg";
    const bytes = decodeBase64(body.dataBase64);
    if (!bytes || bytes.length === 0) {
      return sendError(res, 400, "invalid-avatar", "Avatar bytes are required.");
    }
    if (bytes.length > MAX_AVATAR_BYTES) {
      return sendError(
        res,
        400,
        "avatar-too-large",
        "Avatar must be 800KB or smaller."
      );
    }

    const lower = fileName.toLowerCase();
    if (!lower.endsWith(".png") && !lower.endsWith(".jpg") && !lower.endsWith(".jpeg")) {
      return sendError(
        res,
        400,
        "invalid-avatar-type",
        "Avatar must be JPG, JPEG, or PNG."
      );
    }

    const contentType = contentTypeFor(fileName);
    const avatarRef = getDb()
      .collection("users")
      .doc(req.uid)
      .collection("avatar")
      .doc("current");

    await avatarRef.set({
      data: bytes,
      name: fileName,
      contentType,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const photoUrl = avatarUrl(req.uid);
    await getDb().collection("users").doc(req.uid).set(
      {
        photoUrl,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return res.json({ photoUrl, contentType, size: bytes.length });
  } catch (err) {
    console.error("save avatar error", err.message);
    return sendError(res, 500, "avatar-upload-failed", "Could not save avatar.");
  }
});

// GET /api/users/me/avatar
router.get("/me/avatar", requireAuth, async (req, res) => {
  try {
    const snap = await getDb()
      .collection("users")
      .doc(req.uid)
      .collection("avatar")
      .doc("current")
      .get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Avatar not found.");
    }
    const d = snap.data() || {};
    const buf = bufferFromFirestoreBytes(d.data);
    if (!buf) {
      return sendError(res, 404, "not-found", "Avatar data missing.");
    }
    return res.json({
      photoUrl: avatarUrl(req.uid),
      fileName: d.name || "avatar.jpg",
      contentType: d.contentType || "image/jpeg",
      dataBase64: buf.toString("base64"),
      size: buf.length,
    });
  } catch (err) {
    console.error("get my avatar error", err.message);
    return sendError(res, 500, "avatar-read-failed", "Could not load avatar.");
  }
});

// POST /api/users/me/link-teacher  body: { query }
router.post("/me/link-teacher", requireAuth, async (req, res) => {
  try {
    const query = String((req.body && req.body.query) || "").trim();
    if (!query) {
      return sendError(res, 400, "invalid-query", "Teacher query is required.");
    }

    const teacher = await findTeacher(query);
    if (!teacher || teacher.uid === req.uid) {
      return sendError(res, 404, "teacher-not-found", "No matching teacher found.");
    }

    await getDb().collection("users").doc(req.uid).set(
      {
        connectedTeacherId: teacher.uid,
        connectedTeacherEmail: teacher.email || "",
        connectedTeacherName: teacher.fullName || "",
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const profile = await readUserProfile(req.uid);
    return res.json({ user: profile });
  } catch (err) {
    console.error("link teacher error", err.message);
    return sendError(res, 500, "link-failed", "Could not link teacher.");
  }
});

// DELETE /api/users/me/link-teacher
router.delete("/me/link-teacher", requireAuth, async (req, res) => {
  try {
    await getDb().collection("users").doc(req.uid).set(
      {
        connectedTeacherId: null,
        connectedTeacherEmail: null,
        connectedTeacherName: null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    const profile = await readUserProfile(req.uid);
    if (profile) {
      profile.connectedTeacherId = null;
      profile.connectedTeacherEmail = null;
      profile.connectedTeacherName = null;
    }
    return res.json({ user: profile });
  } catch (err) {
    console.error("unlink teacher error", err.message);
    return sendError(res, 500, "unlink-failed", "Could not unlink teacher.");
  }
});

// DELETE /api/users/me — delete account (Auth + profile + owned courses + avatar + memberIds)
router.delete("/me", requireAuth, async (req, res) => {
  const uid = req.uid;
  const db = getDb();
  try {
    const courses = await db
      .collection("courses")
      .where("teacherId", "==", uid)
      .get();
    for (const course of courses.docs) {
      await deleteCourseTree(course.ref);
    }

    const memberIds = await db
      .collection("memberIds")
      .where("uid", "==", uid)
      .get();
    for (const doc of memberIds.docs) {
      const data = doc.data() || {};
      if (data.uid === uid) {
        await doc.ref.delete();
      }
    }

    const avatars = await db
      .collection("users")
      .doc(uid)
      .collection("avatar")
      .get();
    for (const avatar of avatars.docs) {
      await avatar.ref.delete();
    }

    await db.collection("users").doc(uid).delete().catch(() => {});
    await db.collection("phoneCredentials").doc(uid).delete().catch(() => {});

    try {
      await getAuth().deleteUser(uid);
    } catch (authErr) {
      if (authErr.code !== "auth/user-not-found") {
        throw authErr;
      }
    }

    return res.json({ ok: true });
  } catch (err) {
    console.error("delete account error", err.message);
    return sendError(
      res,
      500,
      "account-delete-failed",
      "Could not delete account."
    );
  }
});

// GET /api/users/:userId/avatar
router.get("/:userId/avatar", requireAuth, async (req, res) => {
  try {
    const userId = String(req.params.userId || "").trim();
    if (!userId) {
      return sendError(res, 400, "invalid-user", "User id is required.");
    }
    const snap = await getDb()
      .collection("users")
      .doc(userId)
      .collection("avatar")
      .doc("current")
      .get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Avatar not found.");
    }
    const d = snap.data() || {};
    const buf = bufferFromFirestoreBytes(d.data);
    if (!buf) {
      return sendError(res, 404, "not-found", "Avatar data missing.");
    }
    return res.json({
      photoUrl: avatarUrl(userId),
      fileName: d.name || "avatar.jpg",
      contentType: d.contentType || "image/jpeg",
      dataBase64: buf.toString("base64"),
      size: buf.length,
    });
  } catch (err) {
    console.error("get avatar error", err.message);
    return sendError(res, 500, "avatar-read-failed", "Could not load avatar.");
  }
});

// GET /api/users/:userId
router.get("/:userId", requireAuth, async (req, res) => {
  try {
    const userId = String(req.params.userId || "").trim();
    if (!userId || userId === "me") {
      return sendError(res, 400, "invalid-user", "User id is required.");
    }
    const profile = await readUserProfile(userId);
    if (!profile) {
      return sendError(res, 404, "not-found", "User not found.");
    }
    return res.json({ user: profile });
  } catch (err) {
    console.error("get user error", err.message);
    return sendError(res, 500, "read-failed", "Could not load user.");
  }
});


// GET /api/member-ids/:id/available — soft check before claim/signup
memberIdsRouter.get("/:id/available", async (req, res) => {
  try {
    const memberId = String(req.params.id || "").trim();
    if (!memberId || !/^\d{1,20}$/.test(memberId)) {
      return sendError(
        res,
        400,
        "invalid-member-id",
        "Member ID must be 1-20 digits."
      );
    }
    const idKey = normalizeMemberId(memberId);
    const snap = await getDb().collection("memberIds").doc(idKey).get();
    return res.json({
      memberId,
      available: !snap.exists,
    });
  } catch (err) {
    console.error("member-id available error", err.message);
    return sendError(res, 500, "check-failed", "Could not check member ID.");
  }
});

// POST /api/member-ids/claim  body: { memberId }
memberIdsRouter.post("/claim", requireAuth, async (req, res) => {
  try {
    const memberId = String((req.body && req.body.memberId) || "").trim();
    if (!memberId || !/^\d{1,20}$/.test(memberId)) {
      return sendError(
        res,
        400,
        "invalid-member-id",
        "Member ID must be 1–20 digits."
      );
    }

    const uid = req.uid;
    const db = getDb();
    const idKey = normalizeMemberId(memberId);
    const idRef = db.collection("memberIds").doc(idKey);
    const userRef = db.collection("users").doc(uid);

    const existingProfile = await userRef.get();
    const prev = existingProfile.exists ? existingProfile.data() || {} : {};
    const role = String(prev.role || "student").toLowerCase() === "teacher"
      ? "teacher"
      : "student";
    const emailLower = String(prev.emailLower || prev.email || "").toLowerCase();

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(idRef);
      if (existing.exists) {
        const data = existing.data() || {};
        const owner = data.uid || "";
        const linkedEmail = String(data.emailLower || "").toLowerCase();
        const sameOwner = owner === uid;
        const sameEmail = !linkedEmail || linkedEmail === emailLower;
        if (!sameOwner || !sameEmail) {
          const err = new Error("This ID is already in use.");
          err.code = "id-in-use";
          throw err;
        }
      }

      // Release a previous memberId claimed by this uid (different key).
      const oldKey = normalizeMemberId(prev.memberId || "");
      if (oldKey && oldKey !== idKey) {
        const oldRef = db.collection("memberIds").doc(oldKey);
        const oldSnap = await tx.get(oldRef);
        if (oldSnap.exists && (oldSnap.data() || {}).uid === uid) {
          tx.delete(oldRef);
        }
      }

      tx.set(idRef, {
        uid,
        emailLower,
        memberId,
        role,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        userRef,
        {
          memberId,
          memberIdLower: idKey,
          studentId: role === "student" ? memberId : null,
          teacherMemberId: role === "teacher" ? memberId : null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    const profile = await readUserProfile(uid);
    return res.json({ user: profile });
  } catch (err) {
    if (err.code === "id-in-use") {
      return sendError(res, 409, "id-in-use", "This ID is already in use.");
    }
    console.error("claim memberId error", err.message);
    return sendError(res, 500, "claim-failed", "Could not claim member ID.");
  }
});

module.exports = { router, memberIdsRouter };
