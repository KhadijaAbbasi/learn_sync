import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_errors.dart';
import '../../core/utils/auth_navigation.dart';
import '../../core/utils/validators.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'signup_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _contactLooksLikeEmail = true;

  @override
  void initState() {
    super.initState();
    _contactController.addListener(_onContactChanged);
  }

  void _onContactChanged() {
    final raw = _contactController.text.trim();
    final phoneMode =
        raw.startsWith('+') || raw.startsWith('92') || raw.startsWith('966');
    final next = !phoneMode;
    if (next != _contactLooksLikeEmail) {
      setState(() => _contactLooksLikeEmail = next);
    }
  }

  @override
  void dispose() {
    _contactController.removeListener(_onContactChanged);
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final contact = _contactController.text.trim();
    final isEmail = Validators.looksLikeEmail(contact);
    final identifier = isEmail ? contact : Validators.normalizePhone(contact);

    try {
      final user = await AppScope.of(context).authService.login(
        emailOrUsername: identifier,
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }

      if (isEmail) {
        if (!AppScope.of(context).authService.isCurrentEmailVerified) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SignupOtpScreen(email: user.email),
            ),
          );
          return;
        }
      } else {
        if (!AppScope.of(context).authService.isCurrentPhoneVerified) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SignupOtpScreen(phone: user.phone),
            ),
          );
          return;
        }
      }

      openDashboard(context, user);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthHeader(title: l10n.welcomeBack, subtitle: l10n.loginSubtitle),
            const SizedBox(height: 32),
            CustomTextField(
              key: const ValueKey('login_contact_field'),
              controller: _contactController,
              hintText: l10n.emailOrPhoneHint,
              prefixIcon: _contactLooksLikeEmail
                  ? Icons.mail_outline_rounded
                  : Icons.phone_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              validator: (value) =>
                  Validators.emailOrSupportedPhone(value, l10n),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              hintText: l10n.password,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (value) => Validators.requiredField(value, l10n),
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
                child: Text(
                  l10n.forgotPassword,
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (AppScope.of(context).authService.showDemoHint) ...[
              const SizedBox(height: 8),
              Text(
                l10n.demoHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(Theme.of(context).brightness),
                ),
              ),
            ],
            const SizedBox(height: 8),
            CustomButton(
              label: l10n.login,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
            AuthFooterLink(
              prompt: l10n.dontHaveAccount,
              actionLabel: l10n.signUp,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.signup),
            ),
          ],
        ),
      ),
    );
  }
}
