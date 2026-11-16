// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LEARNsync';

  @override
  String get appTagline => 'Real time student feedback';

  @override
  String get welcomeBack => 'Welcome Back!';

  @override
  String get loginSubtitle => 'Login to continue to your account.';

  @override
  String get emailOrUsername => 'Email or Username';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter the email for your account. We will send a link to reset your password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get resetEmailSentTitle => 'Check your email';

  @override
  String resetEmailSentBody(String email) {
    return 'We sent a password reset link to $email.';
  }

  @override
  String get resetEmailSentHint =>
      'Open the email, set a new password, then come back here to log in.';

  @override
  String get accountNotFound => 'No account found for this email.';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get otpTitle => 'Verify your email';

  @override
  String otpSubtitle(String email) {
    return 'Enter the 6-digit code we sent to $email.';
  }

  @override
  String get otpHint => '6-digit code';

  @override
  String get otpInvalidLength => 'Enter the 6-digit verification code.';

  @override
  String get verifyOtp => 'Verify code';

  @override
  String get otpSending => 'Sending...';

  @override
  String get resendOtp => 'Resend code';

  @override
  String otpEmailSent(String email) {
    return 'We sent a verification email to $email. Check your inbox and spam folder.';
  }

  @override
  String get otpResent => 'A new verification code was sent to your email.';

  @override
  String get userAlreadyExistsTitle => 'Account already exists';

  @override
  String get userAlreadyExistsBody =>
      'This email is already registered. Log in, or use Forgot Password if you need to reset it.';

  @override
  String get verifyEmailTitle => 'Check your email';

  @override
  String verifyEmailBody(String email) {
    return 'Open the verification email we sent to $email. After you tap the link, this screen will open the login page.';
  }

  @override
  String get waitingForEmailVerification =>
      'Waiting for you to tap the link in your email…';

  @override
  String get emailVerifiedPleaseLogin => 'Email verified. Please log in.';

  @override
  String get emailNotVerified =>
      'Open the verification email and tap the link first, then try again.';

  @override
  String get createAccount => 'Create Your Account';

  @override
  String get signUpSubtitle => 'Sign up to get started.';

  @override
  String get fullName => 'Full Name';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get iAmA => 'I am a...';

  @override
  String get teacher => 'Teacher';

  @override
  String get student => 'Student';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get iAgreePrefix => 'I agree to the ';

  @override
  String get andConjunction => ' and ';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get requiredField => 'This field is required';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get passwordRequirements =>
      'Use at least 8 characters, with uppercase, lowercase, a number, and a special character.';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get selectRole => 'Please select your role';

  @override
  String get acceptTerms => 'Please accept the Terms of Use and Privacy Policy';

  @override
  String get loginSuccess =>
      'Signed in. Backend will be connected in a later step.';

  @override
  String get signupSuccess => 'Account created. You can now log in.';

  @override
  String get termsPlaceholderBody =>
      'The full Terms of Use will be added here before release.';

  @override
  String get privacyPlaceholderBody =>
      'The full Privacy Policy will be added here before release.';

  @override
  String get ok => 'OK';

  @override
  String helloUser(String name) {
    return 'Hello, $name';
  }

  @override
  String get teacherDashboard => 'Teacher Dashboard';

  @override
  String get studentDashboard => 'Student Dashboard';

  @override
  String get yourCourses => 'Your Courses';

  @override
  String get addCourse => 'Add Course';

  @override
  String get newCourse => 'New course';

  @override
  String get courseName => 'Course name';

  @override
  String get deleteCourse => 'Delete course';

  @override
  String get noCoursesTeacher =>
      'No courses yet. Add a course to start teaching.';

  @override
  String get noCoursesStudent =>
      'Connect your teacher to see available courses.';

  @override
  String get liveLecture => 'Live Lecture';

  @override
  String get noLiveLecture => 'No lecture is live right now.';

  @override
  String get connectTeacher => 'Connect with your teacher';

  @override
  String get connectTeacherHint =>
      'Enter your teacher\'s email to access their courses.';

  @override
  String get teacherEmail => 'Teacher email';

  @override
  String get connect => 'Connect';

  @override
  String connectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get statsCourses => 'Courses';

  @override
  String get statsLive => 'Live';

  @override
  String get statsMeetings => 'Meetings';

  @override
  String topicsCount(int count) {
    return '$count topics';
  }

  @override
  String get startTopicSoon => 'Topic start flow will be added next.';

  @override
  String get aiPracticeSoon => 'AI Practice will open from here next.';

  @override
  String get meetingSoon => 'Meeting requests will open from here next.';

  @override
  String get invalidCredentials => 'Incorrect email or password.';

  @override
  String get demoHint =>
      'Demo: teacher@learnsync.app or student@learnsync.app  •  Demo@123';

  @override
  String get emailInUse => 'An account already exists for this email.';

  @override
  String get memberId => 'ID';

  @override
  String get teacherMemberId => 'Teacher ID';

  @override
  String get studentMemberId => 'Student ID';

  @override
  String get memberIdInvalid =>
      'Use 3–32 letters, numbers, hyphen, or underscore.';

  @override
  String get memberIdTaken => 'This ID is already linked to another email.';

  @override
  String get networkError => 'Check your internet connection and try again.';

  @override
  String get tooManyRequests => 'Too many attempts. Try again later.';

  @override
  String get authUnknown => 'Something went wrong. Please try again.';

  @override
  String get teacherNotFound => 'No teacher found with that name or email.';

  @override
  String get teacherHasNoCourses =>
      'Your teacher has not added any courses yet.';

  @override
  String get courseSaveFailed => 'Could not save the course. Try again.';

  @override
  String get courseDeleteFailed => 'Could not delete the course. Try again.';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get aiPractice => 'AI Practice';

  @override
  String get meetTeacher => 'Meet Teacher';

  @override
  String welcomeBackName(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get stayUpdated => 'Stay updated and keep learning!';

  @override
  String get currentLiveTopic => 'Current live topic';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get chapterLabel => 'Chapter 2: Polynomials';

  @override
  String get liveTopicTitle => 'Quadratic Equations';

  @override
  String startedAt(String time) {
    return 'Started at $time';
  }

  @override
  String get howWellUnderstood => 'How well did you understand this topic?';

  @override
  String get understand100 => '100%';

  @override
  String get understand80 => '80%';

  @override
  String get understand60 => '60%';

  @override
  String get understandBelow50 => 'Below 50%';

  @override
  String get understand100Hint => 'Fully clear';

  @override
  String get understand80Hint => 'Mostly clear';

  @override
  String get understand60Hint => 'Need a recap';

  @override
  String get understandBelow50Hint => 'Need help';

  @override
  String get whatNext => 'What would you like to do next?';

  @override
  String get aiPracticeHint =>
      'Get topic-specific questions generated for you.';

  @override
  String get startPractice => 'Start Practice';

  @override
  String get alreadyPracticed => 'Already practiced';

  @override
  String get practiceMore => 'Practice more';

  @override
  String get pastPracticeTitle => 'Past practice';

  @override
  String get pastPracticeEmpty =>
      'No saved practice questions for this lecture yet.';

  @override
  String pastPracticeAttemptLabel(int n, int score, int total, int percent) {
    return 'Attempt $n · $score/$total ($percent%)';
  }

  @override
  String get requestMeetingHint =>
      'Ask for extra support without speaking in class.';

  @override
  String get requestMeeting => 'Request Meeting';

  @override
  String get yourProgress => 'Your Progress';

  @override
  String get viewAll => 'View All';

  @override
  String get topicsCompleted => 'Topics Completed';

  @override
  String get aiPracticesCompleted => 'AI Practices Completed';

  @override
  String get meetingsRequested => 'Meetings Requested';

  @override
  String get thisMonth => 'This month';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navLiveTopics => 'Live Topics';

  @override
  String get navPractice => 'Practice';

  @override
  String get navMeetings => 'Meetings';

  @override
  String get myMeetingRequests => 'My meeting requests';

  @override
  String get meetingRequests => 'Meeting requests';

  @override
  String get meetingDetails => 'Meeting details';

  @override
  String get createMeetingIntro =>
      'Tell your teacher what you need help with. Keep it short and clear.';

  @override
  String get selectCourse => 'Select course';

  @override
  String get meetingTopicLabel => 'Topic';

  @override
  String get meetingTopicHint => 'What topic do you need help with?';

  @override
  String get meetingReasonLabel => 'Reason';

  @override
  String get meetingReasonHint =>
      'Share what feels unclear or what you want to discuss.';

  @override
  String get sendMeetingRequest => 'Send request';

  @override
  String get meetingRequestSent => 'Your meeting request was sent.';

  @override
  String get meetingRequestFailed =>
      'Could not send the meeting request. Try again.';

  @override
  String get meetingFormIncomplete => 'Add a topic and reason before sending.';

  @override
  String get linkTeacherFirstForMeeting =>
      'Connect to your teacher before requesting a meeting.';

  @override
  String get noMeetingRequestsYet => 'No meeting requests yet';

  @override
  String get noMeetingRequestsStudentHint =>
      'When something feels unclear, send a quiet request to your teacher.';

  @override
  String get noMeetingRequestsTeacherHint =>
      'When a student asks for support, their request will appear here.';

  @override
  String get meetingStatusPending => 'Pending';

  @override
  String get meetingStatusAccepted => 'Accepted';

  @override
  String get meetingStatusDeclined => 'Declined';

  @override
  String get meetingStatusCompleted => 'Completed';

  @override
  String get meetingStatusReschedule => 'Reschedule';

  @override
  String get meetingScheduledFor => 'Scheduled for';

  @override
  String get teacherNote => 'Teacher note';

  @override
  String get teacherNoteOptional => 'Note for student (optional)';

  @override
  String get meetingPendingHint =>
      'Your teacher has received this request and will respond soon.';

  @override
  String get meetingAcceptedHint =>
      'Your teacher accepted this meeting. Check the scheduled time above.';

  @override
  String get meetingDeclinedHint =>
      'Your teacher could not take this meeting. You can send a new request anytime.';

  @override
  String get meetingCompletedHint =>
      'This meeting is marked complete. Great job following up.';

  @override
  String get meetingRescheduleHint =>
      'You asked to reschedule. Your teacher will pick a new time.';

  @override
  String get meetingNotFound => 'This meeting request could not be found.';

  @override
  String get pendingMeetings => 'Needs a reply';

  @override
  String get allMeetings => 'All requests';

  @override
  String get scheduleMeetingPrompt => 'Pick a time, then accept or decline.';

  @override
  String get chooseMeetingDateTime => 'Choose date & time';

  @override
  String get chooseNewMeetingDateTime => 'Choose a new date & time';

  @override
  String get chooseMeetingTimeFirst => 'Choose a meeting date and time first.';

  @override
  String get acceptMeeting => 'Accept meeting';

  @override
  String get declineMeeting => 'Decline';

  @override
  String get setNewMeetingTime => 'Set new meeting time';

  @override
  String get studentAskedReschedule =>
      'Student asked to reschedule. Pick a new time.';

  @override
  String get requestReschedule => 'Request reschedule';

  @override
  String get requestRescheduleHint =>
      'Need a different time? Ask your teacher to reschedule.';

  @override
  String get rescheduleNoteOptional => 'Why do you need a new time? (optional)';

  @override
  String get rescheduleNoteLabel => 'Reschedule note';

  @override
  String get rescheduleRequestedToast =>
      'Reschedule request sent to your teacher.';

  @override
  String get meetingRescheduledToast => 'New meeting time saved.';

  @override
  String get markMeetingCompleted => 'Mark as completed';

  @override
  String get meetingCompleteAfterSchedule =>
      'You can mark complete only after the scheduled time.';

  @override
  String meetingCompleteAfterScheduleHint(String time) {
    return 'Complete unlocks after $time.';
  }

  @override
  String pendingMeetingRequests(int count) {
    return '$count pending meeting requests';
  }

  @override
  String get meetingAcceptedToast => 'Meeting accepted.';

  @override
  String get meetingDeclinedToast => 'Meeting declined.';

  @override
  String get meetingCompletedToast => 'Meeting marked complete.';

  @override
  String get meetingUpdateFailed => 'Could not update the meeting. Try again.';

  @override
  String get openMeetings => 'Open meetings';

  @override
  String meetingsPendingCount(int count) {
    return '$count waiting';
  }

  @override
  String get courseLabel => 'Course';

  @override
  String get emailLabel => 'Email';

  @override
  String get navSettings => 'Settings';

  @override
  String get notifications => 'Notifications';

  @override
  String get settingsSoon => 'Settings will be added next.';

  @override
  String get changeTeacher => 'Change';

  @override
  String get timerLabel => 'Timer';

  @override
  String get teacherHomeHint =>
      'Add courses, then start the topic you are teaching.';

  @override
  String get studentHomeHint =>
      'Join using your teacher\'s email. There is no teacher search — that email unlocks their courses.';

  @override
  String get addCourseTitle => 'Add Course';

  @override
  String get addCourseSubtitle =>
      'Enter the course details. You can start topics after saving.';

  @override
  String get saveCourse => 'Save Course';

  @override
  String get editCourse => 'Edit course';

  @override
  String get editCourseTitle => 'Edit Course';

  @override
  String get editCourseSubtitle =>
      'Update the course details. The course ID cannot be changed.';

  @override
  String get saveCourseChanges => 'Save changes';

  @override
  String get courseAdded => 'Course saved.';

  @override
  String get courseUpdated => 'Course updated.';

  @override
  String get sectionBasic => 'Basic information';

  @override
  String get sectionSchedule => 'Schedule';

  @override
  String get sectionAcademic => 'Academic details';

  @override
  String get courseCode => 'Course ID';

  @override
  String get courseCodeTaken =>
      'This course ID is already added. Use a different ID.';

  @override
  String get department => 'Department';

  @override
  String get creditHours => 'Credit hours';

  @override
  String get phoneOtpDesktopUnavailable =>
      'Phone verification is available in the mobile app. On Windows, use email sign-up or email password reset. Existing accounts can still sign in with phone and password.';

  @override
  String fileDownloadStarted(String name) {
    return 'Download started: $name';
  }

  @override
  String creditHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count credit hours',
      one: '1 credit hour',
    );
    return '$_temp0';
  }

  @override
  String get creditHoursInvalid => 'Enter credit hours between 1 and 5.';

  @override
  String get lectureHall => 'Lecture hall';

  @override
  String get lectureDays => 'Lecture days';

  @override
  String get selectLectureDay => 'Select at least one lecture day.';

  @override
  String get lectureTime => 'Lecture time';

  @override
  String get lectureDaysAndTimeTitle => 'Lecture Days & Time';

  @override
  String get lectureDaysAndTimeHint =>
      'Select days and set From / To for each slot';

  @override
  String get selectLectureDaysLabel => 'Select Lecture Days';

  @override
  String get selectMultipleDaysTip => 'You can select multiple days';

  @override
  String get lectureTimeSlotsLabel => 'Lecture Time Slots';

  @override
  String get addAnotherTimeSlot => 'Add Another Time Slot';

  @override
  String get timeFrom => 'From';

  @override
  String get timeTo => 'To';

  @override
  String get registrationDate => 'Registration date';

  @override
  String get selectDate => 'Select date';

  @override
  String get courseOutlines => 'Course outlines';

  @override
  String get semester => 'Semester';

  @override
  String get section => 'Section';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get openMenu => 'Menu';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeHint => 'Choose your preferred app theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkOption => 'Dark';

  @override
  String get languageHint => 'Select your preferred language';

  @override
  String get deleteAccountHint =>
      'Permanently remove your account and all data';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get goBack => 'Back';

  @override
  String get findYourTeacher => 'Find Your Teacher';

  @override
  String get searchTeacherHint => 'Search by teacher email...';

  @override
  String get filter => 'Filter';

  @override
  String get keepLearningAhead => 'Keep learning and stay ahead.';

  @override
  String get keepTeachingAhead =>
      'Add courses and stay in sync with your class.';

  @override
  String get searchCoursesHint => 'Search your courses...';

  @override
  String get notificationsSoon => 'Notifications will open here next.';

  @override
  String get filtersSoon => 'Filters will be added next.';

  @override
  String get courseDetails => 'Course details';

  @override
  String get uploadSyllabus => 'Upload syllabus';

  @override
  String get editCourseDetails => 'Edit course details';

  @override
  String get syllabusFiles => 'Syllabus';

  @override
  String get syllabusUploaded => 'Syllabus uploaded.';

  @override
  String get courseInformation => 'Course Information';

  @override
  String get classSchedule => 'Class Schedule';

  @override
  String deleteCourseConfirm(String name) {
    return 'Delete $name? This cannot be undone.';
  }

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabSyllabus => 'Syllabus';

  @override
  String get tabLectures => 'Lectures';

  @override
  String get tabAssignments => 'Assignments';

  @override
  String get tabResources => 'Resources';

  @override
  String get courseInfo => 'Course info';

  @override
  String get announcements => 'Announcements';

  @override
  String get writeAnnouncement => 'Write an announcement...';

  @override
  String get postAnnouncement => 'Post';

  @override
  String get noAnnouncements => 'No announcements yet.';

  @override
  String get schedule => 'Schedule';

  @override
  String get location => 'Location';

  @override
  String get credits => 'Credits';

  @override
  String get courseOutline => 'Course Outline';

  @override
  String get addWeek => '+ Add Week';

  @override
  String weekNumber(int number) {
    return 'W$number';
  }

  @override
  String get weekTitle => 'Week title';

  @override
  String get weekReadings => 'Readings';

  @override
  String get weekNotes => 'Notes (optional)';

  @override
  String get emptyWeeks => 'No weeks yet. Add the first week of the outline.';

  @override
  String get addLecture => '+ Add Lecture';

  @override
  String get lectureTitle => 'Lecture title';

  @override
  String get lectureDate => 'Lecture date';

  @override
  String get lectureDescription => 'Description';

  @override
  String get lectureAttachment => 'Attachment name (optional)';

  @override
  String get lectureFileHint =>
      'Upload one or more PDF, Word, or PowerPoint files';

  @override
  String get assignmentFileHint => 'Upload one or more PDF or Word files';

  @override
  String get resourceFileHint => 'Upload one or more PDF or Word files';

  @override
  String get addFiles => 'Add files';

  @override
  String get uploadingFiles => 'Uploading…';

  @override
  String get removeFile => 'Remove';

  @override
  String get addLink => 'Add another link';

  @override
  String get resourceLink => 'https://example.com';

  @override
  String get fileTooLarge => 'File must be smaller than 20 MB.';

  @override
  String get fileUnreadable => 'Could not read that file. Try another one.';

  @override
  String get fileUploadFailed => 'Could not upload the file. Try again.';

  @override
  String get storageDenied =>
      'Could not save the file. Sign in as the course teacher and try again.';

  @override
  String get emptyLectures => 'No lectures yet. Add the first lecture.';

  @override
  String get addAssignment => '+ Add Assignment';

  @override
  String get assignmentTitle => 'Assignment title';

  @override
  String get assignmentDue => 'Due date';

  @override
  String get assignmentPoints => 'Points';

  @override
  String get assignmentDescription => 'Description';

  @override
  String get published => 'Published';

  @override
  String get emptyAssignments =>
      'No assignments yet. Add the first assignment.';

  @override
  String get addResource => '+ Add Resource';

  @override
  String get resourceTitle => 'Resource title';

  @override
  String get resourceType => 'Type (Textbook, Document, Link…)';

  @override
  String get resourceDetail => 'Short description';

  @override
  String get emptyResources => 'No resources yet. Add the first resource.';

  @override
  String get itemAdded => 'Saved.';

  @override
  String get viewDetails => 'View details';

  @override
  String get editItem => 'Edit';

  @override
  String get viewWeek => 'Week details';

  @override
  String get editWeek => 'Edit week';

  @override
  String get viewLecture => 'Lecture details';

  @override
  String get editLecture => 'Edit lecture';

  @override
  String get viewAssignment => 'Assignment details';

  @override
  String get editAssignment => 'Edit assignment';

  @override
  String get viewResource => 'Resource details';

  @override
  String get editResource => 'Edit resource';

  @override
  String get navProfile => 'Profile';

  @override
  String get navJoinedCourses => 'Joined Courses';

  @override
  String get noJoinedCoursesYet => 'You have not joined any courses yet.';

  @override
  String get profileSettings => 'Profile Settings';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get bio => 'Bio';

  @override
  String get bioHint => 'Share a brief introduction about yourself...';

  @override
  String get officeTiming => 'Office Timing';

  @override
  String get academicInformation => 'Academic Information';

  @override
  String get aboutMe => 'About';

  @override
  String get university => 'University';

  @override
  String get enrollmentYear => 'Enrollment Year';

  @override
  String get officeNumber => 'Office Number';

  @override
  String get officeInformation => 'Office Information';

  @override
  String get activeStatus => 'Active';

  @override
  String get phoneShort => 'Phone';

  @override
  String get notSet => 'Not set';

  @override
  String get country => 'Country';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get save => 'Save';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileSaveFailed => 'Could not save your profile. Try again.';

  @override
  String get profilePhotoHint => 'JPG, JPEG, or PNG only';

  @override
  String get profilePhotoInvalidType =>
      'Only JPG, JPEG, and PNG images are allowed.';

  @override
  String get profilePhotoTooLarge =>
      'That photo is too large. Choose a smaller JPG or PNG.';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'Permanently delete your account and all of your courses and data. This action is irreversible.';

  @override
  String get deleteAccountConfirm =>
      'Delete your account and all of your data? This cannot be undone.';

  @override
  String get chaptersAndTopics => 'Chapters & Topics';

  @override
  String get manageCourseContent =>
      'Organize what you will teach in this course.';

  @override
  String get viewCourseContent =>
      'Explore the chapters and topics in this course.';

  @override
  String get addChapter => 'Add chapter';

  @override
  String get editChapter => 'Edit chapter';

  @override
  String get deleteChapter => 'Delete chapter';

  @override
  String get deleteChapterConfirm =>
      'Delete this chapter and all of its topics?';

  @override
  String chapterNumber(int number) {
    return 'Chapter $number';
  }

  @override
  String get chapterTitle => 'Chapter title';

  @override
  String get chapterDescription => 'Short chapter description';

  @override
  String get noChapters => 'No chapters yet.';

  @override
  String get noChaptersTeacherHint =>
      'Add the first chapter to start organizing this course.';

  @override
  String get noChaptersStudentHint =>
      'Your teacher has not added any chapters yet.';

  @override
  String get addTopic => 'Add topic';

  @override
  String get changeTopic => 'Change topic';

  @override
  String get continueLectureHint =>
      'Select a previous topic or add a new one to continue this lecture.';

  @override
  String lectureTopicSwitched(String topic) {
    return 'Now teaching: $topic';
  }

  @override
  String get editTopic => 'Edit topic';

  @override
  String get deleteTopic => 'Delete topic';

  @override
  String get deleteTopicConfirm => 'Delete this topic?';

  @override
  String get topicTitle => 'Topic title';

  @override
  String get topicDescription => 'Short topic description';

  @override
  String get noTopics => 'No topics in this chapter yet.';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get contentSaveFailed =>
      'Could not save the course content. Try again.';

  @override
  String get startLecture => 'Start Lecture';

  @override
  String get joinLecture => 'Join Lecture';

  @override
  String joinLectureConfirm(String course, String topic) {
    return 'Join the live lecture for $course?\n\n$topic\n\nFocus mode will try to keep you in LEARNsync until the teacher ends the lecture. Other apps, calls, and notifications cannot be fully blocked on a normal phone.';
  }

  @override
  String get endLecture => 'End Lecture';

  @override
  String get endLectureConfirm => 'End this live lecture for all students?';

  @override
  String get selectChapter => 'Select chapter';

  @override
  String get selectTopic => 'Select topic';

  @override
  String get lectureDuration => 'Lecture duration';

  @override
  String durationMinutes(int count) {
    return '$count minutes';
  }

  @override
  String get noTopicsToStart =>
      'Add at least one chapter and topic before starting a lecture.';

  @override
  String get lectureLiveNow => 'A lecture is live now';

  @override
  String get liveLectures => 'Live Lectures';

  @override
  String get chooseLiveLecture => 'Choose a live lecture to join';

  @override
  String get timeRemaining => 'Time remaining';

  @override
  String get lectureEnded => 'This lecture has ended.';

  @override
  String get liveSessionStartFailed =>
      'Could not start the lecture. Check that another lecture is not already active.';

  @override
  String get teacherAlreadyLive =>
      'You already have a live lecture. End it before starting another.';

  @override
  String get requestToJoin => 'Request to Join';

  @override
  String get joinRequestPending => 'Waiting for teacher approval';

  @override
  String get enterLecture => 'Enter Lecture';

  @override
  String get joinRequestSent => 'Join request sent to the teacher.';

  @override
  String get joinRequestFailed => 'Could not send join request. Try again.';

  @override
  String get joinRequests => 'Join Requests';

  @override
  String get acceptJoin => 'Accept';

  @override
  String get joinAll => 'Join All';

  @override
  String get noJoinRequests => 'No pending join requests.';

  @override
  String get acceptJoinFailed => 'Could not accept the join request.';

  @override
  String get feedbackSubmitted => 'Thanks — your feedback was saved.';

  @override
  String get feedbackSubmitFailed => 'Could not save feedback. Try again.';

  @override
  String get lectureFeedbackTitle => 'Lecture Feedback';

  @override
  String get endedBadge => 'ENDED';

  @override
  String get feedbackCommentHint => 'Share comments or suggestions (optional)';

  @override
  String get submitFeedbackCta => 'SUBMIT FEEDBACK';

  @override
  String get selectUnderstandingFirst =>
      'Select how well you understood this topic.';

  @override
  String get feedbackSubmittedTitle => 'Feedback Submitted!';

  @override
  String get lectureEndTitle => 'Lecture End';

  @override
  String get lectureEndSubtitle => 'What would you like to do next?';

  @override
  String feedbackNextPrompt(String level) {
    return 'Since you selected \'$level\', what would you like to do next?';
  }

  @override
  String get practiceWithAiTitle => 'Practice with AI Assistant';

  @override
  String practiceWithAiHint(String topic) {
    return 'Quiz yourself on $topic concepts now.';
  }

  @override
  String get scheduleMeetingTitle => 'Schedule Meeting with Teacher';

  @override
  String scheduleMeetingHint(String teacher) {
    return 'Schedule a quick 1-on-1 virtual session with $teacher.';
  }

  @override
  String get maybeLater => 'Maybe Later';

  @override
  String get teacherFeedbackSubtitle =>
      'See how students understood this lecture.';

  @override
  String get completedStatus => 'Completed';

  @override
  String get studentsLabel => 'Students';

  @override
  String responsesOfTotal(int received, int total) {
    return 'Responses: $received/$total';
  }

  @override
  String practiceRateLabel(int percent) {
    return 'Practice Rate: $percent%';
  }

  @override
  String totalRequestsLabel(int count) {
    return '$count Total Requests';
  }

  @override
  String thisCourseRequests(int count) {
    return 'This Course: $count';
  }

  @override
  String get understandingBreakdown => 'Understanding Breakdown';

  @override
  String studentResponsesCount(int count) {
    return 'Student Responses ($count)';
  }

  @override
  String get understoodPerfectly => 'Understood perfectly';

  @override
  String get understoodMost => 'Understood most';

  @override
  String get understoodSome => 'Understood some';

  @override
  String get needMoreHelp => 'Need more help';

  @override
  String get practicedBadge => 'Practiced';

  @override
  String get notPracticedBadge => 'Not Practiced';

  @override
  String get meetingShort => 'Meeting';

  @override
  String get yesLabel => 'Yes';

  @override
  String get noLabel => 'No';

  @override
  String get showLess => 'Show less';

  @override
  String needHelpInsight(int count, int percent) {
    return '$count students ($percent%) need more help on this topic. Consider revising examples and practice.';
  }

  @override
  String get understandingSummary => 'Understanding feedback';

  @override
  String feedbackCountLabel(int count) {
    return '$count responses';
  }

  @override
  String get noFeedbackYet => 'No student feedback yet.';

  @override
  String get changeFeedback => 'Change feedback';

  @override
  String get liveSessionEndFailed => 'Could not end the lecture. Try again.';

  @override
  String liveTopic(String topic) {
    return 'Live: $topic';
  }

  @override
  String get liveNow => 'LIVE';

  @override
  String get lectureComplete => 'ENDED';

  @override
  String get plannedDuration => 'Planned';

  @override
  String get sessionDetails => 'Session details';

  @override
  String get startTime => 'Start time';

  @override
  String studentsPresent(int count) {
    return '$count Present';
  }

  @override
  String get attendance => 'Attendance';

  @override
  String attendeesCount(int count) {
    return 'Attendees ($count)';
  }

  @override
  String get noStudentsYet => 'No students have joined yet.';

  @override
  String get youAreInClass => 'You are in this lecture';

  @override
  String get waitingForStudents => 'Waiting for students to join';

  @override
  String get teachingLiveHint => 'You are currently teaching live';

  @override
  String get attendingLiveHint => 'You are currently attending live';

  @override
  String get lectureInformation => 'Lecture Information';

  @override
  String get currentTopic => 'Current Topic';

  @override
  String get estimatedEnd => 'Estimated End';

  @override
  String get topicLiveHint =>
      'This topic is live and visible to all enrolled students.';

  @override
  String joinedAt(String time) {
    return 'Joined at $time';
  }

  @override
  String get scheduleLabel => 'Schedule';

  @override
  String get totalStudents => 'Students';

  @override
  String get creditsShort => 'Credits';

  @override
  String get liveChatSoon => 'Live chat will open from here next.';

  @override
  String get livePollSoon => 'Live polls will open from here next.';

  @override
  String get liveChat => 'Chat';

  @override
  String get livePoll => 'Poll';

  @override
  String pointsLabel(int count) {
    return '$count pts';
  }

  @override
  String get lectureSummaryTitle => 'Lecture Summary';

  @override
  String get lectureSummarySubtitle =>
      'Review this lecture before viewing student feedback.';

  @override
  String get viewStudentFeedback => 'View student feedback';

  @override
  String get endTime => 'End time';

  @override
  String get actualDuration => 'Actual duration';

  @override
  String get lectureSummarySaveFailed =>
      'Could not save the lecture summary. Try again.';

  @override
  String get taughtNotesLabel => 'What did you teach today?';

  @override
  String get taughtNotesHint =>
      'Add a short note about what you covered in this lecture.';

  @override
  String get taughtNotesRequired => 'Please enter what you taught today.';

  @override
  String get backToDashboard => 'Back to Dashboard';

  @override
  String get aiPracticeScreenTitle => 'Practice with AI';

  @override
  String get aiQuizResultsTitle => 'AI Quiz Results';

  @override
  String get inProgressStatus => 'IN PROGRESS';

  @override
  String get completedBadgeCaps => 'COMPLETED';

  @override
  String topicPrefix(String topic) {
    return 'Topic: $topic';
  }

  @override
  String get aiPracticeAnswerAll =>
      'Please answer all 5 questions below before submitting.';

  @override
  String questionOfTotal(int current, int total) {
    return 'QUESTION $current OF $total';
  }

  @override
  String get submitQuiz => 'SUBMIT QUIZ';

  @override
  String get quizCompletedTitle => 'Quiz Completed!';

  @override
  String get quizPassedMessage =>
      'Great effort! You have passed this interactive review module successfully.';

  @override
  String get quizFailedMessage =>
      'Review the explanations and try again to strengthen what you missed.';

  @override
  String get passedBadge => 'PASSED';

  @override
  String get needsReviewBadge => 'NEEDS REVIEW';

  @override
  String get totalQuestionsLabel => 'TOTAL QUESTIONS';

  @override
  String get correctAnswersLabel => 'CORRECT ANSWERS';

  @override
  String get wrongAnswersLabel => 'WRONG ANSWERS';

  @override
  String get aiTutorBadge => 'AI TUTOR';

  @override
  String get diagnosticTitle => 'Diagnostic Evaluation & Guidance';

  @override
  String get reviewExplanations => 'Review Question Explanations';

  @override
  String get practiceAgain => 'Practice Again';

  @override
  String get endPractice => 'End Practice';

  @override
  String get resultsSecureHint =>
      'Your performance has been evaluated and committed securely.';

  @override
  String get aiPracticeUnsupported =>
      'AI practice runs on the mobile app. This browser cannot load the on-device Qwen 2.5 0.5B model.';

  @override
  String get aiPracticeNoNotesTitle => 'Lecture notes needed';

  @override
  String get aiPracticeNoNotes =>
      'Your teacher has not saved notes for what was taught today, so a practice quiz cannot be generated yet. Ask them to save lecture notes, then try again.';

  @override
  String get aiPracticeNoBelow50Title => 'No slides below 50%';

  @override
  String get aiPracticeNoBelow50 =>
      'Practice questions come only from slides you marked below 50%. You have not marked any slide below 50% for this lecture, so there is no quiz yet.';

  @override
  String aiPracticeSourceChapter(String chapter) {
    return 'Chapter: $chapter';
  }

  @override
  String aiPracticeSourceLecture(String lecture) {
    return 'Lecture: $lecture';
  }

  @override
  String aiPracticeSourceSlide(String slide) {
    return 'Slide: $slide';
  }

  @override
  String aiPracticeSourceTopic(String topic) {
    return 'Topic: $topic';
  }

  @override
  String get aiPracticeDownloadTitle => 'Preparing on-device AI';

  @override
  String get aiPracticeDownloadHint =>
      'Downloading Qwen 2.5 0.5B for private, on-device practice. This happens once.';

  @override
  String get aiPracticeGenerating =>
      'Writing 5 questions from today\'s lecture notes…';

  @override
  String get aiPracticeGenerateFailed =>
      'Could not generate a quiz. Try again.';

  @override
  String get aiPracticeRetry => 'Try again';

  @override
  String get aiPracticeSubmitIncomplete =>
      'Answer every question before submitting.';

  @override
  String get aiPracticeSaveFailed => 'Could not save your practice attempt.';

  @override
  String get explanationCorrectLabel => 'Correct answer';

  @override
  String get explanationYourAnswer => 'Your answer';

  @override
  String optionLetter(Object letter) {
    return '$letter';
  }

  @override
  String get teacherAnalytics => 'Teacher Analytics';

  @override
  String get teacherAnalyticsHint =>
      'See understanding, AI practice, and meetings.';

  @override
  String get teacherAnalyticsSubtitle =>
      'Spot hard topics and students who need support.';

  @override
  String get analyticsOverview => 'Overview';

  @override
  String get analyticsUnderstanding => 'Understanding';

  @override
  String get analyticsPractice => 'AI practice';

  @override
  String get analyticsMeetings => 'Meetings';

  @override
  String analyticsAverage(int value) {
    return 'Average $value%';
  }

  @override
  String analyticsResponses(int count) {
    return '$count responses';
  }

  @override
  String analyticsParticipation(int percent) {
    return '$percent% participation';
  }

  @override
  String analyticsCompletion(int percent) {
    return '$percent% completion';
  }

  @override
  String analyticsAverageScore(int value) {
    return 'Avg score $value%';
  }

  @override
  String analyticsMeetingTotal(int count) {
    return '$count requests';
  }

  @override
  String get analyticsTopicOverview => 'Topic Overview';

  @override
  String analyticsCombinedLectures(int count) {
    return '$count lectures combined';
  }

  @override
  String get analyticsTotalStudents => 'Total Students';

  @override
  String get analyticsTotalResponses => 'Total Responses';

  @override
  String get analyticsAvgUnderstanding => 'Avg. Understanding';

  @override
  String get analyticsUnderstandingDistribution =>
      'Understanding Level Distribution';

  @override
  String get analyticsStudentPerformance => 'Student Performance & Details';

  @override
  String get analyticsSearchStudent => 'Search student...';

  @override
  String get analyticsOnTrack => 'On Track';

  @override
  String get analyticsNeedsAttention => 'Needs Attention';

  @override
  String get analyticsMeetingYes => 'Yes';

  @override
  String get analyticsMeetingNo => 'No';

  @override
  String get analyticsSelectTopicHint =>
      'Select a course, chapter, and topic to see combined analytics for every lecture on that topic.';

  @override
  String get analyticsByTopic => 'Understanding by topic';

  @override
  String get analyticsBySession => 'Understanding by session';

  @override
  String get analyticsNeedsSupport => 'Students needing support';

  @override
  String get analyticsLowUnderstanding => 'Low understanding';

  @override
  String get analyticsIncompletePractice => 'Have not practiced';

  @override
  String get analyticsPendingMeetings => 'Pending meetings';

  @override
  String get analyticsAllCourses => 'All courses';

  @override
  String get analyticsAllChapters => 'All chapters';

  @override
  String get analyticsAllTopics => 'All topics';

  @override
  String get analyticsAllTime => 'All time';

  @override
  String get analyticsLast7Days => 'Last 7 days';

  @override
  String get analyticsLast30Days => 'Last 30 days';

  @override
  String get analyticsCustomRange => 'Custom dates';

  @override
  String get analyticsFromDate => 'From';

  @override
  String get analyticsToDate => 'To';

  @override
  String get analyticsEmptyTitle => 'No analytics yet';

  @override
  String get analyticsEmpty =>
      'After students submit feedback, practice, or request meetings, their results will appear here.';

  @override
  String get analyticsLoadFailed => 'Could not load analytics. Try again.';

  @override
  String get analyticsPracticeUnavailable =>
      'AI practice stats are unavailable right now. Understanding and meetings are still shown.';

  @override
  String get analyticsRetry => 'Try again';

  @override
  String get analyticsNoBars => 'No understanding data for this filter.';

  @override
  String get analyticsNoStudents => 'No students in this list.';

  @override
  String analyticsResponsesShort(int count, int value) {
    return '$count responses · $value%';
  }

  @override
  String get analyticsChapterFilter => 'Chapter';

  @override
  String get analyticsTopicFilter => 'Topic';

  @override
  String get dateRangeLabel => 'Date range';

  @override
  String get aiPracticesEmpty =>
      'No ended lectures yet. After your teacher finishes a class with notes, practice will show up here.';

  @override
  String get aiPracticeColorLegendTooltip => 'Color meaning';

  @override
  String get aiPracticeColorLegendTitle => 'Color meaning';

  @override
  String get aiPracticeColorLegendSubtitle =>
      'The colors show how many AI practices are used.';

  @override
  String get aiPracticeColorNone => '0 AI practice';

  @override
  String get aiPracticeColorFew => '1 or 2 AI practice';

  @override
  String get aiPracticeColorMany => '3+ AI practice';

  @override
  String get aiPracticeColorRed => 'red';

  @override
  String get aiPracticeColorYellow => 'yellow';

  @override
  String get aiPracticeColorTeal => 'teal';

  @override
  String get lectureAnalytics => 'Lecture Analytics';

  @override
  String get lectureAnalyticsHint =>
      'See how students engaged with each lecture.';

  @override
  String get remove => 'Remove';

  @override
  String get enrolledStudents => 'Enrolled Students';

  @override
  String get enrolledStudentsHint =>
      'View and manage students enrolled in this course.';

  @override
  String enrolledStudentsCount(int count) {
    return '$count enrolled';
  }

  @override
  String get tapToViewProfile => 'Tap to view profile';

  @override
  String get noEnrolledStudentsYet =>
      'No students are enrolled in this course yet.';

  @override
  String get removeEnrolledStudent => 'Remove student';

  @override
  String removeEnrolledStudentConfirm(String name) {
    return 'Remove $name from this course? They will need to request to join again.';
  }

  @override
  String get removeEnrolledStudentFailed =>
      'Could not remove the student. Try again.';

  @override
  String studentRemovedFromCourse(String name) {
    return '$name was removed from this course.';
  }

  @override
  String get lectureAnalyticsSubtitle =>
      'See how your students engaged with this lecture.';

  @override
  String get courseLecturesTitle => 'Course Lectures';

  @override
  String get courseLecturesEmpty =>
      'No lectures yet for this course. After you run a live lecture, it will appear here.';

  @override
  String get lectureAnalyticsNote =>
      'After the lecture ends you can see how many students understood the topic, completed AI practice, and requested a meeting.';

  @override
  String get backToLectures => 'Back to Lectures';

  @override
  String get viewAllRequests => 'View All Requests';

  @override
  String totalRequestsThisLecture(int count) {
    return '$count Total Requests This Lecture';
  }

  @override
  String studentsCountLabel(int count) {
    return '$count Students';
  }

  @override
  String get understandingSection => '1. Understanding';

  @override
  String get aiPracticeSection => '2. AI Practice';

  @override
  String get meetingsSection => '3. Meetings';

  @override
  String get lectureMeetingsHubTitle => 'Lecture Meetings';

  @override
  String get lectureMeetingsHubSubtitle => 'Requests for this lecture only.';

  @override
  String get pendingRequests => 'Pending requests';

  @override
  String get scheduledMeetings => 'Scheduled meetings';

  @override
  String get attendedMeetings => 'Attended';

  @override
  String get noMeetingsForLecture =>
      'No meeting requests for this lecture yet.';

  @override
  String get noPendingMeetingsForLecture =>
      'No pending requests for this lecture.';

  @override
  String get noScheduledMeetingsForLecture =>
      'No scheduled meetings for this lecture.';

  @override
  String get noAttendedMeetingsForLecture =>
      'No attended meetings for this lecture.';

  @override
  String get understandingDetailTitle => 'Understanding Details';

  @override
  String get aiPracticeDetailTitle => 'AI Practice Details';

  @override
  String get understandingDetailHint =>
      'See how each student understood this lecture';

  @override
  String get aiPracticeDetailHint =>
      'See which students practiced this lecture';

  @override
  String get noPracticeAttemptsYet =>
      'No AI practice attempts for this lecture yet.';

  @override
  String get understandingOverview => 'Understanding Overview';

  @override
  String get practiceOverview => 'AI Practice Overview';

  @override
  String get meetingsOverview => 'Meetings Overview';

  @override
  String get totalResponsesLabel => 'Total Responses';

  @override
  String get totalPracticeLabel => 'Total Practice';

  @override
  String get totalMeetingsLabel => 'Total Meetings';

  @override
  String get searchStudentHint => 'Search student...';

  @override
  String get noStudentsInLevel => 'No students in this understanding level.';

  @override
  String get noStudentsInPracticeGroup => 'No students in this practice group.';

  @override
  String get noMatchingStudents => 'No students match your search.';

  @override
  String get noMeetingsInBucket => 'No meetings in this category.';

  @override
  String get noMatchingMeetings => 'No meetings match your search.';

  @override
  String studentsHeadingCount(int count) {
    return 'Students ($count)';
  }

  @override
  String meetingsHeadingCount(int count) {
    return 'Meetings ($count)';
  }

  @override
  String meetingsCountLabel(int count) {
    return '$count Meetings';
  }

  @override
  String get meetingsDetailTitle => 'Meetings Details';

  @override
  String get meetingsDetailHint => 'See meeting requests for this lecture';

  @override
  String get meetingBucketPending => 'Pending';

  @override
  String get meetingBucketScheduled => 'Scheduled';

  @override
  String get meetingBucketAttended => 'Attended';

  @override
  String get studentProfileTitle => 'Student Profile';

  @override
  String get thisLectureUnderstanding => 'Understanding for this lecture';

  @override
  String get teacherUnderstandingAnalyticsTitle => 'Understanding Analytics';

  @override
  String get teacherPracticeAnalyticsTitle => 'AI Practice Analytics';

  @override
  String get teacherPracticeAnalyticsHint =>
      'See practice across your filtered lectures';

  @override
  String get teacherMeetingsAnalyticsTitle => 'Meetings Analytics';

  @override
  String get teacherMeetingsAnalyticsHint =>
      'See meetings across your current filters';

  @override
  String get noTeacherPracticeAttemptsYet =>
      'No AI practice attempts for this filter yet.';

  @override
  String get noTeacherMeetingsYet => 'No meeting requests for this filter yet.';

  @override
  String get openFile => 'Open';

  @override
  String get downloadFile => 'Download';

  @override
  String get fileOpenFailed => 'Could not open that file.';

  @override
  String get fileDownloadFailed => 'Could not download that file. Try again.';

  @override
  String fileDownloadSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get joiningRequests => 'Joining Requests';

  @override
  String get noJoiningRequests => 'No pending course join requests.';

  @override
  String get joinCourse => 'Join Course';

  @override
  String get requestSentTag => 'Request sent';

  @override
  String get courseJoinedTag => 'Course joined';

  @override
  String get acceptJoinRequest => 'Accept';

  @override
  String get rejectJoinRequest => 'Reject';

  @override
  String get joinRequestAccepted => 'Student joined the course.';

  @override
  String get joinRequestRejected => 'Join request rejected.';

  @override
  String get joinRequestActionFailed =>
      'Could not update that request. Try again.';

  @override
  String get invalidPhoneNumber => 'Enter a valid phone number';

  @override
  String get verify => 'Verify';

  @override
  String otpSentToPhone(String contact) {
    return 'We sent a code to $contact';
  }

  @override
  String otpSmsSent(String contact) {
    return 'A new code was sent to $contact';
  }

  @override
  String otpAttemptsRemaining(int count) {
    return '$count attempts remaining';
  }

  @override
  String get otpAttemptsExhausted =>
      'Too many attempts. Please resend the code.';

  @override
  String otpInvalidWithAttempts(int count) {
    return 'Invalid code. $count attempts left';
  }

  @override
  String resendInSeconds(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpInvalidCode => 'The code you entered is incorrect';

  @override
  String get otpExpiredCode => 'This code has expired, please resend';

  @override
  String get didntReceiveCode => 'Didn\'t receive the code?';

  @override
  String get verifyPhoneTitle => 'Check your phone';

  @override
  String verifyPhoneBody(String phone) {
    return 'Enter the 6-digit code we sent by SMS to $phone.';
  }

  @override
  String get phoneVerifiedPleaseLogin => 'Phone verified. Please log in.';

  @override
  String get emailOrPhoneHint => 'Email or phone with country code';

  @override
  String get invalidEmailOrPhone => 'Enter a valid email or country code';

  @override
  String get topicFilesRequired =>
      'Upload at least one slide or file for this topic.';

  @override
  String get topicFilesRequiredHint =>
      'Slides/files required (PDF, Word, or PowerPoint).';

  @override
  String get topicSlides => 'Slides';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String slidePageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String slideFileOf(int current, int total) {
    return 'File $current of $total';
  }

  @override
  String slideFilePageOf(int file, int files, int page, int pages) {
    return 'File $file of $files · Page $page of $pages';
  }

  @override
  String get slidesLoadFailed => 'Could not load this file.';

  @override
  String get slidesOpenExternally => 'This file type opens outside the app.';

  @override
  String get noTopicSlides => 'No slides uploaded for this topic.';

  @override
  String get followingTeacher => 'Following teacher';

  @override
  String get liveSlideHowClear => 'How clear is this slide?';

  @override
  String get liveSlideSignalsTitle => 'Live slide understanding';

  @override
  String get liveSlideSignalSaved => 'Saved for this slide';

  @override
  String get liveSlideNoSignals =>
      'No student feedback has been submitted yet.';

  @override
  String liveSlideOnPage(int page) {
    return 'Slide $page';
  }

  @override
  String liveSlideOnFilePage(int file, int page) {
    return 'File $file · Slide $page';
  }

  @override
  String liveSlideNeedHelpCount(int count) {
    return '$count need help on this slide';
  }

  @override
  String get liveSlideSignalFailed =>
      'Could not save slide feedback. Try again.';

  @override
  String get studentSlideFeedbackSummaryTitle => 'Your slide feedback';

  @override
  String get studentSlideFeedbackSummarySubtitle =>
      'Review how you rated each slide during the lecture.';

  @override
  String get studentSlideFeedbackEmpty =>
      'You did not leave feedback on any slides during this lecture.';

  @override
  String get studentSlideFeedbackNext => 'Next';

  @override
  String lectureSummaryTitleNumbered(int number) {
    return 'Lecture $number Summary';
  }

  @override
  String studentSlideFeedbackSummaryTitleNumbered(int number) {
    return 'Lecture $number slide feedback';
  }

  @override
  String lectureEndTitleNumbered(int number) {
    return 'Lecture $number ended';
  }

  @override
  String practiceWithAiTitleNumbered(int number) {
    return 'Practice Lecture $number with AI Assistant';
  }

  @override
  String lectureNumber(int number) {
    return 'Lecture $number';
  }

  @override
  String get liveFocusModeBanner =>
      'Focus mode on — stay in LEARNsync until the lecture ends. Other apps, calls, and notifications are not fully blocked by the OS.';

  @override
  String get liveFocusModeAndroidHint =>
      'Focus mode: screen stays on, screenshots blocked, and Android may ask to pin this app. Allow Do Not Disturb access to silence notifications (calls still may ring without MDM).';

  @override
  String get liveFocusModeIosHint =>
      'Focus mode: screen stays on. iOS cannot block other apps, calls, or notifications from this app — use Guided Access (Settings > Accessibility) for a stronger lockdown.';

  @override
  String get liveFocusOpenDndSettings => 'DND access';

  @override
  String get liveFocusLeftAppWarn =>
      'You left LEARNsync during the live lecture. Your teacher can see you as away. Return and stay in the lecture.';

  @override
  String get liveFocusStayTitle => 'Lecture in progress';

  @override
  String get liveFocusStayBody =>
      'Stay in this screen until your teacher ends the lecture. Leaving early is visible to the teacher.';

  @override
  String get liveFocusStudentAway => 'Away (left app)';

  @override
  String get liveFollowTeacher => 'Follow teacher';

  @override
  String get jumpToSlide => 'Jump to slide';

  @override
  String get slideNumber => 'Slide number';

  @override
  String slideNumberOutOfRange(int count) {
    return 'Enter a slide number between 1 and $count.';
  }
}
