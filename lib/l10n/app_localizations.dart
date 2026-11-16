import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'LEARNsync'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Real time student feedback'**
  String get appTagline;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login to continue to your account.'**
  String get loginSubtitle;

  /// No description provided for @emailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or Username'**
  String get emailOrUsername;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the email for your account. We will send a link to reset your password.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @resetEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get resetEmailSentTitle;

  /// No description provided for @resetEmailSentBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset link to {email}.'**
  String resetEmailSentBody(String email);

  /// No description provided for @resetEmailSentHint.
  ///
  /// In en, this message translates to:
  /// **'Open the email, set a new password, then come back here to log in.'**
  String get resetEmailSentHint;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this email.'**
  String get accountNotFound;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}.'**
  String otpSubtitle(String email);

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpHint;

  /// No description provided for @otpInvalidLength.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit verification code.'**
  String get otpInvalidLength;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get verifyOtp;

  /// No description provided for @otpSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get otpSending;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendOtp;

  /// No description provided for @otpEmailSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification email to {email}. Check your inbox and spam folder.'**
  String otpEmailSent(String email);

  /// No description provided for @otpResent.
  ///
  /// In en, this message translates to:
  /// **'A new verification code was sent to your email.'**
  String get otpResent;

  /// No description provided for @userAlreadyExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account already exists'**
  String get userAlreadyExistsTitle;

  /// No description provided for @userAlreadyExistsBody.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Log in, or use Forgot Password if you need to reset it.'**
  String get userAlreadyExistsBody;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Open the verification email we sent to {email}. After you tap the link, this screen will open the login page.'**
  String verifyEmailBody(String email);

  /// No description provided for @waitingForEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you to tap the link in your email…'**
  String get waitingForEmailVerification;

  /// No description provided for @emailVerifiedPleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Email verified. Please log in.'**
  String get emailVerifiedPleaseLogin;

  /// No description provided for @emailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Open the verification email and tap the link first, then try again.'**
  String get emailNotVerified;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get createAccount;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up to get started.'**
  String get signUpSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @iAmA.
  ///
  /// In en, this message translates to:
  /// **'I am a...'**
  String get iAmA;

  /// No description provided for @teacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// No description provided for @student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @iAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreePrefix;

  /// No description provided for @andConjunction.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andConjunction;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters, with uppercase, lowercase, a number, and a special character.'**
  String get passwordRequirements;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Please select your role'**
  String get selectRole;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms of Use and Privacy Policy'**
  String get acceptTerms;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in. Backend will be connected in a later step.'**
  String get loginSuccess;

  /// No description provided for @signupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created. You can now log in.'**
  String get signupSuccess;

  /// No description provided for @termsPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'The full Terms of Use will be added here before release.'**
  String get termsPlaceholderBody;

  /// No description provided for @privacyPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'The full Privacy Policy will be added here before release.'**
  String get privacyPlaceholderBody;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String helloUser(String name);

  /// No description provided for @teacherDashboard.
  ///
  /// In en, this message translates to:
  /// **'Teacher Dashboard'**
  String get teacherDashboard;

  /// No description provided for @studentDashboard.
  ///
  /// In en, this message translates to:
  /// **'Student Dashboard'**
  String get studentDashboard;

  /// No description provided for @yourCourses.
  ///
  /// In en, this message translates to:
  /// **'Your Courses'**
  String get yourCourses;

  /// No description provided for @addCourse.
  ///
  /// In en, this message translates to:
  /// **'Add Course'**
  String get addCourse;

  /// No description provided for @newCourse.
  ///
  /// In en, this message translates to:
  /// **'New course'**
  String get newCourse;

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseName;

  /// No description provided for @deleteCourse.
  ///
  /// In en, this message translates to:
  /// **'Delete course'**
  String get deleteCourse;

  /// No description provided for @noCoursesTeacher.
  ///
  /// In en, this message translates to:
  /// **'No courses yet. Add a course to start teaching.'**
  String get noCoursesTeacher;

  /// No description provided for @noCoursesStudent.
  ///
  /// In en, this message translates to:
  /// **'Connect your teacher to see available courses.'**
  String get noCoursesStudent;

  /// No description provided for @liveLecture.
  ///
  /// In en, this message translates to:
  /// **'Live Lecture'**
  String get liveLecture;

  /// No description provided for @noLiveLecture.
  ///
  /// In en, this message translates to:
  /// **'No lecture is live right now.'**
  String get noLiveLecture;

  /// No description provided for @connectTeacher.
  ///
  /// In en, this message translates to:
  /// **'Connect with your teacher'**
  String get connectTeacher;

  /// No description provided for @connectTeacherHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your teacher\'s email to access their courses.'**
  String get connectTeacherHint;

  /// No description provided for @teacherEmail.
  ///
  /// In en, this message translates to:
  /// **'Teacher email'**
  String get teacherEmail;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {name}'**
  String connectedTo(String name);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirm;

  /// No description provided for @statsCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get statsCourses;

  /// No description provided for @statsLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get statsLive;

  /// No description provided for @statsMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get statsMeetings;

  /// No description provided for @topicsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} topics'**
  String topicsCount(int count);

  /// No description provided for @startTopicSoon.
  ///
  /// In en, this message translates to:
  /// **'Topic start flow will be added next.'**
  String get startTopicSoon;

  /// No description provided for @aiPracticeSoon.
  ///
  /// In en, this message translates to:
  /// **'AI Practice will open from here next.'**
  String get aiPracticeSoon;

  /// No description provided for @meetingSoon.
  ///
  /// In en, this message translates to:
  /// **'Meeting requests will open from here next.'**
  String get meetingSoon;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get invalidCredentials;

  /// No description provided for @demoHint.
  ///
  /// In en, this message translates to:
  /// **'Demo: teacher@learnsync.app or student@learnsync.app  •  Demo@123'**
  String get demoHint;

  /// No description provided for @emailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email.'**
  String get emailInUse;

  /// No description provided for @memberId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get memberId;

  /// No description provided for @teacherMemberId.
  ///
  /// In en, this message translates to:
  /// **'Teacher ID'**
  String get teacherMemberId;

  /// No description provided for @studentMemberId.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get studentMemberId;

  /// No description provided for @memberIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 3–32 letters, numbers, hyphen, or underscore.'**
  String get memberIdInvalid;

  /// No description provided for @memberIdTaken.
  ///
  /// In en, this message translates to:
  /// **'This ID is already linked to another email.'**
  String get memberIdTaken;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get networkError;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyRequests;

  /// No description provided for @authUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authUnknown;

  /// No description provided for @teacherNotFound.
  ///
  /// In en, this message translates to:
  /// **'No teacher found with that name or email.'**
  String get teacherNotFound;

  /// No description provided for @teacherHasNoCourses.
  ///
  /// In en, this message translates to:
  /// **'Your teacher has not added any courses yet.'**
  String get teacherHasNoCourses;

  /// No description provided for @courseSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the course. Try again.'**
  String get courseSaveFailed;

  /// No description provided for @courseDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the course. Try again.'**
  String get courseDeleteFailed;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @aiPractice.
  ///
  /// In en, this message translates to:
  /// **'AI Practice'**
  String get aiPractice;

  /// No description provided for @meetTeacher.
  ///
  /// In en, this message translates to:
  /// **'Meet Teacher'**
  String get meetTeacher;

  /// No description provided for @welcomeBackName.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBackName(String name);

  /// No description provided for @stayUpdated.
  ///
  /// In en, this message translates to:
  /// **'Stay updated and keep learning!'**
  String get stayUpdated;

  /// No description provided for @currentLiveTopic.
  ///
  /// In en, this message translates to:
  /// **'Current live topic'**
  String get currentLiveTopic;

  /// No description provided for @liveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveBadge;

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter 2: Polynomials'**
  String get chapterLabel;

  /// No description provided for @liveTopicTitle.
  ///
  /// In en, this message translates to:
  /// **'Quadratic Equations'**
  String get liveTopicTitle;

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **'Started at {time}'**
  String startedAt(String time);

  /// No description provided for @howWellUnderstood.
  ///
  /// In en, this message translates to:
  /// **'How well did you understand this topic?'**
  String get howWellUnderstood;

  /// No description provided for @understand100.
  ///
  /// In en, this message translates to:
  /// **'100%'**
  String get understand100;

  /// No description provided for @understand80.
  ///
  /// In en, this message translates to:
  /// **'80%'**
  String get understand80;

  /// No description provided for @understand60.
  ///
  /// In en, this message translates to:
  /// **'60%'**
  String get understand60;

  /// No description provided for @understandBelow50.
  ///
  /// In en, this message translates to:
  /// **'Below 50%'**
  String get understandBelow50;

  /// No description provided for @understand100Hint.
  ///
  /// In en, this message translates to:
  /// **'Fully clear'**
  String get understand100Hint;

  /// No description provided for @understand80Hint.
  ///
  /// In en, this message translates to:
  /// **'Mostly clear'**
  String get understand80Hint;

  /// No description provided for @understand60Hint.
  ///
  /// In en, this message translates to:
  /// **'Need a recap'**
  String get understand60Hint;

  /// No description provided for @understandBelow50Hint.
  ///
  /// In en, this message translates to:
  /// **'Need help'**
  String get understandBelow50Hint;

  /// No description provided for @whatNext.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do next?'**
  String get whatNext;

  /// No description provided for @aiPracticeHint.
  ///
  /// In en, this message translates to:
  /// **'Get topic-specific questions generated for you.'**
  String get aiPracticeHint;

  /// No description provided for @startPractice.
  ///
  /// In en, this message translates to:
  /// **'Start Practice'**
  String get startPractice;

  /// No description provided for @alreadyPracticed.
  ///
  /// In en, this message translates to:
  /// **'Already practiced'**
  String get alreadyPracticed;

  /// No description provided for @practiceMore.
  ///
  /// In en, this message translates to:
  /// **'Practice more'**
  String get practiceMore;

  /// No description provided for @pastPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Past practice'**
  String get pastPracticeTitle;

  /// No description provided for @pastPracticeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved practice questions for this lecture yet.'**
  String get pastPracticeEmpty;

  /// No description provided for @pastPracticeAttemptLabel.
  ///
  /// In en, this message translates to:
  /// **'Attempt {n} · {score}/{total} ({percent}%)'**
  String pastPracticeAttemptLabel(int n, int score, int total, int percent);

  /// No description provided for @requestMeetingHint.
  ///
  /// In en, this message translates to:
  /// **'Ask for extra support without speaking in class.'**
  String get requestMeetingHint;

  /// No description provided for @requestMeeting.
  ///
  /// In en, this message translates to:
  /// **'Request Meeting'**
  String get requestMeeting;

  /// No description provided for @yourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your Progress'**
  String get yourProgress;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @topicsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Topics Completed'**
  String get topicsCompleted;

  /// No description provided for @aiPracticesCompleted.
  ///
  /// In en, this message translates to:
  /// **'AI Practices Completed'**
  String get aiPracticesCompleted;

  /// No description provided for @meetingsRequested.
  ///
  /// In en, this message translates to:
  /// **'Meetings Requested'**
  String get meetingsRequested;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navLiveTopics.
  ///
  /// In en, this message translates to:
  /// **'Live Topics'**
  String get navLiveTopics;

  /// No description provided for @navPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get navPractice;

  /// No description provided for @navMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get navMeetings;

  /// No description provided for @myMeetingRequests.
  ///
  /// In en, this message translates to:
  /// **'My meeting requests'**
  String get myMeetingRequests;

  /// No description provided for @meetingRequests.
  ///
  /// In en, this message translates to:
  /// **'Meeting requests'**
  String get meetingRequests;

  /// No description provided for @meetingDetails.
  ///
  /// In en, this message translates to:
  /// **'Meeting details'**
  String get meetingDetails;

  /// No description provided for @createMeetingIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell your teacher what you need help with. Keep it short and clear.'**
  String get createMeetingIntro;

  /// No description provided for @selectCourse.
  ///
  /// In en, this message translates to:
  /// **'Select course'**
  String get selectCourse;

  /// No description provided for @meetingTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get meetingTopicLabel;

  /// No description provided for @meetingTopicHint.
  ///
  /// In en, this message translates to:
  /// **'What topic do you need help with?'**
  String get meetingTopicHint;

  /// No description provided for @meetingReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get meetingReasonLabel;

  /// No description provided for @meetingReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Share what feels unclear or what you want to discuss.'**
  String get meetingReasonHint;

  /// No description provided for @sendMeetingRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendMeetingRequest;

  /// No description provided for @meetingRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Your meeting request was sent.'**
  String get meetingRequestSent;

  /// No description provided for @meetingRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the meeting request. Try again.'**
  String get meetingRequestFailed;

  /// No description provided for @meetingFormIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Add a topic and reason before sending.'**
  String get meetingFormIncomplete;

  /// No description provided for @linkTeacherFirstForMeeting.
  ///
  /// In en, this message translates to:
  /// **'Connect to your teacher before requesting a meeting.'**
  String get linkTeacherFirstForMeeting;

  /// No description provided for @noMeetingRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No meeting requests yet'**
  String get noMeetingRequestsYet;

  /// No description provided for @noMeetingRequestsStudentHint.
  ///
  /// In en, this message translates to:
  /// **'When something feels unclear, send a quiet request to your teacher.'**
  String get noMeetingRequestsStudentHint;

  /// No description provided for @noMeetingRequestsTeacherHint.
  ///
  /// In en, this message translates to:
  /// **'When a student asks for support, their request will appear here.'**
  String get noMeetingRequestsTeacherHint;

  /// No description provided for @meetingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get meetingStatusPending;

  /// No description provided for @meetingStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get meetingStatusAccepted;

  /// No description provided for @meetingStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get meetingStatusDeclined;

  /// No description provided for @meetingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get meetingStatusCompleted;

  /// No description provided for @meetingStatusReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get meetingStatusReschedule;

  /// No description provided for @meetingScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for'**
  String get meetingScheduledFor;

  /// No description provided for @teacherNote.
  ///
  /// In en, this message translates to:
  /// **'Teacher note'**
  String get teacherNote;

  /// No description provided for @teacherNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note for student (optional)'**
  String get teacherNoteOptional;

  /// No description provided for @meetingPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Your teacher has received this request and will respond soon.'**
  String get meetingPendingHint;

  /// No description provided for @meetingAcceptedHint.
  ///
  /// In en, this message translates to:
  /// **'Your teacher accepted this meeting. Check the scheduled time above.'**
  String get meetingAcceptedHint;

  /// No description provided for @meetingDeclinedHint.
  ///
  /// In en, this message translates to:
  /// **'Your teacher could not take this meeting. You can send a new request anytime.'**
  String get meetingDeclinedHint;

  /// No description provided for @meetingCompletedHint.
  ///
  /// In en, this message translates to:
  /// **'This meeting is marked complete. Great job following up.'**
  String get meetingCompletedHint;

  /// No description provided for @meetingRescheduleHint.
  ///
  /// In en, this message translates to:
  /// **'You asked to reschedule. Your teacher will pick a new time.'**
  String get meetingRescheduleHint;

  /// No description provided for @meetingNotFound.
  ///
  /// In en, this message translates to:
  /// **'This meeting request could not be found.'**
  String get meetingNotFound;

  /// No description provided for @pendingMeetings.
  ///
  /// In en, this message translates to:
  /// **'Needs a reply'**
  String get pendingMeetings;

  /// No description provided for @allMeetings.
  ///
  /// In en, this message translates to:
  /// **'All requests'**
  String get allMeetings;

  /// No description provided for @scheduleMeetingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick a time, then accept or decline.'**
  String get scheduleMeetingPrompt;

  /// No description provided for @chooseMeetingDateTime.
  ///
  /// In en, this message translates to:
  /// **'Choose date & time'**
  String get chooseMeetingDateTime;

  /// No description provided for @chooseNewMeetingDateTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a new date & time'**
  String get chooseNewMeetingDateTime;

  /// No description provided for @chooseMeetingTimeFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a meeting date and time first.'**
  String get chooseMeetingTimeFirst;

  /// No description provided for @acceptMeeting.
  ///
  /// In en, this message translates to:
  /// **'Accept meeting'**
  String get acceptMeeting;

  /// No description provided for @declineMeeting.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineMeeting;

  /// No description provided for @setNewMeetingTime.
  ///
  /// In en, this message translates to:
  /// **'Set new meeting time'**
  String get setNewMeetingTime;

  /// No description provided for @studentAskedReschedule.
  ///
  /// In en, this message translates to:
  /// **'Student asked to reschedule. Pick a new time.'**
  String get studentAskedReschedule;

  /// No description provided for @requestReschedule.
  ///
  /// In en, this message translates to:
  /// **'Request reschedule'**
  String get requestReschedule;

  /// No description provided for @requestRescheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Need a different time? Ask your teacher to reschedule.'**
  String get requestRescheduleHint;

  /// No description provided for @rescheduleNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Why do you need a new time? (optional)'**
  String get rescheduleNoteOptional;

  /// No description provided for @rescheduleNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Reschedule note'**
  String get rescheduleNoteLabel;

  /// No description provided for @rescheduleRequestedToast.
  ///
  /// In en, this message translates to:
  /// **'Reschedule request sent to your teacher.'**
  String get rescheduleRequestedToast;

  /// No description provided for @meetingRescheduledToast.
  ///
  /// In en, this message translates to:
  /// **'New meeting time saved.'**
  String get meetingRescheduledToast;

  /// No description provided for @markMeetingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as completed'**
  String get markMeetingCompleted;

  /// No description provided for @meetingCompleteAfterSchedule.
  ///
  /// In en, this message translates to:
  /// **'You can mark complete only after the scheduled time.'**
  String get meetingCompleteAfterSchedule;

  /// No description provided for @meetingCompleteAfterScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'Complete unlocks after {time}.'**
  String meetingCompleteAfterScheduleHint(String time);

  /// No description provided for @pendingMeetingRequests.
  ///
  /// In en, this message translates to:
  /// **'{count} pending meeting requests'**
  String pendingMeetingRequests(int count);

  /// No description provided for @meetingAcceptedToast.
  ///
  /// In en, this message translates to:
  /// **'Meeting accepted.'**
  String get meetingAcceptedToast;

  /// No description provided for @meetingDeclinedToast.
  ///
  /// In en, this message translates to:
  /// **'Meeting declined.'**
  String get meetingDeclinedToast;

  /// No description provided for @meetingCompletedToast.
  ///
  /// In en, this message translates to:
  /// **'Meeting marked complete.'**
  String get meetingCompletedToast;

  /// No description provided for @meetingUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the meeting. Try again.'**
  String get meetingUpdateFailed;

  /// No description provided for @openMeetings.
  ///
  /// In en, this message translates to:
  /// **'Open meetings'**
  String get openMeetings;

  /// No description provided for @meetingsPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String meetingsPendingCount(int count);

  /// No description provided for @courseLabel.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get courseLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settingsSoon.
  ///
  /// In en, this message translates to:
  /// **'Settings will be added next.'**
  String get settingsSoon;

  /// No description provided for @changeTeacher.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeTeacher;

  /// No description provided for @timerLabel.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerLabel;

  /// No description provided for @teacherHomeHint.
  ///
  /// In en, this message translates to:
  /// **'Add courses, then start the topic you are teaching.'**
  String get teacherHomeHint;

  /// No description provided for @studentHomeHint.
  ///
  /// In en, this message translates to:
  /// **'Join using your teacher\'s email. There is no teacher search — that email unlocks their courses.'**
  String get studentHomeHint;

  /// No description provided for @addCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Course'**
  String get addCourseTitle;

  /// No description provided for @addCourseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the course details. You can start topics after saving.'**
  String get addCourseSubtitle;

  /// No description provided for @saveCourse.
  ///
  /// In en, this message translates to:
  /// **'Save Course'**
  String get saveCourse;

  /// No description provided for @editCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get editCourse;

  /// No description provided for @editCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Course'**
  String get editCourseTitle;

  /// No description provided for @editCourseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the course details. The course ID cannot be changed.'**
  String get editCourseSubtitle;

  /// No description provided for @saveCourseChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveCourseChanges;

  /// No description provided for @courseAdded.
  ///
  /// In en, this message translates to:
  /// **'Course saved.'**
  String get courseAdded;

  /// No description provided for @courseUpdated.
  ///
  /// In en, this message translates to:
  /// **'Course updated.'**
  String get courseUpdated;

  /// No description provided for @sectionBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get sectionBasic;

  /// No description provided for @sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get sectionSchedule;

  /// No description provided for @sectionAcademic.
  ///
  /// In en, this message translates to:
  /// **'Academic details'**
  String get sectionAcademic;

  /// No description provided for @courseCode.
  ///
  /// In en, this message translates to:
  /// **'Course ID'**
  String get courseCode;

  /// No description provided for @courseCodeTaken.
  ///
  /// In en, this message translates to:
  /// **'This course ID is already added. Use a different ID.'**
  String get courseCodeTaken;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @creditHours.
  ///
  /// In en, this message translates to:
  /// **'Credit hours'**
  String get creditHours;

  /// No description provided for @phoneOtpDesktopUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Phone verification is available in the mobile app. On Windows, use email sign-up or email password reset. Existing accounts can still sign in with phone and password.'**
  String get phoneOtpDesktopUnavailable;

  /// No description provided for @fileDownloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started: {name}'**
  String fileDownloadStarted(String name);

  /// No description provided for @creditHoursValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 credit hour} other{{count} credit hours}}'**
  String creditHoursValue(int count);

  /// No description provided for @creditHoursInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter credit hours between 1 and 5.'**
  String get creditHoursInvalid;

  /// No description provided for @lectureHall.
  ///
  /// In en, this message translates to:
  /// **'Lecture hall'**
  String get lectureHall;

  /// No description provided for @lectureDays.
  ///
  /// In en, this message translates to:
  /// **'Lecture days'**
  String get lectureDays;

  /// No description provided for @selectLectureDay.
  ///
  /// In en, this message translates to:
  /// **'Select at least one lecture day.'**
  String get selectLectureDay;

  /// No description provided for @lectureTime.
  ///
  /// In en, this message translates to:
  /// **'Lecture time'**
  String get lectureTime;

  /// No description provided for @lectureDaysAndTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture Days & Time'**
  String get lectureDaysAndTimeTitle;

  /// No description provided for @lectureDaysAndTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Select days and set From / To for each slot'**
  String get lectureDaysAndTimeHint;

  /// No description provided for @selectLectureDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Lecture Days'**
  String get selectLectureDaysLabel;

  /// No description provided for @selectMultipleDaysTip.
  ///
  /// In en, this message translates to:
  /// **'You can select multiple days'**
  String get selectMultipleDaysTip;

  /// No description provided for @lectureTimeSlotsLabel.
  ///
  /// In en, this message translates to:
  /// **'Lecture Time Slots'**
  String get lectureTimeSlotsLabel;

  /// No description provided for @addAnotherTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Add Another Time Slot'**
  String get addAnotherTimeSlot;

  /// No description provided for @timeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get timeFrom;

  /// No description provided for @timeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get timeTo;

  /// No description provided for @registrationDate.
  ///
  /// In en, this message translates to:
  /// **'Registration date'**
  String get registrationDate;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @courseOutlines.
  ///
  /// In en, this message translates to:
  /// **'Course outlines'**
  String get courseOutlines;

  /// No description provided for @semester.
  ///
  /// In en, this message translates to:
  /// **'Semester'**
  String get semester;

  /// No description provided for @section.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get section;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @openMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get openMenu;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred app theme'**
  String get themeHint;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkOption.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkOption;

  /// No description provided for @languageHint.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get languageHint;

  /// No description provided for @deleteAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account and all data'**
  String get deleteAccountHint;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get goBack;

  /// No description provided for @findYourTeacher.
  ///
  /// In en, this message translates to:
  /// **'Find Your Teacher'**
  String get findYourTeacher;

  /// No description provided for @searchTeacherHint.
  ///
  /// In en, this message translates to:
  /// **'Search by teacher email...'**
  String get searchTeacherHint;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @keepLearningAhead.
  ///
  /// In en, this message translates to:
  /// **'Keep learning and stay ahead.'**
  String get keepLearningAhead;

  /// No description provided for @keepTeachingAhead.
  ///
  /// In en, this message translates to:
  /// **'Add courses and stay in sync with your class.'**
  String get keepTeachingAhead;

  /// No description provided for @searchCoursesHint.
  ///
  /// In en, this message translates to:
  /// **'Search your courses...'**
  String get searchCoursesHint;

  /// No description provided for @notificationsSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications will open here next.'**
  String get notificationsSoon;

  /// No description provided for @filtersSoon.
  ///
  /// In en, this message translates to:
  /// **'Filters will be added next.'**
  String get filtersSoon;

  /// No description provided for @courseDetails.
  ///
  /// In en, this message translates to:
  /// **'Course details'**
  String get courseDetails;

  /// No description provided for @uploadSyllabus.
  ///
  /// In en, this message translates to:
  /// **'Upload syllabus'**
  String get uploadSyllabus;

  /// No description provided for @editCourseDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit course details'**
  String get editCourseDetails;

  /// No description provided for @syllabusFiles.
  ///
  /// In en, this message translates to:
  /// **'Syllabus'**
  String get syllabusFiles;

  /// No description provided for @syllabusUploaded.
  ///
  /// In en, this message translates to:
  /// **'Syllabus uploaded.'**
  String get syllabusUploaded;

  /// No description provided for @courseInformation.
  ///
  /// In en, this message translates to:
  /// **'Course Information'**
  String get courseInformation;

  /// No description provided for @classSchedule.
  ///
  /// In en, this message translates to:
  /// **'Class Schedule'**
  String get classSchedule;

  /// No description provided for @deleteCourseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone.'**
  String deleteCourseConfirm(String name);

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabSyllabus.
  ///
  /// In en, this message translates to:
  /// **'Syllabus'**
  String get tabSyllabus;

  /// No description provided for @tabLectures.
  ///
  /// In en, this message translates to:
  /// **'Lectures'**
  String get tabLectures;

  /// No description provided for @tabAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get tabAssignments;

  /// No description provided for @tabResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get tabResources;

  /// No description provided for @courseInfo.
  ///
  /// In en, this message translates to:
  /// **'Course info'**
  String get courseInfo;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @writeAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Write an announcement...'**
  String get writeAnnouncement;

  /// No description provided for @postAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postAnnouncement;

  /// No description provided for @noAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet.'**
  String get noAnnouncements;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @courseOutline.
  ///
  /// In en, this message translates to:
  /// **'Course Outline'**
  String get courseOutline;

  /// No description provided for @addWeek.
  ///
  /// In en, this message translates to:
  /// **'+ Add Week'**
  String get addWeek;

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'W{number}'**
  String weekNumber(int number);

  /// No description provided for @weekTitle.
  ///
  /// In en, this message translates to:
  /// **'Week title'**
  String get weekTitle;

  /// No description provided for @weekReadings.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get weekReadings;

  /// No description provided for @weekNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get weekNotes;

  /// No description provided for @emptyWeeks.
  ///
  /// In en, this message translates to:
  /// **'No weeks yet. Add the first week of the outline.'**
  String get emptyWeeks;

  /// No description provided for @addLecture.
  ///
  /// In en, this message translates to:
  /// **'+ Add Lecture'**
  String get addLecture;

  /// No description provided for @lectureTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture title'**
  String get lectureTitle;

  /// No description provided for @lectureDate.
  ///
  /// In en, this message translates to:
  /// **'Lecture date'**
  String get lectureDate;

  /// No description provided for @lectureDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get lectureDescription;

  /// No description provided for @lectureAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment name (optional)'**
  String get lectureAttachment;

  /// No description provided for @lectureFileHint.
  ///
  /// In en, this message translates to:
  /// **'Upload one or more PDF, Word, or PowerPoint files'**
  String get lectureFileHint;

  /// No description provided for @assignmentFileHint.
  ///
  /// In en, this message translates to:
  /// **'Upload one or more PDF or Word files'**
  String get assignmentFileHint;

  /// No description provided for @resourceFileHint.
  ///
  /// In en, this message translates to:
  /// **'Upload one or more PDF or Word files'**
  String get resourceFileHint;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get addFiles;

  /// No description provided for @uploadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploadingFiles;

  /// No description provided for @removeFile.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFile;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add another link'**
  String get addLink;

  /// No description provided for @resourceLink.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get resourceLink;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File must be smaller than 20 MB.'**
  String get fileTooLarge;

  /// No description provided for @fileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file. Try another one.'**
  String get fileUnreadable;

  /// No description provided for @fileUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload the file. Try again.'**
  String get fileUploadFailed;

  /// No description provided for @storageDenied.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file. Sign in as the course teacher and try again.'**
  String get storageDenied;

  /// No description provided for @emptyLectures.
  ///
  /// In en, this message translates to:
  /// **'No lectures yet. Add the first lecture.'**
  String get emptyLectures;

  /// No description provided for @addAssignment.
  ///
  /// In en, this message translates to:
  /// **'+ Add Assignment'**
  String get addAssignment;

  /// No description provided for @assignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Assignment title'**
  String get assignmentTitle;

  /// No description provided for @assignmentDue.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get assignmentDue;

  /// No description provided for @assignmentPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get assignmentPoints;

  /// No description provided for @assignmentDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get assignmentDescription;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @emptyAssignments.
  ///
  /// In en, this message translates to:
  /// **'No assignments yet. Add the first assignment.'**
  String get emptyAssignments;

  /// No description provided for @addResource.
  ///
  /// In en, this message translates to:
  /// **'+ Add Resource'**
  String get addResource;

  /// No description provided for @resourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource title'**
  String get resourceTitle;

  /// No description provided for @resourceType.
  ///
  /// In en, this message translates to:
  /// **'Type (Textbook, Document, Link…)'**
  String get resourceType;

  /// No description provided for @resourceDetail.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get resourceDetail;

  /// No description provided for @emptyResources.
  ///
  /// In en, this message translates to:
  /// **'No resources yet. Add the first resource.'**
  String get emptyResources;

  /// No description provided for @itemAdded.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get itemAdded;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editItem;

  /// No description provided for @viewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week details'**
  String get viewWeek;

  /// No description provided for @editWeek.
  ///
  /// In en, this message translates to:
  /// **'Edit week'**
  String get editWeek;

  /// No description provided for @viewLecture.
  ///
  /// In en, this message translates to:
  /// **'Lecture details'**
  String get viewLecture;

  /// No description provided for @editLecture.
  ///
  /// In en, this message translates to:
  /// **'Edit lecture'**
  String get editLecture;

  /// No description provided for @viewAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment details'**
  String get viewAssignment;

  /// No description provided for @editAssignment.
  ///
  /// In en, this message translates to:
  /// **'Edit assignment'**
  String get editAssignment;

  /// No description provided for @viewResource.
  ///
  /// In en, this message translates to:
  /// **'Resource details'**
  String get viewResource;

  /// No description provided for @editResource.
  ///
  /// In en, this message translates to:
  /// **'Edit resource'**
  String get editResource;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Student bottom nav / sidebar: joined courses
  ///
  /// In en, this message translates to:
  /// **'Joined Courses'**
  String get navJoinedCourses;

  /// Empty state when student has no joined courses
  ///
  /// In en, this message translates to:
  /// **'You have not joined any courses yet.'**
  String get noJoinedCoursesYet;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettings;

  /// Label/hint for the phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'Share a brief introduction about yourself...'**
  String get bioHint;

  /// No description provided for @officeTiming.
  ///
  /// In en, this message translates to:
  /// **'Office Timing'**
  String get officeTiming;

  /// No description provided for @academicInformation.
  ///
  /// In en, this message translates to:
  /// **'Academic Information'**
  String get academicInformation;

  /// No description provided for @aboutMe.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutMe;

  /// No description provided for @university.
  ///
  /// In en, this message translates to:
  /// **'University'**
  String get university;

  /// No description provided for @enrollmentYear.
  ///
  /// In en, this message translates to:
  /// **'Enrollment Year'**
  String get enrollmentYear;

  /// No description provided for @officeNumber.
  ///
  /// In en, this message translates to:
  /// **'Office Number'**
  String get officeNumber;

  /// No description provided for @officeInformation.
  ///
  /// In en, this message translates to:
  /// **'Office Information'**
  String get officeInformation;

  /// No description provided for @activeStatus.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeStatus;

  /// No description provided for @phoneShort.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneShort;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Try again.'**
  String get profileSaveFailed;

  /// No description provided for @profilePhotoHint.
  ///
  /// In en, this message translates to:
  /// **'JPG, JPEG, or PNG only'**
  String get profilePhotoHint;

  /// No description provided for @profilePhotoInvalidType.
  ///
  /// In en, this message translates to:
  /// **'Only JPG, JPEG, and PNG images are allowed.'**
  String get profilePhotoInvalidType;

  /// No description provided for @profilePhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large. Choose a smaller JPG or PNG.'**
  String get profilePhotoTooLarge;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and all of your courses and data. This action is irreversible.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and all of your data? This cannot be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @chaptersAndTopics.
  ///
  /// In en, this message translates to:
  /// **'Chapters & Topics'**
  String get chaptersAndTopics;

  /// No description provided for @manageCourseContent.
  ///
  /// In en, this message translates to:
  /// **'Organize what you will teach in this course.'**
  String get manageCourseContent;

  /// No description provided for @viewCourseContent.
  ///
  /// In en, this message translates to:
  /// **'Explore the chapters and topics in this course.'**
  String get viewCourseContent;

  /// No description provided for @addChapter.
  ///
  /// In en, this message translates to:
  /// **'Add chapter'**
  String get addChapter;

  /// No description provided for @editChapter.
  ///
  /// In en, this message translates to:
  /// **'Edit chapter'**
  String get editChapter;

  /// No description provided for @deleteChapter.
  ///
  /// In en, this message translates to:
  /// **'Delete chapter'**
  String get deleteChapter;

  /// No description provided for @deleteChapterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this chapter and all of its topics?'**
  String get deleteChapterConfirm;

  /// No description provided for @chapterNumber.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterNumber(int number);

  /// No description provided for @chapterTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter title'**
  String get chapterTitle;

  /// No description provided for @chapterDescription.
  ///
  /// In en, this message translates to:
  /// **'Short chapter description'**
  String get chapterDescription;

  /// No description provided for @noChapters.
  ///
  /// In en, this message translates to:
  /// **'No chapters yet.'**
  String get noChapters;

  /// No description provided for @noChaptersTeacherHint.
  ///
  /// In en, this message translates to:
  /// **'Add the first chapter to start organizing this course.'**
  String get noChaptersTeacherHint;

  /// No description provided for @noChaptersStudentHint.
  ///
  /// In en, this message translates to:
  /// **'Your teacher has not added any chapters yet.'**
  String get noChaptersStudentHint;

  /// No description provided for @addTopic.
  ///
  /// In en, this message translates to:
  /// **'Add topic'**
  String get addTopic;

  /// No description provided for @changeTopic.
  ///
  /// In en, this message translates to:
  /// **'Change topic'**
  String get changeTopic;

  /// No description provided for @continueLectureHint.
  ///
  /// In en, this message translates to:
  /// **'Select a previous topic or add a new one to continue this lecture.'**
  String get continueLectureHint;

  /// No description provided for @lectureTopicSwitched.
  ///
  /// In en, this message translates to:
  /// **'Now teaching: {topic}'**
  String lectureTopicSwitched(String topic);

  /// No description provided for @editTopic.
  ///
  /// In en, this message translates to:
  /// **'Edit topic'**
  String get editTopic;

  /// No description provided for @deleteTopic.
  ///
  /// In en, this message translates to:
  /// **'Delete topic'**
  String get deleteTopic;

  /// No description provided for @deleteTopicConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this topic?'**
  String get deleteTopicConfirm;

  /// No description provided for @topicTitle.
  ///
  /// In en, this message translates to:
  /// **'Topic title'**
  String get topicTitle;

  /// No description provided for @topicDescription.
  ///
  /// In en, this message translates to:
  /// **'Short topic description'**
  String get topicDescription;

  /// No description provided for @noTopics.
  ///
  /// In en, this message translates to:
  /// **'No topics in this chapter yet.'**
  String get noTopics;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @contentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the course content. Try again.'**
  String get contentSaveFailed;

  /// No description provided for @startLecture.
  ///
  /// In en, this message translates to:
  /// **'Start Lecture'**
  String get startLecture;

  /// No description provided for @joinLecture.
  ///
  /// In en, this message translates to:
  /// **'Join Lecture'**
  String get joinLecture;

  /// No description provided for @joinLectureConfirm.
  ///
  /// In en, this message translates to:
  /// **'Join the live lecture for {course}?\n\n{topic}\n\nFocus mode will try to keep you in LEARNsync until the teacher ends the lecture. Other apps, calls, and notifications cannot be fully blocked on a normal phone.'**
  String joinLectureConfirm(String course, String topic);

  /// No description provided for @endLecture.
  ///
  /// In en, this message translates to:
  /// **'End Lecture'**
  String get endLecture;

  /// No description provided for @endLectureConfirm.
  ///
  /// In en, this message translates to:
  /// **'End this live lecture for all students?'**
  String get endLectureConfirm;

  /// No description provided for @selectChapter.
  ///
  /// In en, this message translates to:
  /// **'Select chapter'**
  String get selectChapter;

  /// No description provided for @selectTopic.
  ///
  /// In en, this message translates to:
  /// **'Select topic'**
  String get selectTopic;

  /// No description provided for @lectureDuration.
  ///
  /// In en, this message translates to:
  /// **'Lecture duration'**
  String get lectureDuration;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String durationMinutes(int count);

  /// No description provided for @noTopicsToStart.
  ///
  /// In en, this message translates to:
  /// **'Add at least one chapter and topic before starting a lecture.'**
  String get noTopicsToStart;

  /// No description provided for @lectureLiveNow.
  ///
  /// In en, this message translates to:
  /// **'A lecture is live now'**
  String get lectureLiveNow;

  /// No description provided for @liveLectures.
  ///
  /// In en, this message translates to:
  /// **'Live Lectures'**
  String get liveLectures;

  /// No description provided for @chooseLiveLecture.
  ///
  /// In en, this message translates to:
  /// **'Choose a live lecture to join'**
  String get chooseLiveLecture;

  /// No description provided for @timeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get timeRemaining;

  /// No description provided for @lectureEnded.
  ///
  /// In en, this message translates to:
  /// **'This lecture has ended.'**
  String get lectureEnded;

  /// No description provided for @liveSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the lecture. Check that another lecture is not already active.'**
  String get liveSessionStartFailed;

  /// No description provided for @teacherAlreadyLive.
  ///
  /// In en, this message translates to:
  /// **'You already have a live lecture. End it before starting another.'**
  String get teacherAlreadyLive;

  /// No description provided for @requestToJoin.
  ///
  /// In en, this message translates to:
  /// **'Request to Join'**
  String get requestToJoin;

  /// No description provided for @joinRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for teacher approval'**
  String get joinRequestPending;

  /// No description provided for @enterLecture.
  ///
  /// In en, this message translates to:
  /// **'Enter Lecture'**
  String get enterLecture;

  /// No description provided for @joinRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Join request sent to the teacher.'**
  String get joinRequestSent;

  /// No description provided for @joinRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send join request. Try again.'**
  String get joinRequestFailed;

  /// No description provided for @joinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get joinRequests;

  /// No description provided for @acceptJoin.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptJoin;

  /// No description provided for @joinAll.
  ///
  /// In en, this message translates to:
  /// **'Join All'**
  String get joinAll;

  /// No description provided for @noJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending join requests.'**
  String get noJoinRequests;

  /// No description provided for @acceptJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not accept the join request.'**
  String get acceptJoinFailed;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your feedback was saved.'**
  String get feedbackSubmitted;

  /// No description provided for @feedbackSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save feedback. Try again.'**
  String get feedbackSubmitFailed;

  /// No description provided for @lectureFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture Feedback'**
  String get lectureFeedbackTitle;

  /// No description provided for @endedBadge.
  ///
  /// In en, this message translates to:
  /// **'ENDED'**
  String get endedBadge;

  /// No description provided for @feedbackCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Share comments or suggestions (optional)'**
  String get feedbackCommentHint;

  /// No description provided for @submitFeedbackCta.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT FEEDBACK'**
  String get submitFeedbackCta;

  /// No description provided for @selectUnderstandingFirst.
  ///
  /// In en, this message translates to:
  /// **'Select how well you understood this topic.'**
  String get selectUnderstandingFirst;

  /// No description provided for @feedbackSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback Submitted!'**
  String get feedbackSubmittedTitle;

  /// No description provided for @lectureEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture End'**
  String get lectureEndTitle;

  /// No description provided for @lectureEndSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do next?'**
  String get lectureEndSubtitle;

  /// No description provided for @feedbackNextPrompt.
  ///
  /// In en, this message translates to:
  /// **'Since you selected \'{level}\', what would you like to do next?'**
  String feedbackNextPrompt(String level);

  /// No description provided for @practiceWithAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice with AI Assistant'**
  String get practiceWithAiTitle;

  /// No description provided for @practiceWithAiHint.
  ///
  /// In en, this message translates to:
  /// **'Quiz yourself on {topic} concepts now.'**
  String practiceWithAiHint(String topic);

  /// No description provided for @scheduleMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule Meeting with Teacher'**
  String get scheduleMeetingTitle;

  /// No description provided for @scheduleMeetingHint.
  ///
  /// In en, this message translates to:
  /// **'Schedule a quick 1-on-1 virtual session with {teacher}.'**
  String scheduleMeetingHint(String teacher);

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// No description provided for @teacherFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See how students understood this lecture.'**
  String get teacherFeedbackSubtitle;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatus;

  /// No description provided for @studentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get studentsLabel;

  /// No description provided for @responsesOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Responses: {received}/{total}'**
  String responsesOfTotal(int received, int total);

  /// No description provided for @practiceRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Practice Rate: {percent}%'**
  String practiceRateLabel(int percent);

  /// No description provided for @totalRequestsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Total Requests'**
  String totalRequestsLabel(int count);

  /// No description provided for @thisCourseRequests.
  ///
  /// In en, this message translates to:
  /// **'This Course: {count}'**
  String thisCourseRequests(int count);

  /// No description provided for @understandingBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Understanding Breakdown'**
  String get understandingBreakdown;

  /// No description provided for @studentResponsesCount.
  ///
  /// In en, this message translates to:
  /// **'Student Responses ({count})'**
  String studentResponsesCount(int count);

  /// No description provided for @understoodPerfectly.
  ///
  /// In en, this message translates to:
  /// **'Understood perfectly'**
  String get understoodPerfectly;

  /// No description provided for @understoodMost.
  ///
  /// In en, this message translates to:
  /// **'Understood most'**
  String get understoodMost;

  /// No description provided for @understoodSome.
  ///
  /// In en, this message translates to:
  /// **'Understood some'**
  String get understoodSome;

  /// No description provided for @needMoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Need more help'**
  String get needMoreHelp;

  /// No description provided for @practicedBadge.
  ///
  /// In en, this message translates to:
  /// **'Practiced'**
  String get practicedBadge;

  /// No description provided for @notPracticedBadge.
  ///
  /// In en, this message translates to:
  /// **'Not Practiced'**
  String get notPracticedBadge;

  /// No description provided for @meetingShort.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingShort;

  /// No description provided for @yesLabel.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yesLabel;

  /// No description provided for @noLabel.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noLabel;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @needHelpInsight.
  ///
  /// In en, this message translates to:
  /// **'{count} students ({percent}%) need more help on this topic. Consider revising examples and practice.'**
  String needHelpInsight(int count, int percent);

  /// No description provided for @understandingSummary.
  ///
  /// In en, this message translates to:
  /// **'Understanding feedback'**
  String get understandingSummary;

  /// No description provided for @feedbackCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} responses'**
  String feedbackCountLabel(int count);

  /// No description provided for @noFeedbackYet.
  ///
  /// In en, this message translates to:
  /// **'No student feedback yet.'**
  String get noFeedbackYet;

  /// No description provided for @changeFeedback.
  ///
  /// In en, this message translates to:
  /// **'Change feedback'**
  String get changeFeedback;

  /// No description provided for @liveSessionEndFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not end the lecture. Try again.'**
  String get liveSessionEndFailed;

  /// No description provided for @liveTopic.
  ///
  /// In en, this message translates to:
  /// **'Live: {topic}'**
  String liveTopic(String topic);

  /// No description provided for @liveNow.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveNow;

  /// No description provided for @lectureComplete.
  ///
  /// In en, this message translates to:
  /// **'ENDED'**
  String get lectureComplete;

  /// No description provided for @plannedDuration.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get plannedDuration;

  /// No description provided for @sessionDetails.
  ///
  /// In en, this message translates to:
  /// **'Session details'**
  String get sessionDetails;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @studentsPresent.
  ///
  /// In en, this message translates to:
  /// **'{count} Present'**
  String studentsPresent(int count);

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @attendeesCount.
  ///
  /// In en, this message translates to:
  /// **'Attendees ({count})'**
  String attendeesCount(int count);

  /// No description provided for @noStudentsYet.
  ///
  /// In en, this message translates to:
  /// **'No students have joined yet.'**
  String get noStudentsYet;

  /// No description provided for @youAreInClass.
  ///
  /// In en, this message translates to:
  /// **'You are in this lecture'**
  String get youAreInClass;

  /// No description provided for @waitingForStudents.
  ///
  /// In en, this message translates to:
  /// **'Waiting for students to join'**
  String get waitingForStudents;

  /// No description provided for @teachingLiveHint.
  ///
  /// In en, this message translates to:
  /// **'You are currently teaching live'**
  String get teachingLiveHint;

  /// No description provided for @attendingLiveHint.
  ///
  /// In en, this message translates to:
  /// **'You are currently attending live'**
  String get attendingLiveHint;

  /// No description provided for @lectureInformation.
  ///
  /// In en, this message translates to:
  /// **'Lecture Information'**
  String get lectureInformation;

  /// No description provided for @currentTopic.
  ///
  /// In en, this message translates to:
  /// **'Current Topic'**
  String get currentTopic;

  /// No description provided for @estimatedEnd.
  ///
  /// In en, this message translates to:
  /// **'Estimated End'**
  String get estimatedEnd;

  /// No description provided for @topicLiveHint.
  ///
  /// In en, this message translates to:
  /// **'This topic is live and visible to all enrolled students.'**
  String get topicLiveHint;

  /// No description provided for @joinedAt.
  ///
  /// In en, this message translates to:
  /// **'Joined at {time}'**
  String joinedAt(String time);

  /// No description provided for @scheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleLabel;

  /// No description provided for @totalStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get totalStudents;

  /// No description provided for @creditsShort.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get creditsShort;

  /// No description provided for @liveChatSoon.
  ///
  /// In en, this message translates to:
  /// **'Live chat will open from here next.'**
  String get liveChatSoon;

  /// No description provided for @livePollSoon.
  ///
  /// In en, this message translates to:
  /// **'Live polls will open from here next.'**
  String get livePollSoon;

  /// No description provided for @liveChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get liveChat;

  /// No description provided for @livePoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get livePoll;

  /// No description provided for @pointsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String pointsLabel(int count);

  /// No description provided for @lectureSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture Summary'**
  String get lectureSummaryTitle;

  /// No description provided for @lectureSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review this lecture before viewing student feedback.'**
  String get lectureSummarySubtitle;

  /// No description provided for @viewStudentFeedback.
  ///
  /// In en, this message translates to:
  /// **'View student feedback'**
  String get viewStudentFeedback;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// No description provided for @actualDuration.
  ///
  /// In en, this message translates to:
  /// **'Actual duration'**
  String get actualDuration;

  /// No description provided for @lectureSummarySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the lecture summary. Try again.'**
  String get lectureSummarySaveFailed;

  /// No description provided for @taughtNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'What did you teach today?'**
  String get taughtNotesLabel;

  /// No description provided for @taughtNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note about what you covered in this lecture.'**
  String get taughtNotesHint;

  /// No description provided for @taughtNotesRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter what you taught today.'**
  String get taughtNotesRequired;

  /// No description provided for @backToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get backToDashboard;

  /// No description provided for @aiPracticeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice with AI'**
  String get aiPracticeScreenTitle;

  /// No description provided for @aiQuizResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Quiz Results'**
  String get aiQuizResultsTitle;

  /// No description provided for @inProgressStatus.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get inProgressStatus;

  /// No description provided for @completedBadgeCaps.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedBadgeCaps;

  /// No description provided for @topicPrefix.
  ///
  /// In en, this message translates to:
  /// **'Topic: {topic}'**
  String topicPrefix(String topic);

  /// No description provided for @aiPracticeAnswerAll.
  ///
  /// In en, this message translates to:
  /// **'Please answer all 5 questions below before submitting.'**
  String get aiPracticeAnswerAll;

  /// No description provided for @questionOfTotal.
  ///
  /// In en, this message translates to:
  /// **'QUESTION {current} OF {total}'**
  String questionOfTotal(int current, int total);

  /// No description provided for @submitQuiz.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT QUIZ'**
  String get submitQuiz;

  /// No description provided for @quizCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz Completed!'**
  String get quizCompletedTitle;

  /// No description provided for @quizPassedMessage.
  ///
  /// In en, this message translates to:
  /// **'Great effort! You have passed this interactive review module successfully.'**
  String get quizPassedMessage;

  /// No description provided for @quizFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Review the explanations and try again to strengthen what you missed.'**
  String get quizFailedMessage;

  /// No description provided for @passedBadge.
  ///
  /// In en, this message translates to:
  /// **'PASSED'**
  String get passedBadge;

  /// No description provided for @needsReviewBadge.
  ///
  /// In en, this message translates to:
  /// **'NEEDS REVIEW'**
  String get needsReviewBadge;

  /// No description provided for @totalQuestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL QUESTIONS'**
  String get totalQuestionsLabel;

  /// No description provided for @correctAnswersLabel.
  ///
  /// In en, this message translates to:
  /// **'CORRECT ANSWERS'**
  String get correctAnswersLabel;

  /// No description provided for @wrongAnswersLabel.
  ///
  /// In en, this message translates to:
  /// **'WRONG ANSWERS'**
  String get wrongAnswersLabel;

  /// No description provided for @aiTutorBadge.
  ///
  /// In en, this message translates to:
  /// **'AI TUTOR'**
  String get aiTutorBadge;

  /// No description provided for @diagnosticTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Evaluation & Guidance'**
  String get diagnosticTitle;

  /// No description provided for @reviewExplanations.
  ///
  /// In en, this message translates to:
  /// **'Review Question Explanations'**
  String get reviewExplanations;

  /// No description provided for @practiceAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice Again'**
  String get practiceAgain;

  /// No description provided for @endPractice.
  ///
  /// In en, this message translates to:
  /// **'End Practice'**
  String get endPractice;

  /// No description provided for @resultsSecureHint.
  ///
  /// In en, this message translates to:
  /// **'Your performance has been evaluated and committed securely.'**
  String get resultsSecureHint;

  /// No description provided for @aiPracticeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'AI practice runs on the mobile app. This browser cannot load the on-device Qwen 2.5 0.5B model.'**
  String get aiPracticeUnsupported;

  /// No description provided for @aiPracticeNoNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture notes needed'**
  String get aiPracticeNoNotesTitle;

  /// No description provided for @aiPracticeNoNotes.
  ///
  /// In en, this message translates to:
  /// **'Your teacher has not saved notes for what was taught today, so a practice quiz cannot be generated yet. Ask them to save lecture notes, then try again.'**
  String get aiPracticeNoNotes;

  /// No description provided for @aiPracticeNoBelow50Title.
  ///
  /// In en, this message translates to:
  /// **'No slides below 50%'**
  String get aiPracticeNoBelow50Title;

  /// No description provided for @aiPracticeNoBelow50.
  ///
  /// In en, this message translates to:
  /// **'Practice questions come only from slides you marked below 50%. You have not marked any slide below 50% for this lecture, so there is no quiz yet.'**
  String get aiPracticeNoBelow50;

  /// No description provided for @aiPracticeSourceChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter: {chapter}'**
  String aiPracticeSourceChapter(String chapter);

  /// No description provided for @aiPracticeSourceLecture.
  ///
  /// In en, this message translates to:
  /// **'Lecture: {lecture}'**
  String aiPracticeSourceLecture(String lecture);

  /// No description provided for @aiPracticeSourceSlide.
  ///
  /// In en, this message translates to:
  /// **'Slide: {slide}'**
  String aiPracticeSourceSlide(String slide);

  /// No description provided for @aiPracticeSourceTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic: {topic}'**
  String aiPracticeSourceTopic(String topic);

  /// No description provided for @aiPracticeDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing on-device AI'**
  String get aiPracticeDownloadTitle;

  /// No description provided for @aiPracticeDownloadHint.
  ///
  /// In en, this message translates to:
  /// **'Downloading Qwen 2.5 0.5B for private, on-device practice. This happens once.'**
  String get aiPracticeDownloadHint;

  /// No description provided for @aiPracticeGenerating.
  ///
  /// In en, this message translates to:
  /// **'Writing 5 questions from today\'s lecture notes…'**
  String get aiPracticeGenerating;

  /// No description provided for @aiPracticeGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate a quiz. Try again.'**
  String get aiPracticeGenerateFailed;

  /// No description provided for @aiPracticeRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get aiPracticeRetry;

  /// No description provided for @aiPracticeSubmitIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Answer every question before submitting.'**
  String get aiPracticeSubmitIncomplete;

  /// No description provided for @aiPracticeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your practice attempt.'**
  String get aiPracticeSaveFailed;

  /// No description provided for @explanationCorrectLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get explanationCorrectLabel;

  /// No description provided for @explanationYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get explanationYourAnswer;

  /// No description provided for @optionLetter.
  ///
  /// In en, this message translates to:
  /// **'{letter}'**
  String optionLetter(Object letter);

  /// No description provided for @teacherAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Teacher Analytics'**
  String get teacherAnalytics;

  /// No description provided for @teacherAnalyticsHint.
  ///
  /// In en, this message translates to:
  /// **'See understanding, AI practice, and meetings.'**
  String get teacherAnalyticsHint;

  /// No description provided for @teacherAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spot hard topics and students who need support.'**
  String get teacherAnalyticsSubtitle;

  /// No description provided for @analyticsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get analyticsOverview;

  /// No description provided for @analyticsUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding'**
  String get analyticsUnderstanding;

  /// No description provided for @analyticsPractice.
  ///
  /// In en, this message translates to:
  /// **'AI practice'**
  String get analyticsPractice;

  /// No description provided for @analyticsMeetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get analyticsMeetings;

  /// No description provided for @analyticsAverage.
  ///
  /// In en, this message translates to:
  /// **'Average {value}%'**
  String analyticsAverage(int value);

  /// No description provided for @analyticsResponses.
  ///
  /// In en, this message translates to:
  /// **'{count} responses'**
  String analyticsResponses(int count);

  /// No description provided for @analyticsParticipation.
  ///
  /// In en, this message translates to:
  /// **'{percent}% participation'**
  String analyticsParticipation(int percent);

  /// No description provided for @analyticsCompletion.
  ///
  /// In en, this message translates to:
  /// **'{percent}% completion'**
  String analyticsCompletion(int percent);

  /// No description provided for @analyticsAverageScore.
  ///
  /// In en, this message translates to:
  /// **'Avg score {value}%'**
  String analyticsAverageScore(int value);

  /// No description provided for @analyticsMeetingTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} requests'**
  String analyticsMeetingTotal(int count);

  /// No description provided for @analyticsTopicOverview.
  ///
  /// In en, this message translates to:
  /// **'Topic Overview'**
  String get analyticsTopicOverview;

  /// No description provided for @analyticsCombinedLectures.
  ///
  /// In en, this message translates to:
  /// **'{count} lectures combined'**
  String analyticsCombinedLectures(int count);

  /// No description provided for @analyticsTotalStudents.
  ///
  /// In en, this message translates to:
  /// **'Total Students'**
  String get analyticsTotalStudents;

  /// No description provided for @analyticsTotalResponses.
  ///
  /// In en, this message translates to:
  /// **'Total Responses'**
  String get analyticsTotalResponses;

  /// No description provided for @analyticsAvgUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Avg. Understanding'**
  String get analyticsAvgUnderstanding;

  /// No description provided for @analyticsUnderstandingDistribution.
  ///
  /// In en, this message translates to:
  /// **'Understanding Level Distribution'**
  String get analyticsUnderstandingDistribution;

  /// No description provided for @analyticsStudentPerformance.
  ///
  /// In en, this message translates to:
  /// **'Student Performance & Details'**
  String get analyticsStudentPerformance;

  /// No description provided for @analyticsSearchStudent.
  ///
  /// In en, this message translates to:
  /// **'Search student...'**
  String get analyticsSearchStudent;

  /// No description provided for @analyticsOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On Track'**
  String get analyticsOnTrack;

  /// No description provided for @analyticsNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get analyticsNeedsAttention;

  /// No description provided for @analyticsMeetingYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get analyticsMeetingYes;

  /// No description provided for @analyticsMeetingNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get analyticsMeetingNo;

  /// No description provided for @analyticsSelectTopicHint.
  ///
  /// In en, this message translates to:
  /// **'Select a course, chapter, and topic to see combined analytics for every lecture on that topic.'**
  String get analyticsSelectTopicHint;

  /// No description provided for @analyticsByTopic.
  ///
  /// In en, this message translates to:
  /// **'Understanding by topic'**
  String get analyticsByTopic;

  /// No description provided for @analyticsBySession.
  ///
  /// In en, this message translates to:
  /// **'Understanding by session'**
  String get analyticsBySession;

  /// No description provided for @analyticsNeedsSupport.
  ///
  /// In en, this message translates to:
  /// **'Students needing support'**
  String get analyticsNeedsSupport;

  /// No description provided for @analyticsLowUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Low understanding'**
  String get analyticsLowUnderstanding;

  /// No description provided for @analyticsIncompletePractice.
  ///
  /// In en, this message translates to:
  /// **'Have not practiced'**
  String get analyticsIncompletePractice;

  /// No description provided for @analyticsPendingMeetings.
  ///
  /// In en, this message translates to:
  /// **'Pending meetings'**
  String get analyticsPendingMeetings;

  /// No description provided for @analyticsAllCourses.
  ///
  /// In en, this message translates to:
  /// **'All courses'**
  String get analyticsAllCourses;

  /// No description provided for @analyticsAllChapters.
  ///
  /// In en, this message translates to:
  /// **'All chapters'**
  String get analyticsAllChapters;

  /// No description provided for @analyticsAllTopics.
  ///
  /// In en, this message translates to:
  /// **'All topics'**
  String get analyticsAllTopics;

  /// No description provided for @analyticsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get analyticsAllTime;

  /// No description provided for @analyticsLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get analyticsLast7Days;

  /// No description provided for @analyticsLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get analyticsLast30Days;

  /// No description provided for @analyticsCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get analyticsCustomRange;

  /// No description provided for @analyticsFromDate.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get analyticsFromDate;

  /// No description provided for @analyticsToDate.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get analyticsToDate;

  /// No description provided for @analyticsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No analytics yet'**
  String get analyticsEmptyTitle;

  /// No description provided for @analyticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'After students submit feedback, practice, or request meetings, their results will appear here.'**
  String get analyticsEmpty;

  /// No description provided for @analyticsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load analytics. Try again.'**
  String get analyticsLoadFailed;

  /// No description provided for @analyticsPracticeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI practice stats are unavailable right now. Understanding and meetings are still shown.'**
  String get analyticsPracticeUnavailable;

  /// No description provided for @analyticsRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get analyticsRetry;

  /// No description provided for @analyticsNoBars.
  ///
  /// In en, this message translates to:
  /// **'No understanding data for this filter.'**
  String get analyticsNoBars;

  /// No description provided for @analyticsNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students in this list.'**
  String get analyticsNoStudents;

  /// No description provided for @analyticsResponsesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} responses · {value}%'**
  String analyticsResponsesShort(int count, int value);

  /// No description provided for @analyticsChapterFilter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get analyticsChapterFilter;

  /// No description provided for @analyticsTopicFilter.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get analyticsTopicFilter;

  /// No description provided for @dateRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRangeLabel;

  /// No description provided for @aiPracticesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ended lectures yet. After your teacher finishes a class with notes, practice will show up here.'**
  String get aiPracticesEmpty;

  /// No description provided for @aiPracticeColorLegendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Color meaning'**
  String get aiPracticeColorLegendTooltip;

  /// No description provided for @aiPracticeColorLegendTitle.
  ///
  /// In en, this message translates to:
  /// **'Color meaning'**
  String get aiPracticeColorLegendTitle;

  /// No description provided for @aiPracticeColorLegendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The colors show how many AI practices are used.'**
  String get aiPracticeColorLegendSubtitle;

  /// No description provided for @aiPracticeColorNone.
  ///
  /// In en, this message translates to:
  /// **'0 AI practice'**
  String get aiPracticeColorNone;

  /// No description provided for @aiPracticeColorFew.
  ///
  /// In en, this message translates to:
  /// **'1 or 2 AI practice'**
  String get aiPracticeColorFew;

  /// No description provided for @aiPracticeColorMany.
  ///
  /// In en, this message translates to:
  /// **'3+ AI practice'**
  String get aiPracticeColorMany;

  /// No description provided for @aiPracticeColorRed.
  ///
  /// In en, this message translates to:
  /// **'red'**
  String get aiPracticeColorRed;

  /// No description provided for @aiPracticeColorYellow.
  ///
  /// In en, this message translates to:
  /// **'yellow'**
  String get aiPracticeColorYellow;

  /// No description provided for @aiPracticeColorTeal.
  ///
  /// In en, this message translates to:
  /// **'teal'**
  String get aiPracticeColorTeal;

  /// No description provided for @lectureAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Lecture Analytics'**
  String get lectureAnalytics;

  /// No description provided for @lectureAnalyticsHint.
  ///
  /// In en, this message translates to:
  /// **'See how students engaged with each lecture.'**
  String get lectureAnalyticsHint;

  /// Remove action label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Course details link and enrolled list title
  ///
  /// In en, this message translates to:
  /// **'Enrolled Students'**
  String get enrolledStudents;

  /// Subtitle under Enrolled Students card
  ///
  /// In en, this message translates to:
  /// **'View and manage students enrolled in this course.'**
  String get enrolledStudentsHint;

  /// Count label above enrolled students list
  ///
  /// In en, this message translates to:
  /// **'{count} enrolled'**
  String enrolledStudentsCount(int count);

  /// Hint under student name on enrolled list
  ///
  /// In en, this message translates to:
  /// **'Tap to view profile'**
  String get tapToViewProfile;

  /// Empty enrolled students list
  ///
  /// In en, this message translates to:
  /// **'No students are enrolled in this course yet.'**
  String get noEnrolledStudentsYet;

  /// Dialog title for removing enrolled student
  ///
  /// In en, this message translates to:
  /// **'Remove student'**
  String get removeEnrolledStudent;

  /// Confirm removing an enrolled student
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this course? They will need to request to join again.'**
  String removeEnrolledStudentConfirm(String name);

  /// Error toast when remove fails
  ///
  /// In en, this message translates to:
  /// **'Could not remove the student. Try again.'**
  String get removeEnrolledStudentFailed;

  /// Success toast after removing student
  ///
  /// In en, this message translates to:
  /// **'{name} was removed from this course.'**
  String studentRemovedFromCourse(String name);

  /// No description provided for @lectureAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See how your students engaged with this lecture.'**
  String get lectureAnalyticsSubtitle;

  /// No description provided for @courseLecturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Lectures'**
  String get courseLecturesTitle;

  /// No description provided for @courseLecturesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lectures yet for this course. After you run a live lecture, it will appear here.'**
  String get courseLecturesEmpty;

  /// No description provided for @lectureAnalyticsNote.
  ///
  /// In en, this message translates to:
  /// **'After the lecture ends you can see how many students understood the topic, completed AI practice, and requested a meeting.'**
  String get lectureAnalyticsNote;

  /// No description provided for @backToLectures.
  ///
  /// In en, this message translates to:
  /// **'Back to Lectures'**
  String get backToLectures;

  /// No description provided for @viewAllRequests.
  ///
  /// In en, this message translates to:
  /// **'View All Requests'**
  String get viewAllRequests;

  /// No description provided for @totalRequestsThisLecture.
  ///
  /// In en, this message translates to:
  /// **'{count} Total Requests This Lecture'**
  String totalRequestsThisLecture(int count);

  /// No description provided for @studentsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Students'**
  String studentsCountLabel(int count);

  /// No description provided for @understandingSection.
  ///
  /// In en, this message translates to:
  /// **'1. Understanding'**
  String get understandingSection;

  /// No description provided for @aiPracticeSection.
  ///
  /// In en, this message translates to:
  /// **'2. AI Practice'**
  String get aiPracticeSection;

  /// No description provided for @meetingsSection.
  ///
  /// In en, this message translates to:
  /// **'3. Meetings'**
  String get meetingsSection;

  /// No description provided for @lectureMeetingsHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture Meetings'**
  String get lectureMeetingsHubTitle;

  /// No description provided for @lectureMeetingsHubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests for this lecture only.'**
  String get lectureMeetingsHubSubtitle;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get pendingRequests;

  /// No description provided for @scheduledMeetings.
  ///
  /// In en, this message translates to:
  /// **'Scheduled meetings'**
  String get scheduledMeetings;

  /// No description provided for @attendedMeetings.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get attendedMeetings;

  /// No description provided for @noMeetingsForLecture.
  ///
  /// In en, this message translates to:
  /// **'No meeting requests for this lecture yet.'**
  String get noMeetingsForLecture;

  /// No description provided for @noPendingMeetingsForLecture.
  ///
  /// In en, this message translates to:
  /// **'No pending requests for this lecture.'**
  String get noPendingMeetingsForLecture;

  /// No description provided for @noScheduledMeetingsForLecture.
  ///
  /// In en, this message translates to:
  /// **'No scheduled meetings for this lecture.'**
  String get noScheduledMeetingsForLecture;

  /// No description provided for @noAttendedMeetingsForLecture.
  ///
  /// In en, this message translates to:
  /// **'No attended meetings for this lecture.'**
  String get noAttendedMeetingsForLecture;

  /// No description provided for @understandingDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding Details'**
  String get understandingDetailTitle;

  /// No description provided for @aiPracticeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Practice Details'**
  String get aiPracticeDetailTitle;

  /// No description provided for @understandingDetailHint.
  ///
  /// In en, this message translates to:
  /// **'See how each student understood this lecture'**
  String get understandingDetailHint;

  /// No description provided for @aiPracticeDetailHint.
  ///
  /// In en, this message translates to:
  /// **'See which students practiced this lecture'**
  String get aiPracticeDetailHint;

  /// No description provided for @noPracticeAttemptsYet.
  ///
  /// In en, this message translates to:
  /// **'No AI practice attempts for this lecture yet.'**
  String get noPracticeAttemptsYet;

  /// No description provided for @understandingOverview.
  ///
  /// In en, this message translates to:
  /// **'Understanding Overview'**
  String get understandingOverview;

  /// No description provided for @practiceOverview.
  ///
  /// In en, this message translates to:
  /// **'AI Practice Overview'**
  String get practiceOverview;

  /// No description provided for @meetingsOverview.
  ///
  /// In en, this message translates to:
  /// **'Meetings Overview'**
  String get meetingsOverview;

  /// No description provided for @totalResponsesLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Responses'**
  String get totalResponsesLabel;

  /// No description provided for @totalPracticeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Practice'**
  String get totalPracticeLabel;

  /// No description provided for @totalMeetingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Meetings'**
  String get totalMeetingsLabel;

  /// No description provided for @searchStudentHint.
  ///
  /// In en, this message translates to:
  /// **'Search student...'**
  String get searchStudentHint;

  /// No description provided for @noStudentsInLevel.
  ///
  /// In en, this message translates to:
  /// **'No students in this understanding level.'**
  String get noStudentsInLevel;

  /// No description provided for @noStudentsInPracticeGroup.
  ///
  /// In en, this message translates to:
  /// **'No students in this practice group.'**
  String get noStudentsInPracticeGroup;

  /// No description provided for @noMatchingStudents.
  ///
  /// In en, this message translates to:
  /// **'No students match your search.'**
  String get noMatchingStudents;

  /// No description provided for @noMeetingsInBucket.
  ///
  /// In en, this message translates to:
  /// **'No meetings in this category.'**
  String get noMeetingsInBucket;

  /// No description provided for @noMatchingMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings match your search.'**
  String get noMatchingMeetings;

  /// No description provided for @studentsHeadingCount.
  ///
  /// In en, this message translates to:
  /// **'Students ({count})'**
  String studentsHeadingCount(int count);

  /// No description provided for @meetingsHeadingCount.
  ///
  /// In en, this message translates to:
  /// **'Meetings ({count})'**
  String meetingsHeadingCount(int count);

  /// No description provided for @meetingsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Meetings'**
  String meetingsCountLabel(int count);

  /// No description provided for @meetingsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Meetings Details'**
  String get meetingsDetailTitle;

  /// No description provided for @meetingsDetailHint.
  ///
  /// In en, this message translates to:
  /// **'See meeting requests for this lecture'**
  String get meetingsDetailHint;

  /// No description provided for @meetingBucketPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get meetingBucketPending;

  /// No description provided for @meetingBucketScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get meetingBucketScheduled;

  /// No description provided for @meetingBucketAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get meetingBucketAttended;

  /// No description provided for @studentProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Student Profile'**
  String get studentProfileTitle;

  /// No description provided for @thisLectureUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding for this lecture'**
  String get thisLectureUnderstanding;

  /// No description provided for @teacherUnderstandingAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding Analytics'**
  String get teacherUnderstandingAnalyticsTitle;

  /// No description provided for @teacherPracticeAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Practice Analytics'**
  String get teacherPracticeAnalyticsTitle;

  /// No description provided for @teacherPracticeAnalyticsHint.
  ///
  /// In en, this message translates to:
  /// **'See practice across your filtered lectures'**
  String get teacherPracticeAnalyticsHint;

  /// No description provided for @teacherMeetingsAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meetings Analytics'**
  String get teacherMeetingsAnalyticsTitle;

  /// No description provided for @teacherMeetingsAnalyticsHint.
  ///
  /// In en, this message translates to:
  /// **'See meetings across your current filters'**
  String get teacherMeetingsAnalyticsHint;

  /// No description provided for @noTeacherPracticeAttemptsYet.
  ///
  /// In en, this message translates to:
  /// **'No AI practice attempts for this filter yet.'**
  String get noTeacherPracticeAttemptsYet;

  /// No description provided for @noTeacherMeetingsYet.
  ///
  /// In en, this message translates to:
  /// **'No meeting requests for this filter yet.'**
  String get noTeacherMeetingsYet;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// No description provided for @downloadFile.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadFile;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that file.'**
  String get fileOpenFailed;

  /// No description provided for @fileDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download that file. Try again.'**
  String get fileDownloadFailed;

  /// No description provided for @fileDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String fileDownloadSaved(String path);

  /// No description provided for @joiningRequests.
  ///
  /// In en, this message translates to:
  /// **'Joining Requests'**
  String get joiningRequests;

  /// No description provided for @noJoiningRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending course join requests.'**
  String get noJoiningRequests;

  /// No description provided for @joinCourse.
  ///
  /// In en, this message translates to:
  /// **'Join Course'**
  String get joinCourse;

  /// No description provided for @requestSentTag.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get requestSentTag;

  /// No description provided for @courseJoinedTag.
  ///
  /// In en, this message translates to:
  /// **'Course joined'**
  String get courseJoinedTag;

  /// No description provided for @acceptJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptJoinRequest;

  /// No description provided for @rejectJoinRequest.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectJoinRequest;

  /// No description provided for @joinRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Student joined the course.'**
  String get joinRequestAccepted;

  /// No description provided for @joinRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Join request rejected.'**
  String get joinRequestRejected;

  /// No description provided for @joinRequestActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update that request. Try again.'**
  String get joinRequestActionFailed;

  /// Validation error when phone number length is wrong
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get invalidPhoneNumber;

  /// Label for the OTP verify button
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Subtitle on the phone OTP screen
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {contact}'**
  String otpSentToPhone(String contact);

  /// Snackbar shown after resending an SMS OTP
  ///
  /// In en, this message translates to:
  /// **'A new code was sent to {contact}'**
  String otpSmsSent(String contact);

  /// Shown below the OTP field while attempts are left
  ///
  /// In en, this message translates to:
  /// **'{count} attempts remaining'**
  String otpAttemptsRemaining(int count);

  /// Shown when all 5 OTP attempts are used up
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please resend the code.'**
  String get otpAttemptsExhausted;

  /// Snackbar shown after a wrong OTP, with attempts remaining
  ///
  /// In en, this message translates to:
  /// **'Invalid code. {count} attempts left'**
  String otpInvalidWithAttempts(int count);

  /// Resend button label during the cooldown countdown
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendInSeconds(int seconds);

  /// AuthException message for AuthException.invalidOtp
  ///
  /// In en, this message translates to:
  /// **'The code you entered is incorrect'**
  String get otpInvalidCode;

  /// AuthException message for AuthException.otpExpired
  ///
  /// In en, this message translates to:
  /// **'This code has expired, please resend'**
  String get otpExpiredCode;

  /// Text next to the resend button on the OTP screen
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get didntReceiveCode;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your phone'**
  String get verifyPhoneTitle;

  /// No description provided for @verifyPhoneBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent by SMS to {phone}.'**
  String verifyPhoneBody(String phone);

  /// No description provided for @phoneVerifiedPleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Phone verified. Please log in.'**
  String get phoneVerifiedPleaseLogin;

  /// No description provided for @emailOrPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Email or phone with country code'**
  String get emailOrPhoneHint;

  /// No description provided for @invalidEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email or country code'**
  String get invalidEmailOrPhone;

  /// No description provided for @topicFilesRequired.
  ///
  /// In en, this message translates to:
  /// **'Upload at least one slide or file for this topic.'**
  String get topicFilesRequired;

  /// No description provided for @topicFilesRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Slides/files required (PDF, Word, or PowerPoint).'**
  String get topicFilesRequiredHint;

  /// No description provided for @topicSlides.
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get topicSlides;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @slidePageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String slidePageOf(int current, int total);

  /// No description provided for @slideFileOf.
  ///
  /// In en, this message translates to:
  /// **'File {current} of {total}'**
  String slideFileOf(int current, int total);

  /// No description provided for @slideFilePageOf.
  ///
  /// In en, this message translates to:
  /// **'File {file} of {files} · Page {page} of {pages}'**
  String slideFilePageOf(int file, int files, int page, int pages);

  /// No description provided for @slidesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this file.'**
  String get slidesLoadFailed;

  /// No description provided for @slidesOpenExternally.
  ///
  /// In en, this message translates to:
  /// **'This file type opens outside the app.'**
  String get slidesOpenExternally;

  /// No description provided for @noTopicSlides.
  ///
  /// In en, this message translates to:
  /// **'No slides uploaded for this topic.'**
  String get noTopicSlides;

  /// No description provided for @followingTeacher.
  ///
  /// In en, this message translates to:
  /// **'Following teacher'**
  String get followingTeacher;

  /// No description provided for @liveSlideHowClear.
  ///
  /// In en, this message translates to:
  /// **'How clear is this slide?'**
  String get liveSlideHowClear;

  /// No description provided for @liveSlideSignalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live slide understanding'**
  String get liveSlideSignalsTitle;

  /// No description provided for @liveSlideSignalSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved for this slide'**
  String get liveSlideSignalSaved;

  /// No description provided for @liveSlideNoSignals.
  ///
  /// In en, this message translates to:
  /// **'No student feedback has been submitted yet.'**
  String get liveSlideNoSignals;

  /// No description provided for @liveSlideOnPage.
  ///
  /// In en, this message translates to:
  /// **'Slide {page}'**
  String liveSlideOnPage(int page);

  /// No description provided for @liveSlideOnFilePage.
  ///
  /// In en, this message translates to:
  /// **'File {file} · Slide {page}'**
  String liveSlideOnFilePage(int file, int page);

  /// No description provided for @liveSlideNeedHelpCount.
  ///
  /// In en, this message translates to:
  /// **'{count} need help on this slide'**
  String liveSlideNeedHelpCount(int count);

  /// No description provided for @liveSlideSignalFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save slide feedback. Try again.'**
  String get liveSlideSignalFailed;

  /// No description provided for @studentSlideFeedbackSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your slide feedback'**
  String get studentSlideFeedbackSummaryTitle;

  /// No description provided for @studentSlideFeedbackSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review how you rated each slide during the lecture.'**
  String get studentSlideFeedbackSummarySubtitle;

  /// No description provided for @studentSlideFeedbackEmpty.
  ///
  /// In en, this message translates to:
  /// **'You did not leave feedback on any slides during this lecture.'**
  String get studentSlideFeedbackEmpty;

  /// No description provided for @studentSlideFeedbackNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get studentSlideFeedbackNext;

  /// No description provided for @lectureSummaryTitleNumbered.
  ///
  /// In en, this message translates to:
  /// **'Lecture {number} Summary'**
  String lectureSummaryTitleNumbered(int number);

  /// No description provided for @studentSlideFeedbackSummaryTitleNumbered.
  ///
  /// In en, this message translates to:
  /// **'Lecture {number} slide feedback'**
  String studentSlideFeedbackSummaryTitleNumbered(int number);

  /// No description provided for @lectureEndTitleNumbered.
  ///
  /// In en, this message translates to:
  /// **'Lecture {number} ended'**
  String lectureEndTitleNumbered(int number);

  /// No description provided for @practiceWithAiTitleNumbered.
  ///
  /// In en, this message translates to:
  /// **'Practice Lecture {number} with AI Assistant'**
  String practiceWithAiTitleNumbered(int number);

  /// No description provided for @lectureNumber.
  ///
  /// In en, this message translates to:
  /// **'Lecture {number}'**
  String lectureNumber(int number);

  /// No description provided for @liveFocusModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Focus mode on — stay in LEARNsync until the lecture ends. Other apps, calls, and notifications are not fully blocked by the OS.'**
  String get liveFocusModeBanner;

  /// No description provided for @liveFocusModeAndroidHint.
  ///
  /// In en, this message translates to:
  /// **'Focus mode: screen stays on, screenshots blocked, and Android may ask to pin this app. Allow Do Not Disturb access to silence notifications (calls still may ring without MDM).'**
  String get liveFocusModeAndroidHint;

  /// No description provided for @liveFocusModeIosHint.
  ///
  /// In en, this message translates to:
  /// **'Focus mode: screen stays on. iOS cannot block other apps, calls, or notifications from this app — use Guided Access (Settings > Accessibility) for a stronger lockdown.'**
  String get liveFocusModeIosHint;

  /// No description provided for @liveFocusOpenDndSettings.
  ///
  /// In en, this message translates to:
  /// **'DND access'**
  String get liveFocusOpenDndSettings;

  /// No description provided for @liveFocusLeftAppWarn.
  ///
  /// In en, this message translates to:
  /// **'You left LEARNsync during the live lecture. Your teacher can see you as away. Return and stay in the lecture.'**
  String get liveFocusLeftAppWarn;

  /// No description provided for @liveFocusStayTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture in progress'**
  String get liveFocusStayTitle;

  /// No description provided for @liveFocusStayBody.
  ///
  /// In en, this message translates to:
  /// **'Stay in this screen until your teacher ends the lecture. Leaving early is visible to the teacher.'**
  String get liveFocusStayBody;

  /// No description provided for @liveFocusStudentAway.
  ///
  /// In en, this message translates to:
  /// **'Away (left app)'**
  String get liveFocusStudentAway;

  /// No description provided for @liveFollowTeacher.
  ///
  /// In en, this message translates to:
  /// **'Follow teacher'**
  String get liveFollowTeacher;

  /// No description provided for @jumpToSlide.
  ///
  /// In en, this message translates to:
  /// **'Jump to slide'**
  String get jumpToSlide;

  /// No description provided for @slideNumber.
  ///
  /// In en, this message translates to:
  /// **'Slide number'**
  String get slideNumber;

  /// No description provided for @slideNumberOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a slide number between 1 and {count}.'**
  String slideNumberOutOfRange(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
