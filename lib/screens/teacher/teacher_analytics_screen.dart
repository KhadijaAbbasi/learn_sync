import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/lecture_feedback.dart';
import '../../models/lecture_model.dart';
import '../../models/meeting_request.dart';
import '../../models/teacher_analytics.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/custom_button.dart';
import 'teacher_meetings_analytics_screen.dart';
import 'teacher_practice_analytics_screen.dart';
import 'teacher_understanding_analytics_screen.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({
    super.key,
    this.practiceAttemptsStream,
    this.embeddedInShell = false,
    this.initialFilter,
  });

  /// Test hook. Production uses [CourseStore.watchTeacherPracticeAttempts].
  final Stream<List<AiPracticeAttempt>>? practiceAttemptsStream;
  final bool embeddedInShell;
  final TeacherAnalyticsFilter? initialFilter;

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  late TeacherAnalyticsFilter _filter;
  var _studentQuery = '';
  var _attendeesByLecture = const <String, List<LectureAttendee>>{};
  var _attendeeKey = '';
  var _reloadTick = 0;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? const TeacherAnalyticsFilter();
  }

  String _lowLevelLabel(AppLocalizations l10n, UnderstandingLevel level) {
    return switch (level) {
      UnderstandingLevel.percent100 => l10n.understand100,
      UnderstandingLevel.percent80 => l10n.understand80,
      UnderstandingLevel.percent60 => l10n.understand60,
      UnderstandingLevel.below50 => l10n.understandBelow50,
    };
  }

  Future<void> _syncAttendees(List<LectureModel> lectures) async {
    final store = AppScope.of(context).courseStore;
    final filtered = [
      for (final lecture in lectures)
        if (lectureMatchesFilter(lecture, _filter, DateTime.now())) lecture,
    ];
    final ids = [
      for (final lecture in filtered.take(kTeacherAnalyticsAttendeeLectureCap))
        lecture.id,
    ]..sort();
    final key = '${ids.join('|')}|$_reloadTick';
    if (key == _attendeeKey) {
      return;
    }
    _attendeeKey = key;
    try {
      final loaded = await store.loadAttendeesForLectures(ids);
      if (!mounted || _attendeeKey != key) {
        return;
      }
      setState(() => _attendeesByLecture = loaded);
    } catch (error) {
      debugPrint('loadAttendeesForLectures failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user?.role != UserRole.teacher) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.teacherAnalytics)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final teacherId = user!.id;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: widget.embeddedInShell ? null : const AppBackButton(),
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(l10n.teacherAnalytics),
      ),
      body: StreamBuilder<List<LectureModel>>(
        key: ValueKey('analytics-lectures-$_reloadTick'),
        stream: scope.courseStore.watchTeacherLectures(teacherId),
        builder: (context, lectureSnap) {
          if (lectureSnap.hasError) {
            _logAnalyticsStreamError('lectures', lectureSnap.error);
            return _MessageState(
              icon: Icons.error_outline_rounded,
              title: l10n.analyticsLoadFailed,
              action: l10n.analyticsRetry,
              onAction: () => setState(() {
                _attendeeKey = '';
                _reloadTick++;
              }),
            );
          }
          if (lectureSnap.connectionState == ConnectionState.waiting &&
              !lectureSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lectures = lectureSnap.data ?? const [];
          final practiceLectureIds = [
            for (final lecture in lectures.take(
              kTeacherAnalyticsPracticeLectureCap,
            ))
              lecture.id,
          ];

          return StreamBuilder<List<LectureFeedback>>(
            stream: scope.courseStore.watchTeacherFeedback(teacherId),
            builder: (context, feedbackSnap) {
              if (feedbackSnap.hasError) {
                _logAnalyticsStreamError('feedback', feedbackSnap.error);
              }
              return StreamBuilder<List<MeetingRequest>>(
                stream: scope.meetingStore.watchTeacherRequests(teacherId),
                builder: (context, meetingSnap) {
                  if (meetingSnap.hasError) {
                    _logAnalyticsStreamError('meetings', meetingSnap.error);
                  }
                  return StreamBuilder<List<AiPracticeAttempt>>(
                    stream:
                        widget.practiceAttemptsStream ??
                        scope.courseStore.watchTeacherPracticeAttempts(
                          teacherId,
                          lectureIds: practiceLectureIds,
                        ),
                    builder: (context, practiceSnap) {
                      if (practiceSnap.hasError) {
                        _logAnalyticsStreamError(
                          'practiceAttempts',
                          practiceSnap.error,
                        );
                      }
                      final waitingFeedback =
                          feedbackSnap.connectionState ==
                              ConnectionState.waiting &&
                          !feedbackSnap.hasData &&
                          !feedbackSnap.hasError;
                      final waitingMeetings =
                          meetingSnap.connectionState ==
                              ConnectionState.waiting &&
                          !meetingSnap.hasData &&
                          !meetingSnap.hasError;
                      if (waitingFeedback || waitingMeetings) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        unawaited(_syncAttendees(lectures));
                      });

                      final practiceUnavailable = practiceSnap.hasError;
                      final rawAttempts = practiceUnavailable
                          ? const <AiPracticeAttempt>[]
                          : (practiceSnap.data ?? const <AiPracticeAttempt>[]);
                      final rawMeetings = meetingSnap.hasError
                          ? const <MeetingRequest>[]
                          : (meetingSnap.data ?? const <MeetingRequest>[]);
                      final rawFeedback = feedbackSnap.hasError
                          ? const <LectureFeedback>[]
                          : (feedbackSnap.data ?? const <LectureFeedback>[]);
                      final clock = DateTime.now();
                      final filteredLectures = [
                        for (final lecture in lectures)
                          if (lectureMatchesFilter(lecture, _filter, clock))
                            lecture,
                      ];
                      final filteredLectureIds = {
                        for (final lecture in filteredLectures) lecture.id,
                      };
                      final filteredAttempts = [
                        for (final item in rawAttempts)
                          if (filteredLectureIds.contains(item.lectureId)) item,
                      ];
                      final filteredFeedback = [
                        for (final item in rawFeedback)
                          if (filteredLectureIds.contains(item.lectureId)) item,
                      ];
                      final filteredMeetings = [
                        for (final item in rawMeetings)
                          if (meetingMatchesFilter(item, _filter, clock)) item,
                      ];
                      final filteredAttendeesById = <String, LectureAttendee>{};
                      for (final lecture in filteredLectures) {
                        for (final attendee
                            in _attendeesByLecture[lecture.id] ??
                                const <LectureAttendee>[]) {
                          final id = attendee.studentId.trim();
                          if (id.isEmpty) {
                            continue;
                          }
                          filteredAttendeesById.putIfAbsent(id, () => attendee);
                        }
                      }
                      final filteredAttendees = filteredAttendeesById.values
                          .toList();
                      final report = aggregateTeacherAnalytics(
                        TeacherAnalyticsInputs(
                          lectures: lectures,
                          feedback: rawFeedback,
                          attempts: rawAttempts,
                          meetings: rawMeetings,
                          attendeesByLecture: _attendeesByLecture,
                          courses: [
                            for (final course in scope.courseStore.courses)
                              (id: course.id, name: course.name),
                          ],
                        ),
                        _filter,
                        lowLevelLabel: (level) => _lowLevelLabel(l10n, level),
                      );
                      // Progressive combined analytics:
                      // course → course-wide; +chapter → chapter; +topic → topic.
                      final hasCourseSelection = _filter.courseId.isNotEmpty;
                      final displayReport = hasCourseSelection
                          ? report
                          : report.zeroedMetrics();
                      final courseLabel = _courseFilterLabel(l10n, report);
                      final dateLabel = _dateFilterLabel(l10n, clock);

                      return ListView(
                        padding: EdgeInsets.fromLTRB(padding, 16, padding, 36),
                        children: [
                          if (practiceUnavailable) ...[
                            _PracticeUnavailableBanner(
                              message: l10n.analyticsPracticeUnavailable,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _FilterCard(
                            filter: _filter,
                            report: report,
                            onChanged: (next) => setState(() => _filter = next),
                          ),
                          const SizedBox(height: 16),
                          if (!hasCourseSelection) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.teal.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                'Select a course to see combined analytics. Add chapter and topic to narrow further.',
                                style: TextStyle(
                                  color: AppColors.textSecondary(brightness),
                                  height: 1.35,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _TopicOverviewCard(
                            filter: _filter,
                            report: displayReport,
                            courseLabel: courseLabel,
                          ),
                          const SizedBox(height: 16),
                          _OverviewGrid(
                            report: displayReport,
                            onUnderstandingTap: hasCourseSelection
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            TeacherUnderstandingAnalyticsScreen(
                                              feedback: filteredFeedback,
                                              attendees: filteredAttendees,
                                              attendeeCount:
                                                  displayReport
                                                          .uniqueStudentCount >
                                                      0
                                                  ? displayReport
                                                        .uniqueStudentCount
                                                  : displayReport
                                                        .practice
                                                        .attendeeCount,
                                              courseLabel: courseLabel,
                                              dateLabel: dateLabel,
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                            onPracticeTap: hasCourseSelection
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            TeacherPracticeAnalyticsScreen(
                                              attempts: filteredAttempts,
                                              attendees: filteredAttendees,
                                              attendeeCount: displayReport
                                                  .practice
                                                  .attendeeCount,
                                              courseLabel: courseLabel,
                                              dateLabel: dateLabel,
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                            onMeetingsTap: hasCourseSelection
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            TeacherMeetingsAnalyticsScreen(
                                              meetings: filteredMeetings,
                                              courseLabel: courseLabel,
                                              dateLabel: dateLabel,
                                            ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _StudentPerformanceCard(
                            rows: displayReport.studentRows,
                            query: _studentQuery,
                            onQueryChanged: (value) =>
                                setState(() => _studentQuery = value),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _courseFilterLabel(
    AppLocalizations l10n,
    TeacherAnalyticsReport report,
  ) {
    if (_filter.courseId.isEmpty) {
      return l10n.analyticsAllCourses;
    }
    for (final option in report.courseOptions) {
      if (option.id == _filter.courseId) {
        return option.label;
      }
    }
    return _filter.courseId;
  }

  String _dateFilterLabel(AppLocalizations l10n, DateTime now) {
    final locale = Localizations.localeOf(context).toString();
    final format = DateFormat.yMMMd(locale);
    return switch (_filter.dateRange) {
      TeacherAnalyticsDateRange.all => l10n.analyticsAllTime,
      TeacherAnalyticsDateRange.last7 => l10n.analyticsLast7Days,
      TeacherAnalyticsDateRange.last30 => l10n.analyticsLast30Days,
      TeacherAnalyticsDateRange.custom => () {
        final start = _filter.customStart;
        final end = _filter.customEnd ?? _filter.customStart;
        if (start == null && end == null) {
          return l10n.analyticsCustomRange;
        }
        if (start != null && end != null) {
          return '${format.format(start)} – ${format.format(end)}';
        }
        final only = start ?? end!;
        return format.format(only);
      }(),
    };
  }
}

void _logAnalyticsStreamError(String name, Object? error) {
  if (error is FirebaseException) {
    debugPrint('analytics $name failed: ${error.code} ${error.message}');
  } else {
    debugPrint('analytics $name failed: $error');
  }
}

class _PracticeUnavailableBanner extends StatelessWidget {
  const _PracticeUnavailableBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                height: 1.35,
                color: AppColors.textPrimary(Theme.of(context).brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.filter,
    required this.report,
    required this.onChanged,
  });

  final TeacherAnalyticsFilter filter;
  final TeacherAnalyticsReport report;
  final ValueChanged<TeacherAnalyticsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brightness == Brightness.dark
              ? [AppColors.darkSurface, AppColors.teal.withValues(alpha: 0.22)]
              : [
                  const Color(0xFFE8F6F6),
                  AppColors.teal.withValues(alpha: 0.14),
                  const Color(0xFFF7FBFC),
                ],
        ),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterDropdown(
            label: l10n.courseLabel,
            value: filter.courseId,
            allLabel: l10n.analyticsAllCourses,
            options: report.courseOptions,
            icon: Icons.school_outlined,
            accent: AppColors.teal,
            onChanged: (id) => onChanged(
              filter.copyWith(
                courseId: id,
                clearChapter: true,
                clearTopic: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FilterDropdown(
            label: l10n.analyticsChapterFilter,
            value: filter.chapterId,
            allLabel: l10n.analyticsAllChapters,
            options: report.chapterOptions,
            icon: Icons.menu_book_outlined,
            accent: AppColors.teal,
            onChanged: (id) =>
                onChanged(filter.copyWith(chapterId: id, clearTopic: true)),
          ),
          const SizedBox(height: 10),
          _FilterDropdown(
            label: l10n.analyticsTopicFilter,
            value: filter.topicId,
            allLabel: l10n.analyticsAllTopics,
            options: report.topicOptions,
            icon: Icons.topic_outlined,
            accent: AppColors.teal,
            onChanged: (id) => onChanged(filter.copyWith(topicId: id)),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.dateRangeLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                (TeacherAnalyticsDateRange.all, l10n.analyticsAllTime),
                (TeacherAnalyticsDateRange.last7, l10n.analyticsLast7Days),
                (TeacherAnalyticsDateRange.last30, l10n.analyticsLast30Days),
                (TeacherAnalyticsDateRange.custom, l10n.analyticsCustomRange),
              ])
                FilterChip(
                  label: Text(item.$2),
                  selected: filter.dateRange == item.$1,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : Colors.white,
                  labelStyle: TextStyle(
                    color: AppColors.textPrimary(Theme.of(context).brightness),
                  ),
                  selectedColor: AppColors.teal.withValues(alpha: 0.16),
                  checkmarkColor: AppColors.teal,
                  side: BorderSide(
                    color: filter.dateRange == item.$1
                        ? AppColors.teal.withValues(alpha: 0.55)
                        : AppColors.teal.withValues(alpha: 0.28),
                  ),
                  onSelected: (_) => onChanged(
                    filter.copyWith(
                      dateRange: item.$1,
                      clearCustomDates:
                          item.$1 != TeacherAnalyticsDateRange.custom,
                    ),
                  ),
                ),
            ],
          ),
          if (filter.dateRange == TeacherAnalyticsDateRange.custom) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: filter.customStart == null
                        ? l10n.analyticsFromDate
                        : dateFormat.format(filter.customStart!),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: filter.customStart ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        onChanged(filter.copyWith(customStart: picked));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DateButton(
                    label: filter.customEnd == null
                        ? l10n.analyticsToDate
                        : dateFormat.format(filter.customEnd!),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            filter.customEnd ??
                            filter.customStart ??
                            DateTime.now(),
                        firstDate: filter.customStart ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        onChanged(filter.copyWith(customEnd: picked));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String allLabel;
  final List<AnalyticsFilterOption> options;
  final ValueChanged<String> onChanged;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final selected = value.isEmpty || options.any((item) => item.id == value)
        ? (value.isEmpty ? '' : value)
        : '';
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: selected,
      dropdownColor: isDark ? AppColors.darkSurface : null,
      style: TextStyle(color: AppColors.textPrimary(brightness), fontSize: 15),
      iconEnabledColor: AppColors.textSecondary(brightness),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? AppColors.textSecondary(brightness) : AppColors.navy,
        ),
        filled: true,
        floatingLabelStyle: TextStyle(color: accent),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        prefixIcon: Icon(icon, color: accent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(allLabel)),
        for (final option in options)
          DropdownMenuItem(value: option.id, child: Text(option.label)),
      ],
      onChanged: (next) => onChanged(next ?? ''),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.calendar_today_rounded,
        size: 16,
        color: AppColors.teal,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textPrimary(Brightness.dark)
            : AppColors.navy,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        side: BorderSide(color: AppColors.teal.withValues(alpha: 0.55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({
    required this.report,
    this.onUnderstandingTap,
    this.onPracticeTap,
    this.onMeetingsTap,
  });

  final TeacherAnalyticsReport report;
  final VoidCallback? onUnderstandingTap;
  final VoidCallback? onPracticeTap;
  final VoidCallback? onMeetingsTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppSizes.tabletBreakpoint;
    final cards = [
      _OverviewCard(
        icon: Icons.insights_rounded,
        color: AppColors.teal,
        title: l10n.analyticsUnderstanding,
        value: '${report.understandingAverage.round()}%',
        lines: [
          l10n.analyticsAverageScore(report.understandingAverage.round()),
        ],
        onTap: onUnderstandingTap,
      ),
      _OverviewCard(
        icon: Icons.smart_toy_outlined,
        color: AppColors.tealDark,
        title: l10n.analyticsPractice,
        value: '${report.practice.averageScore.round()}%',
        lines: [
          l10n.analyticsAverageScore(report.practice.averageScore.round()),
        ],
        onTap: onPracticeTap,
      ),
      _OverviewCard(
        icon: Icons.event_available_rounded,
        color: AppColors.coral,
        title: l10n.analyticsMeetings,
        value: '${report.meetings.total}',
        lines: const [],
        onTap: onMeetingsTap,
      ),
    ];
    if (!wide) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            cards[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.lines,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final List<String> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tappable = onTap != null;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                  if (tappable)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(brightness),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 6),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: AppColors.coral),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          CustomButton(label: action, onPressed: onAction),
        ],
      ),
    );
  }
}

class _TopicOverviewCard extends StatelessWidget {
  const _TopicOverviewCard({
    required this.filter,
    required this.report,
    required this.courseLabel,
  });

  final TeacherAnalyticsFilter filter;
  final TeacherAnalyticsReport report;
  final String courseLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    String? chapter;
    for (final o in report.chapterOptions) {
      if (o.id == filter.chapterId) {
        chapter = o.label;
        break;
      }
    }
    String? topic;
    for (final o in report.topicOptions) {
      if (o.id == filter.topicId) {
        topic = o.label;
        break;
      }
    }
    final breadcrumb = [
      courseLabel,
      if (chapter != null && chapter.isNotEmpty) chapter,
      if (topic != null && topic.isNotEmpty) topic,
    ].join(' • ');
    final counts = report.understanding;
    final students = report.uniqueStudentCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analyticsTopicOverview,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      breadcrumb,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.analyticsCombinedLectures(report.lectureCount),
                  style: const TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AnalyticsDonut(
                size: 112,
                segments: [
                  (counts.percent100.toDouble(), const Color(0xFF2E9B5A)),
                  (counts.percent80.toDouble(), AppColors.teal),
                  (counts.percent60.toDouble(), const Color(0xFFE0B03A)),
                  (counts.below50.toDouble(), const Color(0xFFE05A5A)),
                ],
                centerTop: '$students',
                centerBottom: l10n.analyticsTotalStudents,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (final row in [
                      (
                        const Color(0xFF2E9B5A),
                        l10n.understand100,
                        counts.percent100,
                        counts.shareLabel(UnderstandingLevel.percent100),
                      ),
                      (
                        AppColors.teal,
                        l10n.understand80,
                        counts.percent80,
                        counts.shareLabel(UnderstandingLevel.percent80),
                      ),
                      (
                        const Color(0xFFE0B03A),
                        l10n.understand60,
                        counts.percent60,
                        counts.shareLabel(UnderstandingLevel.percent60),
                      ),
                      (
                        const Color(0xFFE05A5A),
                        l10n.understandBelow50,
                        counts.below50,
                        counts.shareLabel(UnderstandingLevel.below50),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: row.$1,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(brightness),
                                ),
                              ),
                            ),
                            Text(
                              '${row.$3} (${row.$4})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(brightness),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniStatChip(
                icon: Icons.forum_outlined,
                label: l10n.analyticsTotalResponses,
                value: '${counts.total}',
              ),
              _MiniStatChip(
                icon: Icons.insights_rounded,
                label: l10n.analyticsAvgUnderstanding,
                value: '${report.understandingAverage.round()}%',
              ),
              _MiniStatChip(
                icon: Icons.smart_toy_outlined,
                label: l10n.analyticsPractice,
                value: '${report.practice.averageScore.round()}%',
              ),
              _MiniStatChip(
                icon: Icons.event_available_rounded,
                label: l10n.analyticsMeetings,
                value: '${report.meetings.total}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkBackground
            : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.teal),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentPerformanceCard extends StatelessWidget {
  const _StudentPerformanceCard({
    required this.rows,
    required this.query,
    required this.onQueryChanged,
  });

  final List<StudentAnalyticsRow> rows;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final q = query.trim().toLowerCase();
    final filtered = [
      for (final row in rows)
        if (q.isEmpty || row.studentName.toLowerCase().contains(q)) row,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analyticsStudentPerformance,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: l10n.analyticsSearchStudent,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Text(
              l10n.analyticsNoStudents,
              style: TextStyle(color: AppColors.textSecondary(brightness)),
            )
          else
            for (final row in filtered) ...[
              _StudentPerformanceTile(row: row),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StudentPerformanceTile extends StatelessWidget {
  const _StudentPerformanceTile({required this.row});

  final StudentAnalyticsRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final understanding = row.understandingPercent;
    final practice = row.practicePercent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.teal.withValues(alpha: 0.15),
            child: Text(
              row.studentName.isEmpty
                  ? '?'
                  : row.studentName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppColors.teal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.studentName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (understanding != null)
                      '${l10n.analyticsUnderstanding} ${understanding.round()}%',
                    if (practice != null)
                      '${l10n.analyticsPractice} ${practice.round()}%',
                    '${l10n.analyticsMeetings}: ${row.hasMeetingRequest ? l10n.analyticsMeetingYes : l10n.analyticsMeetingNo}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (row.needsAttention
                          ? const Color(0xFFE05A5A)
                          : const Color(0xFF2E9B5A))
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              row.needsAttention
                  ? l10n.analyticsNeedsAttention
                  : l10n.analyticsOnTrack,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: row.needsAttention
                    ? const Color(0xFFE05A5A)
                    : const Color(0xFF2E9B5A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsDonut extends StatelessWidget {
  const _AnalyticsDonut({
    required this.segments,
    required this.centerTop,
    required this.centerBottom,
    this.size = 118,
  });

  final List<(double, Color)> segments;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _AnalyticsDonutPainter(
          segments: segments,
          trackColor: brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFDDE5EE),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTop,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                Text(
                  centerBottom,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsDonutPainter extends CustomPainter {
  _AnalyticsDonutPainter({required this.segments, required this.trackColor});

  final List<(double, Color)> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (acc, s) => acc + s.$1);
    final stroke = size.shortestSide * 0.16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    if (total <= 0) {
      paint.color = trackColor;
      canvas.drawCircle(center, radius, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.$1 <= 0) {
        continue;
      }
      final sweep = (segment.$1 / total) * math.pi * 2;
      paint.color = segment.$2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyticsDonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.trackColor != trackColor;
  }
}
