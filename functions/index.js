/**
 * LEARNsync Cloud Functions
 * - Signup OTP helpers (existing)
 * - generateAiPracticeQuiz: lecture docs + optional below-50 slides -> 5 MCQs via Vertex Gemini (ADC)
 *
 * Deploy secret (production):
 *   firebase functions:secrets:set API_KEY
 * Local emulator / local Node:
 *   API_KEY is read from process.env (load ../.env or functions/.env; never commit).
 */
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const {logger} = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {GoogleAuth} = require("google-auth-library");

initializeApp();
setGlobalOptions({region: "us-central1", maxInstances: 10});

const OTP_TTL_MS = 10 * 60 * 1000;
const RESEND_WAIT_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;
const QUIZ_QUESTION_COUNT = 5;
const QUIZ_OPTION_COUNT = 3;

/** Unauthenticated callers (signup happens before Auth exists). */
const CALLABLE_OPTS = {invoker: "public"};

function loadLocalEnvFiles() {
  const candidates = [
    path.resolve(__dirname, ".env"),
    path.resolve(__dirname, "../.env"),
  ];
  for (const filePath of candidates) {
    try {
      if (!fs.existsSync(filePath)) {
        continue;
      }
      const text = fs.readFileSync(filePath, "utf8");
      for (const rawLine of text.split(/\r?\n/)) {
        const line = rawLine.trim();
        if (!line || line.startsWith("#")) {
          continue;
        }
        const eq = line.indexOf("=");
        if (eq <= 0) {
          continue;
        }
        const key = line.slice(0, eq).trim();
        let value = line.slice(eq + 1).trim();
        if (
          (value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))
        ) {
          value = value.slice(1, -1);
        }
        if (key && process.env[key] == null) {
          process.env[key] = value;
        }
      }
    } catch (error) {
      logger.warn("Could not load local env file", {
        filePath,
        message: String(error),
      });
    }
  }
}

loadLocalEnvFiles();

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function otpDocId(email) {
  return crypto.createHash("sha256").update(email).digest("hex");
}

function hashOtp(email, otp) {
  return crypto.createHash("sha256").update(`${email}:${otp}`).digest("hex");
}

function fail(code, message, details) {
  throw new HttpsError(code, message, details);
}


/** Detect provider from key prefix without logging the key. */
function detectProvider(apiKey) {
  if (apiKey.startsWith("gsk_")) {
    return "groq";
  }
  if (apiKey.startsWith("AIza")) {
    return "google";
  }
  if (apiKey.startsWith("xai-")) {
    return "xai";
  }
  if (apiKey.startsWith("sk-")) {
    return "openai";
  }
  return "openai";
}

function providerLabel(provider) {
  switch (provider) {
    case "groq":
      return "groq";
    case "google":
      return "google";
    case "xai":
      return "xai";
    default:
      return "openai-compatible";
  }
}

async function emailAlreadyRegistered(email) {
  let inAuth = false;
  try {
    await getAuth().getUserByEmail(email);
    inAuth = true;
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw error;
    }
  }

  const inFirestore = await getFirestore()
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

  return inAuth || !inFirestore.empty;
}

async function queueLearnsyncEmail(email, otp) {
  await getFirestore().collection("mail").add({
    to: [email],
    message: {
      subject: "Your LEARNsync verification code",
      text:
        `Your LEARNsync signup code is ${otp}. ` +
        "It expires in 10 minutes. If you did not request this, ignore this email.",
      html:
        `<p>Your <strong>LEARNsync</strong> signup code is:</p>` +
        `<p style="font-size:28px;letter-spacing:6px;font-weight:700">${otp}</p>` +
        `<p>This code expires in 10 minutes.</p>`,
    },
  });
}

