require("dotenv").config();

function warnIfEnvIncomplete() {
  const cred =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    process.env.FIREBASE_SERVICE_ACCOUNT ||
    "";
  const apiKey = process.env.FIREBASE_API_KEY || "";
  const credPlaceholder =
    !cred ||
    /path\/to\/|your_|example|CHANGE_ME|placeholder|TODO/i.test(cred);
  const apiPlaceholder =
    !apiKey ||
    /your_|example|CHANGE_ME|placeholder|TODO|xxx/i.test(apiKey);

  if (credPlaceholder || apiPlaceholder) {
    console.warn("");
    console.warn("=== server/.env incomplete ===");
    if (credPlaceholder) {
      console.warn(
        "- GOOGLE_APPLICATION_CREDENTIALS (or FIREBASE_SERVICE_ACCOUNT) is missing or still a placeholder."
      );
    }
    if (apiPlaceholder) {
      console.warn(
        "- FIREBASE_API_KEY is missing or still a placeholder."
      );
    }
    console.warn(
      "Edit server/.env once and keep it. Do NOT run: copy .env.example .env"
    );
    console.warn(
      "(That overwrite wipes your real keys.) Use: .\\ensure-env.ps1"
    );
    console.warn("==============================");
    console.warn("");
  }
}

const http = require("http");
const express = require("express");
const cors = require("cors");
const { initFirebase } = require("./firebase");
const authRoutes = require("./routes/auth");
const { router: usersRoutes, memberIdsRouter } = require("./routes/users");
const coursesRoutes = require("./routes/courses");
const filesRoutes = require("./routes/files");
const courseHubRoutes = require("./routes/course_hub");
const {
  courseRouter: enrollmentCourseRoutes,
  joinRequestsRouter,
  studentsRouter,
  teachersRouter,
} = require("./routes/enrollment");
const {
  courseRouter: liveSessionsCourseRoutes,
  lecturesRouter: liveSessionsLecturesRoutes,
} = require("./routes/live_sessions");
const feedbackRoutes = require("./routes/feedback");
const meetingsRoutes = require("./routes/meetings");
const {
  aiPracticeRouter,
  lecturesPracticeRouter,
} = require("./routes/ai_practice");
const {
  teachersRouter: analyticsTeachersRoutes,
  studentsRouter: analyticsStudentsRoutes,
} = require("./routes/analytics");
const { attachRealtime } = require("./realtime");

const app = express();
const port = Number(process.env.PORT) || 3000;

// CORS: localhost / 127.0.0.1 any port (Flutter web + emulators).
const corsOptions = {
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true);
    }
    try {
      const u = new URL(origin);
      if (
        u.hostname === "localhost" ||
        u.hostname === "127.0.0.1" ||
        u.hostname === "[::1]"
      ) {
        return callback(null, true);
      }
    } catch (_) {}
    return callback(null, false);
  },
  methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Authorization", "Content-Type"],
  credentials: true,
};

app.use(cors(corsOptions));

// Chrome Private Network Access (Flutter web ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ 127.0.0.1).
app.use((req, res, next) => {
  if (req.headers["access-control-request-private-network"] === "true") {
    res.setHeader("Access-Control-Allow-Private-Network", "true");
  }
  res.setHeader("Access-Control-Allow-Private-Network", "true");
  next();
});

app.use(express.json({ limit: "30mb" }));

app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "learnsync-server" });
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/auth", authRoutes);
app.use("/api/users", usersRoutes);
app.use("/api/member-ids", memberIdsRouter);
app.use("/api/courses", coursesRoutes);
app.use("/api/courses", filesRoutes);
app.use("/api/courses", courseHubRoutes);
app.use("/api/courses", enrollmentCourseRoutes);
app.use("/api/join-requests", joinRequestsRouter);
app.use("/api/students", studentsRouter);
app.use("/api/teachers", teachersRouter);
app.use("/api/courses", liveSessionsCourseRoutes);
app.use("/api/lectures", liveSessionsLecturesRoutes);
app.use("/api/feedback", feedbackRoutes);
app.use("/api/meeting-requests", meetingsRoutes);
app.use("/api/ai-practice", aiPracticeRouter);
app.use("/api/lectures", lecturesPracticeRouter);
app.use("/api/teachers", analyticsTeachersRoutes);
app.use("/api/students", analyticsStudentsRoutes);

app.use((err, _req, res, _next) => {
  console.error("unhandled", err.message);
  res.status(500).json({ error: "internal", message: "Something went wrong." });
});

warnIfEnvIncomplete();

try {
  initFirebase();
  console.log("Firebase Admin initialized.");
} catch (err) {
  console.warn("Firebase Admin not ready yet:", err.message);
  console.warn("Set credentials in server/.env then restart.");
}

const server = http.createServer(app);

try {
  attachRealtime(server);
} catch (err) {
  console.warn("Realtime bridge not ready:", err.message);
}

server.listen(port, "0.0.0.0", () => {
  console.log("Server running on http://127.0.0.1:" + port);
  console.log("Android emulator: http://10.0.2.2:" + port);
  console.log("Socket.io realtime: /socket.io");
});







