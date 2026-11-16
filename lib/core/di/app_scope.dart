import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/course_enrollment_service.dart';
import '../localization/locale_controller.dart';
import '../session/course_store.dart';
import '../session/meeting_store.dart';
import '../session/session_controller.dart';
import '../theme/theme_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.authService,
    required this.localeController,
    required this.themeController,
    required this.sessionController,
    required this.courseStore,
    required this.meetingStore,
    required this.enrollment,
    required super.child,
  });

  final AuthService authService;
  final LocaleController localeController;
  final ThemeController themeController;
  final SessionController sessionController;
  final CourseStore courseStore;
  final MeetingStore meetingStore;
  final CourseEnrollmentService enrollment;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return authService != oldWidget.authService ||
        localeController != oldWidget.localeController ||
        themeController != oldWidget.themeController ||
        sessionController != oldWidget.sessionController ||
        courseStore != oldWidget.courseStore ||
        meetingStore != oldWidget.meetingStore ||
        enrollment != oldWidget.enrollment;
  }
}