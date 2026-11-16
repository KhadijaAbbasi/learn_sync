const { Server } = require("socket.io");
const { getAuth, getDb } = require("./firebase");

const READ_LIMIT = 400;

function toJsonValue(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate().toISOString();
    } catch (_) {
      return null;
    }
  }
  if (Array.isArray(value)) return value.map(toJsonValue);
  if (typeof value === "object") {
    if (
      typeof value.path === "string" &&
      typeof value.id === "string" &&
      value.firestore
    ) {
      return value.path;
    }
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = toJsonValue(v);
    }
    return out;
  }
  return value;
}

function serializeDoc(id, data) {
  return { id, ...toJsonValue(data || {}) };
}

function emitError(socket, id, channel, err) {
  socket.emit("rt", { id, channel, error: (err && err.message) || String(err) });
}

function listenQuery(socket, subs, id, channel, query, mapFn) {
  const unsub = query.onSnapshot(
    (snap) => {
      socket.emit("rt", {
        id,
        channel,
        data: mapFn(snap),
      });
    },
    (err) => emitError(socket, id, channel, err)
  );
  subs.set(id, unsub);
}

function listenDoc(socket, subs, id, channel, ref, mapFn) {
  const unsub = ref.onSnapshot(
    (snap) => {
      socket.emit("rt", {
        id,
        channel,
        data: mapFn(snap),
      });
    },
    (err) => emitError(socket, id, channel, err)
  );
  subs.set(id, unsub);
}

/**
 * Socket.io bridge: Flutter connects with Firebase ID token,
 * then subscribe/unsubscribe to Firestore Admin realtime listeners.
 */
