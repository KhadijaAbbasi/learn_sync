const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const courseRouter = express.Router();
const lecturesRouter = express.Router();

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

function lectureDateKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function liveSessionRef(courseId, sessionId) {
  return getDb()
    .collection("courses")
    .doc(courseId)
    .collection("liveSessions")
    .doc(sessionId);
}

function lectureRef(lectureId) {
  return getDb().collection("lectures").doc(lectureId);
}

function serializeLiveSession(id, courseId, data) {
  const d = data || {};
  return {
    id,
    courseId,
    chapterId: d.chapterId || "",
    chapterTitle: d.chapterTitle || "",
    topicId: d.topicId || "",
    topicTitle: d.topicTitle || "",
    teacherId: d.teacherId || "",
    durationMinutes:
      typeof d.durationMinutes === "number" ? d.durationMinutes : 0,
    status: d.status === "ended" ? "ended" : "active",
    startedAt: toIso(d.startedAt),
    endedAt: toIso(d.endedAt),
    slideFileIndex:
      typeof d.slideFileIndex === "number" ? d.slideFileIndex : 0,
    slidePage: typeof d.slidePage === "number" ? d.slidePage : 1,
    slideView:
      d.slideView && typeof d.slideView === "object" ? d.slideView : null,
  };
}

function serializeSummary(summary) {
  const s = summary || {};
  return {
    lectureId: s.lectureId || "",
    sessionId: s.sessionId || s.lectureId || "",
    courseId: s.courseId || "",
    courseName: s.courseName || "",
    courseCode: s.courseCode || "",
    department: s.department || "",
    semester: s.semester || "",
    section: s.section || "",
    teacherId: s.teacherId || "",
    teacherName: s.teacherName || "",
    chapterId: s.chapterId || "",
    chapterTitle: s.chapterTitle || "",
    topicId: s.topicId || "",
    topicTitle: s.topicTitle || "",
    durationMinutes:
      typeof s.durationMinutes === "number" ? s.durationMinutes : 0,
    actualDurationMinutes:
      typeof s.actualDurationMinutes === "number"
        ? s.actualDurationMinutes
        : 0,
    attendeeCount: typeof s.attendeeCount === "number" ? s.attendeeCount : 0,
    lectureDate: s.lectureDate || "",
    taughtNotes: s.taughtNotes || "",
    savedAt: toIso(s.savedAt),
  };
}

function serializeLecture(id, data) {
  const d = data || {};
  return {
    id,
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    teacherId: d.teacherId || "",
    teacherName: d.teacherName || "",
    chapterId: d.chapterId || "",
    chapterTitle: d.chapterTitle || "",
    topicId: d.topicId || "",
    topicTitle: d.topicTitle || "",
    durationMinutes:
      typeof d.durationMinutes === "number" ? d.durationMinutes : 0,
    status: d.status === "ended" ? "ended" : "active",
    startedAt: toIso(d.startedAt),
    endedAt: toIso(d.endedAt),
    actualDurationMinutes:
      typeof d.actualDurationMinutes === "number"
        ? d.actualDurationMinutes
        : 0,
    studentCount: typeof d.studentCount === "number" ? d.studentCount : 0,
    lectureDate: d.lectureDate || "",
    taughtNotes: d.taughtNotes || "",
    summary: d.summary ? serializeSummary(d.summary) : null,
    sessionId: d.sessionId || id,
  };
}

function buildSummaryFromLecture(lectureId, lectureData, courseData, overrides) {
  const d = lectureData || {};
  const c = courseData || {};
  const o = overrides || {};
  return {
    lectureId,
    sessionId: d.sessionId || lectureId,
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    courseCode: c.code || "",
    department: c.department || "",
    semester: c.semester || "",
    section: c.section || "",
    teacherId: d.teacherId || "",
    teacherName: d.teacherName || "",
    chapterId: d.chapterId || "",
    chapterTitle: d.chapterTitle || "",
    topicId: d.topicId || "",
    topicTitle: d.topicTitle || "",
    durationMinutes:
      typeof d.durationMinutes === "number" ? d.durationMinutes : 0,
    actualDurationMinutes:
      typeof o.actualDurationMinutes === "number"
        ? o.actualDurationMinutes
        : typeof d.actualDurationMinutes === "number"
          ? d.actualDurationMinutes
          : 0,
    attendeeCount:
      typeof o.attendeeCount === "number"
        ? o.attendeeCount
        : typeof d.studentCount === "number"
          ? d.studentCount
          : 0,
    lectureDate: d.lectureDate || "",
    taughtNotes: String(o.taughtNotes != null ? o.taughtNotes : d.taughtNotes || "").trim(),
  };
}

async function assertTeacherOwns(uid, courseId) {
  const snap = await getDb().collection("courses").doc(courseId).get();
  if (!snap.exists) {
    return {
      ok: false,
      status: 404,
      error: "not-found",
      message: "Course not found.",
    };
  }
  const data = snap.data() || {};
  if (data.teacherId !== uid) {
    return {
      ok: false,
      status: 403,
      error: "forbidden",
      message: "Only the course teacher can do this.",
    };
  }
  return { ok: true, data, snap };
}

async function assertCanAccessCourse(uid, courseId) {
  const snap = await getDb().collection("courses").doc(courseId).get();
  if (!snap.exists) {
    return {
      ok: false,
      status: 404,
      error: "not-found",
      message: "Course not found.",
    };
  }
  const data = snap.data() || {};
  if (data.teacherId === uid) {
    return { ok: true, data, asTeacher: true, snap };
  }
  const member = await snap.ref.collection("members").doc(uid).get();
  if (member.exists) {
    return { ok: true, data, asTeacher: false, snap };
  }
  return {
    ok: false,
    status: 403,
    error: "forbidden",
    message: "You do not have access to this course.",
  };
}

function slideSignalDocId(studentId, fileIndex, page) {
  const safeFile = fileIndex < 0 ? 0 : fileIndex;
  const safePage = page < 1 ? 1 : page;
  return `${studentId}_${safeFile}_${safePage}`;
}

