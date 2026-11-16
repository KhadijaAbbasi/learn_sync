import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/course_model.dart';

enum CourseJoinTag { none, requestSent, joined }

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.subtitle,
    this.onTap,
    this.onDelete,
    this.joinTag = CourseJoinTag.none,
    this.requestSentLabel = 'Request sent',
    this.joinedLabel = 'Course joined',
  });

  final CourseModel course;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final CourseJoinTag joinTag;
  final String requestSentLabel;
  final String joinedLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Material(
      color: AppColors.fieldFill(brightness),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: joinTag == CourseJoinTag.joined
                      ? AppColors.teal.withValues(alpha: 0.22)
                      : AppColors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  course.name.trim().isNotEmpty
                      ? course.name.trim()[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: joinTag == CourseJoinTag.joined
                        ? AppColors.tealDark
                        : AppColors.teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (course.code.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course.code,
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary(brightness),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.textSecondary(brightness),
                  ),
                )
              else if (joinTag == CourseJoinTag.joined)
                _StatusPill(
                  label: joinedLabel,
                  foreground: AppColors.tealDark,
                  background: AppColors.teal.withValues(alpha: 0.16),
                )
              else if (joinTag == CourseJoinTag.requestSent)
                _StatusPill(
                  label: requestSentLabel,
                  foreground: AppColors.navy,
                  background: AppColors.navy.withValues(alpha: 0.10),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary(brightness),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
