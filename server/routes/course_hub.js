const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

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

function parseDate(raw) {
  if (raw == null || raw === "") return null;
  if (typeof raw.toDate === "function") {
    try {
      return raw.toDate();
    } catch (_) {
      return null;
    }
  }
  if (raw instanceof Date) return Number.isNaN(raw.getTime()) ? null : raw;
  if (typeof raw === "string" || typeof raw === "number") {
    const d = new Date(raw);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function newItemId() {
  return String(Date.now()) + String(Math.floor(Math.random() * 1000));
}

function cleanNulls(obj) {
  const out = {};
  for (const [key, value] of Object.entries(obj || {})) {
    if (value !== null && value !== undefined) out[key] = value;
  }
  return out;
}

function attachmentsFrom(body) {
  const attachments = Array.isArray(body.attachments) ? body.attachments : [];
  const normalized = attachments
    .filter((item) => item && typeof item === "object")
    .map((item) => ({
      name: String(item.name || "").trim(),
      url: String(item.url || "").trim(),
    }))
    .filter((item) => item.url);
  if (normalized.length > 0) {
    return {
      attachments: normalized,
      attachmentName: normalized[0].name || "",
      attachmentUrl: normalized[0].url || "",
    };
  }
  const url = String(body.attachmentUrl || "").trim();
  if (!url) {
    return {
      attachments: [],
      attachmentName: "",
      attachmentUrl: "",
    };
  }
  const name = String(body.attachmentName || "").trim() || url;
  return {
    attachments: [{ name, url }],
    attachmentName: name,
    attachmentUrl: url,
  };
}

function serializeAttachment(item) {
  const d = item || {};
  return {
    name: d.name || "",
    url: d.url || "",
  };
}

function serializeAnnouncement(item) {
  const d = item || {};
  return {
    id: d.id || "",
    text: d.text || "",
    createdAt: toIso(d.createdAt),
  };
}

function serializeSyllabusWeek(item) {
  const d = item || {};
  return {
    id: d.id || "",
    weekNumber: typeof d.weekNumber === "number" ? d.weekNumber : 1,
    title: d.title || "",
    readings: d.readings || "",
    notes: d.notes || "",
  };
}

function serializeLecture(item) {
  const d = item || {};
  const att = attachmentsFrom(d);
  return {
    id: d.id || "",
    title: d.title || "",
    date: toIso(d.date),
    description: d.description || "",
    ...att,
  };
}

function serializeAssignment(item) {
  const d = item || {};
  const att = attachmentsFrom(d);
  return {
    id: d.id || "",
    title: d.title || "",
    dueDate: toIso(d.dueDate),
    points: typeof d.points === "number" ? d.points : 0,
    description: d.description || "",
    published: d.published !== false,
    ...att,
  };
}

function serializeResource(item) {
  const d = item || {};
  const att = attachmentsFrom(d);
  const links = Array.isArray(d.links)
    ? d.links.map((v) => String(v || "").trim()).filter(Boolean)
    : [];
  return {
    id: d.id || "",
    title: d.title || "",
    type: d.type || "",
    detail: d.detail || "",
    ...att,
    links,
  };
}

function asMaps(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((item) => item && typeof item === "object")
    .map((item) => ({ ...item }));
}

async function assertCanAccessCourse(uid, courseId) {
  const snap = await getDb().collection("courses").doc(courseId).get();
  if (!snap.exists) {
    return { ok: false, status: 404, error: "not-found", message: "Course not found." };
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

async function assertTeacherOwns(uid, courseId) {
  const access = await assertCanAccessCourse(uid, courseId);
  if (!access.ok) return access;
  if (!access.asTeacher) {
    return {
      ok: false,
      status: 403,
      error: "forbidden",
      message: "Only the course teacher can change this course.",
    };
  }
  return access;
}

async function addToArray(courseId, field, item) {
  const cleaned = cleanNulls(item);
  await getDb()
    .collection("courses")
    .doc(courseId)
    .update({
      [field]: FieldValue.arrayUnion(cleaned),
      updatedAt: FieldValue.serverTimestamp(),
    });
  return cleaned;
}

async function replaceInArray(courseId, field, itemId, data) {
  const ref = getDb().collection("courses").doc(courseId);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error("not-found");
    err.code = "not-found";
    throw err;
  }
  const existing = snap.data()?.[field];
  const items = asMaps(existing);
  const cleaned = cleanNulls(data);
  cleaned.id = itemId;
  const index = items.findIndex((entry) => entry.id === itemId);
  if (index < 0) {
    items.push(cleaned);
  } else {
    items[index] = cleaned;
  }
  await ref.update({
    [field]: items,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return cleaned;
}

// --- announcements ---
router.get("/:courseId/announcements", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const items = asMaps(access.data.announcements).map(serializeAnnouncement);
    items.sort((a, b) => {
      const left = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const right = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return right - left;
    });
    return res.json({ announcements: items });
  } catch (err) {
    console.error("list announcements error", err.message);
    return sendError(res, 500, "list-failed", "Could not list announcements.");
  }
});

router.post("/:courseId/announcements", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const text = String(body.text || "").trim();
    if (!text) {
      return sendError(res, 400, "invalid-text", "Announcement text is required.");
    }
    const createdAt = parseDate(body.createdAt) || new Date();
    const item = await addToArray(courseId, "announcements", {
      id: String(body.id || "").trim() || newItemId(),
      text,
      createdAt,
    });
    return res.status(201).json({ announcement: serializeAnnouncement(item) });
  } catch (err) {
    console.error("add announcement error", err.message);
    return sendError(res, 500, "create-failed", "Could not add announcement.");
  }
});

// --- syllabus ---
router.get("/:courseId/syllabus", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const items = asMaps(access.data.syllabus).map(serializeSyllabusWeek);
    items.sort((a, b) => a.weekNumber - b.weekNumber);
    return res.json({
      syllabus: items,
      syllabusFiles: asMaps(access.data.syllabusFiles).map(serializeAttachment),
    });
  } catch (err) {
    console.error("list syllabus error", err.message);
    return sendError(res, 500, "list-failed", "Could not list syllabus.");
  }
});

