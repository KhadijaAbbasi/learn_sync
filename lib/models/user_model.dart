import 'user_role.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.memberId = '',
    this.connectedTeacherId,
    this.connectedTeacherEmail,
    this.connectedTeacherName,
    this.understandingLevel,
    this.photoUrl = '',
    this.phone = '',
    this.phoneCountry = 'US',
    this.gender = '',
    this.bio = '',
    this.officeTiming = '',
    this.officeNumber = '',
    this.country = '',
    this.department = '',
    this.university = '',
    this.enrollmentYear = '',
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String memberId;
  final String? connectedTeacherId;
  final String? connectedTeacherEmail;
  final String? connectedTeacherName;
  final String? understandingLevel;
  final String photoUrl;
  final String phone;
  final String phoneCountry;
  final String gender;
  final String bio;
  final String officeTiming;
  final String officeNumber;
  final String country;
  final String department;
  final String university;
  final String enrollmentYear;

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    final rawRole = data['role'];
    final roleName = rawRole is String ? rawRole : rawRole?.toString();
    return UserModel(
      id: id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.parse(roleName),
      memberId: (data['memberId'] as String? ??
              data['studentId'] as String? ??
              data['teacherMemberId'] as String? ??
              '')
          .trim(),
      connectedTeacherId: data['connectedTeacherId'] as String?,
      connectedTeacherEmail: data['connectedTeacherEmail'] as String?,
      connectedTeacherName: data['connectedTeacherName'] as String?,
      understandingLevel: data['understandingLevel'] as String?,
      photoUrl: data['photoUrl'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      phoneCountry: data['phoneCountry'] as String? ?? 'US',
      gender: data['gender'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      officeTiming: data['officeTiming'] as String? ?? '',
      officeNumber: data['officeNumber'] as String? ?? '',
      country: data['country'] as String? ?? '',
      department: data['department'] as String? ?? '',
      university: data['university'] as String? ?? '',
      enrollmentYear: data['enrollmentYear'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'emailLower': email.toLowerCase(),
      'nameLower': fullName.trim().toLowerCase(),
      'role': role.name,
      'memberId': memberId,
      'memberIdLower': memberId.trim().toLowerCase(),
      'studentId': role == UserRole.student ? memberId : null,
      'teacherMemberId': role == UserRole.teacher ? memberId : null,
      'connectedTeacherId': connectedTeacherId,
      'connectedTeacherEmail': connectedTeacherEmail,
      'connectedTeacherName': connectedTeacherName,
      'understandingLevel': understandingLevel,
      'photoUrl': photoUrl,
      'phone': phone,
      'phoneCountry': phoneCountry,
      'gender': gender,
      'bio': bio,
      'officeTiming': officeTiming,
      'officeNumber': officeNumber,
      'country': country,
      'department': department,
      'university': university,
      'enrollmentYear': enrollmentYear,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map.removeWhere((_, value) => value == null);
    map['uid'] = id;
    return map;
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    String? memberId,
    String? connectedTeacherId,
    String? connectedTeacherEmail,
    String? connectedTeacherName,
    String? understandingLevel,
    String? photoUrl,
    String? phone,
    String? phoneCountry,
    String? gender,
    String? bio,
    String? officeTiming,
    String? officeNumber,
    String? country,
    String? department,
    String? university,
    String? enrollmentYear,
    bool clearTeacherLink = false,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      memberId: memberId ?? this.memberId,
      connectedTeacherId: clearTeacherLink
          ? null
          : (connectedTeacherId ?? this.connectedTeacherId),
      connectedTeacherEmail: clearTeacherLink
          ? null
          : (connectedTeacherEmail ?? this.connectedTeacherEmail),
      connectedTeacherName: clearTeacherLink
          ? null
          : (connectedTeacherName ?? this.connectedTeacherName),
      understandingLevel: understandingLevel ?? this.understandingLevel,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      phoneCountry: phoneCountry ?? this.phoneCountry,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      officeTiming: officeTiming ?? this.officeTiming,
      officeNumber: officeNumber ?? this.officeNumber,
      country: country ?? this.country,
      department: department ?? this.department,
      university: university ?? this.university,
      enrollmentYear: enrollmentYear ?? this.enrollmentYear,
    );
  }
}
