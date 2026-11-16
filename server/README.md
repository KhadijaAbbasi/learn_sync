# LEARNsync Express API (local) — auth + courses + enrollment + files + course hub + live sessions + feedback + meetings + ai practice
Flutter App ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ HTTP ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Express.js ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Firebase Admin SDK ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Firebase Auth / Firestore

Service account JSON stays on the server only. Never put Admin credentials in the Flutter app.

## Prerequisites

1. Node.js 18+ (for built-in `fetch`)
2. Firebase project with Auth + Firestore
3. A service account JSON key (Firebase Console ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Project settings ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Service accounts ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Generate new private key)
4. Web API key (Firebase Console ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Project settings ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ General ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Your apps ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Web API Key) for email password verify

## Setup (PowerShell)

**Important:** never run `copy .env.example .env` if `.env` already exists — that wipes `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_API_KEY`. Edit `.env` once and keep it.

```powershell
cd "D:\Flutter Projects\LEARNsync\server"
npm install
.\ensure-env.ps1
# Or one-time create only when missing:
# if (!(Test-Path .env)) { copy .env.example .env }
# Edit .env ONCE (do not copy again):
#   GOOGLE_APPLICATION_CREDENTIALS=D:\path\to\your-serviceAccount.json
#   FIREBASE_API_KEY=<your Web API key>
#   PORT=3000
npm start
```

`ensure-env.ps1` copies from `.env.example` only when `.env` is missing; if `.env` exists it leaves values alone and only appends missing key names from the example.

Server listens on `http://127.0.0.1:3000` (also `0.0.0.0` for emulators).

### Device base URLs

| Client | Base URL |
|--------|----------|
| Flutter web / Windows desktop | `http://127.0.0.1:3000` |
| Android emulator | `http://10.0.2.2:3000` |
| Physical phone | `http://<your-PC-LAN-IP>:3000` |

Override from Flutter:

```powershell
flutter run --dart-define=AUTH_API_BASE_URL=http://10.0.2.2:3000
```

Or set `AUTH_API_BASE_URL` in the project root `.env` (loaded by flutter_dotenv if you wire it).

**Full Flutter restart required** after changing the Express URL or auth wiring (hot reload is not enough).

## Routes

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | `/` or `/health` | no | `{ status: "ok" }` |
| POST | `/api/auth/signup` | no | Email signup: createUser + profile + `customToken` |
| POST | `/api/auth/complete-phone-signup` | Bearer ID token | After client phone OTP; writes profile + optional phone password |
| POST | `/api/auth/login` | no | Email or phone + password ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ `customToken` + `user` |
| POST | `/api/auth/password-reset/email` | no | Body `{ email }` — Identity Toolkit sendOobCode (Firebase email) |
| POST | `/api/auth/phone-password` | Bearer | Body `{ password }` — replaces CF `setPhonePassword` / phoneCredentials |
| GET | `/api/auth/me` or `/api/auth/session` | Bearer | Current profile |
| PATCH | `/api/users/me` | Bearer | Update allowed profile fields (see Users / profile) |
| POST | `/api/auth/logout` | no | `{ ok: true }` (client must still `FirebaseAuth.signOut`) |

### Signup (email)

```json
POST /api/auth/signup
{
  "email": "a@b.com",
  "password": "secret123",
  "fullName": "Ada Lovelace",
  "role": "student",
  "memberId": "12345"
}
```

Response `201`: `{ "customToken": "...", "user": { ... } }`

Phone OTP is **not** moved to Express. Client verifies SMS with Firebase Auth, then:

```json
POST /api/auth/complete-phone-signup
Authorization: Bearer <idToken>
{
  "fullName": "...",
  "role": "student",
  "memberId": "12345",
  "password": "secret123"
}
```

### Login

```json
POST /api/auth/login
{ "email": "a@b.com", "password": "secret123" }
```

or

```json
{ "phone": "+923001234567", "password": "secret123" }
```

Response: `{ "customToken": "...", "user": { ... } }`

Flutter signs in with `FirebaseAuth.instance.signInWithCustomToken(customToken)`.

Email password is verified via Identity Toolkit REST (`FIREBASE_API_KEY`). Phone password uses the same `phoneCredentials` scrypt hash as the Cloud Functions `signInWithPhonePassword`.

### Errors

```json
{ "error": "invalid-credentials", "message": "Incorrect email or password." }
```


## Courses module