function normalizeLevel(value) {
  const raw = String(value || "").trim();
  if (raw === "100" || raw === "80" || raw === "60" || raw === "below50") {
    return raw;
  }
  return "";
}

function serializeSlideSignal(id, data) {
  const d = data || {};
  return {
    id,
    sessionId: d.sessionId || "",
    courseId: d.courseId || "",
    teacherId: d.teacherId || "",
    studentId: d.studentId || "",
    studentName: d.studentName || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    slideFileIndex:
      typeof d.slideFileIndex === "number" ? d.slideFileIndex : 0,
    slidePage: typeof d.slidePage === "number" ? d.slidePage : 1,
    level: normalizeLevel(d.level) || "below50",
    createdAt: toIso(d.createdAt),
    updatedAt: toIso(d.updatedAt),
  };
}

function serializeAttendee(id, data) {
  const d = data || {};
  return {
    studentId: d.studentId || id,
    studentName: d.studentName || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    inApp: d.inApp !== false,
    joinedAt: toIso(d.joinedAt),
    lastSeenAt: toIso(d.lastSeenAt),
  };
}

function serializeLiveJoinRequest(id, data) {
  const d = data || {};
  return {
    studentId: d.studentId || id,
    studentName: d.studentName || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    status: d.status || "pending",
    requestedAt: toIso(d.requestedAt),
    respondedAt: toIso(d.respondedAt),
  };
}

function slideSignalsCollection(courseId, sessionId) {
  return liveSessionRef(courseId, sessionId).collection("slideSignals");
}

function joinRequestsCollection(courseId, sessionId) {
  return liveSessionRef(courseId, sessionId).collection("joinRequests");
}

async function acceptLiveJoinInTx(tx, {
  courseId,
  sessionId,
  teacherId,
  studentId,
}) {
  const sessionDoc = liveSessionRef(courseId, sessionId);
  const requestDoc = joinRequestsCollection(courseId, sessionId).doc(studentId);
  const lectureDoc = lectureRef(sessionId);
  const attendeeDoc = lectureDoc.collection("attendees").doc(studentId);

  const session = await tx.get(sessionDoc);
  const request = await tx.get(requestDoc);
  const lecture = await tx.get(lectureDoc);
  const attendee = await tx.get(attendeeDoc);

  if (
    !session.exists ||
    (session.data() || {}).teacherId !== teacherId ||
    (session.data() || {}).status !== "active"
  ) {
    const e = new Error("Live session not found.");
    e.code = "not-found";
    throw e;
  }
  if (!request.exists) {
    const e = new Error("Join request not found.");
    e.code = "not-found";
    throw e;
  }
  const data = request.data() || {};
  if (data.status === "accepted") {
    return { already: true };
  }
  if (data.status !== "pending") {
    const e = new Error("Join request is not pending.");
    e.code = "not-pending";
    throw e;
  }

  tx.update(requestDoc, {
    status: "accepted",
    respondedAt: FieldValue.serverTimestamp(),
  });

  if (!attendee.exists && lecture.exists) {
    tx.set(attendeeDoc, {
      studentId,
      studentName: String(data.studentName || "").trim(),
      studentEmail: String(data.studentEmail || "").trim().toLowerCase(),
      memberId: String(data.memberId || "").trim(),
      inApp: true,
      joinedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
    });
    tx.update(lectureDoc, { studentCount: FieldValue.increment(1) });
  }
  return { already: false };
}


async function readTaughtNotes(lectureId) {
  const ref = lectureRef(lectureId);
  const snap = await ref.get();
  if (snap.exists) {
    const fromLecture = String((snap.data() || {}).taughtNotes || "").trim();
    if (fromLecture) return fromLecture;
  }
  const notesSnap = await ref.collection("teacherNotes").doc("current").get();
  return String((notesSnap.data() || {}).text || "").trim();
}

