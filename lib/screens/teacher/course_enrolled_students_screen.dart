import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_member.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/user_avatar.dart';
import '../common/profile_settings_screen.dart';

class CourseEnrolledStudentsScreen extends StatelessWidget {
  const CourseEnrolledStudentsScreen({super.key, required this.course});

  final CourseModel course;

  void _openProfile(BuildContext context, CourseMember member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSettingsScreen(
          viewUserId: member.studentId,
          readOnly: true,
          fallbackUser: UserModel(
            id: member.studentId,
            fullName: member.studentName,
            email: member.studentEmail,
            role: UserRole.student,
            memberId: member.memberId,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    CourseMember member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    // Course ownership is keyed by course.teacherId (Firebase uid).
    final teacherId = course.teacherId.trim().isNotEmpty
        ? course.teacherId.trim()
        : (scope.sessionController.user?.id ?? '');
    final name = member.studentName.trim().isEmpty
        ? l10n.student
        : member.studentName.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeEnrolledStudent),
        content: Text(l10n.removeEnrolledStudentConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await scope.enrollment.removeMember(
        courseId: course.id,
        teacherId: teacherId,
        studentId: member.studentId,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.studentRemovedFromCourse(name))),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      debugPrint('removeMember failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.removeEnrolledStudentFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          l10n.enrolledStudents,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<CourseMember>>(
        stream: scope.enrollment.watchMembers(course.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snapshot.data ?? const <CourseMember>[];
          if (members.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        size: 36,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noEnrolledStudentsYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary(brightness),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 28),
            children: [
              Text(
                l10n.enrolledStudentsCount(members.length),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.textSecondary(brightness),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              ...members.map((member) {
                final name = member.studentName.trim().isEmpty
                    ? l10n.student
                    : member.studentName.trim();
                final email = member.studentEmail.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppColors.fieldFill(brightness),
                    elevation: isDark ? 0 : 1.5,
                    shadowColor: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openProfile(context, member),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border(brightness),
                          ),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              name: name,
                              photoUrl: '',
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                      color: AppColors.textPrimary(brightness),
                                    ),
                                  ),
                                  if (email.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary(
                                          brightness,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.tapToViewProfile,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Tooltip(
                              message: l10n.remove,
                              child: IconButton(
                                onPressed: () =>
                                    _confirmRemove(context, member),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      AppColors.coral.withValues(alpha: 0.12),
                                  foregroundColor: AppColors.coral,
                                ),
                                icon: const Icon(
                                  Icons.person_remove_rounded,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
