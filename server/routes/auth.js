const express = require("express");
const crypto = require("crypto");
const { FieldValue } = require("firebase-admin/firestore");
const { getAuth, getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

function normalizeEmail(email) {
  return String(email || "")
    .trim()
    .replace(/[\s\u00A0\u2007\u202F]+/g, "")
    .toLowerCase();
}

function normalizeMemberId(value) {
  return String(value || "")
    .trim()
    .replace(/\s+/g, "")
    .toLowerCase();
}

function normalizePhoneE164(phone) {
  const raw = String(phone || "").trim();
  if (!raw) return "";
  if (raw.startsWith("+")) {
    return "+" + raw.replace(/[^\d]/g, "");
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
  if (expected.length !== actual.length) return false;
  return crypto.timingSafeEqual(expected, actual);
}

function sendError(res, status, error, message) {
  return res.status(status).json({ error, message });
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

function buildUserDoc(uid, fields) {
  const role = fields.role;
  const memberId = String(fields.memberId || "").trim();
  const email = fields.email || "";
  const fullName = String(fields.fullName || "").trim();
  const phone = fields.phone || "";
  const userType = role === "teacher" ? 1 : 0;

  const doc = {
    uid,
    userid: uid,
    fullName,
    email,
    emailLower: email ? email.toLowerCase() : "",
    nameLower: fullName.toLowerCase(),
    phone,
    role,
    userType,
    memberId,
    memberIdLower: normalizeMemberId(memberId),
    studentId: role === "student" ? memberId : null,
    teacherMemberId: role === "teacher" ? memberId : null,
    photoUrl: fields.photoUrl || "",
    phoneCountry: fields.phoneCountry || "US",
    gender: fields.gender || "",
    bio: fields.bio || "",
    officeTiming: fields.officeTiming || "",
    officeNumber: fields.officeNumber || "",
    country: fields.country || "",
    department: fields.department || "",
    university: fields.university || "",
    enrollmentYear: fields.enrollmentYear || "",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  Object.keys(doc).forEach((k) => {
    if (doc[k] === null) delete doc[k];
  });
  return doc;
}

async function claimMemberIdAndWriteProfile(uid, fields) {
  const db = getDb();
  const idKey = normalizeMemberId(fields.memberId);
  if (!idKey) {
    const err = new Error("Member ID is required.");
    err.code = "invalid-member-id";
    throw err;
  }

  const idRef = db.collection("memberIds").doc(idKey);
  const userRef = db.collection("users").doc(uid);
  const emailLower = (fields.email || "").toLowerCase();
  const userDoc = buildUserDoc(uid, fields);

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

    tx.set(idRef, {
      uid,
      emailLower,
      memberId: String(fields.memberId || "").trim(),
      role: fields.role,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, userDoc, { merge: true });
  });

  return profileFromDoc(uid, userDoc);
}

async function readProfile(uid) {
  const snap = await getDb().collection("users").doc(uid).get();
  if (!snap.exists) return null;
  return profileFromDoc(uid, snap.data());
}

async function verifyEmailPassword(email, password) {
  const apiKey = process.env.FIREBASE_API_KEY;
  if (!apiKey || apiKey.includes("your_web_api_key")) {
    const err = new Error(
      "Set FIREBASE_API_KEY in server/.env (Firebase Web API key)."
    );
    err.code = "server-misconfigured";
    throw err;
  }

  const url =
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" +
    encodeURIComponent(apiKey);

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });

  const data = await resp.json();
  if (!resp.ok) {
    const msg =
      (data.error && data.error.message) || "Invalid email or password.";
    const err = new Error(msg);
    if (
      msg.includes("INVALID_PASSWORD") ||
      msg.includes("EMAIL_NOT_FOUND") ||
      msg.includes("INVALID_LOGIN_CREDENTIALS")
    ) {
      err.code = "invalid-credentials";
    } else if (msg.includes("USER_DISABLED")) {
      err.code = "user-disabled";
    } else {
      err.code = "login-failed";
    }
    throw err;
  }
  return data;
}

async function storePhonePassword(uid, phone, password) {
  const salt = crypto.randomBytes(16);
  const hash = hashPhonePassword(password, salt);
  await getDb()
    .collection("phoneCredentials")
    .doc(uid)
    .set(
      {
        phone,
        salt: salt.toString("hex"),
        hash,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  try {
    await getAuth().updateUser(uid, { password });
  } catch (_) {
    // Optional; phone login uses phoneCredentials hash.
  }
}

// POST /api/auth/signup — email path creates Auth user + profile.
// Phone OTP signup stays on the Flutter client; use complete-phone-signup after OTP.
router.post("/signup", async (req, res) => {
  try {
    const body = req.body || {};
    const email = body.email ? normalizeEmail(body.email) : "";
    const phone = body.phone ? normalizePhoneE164(body.phone) : "";
    const password = String(body.password || "");
    const fullName = String(body.fullName || "").trim();
    const role = String(body.role || "").trim().toLowerCase();
    const memberId = String(body.memberId || "").trim();

    if (!fullName) {
      return sendError(res, 400, "invalid-signup", "fullName is required.");
    }
    if (role !== "teacher" && role !== "student") {
      return sendError(res, 400, "invalid-role", "role must be teacher or student.");
    }
    if (!memberId || !/^\d{1,20}$/.test(memberId)) {
      return sendError(res, 400, "invalid-member-id", "Enter a numeric member ID.");
    }
    if (password.length < 8) {
      return sendError(res, 400, "weak-password", "Password must be at least 8 characters.");
    }

    if (phone && !email) {
      return sendError(
        res,
        400,
        "use-complete-phone-signup",
        "Phone OTP stays on the Flutter client. After OTP, call POST /api/auth/complete-phone-signup with Bearer idToken."
      );
    }

    if (!email.includes("@")) {
      return sendError(res, 400, "invalid-email", "A valid email is required.");
    }

    const auth = getAuth();
    let userRecord;
    try {
      userRecord = await auth.createUser({
        email,
        password,
        displayName: fullName,
        emailVerified: false,
      });
    } catch (err) {
      if (err.code === "auth/email-already-exists") {
        return sendError(res, 409, "email-in-use", "Email is already registered.");
      }
      if (err.code === "auth/weak-password") {
        return sendError(res, 400, "weak-password", "Password is too weak.");
      }
      throw err;
    }

    const fields = {
      fullName,
      email,
      phone: "",
      role,
      memberId,
      phoneCountry: body.phoneCountry,
      gender: body.gender,
      bio: body.bio,
      country: body.country,
      department: body.department,
      university: body.university,
      enrollmentYear: body.enrollmentYear,
      officeTiming: body.officeTiming,
      officeNumber: body.officeNumber,
    };

    let profile;
    try {
      profile = await claimMemberIdAndWriteProfile(userRecord.uid, fields);
      try {
        await auth.setCustomUserClaims(userRecord.uid, { role });
      } catch (_) {
        // Non-fatal.
      }
    } catch (err) {
      try {
        await auth.deleteUser(userRecord.uid);
      } catch (_) {}
      if (err.code === "id-in-use") {
        return sendError(res, 409, "id-in-use", err.message);
      }
      if (err.code === "invalid-member-id") {
        return sendError(res, 400, "invalid-member-id", err.message);
      }
      throw err;
    }

    const customToken = await auth.createCustomToken(userRecord.uid);
    return res.status(201).json({ customToken, user: profile });
  } catch (err) {
    console.error("signup error", err.code || err.message);
    return sendError(res, 500, "signup-failed", "Could not create account.");
  }
});

// POST /api/auth/complete-phone-signup — after client OTP sign-in.
router.post("/complete-phone-signup", requireAuth, async (req, res) => {
  try {
    const uid = req.uid;
    const body = req.body || {};
    const fullName = String(body.fullName || "").trim();
    const role = String(body.role || "").trim().toLowerCase();
    const memberId = String(body.memberId || "").trim();
    const password = String(body.password || "");

    if (!fullName) {
      return sendError(res, 400, "invalid-signup", "fullName is required.");
    }
    if (role !== "teacher" && role !== "student") {
      return sendError(res, 400, "invalid-role", "role must be teacher or student.");
    }
    if (!memberId || !/^\d{1,20}$/.test(memberId)) {
      return sendError(res, 400, "invalid-member-id", "Enter a numeric member ID.");
    }

    const authUser = await getAuth().getUser(uid);
    const phone = authUser.phoneNumber || normalizePhoneE164(body.phone);
    if (!phone) {
      return sendError(
        res,
        400,
        "not-phone-account",
        "Signed-in user has no phone number."
      );
    }

    const fields = {
      fullName,
      email: authUser.email || "",
      phone,
      role,
      memberId,
      phoneCountry: body.phoneCountry,
      gender: body.gender,
      bio: body.bio,
      country: body.country,
      department: body.department,
      university: body.university,
      enrollmentYear: body.enrollmentYear,
    };

    let profile;
    try {
      profile = await claimMemberIdAndWriteProfile(uid, fields);
      try {
        await getAuth().updateUser(uid, { displayName: fullName });
        await getAuth().setCustomUserClaims(uid, { role });
      } catch (_) {}
    } catch (err) {
      if (err.code === "id-in-use") {
        return sendError(res, 409, "id-in-use", err.message);
      }
      throw err;
    }

    if (password.length >= 8) {
      await storePhonePassword(uid, phone, password);
    }

    return res.json({ user: profile });
  } catch (err) {
    console.error("complete-phone-signup error", err.code || err.message);
    return sendError(res, 500, "signup-failed", "Could not complete phone signup.");
  }
});

// POST /api/auth/login
router.post("/login", async (req, res) => {
  try {
    const body = req.body || {};
    const password = String(body.password || "");
    const email = body.email ? normalizeEmail(body.email) : "";
    const phone = body.phone ? normalizePhoneE164(body.phone) : "";

    if (!password) {
      return sendError(res, 400, "missing-password", "Password is required.");
    }

    if (email.includes("@")) {
      let itk;
      try {
        itk = await verifyEmailPassword(email, password);
      } catch (err) {
        if (err.code === "server-misconfigured") {
          return sendError(res, 500, err.code, err.message);
        }
        if (err.code === "invalid-credentials") {
          return sendError(res, 401, "invalid-credentials", "Incorrect email or password.");
        }
        return sendError(res, 401, err.code || "login-failed", err.message);
      }

      const uid = itk.localId;
      const customToken = await getAuth().createCustomToken(uid);
      let profile = await readProfile(uid);
      if (!profile) {
        const authUser = await getAuth().getUser(uid);
        profile = {
          uid,
          fullName: authUser.displayName || "",
          email: authUser.email || email,
          phone: authUser.phoneNumber || "",
          role: "student",
          memberId: "",
        };
      }
      return res.json({ customToken, user: profile });
    }

    if (phone.startsWith("+") && phone.length >= 10) {
      let authUser;
      try {
        authUser = await getAuth().getUserByPhoneNumber(phone);
      } catch (err) {
        if (err.code === "auth/user-not-found") {
          return sendError(res, 404, "account-not-found", "Account not found.");
        }
        throw err;
      }

      const credSnap = await getDb()
        .collection("phoneCredentials")
        .doc(authUser.uid)
        .get();
      if (!credSnap.exists) {
        return sendError(
          res,
          400,
          "password-not-set",
          "Phone password is not set for this account."
        );
      }
      const cred = credSnap.data() || {};
      if (!verifyPhonePassword(password, cred.salt, cred.hash)) {
        return sendError(res, 401, "invalid-credentials", "Incorrect phone or password.");
      }

      const customToken = await getAuth().createCustomToken(authUser.uid);
      let profile = await readProfile(authUser.uid);
      if (!profile) {
        profile = {
          uid: authUser.uid,
          fullName: authUser.displayName || "",
          email: authUser.email || "",
          phone: authUser.phoneNumber || phone,
          role: "student",
          memberId: "",
        };
      }
      return res.json({ customToken, user: profile });
    }

    return sendError(
      res,
      400,
      "invalid-login",
      "Provide email or phone with password."
    );
  } catch (err) {
    console.error("login error", err.code || err.message);
    return sendError(res, 500, "login-failed", "Could not sign in.");
  }
});

// GET /api/auth/me
router.get("/me", requireAuth, async (req, res) => {
  try {
    const profile = await readProfile(req.uid);
    if (!profile) {
      return sendError(res, 404, "profile-not-found", "User profile not found.");
    }
    let emailVerified = false;
    try {
      const authUser = await getAuth().getUser(req.uid);
      emailVerified = !!authUser.emailVerified;
    } catch (_) {}
    return res.json({ user: { ...profile, emailVerified } });
  } catch (err) {
    console.error("me error", err.message);
    return sendError(res, 500, "session-failed", "Could not load session.");
  }
});

// GET /api/auth/session — alias
router.get("/session", requireAuth, async (req, res) => {
  try {
    const profile = await readProfile(req.uid);
    if (!profile) {
      return sendError(res, 404, "profile-not-found", "User profile not found.");
    }
    return res.json({ user: profile });
  } catch (err) {
    return sendError(res, 500, "session-failed", "Could not load session.");
  }
});


async function sendPasswordResetEmail(email) {
  const apiKey = process.env.FIREBASE_API_KEY;
  if (!apiKey || apiKey.includes("your_web_api_key")) {
    const err = new Error(
      "Set FIREBASE_API_KEY in server/.env (Firebase Web API key)."
    );
    err.code = "server-misconfigured";
    throw err;
  }

  const url =
    "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=" +
    encodeURIComponent(apiKey);

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      requestType: "PASSWORD_RESET",
      email,
    }),
  });

  const data = await resp.json();
  if (!resp.ok) {
    const msg =
      (data.error && data.error.message) || "Could not send password reset.";
    const err = new Error(msg);
    if (msg.includes("EMAIL_NOT_FOUND")) {
      err.code = "account-not-found";
    } else if (msg.includes("INVALID_EMAIL")) {
      err.code = "invalid-email";
    } else {
      err.code = "password-reset-failed";
    }
    throw err;
  }
  return data;
}