async function writeTaughtNotes(lectureId, teacherId, notes) {
  const text = String(notes || "").trim();
  if (!text) return "";
  const ref = lectureRef(lectureId);
  let notesSaved = false;
  let lastError = null;
  try {
    await ref.collection("teacherNotes").doc("current").set({
      text,
      teacherId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    notesSaved = true;
  } catch (err) {
    lastError = err;
    console.error("teacherNotes save failed", err.message);
  }
  try {
    await ref.update({ taughtNotes: text });
    notesSaved = true;
  } catch (err) {
    lastError = err;
    console.error("lecture taughtNotes update failed", err.message);
  }
  if (!notesSaved) {
    const e = new Error(lastError ? lastError.message : "notes-save-failed");
    e.code = "notes-save-failed";
    throw e;
  }
  const verified = await readTaughtNotes(lectureId);
  if (!verified) {
    const e = new Error("Lecture notes did not save to the database.");
    e.code = "notes-save-failed";
    throw e;
  }
  return verified;
}

async function saveLectureSummaryDoc(lectureId, teacherId, summary) {
  const ref = lectureRef(lectureId);
  const snap = await ref.get();
  if (!snap.exists || (snap.data() || {}).teacherId !== teacherId) {
    const e = new Error("Only the course teacher can save this summary.");
    e.code = "forbidden";
    throw e;
  }
  if ((snap.data() || {}).status !== "ended") {
    const e = new Error("Summary can only be saved after the lecture ends.");
    e.code = "lecture-active";
    throw e;
  }
  const existing = snap.data() || {};
  const notes =
    String(summary.taughtNotes || "").trim() ||
    String(existing.taughtNotes || "").trim();
  const payload = {
    ...summary,
    lectureId,
    sessionId: summary.sessionId || lectureId,
    teacherId,
    taughtNotes: notes,
  };
  if (notes) {
    await writeTaughtNotes(lectureId, teacherId, notes);
  }
  await ref.update({
    summary: {
      ...payload,
      savedAt: FieldValue.serverTimestamp(),
    },
  });
  return payload;
}

// POST /api/courses/:courseId/live-sessions — start
courseRouter.post("/:courseId/live-sessions", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const body = req.body || {};
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }

    const chapterId = String(body.chapterId || "").trim();
    const topicId = String(body.topicId || "").trim();
    const chapterTitle = String(body.chapterTitle || "").trim();
    const topicTitle = String(body.topicTitle || "").trim();
    const courseName = String(body.courseName || owned.data.name || "").trim();
    const teacherName = String(body.teacherName || "").trim();
    const durationMinutes =
      typeof body.durationMinutes === "number"
        ? body.durationMinutes
        : parseInt(body.durationMinutes, 10) || 0;
    const taughtNotes = String(body.taughtNotes || "").trim();
    const sessionId =
      String(body.id || "").trim() ||
      `${Date.now()}${Math.floor(Math.random() * 1000)}`;

    if (!chapterId || !topicId || durationMinutes <= 0) {
      return sendError(
        res,
        400,
        "invalid-session",
        "chapterId, topicId, and a positive durationMinutes are required."
      );
    }

    const courseRef = getDb().collection("courses").doc(courseId);
    const sessionDoc = liveSessionRef(courseId, sessionId);
    const lectureDoc = lectureRef(sessionId);
    const teacherRef = getDb().collection("users").doc(req.uid);

    await getDb().runTransaction(async (tx) => {
      const course = await tx.get(courseRef);
      const teacher = await tx.get(teacherRef);
      if (!course.exists || (course.data() || {}).teacherId !== req.uid) {
        const e = new Error("Only the course teacher can start a lecture.");
        e.code = "forbidden";
        throw e;
      }
      const activeId = String((course.data() || {}).activeSessionId || "");
      if (activeId) {
        const e = new Error("This course already has an active session.");
        e.code = "course-already-live";
        throw e;
      }
      const teacherActive = String(
        (teacher.data() || {}).activeLiveSessionId || ""
      );
      if (teacherActive) {
        const e = new Error("Teacher already has an active live session.");
        e.code = "teacher-already-live";
        throw e;
      }

      tx.set(sessionDoc, {
        chapterId,
        chapterTitle,
        topicId,
        topicTitle,
        teacherId: req.uid,
        durationMinutes,
        status: "active",
        startedAt: FieldValue.serverTimestamp(),
        endedAt: null,
        createdAt: FieldValue.serverTimestamp(),
        slideFileIndex: 0,
        slidePage: 1,
      });

      const lectureSeed = {
        courseId,
        courseName,
        teacherId: req.uid,
        teacherName,
        chapterId,
        chapterTitle,
        topicId,
        topicTitle,
        durationMinutes,
        status: "active",
        studentCount: 0,
        actualDurationMinutes: 0,
        lectureDate: lectureDateKey(),
        sessionId,
        startedAt: FieldValue.serverTimestamp(),
        endedAt: null,
        createdAt: FieldValue.serverTimestamp(),
      };
      if (taughtNotes) {
        lectureSeed.taughtNotes = taughtNotes;
      }
      tx.set(lectureDoc, lectureSeed);

      tx.update(courseRef, {
        activeSessionId: sessionId,
        isLive: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        teacherRef,
        {
          activeLiveCourseId: courseId,
          activeLiveSessionId: sessionId,
          activeLiveUpdatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    if (taughtNotes) {
      try {
        await writeTaughtNotes(sessionId, req.uid, taughtNotes);
      } catch (err) {
        return sendError(
          res,
          500,
          "notes-save-failed",
          err.message || "Lecture notes did not save."
        );
      }
    }

    const saved = await sessionDoc.get();
    return res.status(201).json({
      session: serializeLiveSession(
        sessionId,
        courseId,
        saved.data() || {
          chapterId,
          chapterTitle,
          topicId,
          topicTitle,
          teacherId: req.uid,
          durationMinutes,
          status: "active",
        }
      ),
    });
  } catch (err) {
    if (err.code === "teacher-already-live") {
      return sendError(
        res,
        409,
        "teacher-already-live",
        "Teacher already has an active live session."
      );
    }
    if (err.code === "course-already-live") {
      return sendError(
        res,
        409,
        "course-already-live",
        "This course already has an active session."
      );
    }
    if (err.code === "forbidden") {
      return sendError(res, 403, "forbidden", err.message);
    }
    console.error("start live session error", err.message);
    return sendError(res, 500, "start-failed", "Could not start live session.");
  }
});

// POST /api/courses/:courseId/live-sessions/:sessionId/end
courseRouter.post(
  "/:courseId/live-sessions/:sessionId/end",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      if (!courseId || !sessionId) {
        return sendError(res, 400, "invalid-id", "courseId and sessionId required.");
      }

      const courseRef = getDb().collection("courses").doc(courseId);
      const sessionDoc = liveSessionRef(courseId, sessionId);
      const lectureDoc = lectureRef(sessionId);
      const teacherRef = getDb().collection("users").doc(req.uid);
      let summary = null;

      await getDb().runTransaction(async (tx) => {
        const course = await tx.get(courseRef);
        const session = await tx.get(sessionDoc);
        const lecture = await tx.get(lectureDoc);
        if (
          !course.exists ||
          !session.exists ||
          (course.data() || {}).teacherId !== req.uid ||
          (session.data() || {}).teacherId !== req.uid
        ) {
          const e = new Error("Only the course teacher can end this lecture.");
          e.code = "forbidden";
          throw e;
        }

        tx.update(sessionDoc, {
          status: "ended",
          endedAt: FieldValue.serverTimestamp(),
        });

        if (lecture.exists) {
          const lectureData = lecture.data() || {};
          let actualMinutes = 0;
          const startedAt = lectureData.startedAt;
          if (startedAt && typeof startedAt.toDate === "function") {
            actualMinutes = Math.min(
              Math.max(
                0,
                Math.floor((Date.now() - startedAt.toDate().getTime()) / 60000)
              ),
              24 * 60
            );
          }
          const studentCount =
            typeof lectureData.studentCount === "number"
              ? lectureData.studentCount
              : 0;
          summary = buildSummaryFromLecture(
            sessionId,
            lectureData,
            course.data() || {},
            { actualDurationMinutes: actualMinutes, attendeeCount: studentCount }
          );
          tx.update(lectureDoc, {
            status: "ended",
            endedAt: FieldValue.serverTimestamp(),
            actualDurationMinutes: actualMinutes,
            studentCount,
          });
        }

        tx.update(courseRef, {
          activeSessionId: "",
          isLive: false,
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(
          teacherRef,
          {
            activeLiveCourseId: "",
            activeLiveSessionId: "",
            activeLiveUpdatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });

      if (summary) {
        try {
          summary = await saveLectureSummaryDoc(sessionId, req.uid, summary);
        } catch (err) {
          console.error("save summary after end failed", err.message);
        }
      }

      const savedSession = await sessionDoc.get();
      return res.json({
        session: serializeLiveSession(
          sessionId,
          courseId,
          savedSession.data() || { status: "ended", teacherId: req.uid }
        ),
        summary: summary ? serializeSummary(summary) : null,
      });
    } catch (err) {
      if (err.code === "forbidden") {
        return sendError(res, 403, "forbidden", err.message);
      }
      console.error("end live session error", err.message);
      return sendError(res, 500, "end-failed", "Could not end live session.");
    }
  }
);

// PATCH /api/courses/:courseId/live-sessions/:sessionId/slide
courseRouter.patch(
  "/:courseId/live-sessions/:sessionId/slide",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      const body = req.body || {};
      let fileIndex =
        typeof body.fileIndex === "number"
          ? body.fileIndex
          : parseInt(body.fileIndex, 10);
      let page =
        typeof body.page === "number" ? body.page : parseInt(body.page, 10);
      if (!Number.isFinite(fileIndex) || fileIndex < 0) fileIndex = 0;
      if (!Number.isFinite(page) || page < 1) page = 1;

      const ref = liveSessionRef(courseId, sessionId);
      const snap = await ref.get();
      if (!snap.exists) {
        return sendError(res, 404, "not-found", "Live session not found.");
      }
      if ((snap.data() || {}).teacherId !== req.uid) {
        return sendError(res, 403, "forbidden", "Only the teacher can update slides.");
      }
      await ref.update({
        slideFileIndex: fileIndex,
        slidePage: page,
        slideUpdatedAt: FieldValue.serverTimestamp(),
      });
      return res.json({
        ok: true,
        slideFileIndex: fileIndex,
        slidePage: page,
      });
    } catch (err) {
      console.error("update slide error", err.message);
      return sendError(res, 500, "update-failed", "Could not update slide position.");
    }
  }
);

// PATCH /api/courses/:courseId/live-sessions/:sessionId/slide-view
// Teacher zoom/pan sync: { fileIndex, page, zoom, cx, cy, ts }.
courseRouter.patch(
  "/:courseId/live-sessions/:sessionId/slide-view",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      const body = req.body || {};
      const num = (v) => (typeof v === "number" ? v : parseFloat(v));
      let fileIndex = parseInt(body.fileIndex, 10);
      if (!Number.isFinite(fileIndex) || fileIndex < 0) fileIndex = 0;
      fileIndex = Math.min(fileIndex, 200);
      let page = parseInt(body.page, 10);
      if (!Number.isFinite(page) || page < 1) page = 1;
      page = Math.min(page, 5000);
      let zoom = num(body.zoom);
      if (!Number.isFinite(zoom) || zoom <= 0) zoom = 1;
      zoom = Math.min(Math.max(zoom, 0.05), 20);
      const centre = (v) => {
        const n = num(v);
        return Number.isFinite(n) ? Math.min(Math.max(n, -1), 2) : 0.5;
      };
      const tsRaw = num(body.ts);
      const ts = Number.isFinite(tsRaw) ? Math.floor(tsRaw) : Date.now();

      const ref = liveSessionRef(courseId, sessionId);
      const snap = await ref.get();
      if (!snap.exists) {
        return sendError(res, 404, "not-found", "Live session not found.");
      }
      const data = snap.data() || {};
      if (data.teacherId !== req.uid) {
        return sendError(res, 403, "forbidden", "Only the teacher can update slides.");
      }
      if (data.status === "ended") {
        return sendError(res, 409, "ended", "Live session has ended.");
      }
      const prev = data.slideView;
      if (prev && typeof prev.ts === "number" && prev.ts > ts) {
        // Out-of-order request; a newer view is already stored.
        return res.json({ ok: true, stale: true });
      }
      const slideView = {
        fileIndex,
        page,
        zoom,
        cx: centre(body.cx),
        cy: centre(body.cy),
        ts,
      };
      await ref.update({
        slideView,
        slideViewUpdatedAt: FieldValue.serverTimestamp(),
      });
      return res.json({ ok: true, slideView });
    } catch (err) {
      console.error("update slide view error", err.message);
      return sendError(res, 500, "update-failed", "Could not update slide view.");
    }
  }
);

// PATCH /api/courses/:courseId/live-sessions/:sessionId/topic
courseRouter.patch(
  "/:courseId/live-sessions/:sessionId/topic",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      const body = req.body || {};
      const topicId = String(body.topicId || "").trim();
      const topicTitle = String(body.topicTitle || "").trim();
      if (!topicId || !topicTitle) {
        return sendError(
          res,
          400,
          "invalid-topic",
          "topicId and topicTitle are required."
        );
      }

      const sessionDoc = liveSessionRef(courseId, sessionId);
      const lectureDoc = lectureRef(sessionId);
      const sessionSnap = await sessionDoc.get();
      if (!sessionSnap.exists) {
        return sendError(res, 404, "not-found", "Live session not found.");
      }
      if ((sessionSnap.data() || {}).teacherId !== req.uid) {
        return sendError(res, 403, "forbidden", "Only the teacher can change topic.");
      }

      const payload = {
        topicId,
        topicTitle,
        topicUpdatedAt: FieldValue.serverTimestamp(),
      };
      const batch = getDb().batch();
      batch.update(sessionDoc, payload);
      const lectureSnap = await lectureDoc.get();
      if (lectureSnap.exists) {
        batch.update(lectureDoc, payload);
      }
      await batch.commit();
      return res.json({ ok: true, topicId, topicTitle });
    } catch (err) {
      console.error("update topic error", err.message);
      return sendError(res, 500, "update-failed", "Could not update session topic.");
    }
  }
);