router.post("/:courseId/syllabus", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Syllabus week title is required.");
    }
    const weekNumber =
      typeof body.weekNumber === "number"
        ? body.weekNumber
        : parseInt(body.weekNumber, 10) ||
          asMaps(owned.data.syllabus).length + 1;
    const item = await addToArray(courseId, "syllabus", {
      id: String(body.id || "").trim() || newItemId(),
      weekNumber,
      title,
      readings: String(body.readings || "").trim(),
      notes: String(body.notes || "").trim(),
    });
    return res.status(201).json({ week: serializeSyllabusWeek(item) });
  } catch (err) {
    console.error("add syllabus week error", err.message);
    return sendError(res, 500, "create-failed", "Could not add syllabus week.");
  }
});

router.post("/:courseId/syllabus/files", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    let files = [];
    if (Array.isArray(body.files)) {
      files = body.files;
    } else if (body.name || body.url) {
      files = [body];
    }
    const normalized = files
      .filter((item) => item && typeof item === "object")
      .map((item) => ({
        name: String(item.name || "").trim(),
        url: String(item.url || "").trim(),
      }))
      .filter((item) => item.url);
    if (normalized.length === 0) {
      return sendError(res, 400, "invalid-files", "At least one file with url is required.");
    }
    await getDb()
      .collection("courses")
      .doc(courseId)
      .update({
        syllabusFiles: FieldValue.arrayUnion(...normalized),
        updatedAt: FieldValue.serverTimestamp(),
      });
    return res.status(201).json({ files: normalized.map(serializeAttachment) });
  } catch (err) {
    console.error("add syllabus files error", err.message);
    return sendError(res, 500, "create-failed", "Could not attach syllabus files.");
  }
});

router.patch("/:courseId/syllabus/:itemId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const itemId = String(req.params.itemId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    if (!itemId) {
      return sendError(res, 400, "invalid-id", "Syllabus week id is required.");
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Syllabus week title is required.");
    }
    const weekNumber =
      typeof body.weekNumber === "number"
        ? body.weekNumber
        : parseInt(body.weekNumber, 10) || 1;
    const item = await replaceInArray(courseId, "syllabus", itemId, {
      id: itemId,
      weekNumber,
      title,
      readings: String(body.readings || "").trim(),
      notes: String(body.notes || "").trim(),
    });
    return res.json({ week: serializeSyllabusWeek(item) });
  } catch (err) {
    if (err.code === "not-found") {
      return sendError(res, 404, "not-found", "Course not found.");
    }
    console.error("update syllabus week error", err.message);
    return sendError(res, 500, "update-failed", "Could not update syllabus week.");
  }
});

// --- schedule lectures (course doc lectures[] — not live sessions) ---
router.get("/:courseId/schedule-lectures", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const items = asMaps(access.data.lectures).map(serializeLecture);
    items.sort((a, b) => {
      const left = a.date ? new Date(a.date).getTime() : 0;
      const right = b.date ? new Date(b.date).getTime() : 0;
      return left - right;
    });
    return res.json({ lectures: items });
  } catch (err) {
    console.error("list schedule-lectures error", err.message);
    return sendError(res, 500, "list-failed", "Could not list schedule lectures.");
  }
});

router.post("/:courseId/schedule-lectures", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Lecture title is required.");
    }
    const item = await addToArray(courseId, "lectures", {
      id: String(body.id || "").trim() || newItemId(),
      title,
      date: parseDate(body.date),
      description: String(body.description || "").trim(),
      ...attachmentsFrom(body),
    });
    return res.status(201).json({ lecture: serializeLecture(item) });
  } catch (err) {
    console.error("add schedule-lecture error", err.message);
    return sendError(res, 500, "create-failed", "Could not add schedule lecture.");
  }
});

