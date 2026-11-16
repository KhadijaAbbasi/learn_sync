const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

function sendError(res, status, error, message) {
  return res.status(status).json({ error, message });
}

function normalizeCourseCode(raw) {
  return String(raw || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "");
}

function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate().toISOString();
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "string") return value;
  return null;
}

function serializeCourse(id, data) {
  const d = data || {};
  return {
    id,
    teacherId: d.teacherId || d.createdBy || "",
    createdBy: d.createdBy || d.teacherId || "",
    teacherEmail: d.teacherEmail || "",
    teacherName: d.teacherName || "",
    name: d.name || "",
    code: d.code || "",
    department: d.department || "",
    creditHours: typeof d.creditHours === "number" ? d.creditHours : 3,
    lectureHall: d.lectureHall || "",
    lectureDays: Array.isArray(d.lectureDays) ? d.lectureDays : [],
    lectureTime: d.lectureTime || "",
    lectureSlots: Array.isArray(d.lectureSlots) ? d.lectureSlots : [],
    registrationDate: toIso(d.registrationDate),
    outlines: d.outlines || "",
    semester: d.semester || "",
    section: d.section || "",
    topicCount: typeof d.topicCount === "number" ? d.topicCount : 0,
    isLive: Boolean(d.isLive),
    createdAt: toIso(d.createdAt),
    updatedAt: toIso(d.updatedAt),
  };
}

function serializeChapter(id, data) {
  const d = data || {};
  return {
    id,
    title: d.title || "",
    description: d.description || "",
    position: typeof d.position === "number" ? d.position : 0,
    attachments: Array.isArray(d.attachments) ? d.attachments : [],
    attachmentName: d.attachmentName || "",
    attachmentUrl: d.attachmentUrl || "",
    createdAt: toIso(d.createdAt),
    updatedAt: toIso(d.updatedAt),
  };
}

function serializeTopic(id, data) {
  return serializeChapter(id, data);
}

async function getUserDoc(uid) {
  const snap = await getDb().collection("users").doc(uid).get();
  return snap.exists ? snap.data() || {} : {};
}

async function isCourseCodeTaken(code, exceptCourseId) {
  if (!code) return false;
  const col = getDb().collection("courses");
  const byId = await col.doc(code).get();
  if (byId.exists && byId.id !== exceptCourseId) return true;
  const matches = await col.where("code", "==", code).limit(5).get();
  return matches.docs.some((doc) => doc.id !== exceptCourseId);
}

async function assertCanAccessCourse(uid, role, courseSnap) {
  if (!courseSnap.exists) {
    return { ok: false, status: 404, error: "not-found", message: "Course not found." };
  }
  const data = courseSnap.data() || {};
  if (data.teacherId === uid) {
    return { ok: true, data, asTeacher: true };
  }
  const member = await courseSnap.ref.collection("members").doc(uid).get();
  if (member.exists) {
    return { ok: true, data, asTeacher: false };
  }
  return {
    ok: false,
    status: 403,
    error: "forbidden",
    message: "You do not have access to this course.",
  };
}

async function assertTeacherOwns(uid, courseId) {
  const snap = await getDb().collection("courses").doc(courseId).get();
  if (!snap.exists) {
    return { ok: false, status: 404, error: "not-found", message: "Course not found." };
  }
  if ((snap.data() || {}).teacherId !== uid) {
    return {
      ok: false,
      status: 403,
      error: "forbidden",
      message: "Only the course teacher can change this course.",
    };
  }
  return { ok: true, snap, data: snap.data() || {} };
}

async function nextPosition(collectionRef) {
  const snapshot = await collectionRef
    .orderBy("position", "desc")
    .limit(1)
    .get();
  if (snapshot.empty) return 0;
  const pos = snapshot.docs[0].data().position;
  return (typeof pos === "number" ? pos : -1) + 1;
}

async function deleteCourseNested(courseId) {
  const db = getDb();
  const courseRef = db.collection("courses").doc(courseId);
  const chapters = await courseRef.collection("chapters").get();
  for (const chapter of chapters.docs) {
    const topics = await chapter.ref.collection("topics").get();
    const batch = db.batch();
    for (const topic of topics.docs) {
      batch.delete(topic.ref);
    }
    batch.delete(chapter.ref);
    await batch.commit();
  }
  const sessions = await courseRef.collection("liveSessions").get();
  if (!sessions.empty) {
    const batch = db.batch();
    for (const session of sessions.docs) {
      batch.delete(session.ref);
    }
    await batch.commit();
  }
}

