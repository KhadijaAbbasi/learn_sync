const express = require("express");
const { FieldValue } = require("firebase-admin/firestore");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const aiPracticeRouter = express.Router();
const lecturesPracticeRouter = express.Router();

const QUIZ_QUESTION_COUNT = 5;
const QUIZ_OPTION_COUNT = 3;
const NOTES_MAX_CHARS = 12000;
const TEACHER_ATTEMPTS_LIMIT = 400;

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

function clipNotes(notes) {
  const text = String(notes || "").trim();
  if (text.length <= NOTES_MAX_CHARS) return text;
  return text.slice(0, NOTES_MAX_CHARS) + "...";
}

function letterFromIndex(index) {
  return String.fromCharCode(65 + index);
}

function normalizeCorrectAnswer(value, options) {
  if (typeof value === "number" && Number.isInteger(value)) {
    if (value >= 0 && value < QUIZ_OPTION_COUNT) {
      return letterFromIndex(value);
    }
  }
  const raw = String(value == null ? "" : value).trim();
  if (!raw) return "";
  if (/^[A-Ca-c]$/.test(raw)) return raw.toUpperCase();
  const prefix = raw.match(/^([A-Ca-c])(?:[).:\-\s]|$)/);
  if (prefix) return prefix[1].toUpperCase();
  const lower = raw.toLowerCase();
  for (let i = 0; i < options.length; i++) {
    if (String(options[i]).trim().toLowerCase() === lower) {
      return letterFromIndex(i);
    }
  }
  return "";
}

function extractJsonText(raw) {
  const text = String(raw || "").trim();
  if (!text) return "";
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence && fence[1]) return fence[1].trim();
  const startArr = text.indexOf("[");
  const startObj = text.indexOf("{");
  let begin = -1;
  let endChar = "]";
  if (startArr >= 0 && (startObj < 0 || startArr < startObj)) {
    begin = startArr;
    endChar = "]";
  } else if (startObj >= 0) {
    begin = startObj;
    endChar = "}";
  }
  if (begin < 0) return text;
  const end = text.lastIndexOf(endChar);
  if (end <= begin) return text;
  return text.slice(begin, end + 1);
}

function normalizeQuizPayload(decoded) {
  let items = null;
  if (Array.isArray(decoded)) {
    items = decoded;
  } else if (decoded && typeof decoded === "object") {
    if (Array.isArray(decoded.questions)) items = decoded.questions;
    else if (Array.isArray(decoded.quiz)) items = decoded.quiz;
  }
  if (!items) {
    const err = new Error("Model returned invalid quiz JSON.");
    err.code = "malformed-quiz";
    throw err;
  }

  const quiz = [];
  for (const item of items) {
    if (!item || typeof item !== "object") continue;
    const question = String(item.question || item.prompt || "").trim();
    const options = [];
    const rawOptions = Array.isArray(item.options) ? item.options : [];
    for (const option of rawOptions) {
      const text = String(option == null ? "" : option).trim();
      if (text) options.push(text);
      if (options.length >= QUIZ_OPTION_COUNT) break;
    }
    if (!question || options.length !== QUIZ_OPTION_COUNT) continue;
    const correctSource =
      item.correctAnswer != null
        ? item.correctAnswer
        : item.correctIndex != null
          ? item.correctIndex
          : item.answer != null
            ? item.answer
            : item.correct;
    const correctAnswer = normalizeCorrectAnswer(correctSource, options);
    if (!correctAnswer) continue;
    const entry = { question, options, correctAnswer };
    if (item.sourceIndex != null && item.sourceIndex !== "") {
      const sourceIndex = Number(item.sourceIndex);
      if (Number.isInteger(sourceIndex) && sourceIndex >= 0) {
        entry.sourceIndex = sourceIndex;
      }
    }
    const rawFile =
      item.fileIndex != null ? item.fileIndex : item.slideFileIndex;
    if (rawFile != null && rawFile !== "") {
      const fileIndex = Number(rawFile);
      if (Number.isInteger(fileIndex) && fileIndex >= 0) {
        entry.fileIndex = fileIndex;
      }
    }
    if (item.slidePage != null && item.slidePage !== "") {
      const slidePage = Number(item.slidePage);
      if (Number.isInteger(slidePage) && slidePage > 0) {
        entry.slidePage = slidePage;
      }
    }
    const fileName = String(item.fileName || item.slideFileName || "").trim();
    if (fileName) entry.fileName = fileName;
    quiz.push(entry);
    if (quiz.length >= QUIZ_QUESTION_COUNT) break;
  }

  if (quiz.length !== QUIZ_QUESTION_COUNT) {
    const err = new Error(
      "Expected " + QUIZ_QUESTION_COUNT + " questions, got " + quiz.length + "."
    );
    err.code = "malformed-quiz";
    throw err;
  }
  return quiz;
}