exports.requestSignupOtp = onCall(CALLABLE_OPTS, async (request) => {
  const email = normalizeEmail(request.data && request.data.email);
  if (!email.includes("@")) {
    fail("invalid-argument", "Enter a valid email address.", "invalid-email");
  }

  try {
    if (await emailAlreadyRegistered(email)) {
      fail("already-exists", "User already exist.", "user-already-exists");
    }

    const id = otpDocId(email);
    const ref = getFirestore().collection("signupOtps").doc(id);
    const existing = await ref.get();
    const now = Date.now();
    if (existing.exists) {
      const lastSent = existing.data().lastSentAtMs || 0;
      if (now - lastSent < RESEND_WAIT_MS) {
        fail(
            "resource-exhausted",
            "Please wait before requesting another code.",
            "otp-cooldown",
        );
      }
    }

    const otp = String(crypto.randomInt(100000, 1000000));
    await ref.set({
      email,
      hash: hashOtp(email, otp),
      attempts: 0,
      expiresAtMs: now + OTP_TTL_MS,
      lastSentAtMs: now,
      createdAt: FieldValue.serverTimestamp(),
    });

    await queueLearnsyncEmail(email, otp);
    logger.info("Signup OTP queued", {email});
    return {sent: true};
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("requestSignupOtp failed", error);
    fail("internal", "Something went wrong.", "generic");
  }
});

