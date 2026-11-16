const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const courseRouter = express.Router();
const joinRequestsRouter = express.Router();
const studentsRouter = express.Router();
const teachersRouter = express.Router();

function sendError(res, status, error, message) {
  return res.status(status).json({ error, message });
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

function serializeJoinRequest(id, data, courseId) {
  const d = data || {};
  return {
    studentId: d.studentId || id,
    studentName: d.studentName || "",
    courseId: d.courseId || courseId || "",
    courseName: d.courseName || "",
    courseCode: d.courseCode || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    status: d.status || "pending",
    requestedAt: toIso(d.requestedAt),
    respondedAt: toIso(d.respondedAt),
  };
}

function serializeMember(id, data) {
  const d = data || {};
  return {
    studentId: d.studentId || id,
    studentName: d.studentName || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    courseId: d.courseId || "",
    joinedAt: toIso(d.joinedAt),
  };
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
      message: "Only the course teacher can do this.",
    };
  }
  return { ok: true, snap, data: snap.data() || {} };
}

async function pendingForTeacher(teacherId) {
  const db = getDb();
  const coursesSnap = await db
    .collection("courses")
    .where("teacherId", "==", teacherId)
    .get();

  const items = [];
  for (const courseDoc of coursesSnap.docs) {
    const courseData = courseDoc.data() || {};
    const reqSnap = await courseDoc.ref
      .collection("joinRequests")
      .where("status", "==", "pending")
      .get();
    for (const doc of reqSnap.docs) {
      const data = doc.data() || {};
      items.push(
        serializeJoinRequest(doc.id, {
          ...data,
          courseId: data.courseId || courseDoc.id,
          courseName: data.courseName || courseData.name || "",
          courseCode: data.courseCode || courseData.code || "",
        }, courseDoc.id)
      );
    }
  }

  items.sort((a, b) => {
    const left = a.requestedAt || "";
    const right = b.requestedAt || "";
    return String(right).localeCompare(String(left));
  });
  return items;
}

// POST /api/courses/:courseId/join-requests — student requests join
courseRouter.post("/:courseId/join-requests", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const studentId = req.uid;
    const body = req.body || {};

    if (!courseId) {
      return sendError(res, 400, "invalid-course", "Course id is required.");
    }

    const db = getDb();
    const courseRef = db.collection("courses").doc(courseId);
    const memberRef = courseRef.collection("members").doc(studentId);
    const requestRef = courseRef.collection("joinRequests").doc(studentId);

    const courseSnap = await courseRef.get();
    if (!courseSnap.exists) {
      return sendError(res, 404, "not-found", "Course not found.");
    }
    const courseData = courseSnap.data() || {};

    const payload = {
      studentId,
      studentName: String(body.studentName || "").trim(),
      courseId,
      courseName: String(body.courseName || courseData.name || "").trim(),
      courseCode: String(body.courseCode || courseData.code || "").trim(),
      studentEmail: String(body.studentEmail || "").trim().toLowerCase(),
      memberId: String(body.memberId || "").trim(),
      status: "pending",
      requestedAt: FieldValue.serverTimestamp(),
    };

    let result;
    await db.runTransaction(async (tx) => {
      const member = await tx.get(memberRef);
      if (member.exists) {
        const err = new Error("Already enrolled in this course.");
        err.code = "already-enrolled";
        throw err;
      }
      const existing = await tx.get(requestRef);
      if (!existing.exists) {
        tx.set(requestRef, payload);
        result = { ...payload, requestedAt: new Date().toISOString() };
        return;
      }
      const status = (existing.data() || {}).status;
      if (status === "pending") {
        result = serializeJoinRequest(existing.id, existing.data(), courseId);
        return;
      }
      if (status !== "declined") {
        const err = new Error("Join request could not be sent.");
        err.code = "invalid-status";
        throw err;
      }
      tx.update(requestRef, {
        ...payload,
        respondedAt: FieldValue.delete(),
      });
      result = { ...payload, requestedAt: new Date().toISOString(), respondedAt: null };
    });

    return res.status(201).json({ request: serializeJoinRequest(studentId, result, courseId) });
  } catch (err) {
    if (err.code === "already-enrolled") {
      return sendError(res, 409, "already-enrolled", err.message);
    }
    if (err.code === "invalid-status") {
      return sendError(res, 409, "invalid-status", err.message);
    }
    console.error("request join error", err.message);
    return sendError(res, 500, "create-failed", "Could not create join request.");
  }
});