Same stack: Flutter Ã¢â€ â€™ Express Ã¢â€ â€™ Firebase Admin Ã¢â€ â€™ Firestore `courses/{id}`.
All course routes require `Authorization: Bearer <Firebase ID token>`.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/courses` | Teacher: own courses. Student: joined (membership) |
| GET | `/api/courses/:courseId` | Detail (teacher or member) |
| POST | `/api/courses` | Create (teacher). Doc id = normalized code. `409 duplicate-code` |
| PATCH | `/api/courses/:courseId` | Update metadata (teacher) |
| DELETE | `/api/courses/:courseId` | Delete course + chapters/topics + liveSessions (teacher) |
| GET | `/api/courses/code-available?code=` | `{ available: true/false, code }` optional `exceptCourseId` |
| GET | `/api/courses/:courseId/chapters` | List chapters |
| POST | `/api/courses/:courseId/chapters` | Create chapter |
| PATCH | `/api/courses/:courseId/chapters/:chapterId` | Update chapter |
| DELETE | `/api/courses/:courseId/chapters/:chapterId` | Delete chapter + its topics |
| PATCH | `/api/courses/:courseId/chapters/reorder` | Reorder chapters (`orderedIds`) |
| GET | `/api/courses/:courseId/chapters/:chapterId/topics` | List topics |
| POST | `/api/courses/:courseId/chapters/:chapterId/topics` | Create topic (+ topicCount) |
| PATCH | `/api/courses/:courseId/chapters/:chapterId/topics/:topicId` | Update topic |
| DELETE | `/api/courses/:courseId/chapters/:chapterId/topics/:topicId` | Delete topic (Ã¢Ë†â€™ topicCount) |
| PATCH | `/api/courses/:courseId/chapters/:chapterId/topics/reorder` | Reorder topics (`orderedIds`) |

### Create course body (example)

```json
POST /api/courses
Authorization: Bearer <idToken>
{
  "name": "Algorithms",
  "code": "CS301",
  "department": "CS",
  "creditHours": 3,
  "lectureHall": "A1",
  "lectureDays": [1, 3],
  "lectureTime": "10:00",
  "lectureSlots": [{ "day": 1, "from": "10:00", "to": "" }],
  "semester": "Fall 2026",
  "section": "A",
  "outlines": "..."
}
```

Response `201`: `{ "course": { "id": "CS301", ... } }`

Flutter uses `CoursesApiClient` (`lib/services/courses_api_client.dart`) with the same `AUTH_API_BASE_URL` as auth. CourseStore one-shot CRUD (create / update / delete / code-check / chapter+topic mutations + reorder) goes through Express. Realtime listeners (`watchTeacher`, `watchChapters`, `watchTopics`, live sessions, etc.) still use Firestore directly.


## Enrollment / members module

Same stack: Flutter Ã¢â€ â€™ Express Ã¢â€ â€™ Firebase Admin Ã¢â€ â€™ Firestore
`courses/{courseId}/joinRequests/{studentId}` and `courses/{courseId}/members/{studentId}`.

All routes require `Authorization: Bearer <Firebase ID token>`. Matches Flutter `CourseEnrollmentService` behavior (decline deletes the request so the student can re-request).

| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/courses/:courseId/join-requests` | Student requests join (body: studentName, courseName, courseCode, studentEmail, memberId). `409 already-enrolled` |
| GET | `/api/courses/:courseId/join-requests` | Pending requests for course (teacher) |
| GET | `/api/join-requests/mine-as-teacher` | Pending across all teacher courses |
| GET | `/api/teachers/:teacherId/join-requests` | Same as mine-as-teacher; `:teacherId` must equal auth uid |
| POST | `/api/courses/:courseId/join-requests/:studentId/accept` | Accept Ã¢â€ â€™ member doc + request accepted |
| POST | `/api/courses/:courseId/join-requests/:studentId/decline` | Decline Ã¢â€ â€™ deletes request doc |
| GET | `/api/courses/:courseId/members` | Enrolled members (teacher) |
| DELETE | `/api/courses/:courseId/members/:studentId` | Remove member (+ best-effort clear join request) |
| GET | `/api/students/me/joined-courses` | Courses the signed-in student has joined |

Flutter: `EnrollmentApiClient` (`lib/services/enrollment_api_client.dart`). Mutations go through Express via `CourseEnrollmentService`; realtime watches (`watchPendingForCourse`, `watchMembers`, `watchIsMember`, etc.) still use Firestore.