exports.completeSignup = onCall(CALLABLE_OPTS, async (request) => {
  const data = request.data || {};
  const email = normalizeEmail(data.email);
  const otp = String(data.otp || "").trim();
  const password = String(data.password || "");
  const fullName = String(data.fullName || "").trim();
  const role = String(data.role || "");
  const memberId = String(data.memberId || "").trim();

  if (!email.includes("@") || !fullName || otp.length !== 6) {
    fail("invalid-argument", "Invalid signup details.", "invalid-signup");
  }
  if (memberId && !/^\d{1,20}$/.test(memberId)) {
    fail("invalid-argument", "Enter a numeric ID.", "invalid-member-id");
  }
  if (role !== "teacher" && role !== "student") {
    fail("invalid-argument", "Invalid role.", "invalid-role");
  }
  if (password.length < 8) {
    fail("invalid-argument", "Password is too weak.", "weak-password");
  }

  const db = getFirestore();
  const otpRef = db.collection("signupOtps").doc(otpDocId(email));

  try {
    if (await emailAlreadyRegistered(email)) {
      fail("already-exists", "User already exist.", "user-already-exists");
    }

    const otpSnap = await otpRef.get();
    if (!otpSnap.exists) {
      fail("failed-precondition", "Invalid verification code.", "invalid-otp");
    }
    const otpData = otpSnap.data();
    if (Date.now() > (otpData.expiresAtMs || 0)) {
      await otpRef.delete();
      fail("deadline-exceeded", "This code has expired.", "otp-expired");
    }
    if ((otpData.attempts || 0) >= MAX_ATTEMPTS) {
      await otpRef.delete();
      fail(
          "resource-exhausted",
          "Too many incorrect attempts.",
          "otp-locked",
      );
    }
    if (otpData.hash !== hashOtp(email, otp)) {
      await otpRef.update({attempts: FieldValue.increment(1)});
      fail("failed-precondition", "Invalid verification code.", "invalid-otp");
    }

    let userRecord;
    try {
      userRecord = await getAuth().createUser({
        email,
        password,
        displayName: fullName,
        emailVerified: true,
      });
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        fail("already-exists", "User already exist.", "user-already-exists");
      }
      if (error.code === "auth/weak-password") {
        fail("invalid-argument", "Password is too weak.", "weak-password");
      }
      throw error;
    }

    const userType = role === "teacher" ? 1 : 0;
    try {
      await db.collection("users").doc(userRecord.uid).set({
        userid: userRecord.uid,
        uid: userRecord.uid,
        userType,
        memberId,
        fullName,
        email,
        emailLower: email,
        nameLower: fullName.toLowerCase(),
        role,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await getAuth().deleteUser(userRecord.uid);
      logger.error(
          "Firestore profile write failed; rolled back Auth user",
          error,
      );
      fail("internal", "Could not save profile.", "profile-write-failed");
    }

    await otpRef.delete();
    const token = await getAuth().createCustomToken(userRecord.uid);
    return {
      uid: userRecord.uid,
      token,
      fullName,
      email,
      role,
      userType,
      memberId,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error("completeSignup failed", error);
    fail("internal", "Something went wrong.", "generic");
  }
});

function clipNotes(notes) {
  const trimmed = String(notes || "").trim();
  const max = 16000;
  if (trimmed.length <= max) {
    return trimmed;
  }
  return trimmed.slice(0, max) + "\n...[truncated for length]...";
}

function isWeakUnderstandingSlide(item) {
  if (!item || typeof item !== "object") {
    return false;
  }
  const label = String(item.levelLabel || item.level || "").trim().toLowerCase();
  // 80 / 100 are not quiz sources. 60% and below-50 are (≤70% weak).
  if (/\b(80|100)\b/.test(label) && !/below\s*50|below50|60/.test(label)) {
    return false;
  }
  if (/below\s*50|need help|below50|60\s*%|need a recap|percent60/.test(label)) {
    return true;
  }
  // Client priority: below50 = 3, 60% = 2, 80% = 1, 100% = 0.
  const priority = Number(item.priority != null ? item.priority : 0);
  return priority >= 2;
}

/** @deprecated use isWeakUnderstandingSlide — kept name for call sites. */
function isBelow50Slide(item) {
  return isWeakUnderstandingSlide(item);
}

function filterBelow50Slides(weakSlides) {
  if (!Array.isArray(weakSlides)) {
    return [];
  }
  const kept = [];
  for (const item of weakSlides) {
    if (isBelow50Slide(item)) {
      kept.push(item);
    }
  }
  kept.sort((a, b) => {
    const fa = Number(a.fileIndex != null ? a.fileIndex : 0);
    const fb = Number(b.fileIndex != null ? b.fileIndex : 0);
    if (fa !== fb) {
      return fa - fb;
    }
    const pa = Number(a.slidePage != null ? a.slidePage : 0);
    const pb = Number(b.slidePage != null ? b.slidePage : 0);
    return pa - pb;
  });
  return kept;
}

function formatFocusSlides(slides, {below50}) {
  if (!Array.isArray(slides) || slides.length === 0) {
    return "";
  }
  const lines = [];
  for (let i = 0; i < slides.length; i++) {
    const item = slides[i];
    const file = Number(item.fileIndex != null ? item.fileIndex : 0);
    const page = Number(item.slidePage != null ? item.slidePage : 1);
    const name = String(item.fileName || "").trim();
    const nameBit = name ? " | fileName " + name : "";
    const mark = below50
      ? " | student marked \"" +
        String(item.levelLabel || item.level || "Below 50%").trim() +
        "\""
      : " | random practice slide from lecture";
    lines.push(
        "- sourceIndex " + i +
        " | fileIndex " + file +
        " | slidePage " + page +
        nameBit +
        mark,
    );
  }
  return lines.join("\n");
}

/** Parse slide headers embedded in taughtNotes (PPTX extract labels). */
function parseSlidesFromNotes(taughtNotes) {
  const text = String(taughtNotes || "");
  const found = [];
  const seen = new Set();
  const reFileSlide = /---\s*File\s+(\d+)\s+Slide\s+(\d+)\s*(?:\(([^)]*)\))?\s*---/gi;
  let match;
  while ((match = reFileSlide.exec(text)) !== null) {
    const fileIndex = Math.max(0, Number(match[1]) - 1);
    const slidePage = Number(match[2]);
    const fileName = String(match[3] || "").trim();
    if (!Number.isInteger(slidePage) || slidePage < 1) {
      continue;
    }
    const key = fileIndex + ":" + slidePage;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    found.push({fileIndex, slidePage, fileName});
  }
  const reNameSlide = /---\s*(.+?)\s+slide\s+(\d+)\s*---/gi;
  while ((match = reNameSlide.exec(text)) !== null) {
    const label = String(match[1] || "").trim();
    // Skip lines already captured as "File N Slide P".
    if (/^File\s+\d+/i.test(label)) {
      continue;
    }
    const slidePage = Number(match[2]);
    if (!Number.isInteger(slidePage) || slidePage < 1) {
      continue;
    }
    const fileName = label;
    const key = "n:" + fileName.toLowerCase() + ":" + slidePage;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    found.push({fileIndex: 0, slidePage, fileName});
  }
  return found;
}

function shuffleCopy(items) {
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}

/**
 * When no below-50 slides: pick random real slides from the lecture source
 * so each question can carry a real slidePage (not Q1->1, Q2->2, ...).
 */
function sampleRandomSlides(taughtNotes, count) {
  const all = parseSlidesFromNotes(taughtNotes);
  if (all.length === 0 || count < 1) {
    return [];
  }
  const shuffled = shuffleCopy(all);
  const out = [];
  for (let i = 0; i < count; i++) {
    out.push(shuffled[i % shuffled.length]);
  }
  return out;
}

function normalizeFocusSlide(item) {
  return {
    fileIndex: Number(item.fileIndex != null ? item.fileIndex : 0),
    slidePage: Number(item.slidePage != null ? item.slidePage : 1),
    fileName: String(item.fileName || "").trim(),
    levelLabel: String(item.levelLabel || item.level || "").trim(),
  };
}

/**
 * Force every quiz item to carry a real fileIndex/slidePage from [focusSlides].
 * Prefers model sourceIndex / file+page; otherwise assigns from the focus list
 * (not question-index sequential labeling).
 */
function attachRealSlideMeta(quiz, focusSlides) {
  if (!Array.isArray(quiz) || !Array.isArray(focusSlides) || focusSlides.length === 0) {
    return quiz;
  }
  const catalog = focusSlides.map(normalizeFocusSlide);
  const shuffled = shuffleCopy(catalog);
  let cursor = 0;
  return quiz.map((item) => {
    const entry = Object.assign({}, item);
    let chosen = null;
    const sourceIndex = entry.sourceIndex;
    if (Number.isInteger(sourceIndex) && sourceIndex >= 0 && sourceIndex < catalog.length) {
      chosen = catalog[sourceIndex];
    }
    if (!chosen && entry.fileIndex != null && entry.slidePage != null) {
      const fileIndex = Number(entry.fileIndex);
      const slidePage = Number(entry.slidePage);
      for (const slide of catalog) {
        if (slide.fileIndex === fileIndex && slide.slidePage === slidePage) {
          chosen = slide;
          break;
        }
      }
    }
    if (!chosen && entry.slidePage != null) {
      const slidePage = Number(entry.slidePage);
      const matches = catalog.filter((slide) => slide.slidePage === slidePage);
      if (matches.length >= 1) {
        chosen = matches[0];
      }
    }
    if (!chosen) {
      chosen = shuffled[cursor % shuffled.length];
      cursor += 1;
    }
    entry.fileIndex = chosen.fileIndex;
    entry.slidePage = chosen.slidePage;
    if (chosen.fileName) {
      entry.fileName = chosen.fileName;
    }
    return entry;
  });
}

/**
 * System instruction: role + pedagogy + hard output contract.
 * User message: course context, weak slides, and lecture source text.
 */
function buildQuizSystemInstruction() {
  return (
    "You are LEARNsync Practice Tutor — a careful university teaching assistant.\n" +
    "Write multiple-choice questions that diagnose and repair ONE student's gaps " +
    "after a live lecture. Quality beats cleverness.\n\n" +
    "SOURCE RULES (non-negotiable):\n" +
    "1) Use ONLY facts, terms, examples, and relationships present in the lecture source.\n" +
    "2) Never invent formulas, dates, numbers, case studies, or definitions.\n" +
    "3) Do NOT ask about slide numbers, file names, UI, or lecture logistics.\n" +
    "4) Do NOT ask trivia that only tests memorizing a random phrase from the text.\n\n" +
    "SLIDE FOCUS:\n" +
    "5) When a weak-understanding slide list is provided (student marked 60% or Below 50% / ≤70%), " +
    "every question must test a concept taught on one of those listed slides only. " +
    "Do not use 80% or 100% slides. " +
    "Set sourceIndex, fileIndex, and slidePage by copying from exactly one listed slide " +
    "(reuse listed slides if needed; never invent a slide not listed).\n" +
    "6) When NO weak-slide list is provided but a random practice-slide list IS provided, " +
    "write questions from those listed slides and copy sourceIndex/fileIndex/slidePage " +
    "from the list. Never invent sequential Slide 1/2/3 by question order.\n" +
    "   When no slide list is provided at all, write a general quiz from the FULL lecture " +
    "source and set fileIndex/slidePage from real slide labels in the source when present.\n\n" +
    "QUESTION DESIGN (this is what 'good quality' means):\n" +
    "7) Mix of cognitive levels across the 5 questions:\n" +
    "   - 1 recall/definition (precise, important term from the source)\n" +
    "   - 2 understanding (explain meaning, contrast two ideas, choose best description)\n" +
    "   - 2 application (given a short realistic scenario, choose the correct concept/step)\n" +
    "8) Each stem must be a complete question that a student can answer WITHOUT looking " +
    "at the options first (avoid 'Which of the following is true?' with vague stems).\n" +
    "9) Stems should name the concept being tested when helpful " +
    "(e.g. cause/effect, purpose, when to use X, difference between A and B).\n" +
    "10) Keep difficulty fair for university undergrads who attended the lecture: " +
    "not baby-easy, not PhD-hard. One slightly harder application question is OK.\n" +
    "11) Questions must be mutually distinct — different concepts or different angles.\n" +
    "12) Language: clear, short sentences; match the lecture language " +
    "(English or Arabic if the source is Arabic). No trick negatives unless the source " +
    "itself emphasizes a common misconception.\n\n" +
    "DISTRACTORS (wrong options):\n" +
    "13) Exactly 3 options. Exactly one is correct.\n" +
    "14) Wrong options must be plausible misconceptions a confused student might hold, " +
    "drawn from nearby ideas in the SAME lecture (swap cause/effect, confuse similar terms, " +
    "apply the right idea in the wrong situation).\n" +
    "15) Ban silly, joke, extreme, or obviously unrelated options.\n" +
    "16) Options should be similar in length and style; no 'all of the above' / " +
    "'none of the above'.\n" +
    "17) Do not put A)/B)/C) prefixes inside option text.\n\n" +
    "OUTPUT CONTRACT (STRICT):\n" +
    "- Return ONLY a JSON array of exactly " + QUIZ_QUESTION_COUNT + " objects.\n" +
    "- No markdown fences, no commentary, no trailing text.\n" +
    "- Each object shape:\n" +
    '{"question":"...","options":["opt1","opt2","opt3"],"correctAnswer":"A","sourceIndex":0,"fileIndex":0,"slidePage":1}\n' +
    "- Exactly " + QUIZ_OPTION_COUNT + " option strings.\n" +
    "- correctAnswer MUST be A, B, or C matching the correct option index.\n" +
    "- Shuffle where the correct option sits across questions (not always A).\n"
  );
}

function buildQuizUserPrompt({
  chapterTitle,
  topicTitle,
  courseName,
  taughtNotes,
  weakSlides,
  focusSlides,
  sourceKind,
  below50,
}) {
  const chapter = String(chapterTitle || "").trim() || "(unspecified)";
  const topic = String(topicTitle || "").trim() || "(unspecified)";
  const course = String(courseName || "").trim() || "(unspecified)";
  const sourceLabel = String(sourceKind || "").trim() === "documents"
    ? "Teacher lecture documents / slides (extracted text)"
    : "Teacher lecture notes";
  const focusList = Array.isArray(focusSlides) && focusSlides.length
    ? focusSlides
    : (Array.isArray(weakSlides) ? weakSlides : []);
  const focusBlock = formatFocusSlides(focusList, {below50: !!below50});
  let focusSection;
  if (focusBlock && below50) {
    focusSection =
      "BELOW-50 SLIDES (the only allowed quiz sources):\n" +
      focusBlock +
      "\n\n" +
      "Workflow before writing questions:\n" +
      "1) Use only these slides. Ignore every other part of the lecture source.\n" +
      "2) For each question, pick one listed slide and test a concept that slide teaches.\n" +
      "3) Copy that slide's sourceIndex, fileIndex, and slidePage onto the question.\n" +
      "4) All " + QUIZ_QUESTION_COUNT + " questions must come from this list. " +
      "Do not add questions from other slides.\n\n";
  } else if (focusBlock) {
    focusSection =
      "NO below-50 slides. Practice slides were sampled at random from the lecture " +
      "(real slide numbers - copy them exactly; do NOT invent Slide 1/2/3 by question order):\n" +
      focusBlock +
      "\n\n" +
      "Workflow before writing questions:\n" +
      "1) Prefer these sampled slides; you may also use nearby context in the source.\n" +
      "2) For each question, pick one listed slide and test a concept that slide teaches.\n" +
      "3) Copy that slide's sourceIndex, fileIndex, and slidePage onto the question.\n" +
      "4) Never set slidePage to the question index (1 for Q1, 2 for Q2, ...).\n\n";
  } else {
    focusSection =
      "NO SLIDE LIST available. Write a GENERAL practice quiz from the FULL " +
      "lecture source below. When the source labels slides (e.g. 'File N Slide P'), " +
      "set fileIndex and slidePage on each question to the best matching REAL slide.\n\n";
  }
  return (
    "Course: " + course + "\n" +
    "Chapter: " + chapter + "\n" +
    "Topic: " + topic + "\n\n" +
    focusSection +
    sourceLabel + " (source of truth — quote concepts from here only):\n" +
    clipNotes(taughtNotes) + "\n\n" +
    "Now generate the JSON quiz array. Prefer depth over surface wording."
  );
}

function extractJsonText(raw) {
  const text = String(raw || "").trim();
  if (!text) {
    return "";
  }
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence && fence[1]) {
    return fence[1].trim();
  }
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
  if (begin < 0) {
    return text;
  }
  const end = text.lastIndexOf(endChar);
  if (end <= begin) {
    return text;
  }
  return text.slice(begin, end + 1);
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
  if (!raw) {
    return "";
  }
  if (/^[A-Da-d]$/.test(raw)) {
    return raw.toUpperCase();
  }
  const prefix = raw.match(/^([A-Da-d])(?:[).:\-\s]|$)/);
  if (prefix) {
    return prefix[1].toUpperCase();
  }
  const lower = raw.toLowerCase();
  for (let i = 0; i < options.length; i++) {
    if (String(options[i]).trim().toLowerCase() === lower) {
      return letterFromIndex(i);
    }
  }
  return "";
}