function attachRealtime(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin(origin, callback) {
        if (!origin) return callback(null, true);
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
      methods: ["GET", "POST"],
      credentials: true,
    },
  });

  io.use(async (socket, next) => {
    try {
      const token =
        (socket.handshake.auth && socket.handshake.auth.token) ||
        socket.handshake.query.token ||
        "";
      if (!token || typeof token !== "string") {
        return next(new Error("auth-required"));
      }
      const decoded = await getAuth().verifyIdToken(token);
      socket.uid = decoded.uid;
      return next();
    } catch (err) {
      return next(new Error("invalid-token"));
    }
  });

  io.on("connection", (socket) => {
    const subs = new Map();

    const clearSub = (id) => {
      const unsub = subs.get(id);
      if (unsub) {
        try {
          unsub();
        } catch (_) {}
        subs.delete(id);
      }
    };

    socket.on("subscribe", (msg) => {
      try {
        const id = String((msg && msg.id) || "");
        const channel = String((msg && msg.channel) || "");
        if (!id || !channel) return;

        clearSub(id);
        const db = getDb();
        const courseId = String((msg && msg.courseId) || "");
        const sessionId = String((msg && msg.sessionId) || "");
        const chapterId = String((msg && msg.chapterId) || "");
        const topicId = String((msg && msg.topicId) || "");
        const lectureId = String((msg && msg.lectureId) || "");
        const teacherId = String((msg && msg.teacherId) || "");
        const studentId = String((msg && msg.studentId) || "");
        const signalId = String((msg && msg.signalId) || "");
        const requestId = String((msg && msg.requestId) || "");
        const userId = String((msg && msg.userId) || "");
        const limit = Math.min(
          Math.max(Number((msg && msg.limit) || READ_LIMIT) || READ_LIMIT, 1),
          READ_LIMIT
        );

        // --- live lecture (existing) ---
        if (channel === "live_session") {
          if (!courseId || !sessionId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db.collection("courses").doc(courseId).collection("liveSessions").doc(sessionId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        if (channel === "active_session") {
          if (!courseId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("liveSessions")
              .where("status", "==", "active")
              .limit(1),
            (snap) => {
              const doc = snap.docs[0];
              return doc ? serializeDoc(doc.id, doc.data()) : null;
            }
          );
          return;
        }

        if (channel === "slide_signals") {
          if (!courseId || !sessionId) return;
          let query = db
            .collection("courses")
            .doc(courseId)
            .collection("liveSessions")
            .doc(sessionId)
            .collection("slideSignals");
          if (studentId) query = query.where("studentId", "==", studentId);
          listenQuery(socket, subs, id, channel, query, (snap) =>
            snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "slide_signal_doc") {
          if (!courseId || !sessionId || !signalId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("liveSessions")
              .doc(sessionId)
              .collection("slideSignals")
              .doc(signalId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        if (channel === "attendees") {
          if (!lectureId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db.collection("lectures").doc(lectureId).collection("attendees"),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        // --- teacher courses / chapters / topics ---
        if (channel === "teacher_courses") {
          if (!teacherId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db.collection("courses").where("teacherId", "==", teacherId),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "chapters") {
          if (!courseId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("chapters")
              .orderBy("position"),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "topics") {
          if (!courseId || !chapterId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("chapters")
              .doc(chapterId)
              .collection("topics")
              .orderBy("position"),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        // --- teacher active live (user pointer + session) ---
        if (channel === "teacher_active_live") {
          if (!teacherId) return;
          let sessionUnsub = null;
          const clearSession = () => {
            if (sessionUnsub) {
              try {
                sessionUnsub();
              } catch (_) {}
              sessionUnsub = null;
            }
          };
          const userUnsub = db
            .collection("users")
            .doc(teacherId)
            .onSnapshot(
              (userSnap) => {
                clearSession();
                const data = userSnap.data() || {};
                const cId = String(data.activeLiveCourseId || "");
                const sId = String(data.activeLiveSessionId || "");
                if (!cId || !sId) {
                  socket.emit("rt", { id, channel, data: null });
                  return;
                }
                sessionUnsub = db
                  .collection("courses")
                  .doc(cId)
                  .collection("liveSessions")
                  .doc(sId)
                  .onSnapshot(
                    (sessionSnap) => {
                      if (!sessionSnap.exists || !sessionSnap.data()) {
                        socket.emit("rt", { id, channel, data: null });
                        return;
                      }
                      const session = serializeDoc(
                        sessionSnap.id,
                        sessionSnap.data()
                      );
                      session.courseId = cId;
                      if (session.status !== "active") {
                        socket.emit("rt", { id, channel, data: null });
                        return;
                      }
                      socket.emit("rt", { id, channel, data: session });
                    },
                    (err) => emitError(socket, id, channel, err)
                  );
              },
              (err) => emitError(socket, id, channel, err)
            );
          subs.set(id, () => {
            clearSession();
            userUnsub();
          });
          return;
        }

        // --- ended sessions ---
        if (channel === "ended_sessions") {
          if (!courseId) return;
          let query = db
            .collection("courses")
            .doc(courseId)
            .collection("liveSessions")
            .where("status", "==", "ended");
          if (chapterId) query = query.where("chapterId", "==", chapterId);
          if (topicId) query = query.where("topicId", "==", topicId);
          query = query.orderBy("endedAt", "desc");
          if (!chapterId && !topicId) {
            query = query.limit(limit);
          }
          listenQuery(socket, subs, id, channel, query, (snap) =>
            snap.docs.map((d) => {
              const row = serializeDoc(d.id, d.data());
              row.courseId = courseId;
              return row;
            })
          );
          return;
        }

        // --- live join requests ---
        if (channel === "live_join_requests") {
          if (!courseId || !sessionId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("liveSessions")
              .doc(sessionId)
              .collection("joinRequests")
              .orderBy("requestedAt"),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "live_join_request_doc") {
          if (!courseId || !sessionId || !studentId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("liveSessions")
              .doc(sessionId)
              .collection("joinRequests")
              .doc(studentId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        // --- lectures ---
        if (channel === "lecture_doc") {
          if (!lectureId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db.collection("lectures").doc(lectureId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        if (channel === "teacher_lectures") {
          if (!teacherId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("lectures")
              .where("teacherId", "==", teacherId)
              .limit(limit),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        // --- feedback ---
        if (channel === "feedback_doc") {
          const feedbackId = String((msg && msg.feedbackId) || "");
          if (!feedbackId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db.collection("feedback").doc(feedbackId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        if (channel === "teacher_feedback") {
          if (!teacherId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("feedback")
              .where("teacherId", "==", teacherId)
              .limit(limit),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "lecture_feedback") {
          if (!lectureId) return;
          let query = db
            .collection("feedback")
            .where("lectureId", "==", lectureId);
          if (teacherId) query = query.where("teacherId", "==", teacherId);
          listenQuery(socket, subs, id, channel, query, (snap) =>
            snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        // --- practice attempts ---
        if (channel === "practice_attempts") {
          if (!lectureId) return;
          let query = db
            .collection("lectures")
            .doc(lectureId)
            .collection("practiceAttempts");
          if (studentId) query = query.where("studentId", "==", studentId);
          else query = query.limit(limit);
          listenQuery(socket, subs, id, channel, query, (snap) =>
            snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "practice_attempts_by_teacher") {
          if (!teacherId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collectionGroup("practiceAttempts")
              .where("teacherId", "==", teacherId)
              .limit(limit),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        // --- course hub doc ---
        if (channel === "course_doc") {
          if (!courseId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db.collection("courses").doc(courseId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        // --- meetings ---
        if (channel === "meeting_requests") {
          let query = db.collection("meetingRequests");
          if (studentId) query = query.where("studentId", "==", studentId);
          else if (teacherId) query = query.where("teacherId", "==", teacherId);
          else return;
          listenQuery(socket, subs, id, channel, query, (snap) =>
            snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        if (channel === "meeting_request_doc") {
          if (!requestId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db.collection("meetingRequests").doc(requestId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        // --- enrollment ---
        if (channel === "course_join_request_doc") {
          if (!courseId || !studentId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("joinRequests")
              .doc(studentId),
            (snap) => (snap.exists ? serializeDoc(snap.id, snap.data()) : null)
          );
          return;
        }

        if (channel === "course_member_doc") {
          if (!courseId || !studentId) return;
          listenDoc(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("members")
              .doc(studentId),
            (snap) => ({ exists: snap.exists })
          );
          return;
        }

        if (channel === "course_pending_joins") {
          if (!courseId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db
              .collection("courses")
              .doc(courseId)
              .collection("joinRequests")
              .where("status", "==", "pending"),
            (snap) =>
              snap.docs.map((d) => {
                const row = serializeDoc(d.id, d.data());
                if (!row.courseId) row.courseId = courseId;
                return row;
              })
          );
          return;
        }

        if (channel === "course_members") {
          if (!courseId) return;
          listenQuery(
            socket,
            subs,
            id,
            channel,
            db.collection("courses").doc(courseId).collection("members"),
            (snap) => snap.docs.map((d) => serializeDoc(d.id, d.data()))
          );
          return;
        }

        // teacher_pending_joins collectionGroup: rules-heavy on client;
        // server can filter course-level paths for this teacher.
        if (channel === "teacher_pending_joins") {
          if (!teacherId) return;
          const unsub = db
            .collectionGroup("joinRequests")
            .where("status", "==", "pending")
            .onSnapshot(
              async (snap) => {
                try {
                  const items = [];
                  for (const doc of snap.docs) {
                    const parts = doc.ref.path.split("/");
                    // courses/{id}/joinRequests/{uid} only
                    if (
                      parts.length !== 4 ||
                      parts[0] !== "courses" ||
                      parts[2] !== "joinRequests"
                    ) {
                      continue;
                    }
                    const cId = parts[1];
                    const course = await db.collection("courses").doc(cId).get();
                    if (
                      !course.exists ||
                      (course.data() || {}).teacherId !== teacherId
                    ) {
                      continue;
                    }
                    const data = doc.data() || {};
                    items.push(
                      serializeDoc(doc.id, {
                        ...data,
                        courseId: data.courseId || cId,
                        courseName:
                          data.courseName || (course.data() || {}).name || "",
                        courseCode:
                          data.courseCode || (course.data() || {}).code || "",
                      })
                    );
                  }
                  items.sort((a, b) => {
                    const left = a.requestedAt || "";
                    const right = b.requestedAt || "";
                    return String(right).localeCompare(String(left));
                  });
                  socket.emit("rt", { id, channel, data: items });
                } catch (err) {
                  emitError(socket, id, channel, err);
                }
              },
              (err) => emitError(socket, id, channel, err)
            );
          subs.set(id, unsub);
          return;
        }

        socket.emit("rt", { id, channel, error: "unknown-channel" });
      } catch (err) {
        console.error("realtime subscribe error", err.message);
      }
    });

    socket.on("unsubscribe", (msg) => {
      const id = String((msg && msg.id) || "");
      if (id) clearSub(id);
    });

    socket.on("disconnect", () => {
      for (const subId of [...subs.keys()]) {
        clearSub(subId);
      }
    });
  });

  console.log("Socket.io realtime bridge attached (extended channels).");
  return io;
}

module.exports = { attachRealtime };