## Course files / slides module

Same stack: Flutter â†’ Express â†’ Firebase Admin â†’ Firestore
`courses/{courseId}/files/{fileId}` + `chunks/{index}` (Blob bytes).
**No Firebase Storage** â€” matches the Flutter app chunked schema so existing viewers keep working.

URLs stay `firestore://courses/{courseId}/files/{fileId}`.

All routes require `Authorization: Bearer <Firebase ID token>`.
JSON body limit is 30mb for base64 uploads (max file 20mb, chunk size 700kb, max 40 chunks).

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/courses/:courseId/files` | List files (optional `?folder=`). Teacher or member |
| POST | `/api/courses/:courseId/files` | Upload (teacher). Body: `name`, `folder`, `dataBase64`, optional `contentType` |
| GET | `/api/courses/:courseId/files/:fileId` | Download / reassemble. `{ file, dataBase64 }` |
| DELETE | `/api/courses/:courseId/files/:fileId` | Delete file + chunks (teacher) |

### Upload body (example)

```json
POST /api/courses/CS301/files
Authorization: Bearer <idToken>
{
  "name": "week1.pptx",
  "folder": "topics/<chapterId>/<topicId>",
  "contentType": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "dataBase64": "<base64 bytes>"
}
```

Response `201`: `{ "file": { "id", "name", "folder", "contentType", "size", "chunkCount", "url", "createdAt" } }`

Flutter: `FilesApiClient` (`lib/services/files_api_client.dart`).
`CourseFileUpload` / `loadCourseFileBytes` / download / open use Express for firestore:// files.
Realtime course watches still use Firestore.



## Course hub module (arrays on course document)

Same stack: Flutter -> Express -> Firebase Admin -> Firestore `courses/{courseId}` array fields.
Matches `CourseStore` helpers (`_addContent` / `_replaceContent`): announcements, syllabus, lectures, assignments, resources, syllabusFiles.
**No student assignment submission APIs.** Live lectures / AI / auth / enrollment / files unchanged (syllabus file bytes still use the files upload API; this module only attaches `{name,url}` metadata).

All routes require `Authorization: Bearer <Firebase ID token>`.
GET: teacher or member. Mutations: course teacher only.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/courses/:courseId/announcements` | List (newest `createdAt` first) |
| POST | `/api/courses/:courseId/announcements` | Add (`arrayUnion` on `announcements`) |
| GET | `/api/courses/:courseId/syllabus` | Weeks + `syllabusFiles` |
| POST | `/api/courses/:courseId/syllabus` | Add week (`syllabus`) |
| PATCH | `/api/courses/:courseId/syllabus/:itemId` | Replace week by id |
| POST | `/api/courses/:courseId/syllabus/files` | Attach file metadata (`syllabusFiles`). Body: `{ "files": [{ "name", "url" }] }` |
| GET | `/api/courses/:courseId/schedule-lectures` | Course-hub schedule rows (`lectures` array, not live sessions) |
| POST | `/api/courses/:courseId/schedule-lectures` | Add schedule lecture |
| PATCH | `/api/courses/:courseId/schedule-lectures/:itemId` | Update schedule lecture |
| GET | `/api/courses/:courseId/assignments` | Assignment metadata only |
| POST | `/api/courses/:courseId/assignments` | Add assignment metadata |
| PATCH | `/api/courses/:courseId/assignments/:itemId` | Update assignment metadata |
| GET | `/api/courses/:courseId/resources` | List resources |
| POST | `/api/courses/:courseId/resources` | Add resource |
| PATCH | `/api/courses/:courseId/resources/:itemId` | Update resource |

Flutter: `CoursesApiClient` hub methods. `CourseStore` mutations go through Express; watches (`watchAnnouncements`, `watchSyllabus`, `watchLectures`, `watchAssignments`, `watchResources`) still use Firestore.



## Live sessions / lectures module

Same stack: Flutter -> Express -> Firebase Admin -> Firestore
`courses/{courseId}/liveSessions/{sessionId}` and top-level `lectures/{lectureId}`
(+ `attendees`, `teacherNotes`).

One-shot mutations go through Express. **Realtime stays on Firestore** (do not poll):
active session watches, slide position streams, `slideSignals` watches, presence
streams / heartbeats UI, and live join-request queue watches.

All routes require `Authorization: Bearer <Firebase ID token>`.

| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/courses/:courseId/live-sessions` | Start session + lecture docs (teacher). Body: chapter/topic, durationMinutes, courseName, teacherName, optional taughtNotes / id. `409 teacher-already-live` / `course-already-live` |
| POST | `/api/courses/:courseId/live-sessions/:sessionId/end` | End session; clears course/teacher live flags; best-effort summary save |
| PATCH | `/api/courses/:courseId/live-sessions/:sessionId/slide` | Teacher slide position (`fileIndex`, `page`) |
| PATCH | `/api/courses/:courseId/live-sessions/:sessionId/topic` | Retarget topic on existing session + lecture (no new ids) |
| PUT | `/api/courses/:courseId/live-sessions/:sessionId/slide-signals` | Student upsert understanding signal. Body: studentName, level (`100`/`80`/`60`/`below50`), fileIndex, page |
| GET | `/api/courses/:courseId/live-sessions/:sessionId/slide-signals` | One-shot list (teacher: all; student: own) |
| GET | `/api/courses/:courseId/live-sessions/:sessionId/slide-signals/me` | Own signals, or one signal with `?fileIndex=&page=` |
| POST | `/api/courses/:courseId/live-sessions/:sessionId/join-requests` | Student live join request |
| POST | `/api/courses/:courseId/live-sessions/:sessionId/join-requests/accept-all` | Teacher accept all pending |
| POST | `/api/courses/:courseId/live-sessions/:sessionId/join-requests/:studentId/accept` | Teacher accept one (also marks attendance) |
| GET | `/api/lectures` | List teacher lectures (`?courseId=&teacherId=&limit=`). teacherId must be auth uid |
| GET | `/api/lectures/:lectureId` | Lecture detail (teacher or course member) |
| PATCH | `/api/lectures/:lectureId/summary` | Save summary after end (teacher). Body: summary fields / `{ summary: {...} }` |
| GET | `/api/lectures/:lectureId/taught-notes` | `{ text }` for AI practice / display |
| PUT | `/api/lectures/:lectureId/taught-notes` | Save notes (teacher). Body: `{ text }` |
| POST | `/api/lectures/:lectureId/attendees` | Mark attendance once (student self only) |
| GET | `/api/lectures/:lectureId/attendees` | One-shot attendee list |
| PATCH | `/api/lectures/:lectureId/attendees/:studentId/presence` | Presence heartbeat write (`inApp`). Student self only; best-effort |
| POST | `/api/lectures/attendees/batch` | Batch attendees. Body: `{ lectureIds: [] }` (cap 20). `{ attendeesByLecture }` |

No live-join **decline** route â€” `CourseStore` has no decline for lecture join requests (course enrollment decline is separate).

Flutter: `LiveSessionsApiClient` (`lib/services/live_sessions_api_client.dart`).
`CourseStore` start/end/slide/topic/summary/taught-notes/attendance/presence/slide-signals/
live join request+accept(+all)/listLectures/loadAttendeesForLectures use Express.
Realtime watches (`watchLiveSlideSignals`, `watchJoinRequests`, `watchLectureAttendees`, etc.) stay on Firestore.
Lockdown (LiveSessionLockdown) stays on client; AI practice attempt saves go through Express (see AI practice module).



## Feedback module

Same stack: Flutter -> Express -> Firebase Admin -> Firestore `feedback/{lectureId_studentId}`.
Matches `CourseStore.submitLectureFeedback` / feedback watches paths.

All routes require `Authorization: Bearer <Firebase ID token>`.
Mutations go through Express. **Realtime watches stay on Firestore.**

| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/feedback` | Student submit/update. Body: lectureId/sessionId, courseId, courseName, teacherId, teacherName, studentName, level (`100`/`80`/`60`/`below50`), optional comment + chapter/topic fields. `409 lecture-not-ended` |
| GET | `/api/feedback/lectures/:lectureId/me` | Own feedback for lecture (`{ feedback }` or null) |
| GET | `/api/feedback/lectures/:lectureId` | All feedback for lecture (teacher). Optional `?teacherId=` |
| GET | `/api/feedback/teachers/:teacherId` | Teacher feedback list (uid must match). Limit 400 |

Flutter: `FeedbackApiClient` (`lib/services/feedback_api_client.dart`).
`CourseStore.submitLectureFeedback` uses Express; `watchMyLectureFeedback` / `watchLectureFeedback` / `watchTeacherFeedback` stay on Firestore.


## Meetings module

