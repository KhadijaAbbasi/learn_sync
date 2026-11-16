import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/theme/app_colors.dart';
import '../models/course_model.dart';

typedef LectureDaysChanged = void Function(Set<int> days);

class LectureDaysEditor extends StatelessWidget {
  const LectureDaysEditor({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.errorText,
  });

  final Set<int> selectedDays;
  final LectureDaysChanged onChanged;
  final String? errorText;

  static const weekdayIds = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  List<String> _labels(AppLocalizations l10n) => [
        l10n.weekdayMon,
        l10n.weekdayTue,
        l10n.weekdayWed,
        l10n.weekdayThu,
        l10n.weekdayFri,
        l10n.weekdaySat,
        l10n.weekdaySun,
      ];

  void _toggleDay(int day, bool selected) {
    final next = {...selectedDays};
    if (selected) {
      next.add(day);
    } else {
      next.remove(day);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final labels = _labels(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.teal,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.selectLectureDaysLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  Text(
                    l10n.selectMultipleDaysTip,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < weekdayIds.length; i++)
              _DayCheckChip(
                label: labels[i],
                selected: selectedDays.contains(weekdayIds[i]),
                onChanged: (value) => _toggleDay(weekdayIds[i], value),
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

class LectureDaysDisplay extends StatelessWidget {
  const LectureDaysDisplay({
    super.key,
    required this.course,
  });

  final CourseModel course;

  static const weekdayIds = LectureDaysEditor.weekdayIds;

  Set<int> get _selected {
    try {
      if (course.lectureDays.isNotEmpty) {
        return course.lectureDays.toSet();
      }
    } catch (_) {}
    return {for (final slot in course.resolvedLectureSlots) slot.day};
  }

  String _fullDayName(BuildContext context, int day) {
    final now = DateTime.now();
    final delta = (day - now.weekday + 7) % 7;
    final date = now.add(Duration(days: delta));
    return DateFormat.EEEE(
      Localizations.localeOf(context).toString(),
    ).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final selected = [..._selected]..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.lectureDays,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        const SizedBox(height: 10),
        if (selected.isEmpty)
          Text(
            '-',
            style: TextStyle(color: AppColors.textSecondary(brightness)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in selected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _fullDayName(context, day),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCheckChip extends StatelessWidget {
  const _DayCheckChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: selected,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
              activeColor: AppColors.teal,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(Theme.of(context).brightness),
            ),
          ),
        ],
      ),
    );
  }
}