function buildSimpleQuizPrompt(body) {
  const chapter = String(body.chapterTitle || "").trim() || "(unspecified)";
  const topic = String(body.topicTitle || "").trim() || "(unspecified)";
  const course = String(body.courseName || "").trim() || "(unspecified)";
  const sourceKind = String(body.sourceKind || "notes").trim();
  const sourceLabel =
    sourceKind === "documents"
      ? "Teacher lecture documents / slides (source of truth)"
      : "Teacher lecture notes (source of truth)";
  const weakSlides = Array.isArray(body.weakSlides) ? body.weakSlides : [];
  const focusLines = [];
  for (const slide of weakSlides) {
    const fileIndex = Number(slide.fileIndex != null ? slide.fileIndex : 0);
    const slidePage = Number(slide.slidePage != null ? slide.slidePage : 1);
    const levelLabel = String(slide.levelLabel || "").trim() || "Below 50%";
    const priority = Number(slide.priority != null ? slide.priority : 3);
    focusLines.push(
      "- File " +
        (fileIndex + 1) +
        " Slide " +
        slidePage +
        ": " +
        levelLabel +
        " (priority " +
        priority +
        ")"
    );
  }
  const focusBlock =
    focusLines.length === 0
      ? "No slides were marked below 50%. Write a general practice quiz from the FULL lecture source.\n"
      : "The student marked below 50% on these slides only. Every one of the " +
        QUIZ_QUESTION_COUNT +
        " questions MUST be about these slides and no others:\n" +
        focusLines.join("\n") +
        "\n";
  return (
    "You are generating a practice quiz for university students.\n" +
    "Use ONLY the source material below. Do not invent facts missing from it.\n" +
    "Course: " +
    course +
    "\nChapter: " +
    chapter +
    "\nTopic: " +
    topic +
    "\n\n" +
    sourceLabel +
    ":\n" +
    clipNotes(body.taughtNotes) +
    "\n\n" +
    focusBlock +
    "\nReturn ONLY a JSON array of exactly " +
    QUIZ_QUESTION_COUNT +
    " objects. No markdown fences. No commentary.\n" +
    'Each object MUST have this exact shape:\n{"question":"...","options":["A text","B text","C text"],"correctAnswer":"A","reason":"..."}\n' +
    "Rules:\n" +
    "- Exactly " +
    QUIZ_QUESTION_COUNT +
    " MCQs.\n" +
    "- Exactly " +
    QUIZ_OPTION_COUNT +
    " option strings; plain text without A)/B)/C) prefixes.\n" +
    "- correctAnswer MUST be one letter A, B, or C.\n" +
    "- Strictly from the provided source material only.\n"
  );
}

async function callGeminiApi(apiKey, prompt) {
  const model = "gemini-2.0-flash";
  const url =
    "https://generativelanguage.googleapis.com/v1beta/models/" +
    model +
    ":generateContent?key=" +
    encodeURIComponent(apiKey);
  const systemPrompt =
    "You output ONLY valid JSON arrays for MCQ quizzes. No markdown. No prose.";
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [{ text: systemPrompt + "\n\n" + prompt }],
        },
      ],
      generationConfig: { temperature: 0.2 },
    }),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    const err = new Error("Quiz provider request failed.");
    err.code = "provider-error";
    err.detail = bodyText.slice(0, 280);
    throw err;
  }
  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch (_) {
    const err = new Error("Quiz provider returned non-JSON.");
    err.code = "provider-error";
    throw err;
  }
  const parts =
    parsed &&
    parsed.candidates &&
    parsed.candidates[0] &&
    parsed.candidates[0].content &&
    parsed.candidates[0].content.parts;
  if (!Array.isArray(parts)) return "";
  return parts.map((part) => String(part.text || "")).join("");
}

function resolveCfUrl() {
  const fromEnv = String(process.env.AI_PRACTICE_CF_URL || "").trim();
  if (fromEnv) return fromEnv.replace(/\/$/, "");
  const projectId = String(
    process.env.GCLOUD_PROJECT ||
      process.env.GCP_PROJECT ||
      process.env.FIREBASE_PROJECT_ID ||
      "learnsync-bb5e6"
  ).trim();
  return (
    "https://us-central1-" +
    projectId +
    ".cloudfunctions.net/generateAiPracticeQuiz"
  );
}