// POST /api/auth/password-reset/email — Identity Toolkit sendOobCode
router.post("/password-reset/email", async (req, res) => {
  try {
    const email = normalizeEmail((req.body && req.body.email) || "");
    if (!email.includes("@")) {
      return sendError(res, 400, "invalid-email", "A valid email is required.");
    }
    try {
      await sendPasswordResetEmail(email);
    } catch (err) {
      if (err.code === "server-misconfigured") {
        return sendError(res, 500, err.code, err.message);
      }
      if (err.code === "account-not-found") {
        return sendError(res, 404, "account-not-found", "Account not found.");
      }
      if (err.code === "invalid-email") {
        return sendError(res, 400, "invalid-email", "A valid email is required.");
      }
      console.error("password-reset email error", err.message);
      return sendError(
        res,
        500,
        "password-reset-failed",
        "Could not send password reset email."
      );
    }
    return res.json({ ok: true, email });
  } catch (err) {
    console.error("password-reset email error", err.message);
    return sendError(
      res,
      500,
      "password-reset-failed",
      "Could not send password reset email."
    );
  }
});

// POST /api/auth/phone-password — replace Cloud Function setPhonePassword
router.post("/phone-password", requireAuth, async (req, res) => {
  try {
    const password = String((req.body && req.body.password) || "");
    if (password.length < 8) {
      return sendError(
        res,
        400,
        "weak-password",
        "Password must be at least 8 characters."
      );
    }

    let authUser;
    try {
      authUser = await getAuth().getUser(req.uid);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        return sendError(res, 404, "account-not-found", "Account not found.");
      }
      throw err;
    }

    const phone = authUser.phoneNumber || "";
    if (!phone) {
      return sendError(
        res,
        400,
        "not-phone-account",
        "Only phone accounts can set a phone password."
      );
    }

    await storePhonePassword(req.uid, phone, password);
    return res.json({ ok: true });
  } catch (err) {
    console.error("phone-password error", err.code || err.message);
    return sendError(
      res,
      500,
      "phone-password-failed",
      "Could not set phone password."
    );
  }
});