Same stack: Flutter -> Express -> Firebase Admin -> Firestore `meetingRequests/{requestId}`.
Matches `MeetingStore` create / accept / decline / reschedule / complete.

All routes require `Authorization: Bearer <Firebase ID token>`.
Mutations go through Express. **Realtime watches stay on Firestore.**

| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/meeting-requests` | Student create. Body: studentName, teacherId, teacherName, courseId, courseName, topicTitle, reason, optional email/member/chapter/topic/lectureId |
| GET | `/api/meeting-requests/mine` | Student list |
| GET | `/api/meeting-requests/mine-as-teacher` | Teacher list |
| GET | `/api/meeting-requests/pending-count` | Teacher `{ count }` (pending + rescheduleRequested) |
| GET | `/api/meeting-requests/:requestId` | One request (student or teacher) |
| POST | `/api/meeting-requests/:requestId/accept` | Teacher accept. Body: `scheduledAt` (ISO), optional `teacherNote` |
| POST | `/api/meeting-requests/:requestId/decline` | Teacher decline. Optional `teacherNote` |
| POST | `/api/meeting-requests/:requestId/reschedule` | Student reschedule. Optional `note` |
| POST | `/api/meeting-requests/:requestId/complete` | Teacher complete (after scheduled time) |

Flutter: `MeetingsApiClient` (`lib/services/meetings_api_client.dart`).
`MeetingStore` mutations use Express; watches (`watchStudentRequests`, `watchTeacherRequests`, `watchRequest`, `watchPendingCountForTeacher`) stay on Firestore.

## AI practice module

Same stack: Flutter -> Express -> Firebase Admin -> Firestore
`lectures/{lectureId}/practiceAttempts/{attemptId}`.
Generate proxies Cloud Function `generateAiPracticeQuiz` (or local Gemini when
`AI_PRACTICE_MODE=local` + `GEMINI_API_KEY` / `API_KEY`).

All routes require `Authorization: Bearer <Firebase ID token>`.
Mutations / one-shot reads go through Express. **Realtime watches stay on Firestore.**

| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/ai-practice/generate` | Body: taughtNotes, topicTitle, optional chapterTitle/courseName/sourceKind/weakSlides. Returns `{ quiz: [...] }` (same shape as CF) |
| POST | `/api/lectures/:lectureId/practice-attempts` | Student save attempt after lecture ended. `409 lecture-not-ended` |
| GET | `/api/lectures/:lectureId/practice-attempts` | Teacher: all attempts for lecture |
| GET | `/api/lectures/:lectureId/practice-attempts/me` | Student: own attempts for lecture |
| GET | `/api/ai-practice/teachers/:teacherId/attempts` | Teacher list (uid must match). Limit 400 |

### Generate body (example)

```json
POST /api/ai-practice/generate
Authorization: Bearer <idToken>
{
  "taughtNotes": "...",
  "topicTitle": "Sorting",
  "chapterTitle": "Algorithms",
  "courseName": "CS101",
  "sourceKind": "documents",
  "weakSlides": [
    { "fileIndex": 0, "slidePage": 3, "fileName": "lec.pptx", "levelLabel": "Below 50%", "priority": 3 }
  ]
}
```

Response: `{ "quiz": [ { "question", "options"[3], "correctAnswer": "A"|"B"|"C", ... } ] }`

Flutter: `AiPracticeApiClient` + `ExpressAiPracticeGenerator` (`lib/services/`).
`CourseStore.savePracticeAttempt` / `fetchMyPracticeAttemptsOnce` use Express.
Watches (`watchLecturePracticeAttempts`, `watchMyPracticeAttempts`, `watchTeacherPracticeAttempts`) stay on Firestore.


## Users / profile module

Same stack: Flutter -> Express -> Firebase Admin -> Auth + Firestore
(`users/{uid}`, `users/{uid}/avatar/current`, `memberIds/{id}`, owned `courses`).