function attachmentFields(body) {
  const attachments = Array.isArray(body.attachments) ? body.attachments : [];
  const first = attachments[0] || {};
  return {
    attachments,
    attachmentName: body.attachmentName || first.name || "",
    attachmentUrl: body.attachmentUrl || first.url || "",
  };
}

// --- code check (must be before /:courseId) ---
router.get("/code-available", requireAuth, async (req, res) => {
  try {
    const code = normalizeCourseCode(req.query.code);
    const exceptCourseId = String(req.query.exceptCourseId || "").trim() || null;
    if (!code) {
      return res.json({ available: true, code: "" });
    }
    const taken = await isCourseCodeTaken(code, exceptCourseId);
    return res.json({ available: !taken, code });
  } catch (err) {
    console.error("code-available error", err.message);
    return sendError(res, 500, "check-failed", "Could not check course code.");
  }
});

// --- list ---
router.get("/", requireAuth, async (req, res) => {
  try {
    const user = await getUserDoc(req.uid);
    const role = user.role || "student";
    const db = getDb();
    let courses = [];

    if (role === "teacher") {
      const snap = await db
        .collection("courses")
        .where("teacherId", "==", req.uid)
        .get();
      courses = snap.docs.map((doc) => serializeCourse(doc.id, doc.data()));
    } else {
      // Student joined courses: prefer collectionGroup on members.studentId.
      // Fall back to connected teacher's courses + membership check (app pattern).
      let loaded = false;
      try {
        const memberSnap = await db
          .collectionGroup("members")
          .where("studentId", "==", req.uid)
          .get();
        const courseIds = [];
        for (const doc of memberSnap.docs) {
          const parts = doc.ref.path.split("/");
          if (
            parts.length === 4 &&
            parts[0] === "courses" &&
            parts[2] === "members"
          ) {
            courseIds.push(parts[1]);
          }
        }
        const unique = [...new Set(courseIds)];
        for (const id of unique) {
          const courseDoc = await db.collection("courses").doc(id).get();
          if (courseDoc.exists) {
            courses.push(serializeCourse(courseDoc.id, courseDoc.data()));
          }
        }
        loaded = true;
      } catch (err) {
        console.warn("members collectionGroup failed, using fallback:", err.message);
      }
      if (!loaded) {
        const teacherId = user.connectedTeacherId || "";
        if (teacherId) {
          const snap = await db
            .collection("courses")
            .where("teacherId", "==", teacherId)
            .get();
          for (const doc of snap.docs) {
            const member = await doc.ref.collection("members").doc(req.uid).get();
            if (member.exists) {
              courses.push(serializeCourse(doc.id, doc.data()));
            }
          }
        }
      }
    }

    courses.sort((a, b) =>
      String(a.name).toLowerCase().localeCompare(String(b.name).toLowerCase())
    );
    return res.json({ courses });
  } catch (err) {
    console.error("list courses error", err.message);
    return sendError(res, 500, "list-failed", "Could not list courses.");
  }
});