function normalizeQuizPayload(decoded) {
  let items = null;
  if (Array.isArray(decoded)) {
    items = decoded;
  } else if (decoded && typeof decoded === "object") {
    if (Array.isArray(decoded.questions)) {
      items = decoded.questions;
    } else if (Array.isArray(decoded.quiz)) {
      items = decoded.quiz;
    }
  }
  if (!items) {
    fail("internal", "Model returned invalid quiz JSON.", "malformed-quiz");
  }

  const quiz = [];
  for (const item of items) {
    if (!item || typeof item !== "object") {
      continue;
    }
    const question = String(item.question || item.prompt || "").trim();
    const options = [];
    const rawOptions = Array.isArray(item.options) ? item.options : [];
    for (const option of rawOptions) {
      const text = String(option == null ? "" : option).trim();
      if (text) {
        options.push(text);
      }
      if (options.length >= QUIZ_OPTION_COUNT) {
        break;
      }
    }
    if (!question || options.length !== QUIZ_OPTION_COUNT) {
      continue;
    }
    const correctSource = item.correctAnswer != null
      ? item.correctAnswer
      : (item.correctIndex != null
        ? item.correctIndex
        : (item.answer != null ? item.answer : item.correct));
    const correctAnswer = normalizeCorrectAnswer(correctSource, options);
    if (!correctAnswer) {
      continue;
    }
    const entry = {question, options, correctAnswer};
    if (item.sourceIndex != null && item.sourceIndex !== "") {
      const sourceIndex = Number(item.sourceIndex);
      if (Number.isInteger(sourceIndex) && sourceIndex >= 0) {
        entry.sourceIndex = sourceIndex;
      }
    }
    const rawFile = item.fileIndex != null ? item.fileIndex : item.slideFileIndex;
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
    if (fileName) {
      entry.fileName = fileName;
    }
    quiz.push(entry);
    if (quiz.length >= QUIZ_QUESTION_COUNT) {
      break;
    }
  }

  if (quiz.length !== QUIZ_QUESTION_COUNT) {
    fail(
        "internal",
        "Expected " + QUIZ_QUESTION_COUNT + " questions, got " + quiz.length + ".",
        "malformed-quiz",
    );
  }
  return quiz;
}