All routes below require `Authorization: Bearer <Firebase ID token>` except as noted.
Matches `FirebaseAuthService` avatar / link-teacher / unlink / delete-account / memberId claim.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/users/me` | Current profile |
| PATCH | `/api/users/me` | Update allowed fields (fullName, bio, gender, photoUrl, phone, office*, country, department, university, enrollmentYear, phoneCountry) |
| GET | `/api/users/:userId` | Public profile by id |
| POST | `/api/users/me/avatar` | Body: `dataBase64`, `fileName` (jpg/png, max 800KB). Stores Firestore blob; returns `photoUrl` = `firestore://users/{uid}/avatar/current` |
| GET | `/api/users/me/avatar` | Own avatar bytes (`dataBase64`) |
| GET | `/api/users/:userId/avatar` | Avatar bytes for any user |
| POST | `/api/users/me/link-teacher` | Body: `{ "query" }` — email, memberId, or name. `404 teacher-not-found` |
| DELETE | `/api/users/me/link-teacher` | Clears connectedTeacher* fields |
| DELETE | `/api/users/me` | Deletes owned courses/files, memberIds, avatar, user doc, phoneCredentials, Auth user |
| GET | `/api/member-ids/:id/available` | no auth | `{ memberId, available }` soft check |
| POST | `/api/member-ids/claim` | Body: `{ "memberId" }` digits. Claims/replaces memberId for current user. `409 id-in-use` |

Flutter: `AuthApiClient` (`lib/services/auth_api_client.dart`).
`FirebaseAuthService` profile mutations and avatar load/save go through Express.



## Dashboard analytics module

Same stack: Flutter -> Express -> Firebase Admin -> Firestore
(`lectures`, `feedback`, `meetingRequests`, `practiceAttempts`, `attendees`, `courses`).

Aggregation matches Flutter `aggregateTeacherAnalytics` / lecture analytics screen
(understanding buckets, practice participation, meeting status counts, per-lecture
audience + rates). Optional query filters on teacher routes:
`courseId`, `chapterId`, `topicId`, `dateRange` (`all`|`last7`|`last30`|`custom`),
`customStart`, `customEnd` (ISO).

All routes require `Authorization: Bearer <Firebase ID token>`.
Teacher routes: `teacherId` must equal auth uid.
One-shot JSON summaries. **Realtime watches stay on Firestore** for live analytics UI.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/teachers/:teacherId/analytics/understanding` | Counts, average, byTopic/bySession bars, lowUnderstanding, studentRows, filter options |
| GET | `/api/teachers/:teacherId/analytics/practice` | Practice overview (participants/completions/rates), incompletePractice, studentRows |
| GET | `/api/teachers/:teacherId/analytics/meetings` | Meeting status counts + pendingMeetings drill-down |
| GET | `/api/teachers/:teacherId/analytics/lectures/:lectureId` | Per-lecture summary (understanding, practice, meetings, attendees, feedback, attempts) |
| GET | `/api/students/me/dashboard` | Student home summary (joined courses, live, meetings, feedback/practice counts) |

Flutter: `AnalyticsApiClient` (`lib/services/analytics_api_client.dart`).
`CourseStore.fetchTeacher*Analytics` / `fetchLectureAnalytics` / `fetchStudentDashboard`.
`LectureAnalyticsScreen` prefers Express summary for metric cards; streams stay for lists.
`StudentDashboard` loads Express summary strip. Combined teacher analytics screen keeps Firestore streams.

## Password reset / phone password / session

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/api/auth/password-reset/email` | no | Body: `{ "email" }`. Triggers Firebase password-reset email via Identity Toolkit `accounts:sendOobCode` (needs `FIREBASE_API_KEY`). `404 account-not-found` if email missing. |
| POST | `/api/auth/phone-password` | Bearer | Body: `{ "password" }` (min 8). Same logic as Cloud Function `setPhonePassword`: writes `phoneCredentials/{uid}` scrypt hash + optional Auth `updateUser({ password })`. Phone accounts only. |
| GET | `/api/auth/me` | Bearer | Used by Flutter `restoreSession` / email-verified check (falls back to Firestore if profile missing or server unreachable). |
| GET | `/api/member-ids/:id/available` | no | Soft availability check before claim/signup. |

**Still on Firebase client (not moved):** phone OTP (signup + password-reset SMS), email verification send/check link, realtime watches, lockdown.

Flutter: `AuthApiClient.sendPasswordResetEmail` / `setPhonePassword` / `fetchMe`. `FirebaseAuthService` no longer calls Cloud Function `setPhonePassword` or `FirebaseAuth.sendPasswordResetEmail`.

## Security

- Never overwrite an existing `.env` with `copy .env.example .env` — that deletes your keys. Use `.\ensure-env.ps1` instead.
- Never commit `.env` or `*serviceAccount*.json`
- Never ship Admin credentials inside the Flutter app
- CORS allows localhost / 127.0.0.1 and sets `Access-Control-Allow-Private-Network` for Chrome PNA