async function proxyGenerateAiPracticeQuiz(idToken, data) {
  const url = resolveCfUrl();
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: "Bearer " + idToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ data }),
  });
  const bodyText = await response.text();
  let parsed = {};
  try {
    parsed = JSON.parse(bodyText);
  } catch (_) {
    parsed = {};
  }
  if (!response.ok) {
    const err = new Error(
      (parsed.error && (parsed.error.message || parsed.error.status)) ||
        "Cloud Function generate failed."
    );
    err.code = "cf-proxy-failed";
    err.status = response.status;
    err.detail = bodyText.slice(0, 280);
    throw err;
  }
  if (parsed.result && parsed.result.quiz) {
    return normalizeQuizPayload(parsed.result.quiz);
  }
  if (parsed.quiz) {
    return normalizeQuizPayload(parsed.quiz);
  }
  return normalizeQuizPayload(parsed.result || parsed);
}

async function generateQuizLocalOrProxy(req) {
  const body = req.body || {};
  const taughtNotes = String(body.taughtNotes || "").trim();
  if (!taughtNotes) {
    const err = new Error("Lecture notes are required.");
    err.code = "missing-notes";
    err.status = 400;
    throw err;
  }

  const payload = {
    taughtNotes,
    chapterTitle: String(body.chapterTitle || "").trim(),
    topicTitle: String(body.topicTitle || "").trim(),
    courseName: String(body.courseName || "").trim(),
    sourceKind: String(body.sourceKind || "notes").trim() || "notes",
    weakSlides: Array.isArray(body.weakSlides) ? body.weakSlides : [],
  };

  const preferLocal =
    String(process.env.AI_PRACTICE_MODE || "").trim().toLowerCase() ===
    "local";
  const apiKey = String(
    process.env.GEMINI_API_KEY || process.env.API_KEY || ""
  ).trim();

  if (preferLocal && apiKey && apiKey !== "your_api_key_here") {
    const raw = await callGeminiApi(apiKey, buildSimpleQuizPrompt(payload));
    return normalizeQuizPayload(JSON.parse(extractJsonText(raw)));
  }

  const header = req.headers.authorization || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  const idToken = match ? match[1] : "";

  try {
    return await proxyGenerateAiPracticeQuiz(idToken, payload);
  } catch (proxyErr) {
    if (apiKey && apiKey !== "your_api_key_here") {
      console.warn(
        "CF proxy failed, falling back to local Gemini:",
        proxyErr.message
      );
      const raw = await callGeminiApi(apiKey, buildSimpleQuizPrompt(payload));
      return normalizeQuizPayload(JSON.parse(extractJsonText(raw)));
    }
    throw proxyErr;
  }
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

function serializeQuestion(q) {
  const item = q || {};
  return {
    prompt: String(item.prompt || item.question || "").trim(),
    question: String(item.question || item.prompt || "").trim(),
    options: Array.isArray(item.options)
      ? item.options.map((o) => String(o == null ? "" : o))
      : [],
    correctIndex:
      item.correctIndex != null
        ? Number(item.correctIndex)
        : item.correctAnswer
          ? String(item.correctAnswer).toUpperCase().charCodeAt(0) - 65
          : -1,
    explanation: String(item.explanation || item.reason || "").trim(),
    chapterTitle: String(item.chapterTitle || "").trim(),
    lectureTitle: String(item.lectureTitle || "").trim(),
    slideFileName: String(item.slideFileName || item.fileName || "").trim(),
    slideFileIndex:
      item.slideFileIndex != null
        ? Number(item.slideFileIndex)
        : item.fileIndex != null
          ? Number(item.fileIndex)
          : -1,
    slidePage: item.slidePage != null ? Number(item.slidePage) : 0,
    sourceIndex: item.sourceIndex != null ? Number(item.sourceIndex) : -1,
  };
}

function serializeAttempt(id, data) {
  const d = data || {};
  const score = Number(d.score != null ? d.score : 0);
  const total = Number(d.total != null ? d.total : QUIZ_QUESTION_COUNT);
  const percent =
    d.percent != null
      ? Number(d.percent)
      : total === 0
        ? 0
        : Math.round((score / total) * 100);
  return {
    id,
    lectureId: d.lectureId || "",
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    teacherId: d.teacherId || "",
    studentId: d.studentId || "",
    studentName: d.studentName || "",
    topicTitle: d.topicTitle || "",
    chapterTitle: d.chapterTitle || "",
    score,
    total,
    percent,
    passed: d.passed != null ? Boolean(d.passed) : percent >= 60,
    completed: d.completed != null ? Boolean(d.completed) : true,
    selectedIndexes: Array.isArray(d.selectedIndexes)
      ? d.selectedIndexes.map((n) => Number(n))
      : [],
    diagnostic: d.diagnostic || "",
    questions: Array.isArray(d.questions)
      ? d.questions.map(serializeQuestion)
      : [],
    createdAt: toIso(d.createdAt),
    completedAt: toIso(d.completedAt),
  };
}

function sortAttemptsDesc(a, b) {
  const left = a.completedAt || a.createdAt || "";
  const right = b.completedAt || b.createdAt || "";
  return String(right).localeCompare(String(left));
}

function normalizeQuestionsForStore(rawQuestions) {
  if (!Array.isArray(rawQuestions)) return [];
  return rawQuestions.map((item) => {
    const q = serializeQuestion(item);
    return {
      prompt: q.prompt || q.question,
      options: q.options,
      correctIndex: q.correctIndex,
      explanation: q.explanation,
      chapterTitle: q.chapterTitle,
      lectureTitle: q.lectureTitle,
      slideFileName: q.slideFileName,
      slideFileIndex: q.slideFileIndex,
      slidePage: q.slidePage,
      sourceIndex: q.sourceIndex,
    };
  });
}

// POST /api/ai-practice/generate
aiPracticeRouter.post("/generate", requireAuth, async (req, res) => {
  try {
    const quiz = await generateQuizLocalOrProxy(req);
    return res.json({ quiz });
  } catch (err) {
    const code = err.code || "generate-failed";
    if (code === "missing-notes") {
      return sendError(res, 400, "missing-notes", err.message);
    }
    if (code === "malformed-quiz") {
      return sendError(res, 502, "malformed-quiz", err.message);
    }
    console.error("POST /api/ai-practice/generate", err.message, err.detail || "");
    return sendError(
      res,
      err.status && err.status >= 400 ? err.status : 502,
      "generate-failed",
      err.message || "Could not generate a practice quiz."
    );
  }
});

// GET /api/ai-practice/teachers/:teacherId/attempts
aiPracticeRouter.get(
  "/teachers/:teacherId/attempts",
  requireAuth,
  async (req, res) => {
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
          "You can only read your own teacher practice attempts."
        );
      }
      const snap = await getDb()
        .collectionGroup("practiceAttempts")
        .where("teacherId", "==", teacherId)
        .limit(TEACHER_ATTEMPTS_LIMIT)
        .get();
      const items = snap.docs
        .map((doc) => serializeAttempt(doc.id, doc.data()))
        .sort(sortAttemptsDesc);
      return res.json({ attempts: items });
    } catch (err) {
      console.error(
        "GET /api/ai-practice/teachers/:teacherId/attempts",
        err.message
      );
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// POST /api/lectures/:lectureId/practice-attempts
lecturesPracticeRouter.post(
  "/:lectureId/practice-attempts",
  requireAuth,
  async (req, res) => {
    try {
      const lectureId = String(req.params.lectureId || "").trim();
      const body = req.body || {};
      const studentId = req.uid;
      const studentName = String(body.studentName || "").trim();
      const courseId = String(body.courseId || "").trim();

      if (!lectureId || !courseId || !studentName) {
        return sendError(
          res,
          400,
          "invalid-request",
          "A valid practice attempt is required."
        );
      }
      if (body.studentId && String(body.studentId).trim() !== studentId) {
        return sendError(
          res,
          403,
          "forbidden",
          "You can only save your own practice attempts."
        );
      }

      const db = getDb();
      const lectureRef = db.collection("lectures").doc(lectureId);
      const lectureSnap = await lectureRef.get();
      if (!lectureSnap.exists || (lectureSnap.data() || {}).status !== "ended") {
        return sendError(
          res,
          409,
          "lecture-not-ended",
          "Practice is only allowed after the lecture ends."
        );
      }

      const lectureData = lectureSnap.data() || {};
      const resolvedCourseId =
        String(lectureData.courseId || "").trim() || courseId;
      const resolvedTeacherId =
        String(body.teacherId || "").trim() ||
        String(lectureData.teacherId || "").trim();

      const access = await assertMemberOrTeacher(studentId, resolvedCourseId);
      if (!access.ok) {
        return sendError(res, access.status, access.error, access.message);
      }
      if (access.isTeacher) {
        return sendError(
          res,
          403,
          "forbidden",
          "Teachers cannot submit practice attempts."
        );
      }

      const score = Number(body.score != null ? body.score : 0);
      const total = Number(
        body.total != null ? body.total : QUIZ_QUESTION_COUNT
      );
      const percent =
        total === 0 ? 0 : Math.round((score / total) * 100);
      const nowMs = Date.now();
      const id = String(body.id || "").trim() || studentId + "_" + nowMs;
      const attemptRef = lectureRef.collection("practiceAttempts").doc(id);

      const draft = {
        lectureId,
        courseId: resolvedCourseId,
        courseName:
          String(body.courseName || "").trim() ||
          String(lectureData.courseName || "").trim(),
        teacherId: resolvedTeacherId,
        studentId,
        studentName,
        topicTitle:
          String(body.topicTitle || "").trim() ||
          String(lectureData.topicTitle || "").trim(),
        chapterTitle:
          String(body.chapterTitle || "").trim() ||
          String(lectureData.chapterTitle || "").trim(),
        score,
        total,
        percent,
        passed: percent >= 60,
        completed: true,
        selectedIndexes: Array.isArray(body.selectedIndexes)
          ? body.selectedIndexes.map((n) => Number(n))
          : [],
        diagnostic: String(body.diagnostic || "").trim(),
        questions: normalizeQuestionsForStore(body.questions),
        createdAt: FieldValue.serverTimestamp(),
        completedAt: FieldValue.serverTimestamp(),
      };

      await attemptRef.set(draft);
      const snap = await attemptRef.get();
      return res.status(201).json({
        attempt: serializeAttempt(snap.id, snap.data() || draft),
      });
    } catch (err) {
      console.error("POST /api/lectures/:lectureId/practice-attempts", err.message);
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// GET /api/lectures/:lectureId/practice-attempts/me
lecturesPracticeRouter.get(
  "/:lectureId/practice-attempts/me",
  requireAuth,
  async (req, res) => {
    try {
      const lectureId = String(req.params.lectureId || "").trim();
      if (!lectureId) {
        return sendError(res, 400, "invalid-request", "lectureId is required.");
      }
      const snap = await getDb()
        .collection("lectures")
        .doc(lectureId)
        .collection("practiceAttempts")
        .where("studentId", "==", req.uid)
        .get();
      const items = snap.docs
        .map((doc) => serializeAttempt(doc.id, doc.data()))
        .sort(sortAttemptsDesc);
      return res.json({ attempts: items });
    } catch (err) {
      console.error(
        "GET /api/lectures/:lectureId/practice-attempts/me",
        err.message
      );
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// GET /api/lectures/:lectureId/practice-attempts
lecturesPracticeRouter.get(
  "/:lectureId/practice-attempts",
  requireAuth,
  async (req, res) => {
    try {
      const lectureId = String(req.params.lectureId || "").trim();
      if (!lectureId) {
        return sendError(res, 400, "invalid-request", "lectureId is required.");
      }
      const db = getDb();
      const lectureSnap = await db.collection("lectures").doc(lectureId).get();
      if (!lectureSnap.exists) {
        return sendError(res, 404, "not-found", "Lecture not found.");
      }
      const lectureData = lectureSnap.data() || {};
      const courseId = String(lectureData.courseId || "").trim();
      if (!courseId) {
        return sendError(res, 404, "not-found", "Lecture course missing.");
      }
      const access = await assertMemberOrTeacher(req.uid, courseId);
      if (!access.ok) {
        return sendError(res, access.status, access.error, access.message);
      }
      if (!access.isTeacher && lectureData.teacherId !== req.uid) {
        return sendError(
          res,
          403,
          "forbidden",
          "Only the course teacher can list all practice attempts."
        );
      }
      const snap = await lectureSnap.ref.collection("practiceAttempts").get();
      const items = snap.docs
        .map((doc) => serializeAttempt(doc.id, doc.data()))
        .sort(sortAttemptsDesc);
      return res.json({ attempts: items });
    } catch (err) {
      console.error(
        "GET /api/lectures/:lectureId/practice-attempts",
        err.message
      );
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

module.exports = { aiPracticeRouter, lecturesPracticeRouter };
