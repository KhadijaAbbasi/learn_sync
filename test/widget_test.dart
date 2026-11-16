import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learnsync/app.dart';
import 'package:learnsync/core/localization/locale_controller.dart';
import 'package:learnsync/core/session/course_store.dart';
import 'package:learnsync/core/session/meeting_store.dart';
import 'package:learnsync/core/session/session_controller.dart';
import 'package:learnsync/core/theme/theme_controller.dart';
import 'package:learnsync/screens/common/splash_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  LearnsyncApp buildApp() {
    return LearnsyncApp(
      localeController: LocaleController(),
      themeController: ThemeController(),
      authService: MockAuthService(),
      sessionController: SessionController(),
      courseStore: CourseStore(),
      meetingStore: MeetingStore(),
      enrollment: CourseEnrollmentService(),
    );
  }

  testWidgets('splash then login screen', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('login opens forgot password', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
  });
}