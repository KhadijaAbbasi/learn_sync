// ═══════════════════════════════════════════════════════════════
// NOTHING here removes or changes an existing AuthService method.
// Everything below is a pure ADDITION.
// ═══════════════════════════════════════════════════════════════

// 1) signUp() needs an optional `phone` parameter alongside the
//    existing `email` one (keep `email` optional too, so an
//    email-only call still works exactly as before):
//
//    Future<void> signUp({
//      required String fullName,
//      String? email,              // unchanged, still optional-safe
//      String? phone,              // NEW
//      required String memberId,
//      required UserRole role,
//      required String password,
//    });
//
//    Inside the implementation: if `phone` is provided, create the
//    account with phone as the identifier and trigger an SMS OTP
//    instead of the email verification link.

// 2) login() — NO signature change needed. `emailOrUsername` can
//    keep accepting the phone string ("+923001234567") as-is as
//    long as your backend/Firebase lookup supports matching by
//    phone too.

// 3) NEW methods for phone OTP verification (separate from the
//    existing email methods — those stay untouched):
//
//    Future<void> verifySignupPhoneOtp({
//      required String phone,
//      required String otp,
//    });
//    // Must throw AuthException(code: AuthException.invalidOtp)
//    // on a wrong code.
//
//    Future<void> resendSignupPhoneOtp({required String phone});

// 4) NEW getter, parallel to the existing `isCurrentEmailVerified`:
//
//    bool get isCurrentPhoneVerified;

// 5) User model — if it doesn't already have a `phone` field, add:
//
//    final String? phone;

// ── Add to AuthException (core/utils/auth_errors.dart) ──
//    static const String invalidOtp = 'invalid-otp';
//    static const String otpExpired = 'otp-expired';
//
//    // in authErrorMessage(l10n, error):
//    if (error.code == AuthException.invalidOtp) return l10n.otpInvalidCode;
//    if (error.code == AuthException.otpExpired) return l10n.otpExpiredCode;

// ── New l10n keys to add (.arb files) ──
//   "phoneNumber": "Phone Number"
//   "invalidPhoneNumber": "Enter a valid phone number"
//   "verify": "Verify"
//   "otpSentToPhone": "We sent a code to {contact}"
//   "otpSmsSent": "A new code was sent to {contact}"
//   "otpInvalidLength": "Enter the 6-digit code"
//   "otpAttemptsRemaining": "{count} attempts remaining"
//   "otpAttemptsExhausted": "Too many attempts. Please resend the code."
//   "otpInvalidWithAttempts": "Invalid code. {count} attempts left"
//   "resendInSeconds": "Resend in {seconds}s"
//   "otpInvalidCode": "The code you entered is incorrect"
//   "otpExpiredCode": "This code has expired, please resend"
//
// Existing keys (verifyEmailTitle, verifyEmailBody, otpEmailSent,
// resendOtp, otpSending, didntReceiveCode, emailVerifiedPleaseLogin,
// userAlreadyExistsTitle/Body, ok) are reused as-is — no changes.