// PUT /api/courses/:courseId/live-sessions/:sessionId/slide-signals — student upsert
courseRouter.put(
  "/:courseId/live-sessions/:sessionId/slide-signals",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const body = req.body || {};
      const studentId = String(body.studentId || req.uid).trim();
      const studentName = String(body.studentName || "").trim();
      const studentEmail = String(body.studentEmail || "").trim().toLowerCase();
      const memberId = String(body.memberId || "").trim();
      let fileIndex =
        typeof body.fileIndex === "number"
          ? body.fileIndex
          : typeof body.slideFileIndex === "number"
            ? body.slideFileIndex
            : parseInt(body.fileIndex ?? body.slideFileIndex, 10);
      let page =
        typeof body.page === "number"
          ? body.page
          : typeof body.slidePage === "number"
            ? body.slidePage
            : parseInt(body.page ?? body.slidePage, 10);
      const level = normalizeLevel(body.level);

      if (!Number.isFinite(fileIndex) || fileIndex < 0) fileIndex = 0;
      if (!Number.isFinite(page) || page < 1) page = 1;

      if (!courseId || !sessionId || !studentId || !studentName || !level) {
        return sendError(
          res,
          400,
          "invalid-signal",
          "studentName, level (100|80|60|below50), and session ids are required."
        );
      }
      if (studentId !== req.uid) {
        return sendError(
          res,
          403,
          "forbidden",
          "You can only submit your own slide signal."
        );
      }

      const access = await assertCanAccessCourse(req.uid, courseId);
      if (!access.ok) {
        return sendError(res, access.status, access.error, access.message);
      }

      const sessionSnap = await liveSessionRef(courseId, sessionId).get();
      if (!sessionSnap.exists || (sessionSnap.data() || {}).status !== "active") {
        return sendError(res, 404, "not-found", "Live session not found.");
      }
      const sessionData = sessionSnap.data() || {};
      const id = slideSignalDocId(studentId, fileIndex, page);
      const ref = slideSignalsCollection(courseId, sessionId).doc(id);
      const existing = await ref.get();
      const payload = {
        sessionId,
        courseId,
        teacherId: sessionData.teacherId || "",
        studentId,
        studentName,
        studentEmail,
        memberId,
        slideFileIndex: fileIndex,
        slidePage: page,
        level,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        payload.createdAt = FieldValue.serverTimestamp();
      }
      await ref.set(payload, { merge: true });
      const snap = await ref.get();
      return res.status(existing.exists ? 200 : 201).json({
        signal: serializeSlideSignal(id, snap.data() || payload),
      });
    } catch (err) {
      console.error("upsert slide-signal error", err.message);
      return sendError(res, 500, "save-failed", "Could not save slide signal.");
    }
  }
);

