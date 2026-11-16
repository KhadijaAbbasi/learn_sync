import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../models/user_role.dart';
import '../core/utils/validators.dart';
import 'auth_service.dart';
import 'windows_callable_client.dart';

// NEW — small holder for signup details while we wait for the user
// to type the SMS code. Not persisted; lives only in memory for the
// duration of the phone-signup flow.
class _PendingPhoneSignup {
  _PendingPhoneSignup({
    required this.fullName,
    required this.memberId,
    required this.role,
    required this.password,
  });

  final String fullName;
  final String memberId;
  final UserRole role;
  final String password;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  bool get showDemoHint => false;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ── NEW: phone-signup state (separate from everything else) ──
  final Map<String, String> _phoneVerificationIds = {};
  final Map<String, int> _phoneResendTokens = {};
  final Map<String, String> _passwordResetVerificationIds = {};
  final Map<String, int> _passwordResetResendTokens = {};
  final Map<String, ConfirmationResult> _passwordResetConfirmationResults = {};
  final Set<String> _passwordResetPhones = {};
  final Map<String, ConfirmationResult> _phoneConfirmationResults = {};
  final Map<String, _PendingPhoneSignup> _pendingPhoneSignups = {};

  bool _looksLikeEmail(String value) => value.contains('@');

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Object?> _callFunction(
    String name,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return WindowsCallableClient(
        projectId: _auth.app.options.projectId,
        idToken: () async => _auth.currentUser?.getIdToken(),
      ).call(name, data, requireAuth: requireAuth);
    }
    return (await _functions.httpsCallable(name).call(data)).data;
  }

  Future<void> _setPhonePasswordRemote(String password) async {
    await _callFunction('setPhonePassword', {'password': password});
  }

  Future<UserModel> _signInWithPhonePassword({
    required String phone,
    required String password,
  }) async {
    final data = await _callFunction(
      'signInWithPhonePassword',
      <String, dynamic>{'phone': phone, 'password': password},
      requireAuth: false,
    );
    final token = data is Map ? data['token'] as String? : null;
    if (token == null || token.isEmpty) {
      throw const AuthException('invalid_credentials');
    }
    final credential = await _auth.signInWithCustomToken(token);
    final user = credential.user;
    if (user == null) {
      throw const AuthException('invalid_credentials');
    }
    await user.getIdToken(true);
    return _readOrCreateProfile(user);
  }

  @override
  Future<UserModel> login({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final trimmed = emailOrUsername.trim();
      if (!_looksLikeEmail(trimmed)) {
        final phone = trimmed.startsWith('+')
            ? trimmed
            : Validators.normalizePhone(trimmed);
        try {
          return await _signInWithPhonePassword(
            phone: phone,
            password: password,
          );
        } on FirebaseFunctionsException catch (error) {
          throw _mapFunctionsError(error);
        }
      }

      final email = normalizeAuthEmail(trimmed);
      try {
        return await _signInAndLoadProfile(email, password);
      } on FirebaseAuthException catch (error) {
        final staleSession =
            _auth.currentUser != null &&
            (error.code == 'invalid-credential' ||
                error.code == 'invalid-login-credentials' ||
                error.code == 'user-token-expired');
        if (!staleSession) {
          throw _mapAuthError(error);
        }
        await _auth.signOut();
        return await _signInAndLoadProfile(email, password);
      }
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw AuthException('unknown', error.message);
    }
  }

  // 🔒 UNCHANGED
  Future<UserModel> _signInAndLoadProfile(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthException('invalid_credentials');
    }
    await user.getIdToken(true);
    final profile = await _readOrCreateProfile(user);
    if (user.emailVerified) {
      await _setRequiresLoginAfterSignup(false);
    }
    return profile;
  }

  @override
  Future<UserModel> signUp({
    required String fullName,
    String? email, // was: required String email
    String? phone, // NEW
    required String memberId,
    required UserRole role,
    required String password,
  }) async {
    assert(
      (email != null) ^ (phone != null),
      'Provide exactly one of email or phone',
    );

    if (phone != null) {
      // NEW — phone signup path, fully separate from the email path.
      return _signUpWithPhone(
        fullName: fullName,
        phone: phone,
        memberId: memberId,
        role: role,
        password: password,
      );
    }

    // 🔒 UNCHANGED — original email signup, identical to before.
    User? created;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizeAuthEmail(email!),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('unknown');
      }
      created = user;
      await _ensureSignedIn(user);
      final trimmedId = memberId.trim();
      final profile = UserModel(
        id: user.uid,
        fullName: fullName.trim(),
        email: (user.email ?? normalizeAuthEmail(email)),
        role: role,
        memberId: trimmedId,
      );
      await _claimMemberIdAndWriteProfile(user, profile);
      try {
        await user.updateDisplayName(fullName.trim());
        await _persistRole(user, role);
      } on FirebaseAuthException {
        // Profile document is already saved; display name can be updated later.
      }
      try {
        try {
          await user.sendEmailVerification(_verificationSettings());
        } on FirebaseAuthException {
          await user.sendEmailVerification();
        }
      } on FirebaseAuthException catch (error) {
        throw _mapAuthError(error);
      }
      await _setRequiresLoginAfterSignup(true);
      return profile;
    } on AuthException catch (error) {
      if (error.code == AuthException.idInUse && created != null) {
        try {
          await created.delete();
        } on FirebaseAuthException {
          // Account remains; signup is still rejected for the taken ID.
        }
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw AuthException('unknown', error.message);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // NEW — phone signup & OTP verification.
  // ══════════════════════════════════════════════════════════════

  Future<UserModel> _signUpWithPhone({
    required String fullName,
    required String phone,
    required String memberId,
    required UserRole role,
    required String password,
  }) async {
    final normalizedId = normalizeMemberId(memberId);
    if (normalizedId.isEmpty) {
      throw const AuthException(AuthException.idInUse);
    }
    // Do NOT read memberIds here — the user is not signed in yet, and
    // Firestore rules require auth for that collection. The real unique
    // claim runs in _claimMemberIdAndWriteProfile after OTP verifies.
    // Optional soft check only when already signed in (e.g. retries).
    if (_auth.currentUser != null) {
      try {
        final existingId = await _db
            .collection('memberIds')
            .doc(normalizedId)
            .get();
        if (existingId.exists) {
          throw const AuthException(AuthException.idInUse);
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          throw AuthException('unknown', error.message);
        }
      }
    }

    _pendingPhoneSignups[phone] = _PendingPhoneSignup(
      fullName: fullName.trim(),
      memberId: memberId.trim(),
      role: role,
      password: password,
    );

    await resendSignupPhoneOtp(phone: phone); // sends the first SMS code

    // NOTE: signup_screen.dart doesn't use this return value (it just
    // navigates to SignupOtpScreen afterwards), so a lightweight
    // placeholder is fine — the *real* profile is created below in
    // verifySignupPhoneOtp() once the code is confirmed correct.
    return UserModel(
      id: '',
      fullName: fullName.trim(),
      email: '',
      phone: phone,
      role: role,
      memberId: memberId.trim(),
    );
  }

  @override
  Future<void> resendSignupPhoneOtp({required String phone}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      throw const AuthException('phone_otp_desktop_unsupported');
    }
    // Each call requests a fresh SMS code (forceResendToken on mobile).
    if (kIsWeb) {
      try {
        final result = await _auth.signInWithPhoneNumber(phone);
        _phoneConfirmationResults[phone] = result;
      } on FirebaseAuthException catch (error) {
        throw _mapAuthError(error);
      }
      return;
    }

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _phoneResendTokens[phone],
      verificationCompleted: (credential) async {
        try {
          await _completePhoneSignIn(phone, credential);
        } catch (_) {}
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(_mapAuthError(error));
        }
      },
      codeSent: (verificationId, resendToken) {
        _phoneVerificationIds[phone] = verificationId;
        if (resendToken != null) {
          _phoneResendTokens[phone] = resendToken;
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _phoneVerificationIds[phone] = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
    return completer.future;
  }

  @override
  Future<void> verifySignupPhoneOtp({
    required String phone,
    required String otp,
  }) async {
    if (kIsWeb) {
      final confirmation = _phoneConfirmationResults[phone];
      if (confirmation == null) {
        throw const AuthException(AuthException.invalidOtp);
      }
      User? webUser;
      try {
        final userCredential = await confirmation.confirm(otp.trim());
        webUser = userCredential.user;
        if (webUser == null) {
          throw const AuthException('unknown');
        }
        await _completePhoneSignInForUser(phone, webUser);
        _phoneConfirmationResults.remove(phone);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'invalid-verification-code' ||
            error.code == 'invalid-verification-id' ||
            error.code == 'session-expired' ||
            error.code == 'code-expired') {
          throw const AuthException(AuthException.invalidOtp);
        }
        throw _mapAuthError(error);
      } on AuthException catch (error) {
        if (error.code == AuthException.idInUse && webUser != null) {
          try {
            await webUser.delete();
          } on FirebaseAuthException {
            // Account remains; signup is still rejected for the taken ID.
          }
        }
        rethrow;
      }
      return;
    }

    final verificationId = _phoneVerificationIds[phone];
    if (verificationId == null) {
      throw const AuthException(AuthException.invalidOtp);
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp.trim(),
    );
    await _completePhoneSignIn(phone, credential);
  }

  Future<void> _completePhoneSignIn(
    String phone,
    PhoneAuthCredential credential,
  ) async {
    User? phoneUser;
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      phoneUser = userCredential.user;
      if (phoneUser == null) {
        throw const AuthException('unknown');
      }
      await _completePhoneSignInForUser(phone, phoneUser);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-verification-code' ||
          error.code == 'invalid-verification-id' ||
          error.code == 'session-expired') {
        throw const AuthException(AuthException.invalidOtp);
      }
      throw _mapAuthError(error);
    } on AuthException catch (error) {
      if (error.code == AuthException.idInUse && phoneUser != null) {
        try {
          await phoneUser.delete();
        } on FirebaseAuthException {
          // Account remains; signup is still rejected for the taken ID.
        }
      }
      rethrow;
    }
  }

  /// Shared finish for mobile credential sign-in and web ConfirmationResult.
  Future<void> _completePhoneSignInForUser(String phone, User phoneUser) async {
    final pending = _pendingPhoneSignups[phone];
    if (pending == null) {
      throw const AuthException('unknown');
    }

    await _ensureSignedIn(phoneUser);
    // Keep phone as phone — never invent a synthetic email identity.
    final profile = UserModel(
      id: phoneUser.uid,
      fullName: pending.fullName,
      email: '',
      phone: phone,
      role: pending.role,
      memberId: pending.memberId,
    );
    await _claimMemberIdAndWriteProfile(phoneUser, profile);
    try {
      await phoneUser.updateDisplayName(pending.fullName);
      await _persistRole(phoneUser, pending.role);
    } on FirebaseAuthException {
      // Profile document is already saved; display name can be updated later.
    }

    try {
      await phoneUser.updatePassword(pending.password);
    } on FirebaseAuthException {
      // Password is still stored via Cloud Function for phone login.
    }
    try {
      await _setPhonePasswordRemote(pending.password);
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsError(error);
    }

    await _setRequiresLoginAfterSignup(true);
    _pendingPhoneSignups.remove(phone);
    _phoneVerificationIds.remove(phone);
  }

  @override
  bool get isCurrentPhoneVerified => _auth.currentUser?.phoneNumber != null;

  // ══════════════════════════════════════════════════════════════
  // 🔒 EVERYTHING BELOW IS UNCHANGED from your original file.
  // ══════════════════════════════════════════════════════════════

  Future<void> _claimMemberIdAndWriteProfile(
    User user,
    UserModel profile,
  ) async {
    final idKey = normalizeMemberId(profile.memberId);
    if (idKey.isEmpty) {
      throw const AuthException(AuthException.idInUse);
    }
    final idRef = _db.collection('memberIds').doc(idKey);
    final userRef = _users.doc(user.uid);
    final emailLower = profile.email.toLowerCase();

    try {
      await _db.runTransaction((transaction) async {
        final existing = await transaction.get(idRef);
        if (existing.exists) {
          final data = existing.data();
          final owner = data?['uid'] as String? ?? '';
          final linkedEmail = (data?['emailLower'] as String? ?? '')
              .toLowerCase();
          final sameOwner = owner == user.uid;
          final sameEmail = linkedEmail == emailLower;
          if (!sameOwner || (linkedEmail.isNotEmpty && !sameEmail)) {
            throw const AuthException(AuthException.idInUse);
          }
        }
        transaction.set(idRef, {
          'uid': user.uid,
          'emailLower': emailLower,
          'memberId': profile.memberId,
          'role': profile.role.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final data = profile.toFirestoreMap();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        transaction.set(userRef, data, SetOptions(merge: true));
      });
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AuthException(AuthException.idInUse);
      }
      throw AuthException('unknown', error.message);
    }
  }

  @override
  Future<UserModel?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    try {
      await user.reload();
      final fresh = _auth.currentUser;
      if (fresh == null) {
        return null;
      }
      return await _readOrCreateProfile(fresh);
    } on FirebaseAuthException {
      await _auth.signOut();
      return null;
    }
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }

  @override
  Future<UserModel> linkTeacher({required String query}) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    final teacher = await _findTeacher(query);
    if (teacher == null || teacher.id == current.uid) {
      throw const AuthException('teacher_not_found');
    }
    await _users.doc(current.uid).set({
      'connectedTeacherId': teacher.id,
      'connectedTeacherEmail': teacher.email,
      'connectedTeacherName': teacher.fullName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final profile = await _readOrCreateProfile(current);
    return profile.copyWith(
      connectedTeacherId: teacher.id,
      connectedTeacherEmail: teacher.email,
      connectedTeacherName: teacher.fullName,
    );
  }

  @override
  Future<UserModel> unlinkTeacher() async {
    final current = _auth.currentUser;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    await _users.doc(current.uid).set({
      'connectedTeacherId': null,
      'connectedTeacherEmail': null,
      'connectedTeacherName': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final profile = await _readOrCreateProfile(current);
    return profile.copyWith(clearTeacherLink: true);
  }

  @override
  Future<void> startPasswordResetPhoneOtp({required String phone}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      throw const AuthException('phone_otp_desktop_unsupported');
    }
    _passwordResetPhones.add(phone);
    if (kIsWeb) {
      try {
        final result = await _auth.signInWithPhoneNumber(phone);
        _passwordResetConfirmationResults[phone] = result;
      } on FirebaseAuthException catch (error) {
        _passwordResetPhones.remove(phone);
        throw _mapAuthError(error);
      }
      return;
    }

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _passwordResetResendTokens[phone],
      verificationCompleted: (credential) async {
        try {
          await _finishPasswordResetPhoneSignIn(phone, credential: credential);
          if (!completer.isCompleted) completer.complete();
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(_mapAuthError(error));
        }
      },
      codeSent: (verificationId, resendToken) {
        _passwordResetVerificationIds[phone] = verificationId;
        if (resendToken != null) {
          _passwordResetResendTokens[phone] = resendToken;
        }
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _passwordResetVerificationIds[phone] = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
    try {
      await completer.future;
    } catch (error) {
      _passwordResetPhones.remove(phone);
      rethrow;
    }
  }

  @override
  Future<void> verifyPasswordResetPhoneOtp({
    required String phone,
    required String otp,
  }) async {
    if (!_passwordResetPhones.contains(phone)) {
      throw const AuthException(AuthException.invalidOtp);
    }
    if (kIsWeb) {
      final confirmation = _passwordResetConfirmationResults[phone];
      if (confirmation == null) {
        throw const AuthException(AuthException.invalidOtp);
      }
      try {
        final cred = await confirmation.confirm(otp.trim());
        final user = cred.user;
        if (user == null) throw const AuthException('unknown');
        await _ensureExistingPhoneAccountOrAbort(user);
        _passwordResetConfirmationResults.remove(phone);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'invalid-verification-code' ||
            error.code == 'invalid-verification-id' ||
            error.code == 'session-expired' ||
            error.code == 'code-expired') {
          throw const AuthException(AuthException.invalidOtp);
        }
        throw _mapAuthError(error);
      }
      return;
    }

    final verificationId = _passwordResetVerificationIds[phone];
    if (verificationId == null) {
      throw const AuthException(AuthException.invalidOtp);
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp.trim(),
    );
    await _finishPasswordResetPhoneSignIn(phone, credential: credential);
  }

  Future<void> _finishPasswordResetPhoneSignIn(
    String phone, {
    required PhoneAuthCredential credential,
  }) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw const AuthException('unknown');
      await _ensureExistingPhoneAccountOrAbort(user);
      _passwordResetVerificationIds.remove(phone);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-verification-code' ||
          error.code == 'invalid-verification-id' ||
          error.code == 'session-expired') {
        throw const AuthException(AuthException.invalidOtp);
      }
      throw _mapAuthError(error);
    }
  }

  Future<void> _ensureExistingPhoneAccountOrAbort(User user) async {
    final profile = await _users.doc(user.uid).get();
    if (!profile.exists) {
      try {
        await user.delete();
      } on FirebaseAuthException {
        await _auth.signOut();
      }
      throw const AuthException('account_not_found');
    }
  }

  @override
  Future<void> completePasswordResetWithNewPassword({
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('invalid_credentials');
    }
    try {
      await user.updatePassword(newPassword);
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        try {
          await _setPhonePasswordRemote(newPassword);
        } on FirebaseFunctionsException catch (error) {
          throw _mapFunctionsError(error);
        }
      }
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } finally {
      _passwordResetPhones.clear();
      await _auth.signOut();
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: normalizeAuthEmail(email));
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        throw const AuthException('account_not_found');
      }
      throw _mapAuthError(error);
    }
  }

  @override
  Future<void> resendSignupVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('invalid_credentials');
    }
    if (user.emailVerified) {
      return;
    }
    try {
      try {
        await user.sendEmailVerification(_verificationSettings());
      } on FirebaseAuthException {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    }
  }

  @override
  Future<UserModel?> checkSignupEmailVerified() async {
    await _applyEmailLinkFromCurrentUri();
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    try {
      await user.reload();
    } on FirebaseAuthException {
      return null;
    }
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) {
      return null;
    }
    return _readOrCreateProfile(fresh);
  }

  @override
  bool get isCurrentEmailVerified => _auth.currentUser?.emailVerified ?? false;

  @override
  Future<bool> get requiresLoginAfterSignup async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_mustLoginPrefKey) ?? false;
  }

  Future<void> _setRequiresLoginAfterSignup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mustLoginPrefKey, value);
  }

  ActionCodeSettings _verificationSettings() {
    final continueUrl = kIsWeb
        ? '${Uri.base.origin}/'
        : 'https://learnsync-bb5e6.firebaseapp.com/';
    return ActionCodeSettings(url: continueUrl, handleCodeInApp: false);
  }

  Future<void> _applyEmailLinkFromCurrentUri() async {
    if (!kIsWeb) {
      return;
    }
    final params = _authLinkParams();
    if (params['mode'] != 'verifyEmail') {
      return;
    }
    final code = params['oobCode'];
    if (code == null || code.isEmpty) {
      return;
    }
    try {
      await _auth.applyActionCode(code);
    } on FirebaseAuthException {
      // Link may already have been consumed in another tab.
    }
  }

  Map<String, String> _authLinkParams() {
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('oobCode')) {
      return uri.queryParameters;
    }
    final hash = uri.fragment;
    final queryIndex = hash.indexOf('?');
    if (queryIndex < 0) {
      return const {};
    }
    return Uri.splitQueryString(hash.substring(queryIndex + 1));
  }

  Future<void> _ensureSignedIn(User user) async {
    try {
      if (_auth.currentUser?.uid != user.uid) {
        await _auth
            .authStateChanges()
            .firstWhere((signedIn) => signedIn?.uid == user.uid)
            .timeout(const Duration(seconds: 8));
      }
    } on TimeoutException {
      // Token fetch below still runs if auth-state is delayed.
    }
    await user.getIdToken(true);
  }

  Future<void> _writeUserProfile(
    User user,
    UserModel profile, {
    required bool isNew,
  }) async {
    await _ensureSignedIn(user);
    final data = profile.toFirestoreMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    FirebaseException? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        await user.getIdToken(true);
      }
      try {
        await _users.doc(user.uid).set(data, SetOptions(merge: true));
        return;
      } on FirebaseException catch (error) {
        lastError = error;
        if (error.code != 'permission-denied' && error.code != 'unavailable') {
          throw AuthException('unknown', error.message);
        }
      }
    }
    throw AuthException(
      'unknown',
      lastError?.message ?? 'Could not save your profile to Firestore.',
    );
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != user.id) {
      throw const AuthException('invalid_credentials');
    }
    await _writeUserProfile(current, user, isNew: false);
    return user;
  }

  @override
  Future<UserModel?> fetchUserById(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return null;
    }
    try {
      final snapshot = await _users.doc(id).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return UserModel.fromMap(snapshot.id, data);
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<String> saveAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != userId) {
      throw const AuthException('invalid_credentials');
    }
    await _ensureSignedIn(current);
    final lower = fileName.toLowerCase();
    final contentType = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
    try {
      await _users.doc(userId).collection('avatar').doc('current').set({
        'data': Blob(Uint8List.fromList(bytes)),
        'name': fileName,
        'contentType': contentType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw AuthException('avatar_upload_failed', error.message);
    }
    return 'firestore://users/$userId/avatar/current';
  }

  @override
  Future<List<int>?> loadAvatarBytes(String photoUrl) async {
    if (!photoUrl.startsWith('firestore://')) {
      return null;
    }
    final path = photoUrl.replaceFirst('firestore://', '');
    try {
      final snapshot = await _db
          .doc(path)
          .get(const GetOptions(source: Source.serverAndCache));
      final blob = snapshot.data()?['data'];
      if (blob is Blob) {
        return blob.bytes;
      }
    } on FirebaseException {
      return null;
    }
    return null;
  }

  @override
  Future<void> deleteAccount() async {
    final current = _auth.currentUser;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    final uid = current.uid;
    try {
      await current.getIdToken(true);
      final courses = await _db
          .collection('courses')
          .where('teacherId', isEqualTo: uid)
          .get();
      for (final course in courses.docs) {
        final files = await course.reference.collection('files').get();
        for (final file in files.docs) {
          final chunks = await file.reference.collection('chunks').get();
          for (final chunk in chunks.docs) {
            await chunk.reference.delete();
          }
          await file.reference.delete();
        }
        await course.reference.delete();
      }

      final memberIds = await _db
          .collection('memberIds')
          .where('uid', isEqualTo: uid)
          .get();
      for (final memberId in memberIds.docs) {
        if (memberId.data()['uid'] == uid) {
          await memberId.reference.delete();
        }
      }

      final avatars = await _users.doc(uid).collection('avatar').get();
      for (final avatar in avatars.docs) {
        await avatar.reference.delete();
      }
      await _users.doc(uid).delete();
      await current.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_rolePrefPrefix$uid');
      await prefs.remove(_mustLoginPrefKey);
    } on FirebaseAuthException catch (error) {
      throw _mapAuthError(error);
    } on FirebaseException catch (error) {
      throw AuthException('account_delete_failed', error.message);
    }
  }

  static const _rolePhotoPrefix = 'https://learnsync.app/role/';
  static const _rolePrefPrefix = 'learnsync_role_';
  static const _mustLoginPrefKey = 'learnsync_must_login_after_signup';

  UserModel _profileFromAuth(User user, UserRole role) {
    return UserModel(
      id: user.uid,
      fullName: user.displayName ?? user.email?.split('@').first ?? 'User',
      email: (user.email ?? '').toLowerCase(),
      role: role,
    );
  }

  Future<UserRole> _resolveRole(User user, {UserRole? firestoreRole}) async {
    if (firestoreRole == UserRole.teacher) {
      return UserRole.teacher;
    }
    final fromAuth = _roleFromPhotoUrl(user.photoURL);
    if (fromAuth == UserRole.teacher) {
      return UserRole.teacher;
    }
    final fromPrefs = await _roleFromPrefs(user.uid);
    if (fromPrefs == UserRole.teacher) {
      return UserRole.teacher;
    }
    if (await _userOwnsCourses(user.uid)) {
      return UserRole.teacher;
    }
    return firestoreRole ?? fromAuth ?? fromPrefs ?? UserRole.student;
  }

  UserRole? _roleFromPhotoUrl(String? url) {
    if (url == null || !url.startsWith(_rolePhotoPrefix)) {
      return null;
    }
    return UserRole.parse(
      url.substring(_rolePhotoPrefix.length),
      fallback: UserRole.student,
    );
  }

  Future<UserRole?> _roleFromPrefs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_rolePrefPrefix$uid');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return UserRole.parse(raw);
  }

  Future<void> _persistRole(User user, UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_rolePrefPrefix${user.uid}', role.name);
    try {
      if (user.photoURL != '$_rolePhotoPrefix${role.name}') {
        await user.updatePhotoURL('$_rolePhotoPrefix${role.name}');
      }
    } on FirebaseAuthException {
      // Role is still stored locally if Auth profile update is blocked.
    }
  }

  Future<bool> _userOwnsCourses(String uid) async {
    try {
      final snapshot = await _db
          .collection('courses')
          .where('teacherId', isEqualTo: uid)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } on FirebaseException {
      return false;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _readUserDoc(
    String uid,
  ) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
      try {
        return await _users.doc(uid).get();
      } on FirebaseException {
        // Retry: Auth token is sometimes not visible to Firestore yet.
      }
    }
    return null;
  }

  Future<UserModel> _readOrCreateProfile(User user) async {
    final snapshot = await _readUserDoc(user.uid);
    UserModel profile;
    if (snapshot != null && snapshot.exists && snapshot.data() != null) {
      profile = UserModel.fromMap(user.uid, snapshot.data()!);
    } else {
      profile = _profileFromAuth(user, await _resolveRole(user));
    }

    final role = await _resolveRole(user, firestoreRole: profile.role);
    if (role != profile.role) {
      profile = profile.copyWith(role: role);
    }

    if (profile.role == UserRole.teacher) {
      await _persistRole(user, profile.role);
    }

    final missingDoc = snapshot == null || !snapshot.exists;
    if (missingDoc || profile.role == UserRole.teacher) {
      await _writeUserProfile(user, profile, isNew: missingDoc);
    }
    return profile;
  }

  Future<UserModel?> _findTeacher(String query) async {
    final needle = query.trim();
    if (needle.isEmpty) {
      return null;
    }
    final lower = needle.toLowerCase();

    Future<UserModel?> matchField(String field, String value) async {
      final snapshot = await _users
          .where(field, isEqualTo: value)
          .limit(8)
          .get();
      for (final doc in snapshot.docs) {
        final user = UserModel.fromMap(doc.id, doc.data());
        if (user.role == UserRole.teacher) {
          return user;
        }
      }
      return null;
    }

    if (needle.contains('@')) {
      final byProfile =
          await matchField('emailLower', lower) ??
          await matchField('email', lower);
      if (byProfile != null) {
        return byProfile;
      }
      final courses = await _db
          .collection('courses')
          .where('teacherEmail', isEqualTo: lower)
          .limit(1)
          .get();
      if (courses.docs.isEmpty) {
        return null;
      }
      final teacherId = courses.docs.first.data()['teacherId'] as String?;
      if (teacherId == null || teacherId.isEmpty) {
        return null;
      }
      final doc = await _users.doc(teacherId).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      return UserModel.fromMap(doc.id, data);
    }

    return await matchField('memberIdLower', lower) ??
        await matchField('nameLower', lower);
  }

  AuthException _mapFunctionsError(FirebaseFunctionsException error) {
    final details = error.details;
    final code = details is String && details.isNotEmpty ? details : error.code;
    switch (code) {
      case 'invalid-credentials':
      case 'permission-denied':
        return const AuthException('invalid_credentials');
      case 'account-not-found':
      case 'not-found':
      case 'password-not-set':
        return const AuthException('account_not_found');
      case 'weak-password':
        return const AuthException('weak_password');
      case 'invalid-phone':
        return const AuthException(AuthException.invalidPhoneNumber);
      default:
        return AuthException('unknown', error.message);
    }
  }

  AuthException _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-disabled':
        return const AuthException('invalid_credentials');
      case 'invalid-email':
        return const AuthException('invalid_email');
      case 'email-already-in-use':
        return const AuthException('email_in_use');
      case 'network-request-failed':
        return const AuthException('network');
      case 'too-many-requests':
        return const AuthException('too_many_requests');
      case 'weak-password':
        return const AuthException('weak_password');
      case 'operation-not-allowed':
        return const AuthException('operation_not_allowed');
      case 'missing-client-identifier':
      case 'invalid-app-credential':
      case 'app-not-authorized':
        // Prefer the Firebase message so the snackbar is actionable.
        return AuthException(
          kIsWeb ? 'phone_auth_web_unsupported' : 'unknown',
          error.message ??
              (kIsWeb
                  ? 'Phone reCAPTCHA failed on web. Add a test phone in Firebase Auth, or try Email signup.'
                  : null),
        );
      // NEW — phone OTP related
      case 'invalid-verification-code':
      case 'invalid-verification-id':
      case 'session-expired':
        return const AuthException(AuthException.invalidOtp);
      case 'credential-already-in-use':
      case 'provider-already-linked':
      case 'phone-number-already-exists':
        return const AuthException(AuthException.phoneAlreadyInUse);
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return const AuthException(AuthException.invalidPhoneNumber);
      default:
        return AuthException('unknown', error.message);
    }
  }
}
