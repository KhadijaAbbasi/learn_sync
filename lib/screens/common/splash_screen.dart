import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/utils/auth_navigation.dart';
import '../auth/signup_otp_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    Future<void>.delayed(const Duration(milliseconds: 1700), _openApp);
  }

  Future<void> _openApp() async {
    if (!mounted) {
      return;
    }
    try {
      final user = await AppScope.of(context).authService.restoreSession();
      if (!mounted) {
        return;
      }
      if (user != null) {
        final auth = AppScope.of(context).authService;
        if (!auth.isCurrentEmailVerified) {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => SignupOtpScreen(email: user.email),
            ),
          );
          return;
        }
        if (await auth.requiresLoginAfterSignup) {
          await auth.signOut();
          if (!mounted) {
            return;
          }
          await Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          return;
        }
        if (!mounted) {
          return;
        }
        openDashboard(context, user);
        return;
      }
    } catch (_) {}
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.asset(
                  AppAssets.logoMark,
                  width: 148,
                  height: 148,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}