async function callOpenAiCompatible({apiKey, baseUrl, model, prompt}) {
  const response = await fetch(baseUrl + "/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": "Bearer " + apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      messages: [
        {
          role: "system",
          content:
            "You output ONLY valid JSON for MCQ quizzes. No markdown. No prose.",
        },
        {role: "user", content: prompt},
      ],
    }),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    logger.error("Upstream quiz API failed", {
      status: response.status,
      providerBase: baseUrl,
    });
    fail("internal", "Quiz provider request failed.", "provider-error");
  }
  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch (error) {
    fail("internal", "Quiz provider returned non-JSON.", "provider-error");
  }
  const content =
    parsed &&
    parsed.choices &&
    parsed.choices[0] &&
    parsed.choices[0].message &&
    parsed.choices[0].message.content;
  return String(content || "");
}

function resolveQuizProjectId() {
  const fromEnv = String(
      process.env.GCLOUD_PROJECT ||
      process.env.GCP_PROJECT ||
      process.env.GOOGLE_CLOUD_PROJECT ||
      "",
  ).trim();
  if (fromEnv) {
    return fromEnv;
  }
  try {
    const cfg = JSON.parse(process.env.FIREBASE_CONFIG || "{}");
    if (cfg && cfg.projectId) {
      return String(cfg.projectId);
    }
  } catch (error) {
    // ignore
  }
  return "learnsync-bb5e6";
}

