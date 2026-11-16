# LEARNsync Remaining Implementation Plan

This plan completes the main flow described in the app proposal and interface map.
Implement phases in order because later features depend on earlier data models.

## Already completed

- Teacher/student authentication, email verification, and role-based dashboards
- Unique teacher/student ID linked to one email
- Student-to-teacher linking and teacher course listing
- Course create, view, edit, delete, and syllabus upload
- Profile and settings pages
- English/Arabic and light/dark themes
- Firebase Auth, Firestore, and Storage foundation

## Phase 0 — Stabilize the current foundation

- [ ] Review and deploy current Firestore and Storage rules
- [ ] Confirm unique member ID signup on real Firebase
- [ ] Test course and syllabus permissions for teacher and student accounts
- [ ] Remove or reconcile unused OTP and old course-hub code
- [ ] Add loading, empty, offline, and Firebase error states

**Done when:** signup, profile, teacher linking, courses, and syllabus work on
Android and Web without permission errors.

## Phase 1 — Chapters and topics

- [x] Add `ChapterModel` and `TopicModel`
- [x] Store chapters under `courses/{courseId}/chapters`
- [x] Store topics under each chapter
- [x] Build teacher chapter/topic management screens
- [x] Add create, edit, reorder, and delete actions
- [x] Build read-only chapter/topic view for students
- [x] Update Firestore rules so only the course teacher can manage content

**Done when:** a teacher can open a course, create chapters and topics, and the
linked students can see them.

**Status:** Implemented locally. Deploy the updated Firestore rules before
testing this phase against the live Firebase project.

## Phase 2 — Live timed lecture

- [x] Add a `LiveSessionModel`
- [x] Store sessions under `courses/{courseId}/liveSessions`
- [x] Let the teacher choose a chapter and topic
- [x] Add lecture duration/timer selection
- [x] Build Start Lecture, End Lecture, and active-session screens
- [x] Use Firestore server timestamps for reliable timing
- [x] Allow only one active session per course
- [x] Listen to the active session in real time on the student dashboard

**Done when:** starting a topic on the teacher device immediately opens the same
topic and synchronized timer for linked students.

**Status:** Implemented locally. Deploy the updated Firestore rules before
testing live lectures against the Firebase project.

## Phase 3 — Student understanding feedback

- [x] Show 100%, 80%, 60%, and Below 50% options
- [x] Save one response per student per live session
- [x] Collect feedback after the lecture ends (attendees only)
- [x] Keep responses private from other students
- [x] Show teacher response counts after class ends
- [x] Prompt students for their next action after submitting

Collection:
`feedback/{lectureId_studentUid}` linked to lecture, course, teacher, and student.

**Done when:** every student can submit one private response and the teacher sees
real-time totals.

**Status:** Implemented locally. Deploy the updated Firestore rules before
testing feedback against the Firebase project.

## Phase 4 — Meeting requests

- [x] Add a `MeetingRequestModel`
- [x] Build student request form with topic and reason
- [x] Save request date, status, student, teacher, course, and topic
- [x] Build teacher request list and request detail screen
- [x] Add Pending, Accepted, Completed, and Declined statuses
- [x] Let the teacher add a meeting date/time
- [x] Notify the student when status changes
- [x] Restrict requests to the linked teacher and owning student

**Done when:** a student can request support and both users can track its status.

**Status:** Implemented. Student and teacher meeting screens are separate.
In-app status updates appear when either side opens their meetings list.
Push notifications remain for Phase 7.

## Phase 5 — AI practice

- [ ] Provision Firebase AI Logic with the Gemini Developer API
- [ ] Add Firebase App Check before enabling AI requests
- [ ] Generate structured topic-specific multiple-choice questions
- [ ] Build practice question, answer, result, and review screens
- [ ] Save attempts, scores, completion status, and timestamps
- [ ] Prevent answers from being included in the initial student payload
- [ ] Add retry, quota, safety, and malformed-response handling
- [ ] Keep the model name configurable through Remote Config

Suggested model: `gemini-flash-latest`.

**Done when:** a student can generate and complete safe topic-specific practice,
and the completion result is stored for analytics.

## Phase 6 — Teacher analytics

- [ ] Build overview cards for understanding, AI practice, and meetings
- [ ] Add understanding percentage/bar chart by topic and session
- [ ] Add AI participation, completion, and average-score analytics
- [ ] Add meeting request count and status analytics
- [ ] Add drill-down lists showing relevant student names
- [ ] Add course, chapter, topic, and date filters
- [ ] Use Firestore aggregation queries or maintained summary documents
- [ ] Avoid unrestricted reads of every student response

**Done when:** the teacher can identify difficult topics and students needing
support from clear, filterable data.

## Phase 7 — Notifications, quality, and release

- [ ] Add in-app notifications for live topics and meeting updates
- [ ] Add Firebase Cloud Messaging if push notifications are required
- [ ] Add unit tests for models, stores, permissions, and analytics calculations
- [ ] Add widget tests for all teacher and student journeys
- [ ] Test Arabic RTL, dark mode, small phones, tablets, and Web
- [ ] Add accessibility labels and adequate touch targets
- [ ] Add App Check for Firebase services
- [ ] Review privacy rules for student responses and AI data
- [ ] Deploy rules, indexes, and required Firebase services
- [ ] Run a complete teacher/student acceptance test

## Recommended implementation order

1. Foundation validation
2. Chapters and topics
3. Live lecture and timer
4. Understanding feedback
5. Meeting requests
6. AI practice
7. Analytics
8. Notifications and final testing

## First implementation task

Start with **Phase 5: AI practice**, using course topics from earlier phases.
