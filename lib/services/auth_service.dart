import 'dart:math';
import '../models/user_model.dart';
import '../models/user_role.dart';

class AuthException implements Exception {
  const AuthException(this.code, [this.details]);

  static const String emailAlreadyInUse = 'email_in_use';
  static const String invalidOtp = 'invalid_otp';
  static const String idInUse = 'id_in_use';
  static const String phoneAlreadyInUse = 'phone_in_use';
  static const String invalidPhoneNumber = 'invalid_phone_number';

  final String code;
  final String? details;

  @override
  String toString() => details ?? code;
}

String normalizeMemberId(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

String normalizeAuthEmail(String email) {
  return email
      .trim()
      .replaceAll(RegExp(r'[\s\u00A0\u2007\u202F]+'), '')
      .toLowerCase();
}

class _StoredAccount {
  const _StoredAccount({required this.user, required this.password});

  final UserModel user;
  final String password;
}

abstract class AuthService {
  bool get showDemoHint => false;

  Future<UserModel> login({
    required String emailOrUsername,
    required String password,
  });

  // 🔧 CHANGED: `email` is now optional and `phone` was added, so a
  // signup can be completed with either one. Exactly one of the two
  // must be provided by the caller — implementations should validate
  // this. Every other parameter is unchanged.
  Future<UserModel> signUp({
    required String fullName,
    String? email, // was: required String email
    String? phone, // NEW
    required String memberId,
    required UserRole role,
    required String password,
  });

  Future<UserModel?> restoreSession();

  Future<void> signOut();

  Future<UserModel> linkTeacher({required String query});

  Future<UserModel> unlinkTeacher();

  Future<void> sendPasswordReset({required String email});

  Future<void> resendSignupVerification();

  Future<UserModel?> checkSignupEmailVerified();

  bool get isCurrentEmailVerified;

  // ── NEW: phone-signup OTP verification, parallel to the email flow ──

  /// Verifies the 6-digit SMS code entered on the phone OTP screen.
  /// Must throw `AuthException(AuthException.invalidOtp)` on a wrong code.
  Future<void> verifySignupPhoneOtp({
    required String phone,
    required String otp,
  });

  /// Sends a fresh SMS OTP to [phone].
  Future<void> resendSignupPhoneOtp({required String phone});

  /// Starts password-reset SMS OTP for an existing phone account.
  Future<void> startPasswordResetPhoneOtp({required String phone});

  /// Verifies password-reset SMS OTP (signs the user in briefly).
  Future<void> verifyPasswordResetPhoneOtp({
    required String phone,
    required String otp,
  });

  /// Sets a new password after a successful phone reset OTP, then signs out.
  Future<void> completePasswordResetWithNewPassword({
    required String newPassword,
  });

  /// Mirrors [isCurrentEmailVerified] for phone-based accounts.
  bool get isCurrentPhoneVerified;

  Future<bool> get requiresLoginAfterSignup;

  Future<UserModel> updateProfile(UserModel user);

  Future<String> saveAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  });

  Future<List<int>?> loadAvatarBytes(String photoUrl);

  Future<void> deleteAccount();

  /// Load another user's public profile by id (teacher read-only views).
  Future<UserModel?> fetchUserById(String userId);
}

/// In-memory auth used by the app and widget tests.
class MockAuthService implements AuthService {
  MockAuthService() {
    _accounts['teacher@learnsync.app'] = const _StoredAccount(
      user: UserModel(
        id: 'demo-teacher',
        fullName: 'Demo Teacher',
        email: 'teacher@learnsync.app',
        role: UserRole.teacher,
        memberId: 'T-1000',
      ),
      password: 'Demo@123',
    );
    _accounts['student@learnsync.app'] = const _StoredAccount(
      user: UserModel(
        id: 'demo-student',
        fullName: 'Demo Student',
        email: 'student@learnsync.app',
        role: UserRole.student,
        memberId: 'S-1000',
      ),
      password: 'Demo@123',
    );
  }

  @override
  bool get showDemoHint => true;

  static const _delay = Duration(milliseconds: 500);
  final Map<String, _StoredAccount> _accounts = {};
  final Set<String> _memberIds = {'t-1000', 's-1000'};
  UserModel? _current;
  bool _mustLoginAfterSignup = false;