// GET /api/courses/:courseId/join-requests — pending for course (teacher)
courseRouter.get("/:courseId/join-requests", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }

    const snap = await getDb()
      .collection("courses")
      .doc(courseId)
      .collection("joinRequests")
      .where("status", "==", "pending")
      .get();

    const requests = snap.docs.map((doc) =>
      serializeJoinRequest(doc.id, {
        ...doc.data(),
        courseId: (doc.data() || {}).courseId || courseId,
        courseName: (doc.data() || {}).courseName || owned.data.name || "",
        courseCode: (doc.data() || {}).courseCode || owned.data.code || "",
      }, courseId)
    );

    requests.sort((a, b) =>
      String(b.requestedAt || "").localeCompare(String(a.requestedAt || ""))
    );
    return res.json({ requests });
  } catch (err) {
    console.error("list join-requests error", err.message);
    return sendError(res, 500, "list-failed", "Could not list join requests.");
  }
});

// POST accept
courseRouter.post(
  "/:courseId/join-requests/:studentId/accept",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const studentId = String(req.params.studentId || "").trim();
      const teacherId = req.uid;

      if (!courseId || !studentId) {
        return sendError(res, 400, "invalid-params", "Course and student id are required.");
      }

      const db = getDb();
      const courseRef = db.collection("courses").doc(courseId);
      const requestRef = courseRef.collection("joinRequests").doc(studentId);
      const memberRef = courseRef.collection("members").doc(studentId);

      await db.runTransaction(async (tx) => {
        const course = await tx.get(courseRef);
        const request = await tx.get(requestRef);
        if (!course.exists || (course.data() || {}).teacherId !== teacherId) {
          const err = new Error("Course not found.");
          err.code = "not-found";
          throw err;
        }
        if (!request.exists) {
          const err = new Error("Join request not found.");
          err.code = "request-not-found";
          throw err;
        }
        const data = request.data() || {};
        if (data.status === "accepted") {
          return;
        }
        if (data.status !== "pending") {
          const err = new Error("Join request is not pending.");
          err.code = "not-pending";
          throw err;
        }
        tx.update(requestRef, {
          status: "accepted",
          respondedAt: FieldValue.serverTimestamp(),
        });
        tx.set(memberRef, {
          studentId,
          studentName: data.studentName || "",
          studentEmail: data.studentEmail || "",
          memberId: data.memberId || "",
          courseId,
          joinedAt: FieldValue.serverTimestamp(),
        });
      });

      return res.json({ ok: true });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      if (err.code === "request-not-found") {
        return sendError(res, 404, "request-not-found", err.message);
      }
      if (err.code === "not-pending") {
        return sendError(res, 409, "not-pending", err.message);
      }
      console.error("accept join error", err.message);
      return sendError(res, 500, "accept-failed", "Could not accept join request.");
    }
  }
);

// POST decline — deletes the request so student can re-request
courseRouter.post(
  "/:courseId/join-requests/:studentId/decline",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const studentId = String(req.params.studentId || "").trim();
      const teacherId = req.uid;

      if (!courseId || !studentId) {
        return sendError(res, 400, "invalid-params", "Course and student id are required.");
      }

      const db = getDb();
      const courseRef = db.collection("courses").doc(courseId);
      const requestRef = courseRef.collection("joinRequests").doc(studentId);

      await db.runTransaction(async (tx) => {
        const course = await tx.get(courseRef);
        const request = await tx.get(requestRef);
        if (!course.exists || (course.data() || {}).teacherId !== teacherId) {
          const err = new Error("Course not found.");
          err.code = "not-found";
          throw err;
        }
        if (!request.exists) {
          const err = new Error("Join request not found.");
          err.code = "request-not-found";
          throw err;
        }
        const data = request.data() || {};
        if (data.status !== "pending") {
          const err = new Error("Join request is not pending.");
          err.code = "not-pending";
          throw err;
        }
        tx.delete(requestRef);
      });

      return res.json({ ok: true });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      if (err.code === "request-not-found") {
        return sendError(res, 404, "request-not-found", err.message);
      }
      if (err.code === "not-pending") {
        return sendError(res, 409, "not-pending", err.message);
      }
      console.error("decline join error", err.message);
      return sendError(res, 500, "decline-failed", "Could not decline join request.");
    }
  }
);

