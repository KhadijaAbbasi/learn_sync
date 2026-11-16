const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

const MAX_BYTES = 20 * 1024 * 1024;
const CHUNK_BYTES = 700 * 1024;
const MAX_CHUNKS = 40;

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

function extensionOf(name) {
  const index = String(name || "").lastIndexOf(".");
  if (index < 0 || index === String(name).length - 1) return "";
  return String(name).substring(index + 1);
}

function mimeFor(nameOrExt) {
  const ext = extensionOf(nameOrExt).toLowerCase() || String(nameOrExt || "").toLowerCase();
  switch (ext) {
    case "pdf":
      return "application/pdf";
    case "doc":
      return "application/msword";
    case "docx":
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    case "ppt":
      return "application/vnd.ms-powerpoint";
    case "pptx":
      return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "gif":
      return "image/gif";
    case "webp":
      return "image/webp";
    case "bmp":
      return "image/bmp";
    default:
      return "application/octet-stream";
  }
}

function fileUrl(courseId, fileId) {
  return `firestore://courses/${courseId}/files/${fileId}`;
}

function serializeFile(courseId, id, data) {
  const d = data || {};
  return {
    id,
    name: d.name || "",
    folder: d.folder || "",
    contentType: d.contentType || "application/octet-stream",
    size: typeof d.size === "number" ? d.size : 0,
    chunkCount: typeof d.chunkCount === "number" ? d.chunkCount : 0,
    url: fileUrl(courseId, id),
    createdAt: toIso(d.createdAt),
  };
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
      message: "Only the course teacher can change course files.",
    };
  }
  return access;
}

function decodeBase64(raw) {
  const value = String(raw || "").trim();
  if (!value) return null;
  const cleaned = value.includes(",")
    ? value.slice(value.indexOf(",") + 1)
    : value;
  try {
    return Buffer.from(cleaned, "base64");
  } catch (_) {
    return null;
  }
}

function chunkBuffer(bytes) {
  const chunkCount = Math.min(
    Math.max(Math.ceil(bytes.length / CHUNK_BYTES) || 1, 1),
    MAX_CHUNKS
  );
  const chunks = [];
  for (let i = 0; i < chunkCount; i++) {
    const start = i * CHUNK_BYTES;
    const end = Math.min(start + CHUNK_BYTES, bytes.length);
    chunks.push(bytes.subarray(start, end));
  }
  return chunks;
}

async function writeChunks(fileRef, chunks) {
  for (let i = 0; i < chunks.length; i++) {
    await fileRef.collection("chunks").doc(String(i)).set({
      data: Buffer.from(chunks[i]),
    });
  }
}

async function readFileBytes(fileRef, data) {
  const chunkCount =
    typeof data.chunkCount === "number" && data.chunkCount > 0
      ? data.chunkCount
      : 1;
  const parts = [];
  for (let i = 0; i < chunkCount; i++) {
    const chunk = await fileRef.collection("chunks").doc(String(i)).get();
    if (!chunk.exists) continue;
    const raw = (chunk.data() || {}).data;
    if (!raw) continue;
    if (Buffer.isBuffer(raw)) {
      parts.push(raw);
    } else if (raw instanceof Uint8Array) {
      parts.push(Buffer.from(raw));
    } else if (typeof raw.toBuffer === "function") {
      parts.push(raw.toBuffer());
    } else if (typeof raw.toUint8Array === "function") {
      parts.push(Buffer.from(raw.toUint8Array()));
    } else if (ArrayBuffer.isView(raw)) {
      parts.push(Buffer.from(raw.buffer, raw.byteOffset, raw.byteLength));
    }
  }
  return Buffer.concat(parts);
}