// GET /api/courses/:courseId/live-sessions/:sessionId/slide-signals — one-shot list
courseRouter.get(
  "/:courseId/live-sessions/:sessionId/slide-signals",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const access = await assertCanAccessCourse(req.uid, courseId);
      if (!access.ok) {
        return sendError(res, access.status, access.error, access.message);
      }
      const sessionSnap = await liveSessionRef(courseId, sessionId).get();
      if (!sessionSnap.exists) {
        return sendError(res, 404, "not-found", "Live session not found.");
      }

      let query = slideSignalsCollection(courseId, sessionId);
      // Students only see their own docs on one-shot list unless teacher.
      if (!access.asTeacher) {
        query = query.where("studentId", "==", req.uid);
      }
      const snap = await query.get();
      const signals = snap.docs
        .map((doc) => serializeSlideSignal(doc.id, doc.data()))
        .sort((a, b) => {
          if (a.slideFileIndex !== b.slideFileIndex) {
            return a.slideFileIndex - b.slideFileIndex;
          }
          if (a.slidePage !== b.slidePage) {
            return a.slidePage - b.slidePage;
          }
          return String(a.studentName).localeCompare(String(b.studentName));
        });
      return res.json({ signals });
    } catch (err) {
      console.error("list slide-signals error", err.message);
      return sendError(res, 500, "list-failed", "Could not list slide signals.");
    }
  }
);

// GET /api/courses/:courseId/live-sessions/:sessionId/slide-signals/me
courseRouter.get(
  "/:courseId/live-sessions/:sessionId/slide-signals/me",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const access = await assertCanAccessCourse(req.uid, courseId);
      if (!access.ok) {
        return sendError(res, access.status, access.error, access.message);
      }
      const sessionSnap = await liveSessionRef(courseId, sessionId).get();
      if (!sessionSnap.exists) {
        return sendError(res, 404, "not-found", "Live session not found.");
      }

      const fileIndexRaw = req.query.fileIndex ?? req.query.slideFileIndex;
      const pageRaw = req.query.page ?? req.query.slidePage;
      if (fileIndexRaw != null && pageRaw != null) {
        let fileIndex = parseInt(fileIndexRaw, 10);
        let page = parseInt(pageRaw, 10);
        if (!Number.isFinite(fileIndex) || fileIndex < 0) fileIndex = 0;
        if (!Number.isFinite(page) || page < 1) page = 1;
        const id = slideSignalDocId(req.uid, fileIndex, page);
        const snap = await slideSignalsCollection(courseId, sessionId)
          .doc(id)
          .get();
        return res.json({
          signal: snap.exists
            ? serializeSlideSignal(snap.id, snap.data())
            : null,
        });
      }

      const snap = await slideSignalsCollection(courseId, sessionId)
        .where("studentId", "==", req.uid)
        .get();
      const signals = snap.docs
        .map((doc) => serializeSlideSignal(doc.id, doc.data()))
        .sort((a, b) => {
          if (a.slideFileIndex !== b.slideFileIndex) {
            return a.slideFileIndex - b.slideFileIndex;
          }
          return a.slidePage - b.slidePage;
        });
      return res.json({ signals });
    } catch (err) {
      console.error("get my slide-signals error", err.message);
      return sendError(res, 500, "get-failed", "Could not load slide signals.");
    }
  }
);

