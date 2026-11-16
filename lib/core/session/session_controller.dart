import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../models/user_role.dart';

class SessionController extends ChangeNotifier {
  UserModel? _user;
  String? _connectedTeacherId;
  String? _connectedTeacherEmail;
  String? _connectedTeacherName;
  String? _understandingLevel;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isTeacher => _user?.role == UserRole.teacher;
  bool get isStudent => _user?.role == UserRole.student;
  String? get connectedTeacherId => _connectedTeacherId;
  String? get connectedTeacherEmail => _connectedTeacherEmail;
  String? get connectedTeacherName => _connectedTeacherName;
  bool get hasTeacherLink =>
      (_connectedTeacherId != null && _connectedTeacherId!.isNotEmpty) ||
      (_connectedTeacherEmail != null && _connectedTeacherEmail!.isNotEmpty);
  String? get understandingLevel => _understandingLevel;

  void signIn(UserModel user) {
    _user = user;
    _connectedTeacherId = user.connectedTeacherId;
    _connectedTeacherEmail = user.connectedTeacherEmail;
    _connectedTeacherName = user.connectedTeacherName;
    _understandingLevel = user.understandingLevel;
    notifyListeners();
  }

  void updateUser(UserModel user) {
    _user = user;
    _connectedTeacherId = user.connectedTeacherId;
    _connectedTeacherEmail = user.connectedTeacherEmail;
    _connectedTeacherName = user.connectedTeacherName;
    _understandingLevel = user.understandingLevel;
    notifyListeners();
  }

  void connectTeacher({
    required String email,
    required String name,
    String? id,
  }) {
    _connectedTeacherId = id;
    _connectedTeacherEmail = email;
    _connectedTeacherName = name;
    _user = _user?.copyWith(
      connectedTeacherId: id,
      connectedTeacherEmail: email,
      connectedTeacherName: name,
    );
    notifyListeners();
  }

  void selectUnderstanding(String level) {
    _understandingLevel = level;
    notifyListeners();
  }

  void disconnectTeacher() {
    _connectedTeacherId = null;
    _connectedTeacherEmail = null;
    _connectedTeacherName = null;
    _understandingLevel = null;
    _user = _user?.copyWith(clearTeacherLink: true);
    notifyListeners();
  }

  void signOut() {
    _user = null;
    _connectedTeacherId = null;
    _connectedTeacherEmail = null;
    _connectedTeacherName = null;
    _understandingLevel = null;
    notifyListeners();
  }
}