// --- create ---
router.post("/", requireAuth, async (req, res) => {
  try {
    const user = await getUserDoc(req.uid);
    if ((user.role || "student") !== "teacher") {
      return sendError(res, 403, "forbidden", "Only teachers can create courses.");
    }

    const body = req.body || {};
    const code = normalizeCourseCode(body.code || body.id);
    const name = String(body.name || "").trim();
    if (!code) {
      return sendError(res, 400, "invalid-code", "Course code is required.");
    }
    if (!name) {
      return sendError(res, 400, "invalid-name", "Course name is required.");
    }
    if (await isCourseCodeTaken(code)) {
      return sendError(res, 409, "duplicate-code", "Course code is already taken.");
    }

    const teacherId = req.uid;
    const payload = {
      teacherId,
      createdBy: teacherId,
      teacherEmail: String(body.teacherEmail || user.email || "").trim(),
      teacherName: String(body.teacherName || user.fullName || "").trim(),
      name,
      code,
      department: String(body.department || "").trim(),
      creditHours:
        typeof body.creditHours === "number"
          ? body.creditHours
          : parseInt(body.creditHours, 10) || 3,
      lectureHall: String(body.lectureHall || "").trim(),
      lectureDays: Array.isArray(body.lectureDays) ? body.lectureDays : [],
      lectureTime: String(body.lectureTime || "").trim(),
      lectureSlots: Array.isArray(body.lectureSlots) ? body.lectureSlots : [],
      outlines: String(body.outlines || "").trim(),
      semester: String(body.semester || "").trim(),
      section: String(body.section || "").trim(),
      topicCount: 0,
      isLive: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (body.registrationDate) {
      const d = new Date(body.registrationDate);
      if (!Number.isNaN(d.getTime())) {
        payload.registrationDate = d;
      }
    }

    const ref = getDb().collection("courses").doc(code);
    try {
      await getDb().runTransaction(async (tx) => {
        const existing = await tx.get(ref);
        if (existing.exists) {
          const err = new Error("duplicate");
          err.code = "duplicate-code";
          throw err;
        }
        tx.set(ref, payload);
      });
    } catch (err) {
      if (err.code === "duplicate-code" || err.message === "duplicate") {
        return sendError(res, 409, "duplicate-code", "Course code is already taken.");
      }
      throw err;
    }

    const snap = await ref.get();
    return res.status(201).json({ course: serializeCourse(snap.id, snap.data()) });
  } catch (err) {
    console.error("create course error", err.message);
    return sendError(res, 500, "create-failed", "Could not create course.");
  }
});

// --- detail ---
router.get("/:courseId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const snap = await getDb().collection("courses").doc(courseId).get();
    const user = await getUserDoc(req.uid);
    const access = await assertCanAccessCourse(req.uid, user.role, snap);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    return res.json({ course: serializeCourse(snap.id, access.data) });
  } catch (err) {
    console.error("get course error", err.message);
    return sendError(res, 500, "get-failed", "Could not load course.");
  }
});

// --- update ---
router.patch("/:courseId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }

    const body = req.body || {};
    const code = normalizeCourseCode(body.code || owned.data.code || courseId);
    if (!code) {
      return sendError(res, 400, "invalid-code", "Course code is required.");
    }
    if (await isCourseCodeTaken(code, courseId)) {
      return sendError(res, 409, "duplicate-code", "Course code is already taken.");
    }

    const updates = {
      code,
      updatedAt: FieldValue.serverTimestamp(),
    };

    const stringFields = [
      "name",
      "department",
      "lectureHall",
      "lectureTime",
      "outlines",
      "semester",
      "section",
      "teacherEmail",
      "teacherName",
    ];
    for (const key of stringFields) {
      if (Object.prototype.hasOwnProperty.call(body, key)) {
        updates[key] = String(body[key] || "").trim();
      }
    }
    if (Object.prototype.hasOwnProperty.call(body, "creditHours")) {
      updates.creditHours =
        typeof body.creditHours === "number"
          ? body.creditHours
          : parseInt(body.creditHours, 10) || 3;
    }
    if (Object.prototype.hasOwnProperty.call(body, "lectureDays")) {
      updates.lectureDays = Array.isArray(body.lectureDays) ? body.lectureDays : [];
    }
    if (Object.prototype.hasOwnProperty.call(body, "lectureSlots")) {
      updates.lectureSlots = Array.isArray(body.lectureSlots) ? body.lectureSlots : [];
    }
    if (Object.prototype.hasOwnProperty.call(body, "registrationDate")) {
      if (body.registrationDate == null || body.registrationDate === "") {
        updates.registrationDate = null;
      } else {
        const d = new Date(body.registrationDate);
        if (!Number.isNaN(d.getTime())) {
          updates.registrationDate = d;
        }
      }
    }
    if (updates.name !== undefined && !updates.name) {
      return sendError(res, 400, "invalid-name", "Course name is required.");
    }

    await getDb().collection("courses").doc(courseId).update(updates);
    const snap = await getDb().collection("courses").doc(courseId).get();
    return res.json({ course: serializeCourse(snap.id, snap.data()) });
  } catch (err) {
    console.error("update course error", err.message);
    return sendError(res, 500, "update-failed", "Could not update course.");
  }
});