// POST /api/courses/:courseId/live-sessions/:sessionId/join-requests
courseRouter.post(
  "/:courseId/live-sessions/:sessionId/join-requests",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const body = req.body || {};
      const studentId = String(body.studentId || req.uid).trim();
      const studentName = String(body.studentName || "").trim();
      const studentEmail = String(body.studentEmail || "").trim().toLowerCase();
      const memberId = String(body.memberId || "").trim();

      if (!courseId || !sessionId || !studentId || !studentName) {
        return sendError(
          res,
          400,
          "invalid-join",
          "studentName and session ids are required."
        );
      }
      if (studentId !== req.uid) {
        return sendError(
          res,
          403,
          "forbidden",
          "You can only request join for yourself."
        );
      }

      const access = await assertCanAccessCourse(req.uid, courseId);
      if (!access.ok) {
        return sendError(res, access.status, access.error, access.message);
      }

      const sessionDoc = liveSessionRef(courseId, sessionId);
      const requestDoc = joinRequestsCollection(courseId, sessionId).doc(
        studentId
      );
      let created = false;
      let existingData = null;

      await getDb().runTransaction(async (tx) => {
        const session = await tx.get(sessionDoc);
        const existing = await tx.get(requestDoc);
        if (!session.exists || (session.data() || {}).status !== "active") {
          const e = new Error("Live session not found.");
          e.code = "not-found";
          throw e;
        }
        if (existing.exists) {
          existingData = existing.data() || {};
          return;
        }
        tx.set(requestDoc, {
          studentId,
          studentName,
          studentEmail,
          memberId,
          status: "pending",
          requestedAt: FieldValue.serverTimestamp(),
        });
        created = true;
      });

      if (!created) {
        return res.json({
          ok: true,
          created: false,
          request: serializeLiveJoinRequest(studentId, existingData),
        });
      }
      const snap = await requestDoc.get();
      return res.status(201).json({
        ok: true,
        created: true,
        request: serializeLiveJoinRequest(
          studentId,
          snap.data() || {
            studentId,
            studentName,
            studentEmail,
            memberId,
            status: "pending",
          }
        ),
      });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      console.error("live join-request error", err.message);
      return sendError(res, 500, "join-failed", "Could not create join request.");
    }
  }
);

// POST accept-all (before :studentId/accept)
courseRouter.post(
  "/:courseId/live-sessions/:sessionId/join-requests/accept-all",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }

      const sessionSnap = await liveSessionRef(courseId, sessionId).get();
      if (
        !sessionSnap.exists ||
        (sessionSnap.data() || {}).teacherId !== req.uid ||
        (sessionSnap.data() || {}).status !== "active"
      ) {
        return sendError(res, 404, "not-found", "Live session not found.");
      }

      const pendingSnap = await joinRequestsCollection(courseId, sessionId)
        .where("status", "==", "pending")
        .get();
      let accepted = 0;
      for (const doc of pendingSnap.docs) {
        await getDb().runTransaction(async (tx) => {
          const result = await acceptLiveJoinInTx(tx, {
            courseId,
            sessionId,
            teacherId: req.uid,
            studentId: doc.id,
          });
          if (!result.already) accepted += 1;
        });
      }
      return res.json({ ok: true, accepted, pending: pendingSnap.size });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      if (err.code === "not-pending") {
        return sendError(res, 409, "not-pending", err.message);
      }
      console.error("accept-all join error", err.message);
      return sendError(res, 500, "accept-failed", "Could not accept join requests.");
    }
  }
);

// POST /api/courses/:courseId/live-sessions/:sessionId/join-requests/:studentId/accept
courseRouter.post(
  "/:courseId/live-sessions/:sessionId/join-requests/:studentId/accept",
  requireAuth,
  async (req, res) => {
    try {
      const courseId = String(req.params.courseId || "").trim();
      const sessionId = String(req.params.sessionId || "").trim();
      const studentId = String(req.params.studentId || "").trim();
      const owned = await assertTeacherOwns(req.uid, courseId);
      if (!owned.ok) {
        return sendError(res, owned.status, owned.error, owned.message);
      }
      if (!studentId) {
        return sendError(res, 400, "invalid-join", "studentId is required.");
      }

      await getDb().runTransaction(async (tx) => {
        await acceptLiveJoinInTx(tx, {
          courseId,
          sessionId,
          teacherId: req.uid,
          studentId,
        });
      });

      const requestSnap = await joinRequestsCollection(courseId, sessionId)
        .doc(studentId)
        .get();
      return res.json({
        ok: true,
        request: requestSnap.exists
          ? serializeLiveJoinRequest(studentId, requestSnap.data())
          : null,
      });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      if (err.code === "not-pending") {
        return sendError(res, 409, "not-pending", err.message);
      }
      console.error("accept live join error", err.message);
      return sendError(res, 500, "accept-failed", "Could not accept join request.");
    }
  }
);

