import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/lecture_feedback.dart';
import '../../models/lecture_model.dart';
import '../../models/user_model.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/user_avatar.dart';
import 'understanding_level_style.dart';

class TeacherStudentProfileScreen extends StatelessWidget {
  const TeacherStudentProfileScreen({
    super.key,
    required this.student,
    required this.feedback,
    required this.lecture,
  });

  final UserModel student;
  final LectureFeedback feedback;
  final LectureModel lecture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final name = student.fullName.trim().isEmpty
        ? (feedback.studentName.trim().isEmpty
              ? l10n.student
              : feedback.studentName)
        : student.fullName;
    final email = student.email.trim().isNotEmpty
        ? student.email.trim()
        : feedback.studentEmail.trim();
    final visual = understandingLevelVisual(l10n, feedback.level);
    final topic = lecture.topicTitle.trim().isEmpty
        ? lecture.chapterTitle
        : lecture.topicTitle;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          l10n.studentProfileTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
        children: [
          Material(
            color: brightness == Brightness.dark
                ? AppColors.darkSurface
                : Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Column(
                children: [
                  UserAvatar(name: name, photoUrl: student.photoUrl, radius: 36),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: brightness == Brightness.dark
                ? AppColors.darkSurface
                : Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.thisLectureUnderstanding,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  if (topic.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      topic,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: visual.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(visual.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visual.percent,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: visual.color,
                                ),
                              ),
                              Text(
                                visual.hint,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary(brightness),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
