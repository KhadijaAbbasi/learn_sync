const express = require("express");
const { getDb } = require("../firebase");
const { requireAuth } = require("../middleware/auth");

const teachersRouter = express.Router();
const studentsRouter = express.Router();

const READ_LIMIT = 400;
const ATTENDEE_LECTURE_CAP = 20;
const PRACTICE_LECTURE_CAP = 20;
const DRILL_DOWN_LIMIT = 20;

function sendError(res, status, error, message) {
  return res.status(status).json({ error, message });
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

function toIso(value) {
  const d = toDate(value);
  return d ? d.toISOString() : null;
}

function understandingPoints(level) {
  switch (String(level || "")) {
    case "100":
      return 100;
    case "80":
      return 80;
    case "60":
      return 60;
    case "below50":
      return 40;
    default:
      return 40;
  }
}

function isLowUnderstanding(level) {
  const v = String(level || "");
  return v === "60" || v === "below50";
}

function levelLabel(level) {
  switch (String(level || "")) {
    case "100":
      return "100%";
    case "80":
      return "80%";
    case "60":
      return "60%";
    case "below50":
      return "Below 50%";
    default:
      return String(level || "");
  }
}

function parseFilter(query) {
  const dateRange = String(query.dateRange || "all").trim() || "all";
  return {
    courseId: String(query.courseId || "").trim(),
    chapterId: String(query.chapterId || "").trim(),
    topicId: String(query.topicId || "").trim(),
    dateRange,
    customStart: query.customStart ? toDate(query.customStart) : null,
    customEnd: query.customEnd ? toDate(query.customEnd) : null,
  };
}

function rangeStart(filter, now) {
  if (filter.dateRange === "all") return null;
  if (filter.dateRange === "last7") {
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6);
  }
  if (filter.dateRange === "last30") {
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() - 29);
  }
  if (filter.dateRange === "custom" && filter.customStart) {
    const s = filter.customStart;
    return new Date(s.getFullYear(), s.getMonth(), s.getDate());
  }
  return null;
}

function rangeEnd(filter, now) {
  if (
    filter.dateRange === "all" ||
    filter.dateRange === "last7" ||
    filter.dateRange === "last30"
  ) {
    return new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      23,
      59,
      59,
      999
    );
  }
  if (filter.dateRange === "custom") {
    const end = filter.customEnd || filter.customStart || now;
    return new Date(
      end.getFullYear(),
      end.getMonth(),
      end.getDate(),
      23,
      59,
      59,
      999
    );
  }
  return null;
}

function dateInRange(value, filter, now) {
  if (filter.dateRange === "all") return true;
  if (!value) return false;
  const start = rangeStart(filter, now);
  const end = rangeEnd(filter, now);
  if (start && value < start) return false;
  if (end && value > end) return false;
  return true;
}

function lectureMatches(lecture, filter, now) {
  if (filter.courseId && lecture.courseId !== filter.courseId) return false;
  if (filter.chapterId && lecture.chapterId !== filter.chapterId) return false;
  if (filter.topicId && lecture.topicId !== filter.topicId) return false;
  const when = lecture.endedAt || lecture.startedAt;
  return dateInRange(when, filter, now);
}

function meetingMatches(meeting, filter, now) {
  if (filter.courseId && meeting.courseId !== filter.courseId) return false;
  if (
    filter.chapterId &&
    meeting.chapterId &&
    meeting.chapterId !== filter.chapterId
  ) {
    return false;
  }
  if (filter.topicId && meeting.topicId && meeting.topicId !== filter.topicId) {
    return false;
  }
  return dateInRange(meeting.requestedAt, filter, now);
}

function meetingMatchesLecture(meeting, lecture) {
  const stored = (meeting.lectureId || "").trim();
  const target = (lecture.id || "").trim();
  if (stored && target) return stored === target;
  if (meeting.courseId !== lecture.courseId) return false;
  if (lecture.topicId && meeting.topicId === lecture.topicId) return true;
  const topic = (lecture.topicTitle || "").trim().toLowerCase();
  return (
    topic.length > 0 &&
    (meeting.topicTitle || "").trim().toLowerCase() === topic
  );
}