// GET /api/lectures — list (teacher), optional ?courseId=
lecturesRouter.get("/", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.query.courseId || "").trim();
    const teacherId = String(req.query.teacherId || req.uid).trim();
    if (teacherId !== req.uid) {
      return sendError(
        res,
        403,
        "forbidden",
        "You can only list your own lectures."
      );
    }
    const limitRaw = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(limitRaw)
      ? Math.min(Math.max(limitRaw, 1), 400)
      : 400;

    const snap = await getDb()
      .collection("lectures")
      .where("teacherId", "==", teacherId)
      .limit(limit)
      .get();

    let items = snap.docs.map((doc) => serializeLecture(doc.id, doc.data()));
    if (courseId) {
      items = items.filter((item) => item.courseId === courseId);
    }
    items.sort((a, b) => {
      const left = a.endedAt || a.startedAt || "";
      const right = b.endedAt || b.startedAt || "";
      return String(right).localeCompare(String(left));
    });
    return res.json({ lectures: items });
  } catch (err) {
    console.error("list lectures error", err.message);
    return sendError(res, 500, "list-failed", "Could not list lectures.");
  }
});


// POST /api/lectures/attendees/batch — one-shot map for analytics (before :lectureId)
lecturesRouter.post("/attendees/batch", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const raw = Array.isArray(body.lectureIds) ? body.lectureIds : [];
    const ids = [
      ...new Set(
        raw
          .map((id) => String(id || "").trim())
          .filter(Boolean)
      ),
    ].slice(0, 20);
    if (ids.length === 0) {
      return res.json({ attendeesByLecture: {} });
    }

    const entries = await Promise.all(
      ids.map(async (lectureId) => {
        const lectureSnap = await lectureRef(lectureId).get();
        if (!lectureSnap.exists) {
          return [lectureId, []];
        }
        const data = lectureSnap.data() || {};
        if (data.teacherId !== req.uid) {
          const access = await assertCanAccessCourse(req.uid, data.courseId || "");
          if (!access.ok) {
            return [lectureId, []];
          }
        }
        const attSnap = await lectureRef(lectureId)
          .collection("attendees")
          .get();
        return [
          lectureId,
          attSnap.docs.map((doc) => serializeAttendee(doc.id, doc.data())),
        ];
      })
    );

    const attendeesByLecture = {};
    for (const [id, list] of entries) {
      attendeesByLecture[id] = list;
    }
    return res.json({ attendeesByLecture });
  } catch (err) {
    console.error("batch attendees error", err.message);
    return sendError(res, 500, "list-failed", "Could not load attendees.");
  }
});

// GET /api/lectures/:lectureId
lecturesRouter.get("/:lectureId", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const snap = await lectureRef(lectureId).get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Lecture not found.");
    }
    const data = snap.data() || {};
    const access = await assertCanAccessCourse(req.uid, data.courseId || "");
    if (!access.ok && data.teacherId !== req.uid) {
      return sendError(res, access.status || 403, access.error || "forbidden", access.message || "Forbidden.");
    }
    return res.json({ lecture: serializeLecture(lectureId, data) });
  } catch (err) {
    console.error("get lecture error", err.message);
    return sendError(res, 500, "get-failed", "Could not load lecture.");
  }
});

// PATCH /api/lectures/:lectureId/summary
lecturesRouter.patch("/:lectureId/summary", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const body = req.body || {};
    const summaryBody = body.summary && typeof body.summary === "object"
      ? body.summary
      : body;
    const snap = await lectureRef(lectureId).get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Lecture not found.");
    }
    const data = snap.data() || {};
    if (data.teacherId !== req.uid) {
      return sendError(res, 403, "forbidden", "Only the course teacher can save this summary.");
    }
    if (data.status !== "ended") {
      return sendError(
        res,
        409,
        "lecture-active",
        "Summary can only be saved after the lecture ends."
      );
    }

    let courseData = {};
    if (data.courseId) {
      const courseSnap = await getDb().collection("courses").doc(data.courseId).get();
      courseData = courseSnap.exists ? courseSnap.data() || {} : {};
    }

    const base = buildSummaryFromLecture(lectureId, data, courseData, {
      actualDurationMinutes:
        typeof summaryBody.actualDurationMinutes === "number"
          ? summaryBody.actualDurationMinutes
          : data.actualDurationMinutes,
      attendeeCount:
        typeof summaryBody.attendeeCount === "number"
          ? summaryBody.attendeeCount
          : data.studentCount,
      taughtNotes:
        summaryBody.taughtNotes != null
          ? summaryBody.taughtNotes
          : data.taughtNotes,
    });

    // Allow client to override display fields from summary body.
    const merged = {
      ...base,
      courseName: String(summaryBody.courseName || base.courseName || "").trim(),
      courseCode: String(summaryBody.courseCode || base.courseCode || "").trim(),
      department: String(summaryBody.department || base.department || "").trim(),
      semester: String(summaryBody.semester || base.semester || "").trim(),
      section: String(summaryBody.section || base.section || "").trim(),
      teacherName: String(summaryBody.teacherName || base.teacherName || "").trim(),
      chapterTitle: String(summaryBody.chapterTitle || base.chapterTitle || "").trim(),
      topicTitle: String(summaryBody.topicTitle || base.topicTitle || "").trim(),
      lectureDate: String(summaryBody.lectureDate || base.lectureDate || "").trim(),
      durationMinutes:
        typeof summaryBody.durationMinutes === "number"
          ? summaryBody.durationMinutes
          : base.durationMinutes,
    };

    const saved = await saveLectureSummaryDoc(lectureId, req.uid, merged);
    return res.json({ summary: serializeSummary(saved) });
  } catch (err) {
    if (err.code === "forbidden") {
      return sendError(res, 403, "forbidden", err.message);
    }
    if (err.code === "lecture-active") {
      return sendError(res, 409, "lecture-active", err.message);
    }
    if (err.code === "notes-save-failed") {
      return sendError(res, 500, "notes-save-failed", err.message);
    }
    console.error("save summary error", err.message);
    return sendError(res, 500, "save-failed", "Could not save lecture summary.");
  }
});