  // ── NEW: mock phone-OTP state (does not affect anything above) ──
  bool _phoneVerified = false;
  final Map<String, String> _pendingPhoneOtp = {};

  String _randomOtp() {
    final n = Random().nextInt(1000000);
    return n.toString().padLeft(6, '0');
  }

  @override
  Future<UserModel> login({
    required String emailOrUsername,
    required String password,
  }) async {
    // 🔒 UNCHANGED — works for phone identifiers too, since this is just
    // generic string normalization, not email-specific validation.
    await Future<void>.delayed(_delay);
    final key = normalizeAuthEmail(emailOrUsername);
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw const AuthException('invalid_credentials');
    }
    _current = account.user;
    _mustLoginAfterSignup = false;
    return account.user;
  }

  @override
  Future<UserModel> signUp({
    required String fullName,
    String? email,
    String? phone,
    required String memberId,
    required UserRole role,
    required String password,
  }) async {
    assert(
      (email != null) ^ (phone != null),
      'Provide exactly one of email or phone',
    );
    await Future<void>.delayed(_delay);

    final bool isPhoneSignup = email == null;
    final String key = normalizeAuthEmail(isPhoneSignup ? phone! : email);

    if (_accounts.containsKey(key)) {
      throw AuthException(
        isPhoneSignup
            ? AuthException.phoneAlreadyInUse
            : AuthException.emailAlreadyInUse,
      );
    }
    final normalizedId = normalizeMemberId(memberId);
    if (normalizedId.isEmpty || _memberIds.contains(normalizedId)) {
      throw const AuthException(AuthException.idInUse);
    }

    final user = UserModel(
      id: 'mock-$key',
      fullName: fullName.trim(),
      // 🔧 NOTE: assumes UserModel has an optional `phone` field.
      // If it doesn't yet, add: `final String? phone;` to UserModel
      // (see auth_service_todo.dart from earlier for the full list).
      email: isPhoneSignup ? '' : key,
      phone: phone ?? '',
      role: role,
      memberId: memberId.trim(),
    );
    _memberIds.add(normalizedId);
    _accounts[key] = _StoredAccount(user: user, password: password);
    _current = user;
    _mustLoginAfterSignup = true;

    if (isPhoneSignup) {
      _phoneVerified = false;
      _pendingPhoneOtp[key] = _randomOtp();
    }
    return user;
  }

  @override
  Future<UserModel?> restoreSession() async => _current;

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<UserModel> linkTeacher({required String query}) async {
    await Future<void>.delayed(_delay);
    final current = _current;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    final needle = query.trim().toLowerCase();
    for (final account in _accounts.values) {
      final user = account.user;
      if (user.role != UserRole.teacher) {
        continue;
      }
      if (user.email.toLowerCase() == needle ||
          user.fullName.toLowerCase() == needle) {
        final linked = current.copyWith(
          connectedTeacherId: user.id,
          connectedTeacherEmail: user.email,
          connectedTeacherName: user.fullName,
        );
        _current = linked;
        _accounts[current.email] = _StoredAccount(
          user: linked,
          password: _accounts[current.email]!.password,
        );
        return linked;
      }
    }
    throw const AuthException('teacher_not_found');
  }

  @override
  Future<UserModel> unlinkTeacher() async {
    await Future<void>.delayed(_delay);
    final current = _current;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    final linked = current.copyWith(clearTeacherLink: true);
    _current = linked;
    _accounts[current.email] = _StoredAccount(
      user: linked,
      password: _accounts[current.email]!.password,
    );
    return linked;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await Future<void>.delayed(_delay);
    final key = normalizeAuthEmail(email);
    if (!_accounts.containsKey(key)) {
      throw const AuthException('account_not_found');
    }
  }

  @override
  Future<void> resendSignupVerification() async {
    await Future<void>.delayed(_delay);
  }

  @override
  Future<UserModel?> checkSignupEmailVerified() async {
    await Future<void>.delayed(_delay);
    return _current;
  }

  @override
  bool get isCurrentEmailVerified => _current != null;

  // ── NEW: phone OTP methods (mock) ──

  @override
  Future<void> verifySignupPhoneOtp({
    required String phone,
    required String otp,
  }) async {
    await Future<void>.delayed(_delay);
    final key = normalizeAuthEmail(phone);
    final expected = _pendingPhoneOtp[key];
    if (expected == null || expected != otp.trim()) {
      throw const AuthException(AuthException.invalidOtp);
    }
    _phoneVerified = true;
    _pendingPhoneOtp.remove(key);
  }

  @override
  Future<void> resendSignupPhoneOtp({required String phone}) async {
    await Future<void>.delayed(_delay);
    final key = normalizeAuthEmail(phone);
    _pendingPhoneOtp[key] = _randomOtp();
  }

  final Set<String> _passwordResetPhones = {};

  @override
  Future<void> startPasswordResetPhoneOtp({required String phone}) async {
    await Future<void>.delayed(_delay);
    final key = normalizeAuthEmail(phone);
    final account = _accounts[key];
    if (account == null) {
      throw const AuthException('account_not_found');
    }
    _passwordResetPhones.add(key);
    _pendingPhoneOtp[key] = _randomOtp();
  }

  @override
  Future<void> verifyPasswordResetPhoneOtp({
    required String phone,
    required String otp,
  }) async {
    await Future<void>.delayed(_delay);
    final key = normalizeAuthEmail(phone);
    if (!_passwordResetPhones.contains(key)) {
      throw const AuthException(AuthException.invalidOtp);
    }
    final expected = _pendingPhoneOtp[key];
    if (expected == null || expected != otp.trim()) {
      throw const AuthException(AuthException.invalidOtp);
    }
    _pendingPhoneOtp.remove(key);
    _current = _accounts[key]!.user;
  }

  @override
  Future<void> completePasswordResetWithNewPassword({
    required String newPassword,
  }) async {
    await Future<void>.delayed(_delay);
    final current = _current;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    final emailKey = normalizeAuthEmail(
      current.email.isNotEmpty ? current.email : current.phone,
    );
    final existing = _accounts[emailKey];
    if (existing == null) {
      throw const AuthException('account_not_found');
    }
    _accounts[emailKey] = _StoredAccount(user: existing.user, password: newPassword);
    // Also update phone-keyed entry if present.
    final phoneKey = normalizeAuthEmail(current.phone);
    if (phoneKey.isNotEmpty && _accounts.containsKey(phoneKey)) {
      _accounts[phoneKey] = _StoredAccount(user: existing.user, password: newPassword);
    }
    _current = null;
    _passwordResetPhones.clear();
  }

  @override
  bool get isCurrentPhoneVerified => _phoneVerified;

  @override
  Future<bool> get requiresLoginAfterSignup async => _mustLoginAfterSignup;

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    await Future<void>.delayed(_delay);
    final current = _current;
    if (current == null || current.id != user.id) {
      throw const AuthException('invalid_credentials');
    }
    _current = user;
    final password = _accounts[current.email]?.password ?? '';
    _accounts[user.email] = _StoredAccount(user: user, password: password);
    return user;
  }

  @override
  Future<UserModel?> fetchUserById(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) {
      return null;
    }
    if (_current?.id == id) {
      return _current;
    }
    for (final account in _accounts.values) {
      if (account.user.id == id) {
        return account.user;
      }
    }
    return _directory[id];
  }

  /// Test helper so widget tests can resolve a student profile by id.
  void seedUser(UserModel user) {
    _directory[user.id] = user;
    final email = user.email.trim();
    if (email.isNotEmpty) {
      _accounts.putIfAbsent(
        normalizeAuthEmail(email),
        () => _StoredAccount(user: user, password: ''),
      );
    }
  }

  final Map<String, UserModel> _directory = {};

  @override
  Future<String> saveAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    await Future<void>.delayed(_delay);
    final key = 'memory:$userId';
    _avatars[key] = List<int>.from(bytes);
    return key;
  }

  @override
  Future<List<int>?> loadAvatarBytes(String photoUrl) async {
    return _avatars[photoUrl];
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(_delay);
    final current = _current;
    if (current == null) {
      throw const AuthException('invalid_credentials');
    }
    _accounts.remove(current.email);
    _memberIds.remove(normalizeMemberId(current.memberId));
    _avatars.remove('memory:${current.id}');
    _current = null;
  }

  final Map<String, List<int>> _avatars = {};
}
