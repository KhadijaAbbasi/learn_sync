import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import 'core/constants/app_routes.dart';
import 'core/di/app_scope.dart';
import 'core/localization/locale_controller.dart';
import 'core/session/course_store.dart';
import 'core/session/meeting_store.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/common/profile_settings_screen.dart';
import 'screens/common/settings_screen.dart';
import 'screens/common/splash_screen.dart';
import 'screens/student/student_shell.dart';
import 'screens/teacher/add_course_screen.dart';
import 'screens/teacher/teacher_shell.dart';
import 'services/auth_service.dart';
import 'services/course_enrollment_service.dart';

class LearnsyncApp extends StatelessWidget {
  const LearnsyncApp({
    super.key,
    required this.localeController,
    required this.themeController,
    required this.authService,
    required this.sessionController,
    required this.courseStore,
    required this.meetingStore,
    required this.enrollment,
  });

  final LocaleController localeController;
  final ThemeController themeController;
  final AuthService authService;
  final SessionController sessionController;
  final CourseStore courseStore;
  final MeetingStore meetingStore;
  final CourseEnrollmentService enrollment;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      authService: authService,
      localeController: localeController,
      themeController: themeController,
      sessionController: sessionController,
      courseStore: courseStore,
      meetingStore: meetingStore,
      enrollment: enrollment,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          localeController,
          themeController,
          sessionController,
        ]),
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => AppLocalizations.of(context).appName,
            theme: AppTheme.light(locale: localeController.locale),
            darkTheme: AppTheme.dark(locale: localeController.locale),
            themeMode: themeController.mode,
            locale: localeController.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            initialRoute: AppRoutes.splash,
            routes: {
              AppRoutes.splash: (_) => const SplashScreen(),
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
              AppRoutes.signup: (_) => const SignupScreen(),
              AppRoutes.teacherDashboard: (_) => const TeacherShell(),
              AppRoutes.addCourse: (_) => const AddCourseScreen(),
              AppRoutes.studentDashboard: (_) => const StudentShell(),
              AppRoutes.profile: (_) => const ProfileSettingsScreen(),
              AppRoutes.settings: (_) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}