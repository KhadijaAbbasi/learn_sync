const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

const TEACHER_FEEDBACK_LIMIT = 400;
const LEVELS = new Set(["100", "80", "60", "below50"]);

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

function feedbackDocId(lectureId, studentId) {
  return `${lectureId}_${studentId}`;
}

function serializeFeedback(id, data) {
  const d = data || {};
  return {
    id,
    lectureId: d.lectureId || "",
    sessionId: d.sessionId || d.lectureId || "",
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    teacherId: d.teacherId || "",
    teacherName: d.teacherName || "",
    studentId: d.studentId || "",
    studentName: d.studentName || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    chapterId: d.chapterId || "",
    chapterTitle: d.chapterTitle || "",
    topicId: d.topicId || "",
    topicTitle: d.topicTitle || "",
    level: d.level || "below50",
    comment: d.comment || "",
    createdAt: toIso(d.createdAt),
    updatedAt: toIso(d.updatedAt),
  };
}

function sortByUpdatedDesc(a, b) {
  const left = a.updatedAt || a.createdAt || "";
  const right = b.updatedAt || b.createdAt || "";
  return right.localeCompare(left);
}

async function assertMemberOrTeacher(uid, courseId) {
  const courseSnap = await getDb().collection("courses").doc(courseId).get();
  if (!courseSnap.exists) {
    return {
      ok: false,
      status: 404,
      error: "not-found",
      message: "Course not found.",
    };
  }
  const data = courseSnap.data() || {};
  if (data.teacherId === uid) {
    return { ok: true, courseSnap, data, isTeacher: true };
  }
  const memberSnap = await courseSnap.ref.collection("members").doc(uid).get();
  if (!memberSnap.exists) {
    return {
      ok: false,
      status: 403,
      error: "forbidden",
      message: "Not a member of this course.",
    };
  }
  return { ok: true, courseSnap, data, isTeacher: false };
}

