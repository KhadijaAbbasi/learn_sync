import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../constants/app_routes.dart';
import '../di/app_scope.dart';

void openDashboard(BuildContext context, UserModel user) {
  final scope = AppScope.of(context);
  scope.sessionController.signIn(user);
  scope.courseStore.watchTeacher(
    user.role == UserRole.teacher ? user.id : user.connectedTeacherId,
  );
  final route = user.role == UserRole.teacher
      ? AppRoutes.teacherDashboard
      : AppRoutes.studentDashboard;
  Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
}

Future<void> openLogin(BuildContext context) async {
  final scope = AppScope.of(context);
  await scope.authService.signOut();
  scope.courseStore.watchTeacher(null);
  scope.sessionController.signOut();
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
}

Future<void> confirmLogout(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.logout),
      content: Text(l10n.logoutConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.logout),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await openLogin(context);
  }
}

void openProfileSettings(BuildContext context) {
  final name = ModalRoute.of(context)?.settings.name;
  if (name == AppRoutes.profile) {
    return;
  }
  Navigator.of(context).pushNamed(AppRoutes.profile);
}

void openHomeDashboard(BuildContext context) {
  final name = ModalRoute.of(context)?.settings.name;
  if (name == AppRoutes.teacherDashboard ||
      name == AppRoutes.studentDashboard) {
    return;
  }
  if (name == AppRoutes.profile && Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }
  final user = AppScope.of(context).sessionController.user;
  if (user == null) {
    openLogin(context);
    return;
  }
  final route = user.role == UserRole.teacher
      ? AppRoutes.teacherDashboard
      : AppRoutes.studentDashboard;
  Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
}