function needsTeacherAction(status) {
  return status === "pending" || status === "rescheduleRequested";
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
    status: d.status || "",
    studentCount: Number(d.studentCount || 0),
    startedAt: toDate(d.startedAt),
    endedAt: toDate(d.endedAt),
  };
}

function serializeFeedback(id, data) {
  const d = data || {};
  return {
    id,
    lectureId: d.lectureId || "",
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    teacherId: d.teacherId || "",
    studentId: d.studentId || "",
    studentName: d.studentName || "",
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

function serializeMeeting(id, data) {
  const d = data || {};
  return {
    id,
    studentId: d.studentId || "",
    studentName: d.studentName || "",
    teacherId: d.teacherId || "",
    courseId: d.courseId || "",
    courseName: d.courseName || "",
    chapterId: d.chapterId || "",
    chapterTitle: d.chapterTitle || "",
    topicId: d.topicId || "",
    topicTitle: d.topicTitle || "",
    lectureId: d.lectureId || "",
    status: d.status || "pending",
    reason: d.reason || "",
    requestedAt: toDate(d.requestedAt),
    scheduledAt: toIso(d.scheduledAt),
  };
}

function serializeAttempt(id, data, lectureIdFallback) {
  const d = data || {};
  const score = Number(d.score != null ? d.score : 0);
  const total = Number(d.total != null ? d.total : 5);
  const percent =
    d.percent != null
      ? Number(d.percent)
      : total === 0
        ? 0
        : Math.round((score / total) * 100);
  return {
    id,
    lectureId: d.lectureId || lectureIdFallback || "",
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
    completed: d.completed != null ? Boolean(d.completed) : true,
    createdAt: toIso(d.createdAt),
    completedAt: toIso(d.completedAt),
  };
}

function feedbackCounts(items) {
  let percent100 = 0;
  let percent80 = 0;
  let percent60 = 0;
  let below50 = 0;
  for (const item of items) {
    switch (String(item.level || "")) {
      case "100":
        percent100++;
        break;
      case "80":
        percent80++;
        break;
      case "60":
        percent60++;
        break;
      default:
        below50++;
        break;
    }
  }
  return {
    percent100,
    percent80,
    percent60,
    below50,
    total: percent100 + percent80 + percent60 + below50,
  };
}

function meetingStatusCounts(items) {
  let pending = 0;
  let accepted = 0;
  let declined = 0;
  let completed = 0;
  let rescheduleRequested = 0;
  for (const item of items) {
    switch (item.status) {
      case "pending":
        pending++;
        break;
      case "accepted":
        accepted++;
        break;
      case "declined":
        declined++;
        break;
      case "completed":
        completed++;
        break;
      case "rescheduleRequested":
        rescheduleRequested++;
        break;
      default:
        break;
    }
  }
  return {
    pending,
    accepted,
    declined,
    completed,
    rescheduleRequested,
    total:
      pending + accepted + declined + completed + rescheduleRequested,
  };
}

function barsByKey(feedback, keyOf, labelOf, subtitleOf) {
  const sums = {};
  const counts = {};
  const labels = {};
  const subtitles = {};
  for (const item of feedback) {
    const key = keyOf(item);
    if (!key) continue;
    sums[key] = (sums[key] || 0) + understandingPoints(item.level);
    counts[key] = (counts[key] || 0) + 1;
    labels[key] = labelOf(item);
    subtitles[key] = subtitleOf(item);
  }
  return Object.keys(sums)
    .map((key) => ({
      id: key,
      label: labels[key] || key,
      average: sums[key] / counts[key],
      count: counts[key],
      subtitle: subtitles[key] || "",
    }))
    .sort((a, b) => {
      if (a.average !== b.average) return a.average - b.average;
      return String(a.label).localeCompare(String(b.label));
    });
}

function uniqueOptions(lectures, idOf, labelOf) {
  const seen = new Set();
  const options = [];
  for (const lecture of lectures) {
    const id = idOf(lecture);
    if (!id || seen.has(id)) continue;
    seen.add(id);
    const label = String(labelOf(lecture) || "").trim();
    options.push({ id, label: label || id });
  }
  options.sort((a, b) => String(a.label).localeCompare(String(b.label)));
  return options;
}

async function loadTeacherInputs(db, teacherId) {
  const [lecturesSnap, feedbackSnap, meetingsSnap, coursesSnap] =
    await Promise.all([
      db
        .collection("lectures")
        .where("teacherId", "==", teacherId)
        .limit(READ_LIMIT)
        .get(),
      db
        .collection("feedback")
        .where("teacherId", "==", teacherId)
        .limit(READ_LIMIT)
        .get(),
      db
        .collection("meetingRequests")
        .where("teacherId", "==", teacherId)
        .limit(READ_LIMIT)
        .get(),
      db.collection("courses").where("teacherId", "==", teacherId).get(),
    ]);

  const lectures = lecturesSnap.docs.map((doc) =>
    serializeLecture(doc.id, doc.data())
  );
  const feedback = feedbackSnap.docs.map((doc) =>
    serializeFeedback(doc.id, doc.data())
  );
  const meetings = meetingsSnap.docs.map((doc) =>
    serializeMeeting(doc.id, doc.data())
  );
  const courses = coursesSnap.docs.map((doc) => {
    const d = doc.data() || {};
    return { id: doc.id, name: d.name || doc.id };
  });

  const practiceIds = lectures.slice(0, PRACTICE_LECTURE_CAP).map((l) => l.id);
  let attempts = [];
  try {
    const attemptSnap = await db
      .collectionGroup("practiceAttempts")
      .where("teacherId", "==", teacherId)
      .limit(READ_LIMIT)
      .get();
    attempts = attemptSnap.docs.map((doc) => {
      const parts = doc.ref.path.split("/");
      const lectureId =
        parts.length >= 2 && parts[0] === "lectures" ? parts[1] : "";
      return serializeAttempt(doc.id, doc.data(), lectureId);
    });
  } catch (err) {
    console.warn("practiceAttempts collectionGroup failed:", err.message);
    for (const lectureId of practiceIds) {
      const snap = await db
        .collection("lectures")
        .doc(lectureId)
        .collection("practiceAttempts")
        .get();
      for (const doc of snap.docs) {
        attempts.push(serializeAttempt(doc.id, doc.data(), lectureId));
      }
    }
  }

  const attendeesByLecture = {};
  const attendeeIds = lectures.slice(0, ATTENDEE_LECTURE_CAP).map((l) => l.id);
  await Promise.all(
    attendeeIds.map(async (lectureId) => {
      const snap = await db
        .collection("lectures")
        .doc(lectureId)
        .collection("attendees")
        .get();
      attendeesByLecture[lectureId] = snap.docs.map((doc) => {
        const d = doc.data() || {};
        return {
          studentId: d.studentId || doc.id,
          studentName: d.studentName || "",
          studentEmail: d.studentEmail || "",
          memberId: d.memberId || "",
        };
      });
    })
  );

  return { lectures, feedback, attempts, meetings, attendeesByLecture, courses };
}

function aggregateReport(inputs, filter, now) {
  const lectures = inputs.lectures.filter((l) =>
    lectureMatches(l, filter, now)
  );
  const lectureIds = new Set(lectures.map((l) => l.id));
  const feedback = inputs.feedback.filter((f) => lectureIds.has(f.lectureId));
  const attempts = inputs.attempts.filter((a) => lectureIds.has(a.lectureId));
  const meetings = inputs.meetings.filter((m) =>
    meetingMatches(m, filter, now)
  );

  const counts = feedbackCounts(feedback);
  let scoreSum = 0;
  for (const item of feedback) scoreSum += understandingPoints(item.level);
  const understandingAverage =
    counts.total === 0 ? 0 : scoreSum / counts.total;

  let scoreTotal = 0;
  let scoreCount = 0;
  for (const attempt of attempts) {
    if (attempt.completed) {
      scoreTotal += attempt.percent;
      scoreCount++;
    }
  }

  const uniqueAttendeeIds = new Set();
  const attendeeNames = {};
  let fallbackAttendeeCount = 0;
  for (const lecture of lectures) {
    const attendees = inputs.attendeesByLecture[lecture.id];
    if (attendees && attendees.length) {
      for (const attendee of attendees) {
        const id = String(attendee.studentId || "").trim();
        if (!id) continue;
        uniqueAttendeeIds.add(id);
        attendeeNames[id] =
          String(attendee.studentName || "").trim() || id;
      }
    } else if (lecture.studentCount > 0) {
      fallbackAttendeeCount += lecture.studentCount;
    }
  }
  const attendeeCount =
    uniqueAttendeeIds.size > 0
      ? uniqueAttendeeIds.size
      : fallbackAttendeeCount;

  const participants = new Set(
    attempts.map((a) => a.studentId).filter(Boolean)
  ).size;
  const completions = new Set(
    attempts
      .filter((a) => a.completed)
      .map((a) => a.studentId)
      .filter(Boolean)
  ).size;
  const practice = {
    participants,
    completions,
    attendeeCount,
    averageScore: scoreCount === 0 ? 0 : scoreTotal / scoreCount,
    attemptCount: attempts.length,
    participationPercent:
      attendeeCount === 0
        ? 0
        : Math.round((participants / attendeeCount) * 100),
    completionPercent:
      attendeeCount === 0
        ? 0
        : Math.round((completions / attendeeCount) * 100),
  };

  const byTopic = barsByKey(
    feedback,
    (item) => item.topicId || item.topicTitle,
    (item) =>
      String(item.topicTitle || "").trim() || item.topicId || "Topic",
    (item) => item.courseName || ""
  );
  const bySession = barsByKey(
    feedback,
    (item) => item.lectureId,
    (item) =>
      String(item.topicTitle || "").trim() || item.lectureId || "Session",
    (item) => {
      const chapter = String(item.chapterTitle || "").trim();
      const course = String(item.courseName || "").trim();
      if (chapter && course) return `${course} · ${chapter}`;
      return course || chapter;
    }
  );

  const lowUnderstanding = feedback
    .filter((item) => isLowUnderstanding(item.level))
    .map((item) => ({
      studentId: item.studentId,
      studentName: item.studentName,
      detail: levelLabel(item.level),
      topicTitle: item.topicTitle || "",
      courseName: item.courseName || "",
    }))
    .sort((a, b) =>
      String(a.studentName).localeCompare(String(b.studentName))
    )
    .slice(0, DRILL_DOWN_LIMIT);

  const practicedStudents = new Set(
    attempts.map((a) => a.studentId).filter(Boolean)
  );
  const incompleteCandidates = {};
  for (const lecture of lectures) {
    const attendees = inputs.attendeesByLecture[lecture.id];
    const candidates = [];
    if (attendees && attendees.length) {
      for (const a of attendees) {
        candidates.push({
          id: a.studentId,
          name: a.studentName,
        });
      }
    } else {
      for (const item of feedback) {
        if (item.lectureId === lecture.id) {
          candidates.push({
            id: item.studentId,
            name: item.studentName,
          });
        }
      }
    }
    for (const student of candidates) {
      const id = String(student.id || "").trim();
      if (!id || practicedStudents.has(id)) continue;
      if (!incompleteCandidates[id]) {
        incompleteCandidates[id] = {
          studentId: id,
          studentName: student.name || id,
          detail: lecture.topicTitle || "",
          topicTitle: lecture.topicTitle || "",
          courseName: lecture.courseName || "",
        };
      }
    }
  }
  const incompletePractice = Object.values(incompleteCandidates)
    .sort((a, b) =>
      String(a.studentName).localeCompare(String(b.studentName))
    )
    .slice(0, DRILL_DOWN_LIMIT);

  const pendingMeetings = meetings
    .filter((m) => needsTeacherAction(m.status))
    .map((m) => ({
      studentId: m.studentId,
      studentName: m.studentName,
      detail: m.topicTitle || "",
      topicTitle: m.topicTitle || "",
      courseName: m.courseName || "",
      requestId: m.id,
      status: m.status,
    }))
    .slice(0, DRILL_DOWN_LIMIT);

  let courseOptions = inputs.courses.map((c) => ({
    id: c.id,
    label: c.name || c.id,
  }));
  if (!courseOptions.length) {
    const seen = new Set();
    for (const lecture of inputs.lectures) {
      if (!lecture.courseId || seen.has(lecture.courseId)) continue;
      seen.add(lecture.courseId);
      courseOptions.push({
        id: lecture.courseId,
        label: lecture.courseName || lecture.courseId,
      });
    }
  }

  const scopedForChapter = inputs.lectures.filter(
    (l) => !filter.courseId || l.courseId === filter.courseId
  );
  const chapterOptions = uniqueOptions(
    scopedForChapter,
    (l) => l.chapterId,
    (l) => l.chapterTitle
  );
  const scopedForTopic = scopedForChapter.filter(
    (l) => !filter.chapterId || l.chapterId === filter.chapterId
  );
  const topicOptions = uniqueOptions(
    scopedForTopic,
    (l) => l.topicId,
    (l) => l.topicTitle
  );

  const feedbackByStudent = {};
  for (const item of feedback) {
    const id = String(item.studentId || "").trim();
    if (!id) continue;
    if (!feedbackByStudent[id]) feedbackByStudent[id] = [];
    feedbackByStudent[id].push(item);
    if (!attendeeNames[id]) {
      attendeeNames[id] =
        String(item.studentName || "").trim() || id;
    }
    uniqueAttendeeIds.add(id);
  }

  const practiceBest = {};
  for (const attempt of attempts) {
    const id = String(attempt.studentId || "").trim();
    if (!id) continue;
    if (!attendeeNames[id]) {
      attendeeNames[id] =
        String(attempt.studentName || "").trim() || id;
    }
    uniqueAttendeeIds.add(id);
    if (practiceBest[id] == null || attempt.percent > practiceBest[id]) {
      practiceBest[id] = attempt.percent;
    }
  }

  const meetingStudentIds = new Set(
    meetings.map((m) => m.studentId).filter(Boolean)
  );
  const pendingMeetingIds = new Set(
    meetings
      .filter((m) => needsTeacherAction(m.status))
      .map((m) => m.studentId)
      .filter(Boolean)
  );

  const studentIds = new Set([
    ...uniqueAttendeeIds,
    ...Object.keys(feedbackByStudent),
    ...Object.keys(practiceBest),
  ]);
  const studentRows = [];
  for (const id of studentIds) {
    const fb = feedbackByStudent[id] || [];
    let understandingPercent = null;
    if (fb.length) {
      const sum = fb.reduce(
        (s, e) => s + understandingPoints(e.level),
        0
      );
      understandingPercent = sum / fb.length;
    }
    const practicePercent =
      practiceBest[id] != null ? Number(practiceBest[id]) : null;
    const hasMeetingRequest = meetingStudentIds.has(id);
    const needsAttention =
      (understandingPercent != null && understandingPercent < 70) ||
      pendingMeetingIds.has(id) ||
      (practicePercent == null && uniqueAttendeeIds.has(id));
    studentRows.push({
      studentId: id,
      studentName: attendeeNames[id] || id,
      understandingPercent,
      practicePercent,
      hasMeetingRequest,
      needsAttention,
    });
  }
  studentRows.sort((a, b) => {
    if (a.needsAttention !== b.needsAttention) {
      return a.needsAttention ? -1 : 1;
    }
    return String(a.studentName).localeCompare(String(b.studentName));
  });

  return {
    understanding: counts,
    understandingAverage,
    practice,
    meetings: meetingStatusCounts(meetings),
    byTopic,
    bySession,
    lowUnderstanding,
    incompletePractice,
    pendingMeetings,
    courseOptions,
    chapterOptions,
    topicOptions,
    lectureCount: lectures.length,
    uniqueStudentCount: uniqueAttendeeIds.size + fallbackAttendeeCount,
    studentRows: studentRows.slice(0, DRILL_DOWN_LIMIT * 2),
    filter,
  };
}

function assertSelfTeacher(req, teacherId) {
  if (!teacherId) {
    return { ok: false, status: 400, error: "invalid-request", message: "teacherId is required." };
  }
  if (teacherId !== req.uid) {
    return {
      ok: false,
      status: 403,
      error: "forbidden",
      message: "You can only read your own teacher analytics.",
    };
  }
  return { ok: true };
}

// GET /api/teachers/:teacherId/analytics/understanding
teachersRouter.get(
  "/:teacherId/analytics/understanding",
  requireAuth,
  async (req, res) => {
    try {
      const teacherId = String(req.params.teacherId || "").trim();
      const gate = assertSelfTeacher(req, teacherId);
      if (!gate.ok) {
        return sendError(res, gate.status, gate.error, gate.message);
      }
      const filter = parseFilter(req.query || {});
      const inputs = await loadTeacherInputs(getDb(), teacherId);
      const report = aggregateReport(inputs, filter, new Date());
      return res.json({
        understanding: report.understanding,
        understandingAverage: report.understandingAverage,
        byTopic: report.byTopic,
        bySession: report.bySession,
        lowUnderstanding: report.lowUnderstanding,
        lectureCount: report.lectureCount,
        uniqueStudentCount: report.uniqueStudentCount,
        studentRows: report.studentRows.map((row) => ({
          studentId: row.studentId,
          studentName: row.studentName,
          understandingPercent: row.understandingPercent,
          needsAttention: row.needsAttention,
        })),
        courseOptions: report.courseOptions,
        chapterOptions: report.chapterOptions,
        topicOptions: report.topicOptions,
        filter: report.filter,
      });
    } catch (err) {
      console.error("analytics/understanding", err.message);
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// GET /api/teachers/:teacherId/analytics/practice
teachersRouter.get(
  "/:teacherId/analytics/practice",
  requireAuth,
  async (req, res) => {
    try {
      const teacherId = String(req.params.teacherId || "").trim();
      const gate = assertSelfTeacher(req, teacherId);
      if (!gate.ok) {
        return sendError(res, gate.status, gate.error, gate.message);
      }
      const filter = parseFilter(req.query || {});
      const inputs = await loadTeacherInputs(getDb(), teacherId);
      const report = aggregateReport(inputs, filter, new Date());
      return res.json({
        practice: report.practice,
        incompletePractice: report.incompletePractice,
        lectureCount: report.lectureCount,
        uniqueStudentCount: report.uniqueStudentCount,
        studentRows: report.studentRows.map((row) => ({
          studentId: row.studentId,
          studentName: row.studentName,
          practicePercent: row.practicePercent,
          needsAttention: row.needsAttention,
        })),
        courseOptions: report.courseOptions,
        chapterOptions: report.chapterOptions,
        topicOptions: report.topicOptions,
        filter: report.filter,
      });
    } catch (err) {
      console.error("analytics/practice", err.message);
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// GET /api/teachers/:teacherId/analytics/meetings
teachersRouter.get(
  "/:teacherId/analytics/meetings",
  requireAuth,
  async (req, res) => {
    try {
      const teacherId = String(req.params.teacherId || "").trim();
      const gate = assertSelfTeacher(req, teacherId);
      if (!gate.ok) {
        return sendError(res, gate.status, gate.error, gate.message);
      }
      const filter = parseFilter(req.query || {});
      const inputs = await loadTeacherInputs(getDb(), teacherId);
      const report = aggregateReport(inputs, filter, new Date());
      return res.json({
        meetings: report.meetings,
        pendingMeetings: report.pendingMeetings,
        lectureCount: report.lectureCount,
        courseOptions: report.courseOptions,
        chapterOptions: report.chapterOptions,
        topicOptions: report.topicOptions,
        filter: report.filter,
      });
    } catch (err) {
      console.error("analytics/meetings", err.message);
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// GET /api/teachers/:teacherId/analytics/lectures/:lectureId
teachersRouter.get(
  "/:teacherId/analytics/lectures/:lectureId",
  requireAuth,
  async (req, res) => {
    try {
      const teacherId = String(req.params.teacherId || "").trim();
      const lectureId = String(req.params.lectureId || "").trim();
      const gate = assertSelfTeacher(req, teacherId);
      if (!gate.ok) {
        return sendError(res, gate.status, gate.error, gate.message);
      }
      if (!lectureId) {
        return sendError(res, 400, "invalid-request", "lectureId is required.");
      }

      const db = getDb();
      const lectureSnap = await db.collection("lectures").doc(lectureId).get();
      if (!lectureSnap.exists) {
        return sendError(res, 404, "not-found", "Lecture not found.");
      }
      const lecture = serializeLecture(lectureSnap.id, lectureSnap.data());
      if (lecture.teacherId && lecture.teacherId !== teacherId) {
        return sendError(
          res,
          403,
          "forbidden",
          "Lecture does not belong to this teacher."
        );
      }

      const [feedbackSnap, attendeesSnap, attemptsSnap, meetingsSnap] =
        await Promise.all([
          db.collection("feedback").where("lectureId", "==", lectureId).get(),
          lectureSnap.ref.collection("attendees").get(),
          lectureSnap.ref.collection("practiceAttempts").get(),
          db
            .collection("meetingRequests")
            .where("teacherId", "==", teacherId)
            .limit(READ_LIMIT)
            .get(),
        ]);

      const feedback = feedbackSnap.docs.map((doc) =>
        serializeFeedback(doc.id, doc.data())
      );
      const attendees = attendeesSnap.docs.map((doc) => {
        const d = doc.data() || {};
        return {
          studentId: d.studentId || doc.id,
          studentName: d.studentName || "",
          studentEmail: d.studentEmail || "",
          memberId: d.memberId || "",
          inApp: d.inApp != null ? Boolean(d.inApp) : true,
        };
      });
      const attempts = attemptsSnap.docs.map((doc) =>
        serializeAttempt(doc.id, doc.data(), lectureId)
      );
      const allMeetings = meetingsSnap.docs.map((doc) =>
        serializeMeeting(doc.id, doc.data())
      );
      const meetings = allMeetings.filter((m) =>
        meetingMatchesLecture(m, lecture)
      );

      const counts = feedbackCounts(feedback);
      const attendeeRecords = attendees.length;
      const studentCount =
        attendeeRecords > 0
          ? attendeeRecords
          : lecture.studentCount > 0
            ? lecture.studentCount
            : counts.total;

      const practicedIds = new Set(
        attempts.map((a) => a.studentId).filter(Boolean)
      );
      const practiced = practicedIds.size;
      const notPracticed = Math.max(studentCount - practiced, 0);
      const practiceRate =
        studentCount === 0
          ? 0
          : Math.round((practiced / studentCount) * 100);

      let scoreTotal = 0;
      let scoreCount = 0;
      for (const attempt of attempts) {
        if (attempt.completed) {
          scoreTotal += attempt.percent;
          scoreCount++;
        }
      }

      let understandingSum = 0;
      for (const item of feedback) {
        understandingSum += understandingPoints(item.level);
      }

      return res.json({
        lecture: {
          id: lecture.id,
          courseId: lecture.courseId,
          courseName: lecture.courseName,
          chapterId: lecture.chapterId,
          chapterTitle: lecture.chapterTitle,
          topicId: lecture.topicId,
          topicTitle: lecture.topicTitle,
          status: lecture.status,
          studentCount: lecture.studentCount,
          startedAt: toIso(lecture.startedAt),
          endedAt: toIso(lecture.endedAt),
        },
        understanding: counts,
        understandingAverage:
          counts.total === 0 ? 0 : understandingSum / counts.total,
        audienceCount: studentCount,
        responseCount: counts.total,
        practice: {
          practiced,
          notPracticed,
          attendeeCount: studentCount,
          practiceRate,
          attemptCount: attempts.length,
          averageScore: scoreCount === 0 ? 0 : scoreTotal / scoreCount,
        },
        meetings: meetingStatusCounts(meetings),
        meetingCount: meetings.length,
        attendees,
        feedback,
        attempts,
        meetingRequests: meetings.map((m) => ({
          ...m,
          requestedAt: toIso(m.requestedAt),
        })),
      });
    } catch (err) {
      console.error("analytics/lectures/:lectureId", err.message);
      return sendError(res, 500, "internal", "Something went wrong.");
    }
  }
);

// GET /api/students/me/dashboard
studentsRouter.get("/me/dashboard", requireAuth, async (req, res) => {
  try {
    const db = getDb();
    const uid = req.uid;
    const userSnap = await db.collection("users").doc(uid).get();
    const user = userSnap.data() || {};

    let joinedCourses = [];
    try {
      const memberSnap = await db
        .collectionGroup("members")
        .where("studentId", "==", uid)
        .get();
      const courseIds = [];
      for (const doc of memberSnap.docs) {
        const parts = doc.ref.path.split("/");
        if (
          parts.length === 4 &&
          parts[0] === "courses" &&
          parts[2] === "members"
        ) {
          courseIds.push(parts[1]);
        }
      }
      for (const id of [...new Set(courseIds)]) {
        const courseDoc = await db.collection("courses").doc(id).get();
        if (courseDoc.exists) {
          const d = courseDoc.data() || {};
          joinedCourses.push({
            id: courseDoc.id,
            name: d.name || "",
            code: d.code || "",
            teacherId: d.teacherId || "",
            liveSessionId: d.liveSessionId || "",
          });
        }
      }
    } catch (err) {
      console.warn("student dashboard members failed:", err.message);
      const teacherId = user.connectedTeacherId || "";
      if (teacherId) {
        const snap = await db
          .collection("courses")
          .where("teacherId", "==", teacherId)
          .get();
        for (const doc of snap.docs) {
          const member = await doc.ref.collection("members").doc(uid).get();
          if (member.exists) {
            const d = doc.data() || {};
            joinedCourses.push({
              id: doc.id,
              name: d.name || "",
              code: d.code || "",
              teacherId: d.teacherId || "",
              liveSessionId: d.liveSessionId || "",
            });
          }
        }
      }
    }

    let pendingJoinRequests = 0;
    for (const course of joinedCourses) {
      // already member — skip
    }
    // Pending requests: collectionGroup joinRequests where studentId == uid and status pending
    try {
      const joinSnap = await db
        .collectionGroup("joinRequests")
        .where("studentId", "==", uid)
        .get();
      for (const doc of joinSnap.docs) {
        const status = (doc.data() || {}).status || "pending";
        if (status === "pending") pendingJoinRequests++;
      }
    } catch (err) {
      console.warn("student dashboard joinRequests failed:", err.message);
    }

    const activeLiveSessions = joinedCourses.filter(
      (c) => String(c.liveSessionId || "").trim().length > 0
    );

    let pendingMeetings = 0;
    let meetingTotal = 0;
    try {
      const meetingSnap = await db
        .collection("meetingRequests")
        .where("studentId", "==", uid)
        .limit(READ_LIMIT)
        .get();
      meetingTotal = meetingSnap.size;
      for (const doc of meetingSnap.docs) {
        const status = (doc.data() || {}).status || "";
        if (status === "pending" || status === "rescheduleRequested") {
          pendingMeetings++;
        }
      }
    } catch (err) {
      console.warn("student dashboard meetings failed:", err.message);
    }

    let myFeedbackCount = 0;
    try {
      const fbSnap = await db
        .collection("feedback")
        .where("studentId", "==", uid)
        .limit(READ_LIMIT)
        .get();
      myFeedbackCount = fbSnap.size;
    } catch (err) {
      console.warn("student dashboard feedback failed:", err.message);
    }

    let myPracticeAttemptCount = 0;
    try {
      const attemptSnap = await db
        .collectionGroup("practiceAttempts")
        .where("studentId", "==", uid)
        .limit(READ_LIMIT)
        .get();
      myPracticeAttemptCount = attemptSnap.size;
    } catch (err) {
      console.warn("student dashboard practice failed:", err.message);
    }

    return res.json({
      studentId: uid,
      fullName: user.fullName || "",
      connectedTeacherId: user.connectedTeacherId || "",
      connectedTeacherName: user.connectedTeacherName || "",
      connectedTeacherEmail: user.connectedTeacherEmail || "",
      joinedCourseCount: joinedCourses.length,
      pendingJoinRequestCount: pendingJoinRequests,
      activeLiveSessionCount: activeLiveSessions.length,
      pendingMeetingCount: pendingMeetings,
      meetingRequestCount: meetingTotal,
      myFeedbackCount,
      myPracticeAttemptCount,
      joinedCourses,
      activeLiveSessions,
    });
  } catch (err) {
    console.error("students/me/dashboard", err.message);
    return sendError(res, 500, "internal", "Something went wrong.");
  }
});

module.exports = { teachersRouter, studentsRouter };
