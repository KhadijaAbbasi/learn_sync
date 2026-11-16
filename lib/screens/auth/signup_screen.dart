import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/utils/auth_errors.dart';
import '../../core/utils/validators.dart';
import '../../models/user_role.dart';
import '../../screens/auth/signup_otp_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dropdown_field.dart';
import '../../widgets/custom_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _memberIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole? _role;
  bool _isSubmitting = false;
  bool _contactLooksLikeEmail = true;

  @override
  void initState() {
    super.initState();
    _contactController.addListener(_onContactChanged);
  }

  void _onContactChanged() {
    final raw = _contactController.text.trim();
    // Phone icon when user is clearly typing a PK/SA dial code.
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
    _contactController.removeListener(_onContactChanged);
    _nameController.dispose();
    _contactController.dispose();
    _memberIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final contact = _contactController.text.trim();

    try {
      if (Validators.looksLikeEmail(contact)) {
        final email = contact;
        await AppScope.of(context).authService.signUp(
          fullName: _nameController.text.trim(),
          email: email,
          memberId: _memberIdController.text.trim(),
          role: _role!,
          password: _passwordController.text,
        );
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignupOtpScreen(email: email),
          ),
        );
      } else {
        final phone = Validators.normalizePhone(contact);
        await AppScope.of(context).authService.signUp(
          fullName: _nameController.text.trim(),
          phone: phone,
          memberId: _memberIdController.text.trim(),
          role: _role!,
          password: _passwordController.text,
        );
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignupOtpScreen(phone: phone),
          ),
        );
      }
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == AuthException.emailAlreadyInUse ||
          error.code == AuthException.phoneAlreadyInUse) {
        await showUserAlreadyExistsDialog(context);
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
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
      showBackButton: true,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AuthHeader(
                title: l10n.createAccount,
                subtitle: l10n.signUpSubtitle,
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _nameController,
                hintText: l10n.fullName,
                prefixIcon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                validator: (value) => Validators.requiredField(value, l10n),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                key: const ValueKey('contact_field'),
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
              const SizedBox(height: 14),
              CustomTextField(
                controller: _memberIdController,
                hintText: _role == UserRole.teacher
                    ? l10n.teacherMemberId
                    : _role == UserRole.student
                    ? l10n.studentMemberId
                    : l10n.memberId,
                prefixIcon: Icons.badge_outlined,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                ],
                validator: (value) => Validators.memberId(value, l10n),
              ),
              const SizedBox(height: 14),
              CustomDropdownField<UserRole>(
                value: _role,
                hintText: l10n.iAmA,
                prefixIcon: Icons.school_outlined,
                items: [
                  DropdownMenuItem(
                    value: UserRole.teacher,
                    child: Text(l10n.teacher),
                  ),
                  DropdownMenuItem(
                    value: UserRole.student,
                    child: Text(l10n.student),
                  ),
                ],
                onChanged: (role) => setState(() => _role = role),
                validator: (value) => value == null ? l10n.selectRole : null,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _passwordController,
                hintText: l10n.password,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => Validators.password(value, l10n),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _confirmPasswordController,
                hintText: l10n.confirmPassword,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => Validators.confirmPassword(
                  value: value,
                  original: _passwordController.text,
                  l10n: l10n,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: l10n.signUp,
                variant: AppButtonVariant.signup,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              AuthFooterLink(
                prompt: l10n.alreadyHaveAccount,
                actionLabel: l10n.login,
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