/**
 * Gemini via Vertex AI using the Cloud Function runtime service account.
 * No Secret Manager API key required — billed on this GCP project.
 */
async function callVertexGemini({prompt, systemInstruction}) {
  const projectId = resolveQuizProjectId();
  const location = "us-central1";
  const model = "gemini-2.5-flash";
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const accessTokenResponse = await client.getAccessToken();
  const accessToken = typeof accessTokenResponse === "string"
    ? accessTokenResponse
    : (accessTokenResponse && accessTokenResponse.token);
  if (!accessToken) {
    fail(
        "failed-precondition",
        "Could not obtain Google credentials for Vertex AI.",
        "missing-adc",
    );
  }
  const url =
    "https://" + location + "-aiplatform.googleapis.com/v1/projects/" +
    encodeURIComponent(projectId) +
    "/locations/" + location +
    "/publishers/google/models/" + model +
    ":generateContent";
  const body = {
    contents: [{role: "user", parts: [{text: prompt}]}],
    generationConfig: {
      temperature: 0.4,
      topP: 0.9,
      responseMimeType: "application/json",
    },
  };
  if (systemInstruction) {
    body.systemInstruction = {
      parts: [{text: String(systemInstruction)}],
    };
  }
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + accessToken,
    },
    body: JSON.stringify(body),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    logger.error("Vertex Gemini quiz API failed", {
      status: response.status,
      bodyPreview: String(bodyText || "").slice(0, 240),
    });
    fail("internal", "Quiz provider request failed.", "provider-error");
  }
  let parsed;
  try {
    parsed = JSON.parse(bodyText);
  } catch (error) {
    fail("internal", "Quiz provider returned non-JSON.", "provider-error");
  }
  const parts =
    parsed &&
    parsed.candidates &&
    parsed.candidates[0] &&
    parsed.candidates[0].content &&
    parsed.candidates[0].content.parts;
  if (!Array.isArray(parts)) {
    return "";
  }
  return parts.map((part) => String(part.text || "")).join("");
}