// POST /api/feedback — student submit/update (matches CourseStore.submitLectureFeedback)
router.post("/", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const lectureId = String(body.lectureId || body.sessionId || "").trim();
    const courseId = String(body.courseId || "").trim();
    const studentId = req.uid;
    const studentName = String(body.studentName || "").trim();
    const level = String(body.level || "").trim();
    const comment = String(body.comment || "").trim();

    if (!lectureId || !courseId || !studentName) {
      return sendError(
        res,
        400,
        "invalid-request",
        "A valid lecture feedback is required."
      );
    }
    if (!LEVELS.has(level)) {
      return sendError(
        res,
        400,
        "invalid-level",
        "level must be 100, 80, 60, or below50."
      );
    }

    const db = getDb();
    const lectureRef = db.collection("lectures").doc(lectureId);
    let lecture = await lectureRef.get();

    if (!lecture.exists || (lecture.data() || {}).status !== "ended") {
      const liveSnap = await db
        .collection("courses")
        .doc(courseId)
        .collection("liveSessions")
        .doc(lectureId)
        .get();
      const liveStatus = (liveSnap.data() || {}).status || "";
      if (liveStatus !== "ended") {
        return sendError(
          res,
          409,
          "lecture-not-ended",
          "Feedback is only allowed after the lecture ends."
        );
      }
      await new Promise((r) => setTimeout(r, 800));
      lecture = await lectureRef.get();
    }

    if (!lecture.exists || (lecture.data() || {}).status !== "ended") {
      return sendError(
        res,
        409,
        "lecture-not-ended",
        "Lecture is not marked ended yet. Wait a moment and try again."
      );
    }

    const lectureData = lecture.data() || {};
    const resolvedCourseId =
      (lectureData.courseId || "").trim() || courseId;
    const resolvedTeacherId =
      (lectureData.teacherId || "").trim() ||
      String(body.teacherId || "").trim();
    const resolvedCourseName =
      String(body.courseName || "").trim() ||
      (lectureData.courseName || "").trim() ||
      "Course";
    const resolvedTeacherName =
      String(body.teacherName || "").trim() ||
      (lectureData.teacherName || "").trim() ||
      "Teacher";

    if (!resolvedCourseId || !resolvedTeacherId) {
      return sendError(
        res,
        400,
        "invalid-request",
        "A valid lecture feedback is required."
      );
    }

    const access = await assertMemberOrTeacher(studentId, resolvedCourseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    if (access.isTeacher) {
      return sendError(
        res,
        403,
        "forbidden",
        "Teachers cannot submit lecture feedback."
      );
    }

    const id = feedbackDocId(lectureId, studentId);
    const feedbackRef = db.collection("feedback").doc(id);
    const draft = {
      lectureId,
      sessionId: lectureId,
      courseId: resolvedCourseId,
      courseName: resolvedCourseName,
      teacherId: resolvedTeacherId,
      teacherName: resolvedTeacherName,
      studentId,
      studentName,
      studentEmail: String(body.studentEmail || "")
        .trim()
        .toLowerCase(),
      memberId: String(body.memberId || "").trim(),
      chapterId: String(body.chapterId || lectureData.chapterId || "").trim(),
      chapterTitle: String(
        body.chapterTitle || lectureData.chapterTitle || ""
      ).trim(),
      topicId: String(body.topicId || lectureData.topicId || "").trim(),
      topicTitle: String(
        body.topicTitle || lectureData.topicTitle || ""
      ).trim(),
      level,
      comment,
    };

    const existing = await feedbackRef.get();
    if (existing.exists) {
      await feedbackRef.update({
        level,
        comment,
        studentName,
        studentEmail: draft.studentEmail,
        memberId: draft.memberId,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      await feedbackRef.set({
        ...draft,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const snap = await feedbackRef.get();
    return res.status(existing.exists ? 200 : 201).json({
      feedback: serializeFeedback(snap.id, snap.data() || draft),
    });
  } catch (err) {
    console.error("POST /api/feedback", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/feedback/lectures/:lectureId/me
router.get("/lectures/:lectureId/me", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    if (!lectureId) {
      return sendError(res, 400, "invalid-request", "lectureId is required.");
    }
    const id = feedbackDocId(lectureId, req.uid);
    const snap = await getDb().collection("feedback").doc(id).get();
    if (!snap.exists) {
      return res.json({ feedback: null });
    }
    return res.json({ feedback: serializeFeedback(snap.id, snap.data()) });
  } catch (err) {
    console.error("GET /api/feedback/lectures/:lectureId/me", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/feedback/lectures/:lectureId — all for lecture (teacher of that lecture)
router.get("/lectures/:lectureId", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const teacherId = String(req.query.teacherId || "").trim();
    if (!lectureId) {
      return sendError(res, 400, "invalid-request", "lectureId is required.");
    }

    const db = getDb();
    const lectureSnap = await db.collection("lectures").doc(lectureId).get();
    if (!lectureSnap.exists) {
      return sendError(res, 404, "not-found", "Lecture not found.");
    }
    const lectureData = lectureSnap.data() || {};
    const courseId = (lectureData.courseId || "").trim();
    if (!courseId) {
      return sendError(res, 404, "not-found", "Lecture course missing.");
    }

    const access = await assertMemberOrTeacher(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    if (!access.isTeacher && lectureData.teacherId !== req.uid) {
      // Students only see their own via /me; all list is teacher-only.
      return sendError(
        res,
        403,
        "forbidden",
        "Only the course teacher can list all feedback."
      );
    }

    let query = db.collection("feedback").where("lectureId", "==", lectureId);
    if (teacherId) {
      query = query.where("teacherId", "==", teacherId);
    }
    const snap = await query.get();
    const items = snap.docs
      .map((doc) => serializeFeedback(doc.id, doc.data()))
      .sort(sortByUpdatedDesc);
    return res.json({ feedback: items });
  } catch (err) {
    console.error("GET /api/feedback/lectures/:lectureId", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/feedback/teachers/:teacherId — matches watchTeacherFeedback
router.get("/teachers/:teacherId", requireAuth, async (req, res) => {
  try {
    const teacherId = String(req.params.teacherId || "").trim();
    if (!teacherId) {
      return sendError(res, 400, "invalid-request", "teacherId is required.");
    }
    if (teacherId !== req.uid) {
      return sendError(
        res,
        403,
        "forbidden",
        "You can only read your own teacher feedback."
      );
    }
    const snap = await getDb()
      .collection("feedback")
      .where("teacherId", "==", teacherId)
      .limit(TEACHER_FEEDBACK_LIMIT)
      .get();
    const items = snap.docs
      .map((doc) => serializeFeedback(doc.id, doc.data()))
      .sort(sortByUpdatedDesc);
    return res.json({ feedback: items });
  } catch (err) {
    console.error("GET /api/feedback/teachers/:teacherId", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

module.exports = router;