async function sendEmailVerificationOob(idToken, continueUrl) {
  const apiKey = process.env.FIREBASE_API_KEY;
  if (!apiKey || apiKey.includes("your_web_api_key")) {
    const err = new Error(
      "Set FIREBASE_API_KEY in server/.env (Firebase Web API key)."
    );
    err.code = "server-misconfigured";
    throw err;
  }

  const url =
    "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=" +
    encodeURIComponent(apiKey);

  const body = {
    requestType: "VERIFY_EMAIL",
    idToken,
  };
  if (continueUrl) {
    body.continueUrl = continueUrl;
    body.canHandleCodeInApp = false;
  }

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const data = await resp.json();
  if (!resp.ok) {
    const msg =
      (data.error && data.error.message) || "Could not send verification email.";
    const err = new Error(msg);
    if (
      msg.includes("TOO_MANY_ATTEMPTS") ||
      msg.includes("TOO_MANY_ATTEMPTS_TRY_LATER")
    ) {
      err.code = "too-many-attempts";
    } else if (msg.includes("INVALID_ID_TOKEN") || msg.includes("TOKEN_EXPIRED")) {
      err.code = "invalid-token";
    } else if (msg.includes("EMAIL_NOT_FOUND")) {
      err.code = "account-not-found";
    } else {
      err.code = "email-verification-failed";
    }
    throw err;
  }
  return data;
}

