import 'package:flutter/foundation.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../services/auth_service.dart';

String authErrorMessage(AppLocalizations l10n, Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return l10n.invalidCredentials;
      case 'invalid_email':
        return l10n.invalidEmail;
      case 'email_in_use':
        return l10n.emailInUse;
      case 'phone_in_use':
        return l10n.emailInUse;
      case 'invalid_phone_number':
        return l10n.invalidPhoneNumber;
      case 'id_in_use':
        return l10n.memberIdTaken;
      case 'invalid_otp':
        return l10n.otpInvalidLength;
      case 'network':
        return l10n.networkError;
      case 'too_many_requests':
        return l10n.tooManyRequests;
      case 'teacher_not_found':
        return l10n.teacherNotFound;
      case 'account_not_found':
        return l10n.accountNotFound;
      case 'email_not_verified':
        return l10n.emailNotVerified;
      case 'weak_password':
        return l10n.passwordRequirements;
      case 'operation_not_allowed':
        return 'This sign-in method is not enabled. Check Firebase Auth providers.';
      case 'phone_auth_web_unsupported':
        final webDetails = error.details?.trim();
        if (webDetails != null && webDetails.isNotEmpty) {
          return webDetails;
        }
        return 'Phone reCAPTCHA failed on web. Add a Firebase test phone number, use the Android app, or switch to Email.';
      case 'phone_otp_desktop_unsupported':
        return l10n.phoneOtpDesktopUnavailable;
      default:
        final details = error.details?.trim();
        if (details != null && details.isNotEmpty) {
          return details;
        }
        if (kDebugMode) {
          return '${l10n.authUnknown} (${error.code})';
        }
        return l10n.authUnknown;
    }
  }
  if (kDebugMode) {
    final text = error.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return l10n.authUnknown;
}
