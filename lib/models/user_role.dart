enum UserRole {
  teacher,
  student;

  static UserRole parse(String? value, {UserRole fallback = UserRole.student}) {
    final name = value?.trim().toLowerCase();
    for (final role in UserRole.values) {
      if (role.name == name) {
        return role;
      }
    }
    return fallback;
  }
}