// --- delete (course + chapters/topics + liveSessions) ---
router.delete("/:courseId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    await deleteCourseNested(courseId);
    await getDb().collection("courses").doc(courseId).delete();
    return res.json({ ok: true, id: courseId });
  } catch (err) {
    console.error("delete course error", err.message);
    return sendError(res, 500, "delete-failed", "Could not delete course.");
  }
});

// --- chapters ---
router.get("/:courseId/chapters", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const snap = await getDb().collection("courses").doc(courseId).get();
    const user = await getUserDoc(req.uid);
    const access = await assertCanAccessCourse(req.uid, user.role, snap);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const chapters = await snap.ref.collection("chapters").orderBy("position").get();
    return res.json({
      chapters: chapters.docs.map((doc) => serializeChapter(doc.id, doc.data())),
    });
  } catch (err) {
    console.error("list chapters error", err.message);
    return sendError(res, 500, "list-failed", "Could not list chapters.");
  }
});

router.post("/:courseId/chapters", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Chapter title is required.");
    }
    const col = getDb().collection("courses").doc(courseId).collection("chapters");
    const doc = body.id ? col.doc(String(body.id)) : col.doc();
    const position = await nextPosition(col);
    const payload = {
      title,
      description: String(body.description || "").trim(),
      position,
      ...attachmentFields(body),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    await doc.set(payload);
    const saved = await doc.get();
    return res.status(201).json({ chapter: serializeChapter(saved.id, saved.data()) });
  } catch (err) {
    console.error("add chapter error", err.message);
    return sendError(res, 500, "create-failed", "Could not create chapter.");
  }
});

router.patch("/:courseId/chapters/reorder", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const orderedIds = Array.isArray(req.body?.orderedIds)
      ? req.body.orderedIds.map((id) => String(id || "").trim()).filter(Boolean)
      : [];
    if (orderedIds.length === 0) {
      return sendError(res, 400, "invalid-order", "orderedIds is required.");
    }
    const col = getDb().collection("courses").doc(courseId).collection("chapters");
    const batch = getDb().batch();
    orderedIds.forEach((id, index) => {
      batch.update(col.doc(id), {
        position: index,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
    const chapters = await col.orderBy("position").get();
    return res.json({
      chapters: chapters.docs.map((doc) => serializeChapter(doc.id, doc.data())),
    });
  } catch (err) {
    console.error("reorder chapters error", err.message);
    return sendError(res, 500, "reorder-failed", "Could not reorder chapters.");
  }
});

router.patch("/:courseId/chapters/:chapterId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const chapterId = String(req.params.chapterId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Chapter title is required.");
    }
    const ref = getDb()
      .collection("courses")
      .doc(courseId)
      .collection("chapters")
      .doc(chapterId);
    const existing = await ref.get();
    if (!existing.exists) {
      return sendError(res, 404, "not-found", "Chapter not found.");
    }
    await ref.update({
      title,
      description: String(body.description || "").trim(),
      ...attachmentFields(body),
      updatedAt: FieldValue.serverTimestamp(),
    });
    const saved = await ref.get();
    return res.json({ chapter: serializeChapter(saved.id, saved.data()) });
  } catch (err) {
    console.error("update chapter error", err.message);
    return sendError(res, 500, "update-failed", "Could not update chapter.");
  }
});

router.delete("/:courseId/chapters/:chapterId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const chapterId = String(req.params.chapterId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const db = getDb();
    const chapterRef = db
      .collection("courses")
      .doc(courseId)
      .collection("chapters")
      .doc(chapterId);
    const topics = await chapterRef.collection("topics").get();
    const batch = db.batch();
    for (const topic of topics.docs) {
      batch.delete(topic.ref);
    }
    batch.delete(chapterRef);
    if (!topics.empty) {
      batch.update(db.collection("courses").doc(courseId), {
        topicCount: FieldValue.increment(-topics.size),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return res.json({ ok: true, id: chapterId });
  } catch (err) {
    console.error("delete chapter error", err.message);
    return sendError(res, 500, "delete-failed", "Could not delete chapter.");
  }
});

// --- topics ---
router.get("/:courseId/chapters/:chapterId/topics", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const chapterId = String(req.params.chapterId || "").trim();
    const snap = await getDb().collection("courses").doc(courseId).get();
    const user = await getUserDoc(req.uid);
    const access = await assertCanAccessCourse(req.uid, user.role, snap);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const topics = await snap.ref
      .collection("chapters")
      .doc(chapterId)
      .collection("topics")
      .orderBy("position")
      .get();
    return res.json({
      topics: topics.docs.map((doc) => serializeTopic(doc.id, doc.data())),
    });
  } catch (err) {
    console.error("list topics error", err.message);
    return sendError(res, 500, "list-failed", "Could not list topics.");
  }
});

