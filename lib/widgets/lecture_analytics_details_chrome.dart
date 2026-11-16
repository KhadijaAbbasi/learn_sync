import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/theme/app_colors.dart';
import '../models/lecture_model.dart';
import 'category_share_bar_chart.dart';
import 'user_avatar.dart';

String lectureChapterLine(AppLocalizations l10n, LectureModel lecture) {
  final chapter = lecture.chapterTitle.trim();
  final topic = lecture.topicTitle.trim();
  if (chapter.isNotEmpty && topic.isNotEmpty) {
    return '$chapter: $topic';
  }
  if (chapter.isNotEmpty) {
    return chapter;
  }
  return topic.isNotEmpty ? topic : l10n.lectureAnalytics;
}

String lectureStudentDisplayId({
  String memberId = '',
  String studentId = '',
}) {
  final member = memberId.trim();
  if (member.isNotEmpty) {
    return member;
  }
  return studentId.trim();
}

class LectureAnalyticsHeaderCard extends StatelessWidget {
  const LectureAnalyticsHeaderCard({
    super.key,
    required this.courseName,
    required this.courseCode,
    required this.semester,
    required this.chapterLine,
    required this.completed,
    required this.completedLabel,
    required this.liveLabel,
    required this.dateLabel,
    required this.timeLabel,
  });

  final String courseName;
  final String courseCode;
  final String semester;
  final String chapterLine;
  final bool completed;
  final String completedLabel;
  final String liveLabel;
  final String dateLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseName,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (courseCode.trim().isNotEmpty)
                            _Chip(text: courseCode, filled: true),
                          if (semester.trim().isNotEmpty)
                            _Chip(
                              text: semester,
                              color: const Color(0xFF4A90C8),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        chapterLine,
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (completed ? const Color(0xFF2E9B5A) : AppColors.coral)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completed
                            ? Icons.check_circle_rounded
                            : Icons.podcasts_rounded,
                        size: 14,
                        color: completed
                            ? const Color(0xFF2E9B5A)
                            : AppColors.coral,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        completed ? completedLabel : liveLabel,
                        style: TextStyle(
                          color: completed
                              ? const Color(0xFF2E9B5A)
                              : AppColors.coral,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _Meta(icon: Icons.calendar_today_outlined, text: dateLabel),
                _Meta(icon: Icons.schedule_outlined, text: timeLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LectureDetailsOverviewCard extends StatelessWidget {
  const LectureDetailsOverviewCard({
    super.key,
    required this.title,
    required this.bars,
    required this.selectedId,
    required this.onSelect,
    required this.countLabel,
    required this.totalLabel,
    required this.totalValue,
    required this.barKeyPrefix,
  });

  final String title;
  final List<CategoryBarData> bars;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String Function(int count) countLabel;
  final String totalLabel;
  final String totalValue;
  final String barKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 14),
            CategoryShareBarChart(
              bars: bars,
              selectedId: selectedId,
              onSelect: onSelect,
              countLabel: countLabel,
              keyPrefix: barKeyPrefix,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: brightness == Brightness.dark
                    ? AppColors.darkBackground
                    : const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    color: AppColors.teal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      totalLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                  Text(
                    totalValue,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LectureDetailsSearchField extends StatelessWidget {
  const LectureDetailsSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: AppColors.textPrimary(brightness),
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
      ),
    );
  }
}

class LectureCategoryHeading extends StatelessWidget {
  const LectureCategoryHeading({
    super.key,
    required this.title,
    required this.categoryLabel,
    required this.categoryColor,
  });

  final String title;
  final String categoryLabel;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        if (categoryLabel.trim().isNotEmpty) ...[
          Text(
            '·',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          Text(
            categoryLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: categoryColor,
            ),
          ),
        ],
      ],
    );
  }
}

class LectureStudentListTile extends StatelessWidget {
  const LectureStudentListTile({
    super.key,
    required this.name,
    required this.studentId,
    required this.onTap,
  });

  final String name;
  final String studentId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                UserAvatar(name: name, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      if (studentId.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          studentId.trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(brightness),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.filled = false, this.color});

  final String text;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.teal : tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? Colors.white : tone,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.teal),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(Theme.of(context).brightness),
            ),
          ),
        ),
      ],
    );
  }
}


class TeacherAnalyticsScopeHeaderCard extends StatelessWidget {
  const TeacherAnalyticsScopeHeaderCard({
    super.key,
    required this.courseLabel,
    required this.dateLabel,
    this.icon = Icons.menu_book_rounded,
    this.iconColor = AppColors.teal,
  });

  final String courseLabel;
  final String dateLabel;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