// GET /api/lectures/:lectureId/taught-notes
lecturesRouter.get("/:lectureId/taught-notes", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const snap = await lectureRef(lectureId).get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Lecture not found.");
    }
    const data = snap.data() || {};
    const access = await assertCanAccessCourse(req.uid, data.courseId || "");
    if (!access.ok && data.teacherId !== req.uid) {
      return sendError(
        res,
        access.status || 403,
        access.error || "forbidden",
        access.message || "Forbidden."
      );
    }
    const text = await readTaughtNotes(lectureId);
    return res.json({ text, lectureId });
  } catch (err) {
    console.error("load taught notes error", err.message);
    return sendError(res, 500, "load-failed", "Could not load taught notes.");
  }
});

// PUT /api/lectures/:lectureId/taught-notes
lecturesRouter.put("/:lectureId/taught-notes", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const text = String((req.body || {}).text || (req.body || {}).taughtNotes || "").trim();
    const snap = await lectureRef(lectureId).get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Lecture not found.");
    }
    if ((snap.data() || {}).teacherId !== req.uid) {
      return sendError(res, 403, "forbidden", "Only the teacher can save taught notes.");
    }
    if (!text) {
      return sendError(res, 400, "invalid-notes", "Taught notes text is required.");
    }
    const saved = await writeTaughtNotes(lectureId, req.uid, text);
    return res.json({ text: saved, lectureId });
  } catch (err) {
    if (err.code === "notes-save-failed") {
      return sendError(res, 500, "notes-save-failed", err.message);
    }
    console.error("save taught notes error", err.message);
    return sendError(res, 500, "save-failed", "Could not save taught notes.");
  }
});

// POST /api/lectures/:lectureId/attendees — mark attendance (one-shot)
lecturesRouter.post("/:lectureId/attendees", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const body = req.body || {};
    const studentId = String(body.studentId || req.uid).trim();
    const studentName = String(body.studentName || "").trim();
    const studentEmail = String(body.studentEmail || "").trim().toLowerCase();
    const memberId = String(body.memberId || "").trim();

    if (!lectureId || !studentId || !studentName) {
      return sendError(
        res,
        400,
        "invalid-attendee",
        "lectureId, studentId, and studentName are required."
      );
    }
    // Students may only mark themselves.
    if (studentId !== req.uid) {
      return sendError(
        res,
        403,
        "forbidden",
        "You can only mark your own attendance."
      );
    }

    const lectureDoc = lectureRef(lectureId);
    const attendeeDoc = lectureDoc.collection("attendees").doc(studentId);
    let created = false;

    await getDb().runTransaction(async (tx) => {
      const lecture = await tx.get(lectureDoc);
      const existing = await tx.get(attendeeDoc);
      if (!lecture.exists) {
        const e = new Error("Lecture not found.");
        e.code = "not-found";
        throw e;
      }
      const status = String((lecture.data() || {}).status || "");
      if (status !== "active" && status !== "ended") {
        return;
      }
      if (existing.exists) {
        return;
      }
      tx.set(attendeeDoc, {
        studentId,
        studentName,
        studentEmail,
        memberId,
        inApp: true,
        joinedAt: FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
      });
      tx.update(lectureDoc, { studentCount: FieldValue.increment(1) });
      created = true;
    });

    return res.status(created ? 201 : 200).json({
      ok: true,
      created,
      attendee: {
        studentId,
        studentName,
        studentEmail,
        memberId,
        inApp: true,
      },
    });
  } catch (err) {
    if (err.code === "not-found") {
      return sendError(res, 404, "not-found", err.message);
    }
    console.error("mark attendance error", err.message);
    return sendError(res, 500, "mark-failed", "Could not mark attendance.");
  }
});


// GET /api/lectures/:lectureId/attendees — one-shot list
lecturesRouter.get("/:lectureId/attendees", requireAuth, async (req, res) => {
  try {
    const lectureId = String(req.params.lectureId || "").trim();
    const snap = await lectureRef(lectureId).get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Lecture not found.");
    }
    const data = snap.data() || {};
    const access = await assertCanAccessCourse(req.uid, data.courseId || "");
    if (!access.ok && data.teacherId !== req.uid) {
      return sendError(
        res,
        access.status || 403,
        access.error || "forbidden",
        access.message || "Forbidden."
      );
    }
    const attSnap = await lectureRef(lectureId).collection("attendees").get();
    const attendees = attSnap.docs
      .map((doc) => serializeAttendee(doc.id, doc.data()))
      .sort((a, b) => String(a.joinedAt || "").localeCompare(String(b.joinedAt || "")));
    return res.json({ attendees });
  } catch (err) {
    console.error("list attendees error", err.message);
    return sendError(res, 500, "list-failed", "Could not list attendees.");
  }
});

// PATCH /api/lectures/:lectureId/attendees/:studentId/presence — best-effort heartbeat write
lecturesRouter.patch(
  "/:lectureId/attendees/:studentId/presence",
  requireAuth,
  async (req, res) => {
    try {
      const lectureId = String(req.params.lectureId || "").trim();
      const studentId = String(req.params.studentId || "").trim();
      const body = req.body || {};
      const inApp = body.inApp !== false && body.inApp !== "false";

      if (!lectureId || !studentId) {
        return sendError(res, 400, "invalid-presence", "lectureId and studentId required.");
      }
      if (studentId !== req.uid) {
        return sendError(
          res,
          403,
          "forbidden",
          "You can only update your own presence."
        );
      }

      const attendeeDoc = lectureRef(lectureId)
        .collection("attendees")
        .doc(studentId);
      try {
        await attendeeDoc.update({
          inApp: Boolean(inApp),
          lastSeenAt: FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Best-effort: missing doc / races are ignored (matches Flutter store).
        return res.json({ ok: true, updated: false });
      }
      return res.json({ ok: true, updated: true, inApp: Boolean(inApp) });
    } catch (err) {
      console.error("presence update error", err.message);
      return sendError(res, 500, "update-failed", "Could not update presence.");
    }
  }
);

module.exports = { courseRouter, lecturesRouter };