// POST /api/auth/email-verification/resend — Identity Toolkit VERIFY_EMAIL
router.post("/email-verification/resend", requireAuth, async (req, res) => {
  try {
    const header = req.headers.authorization || "";
    const match = header.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : "";
    if (!idToken) {
      return sendError(res, 401, "auth-required", "Missing Authorization Bearer token.");
    }

    let authUser;
    try {
      authUser = await getAuth().getUser(req.uid);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        return sendError(res, 404, "account-not-found", "Account not found.");
      }
      throw err;
    }

    if (!authUser.email) {
      return sendError(res, 400, "no-email", "This account has no email address.");
    }
    if (authUser.emailVerified) {
      return res.json({ ok: true, alreadyVerified: true, email: authUser.email });
    }

    const continueUrl =
      String((req.body && req.body.continueUrl) || "").trim() ||
      process.env.EMAIL_CONTINUE_URL ||
      "https://learnsync-bb5e6.firebaseapp.com/";

    try {
      await sendEmailVerificationOob(idToken, continueUrl);
    } catch (err) {
      if (err.code === "server-misconfigured") {
        return sendError(res, 500, err.code, err.message);
      }
      if (err.code === "too-many-attempts") {
        return sendError(
          res,
          429,
          "too-many-attempts",
          "Too many attempts. Try again later."
        );
      }
      if (err.code === "invalid-token") {
        return sendError(res, 401, "invalid-token", "Invalid or expired ID token.");
      }
      console.error("email-verification resend error", err.message);
      return sendError(
        res,
        500,
        "email-verification-failed",
        "Could not send verification email."
      );
    }

    return res.json({ ok: true, email: authUser.email });
  } catch (err) {
    console.error("email-verification resend error", err.message);
    return sendError(
      res,
      500,
      "email-verification-failed",
      "Could not send verification email."
    );
  }
});

// POST /api/auth/logout — client still must FirebaseAuth.signOut()
router.post("/logout", (_req, res) => {
  return res.json({ ok: true });
});

module.exports = router;