async function generateQuizFromProvider({systemInstruction, userPrompt}) {
  logger.info("Generating AI practice quiz", {
    provider: "vertex-gemini",
    model: "gemini-2.5-flash",
    projectId: resolveQuizProjectId(),
  });
  const raw = await callVertexGemini({
    prompt: userPrompt,
    systemInstruction,
  });
  const jsonText = extractJsonText(raw);
  let decoded;
  try {
    decoded = JSON.parse(jsonText);
  } catch (error) {
    fail("internal", "Could not parse quiz JSON.", "malformed-quiz");
  }
  return normalizeQuizPayload(decoded);
}

/**
 * Callable: signed-in student/teacher requests a fresh 5-question MCQ quiz.
 * Input: { chapterTitle?, topicTitle?, courseName?, taughtNotes }
 * Output: { quiz: [{ question, options[4], correctAnswer: "A"|"B"|"C"|"D" }] }
 */
exports.generateAiPracticeQuiz = onCall(
    {
      invoker: "public",
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        fail(
            "unauthenticated",
            "Sign in to generate a practice quiz.",
            "auth-required",
        );
      }

      const data = request.data || {};
      const taughtNotes = String(data.taughtNotes || "").trim();
      if (!taughtNotes) {
        fail(
            "invalid-argument",
            "Lecture notes are required.",
            "missing-notes",
        );
      }

      const chapterTitle = String(data.chapterTitle || "").trim();
      const topicTitle = String(data.topicTitle || "").trim();
      const courseName = String(data.courseName || "").trim();
      const sourceKind = String(data.sourceKind || "notes").trim();
      // Empty weakSlides => sample random real slides from the lecture source.
      const weakSlides = filterBelow50Slides(
          Array.isArray(data.weakSlides) ? data.weakSlides : [],
      );
      const below50 = weakSlides.length > 0;
      const focusSlides = below50
        ? weakSlides
        : sampleRandomSlides(taughtNotes, QUIZ_QUESTION_COUNT);

      try {
        const systemInstruction = buildQuizSystemInstruction();
        const userPrompt = buildQuizUserPrompt({
          chapterTitle,
          topicTitle,
          courseName,
          taughtNotes,
          weakSlides,
          focusSlides,
          sourceKind,
          below50,
        });
        const quiz = attachRealSlideMeta(
            await generateQuizFromProvider({
              systemInstruction,
              userPrompt,
            }),
            focusSlides,
        );
        return {quiz};
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        logger.error("generateAiPracticeQuiz failed", error);
        fail(
            "internal",
            "Could not generate a practice quiz.",
            "generate-failed",
        );
      }
    },
);