// GET /api/courses/:courseId/members
courseRouter.get("/:courseId/members", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }

    const snap = await getDb()
      .collection("courses")
      .doc(courseId)
      .collection("members")
      .get();

    const members = snap.docs.map((doc) => serializeMember(doc.id, doc.data()));
    members.sort((a, b) =>
      String(a.studentName).toLowerCase().localeCompare(String(b.studentName).toLowerCase())
    );
    return res.json({ members });
  } catch (err) {
    console.error("list members error", err.message);
    return sendError(res, 500, "list-failed", "Could not list members.");
  }
});

// DELETE /api/courses/:courseId/members/:studentId
courseRouter.delete(
  "/:courseId/members/:studentId",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const studentId = String(req.params.studentId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }

      const courseRef = getDb().collection("courses").doc(courseId);
      const memberRef = courseRef.collection("members").doc(studentId);
      const requestRef = courseRef.collection("joinRequests").doc(studentId);

      const member = await memberRef.get();
      if (member.exists) {
        await memberRef.delete();
      }

      try {
        const request = await requestRef.get();
        if (request.exists) {
          await requestRef.delete();
        }
      } catch (_) {
        // Best-effort: membership already removed.
      }

      return res.json({ ok: true, id: studentId });
    } catch (err) {
      console.error("remove member error", err.message);
      return sendError(res, 500, "remove-failed", "Could not remove member.");
    }
  }
);

// GET /api/join-requests/mine-as-teacher
joinRequestsRouter.get("/mine-as-teacher", requireAuth, async (req, res) => {
  try {
    const requests = await pendingForTeacher(req.uid);
    return res.json({ requests });
  } catch (err) {
    console.error("mine-as-teacher join-requests error", err.message);
    return sendError(res, 500, "list-failed", "Could not list join requests.");
  }
});

// GET /api/teachers/:teacherId/join-requests (must be self)
teachersRouter.get("/:teacherId/join-requests", requireAuth, async (req, res) => {
  try {
    const teacherId = String(req.params.teacherId || "").trim();
    if (teacherId !== req.uid) {
      return sendError(res, 403, "forbidden", "You can only list your own join requests.");
    }
    const requests = await pendingForTeacher(teacherId);
    return res.json({ requests });
  } catch (err) {
    console.error("teacher join-requests error", err.message);
    return sendError(res, 500, "list-failed", "Could not list join requests.");
  }
});

// GET /api/students/me/joined-courses
studentsRouter.get("/me/joined-courses", requireAuth, async (req, res) => {
  try {
    const db = getDb();
    const courses = [];

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
      for (const id of [...new Set(courseIds)]) {
        const courseDoc = await db.collection("courses").doc(id).get();
        if (courseDoc.exists) {
          courses.push(serializeCourse(courseDoc.id, courseDoc.data()));
        }
      }
    } catch (err) {
      console.warn("joined-courses collectionGroup failed:", err.message);
      const userSnap = await db.collection("users").doc(req.uid).get();
      const teacherId = (userSnap.data() || {}).connectedTeacherId || "";
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

    courses.sort((a, b) =>
      String(a.name).toLowerCase().localeCompare(String(b.name).toLowerCase())
    );
    return res.json({ courses });
  } catch (err) {
    console.error("joined-courses error", err.message);
    return sendError(res, 500, "list-failed", "Could not list joined courses.");
  }
});

module.exports = {
  courseRouter,
  joinRequestsRouter,
  studentsRouter,
  teachersRouter,
};