router.patch("/:courseId/schedule-lectures/:itemId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const itemId = String(req.params.itemId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    if (!itemId) {
      return sendError(res, 400, "invalid-id", "Lecture id is required.");
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Lecture title is required.");
    }
    const item = await replaceInArray(courseId, "lectures", itemId, {
      id: itemId,
      title,
      date: parseDate(body.date),
      description: String(body.description || "").trim(),
      ...attachmentsFrom(body),
    });
    return res.json({ lecture: serializeLecture(item) });
  } catch (err) {
    if (err.code === "not-found") {
      return sendError(res, 404, "not-found", "Course not found.");
    }
    console.error("update schedule-lecture error", err.message);
    return sendError(res, 500, "update-failed", "Could not update schedule lecture.");
  }
});

// --- assignments (metadata only; no student submissions) ---
router.get("/:courseId/assignments", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const items = asMaps(access.data.assignments).map(serializeAssignment);
    return res.json({ assignments: items });
  } catch (err) {
    console.error("list assignments error", err.message);
    return sendError(res, 500, "list-failed", "Could not list assignments.");
  }
});

router.post("/:courseId/assignments", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Assignment title is required.");
    }
    const points =
      typeof body.points === "number"
        ? body.points
        : parseInt(body.points, 10) || 0;
    const item = await addToArray(courseId, "assignments", {
      id: String(body.id || "").trim() || newItemId(),
      title,
      dueDate: parseDate(body.dueDate),
      points,
      description: String(body.description || "").trim(),
      published: body.published !== false,
      ...attachmentsFrom(body),
    });
    return res.status(201).json({ assignment: serializeAssignment(item) });
  } catch (err) {
    console.error("add assignment error", err.message);
    return sendError(res, 500, "create-failed", "Could not add assignment.");
  }
});

router.patch("/:courseId/assignments/:itemId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const itemId = String(req.params.itemId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    if (!itemId) {
      return sendError(res, 400, "invalid-id", "Assignment id is required.");
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Assignment title is required.");
    }
    const points =
      typeof body.points === "number"
        ? body.points
        : parseInt(body.points, 10) || 0;
    const item = await replaceInArray(courseId, "assignments", itemId, {
      id: itemId,
      title,
      dueDate: parseDate(body.dueDate),
      points,
      description: String(body.description || "").trim(),
      published: body.published !== false,
      ...attachmentsFrom(body),
    });
    return res.json({ assignment: serializeAssignment(item) });
  } catch (err) {
    if (err.code === "not-found") {
      return sendError(res, 404, "not-found", "Course not found.");
    }
    console.error("update assignment error", err.message);
    return sendError(res, 500, "update-failed", "Could not update assignment.");
  }
});

// --- resources ---
router.get("/:courseId/resources", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const items = asMaps(access.data.resources).map(serializeResource);
    return res.json({ resources: items });
  } catch (err) {
    console.error("list resources error", err.message);
    return sendError(res, 500, "list-failed", "Could not list resources.");
  }
});

router.post("/:courseId/resources", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Resource title is required.");
    }
    const links = Array.isArray(body.links)
      ? body.links.map((v) => String(v || "").trim()).filter(Boolean)
      : [];
    const item = await addToArray(courseId, "resources", {
      id: String(body.id || "").trim() || newItemId(),
      title,
      type: String(body.type || "").trim(),
      detail: String(body.detail || "").trim(),
      ...attachmentsFrom(body),
      links,
    });
    return res.status(201).json({ resource: serializeResource(item) });
  } catch (err) {
    console.error("add resource error", err.message);
    return sendError(res, 500, "create-failed", "Could not add resource.");
  }
});

router.patch("/:courseId/resources/:itemId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const itemId = String(req.params.itemId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }
    if (!itemId) {
      return sendError(res, 400, "invalid-id", "Resource id is required.");
    }
    const body = req.body || {};
    const title = String(body.title || "").trim();
    if (!title) {
      return sendError(res, 400, "invalid-title", "Resource title is required.");
    }
    const links = Array.isArray(body.links)
      ? body.links.map((v) => String(v || "").trim()).filter(Boolean)
      : [];
    const item = await replaceInArray(courseId, "resources", itemId, {
      id: itemId,
      title,
      type: String(body.type || "").trim(),
      detail: String(body.detail || "").trim(),
      ...attachmentsFrom(body),
      links,
    });
    return res.json({ resource: serializeResource(item) });
  } catch (err) {
    if (err.code === "not-found") {
      return sendError(res, 404, "not-found", "Course not found.");
    }
    console.error("update resource error", err.message);
    return sendError(res, 500, "update-failed", "Could not update resource.");
  }
});

module.exports = router;
