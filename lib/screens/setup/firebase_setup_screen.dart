import 'package:flutter/material.dart';

class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirebaseSetupScreen(),
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = '''
Project: learnsync-bb5e6

Enable in Firebase Console:
1. Authentication → Email/Password
2. Cloud Firestore

Then on this computer:

   firebase login
   flutterfire configure --project=learnsync-bb5e6

Restart the app after configure finishes.
''';

    return Scaffold(
      backgroundColor: const Color(0xFF0B2545),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect Firebase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Accounts, teacher links, and courses will be stored in learnsync-bb5e6.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    steps,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.55,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
