import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_errors.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/custom_button.dart'; // NEW — needed for the phone OTP screen

/// Max number of wrong OTP attempts allowed (phone flow only) before
/// the field locks. Does not affect the email flow below.
const int kMaxOtpAttempts = 5;

class SignupOtpScreen extends StatefulWidget {
  // NEW: both params are now optional, but exactly one must be given.
  // Existing calls like `SignupOtpScreen(email: user.email)` keep working
  // with ZERO changes required at the call site.
  const SignupOtpScreen({super.key, this.email, this.phone})
    : assert(
        email != null || phone != null,
        'Either email or phone must be provided',
      );

  final String? email;
  final String? phone; // NEW

  bool get isPhoneFlow => phone != null; // NEW

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen>
    with WidgetsBindingObserver {
  // ══════════════════════════════════════════════════════════════
  // 🔒 EMAIL FLOW — everything in this section is UNCHANGED from
  // your original file. It only runs when widget.email != null.
  // ══════════════════════════════════════════════════════════════
  Timer? _pollTimer;
  bool _isResending = false;
  bool _openingLogin = false;

  Future<void> _checkVerified() async {
    if (!mounted || _openingLogin) {
      return;
    }
    final user = await AppScope.of(
      context,
    ).authService.checkSignupEmailVerified();
    if (!mounted || user == null || _openingLogin) {
      return;
    }
    _openingLogin = true;
    _pollTimer?.cancel();
    final l10n = AppLocalizations.of(context);
    await AppScope.of(context).authService.signOut();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.emailVerifiedPleaseLogin)));
    await Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    final l10n = AppLocalizations.of(context);
    try {
      await AppScope.of(context).authService.resendSignupVerification();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.otpEmailSent(widget.email!))),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(l10n, error))));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // NEW — PHONE FLOW state & methods. Only used when
  // widget.phone != null. Completely separate from the email
  // methods above, so nothing old is touched.
  // ══════════════════════════════════════════════════════════════
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  int _remainingAttempts = kMaxOtpAttempts;
  bool _isVerifyingPhoneOtp = false;
  bool _isPhoneOtpLocked = false;
  bool _isResendingPhoneOtp = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  void _startResendCooldown() {
    _resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyPhoneOtp() async {
    if (_isPhoneOtpLocked || _isVerifyingPhoneOtp) return;

    final form = _phoneFormKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isVerifyingPhoneOtp = true);
    final l10n = AppLocalizations.of(context);

    try {
      // NEW AuthService method — see auth_service_todo.dart.
      // Must throw AuthException(code: AuthException.invalidOtp) on a
      // wrong code, and complete normally when it's correct.
      await AppScope.of(context).authService.verifySignupPhoneOtp(
        phone: widget.phone!,
        otp: _otpController.text.trim(),
      );

      if (!mounted) return;

      // Match email flow: clear the just-created session and ask user to log in.
      await AppScope.of(context).authService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.phoneVerifiedPleaseLogin)));
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      _registerFailedPhoneAttempt(
        l10n,
        message: authErrorMessage(l10n, error),
      );
    } catch (_) {
      if (!mounted) return;
      _registerFailedPhoneAttempt(l10n);
    } finally {
      if (mounted) {
        setState(() => _isVerifyingPhoneOtp = false);
      }
    }
  }

  void _registerFailedPhoneAttempt(AppLocalizations l10n, {String? message}) {
    setState(() {
      _remainingAttempts--;
      _otpController.clear();
      if (_remainingAttempts <= 0) {
        _remainingAttempts = 0;
        _isPhoneOtpLocked = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPhoneOtpLocked
              ? (message ?? l10n.otpAttemptsExhausted)
              : (message ?? l10n.otpInvalidWithAttempts(_remainingAttempts)),
        ),
        backgroundColor: _isPhoneOtpLocked
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }

  Future<void> _resendPhoneOtp() async {
    if (_isResendingPhoneOtp || _resendCooldown > 0 || _isPhoneOtpLocked) return;

    setState(() => _isResendingPhoneOtp = true);
    final l10n = AppLocalizations.of(context);

    try {
      // NEW AuthService method — see auth_service_todo.dart.
      await AppScope.of(
        context,
      ).authService.resendSignupPhoneOtp(phone: widget.phone!);

      if (!mounted) return;

      // Keep the same 5-attempt budget — resend only issues a fresh OTP.
      setState(() {
        _otpController.clear();
      });
      _startResendCooldown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.otpSmsSent(widget.phone!))),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(l10n, error))));
    } finally {
      if (mounted) {
        setState(() => _isResendingPhoneOtp = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Lifecycle — email polling only starts for the email flow,
  // exactly like before. Phone flow skips it entirely.
  // ══════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    if (widget.isPhoneFlow) {
      // Phone flow: no email polling / lifecycle observer; start SMS resend cooldown.
      _startResendCooldown();
      return;
    }
    // 🔒 UNCHANGED — original email polling setup.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVerified());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkVerified();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    // Phone flow never registers the lifecycle observer — only remove it for email.
    if (!widget.isPhoneFlow) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.isPhoneFlow) return; // NEW: not relevant for phone flow
    if (state == AppLifecycleState.resumed) {
      _checkVerified();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPhoneFlow) {
      return _buildPhoneOtpUi(context); // NEW
    }
    return _buildEmailVerifyUi(context); // 🔒 UNCHANGED
  }

  // 🔒 UNCHANGED — identical to your original build() body.
  Widget _buildEmailVerifyUi(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;

    return AuthLayout(
      showBackButton: true,
      child: Column(
        children: [
          AuthHeader(
            title: l10n.verifyEmailTitle,
            subtitle: l10n.verifyEmailBody(widget.email!),
          ),
          const SizedBox(height: 28),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.waitingForEmailVerification,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(brightness),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isResending ? null : _resend,
            child: Text(_isResending ? l10n.otpSending : l10n.resendOtp),
          ),
        ],
      ),
    );
  }

  // NEW — typed OTP UI with 5-attempt limit, for the phone flow.
  Widget _buildPhoneOtpUi(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);

    return AuthLayout(
      showBackButton: true,
      child: Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              title: l10n.verifyPhoneTitle,
              subtitle: l10n.verifyPhoneBody(widget.phone!),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _otpController,
              enabled: !_isPhoneOtpLocked,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              maxLength: 6,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '------',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return l10n.otpInvalidLength;
                }
                return null;
              },
              onFieldSubmitted: (_) => _verifyPhoneOtp(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _isPhoneOtpLocked
                    ? l10n.otpAttemptsExhausted
                    : l10n.otpAttemptsRemaining(_remainingAttempts),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: (_remainingAttempts <= 2 || _isPhoneOtpLocked)
                      ? theme.colorScheme.error
                      : AppColors.textSecondary(brightness),
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: l10n.verify,
              isLoading: _isVerifyingPhoneOtp,
              onPressed: _isPhoneOtpLocked ? null : _verifyPhoneOtp,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.didntReceiveCode,
                  style: TextStyle(color: AppColors.textSecondary(brightness)),
                ),
                TextButton(
                  onPressed: (_resendCooldown > 0 || _isResendingPhoneOtp || _isPhoneOtpLocked)
                      ? null
                      : _resendPhoneOtp,
                  child: Text(
                    _isResendingPhoneOtp
                        ? l10n.otpSending
                        : _resendCooldown > 0
                        ? l10n.resendInSeconds(_resendCooldown)
                        : l10n.resendOtp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 🔒 UNCHANGED
Future<void> showUserAlreadyExistsDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.userAlreadyExistsTitle),
        content: Text(l10n.userAlreadyExistsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.ok),
          ),
        ],
      );
    },
  );
}