router.post("/:courseId/chapters/:chapterId/topics", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const chapterId = String(req.params.chapterId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Topic title is required.");
    }
    const db = getDb();
    const topics = db
      .collection("courses")
      .doc(courseId)
      .collection("chapters")
      .doc(chapterId)
      .collection("topics");
    const doc = body.id ? topics.doc(String(body.id)) : topics.doc();
    const position = await nextPosition(topics);
    const batch = db.batch();
    batch.set(doc, {
      title,
      description: String(body.description || "").trim(),
      position,
      ...attachmentFields(body),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.update(db.collection("courses").doc(courseId), {
      topicCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    const saved = await doc.get();
    return res.status(201).json({ topic: serializeTopic(saved.id, saved.data()) });
  } catch (err) {
    console.error("add topic error", err.message);
    return sendError(res, 500, "create-failed", "Could not create topic.");
  }
});

router.patch(
  "/:courseId/chapters/:chapterId/topics/reorder",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const chapterId = String(req.params.chapterId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      const orderedIds = Array.isArray(req.body?.orderedIds)
        ? req.body.orderedIds.map((id) => String(id || "").trim()).filter(Boolean)
        : [];
      if (orderedIds.length === 0) {
        return sendError(res, 400, "invalid-order", "orderedIds is required.");
      }
      const col = getDb()
        .collection("courses")
        .doc(courseId)
        .collection("chapters")
        .doc(chapterId)
        .collection("topics");
      const batch = getDb().batch();
      orderedIds.forEach((id, index) => {
        batch.update(col.doc(id), {
          position: index,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      const topics = await col.orderBy("position").get();
      return res.json({
        topics: topics.docs.map((doc) => serializeTopic(doc.id, doc.data())),
      });
    } catch (err) {
      console.error("reorder topics error", err.message);
      return sendError(res, 500, "reorder-failed", "Could not reorder topics.");
    }
  }
);

router.patch(
  "/:courseId/chapters/:chapterId/topics/:topicId",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const chapterId = String(req.params.chapterId || "").trim();
      const topicId = String(req.params.topicId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      const body = req.body || {};
      const title = String(body.title || "").trim();
      if (!title) {
        return sendError(res, 400, "invalid-title", "Topic title is required.");
      }
      const ref = getDb()
        .collection("courses")
        .doc(courseId)
        .collection("chapters")
        .doc(chapterId)
        .collection("topics")
        .doc(topicId);
      const existing = await ref.get();
      if (!existing.exists) {
        return sendError(res, 404, "not-found", "Topic not found.");
      }
      await ref.update({
        title,
        description: String(body.description || "").trim(),
        ...attachmentFields(body),
        updatedAt: FieldValue.serverTimestamp(),
      });
      const saved = await ref.get();
      return res.json({ topic: serializeTopic(saved.id, saved.data()) });
    } catch (err) {
      console.error("update topic error", err.message);
      return sendError(res, 500, "update-failed", "Could not update topic.");
    }
  }
);

router.delete(
  "/:courseId/chapters/:chapterId/topics/:topicId",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const chapterId = String(req.params.chapterId || "").trim();
      const topicId = String(req.params.topicId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      const db = getDb();
      const topicRef = db
        .collection("courses")
        .doc(courseId)
        .collection("chapters")
        .doc(chapterId)
        .collection("topics")
        .doc(topicId);
      const courseRef = db.collection("courses").doc(courseId);
      await db.runTransaction(async (tx) => {
        const topic = await tx.get(topicRef);
        if (!topic.exists) return;
        const course = await tx.get(courseRef);
        const currentCount = (course.data() || {}).topicCount || 0;
        tx.delete(topicRef);
        tx.update(courseRef, {
          topicCount: currentCount > 0 ? currentCount - 1 : 0,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      return res.json({ ok: true, id: topicId });
    } catch (err) {
      console.error("delete topic error", err.message);
      return sendError(res, 500, "delete-failed", "Could not delete topic.");
    }
  }
);

module.exports = router;
