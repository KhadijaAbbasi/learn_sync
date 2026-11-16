import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';
import 'core/localization/locale_controller.dart';
import 'core/session/course_store.dart';
import 'core/session/meeting_store.dart';
import 'core/session/session_controller.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';
import 'screens/setup/firebase_setup_screen.dart';
import 'services/course_enrollment_service.dart';
import 'services/firebase_auth_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (!DefaultFirebaseOptions.isConfigured) {
    FlutterNativeSplash.remove();
    runApp(const FirebaseSetupApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    LearnsyncApp(
      localeController: LocaleController(),
      themeController: ThemeController(),
      authService: FirebaseAuthService(),
      sessionController: SessionController(),
      courseStore: CourseStore(firestore: FirebaseFirestore.instance),
      meetingStore: MeetingStore(firestore: FirebaseFirestore.instance),
      enrollment: CourseEnrollmentService(
        firestore: FirebaseFirestore.instance,
      ),
    ),
  );
}
