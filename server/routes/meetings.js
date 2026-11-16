const express = require("express");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

const STATUS = {
  pending: "pending",
  accepted: "accepted",
  declined: "declined",
  completed: "completed",
  rescheduleRequested: "rescheduleRequested",
};

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

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function serializeMeeting(id, data) {
  const d = data || {};
  return {
    id,
    studentId: d.studentId || "",
    studentName: d.studentName || "",
    studentEmail: d.studentEmail || "",
    memberId: d.memberId || "",
    teacherId: d.teacherId || "",
    teacherName: d.teacherName || "",
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    chapterId: d.chapterId || "",
    chapterTitle: d.chapterTitle || "",
    topicId: d.topicId || "",
    topicTitle: d.topicTitle || "",
    lectureId: d.lectureId || "",
    reason: d.reason || "",
    status: d.status || STATUS.pending,
    teacherNote: d.teacherNote || "",
    rescheduleNote: d.rescheduleNote || "",
    requestedAt: toIso(d.requestedAt),
    scheduledAt: toIso(d.scheduledAt),
    respondedAt: toIso(d.respondedAt),
    completedAt: toIso(d.completedAt),
  };
}

function sortByRequestedDesc(a, b) {
  const left = a.requestedAt || "";
  const right = b.requestedAt || "";
  return right.localeCompare(left);
}

function needsTeacherAction(status) {
  return status === STATUS.pending || status === STATUS.rescheduleRequested;
}

function collection() {
  return getDb().collection("meetingRequests");
}

