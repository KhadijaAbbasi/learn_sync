import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_errors.dart';
import '../../core/utils/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

enum _ForgotStep { identify, phoneOtp, newPassword, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ForgotStep _step = _ForgotStep.identify;
  bool _contactLooksLikeEmail = true;

  bool _isSubmitting = false;
  String? _sentToEmail;
  String? _phoneE164;

  int _remainingAttempts = 5;
  bool _otpLocked = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _contactController.addListener(_onContactChanged);
  }

  void _onContactChanged() {
    final raw = _contactController.text.trim();
    final phoneMode = raw.startsWith('+') ||
        raw.startsWith('92') ||
        raw.startsWith('966');
    final next = !phoneMode;
    if (next != _contactLooksLikeEmail) {
      setState(() => _contactLooksLikeEmail = next);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _contactController.removeListener(_onContactChanged);
    _contactController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _submitIdentify() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final contact = _contactController.text.trim();
    try {
      if (Validators.looksLikeEmail(contact)) {
        final email = contact;
        await AppScope.of(context).authService.sendPasswordReset(email: email);
        if (!mounted) return;
        setState(() {
          _sentToEmail = email;
          _step = _ForgotStep.done;
        });
      } else {
        final phone = Validators.normalizePhone(contact);
        await AppScope.of(context)
            .authService
            .startPasswordResetPhoneOtp(phone: phone);
        if (!mounted) return;
        setState(() {
          _phoneE164 = phone;
          _step = _ForgotStep.phoneOtp;
          _remainingAttempts = 5;
          _otpLocked = false;
        });
        _startCooldown();
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpLocked || _isSubmitting || _phoneE164 == null) return;
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;

    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await AppScope.of(context).authService.verifyPasswordResetPhoneOtp(
        phone: _phoneE164!,
        otp: otp,
      );
      if (!mounted) return;
      setState(() => _step = _ForgotStep.newPassword);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _remainingAttempts--;
        _otpController.clear();
        if (_remainingAttempts <= 0) {
          _remainingAttempts = 0;
          _otpLocked = true;
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _otpLocked
                ? l10n.otpAttemptsExhausted
                : authErrorMessage(l10n, error),
          ),
          backgroundColor: _otpLocked
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_isSubmitting || _resendCooldown > 0 || _otpLocked || _phoneE164 == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context)
          .authService
          .startPasswordResetPhoneOtp(phone: _phoneE164!);
      if (!mounted) return;
      _otpController.clear();
      _startCooldown();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.otpSmsSent(_phoneE164!))),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitNewPassword() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).authService.completePasswordResetWithNewPassword(
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _step = _ForgotStep.done);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthLayout(
      showBackButton: true,
      child: switch (_step) {
        _ForgotStep.identify => _buildIdentify(l10n),
        _ForgotStep.phoneOtp => _buildPhoneOtp(l10n),
        _ForgotStep.newPassword => _buildNewPassword(l10n),
        _ForgotStep.done => _buildDone(l10n),
      },
    );
  }

  Widget _buildIdentify(AppLocalizations l10n) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthHeader(
              title: l10n.forgotPasswordTitle,
              subtitle: l10n.forgotPasswordSubtitle,
            ),
            const SizedBox(height: 24),
            CustomTextField(
              key: const ValueKey('forgot_contact_field'),
              controller: _contactController,
              hintText: l10n.emailOrPhoneHint,
              prefixIcon: _contactLooksLikeEmail
                  ? Icons.mail_outline_rounded
                  : Icons.phone_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              validator: (value) =>
                  Validators.emailOrSupportedPhone(value, l10n),
              onFieldSubmitted: (_) => _submitIdentify(),
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: _contactLooksLikeEmail
                  ? l10n.sendResetLink
                  : 'Send code',
              isLoading: _isSubmitting,
              onPressed: _submitIdentify,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneOtp(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthHeader(
            title: l10n.forgotPasswordTitle,
            subtitle: l10n.otpSmsSent(_phoneE164 ?? ''),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpController,
            enabled: !_otpLocked,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '------',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onFieldSubmitted: (_) => _verifyOtp(),
          ),
          const SizedBox(height: 12),
          Text(
            _otpLocked
                ? l10n.otpAttemptsExhausted
                : l10n.otpInvalidWithAttempts(_remainingAttempts),
            style: TextStyle(
              color: _otpLocked
                  ? Theme.of(context).colorScheme.error
                  : AppColors.textSecondary(Theme.of(context).brightness),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            label: l10n.verifyOtp,
            isLoading: _isSubmitting,
            onPressed: _otpLocked ? null : _verifyOtp,
          ),
          TextButton(
            onPressed: (_resendCooldown > 0 || _otpLocked || _isSubmitting)
                ? null
                : _resendOtp,
            child: Text(
              _resendCooldown > 0
                  ? 'Resend code ($_resendCooldown)'
                  : 'Resend code',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPassword(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthHeader(
            title: l10n.forgotPasswordTitle,
            subtitle: l10n.passwordRequirements,
          ),
          const SizedBox(height: 24),
          CustomTextField(
            controller: _passwordController,
            hintText: l10n.password,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (value) => Validators.password(value, l10n),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _confirmPasswordController,
            hintText: l10n.confirmPassword,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (value) => Validators.confirmPassword(
              value: value,
              original: _passwordController.text,
              l10n: l10n,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            label: 'Save new password',
            isLoading: _isSubmitting,
            onPressed: _submitNewPassword,
          ),
        ],
      ),
    );
  }

  Widget _buildDone(AppLocalizations l10n) {
    final sentTo = _sentToEmail;
    return Column(
      children: [
        AuthHeader(
          title: sentTo != null
              ? l10n.resetEmailSentTitle
              : 'Password updated',
          subtitle: sentTo != null
              ? l10n.resetEmailSentBody(sentTo)
              : 'Your password was changed. You can log in with your phone number and new password.',
        ),
        const SizedBox(height: 16),
        Text(
          l10n.resetEmailSentHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary(Theme.of(context).brightness),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        CustomButton(
          label: l10n.backToLogin,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
