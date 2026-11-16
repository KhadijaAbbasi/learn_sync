// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'LEARNsync';

  @override
  String get appTagline => 'ملاحظات الطلاب في الوقت الفعلي';

  @override
  String get welcomeBack => 'مرحبًا بعودتك!';

  @override
  String get loginSubtitle => 'سجّل الدخول للمتابعة إلى حسابك.';

  @override
  String get emailOrUsername => 'البريد الإلكتروني أو اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get forgotPassword => 'هل نسيت كلمة المرور؟';

  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get forgotPasswordSubtitle =>
      'أدخل البريد الإلكتروني لحسابك. سنرسل رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get resetEmailSentTitle => 'تحقق من بريدك';

  @override
  String resetEmailSentBody(String email) {
    return 'أرسلنا رابط إعادة تعيين كلمة المرور إلى $email.';
  }

  @override
  String get resetEmailSentHint =>
      'افتح الرسالة وعيّن كلمة مرور جديدة ثم عد إلى هنا لتسجيل الدخول.';

  @override
  String get accountNotFound => 'لا يوجد حساب لهذا البريد الإلكتروني.';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get otpTitle => 'تحقق من بريدك';

  @override
  String otpSubtitle(String email) {
    return 'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى $email.';
  }

  @override
  String get otpHint => 'رمز من 6 أرقام';

  @override
  String get otpInvalidLength => 'أدخل رمز التحقق المكوّن من 6 أرقام.';

  @override
  String get verifyOtp => 'تحقق من الرمز';

  @override
  String get otpSending => 'جارٍ الإرسال...';

  @override
  String get resendOtp => 'إعادة إرسال الرمز';

  @override
  String otpEmailSent(String email) {
    return 'أرسلنا رسالة تحقق إلى $email. تحقق من صندوق الوارد والرسائل غير المرغوب فيها.';
  }

  @override
  String get otpResent => 'تم إرسال رمز تحقق جديد إلى بريدك.';

  @override
  String get userAlreadyExistsTitle => 'الحساب موجود بالفعل';

  @override
  String get userAlreadyExistsBody =>
      'هذا البريد مسجّل بالفعل. سجّل الدخول، أو استخدم نسيت كلمة المرور لإعادة تعيينها.';

  @override
  String get verifyEmailTitle => 'تحقق من بريدك';

  @override
  String verifyEmailBody(String email) {
    return 'افتح رسالة التحقق التي أرسلناها إلى $email. بعد الضغط على الرابط ستفتح شاشة تسجيل الدخول.';
  }

  @override
  String get waitingForEmailVerification =>
      'بانتظار الضغط على الرابط في بريدك…';

  @override
  String get emailVerifiedPleaseLogin =>
      'تم التحقق من البريد. يرجى تسجيل الدخول.';

  @override
  String get emailNotVerified =>
      'افتح رسالة التحقق واضغط الرابط أولاً، ثم حاول مرة أخرى.';

  @override
  String get createAccount => 'أنشئ حسابك';

  @override
  String get signUpSubtitle => 'سجّل للبدء.';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get iAmA => 'أنا...';

  @override
  String get teacher => 'معلم';

  @override
  String get student => 'طالب';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get iAgreePrefix => 'أوافق على ';

  @override
  String get andConjunction => ' و';

  @override
  String get termsOfUse => 'شروط الاستخدام';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get requiredField => 'هذا الحقل مطلوب';

  @override
  String get invalidEmail => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get passwordTooShort => 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل';

  @override
  String get passwordRequirements =>
      'استخدم 8 أحرف على الأقل مع حرف كبير وحرف صغير ورقم ورمز خاص.';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get selectRole => 'يرجى اختيار الدور';

  @override
  String get acceptTerms => 'يرجى الموافقة على شروط الاستخدام وسياسة الخصوصية';

  @override
  String get loginSuccess => 'تم تسجيل الدخول. سيتم ربط الخادم في خطوة لاحقة.';

  @override
  String get signupSuccess => 'تم إنشاء الحساب. يمكنك الآن تسجيل الدخول.';

  @override
  String get termsPlaceholderBody =>
      'ستُضاف شروط الاستخدام الكاملة هنا قبل الإطلاق.';

  @override
  String get privacyPlaceholderBody =>
      'ستُضاف سياسة الخصوصية الكاملة هنا قبل الإطلاق.';

  @override
  String get ok => 'حسنًا';

  @override
  String helloUser(String name) {
    return 'مرحبًا، $name';
  }

  @override
  String get teacherDashboard => 'لوحة المعلم';

  @override
  String get studentDashboard => 'لوحة الطالب';

  @override
  String get yourCourses => 'المقررات';

  @override
  String get addCourse => 'إضافة مقرر';

  @override
  String get newCourse => 'مقرر جديد';

  @override
  String get courseName => 'اسم المقرر';

  @override
  String get deleteCourse => 'حذف المقرر';

  @override
  String get noCoursesTeacher => 'لا توجد مقررات بعد. أضف مقررًا لبدء التدريس.';

  @override
  String get noCoursesStudent => 'اربط حساب معلمك لعرض المقررات المتاحة.';

  @override
  String get liveLecture => 'محاضرة مباشرة';

  @override
  String get noLiveLecture => 'لا توجد محاضرة مباشرة الآن.';

  @override
  String get connectTeacher => 'الارتباط بالمعلم';

  @override
  String get connectTeacherHint => 'أدخل بريد معلمك للوصول إلى مقرراته.';

  @override
  String get teacherEmail => 'بريد المعلم';

  @override
  String get connect => 'ارتباط';

  @override
  String connectedTo(String name) {
    return 'مرتبط بـ $name';
  }

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirm => 'هل أنت متأكد أنك تريد تسجيل الخروج؟';

  @override
  String get statsCourses => 'المقررات';

  @override
  String get statsLive => 'مباشر';

  @override
  String get statsMeetings => 'الاجتماعات';

  @override
  String topicsCount(int count) {
    return '$count موضوعات';
  }

  @override
  String get startTopicSoon => 'سيتم إضافة بدء الموضوع لاحقًا.';

  @override
  String get aiPracticeSoon =>
      'سيتم فتح التمرين بالذكاء الاصطناعي من هنا لاحقًا.';

  @override
  String get meetingSoon => 'سيتم فتح طلبات الاجتماع من هنا لاحقًا.';

  @override
  String get invalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get demoHint =>
      'تجريبي: teacher@learnsync.app أو student@learnsync.app  •  Demo@123';

  @override
  String get emailInUse => 'يوجد حساب بالفعل لهذا البريد الإلكتروني.';

  @override
  String get memberId => 'المعرف';

  @override
  String get teacherMemberId => 'معرف المعلم';

  @override
  String get studentMemberId => 'معرف الطالب';

  @override
  String get memberIdInvalid =>
      'استخدم 3 إلى 32 حرفًا أو رقمًا أو شرطة أو شرطة سفلية.';

  @override
  String get memberIdTaken => 'هذا المعرف مرتبط بالفعل ببريد إلكتروني آخر.';

  @override
  String get networkError => 'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.';

  @override
  String get tooManyRequests => 'محاولات كثيرة جدًا. حاول لاحقًا.';

  @override
  String get authUnknown => 'حدث خطأ. يرجى المحاولة مرة أخرى.';

  @override
  String get teacherNotFound => 'لم يتم العثور على معلم بهذا الاسم أو البريد.';

  @override
  String get teacherHasNoCourses => 'لم يُضف معلمك أي مقررات بعد.';

  @override
  String get courseSaveFailed => 'تعذر حفظ المقرر. حاول مرة أخرى.';

  @override
  String get courseDeleteFailed => 'تعذر حذف المقرر. حاول مرة أخرى.';

  @override
  String get add => 'إضافة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get aiPractice => 'تمرين الذكاء الاصطناعي';

  @override
  String get meetTeacher => 'لقاء المعلم';

  @override
  String welcomeBackName(String name) {
    return 'مرحبًا بعودتك، $name';
  }

  @override
  String get stayUpdated => 'ابقَ على اطلاع واستمر في التعلّم!';

  @override
  String get currentLiveTopic => 'الموضوع المباشر الحالي';

  @override
  String get liveBadge => 'مباشر';

  @override
  String get chapterLabel => 'الفصل 2: كثيرات الحدود';

  @override
  String get liveTopicTitle => 'المعادلات التربيعية';

  @override
  String startedAt(String time) {
    return 'بدأت الساعة $time';
  }

  @override
  String get howWellUnderstood => 'ما مدى فهمك لهذا الموضوع؟';

  @override
  String get understand100 => '100%';

  @override
  String get understand80 => '80%';

  @override
  String get understand60 => '60%';

  @override
  String get understandBelow50 => 'أقل من 50%';

  @override
  String get understand100Hint => 'واضح تمامًا';

  @override
  String get understand80Hint => 'واضح إلى حد كبير';

  @override
  String get understand60Hint => 'أحتاج مراجعة';

  @override
  String get understandBelow50Hint => 'أحتاج مساعدة';

  @override
  String get whatNext => 'ماذا تريد أن تفعل بعد ذلك؟';

  @override
  String get aiPracticeHint => 'احصل على أسئلة خاصة بالموضوع.';

  @override
  String get startPractice => 'ابدأ التمرين';

  @override
  String get alreadyPracticed => 'تم التمرين';

  @override
  String get practiceMore => 'تمرّن أكثر';

  @override
  String get pastPracticeTitle => 'التمارين السابقة';

  @override
  String get pastPracticeEmpty =>
      'لا توجد أسئلة تمرين محفوظة لهذه المحاضرة بعد.';

  @override
  String pastPracticeAttemptLabel(int n, int score, int total, int percent) {
    return 'المحاولة $n · $score/$total ($percent%)';
  }

  @override
  String get requestMeetingHint => 'اطلب دعمًا إضافيًا دون التحدث أمام الصف.';

  @override
  String get requestMeeting => 'طلب اجتماع';

  @override
  String get yourProgress => 'تقدّمك';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get topicsCompleted => 'الموضوعات المكتملة';

  @override
  String get aiPracticesCompleted => 'تمارين الذكاء الاصطناعي';

  @override
  String get meetingsRequested => 'طلبات الاجتماع';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get navLiveTopics => 'الموضوعات المباشرة';

  @override
  String get navPractice => 'التمرين';

  @override
  String get navMeetings => 'الاجتماعات';

  @override
  String get myMeetingRequests => 'طلبات الاجتماع الخاصة بي';

  @override
  String get meetingRequests => 'طلبات الاجتماع';

  @override
  String get meetingDetails => 'تفاصيل الاجتماع';

  @override
  String get createMeetingIntro =>
      'أخبر معلمك بما تحتاج مساعدة فيه. اجعل الطلب قصيرًا وواضحًا.';

  @override
  String get selectCourse => 'اختر المقرر';

  @override
  String get meetingTopicLabel => 'الموضوع';

  @override
  String get meetingTopicHint => 'ما الموضوع الذي تحتاج مساعدة فيه؟';

  @override
  String get meetingReasonLabel => 'السبب';

  @override
  String get meetingReasonHint => 'اشرح ما غير واضح أو ما تريد مناقشته.';

  @override
  String get sendMeetingRequest => 'إرسال الطلب';

  @override
  String get meetingRequestSent => 'تم إرسال طلب الاجتماع.';

  @override
  String get meetingRequestFailed => 'تعذر إرسال طلب الاجتماع. حاول مرة أخرى.';

  @override
  String get meetingFormIncomplete => 'أضف موضوعًا وسببًا قبل الإرسال.';

  @override
  String get linkTeacherFirstForMeeting => 'اربط حسابك بمعلمك قبل طلب اجتماع.';

  @override
  String get noMeetingRequestsYet => 'لا توجد طلبات اجتماع بعد';

  @override
  String get noMeetingRequestsStudentHint =>
      'عندما تشعر بعدم الوضوح، أرسل طلبًا هادئًا إلى معلمك.';

  @override
  String get noMeetingRequestsTeacherHint =>
      'عندما يطلب طالب الدعم، سيظهر طلبه هنا.';

  @override
  String get meetingStatusPending => 'قيد الانتظار';

  @override
  String get meetingStatusAccepted => 'مقبول';

  @override
  String get meetingStatusDeclined => 'مرفوض';

  @override
  String get meetingStatusCompleted => 'مكتمل';

  @override
  String get meetingStatusReschedule => 'إعادة جدولة';

  @override
  String get meetingScheduledFor => 'مجدول في';

  @override
  String get teacherNote => 'ملاحظة المعلم';

  @override
  String get teacherNoteOptional => 'ملاحظة للطالب (اختياري)';

  @override
  String get meetingPendingHint => 'استلم معلمك هذا الطلب وسيرد قريبًا.';

  @override
  String get meetingAcceptedHint =>
      'قبل معلمك هذا الاجتماع. راجع الوقت المجدول أعلاه.';

  @override
  String get meetingDeclinedHint =>
      'لم يتمكن معلمك من قبول هذا الاجتماع. يمكنك إرسال طلب جديد في أي وقت.';

  @override
  String get meetingCompletedHint =>
      'تم تعليم هذا الاجتماع كمكتمل. أحسنت على المتابعة.';

  @override
  String get meetingRescheduleHint =>
      'طلبت إعادة الجدولة. سيختار معلمك وقتًا جديدًا.';

  @override
  String get meetingNotFound => 'تعذر العثور على طلب الاجتماع هذا.';

  @override
  String get pendingMeetings => 'بانتظار الرد';

  @override
  String get allMeetings => 'كل الطلبات';

  @override
  String get scheduleMeetingPrompt => 'اختر وقتًا ثم اقبل أو ارفض.';

  @override
  String get chooseMeetingDateTime => 'اختر التاريخ والوقت';

  @override
  String get chooseNewMeetingDateTime => 'اختر تاريخًا ووقتًا جديدين';

  @override
  String get chooseMeetingTimeFirst => 'اختر تاريخ ووقت الاجتماع أولًا.';

  @override
  String get acceptMeeting => 'قبول الاجتماع';

  @override
  String get declineMeeting => 'رفض';

  @override
  String get setNewMeetingTime => 'تعيين وقت جديد';

  @override
  String get studentAskedReschedule =>
      'طلب الطالب إعادة الجدولة. اختر وقتًا جديدًا.';

  @override
  String get requestReschedule => 'طلب إعادة جدولة';

  @override
  String get requestRescheduleHint =>
      'تحتاج وقتًا مختلفًا؟ اطلب من معلمك إعادة الجدولة.';

  @override
  String get rescheduleNoteOptional => 'لماذا تحتاج وقتًا جديدًا؟ (اختياري)';

  @override
  String get rescheduleNoteLabel => 'ملاحظة إعادة الجدولة';

  @override
  String get rescheduleRequestedToast =>
      'تم إرسال طلب إعادة الجدولة إلى معلمك.';

  @override
  String get meetingRescheduledToast => 'تم حفظ وقت الاجتماع الجديد.';

  @override
  String get markMeetingCompleted => 'تعليم كمكتمل';

  @override
  String get meetingCompleteAfterSchedule =>
      'يمكنك التعليم كمكتمل فقط بعد الوقت المجدول.';

  @override
  String meetingCompleteAfterScheduleHint(String time) {
    return 'يُفعَّل الإكمال بعد $time.';
  }

  @override
  String pendingMeetingRequests(int count) {
    return '$count طلبات اجتماع قيد الانتظار';
  }

  @override
  String get meetingAcceptedToast => 'تم قبول الاجتماع.';

  @override
  String get meetingDeclinedToast => 'تم رفض الاجتماع.';

  @override
  String get meetingCompletedToast => 'تم تعليم الاجتماع كمكتمل.';

  @override
  String get meetingUpdateFailed => 'تعذر تحديث الاجتماع. حاول مرة أخرى.';

  @override
  String get openMeetings => 'فتح الاجتماعات';

  @override
  String meetingsPendingCount(int count) {
    return '$count بانتظار الرد';
  }

  @override
  String get courseLabel => 'المقرر';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get settingsSoon => 'ستُضاف الإعدادات لاحقًا.';

  @override
  String get changeTeacher => 'تغيير';

  @override
  String get timerLabel => 'المؤقت';

  @override
  String get teacherHomeHint => 'أضف المقررات ثم ابدأ الموضوع الذي تدرّسه.';

  @override
  String get studentHomeHint =>
      'انضم عبر بريد معلمك. لا يوجد بحث عن المعلمين — البريد يفتح جميع مقرراته.';

  @override
  String get addCourseTitle => 'إضافة مقرر';

  @override
  String get addCourseSubtitle =>
      'أدخل تفاصيل المقرر. يمكنك بدء الموضوعات بعد الحفظ.';

  @override
  String get saveCourse => 'حفظ المقرر';

  @override
  String get editCourse => 'تعديل المقرر';

  @override
  String get editCourseTitle => 'تعديل المقرر';

  @override
  String get editCourseSubtitle =>
      'حدّث تفاصيل المقرر. لا يمكن تغيير معرف المقرر.';

  @override
  String get saveCourseChanges => 'حفظ التغييرات';

  @override
  String get courseAdded => 'تم حفظ المقرر.';

  @override
  String get courseUpdated => 'تم تحديث المقرر.';

  @override
  String get sectionBasic => 'المعلومات الأساسية';

  @override
  String get sectionSchedule => 'الجدول';

  @override
  String get sectionAcademic => 'التفاصيل الأكاديمية';

  @override
  String get courseCode => 'معرف المقرر';

  @override
  String get courseCodeTaken =>
      'معرف المقرر هذا مضاف بالفعل. استخدم معرفًا مختلفًا.';

  @override
  String get department => 'القسم';

  @override
  String get creditHours => 'الساعات المعتمدة';

  @override
  String get phoneOtpDesktopUnavailable =>
      'التحقق برقم الهاتف متاح في تطبيق الهاتف. على Windows، استخدم البريد الإلكتروني للتسجيل أو إعادة تعيين كلمة المرور. يمكن للحسابات الحالية تسجيل الدخول برقم الهاتف وكلمة المرور.';

  @override
  String fileDownloadStarted(String name) {
    return 'بدأ التنزيل: $name';
  }

  @override
  String creditHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعات معتمدة',
      two: 'ساعتان معتمدتان',
      one: 'ساعة معتمدة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get creditHoursInvalid => 'أدخل ساعات معتمدة بين 1 و 5.';

  @override
  String get lectureHall => 'قاعة المحاضرة';

  @override
  String get lectureDays => 'أيام المحاضرة';

  @override
  String get selectLectureDay => 'اختر يوم محاضرة واحدًا على الأقل.';

  @override
  String get lectureTime => 'وقت المحاضرة';

  @override
  String get lectureDaysAndTimeTitle => 'أيام ووقت المحاضرة';

  @override
  String get lectureDaysAndTimeHint => 'اختر الأيام وحدد من / إلى لكل فترة';

  @override
  String get selectLectureDaysLabel => 'اختر أيام المحاضرة';

  @override
  String get selectMultipleDaysTip => 'يمكنك اختيار أكثر من يوم';

  @override
  String get lectureTimeSlotsLabel => 'فترات وقت المحاضرة';

  @override
  String get addAnotherTimeSlot => 'إضافة فترة وقت أخرى';

  @override
  String get timeFrom => 'من';

  @override
  String get timeTo => 'إلى';

  @override
  String get registrationDate => 'تاريخ التسجيل';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String get courseOutlines => 'مخطط المقرر';

  @override
  String get semester => 'الفصل الدراسي';

  @override
  String get section => 'الشعبة';

  @override
  String get weekdayMon => 'الإثنين';

  @override
  String get weekdayTue => 'الثلاثاء';

  @override
  String get weekdayWed => 'الأربعاء';

  @override
  String get weekdayThu => 'الخميس';

  @override
  String get weekdayFri => 'الجمعة';

  @override
  String get weekdaySat => 'السبت';

  @override
  String get weekdaySun => 'الأحد';

  @override
  String get openMenu => 'القائمة';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'المظهر';

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
  String get darkTheme => 'الوضع الداكن';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get goBack => 'رجوع';

  @override
  String get findYourTeacher => 'ابحث عن معلمك';

  @override
  String get searchTeacherHint => 'ابحث ببريد المعلم الإلكتروني...';

  @override
  String get filter => 'تصفية';

  @override
  String get keepLearningAhead => 'استمر في التعلّم وتقدّم.';

  @override
  String get keepTeachingAhead => 'أضف المقررات وابقَ على تواصل مع صفك.';

  @override
  String get searchCoursesHint => 'ابحث في مقرراتك...';

  @override
  String get notificationsSoon => 'ستُفتح الإشعارات من هنا لاحقًا.';

  @override
  String get filtersSoon => 'ستُضاف عوامل التصفية لاحقًا.';

  @override
  String get courseDetails => 'تفاصيل المقرر';

  @override
  String get uploadSyllabus => 'رفع المنهج';

  @override
  String get editCourseDetails => 'تعديل تفاصيل المقرر';

  @override
  String get syllabusFiles => 'المنهج';

  @override
  String get syllabusUploaded => 'تم رفع المنهج.';

  @override
  String get courseInformation => 'معلومات المقرر';

  @override
  String get classSchedule => 'جدول المحاضرة';

  @override
  String deleteCourseConfirm(String name) {
    return 'هل تريد حذف $name؟ لا يمكن التراجع عن هذا.';
  }

  @override
  String get tabOverview => 'نظرة عامة';

  @override
  String get tabSyllabus => 'المنهج';

  @override
  String get tabLectures => 'المحاضرات';

  @override
  String get tabAssignments => 'الواجبات';

  @override
  String get tabResources => 'المصادر';

  @override
  String get courseInfo => 'معلومات المقرر';

  @override
  String get announcements => 'الإعلانات';

  @override
  String get writeAnnouncement => 'اكتب إعلانًا...';

  @override
  String get postAnnouncement => 'نشر';

  @override
  String get noAnnouncements => 'لا توجد إعلانات بعد.';

  @override
  String get schedule => 'الجدول';

  @override
  String get location => 'المكان';

  @override
  String get credits => 'الساعات';

  @override
  String get courseOutline => 'خطة المقرر';

  @override
  String get addWeek => '+ إضافة أسبوع';

  @override
  String weekNumber(int number) {
    return 'أ$number';
  }

  @override
  String get weekTitle => 'عنوان الأسبوع';

  @override
  String get weekReadings => 'القراءات';

  @override
  String get weekNotes => 'ملاحظات (اختياري)';

  @override
  String get emptyWeeks => 'لا توجد أسابيع بعد. أضف أول أسبوع في الخطة.';

  @override
  String get addLecture => '+ إضافة محاضرة';

  @override
  String get lectureTitle => 'عنوان المحاضرة';

  @override
  String get lectureDate => 'تاريخ المحاضرة';

  @override
  String get lectureDescription => 'الوصف';

  @override
  String get lectureAttachment => 'اسم المرفق (اختياري)';

  @override
  String get lectureFileHint =>
      'ارفع ملفًا واحدًا أو أكثر بصيغة PDF أو Word أو PowerPoint';

  @override
  String get assignmentFileHint =>
      'ارفع ملفًا واحدًا أو أكثر بصيغة PDF أو Word';

  @override
  String get resourceFileHint => 'ارفع ملفًا واحدًا أو أكثر بصيغة PDF أو Word';

  @override
  String get addFiles => 'إضافة ملفات';

  @override
  String get uploadingFiles => 'جاري الرفع…';

  @override
  String get removeFile => 'إزالة';

  @override
  String get addLink => 'إضافة رابط آخر';

  @override
  String get resourceLink => 'https://example.com';

  @override
  String get fileTooLarge => 'يجب أن يكون الملف أصغر من 20 ميغابايت.';

  @override
  String get fileUnreadable => 'تعذر قراءة الملف. جرّب ملفًا آخر.';

  @override
  String get fileUploadFailed => 'تعذر رفع الملف. حاول مرة أخرى.';

  @override
  String get storageDenied =>
      'تعذر حفظ الملف. سجّل الدخول كمعلم المقرر ثم حاول مرة أخرى.';

  @override
  String get emptyLectures => 'لا توجد محاضرات بعد. أضف أول محاضرة.';

  @override
  String get addAssignment => '+ إضافة واجب';

  @override
  String get assignmentTitle => 'عنوان الواجب';

  @override
  String get assignmentDue => 'تاريخ التسليم';

  @override
  String get assignmentPoints => 'الدرجات';

  @override
  String get assignmentDescription => 'الوصف';

  @override
  String get published => 'منشور';

  @override
  String get emptyAssignments => 'لا توجد واجبات بعد. أضف أول واجب.';

  @override
  String get addResource => '+ إضافة مصدر';

  @override
  String get resourceTitle => 'عنوان المصدر';

  @override
  String get resourceType => 'النوع (كتاب، مستند، رابط…)';

  @override
  String get resourceDetail => 'وصف مختصر';

  @override
  String get emptyResources => 'لا توجد مصادر بعد. أضف أول مصدر.';

  @override
  String get itemAdded => 'تم الحفظ.';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get editItem => 'تعديل';

  @override
  String get viewWeek => 'تفاصيل الأسبوع';

  @override
  String get editWeek => 'تعديل الأسبوع';

  @override
  String get viewLecture => 'تفاصيل المحاضرة';

  @override
  String get editLecture => 'تعديل المحاضرة';

  @override
  String get viewAssignment => 'تفاصيل الواجب';

  @override
  String get editAssignment => 'تعديل الواجب';

  @override
  String get viewResource => 'تفاصيل المصدر';

  @override
  String get editResource => 'تعديل المصدر';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navJoinedCourses => 'الدورات المنضم إليها';

  @override
  String get noJoinedCoursesYet => 'لم تنضم إلى أي دورة بعد.';

  @override
  String get profileSettings => 'إعدادات الملف الشخصي';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get gender => 'الجنس';

  @override
  String get genderMale => 'ذكر';

  @override
  String get genderFemale => 'أنثى';

  @override
  String get genderOther => 'آخر';

  @override
  String get bio => 'نبذة';

  @override
  String get bioHint => 'اكتبي مقدمة قصيرة عن نفسك...';

  @override
  String get officeTiming => 'ساعات المكتب';

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
  String get country => 'الدولة';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get save => 'حفظ';

  @override
  String get profileSaved => 'تم حفظ الملف الشخصي.';

  @override
  String get profileSaveFailed => 'تعذر حفظ الملف الشخصي. حاولي مرة أخرى.';

  @override
  String get profilePhotoHint => 'JPG أو JPEG أو PNG فقط';

  @override
  String get profilePhotoInvalidType => 'يُسمح فقط بصور JPG و JPEG و PNG.';

  @override
  String get profilePhotoTooLarge =>
      'الصورة كبيرة جدًا. اختاري صورة JPG أو PNG أصغر.';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountWarning =>
      'احذف حسابك وجميع مقرراتك وبياناتك نهائيًا. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteAccountConfirm =>
      'حذف حسابك وجميع بياناتك؟ لا يمكن التراجع عن ذلك.';

  @override
  String get chaptersAndTopics => 'الفصول والموضوعات';

  @override
  String get manageCourseContent => 'نظّم ما ستدرّسه في هذا المقرر.';

  @override
  String get viewCourseContent => 'استكشف فصول وموضوعات هذا المقرر.';

  @override
  String get addChapter => 'إضافة فصل';

  @override
  String get editChapter => 'تعديل الفصل';

  @override
  String get deleteChapter => 'حذف الفصل';

  @override
  String get deleteChapterConfirm => 'هل تريد حذف هذا الفصل وجميع موضوعاته؟';

  @override
  String chapterNumber(int number) {
    return 'الفصل $number';
  }

  @override
  String get chapterTitle => 'عنوان الفصل';

  @override
  String get chapterDescription => 'وصف مختصر للفصل';

  @override
  String get noChapters => 'لا توجد فصول بعد.';

  @override
  String get noChaptersTeacherHint => 'أضف الفصل الأول لبدء تنظيم هذا المقرر.';

  @override
  String get noChaptersStudentHint => 'لم يضف معلمك أي فصول بعد.';

  @override
  String get addTopic => 'إضافة موضوع';

  @override
  String get changeTopic => 'تغيير الموضوع';

  @override
  String get continueLectureHint =>
      'اختَر موضوعًا سابقًا أو أضِف موضوعًا جديدًا لمتابعة هذه المحاضرة.';

  @override
  String lectureTopicSwitched(String topic) {
    return 'يتم التدريس الآن: $topic';
  }

  @override
  String get editTopic => 'تعديل الموضوع';

  @override
  String get deleteTopic => 'حذف الموضوع';

  @override
  String get deleteTopicConfirm => 'هل تريد حذف هذا الموضوع؟';

  @override
  String get topicTitle => 'عنوان الموضوع';

  @override
  String get topicDescription => 'وصف مختصر للموضوع';

  @override
  String get noTopics => 'لا توجد موضوعات في هذا الفصل بعد.';

  @override
  String get moveUp => 'تحريك لأعلى';

  @override
  String get moveDown => 'تحريك لأسفل';

  @override
  String get contentSaveFailed => 'تعذر حفظ محتوى المقرر. حاول مرة أخرى.';

  @override
  String get startLecture => 'بدء المحاضرة';

  @override
  String get joinLecture => 'الانضمام للمحاضرة';

  @override
  String joinLectureConfirm(String course, String topic) {
    return 'هل تريد الانضمام للمحاضرة المباشرة لـ $course؟\n\n$topic\n\nسيحاول وضع التركيز إبقاؤك في LEARNsync حتى ينهي المعلم المحاضرة. لا يمكن حظر التطبيقات أو المكالمات أو الإشعارات بالكامل على هاتف عادي.';
  }

  @override
  String get endLecture => 'إنهاء المحاضرة';

  @override
  String get endLectureConfirm =>
      'هل تريد إنهاء هذه المحاضرة المباشرة لجميع الطلاب؟';

  @override
  String get selectChapter => 'اختر الفصل';

  @override
  String get selectTopic => 'اختر الموضوع';

  @override
  String get lectureDuration => 'مدة المحاضرة';

  @override
  String durationMinutes(int count) {
    return '$count دقيقة';
  }

  @override
  String get noTopicsToStart =>
      'أضف فصلاً وموضوعًا واحدًا على الأقل قبل بدء المحاضرة.';

  @override
  String get lectureLiveNow => 'توجد محاضرة مباشرة الآن';

  @override
  String get liveLectures => 'المحاضرات المباشرة';

  @override
  String get chooseLiveLecture => 'اختر محاضرة مباشرة للانضمام';

  @override
  String get timeRemaining => 'الوقت المتبقي';

  @override
  String get lectureEnded => 'انتهت هذه المحاضرة.';

  @override
  String get liveSessionStartFailed =>
      'تعذر بدء المحاضرة. تأكد من عدم وجود محاضرة أخرى نشطة.';

  @override
  String get teacherAlreadyLive =>
      'لديك محاضرة مباشرة بالفعل. أنهِها قبل بدء محاضرة أخرى.';

  @override
  String get requestToJoin => 'طلب الانضمام';

  @override
  String get joinRequestPending => 'بانتظار موافقة المعلم';

  @override
  String get enterLecture => 'دخول المحاضرة';

  @override
  String get joinRequestSent => 'تم إرسال طلب الانضمام إلى المعلم.';

  @override
  String get joinRequestFailed => 'تعذر إرسال طلب الانضمام. حاول مرة أخرى.';

  @override
  String get joinRequests => 'طلبات الانضمام';

  @override
  String get acceptJoin => 'قبول';

  @override
  String get joinAll => 'قبول الكل';

  @override
  String get noJoinRequests => 'لا توجد طلبات انضمام قيد الانتظار.';

  @override
  String get acceptJoinFailed => 'تعذر قبول طلب الانضمام.';

  @override
  String get feedbackSubmitted => 'شكرًا — تم حفظ ملاحظاتك.';

  @override
  String get feedbackSubmitFailed => 'تعذر حفظ الملاحظات. حاول مرة أخرى.';

  @override
  String get lectureFeedbackTitle => 'ملاحظات المحاضرة';

  @override
  String get endedBadge => 'انتهت';

  @override
  String get feedbackCommentHint => 'شارك تعليقات أو اقتراحات (اختياري)';

  @override
  String get submitFeedbackCta => 'إرسال الملاحظات';

  @override
  String get selectUnderstandingFirst => 'اختر مدى فهمك لهذا الموضوع.';

  @override
  String get feedbackSubmittedTitle => 'تم إرسال الملاحظات!';

  @override
  String get lectureEndTitle => 'انتهت المحاضرة';

  @override
  String get lectureEndSubtitle => 'ماذا تريد أن تفعل بعد ذلك؟';

  @override
  String feedbackNextPrompt(String level) {
    return 'بما أنك اخترت \'$level\'، ماذا تريد أن تفعل بعد ذلك؟';
  }

  @override
  String get practiceWithAiTitle => 'تمرّن مع مساعد الذكاء الاصطناعي';

  @override
  String practiceWithAiHint(String topic) {
    return 'اختبر نفسك الآن على مفاهيم $topic.';
  }

  @override
  String get scheduleMeetingTitle => 'جدولة اجتماع مع المعلم';

  @override
  String scheduleMeetingHint(String teacher) {
    return 'احجز جلسة افتراضية سريعة فردية مع $teacher.';
  }

  @override
  String get maybeLater => 'ربما لاحقًا';

  @override
  String get teacherFeedbackSubtitle =>
      'اطلع على مدى فهم الطلاب لهذه المحاضرة.';

  @override
  String get completedStatus => 'مكتملة';

  @override
  String get studentsLabel => 'طلاب';

  @override
  String responsesOfTotal(int received, int total) {
    return 'الردود: $received/$total';
  }

  @override
  String practiceRateLabel(int percent) {
    return 'معدل التمرين: $percent%';
  }

  @override
  String totalRequestsLabel(int count) {
    return '$count طلبات إجمالية';
  }

  @override
  String thisCourseRequests(int count) {
    return 'هذه المادة: $count';
  }

  @override
  String get understandingBreakdown => 'تفصيل الفهم';

  @override
  String studentResponsesCount(int count) {
    return 'ردود الطلاب ($count)';
  }

  @override
  String get understoodPerfectly => 'فهم تام';

  @override
  String get understoodMost => 'فهم معظم المحتوى';

  @override
  String get understoodSome => 'فهم جزئي';

  @override
  String get needMoreHelp => 'يحتاج مساعدة أكثر';

  @override
  String get practicedBadge => 'تمرّن';

  @override
  String get notPracticedBadge => 'لم يتمرّن';

  @override
  String get meetingShort => 'اجتماع';

  @override
  String get yesLabel => 'نعم';

  @override
  String get noLabel => 'لا';

  @override
  String get showLess => 'عرض أقل';

  @override
  String needHelpInsight(int count, int percent) {
    return '$count طلاب ($percent%) يحتاجون مساعدة أكثر في هذا الموضوع. فكّر في مراجعة الأمثلة والتمرين.';
  }

  @override
  String get understandingSummary => 'ملاحظات الفهم';

  @override
  String feedbackCountLabel(int count) {
    return '$count ردود';
  }

  @override
  String get noFeedbackYet => 'لا توجد ملاحظات من الطلاب بعد.';

  @override
  String get changeFeedback => 'تغيير الملاحظات';

  @override
  String get liveSessionEndFailed => 'تعذر إنهاء المحاضرة. حاول مرة أخرى.';

  @override
  String liveTopic(String topic) {
    return 'مباشر: $topic';
  }

  @override
  String get liveNow => 'مباشر';

  @override
  String get lectureComplete => 'انتهت';

  @override
  String get plannedDuration => 'المدة المخططة';

  @override
  String get sessionDetails => 'تفاصيل الجلسة';

  @override
  String get startTime => 'وقت البدء';

  @override
  String studentsPresent(int count) {
    return '$count حاضرون';
  }

  @override
  String get attendance => 'الحضور';

  @override
  String attendeesCount(int count) {
    return 'الحضور ($count)';
  }

  @override
  String get noStudentsYet => 'لم ينضم أي طالب بعد.';

  @override
  String get youAreInClass => 'أنت في هذه المحاضرة';

  @override
  String get waitingForStudents => 'بانتظار انضمام الطلاب';

  @override
  String get teachingLiveHint => 'أنت تدرّس مباشرة الآن';

  @override
  String get attendingLiveHint => 'أنت تحضر المحاضرة المباشرة الآن';

  @override
  String get lectureInformation => 'معلومات المحاضرة';

  @override
  String get currentTopic => 'الموضوع الحالي';

  @override
  String get estimatedEnd => 'الانتهاء المتوقع';

  @override
  String get topicLiveHint => 'هذا الموضوع مباشر وظاهر لجميع الطلاب المسجلين.';

  @override
  String joinedAt(String time) {
    return 'انضم في $time';
  }

  @override
  String get scheduleLabel => 'الجدول';

  @override
  String get totalStudents => 'الطلاب';

  @override
  String get creditsShort => 'الساعات';

  @override
  String get liveChatSoon => 'ستفتح المحادثة المباشرة من هنا لاحقًا.';

  @override
  String get livePollSoon => 'ستفتح الاستطلاعات المباشرة من هنا لاحقًا.';

  @override
  String get liveChat => 'محادثة';

  @override
  String get livePoll => 'استطلاع';

  @override
  String pointsLabel(int count) {
    return '$count درجة';
  }

  @override
  String get lectureSummaryTitle => 'ملخص المحاضرة';

  @override
  String get lectureSummarySubtitle =>
      'راجع هذه المحاضرة قبل عرض ملاحظات الطلاب.';

  @override
  String get viewStudentFeedback => 'عرض ملاحظات الطلاب';

  @override
  String get endTime => 'وقت الانتهاء';

  @override
  String get actualDuration => 'المدة الفعلية';

  @override
  String get lectureSummarySaveFailed =>
      'تعذر حفظ ملخص المحاضرة. حاول مرة أخرى.';

  @override
  String get taughtNotesLabel => 'ماذا درّست اليوم؟';

  @override
  String get taughtNotesHint => 'أضف ملاحظة قصيرة عما غطيته في هذه المحاضرة.';

  @override
  String get taughtNotesRequired => 'يرجى كتابة ما درّسته اليوم.';

  @override
  String get backToDashboard => 'العودة إلى لوحة التحكم';

  @override
  String get aiPracticeScreenTitle => 'تمرّن مع الذكاء الاصطناعي';

  @override
  String get aiQuizResultsTitle => 'نتائج اختبار الذكاء الاصطناعي';

  @override
  String get inProgressStatus => 'قيد التنفيذ';

  @override
  String get completedBadgeCaps => 'مكتمل';

  @override
  String topicPrefix(String topic) {
    return 'الموضوع: $topic';
  }

  @override
  String get aiPracticeAnswerAll =>
      'يرجى الإجابة عن الأسئلة الخمسة أدناه قبل الإرسال.';

  @override
  String questionOfTotal(int current, int total) {
    return 'السؤال $current من $total';
  }

  @override
  String get submitQuiz => 'إرسال الاختبار';

  @override
  String get quizCompletedTitle => 'اكتمل الاختبار!';

  @override
  String get quizPassedMessage => 'أحسنت! لقد اجتزت مراجعة هذه المحاضرة بنجاح.';

  @override
  String get quizFailedMessage =>
      'راجع الشروحات وحاول مرة أخرى لتعزيز ما فاتك.';

  @override
  String get passedBadge => 'ناجح';

  @override
  String get needsReviewBadge => 'يحتاج مراجعة';

  @override
  String get totalQuestionsLabel => 'إجمالي الأسئلة';

  @override
  String get correctAnswersLabel => 'إجابات صحيحة';

  @override
  String get wrongAnswersLabel => 'إجابات خاطئة';

  @override
  String get aiTutorBadge => 'المعلّم الذكي';

  @override
  String get diagnosticTitle => 'التشخيص والإرشاد';

  @override
  String get reviewExplanations => 'مراجعة شرح الأسئلة';

  @override
  String get practiceAgain => 'تمرّن مرة أخرى';

  @override
  String get endPractice => 'إنهاء التمرين';

  @override
  String get resultsSecureHint => 'تم تقييم أدائك وحفظه بشكل آمن.';

  @override
  String get aiPracticeUnsupported =>
      'تمرين الذكاء الاصطناعي يعمل على تطبيق الهاتف. لا يمكن للمتصفح تحميل نموذج Qwen 2.5 0.5B على الجهاز.';

  @override
  String get aiPracticeNoNotesTitle => 'ملاحظات المحاضرة مطلوبة';

  @override
  String get aiPracticeNoNotes =>
      'لم يحفظ المعلّم ملاحظات عما دُرّس اليوم، لذلك لا يمكن إنشاء اختبار التمرين بعد. اطلب منهم حفظ الملاحظات ثم حاول مرة أخرى.';

  @override
  String get aiPracticeNoBelow50Title => 'لا توجد شرائح أقل من 50٪';

  @override
  String get aiPracticeNoBelow50 =>
      'أسئلة التمرين تأتي فقط من الشرائح التي قيّمتها بأقل من 50٪. لم تقيّم أي شريحة بأقل من 50٪ في هذه المحاضرة، لذلك لا يوجد اختبار الآن.';

  @override
  String aiPracticeSourceChapter(String chapter) {
    return 'الفصل: $chapter';
  }

  @override
  String aiPracticeSourceLecture(String lecture) {
    return 'المحاضرة: $lecture';
  }

  @override
  String aiPracticeSourceSlide(String slide) {
    return 'الشريحة: $slide';
  }

  @override
  String aiPracticeSourceTopic(String topic) {
    return 'الموضوع: $topic';
  }

  @override
  String get aiPracticeDownloadTitle =>
      'جارٍ تجهيز الذكاء الاصطناعي على الجهاز';

  @override
  String get aiPracticeDownloadHint =>
      'يتم تنزيل Qwen 2.5 0.5B للتمرين الخاص على جهازك. يحدث هذا مرة واحدة.';

  @override
  String get aiPracticeGenerating =>
      'جارٍ كتابة خمسة أسئلة من ملاحظات محاضرة اليوم…';

  @override
  String get aiPracticeGenerateFailed => 'تعذر إنشاء الاختبار. حاول مرة أخرى.';

  @override
  String get aiPracticeRetry => 'حاول مرة أخرى';

  @override
  String get aiPracticeSubmitIncomplete => 'أجب عن كل الأسئلة قبل الإرسال.';

  @override
  String get aiPracticeSaveFailed => 'تعذر حفظ محاولة التمرين.';

  @override
  String get explanationCorrectLabel => 'الإجابة الصحيحة';

  @override
  String get explanationYourAnswer => 'إجابتك';

  @override
  String optionLetter(Object letter) {
    return '$letter';
  }

  @override
  String get teacherAnalytics => 'تحليلات المعلّم';

  @override
  String get teacherAnalyticsHint =>
      'اطلع على الفهم، تمارين الذكاء الاصطناعي، والاجتماعات.';

  @override
  String get teacherAnalyticsSubtitle =>
      'حدد الموضوعات الصعبة والطلاب الذين يحتاجون دعمًا.';

  @override
  String get analyticsOverview => 'نظرة عامة';

  @override
  String get analyticsUnderstanding => 'الفهم';

  @override
  String get analyticsPractice => 'تمرين الذكاء الاصطناعي';

  @override
  String get analyticsMeetings => 'الاجتماعات';

  @override
  String analyticsAverage(int value) {
    return 'المتوسط $value%';
  }

  @override
  String analyticsResponses(int count) {
    return '$count ردود';
  }

  @override
  String analyticsParticipation(int percent) {
    return '$percent% مشاركة';
  }

  @override
  String analyticsCompletion(int percent) {
    return '$percent% إكمال';
  }

  @override
  String analyticsAverageScore(int value) {
    return 'متوسط الدرجة $value%';
  }

  @override
  String analyticsMeetingTotal(int count) {
    return '$count طلبات';
  }

  @override
  String get analyticsTopicOverview => 'نظرة عامة على الموضوع';

  @override
  String analyticsCombinedLectures(int count) {
    return '$count محاضرات مجمعة';
  }

  @override
  String get analyticsTotalStudents => 'إجمالي الطلاب';

  @override
  String get analyticsTotalResponses => 'إجمالي الردود';

  @override
  String get analyticsAvgUnderstanding => 'متوسط الفهم';

  @override
  String get analyticsUnderstandingDistribution => 'توزيع مستوى الفهم';

  @override
  String get analyticsStudentPerformance => 'أداء الطلاب والتفاصيل';

  @override
  String get analyticsSearchStudent => 'ابحث عن طالب...';

  @override
  String get analyticsOnTrack => 'على المسار';

  @override
  String get analyticsNeedsAttention => 'يحتاج اهتماماً';

  @override
  String get analyticsMeetingYes => 'نعم';

  @override
  String get analyticsMeetingNo => 'لا';

  @override
  String get analyticsSelectTopicHint =>
      'اختر مقرراً وفصلاً وموضوعاً لعرض تحليلات مجمعة لكل محاضرات هذا الموضوع.';

  @override
  String get analyticsByTopic => 'الفهم حسب الموضوع';

  @override
  String get analyticsBySession => 'الفهم حسب الجلسة';

  @override
  String get analyticsNeedsSupport => 'طلاب يحتاجون دعمًا';

  @override
  String get analyticsLowUnderstanding => 'فهم منخفض';

  @override
  String get analyticsIncompletePractice => 'لم يتمرّنوا بعد';

  @override
  String get analyticsPendingMeetings => 'اجتماعات معلّقة';

  @override
  String get analyticsAllCourses => 'كل المقررات';

  @override
  String get analyticsAllChapters => 'كل الفصول';

  @override
  String get analyticsAllTopics => 'كل الموضوعات';

  @override
  String get analyticsAllTime => 'كل الوقت';

  @override
  String get analyticsLast7Days => 'آخر 7 أيام';

  @override
  String get analyticsLast30Days => 'آخر 30 يومًا';

  @override
  String get analyticsCustomRange => 'تواريخ مخصصة';

  @override
  String get analyticsFromDate => 'من';

  @override
  String get analyticsToDate => 'إلى';

  @override
  String get analyticsEmptyTitle => 'لا توجد تحليلات بعد';

  @override
  String get analyticsEmpty =>
      'بعد أن يرسل الطلاب الملاحظات أو يتمرّنوا أو يطلبوا اجتماعات، ستظهر النتائج هنا.';

  @override
  String get analyticsLoadFailed => 'تعذر تحميل التحليلات. حاول مرة أخرى.';

  @override
  String get analyticsPracticeUnavailable =>
      'إحصاءات تمرين الذكاء الاصطناعي غير متاحة الآن. ما زال الفهم والاجتماعات يظهران.';

  @override
  String get analyticsRetry => 'حاول مرة أخرى';

  @override
  String get analyticsNoBars => 'لا توجد بيانات فهم لهذا التصفية.';

  @override
  String get analyticsNoStudents => 'لا يوجد طلاب في هذه القائمة.';

  @override
  String analyticsResponsesShort(int count, int value) {
    return '$count ردود · $value%';
  }

  @override
  String get analyticsChapterFilter => 'الفصل';

  @override
  String get analyticsTopicFilter => 'الموضوع';

  @override
  String get dateRangeLabel => 'النطاق الزمني';

  @override
  String get aiPracticesEmpty =>
      'لا توجد محاضرات منتهية بعد. بعد أن ينهي معلمك الحصة مع الملاحظات، ستظهر هنا تمارين الذكاء الاصطناعي.';

  @override
  String get aiPracticeColorLegendTooltip => 'معنى الألوان';

  @override
  String get aiPracticeColorLegendTitle => 'معنى الألوان';

  @override
  String get aiPracticeColorLegendSubtitle =>
      'تُظهر الألوان عدد تمارين الذكاء الاصطناعي المستخدمة.';

  @override
  String get aiPracticeColorNone => '0 تمارين ذكاء اصطناعي';

  @override
  String get aiPracticeColorFew => '1 أو 2 تمارين ذكاء اصطناعي';

  @override
  String get aiPracticeColorMany => '3+ تمارين ذكاء اصطناعي';

  @override
  String get aiPracticeColorRed => 'أحمر';

  @override
  String get aiPracticeColorYellow => 'أصفر';

  @override
  String get aiPracticeColorTeal => 'تركواز';

  @override
  String get lectureAnalytics => 'تحليلات المحاضرة';

  @override
  String get lectureAnalyticsHint => 'اطلع على تفاعل الطلاب مع كل محاضرة.';

  @override
  String get remove => 'إزالة';

  @override
  String get enrolledStudents => 'الطلاب المسجلون';

  @override
  String get enrolledStudentsHint =>
      'عرض وإدارة الطلاب المسجلين في هذه الدورة.';

  @override
  String enrolledStudentsCount(int count) {
    return '$count مسجلون';
  }

  @override
  String get tapToViewProfile => 'اضغط لعرض الملف الشخصي';

  @override
  String get noEnrolledStudentsYet => 'لا يوجد طلاب مسجلون في هذه الدورة بعد.';

  @override
  String get removeEnrolledStudent => 'إزالة الطالب';

  @override
  String removeEnrolledStudentConfirm(String name) {
    return 'إزالة $name من هذه الدورة؟ سيحتاج إلى طلب الانضمام مرة أخرى.';
  }

  @override
  String get removeEnrolledStudentFailed => 'تعذر إزالة الطالب. حاول مرة أخرى.';

  @override
  String studentRemovedFromCourse(String name) {
    return 'تمت إزالة $name من هذه الدورة.';
  }

  @override
  String get lectureAnalyticsSubtitle =>
      'اطلع على تفاعل طلابك مع هذه المحاضرة.';

  @override
  String get courseLecturesTitle => 'محاضرات المقرر';

  @override
  String get courseLecturesEmpty =>
      'لا توجد محاضرات لهذا المقرر بعد. بعد أن تقدّم محاضرة مباشرة ستظهر هنا.';

  @override
  String get lectureAnalyticsNote =>
      'بعد انتهاء المحاضرة يمكنك معرفة عدد الطلاب الذين فهموا الموضوع، وأكملوا تمرين الذكاء الاصطناعي، وطلبوا اجتماعًا.';

  @override
  String get backToLectures => 'العودة إلى المحاضرات';

  @override
  String get viewAllRequests => 'عرض كل الطلبات';

  @override
  String totalRequestsThisLecture(int count) {
    return '$count طلبات لهذه المحاضرة';
  }

  @override
  String studentsCountLabel(int count) {
    return '$count طلاب';
  }

  @override
  String get understandingSection => '١. الفهم';

  @override
  String get aiPracticeSection => '٢. تمرين الذكاء الاصطناعي';

  @override
  String get meetingsSection => '٣. الاجتماعات';

  @override
  String get lectureMeetingsHubTitle => 'اجتماعات المحاضرة';

  @override
  String get lectureMeetingsHubSubtitle => 'الطلبات الخاصة بهذه المحاضرة فقط.';

  @override
  String get pendingRequests => 'طلبات معلّقة';

  @override
  String get scheduledMeetings => 'اجتماعات مجدولة';

  @override
  String get attendedMeetings => 'تم الحضور';

  @override
  String get noMeetingsForLecture => 'لا توجد طلبات اجتماع لهذه المحاضرة بعد.';

  @override
  String get noPendingMeetingsForLecture =>
      'لا توجد طلبات معلّقة لهذه المحاضرة.';

  @override
  String get noScheduledMeetingsForLecture =>
      'لا توجد اجتماعات مجدولة لهذه المحاضرة.';

  @override
  String get noAttendedMeetingsForLecture =>
      'لا توجد اجتماعات تم حضورها لهذه المحاضرة.';

  @override
  String get understandingDetailTitle => 'تفاصيل الفهم';

  @override
  String get aiPracticeDetailTitle => 'تفاصيل تمرين الذكاء الاصطناعي';

  @override
  String get understandingDetailHint =>
      'اطلع على مدى فهم كل طالب لهذه المحاضرة';

  @override
  String get aiPracticeDetailHint =>
      'اطلع على الطلاب الذين تمرّنوا على هذه المحاضرة';

  @override
  String get noPracticeAttemptsYet =>
      'لا توجد محاولات تمرين لهذه المحاضرة بعد.';

  @override
  String get understandingOverview => 'نظرة عامة على الفهم';

  @override
  String get practiceOverview => 'نظرة عامة على التمرين';

  @override
  String get meetingsOverview => 'نظرة عامة على الاجتماعات';

  @override
  String get totalResponsesLabel => 'إجمالي الردود';

  @override
  String get totalPracticeLabel => 'إجمالي التمرين';

  @override
  String get totalMeetingsLabel => 'إجمالي الاجتماعات';

  @override
  String get searchStudentHint => 'ابحث عن طالب...';

  @override
  String get noStudentsInLevel => 'لا يوجد طلاب في هذا مستوى الفهم.';

  @override
  String get noStudentsInPracticeGroup => 'لا يوجد طلاب في مجموعة التمرين هذه.';

  @override
  String get noMatchingStudents => 'لا يوجد طلاب مطابقون لبحثك.';

  @override
  String get noMeetingsInBucket => 'لا توجد اجتماعات في هذه الفئة.';

  @override
  String get noMatchingMeetings => 'لا توجد اجتماعات مطابقة لبحثك.';

  @override
  String studentsHeadingCount(int count) {
    return 'الطلاب ($count)';
  }

  @override
  String meetingsHeadingCount(int count) {
    return 'الاجتماعات ($count)';
  }

  @override
  String meetingsCountLabel(int count) {
    return '$count اجتماعات';
  }

  @override
  String get meetingsDetailTitle => 'تفاصيل الاجتماعات';

  @override
  String get meetingsDetailHint => 'اطلع على طلبات الاجتماع لهذه المحاضرة';

  @override
  String get meetingBucketPending => 'معلّق';

  @override
  String get meetingBucketScheduled => 'مجدول';

  @override
  String get meetingBucketAttended => 'تم الحضور';

  @override
  String get studentProfileTitle => 'ملف الطالب';

  @override
  String get thisLectureUnderstanding => 'الفهم في هذه المحاضرة';

  @override
  String get teacherUnderstandingAnalyticsTitle => 'تحليلات الفهم';

  @override
  String get teacherPracticeAnalyticsTitle =>
      'تحليلات التدريب بالذكاء الاصطناعي';

  @override
  String get teacherPracticeAnalyticsHint =>
      'اطلع على التدريب ضمن فلترك الحالي';

  @override
  String get teacherMeetingsAnalyticsTitle => 'تحليلات الاجتماعات';

  @override
  String get teacherMeetingsAnalyticsHint =>
      'اطلع على الاجتماعات ضمن فلترك الحالي';

  @override
  String get noTeacherPracticeAttemptsYet =>
      'لا توجد محاولات تدريب لهذا الفلتر بعد.';

  @override
  String get noTeacherMeetingsYet => 'لا توجد طلبات اجتماع لهذا الفلتر بعد.';

  @override
  String get openFile => 'فتح';

  @override
  String get downloadFile => 'تنزيل';

  @override
  String get fileOpenFailed => 'تعذر فتح هذا الملف.';

  @override
  String get fileDownloadFailed => 'تعذر تنزيل هذا الملف. حاول مرة أخرى.';

  @override
  String fileDownloadSaved(String path) {
    return 'تم الحفظ في $path';
  }

  @override
  String get joiningRequests => 'طلبات الانضمام';

  @override
  String get noJoiningRequests => 'لا توجد طلبات انضمام معلقة.';

  @override
  String get joinCourse => 'الانضمام للدورة';

  @override
  String get requestSentTag => 'تم إرسال الطلب';

  @override
  String get courseJoinedTag => 'تم الانضمام';

  @override
  String get acceptJoinRequest => 'قبول';

  @override
  String get rejectJoinRequest => 'رفض';

  @override
  String get joinRequestAccepted => 'انضم الطالب إلى الدورة.';

  @override
  String get joinRequestRejected => 'تم رفض طلب الانضمام.';

  @override
  String get joinRequestActionFailed => 'تعذر تحديث الطلب. حاول مرة أخرى.';

  @override
  String get invalidPhoneNumber => 'أدخلي رقم هاتف صالحًا';

  @override
  String get verify => 'تحقق';

  @override
  String otpSentToPhone(String contact) {
    return 'أرسلنا رمزًا إلى $contact';
  }

  @override
  String otpSmsSent(String contact) {
    return 'أُرسل رمز جديد إلى $contact';
  }

  @override
  String otpAttemptsRemaining(int count) {
    return 'تبقى $count محاولات';
  }

  @override
  String get otpAttemptsExhausted => 'محاولات كثيرة. أعيدي إرسال الرمز.';

  @override
  String otpInvalidWithAttempts(int count) {
    return 'رمز غير صحيح. تبقى $count محاولات';
  }

  @override
  String resendInSeconds(int seconds) {
    return 'إعادة الإرسال خلال $secondsث';
  }

  @override
  String get otpInvalidCode => 'الرمز الذي أدخلته غير صحيح';

  @override
  String get otpExpiredCode => 'انتهت صلاحية هذا الرمز، أعيدي الإرسال';

  @override
  String get didntReceiveCode => 'لم يصلك الرمز؟';

  @override
  String get verifyPhoneTitle => 'تحقق من هاتفك';

  @override
  String verifyPhoneBody(String phone) {
    return 'أدخل الرمز المكون من 6 أرقام الذي أرسلناه عبر رسالة نصية إلى $phone.';
  }

  @override
  String get phoneVerifiedPleaseLogin =>
      'تم التحقق من الهاتف. يرجى تسجيل الدخول.';

  @override
  String get emailOrPhoneHint => 'البريد أو الهاتف مع رمز الدولة';

  @override
  String get invalidEmailOrPhone => 'أدخل بريداً صالحاً أو رمز الدولة';

  @override
  String get topicFilesRequired =>
      'ارفع شريحة أو ملفاً واحداً على الأقل لهذا الموضوع.';

  @override
  String get topicFilesRequiredHint =>
      'الشرائح/الملفات مطلوبة (PDF أو Word أو PowerPoint).';

  @override
  String get topicSlides => 'الشرائح';

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get nextPage => 'الصفحة التالية';

  @override
  String slidePageOf(int current, int total) {
    return 'صفحة $current من $total';
  }

  @override
  String slideFileOf(int current, int total) {
    return 'ملف $current من $total';
  }

  @override
  String slideFilePageOf(int file, int files, int page, int pages) {
    return 'ملف $file من $files · صفحة $page من $pages';
  }

  @override
  String get slidesLoadFailed => 'تعذر تحميل هذا الملف.';

  @override
  String get slidesOpenExternally => 'هذا النوع من الملفات يُفتح خارج التطبيق.';

  @override
  String get noTopicSlides => 'لا توجد شرائح لهذا الموضوع.';

  @override
  String get followingTeacher => 'متابعة المعلم';

  @override
  String get liveSlideHowClear => 'ما مدى وضوح هذه الشريحة؟';

  @override
  String get liveSlideSignalsTitle => 'فهم الشرائح المباشر';

  @override
  String get liveSlideSignalSaved => 'تم الحفظ لهذه الشريحة';

  @override
  String get liveSlideNoSignals => 'لم يتم تقديم ملاحظات من الطلاب بعد.';

  @override
  String liveSlideOnPage(int page) {
    return 'الشريحة $page';
  }

  @override
  String liveSlideOnFilePage(int file, int page) {
    return 'ملف $file · شريحة $page';
  }

  @override
  String liveSlideNeedHelpCount(int count) {
    return '$count يحتاجون مساعدة في هذه الشريحة';
  }

  @override
  String get liveSlideSignalFailed =>
      'تعذر حفظ ملاحظات الشريحة. حاول مرة أخرى.';

  @override
  String get studentSlideFeedbackSummaryTitle => 'ملاحظاتك على الشرائح';

  @override
  String get studentSlideFeedbackSummarySubtitle =>
      'راجع تقييمك لكل شريحة أثناء المحاضرة.';

  @override
  String get studentSlideFeedbackEmpty =>
      'لم تترك ملاحظات على أي شريحة خلال هذه المحاضرة.';

  @override
  String get studentSlideFeedbackNext => 'التالي';

  @override
  String lectureSummaryTitleNumbered(int number) {
    return 'ملخص المحاضرة $number';
  }

  @override
  String studentSlideFeedbackSummaryTitleNumbered(int number) {
    return 'ملاحظات شرائح المحاضرة $number';
  }

  @override
  String lectureEndTitleNumbered(int number) {
    return 'انتهت المحاضرة $number';
  }

  @override
  String practiceWithAiTitleNumbered(int number) {
    return 'تمرّن على المحاضرة $number مع مساعد الذكاء الاصطناعي';
  }

  @override
  String lectureNumber(int number) {
    return 'المحاضرة $number';
  }

  @override
  String get liveFocusModeBanner =>
      'وضع التركيز مفعّل — ابقِ في LEARNsync حتى تنتهي المحاضرة. التطبيقات الأخرى والمكالمات والإشعارات لا تُحظر بالكامل من نظام التشغيل.';

  @override
  String get liveFocusModeAndroidHint =>
      'وضع التركيز: تبقى الشاشة مضاءة، وتُحظر لقطات الشاشة، وقد يطلب Android تثبيت هذا التطبيق. امنح إذن عدم الإزعاج لكتم الإشعارات (قد تظل المكالمات ترن بدون MDM).';

  @override
  String get liveFocusModeIosHint =>
      'وضع التركيز: تبقى الشاشة مضاءة. لا يستطيع iOS حظر التطبيقات أو المكالمات أو الإشعارات من هذا التطبيق — استخدمي Guided Access (الإعدادات > إمكانية الوصول) لقفل أقوى.';

  @override
  String get liveFocusOpenDndSettings => 'إذن عدم الإزعاج';

  @override
  String get liveFocusLeftAppWarn =>
      'غادرتِ LEARNsync أثناء المحاضرة المباشرة. يمكن لمعلمك رؤيتك كغائبة. ارجعي وابقي في المحاضرة.';

  @override
  String get liveFocusStayTitle => 'المحاضرة جارية';

  @override
  String get liveFocusStayBody =>
      'ابقي في هذه الشاشة حتى ينهي معلمك المحاضرة. المغادرة مبكرًا ظاهرة للمعلم.';

  @override
  String get liveFocusStudentAway => 'غائبة (غادرت التطبيق)';

  @override
  String get liveFollowTeacher => 'متابعة المعلم';

  @override
  String get jumpToSlide => 'الانتقال إلى شريحة';

  @override
  String get slideNumber => 'رقم الشريحة';

  @override
  String slideNumberOutOfRange(int count) {
    return 'أدخل رقم شريحة بين 1 و$count.';
  }
}