// POST /api/meeting-requests — student create (matches MeetingStore.createRequest)
router.post("/", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const studentId = req.uid;
    const studentName = String(body.studentName || "").trim();
    const teacherId = String(body.teacherId || "").trim();
    const teacherName = String(body.teacherName || "").trim();
    const courseId = String(body.courseId || "").trim();
    const courseName = String(body.courseName || "").trim();
    const topicTitle = String(body.topicTitle || "").trim();
    const reason = String(body.reason || "").trim();

    if (
      !studentId ||
      !teacherId ||
      !courseId ||
      !topicTitle ||
      !reason ||
      !studentName
    ) {
      return sendError(
        res,
        400,
        "invalid-request",
        "A complete meeting request is required."
      );
    }
    if (studentId === teacherId) {
      return sendError(
        res,
        400,
        "invalid-request",
        "Students can only request meetings with a teacher."
      );
    }

    const draft = {
      studentId,
      studentName,
      studentEmail: String(body.studentEmail || "")
        .trim()
        .toLowerCase(),
      memberId: String(body.memberId || "").trim(),
      teacherId,
      teacherName,
      courseId,
      courseName,
      chapterId: String(body.chapterId || "").trim(),
      chapterTitle: String(body.chapterTitle || "").trim(),
      topicId: String(body.topicId || "").trim(),
      topicTitle,
      reason,
      status: STATUS.pending,
      teacherNote: "",
      requestedAt: FieldValue.serverTimestamp(),
      scheduledAt: null,
      respondedAt: null,
      completedAt: null,
    };
    const lectureId = String(body.lectureId || "").trim();
    if (lectureId) {
      draft.lectureId = lectureId;
    }

    const doc = collection().doc();
    await doc.set(draft);
    const snap = await doc.get();
    return res.status(201).json({
      request: serializeMeeting(snap.id, snap.data() || draft),
    });
  } catch (err) {
    console.error("POST /api/meeting-requests", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/meeting-requests/mine — student list
router.get("/mine", requireAuth, async (req, res) => {
  try {
    const snap = await collection()
      .where("studentId", "==", req.uid)
      .get();
    const items = snap.docs
      .map((doc) => serializeMeeting(doc.id, doc.data()))
      .sort(sortByRequestedDesc);
    return res.json({ requests: items });
  } catch (err) {
    console.error("GET /api/meeting-requests/mine", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/meeting-requests/mine-as-teacher — teacher list
router.get("/mine-as-teacher", requireAuth, async (req, res) => {
  try {
    const snap = await collection()
      .where("teacherId", "==", req.uid)
      .get();
    const items = snap.docs
      .map((doc) => serializeMeeting(doc.id, doc.data()))
      .sort(sortByRequestedDesc);
    return res.json({ requests: items });
  } catch (err) {
    console.error("GET /api/meeting-requests/mine-as-teacher", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/meeting-requests/pending-count — teacher pending + rescheduleRequested
router.get("/pending-count", requireAuth, async (req, res) => {
  try {
    const snap = await collection()
      .where("teacherId", "==", req.uid)
      .get();
    let count = 0;
    for (const doc of snap.docs) {
      const status = (doc.data() || {}).status || STATUS.pending;
      if (needsTeacherAction(status)) count += 1;
    }
    return res.json({ count });
  } catch (err) {
    console.error("GET /api/meeting-requests/pending-count", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// GET /api/meeting-requests/:requestId
router.get("/:requestId", requireAuth, async (req, res) => {
  try {
    const requestId = String(req.params.requestId || "").trim();
    if (!requestId) {
      return sendError(res, 400, "invalid-request", "requestId is required.");
    }
    const snap = await collection().doc(requestId).get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "Meeting request not found.");
    }
    const data = snap.data() || {};
    if (data.studentId !== req.uid && data.teacherId !== req.uid) {
      return sendError(
        res,
        403,
        "forbidden",
        "Only the student or teacher can view this request."
      );
    }
    return res.json({ request: serializeMeeting(snap.id, data) });
  } catch (err) {
    console.error("GET /api/meeting-requests/:requestId", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

async function respondAsTeacher({
  req,
  res,
  status,
  allowFromStatuses,
  scheduledAt,
  teacherNote,
}) {
  const requestId = String(req.params.requestId || "").trim();
  const teacherId = req.uid;
  if (!requestId) {
    return sendError(res, 400, "invalid-request", "requestId is required.");
  }
  if (status === STATUS.accepted && !scheduledAt) {
    return sendError(
      res,
      400,
      "invalid-request",
      "Choose a meeting date and time before accepting."
    );
  }

  const ref = collection().doc(requestId);
  try {
    await getDb().runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) {
        const err = new Error("Meeting request not found.");
        err.code = "not-found";
        throw err;
      }
      const data = snap.data() || {};
      if (data.teacherId !== teacherId) {
        const err = new Error(
          "Only the assigned teacher can update this request."
        );
        err.code = "forbidden";
        throw err;
      }
      const current = data.status || STATUS.pending;
      if (!allowFromStatuses.includes(current)) {
        const err = new Error("This request cannot be updated right now.");
        err.code = "conflict";
        throw err;
      }
      const payload = {
        status,
        teacherNote: String(teacherNote || "").trim(),
        respondedAt: FieldValue.serverTimestamp(),
      };
      if (status === STATUS.accepted) {
        payload.scheduledAt = Timestamp.fromDate(scheduledAt);
      } else {
        payload.scheduledAt = null;
      }
      transaction.update(ref, payload);
    });
  } catch (err) {
    if (err.code === "not-found") {
      return sendError(res, 404, "not-found", err.message);
    }
    if (err.code === "forbidden") {
      return sendError(res, 403, "forbidden", err.message);
    }
    if (err.code === "conflict") {
      return sendError(res, 409, "conflict", err.message);
    }
    throw err;
  }

  const snap = await ref.get();
  return res.json({ request: serializeMeeting(snap.id, snap.data()) });
}

// POST /api/meeting-requests/:requestId/accept
router.post("/:requestId/accept", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    const scheduledRaw = body.scheduledAt;
    const scheduledAt = toDate(scheduledRaw);
    if (!scheduledAt) {
      return sendError(
        res,
        400,
        "invalid-request",
        "Choose a meeting date and time before accepting."
      );
    }
    return await respondAsTeacher({
      req,
      res,
      status: STATUS.accepted,
      allowFromStatuses: [STATUS.pending, STATUS.rescheduleRequested],
      scheduledAt,
      teacherNote: body.teacherNote,
    });
  } catch (err) {
    console.error("POST /api/meeting-requests/:id/accept", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// POST /api/meeting-requests/:requestId/decline
router.post("/:requestId/decline", requireAuth, async (req, res) => {
  try {
    const body = req.body || {};
    return await respondAsTeacher({
      req,
      res,
      status: STATUS.declined,
      allowFromStatuses: [STATUS.pending],
      scheduledAt: null,
      teacherNote: body.teacherNote,
    });
  } catch (err) {
    console.error("POST /api/meeting-requests/:id/decline", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// POST /api/meeting-requests/:requestId/reschedule — student
router.post("/:requestId/reschedule", requireAuth, async (req, res) => {
  try {
    const requestId = String(req.params.requestId || "").trim();
    const studentId = req.uid;
    const note = String((req.body || {}).note || "").trim();
    if (!requestId) {
      return sendError(res, 400, "invalid-request", "requestId is required.");
    }

    const ref = collection().doc(requestId);
    try {
      await getDb().runTransaction(async (transaction) => {
        const snap = await transaction.get(ref);
        if (!snap.exists) {
          const err = new Error("Meeting request not found.");
          err.code = "not-found";
          throw err;
        }
        const data = snap.data() || {};
        if (data.studentId !== studentId) {
          const err = new Error("Only the student can request a reschedule.");
          err.code = "forbidden";
          throw err;
        }
        if (data.status !== STATUS.accepted) {
          const err = new Error("Only accepted meetings can be rescheduled.");
          err.code = "conflict";
          throw err;
        }
        const payload = {
          status: STATUS.rescheduleRequested,
          rescheduleRequestedAt: FieldValue.serverTimestamp(),
        };
        if (note) {
          payload.rescheduleNote = note;
        }
        transaction.update(ref, payload);
      });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      if (err.code === "forbidden") {
        return sendError(res, 403, "forbidden", err.message);
      }
      if (err.code === "conflict") {
        return sendError(res, 409, "conflict", err.message);
      }
      throw err;
    }

    const snap = await ref.get();
    return res.json({ request: serializeMeeting(snap.id, snap.data()) });
  } catch (err) {
    console.error("POST /api/meeting-requests/:id/reschedule", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

// POST /api/meeting-requests/:requestId/complete — teacher
router.post("/:requestId/complete", requireAuth, async (req, res) => {
  try {
    const requestId = String(req.params.requestId || "").trim();
    const teacherId = req.uid;
    if (!requestId) {
      return sendError(res, 400, "invalid-request", "requestId is required.");
    }

    const ref = collection().doc(requestId);
    try {
      await getDb().runTransaction(async (transaction) => {
        const snap = await transaction.get(ref);
        if (!snap.exists) {
          const err = new Error("Meeting request not found.");
          err.code = "not-found";
          throw err;
        }
        const data = snap.data() || {};
        if (data.teacherId !== teacherId) {
          const err = new Error(
            "Only the assigned teacher can update this request."
          );
          err.code = "forbidden";
          throw err;
        }
        if (data.status !== STATUS.accepted) {
          const err = new Error("Only accepted meetings can be completed.");
          err.code = "conflict";
          throw err;
        }
        const scheduled = toDate(data.scheduledAt);
        if (!scheduled || Date.now() < scheduled.getTime()) {
          const err = new Error(
            "Meeting can be completed only after the scheduled time."
          );
          err.code = "conflict";
          throw err;
        }
        transaction.update(ref, {
          status: STATUS.completed,
          completedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      if (err.code === "not-found") {
        return sendError(res, 404, "not-found", err.message);
      }
      if (err.code === "forbidden") {
        return sendError(res, 403, "forbidden", err.message);
      }
      if (err.code === "conflict") {
        return sendError(res, 409, "conflict", err.message);
      }
      throw err;
    }

    const snap = await ref.get();
    return res.json({ request: serializeMeeting(snap.id, snap.data()) });
  } catch (err) {
    console.error("POST /api/meeting-requests/:id/complete", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

module.exports = router;