// ---------------------------------------------------------------------------
// Phone auth without synthetic email: password hash + custom token login.
// Client never reads phoneCredentials (rules deny all).
// ---------------------------------------------------------------------------

function normalizePhoneE164(phone) {
  const raw = String(phone || "").trim();
  if (!raw) {
    return "";
  }
  if (raw.startsWith("+")) {
    return "+" + raw.slice(1).replace(/[^\d]/g, "");
  }
  return "+" + raw.replace(/[^\d]/g, "");
}

function hashPhonePassword(password, salt) {
  return crypto.scryptSync(String(password), salt, 64).toString("hex");
}

function verifyPhonePassword(password, saltHex, hashHex) {
  const salt = Buffer.from(saltHex, "hex");
  const expected = Buffer.from(hashHex, "hex");
  const actual = crypto.scryptSync(String(password), salt, 64);
  if (expected.length !== actual.length) {
    return false;
  }
  return crypto.timingSafeEqual(expected, actual);
}

/**
 * Authenticated callable. Call right after phone OTP signup / password reset.
 * Stores password hash for phone login (no email conversion).
 */
exports.setPhonePassword = onCall(CALLABLE_OPTS, async (request) => {
  if (!request.auth || !request.auth.uid) {
    fail("unauthenticated", "Sign in with phone OTP first.", "auth-required");
  }
  const password = String((request.data && request.data.password) || "");
  if (password.length < 8) {
    fail("invalid-argument", "Password is too short.", "weak-password");
  }

  const uid = request.auth.uid;
  let authUser;
  try {
    authUser = await getAuth().getUser(uid);
  } catch (error) {
    fail("not-found", "Account not found.", "account-not-found");
  }
  if (!authUser.phoneNumber) {
    fail(
        "failed-precondition",
        "Only phone accounts can set a phone password.",
        "not-phone-account",
    );
  }

  const salt = crypto.randomBytes(16);
  const hash = hashPhonePassword(password, salt);
  await getFirestore().collection("phoneCredentials").doc(uid).set({
    phone: authUser.phoneNumber,
    salt: salt.toString("hex"),
    hash,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  // Keep Auth password in sync for updatePassword / security tooling,
  // but never invent a synthetic email identity.
  try {
    await getAuth().updateUser(uid, {password});
  } catch (error) {
    logger.warn("Auth updatePassword skipped", {
      uid,
      code: error && error.code,
    });
  }

  return {ok: true};
});

/**
 * Public callable. Phone + password -> Firebase custom token.
 */
exports.signInWithPhonePassword = onCall(CALLABLE_OPTS, async (request) => {
  const phone = normalizePhoneE164(request.data && request.data.phone);
  const password = String((request.data && request.data.password) || "");
  if (!phone.startsWith("+") || phone.length < 10) {
    fail("invalid-argument", "Enter a valid phone number.", "invalid-phone");
  }
  if (!password) {
    fail("invalid-argument", "Password is required.", "missing-password");
  }

  let authUser;
  try {
    authUser = await getAuth().getUserByPhoneNumber(phone);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      fail("not-found", "Account not found.", "account-not-found");
    }
    throw error;
  }

  const credSnap = await getFirestore()
      .collection("phoneCredentials")
      .doc(authUser.uid)
      .get();
  if (!credSnap.exists) {
    fail(
        "failed-precondition",
        "Phone password is not set for this account.",
        "password-not-set",
    );
  }
  const cred = credSnap.data() || {};
  const ok = verifyPhonePassword(password, cred.salt, cred.hash);
  if (!ok) {
    fail("permission-denied", "Incorrect phone or password.", "invalid-credentials");
  }

  const token = await getAuth().createCustomToken(authUser.uid);
  return {token};
});