async function deleteFileAndChunks(fileRef) {
  const chunks = await fileRef.collection("chunks").get();
  const db = getDb();
  let batch = db.batch();
  let ops = 0;
  for (const doc of chunks.docs) {
    batch.delete(doc.ref);
    ops += 1;
    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  batch.delete(fileRef);
  await batch.commit();
}

// GET /api/courses/:courseId/files
router.get("/:courseId/files", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }
    const folder = String(req.query.folder || "").trim();
    let query = getDb().collection("courses").doc(courseId).collection("files");
    if (folder) {
      query = query.where("folder", "==", folder);
    }
    const snap = await query.get();
    const files = snap.docs.map((doc) =>
      serializeFile(courseId, doc.id, doc.data())
    );
    files.sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")));
    return res.json({ files });
  } catch (err) {
    console.error("list files error", err.message);
    return sendError(res, 500, "list-failed", "Could not list course files.");
  }
});

// POST /api/courses/:courseId/files  — base64 body (same Firestore chunk schema)
router.post("/:courseId/files", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }

    const body = req.body || {};
    const name = String(body.name || "").trim();
    const folder = String(body.folder || "").trim();
    if (!name) {
      return sendError(res, 400, "invalid-body", "File name is required.");
    }
    if (!folder) {
      return sendError(res, 400, "invalid-body", "Folder is required.");
    }

    const bytes = decodeBase64(body.dataBase64 || body.data || body.bytesBase64);
    if (!bytes || bytes.length === 0) {
      return sendError(res, 400, "invalid-body", "File data (dataBase64) is required.");
    }
    if (bytes.length > MAX_BYTES) {
      return sendError(res, 400, "file_too_large", "File exceeds 20 MB limit.");
    }

    const contentType =
      String(body.contentType || "").trim() || mimeFor(name);
    const chunks = chunkBuffer(bytes);
    if (chunks.length > MAX_CHUNKS) {
      return sendError(res, 400, "file_too_large", "File has too many chunks.");
    }

    const files = getDb().collection("courses").doc(courseId).collection("files");
    const doc = files.doc();
    await doc.set({
      name,
      folder,
      contentType,
      size: bytes.length,
      chunkCount: chunks.length,
      createdAt: FieldValue.serverTimestamp(),
    });
    await writeChunks(doc, chunks);

    const saved = await doc.get();
    return res.status(201).json({
      file: serializeFile(courseId, saved.id, saved.data()),
    });
  } catch (err) {
    console.error("upload file error", err.message);
    return sendError(res, 500, "file_upload_failed", "Could not upload file.");
  }
});

// GET /api/courses/:courseId/files/:fileId — metadata + reassembled base64
router.get("/:courseId/files/:fileId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const fileId = String(req.params.fileId || "").trim();
    const access = await assertCanAccessCourse(req.uid, courseId);
    if (!access.ok) {
      return sendError(res, access.status, access.error, access.message);
    }

    const fileRef = getDb()
      .collection("courses")
      .doc(courseId)
      .collection("files")
      .doc(fileId);
    const snap = await fileRef.get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "File not found.");
    }
    const data = snap.data() || {};
    const bytes = await readFileBytes(fileRef, data);
    const meta = serializeFile(courseId, snap.id, data);
    return res.json({
      file: meta,
      dataBase64: bytes.toString("base64"),
    });
  } catch (err) {
    console.error("download file error", err.message);
    return sendError(res, 500, "download-failed", "Could not download file.");
  }
});

// DELETE /api/courses/:courseId/files/:fileId
router.delete("/:courseId/files/:fileId", requireAuth, async (req, res) => {
  try {
    const courseId = String(req.params.courseId || "").trim();
    const fileId = String(req.params.fileId || "").trim();
    const owned = await assertTeacherOwns(req.uid, courseId);
    if (!owned.ok) {
      return sendError(res, owned.status, owned.error, owned.message);
    }

    const fileRef = getDb()
      .collection("courses")
      .doc(courseId)
      .collection("files")
      .doc(fileId);
    const snap = await fileRef.get();
    if (!snap.exists) {
      return sendError(res, 404, "not-found", "File not found.");
    }
    await deleteFileAndChunks(fileRef);
    return res.json({ ok: true, id: fileId });
  } catch (err) {
    console.error("delete file error", err.message);
    return sendError(res, 500, "delete-failed", "Could not delete file.");
  }
});

module.exports = router;
