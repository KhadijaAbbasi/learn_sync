import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/lecture_ordinal.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_model.dart';
import '../../models/lecture_model.dart';
import '../../models/live_session_model.dart';
import '../../widgets/custom_button.dart';


class TeacherLectureSummaryScreen extends StatefulWidget {
  const TeacherLectureSummaryScreen({
    super.key,
    required this.session,
    required this.courseName,
    this.courseCode = '',
    this.department = '',
    this.semester = '',
    this.teacherId = '',
    this.summary,
  });

  final LiveSessionModel session;
  final String courseName;
  final String courseCode;
  final String department;
  final String semester;
  final String teacherId;
  final LectureSummary? summary;

  @override
  State<TeacherLectureSummaryScreen> createState() =>
      _TeacherLectureSummaryScreenState();
}

class _TeacherLectureSummaryScreenState
    extends State<TeacherLectureSummaryScreen> {
  Stream<LectureModel?>? _lectureStream;
  Stream<List<LectureAttendee>>? _attendeesStream;
  final _notesController = TextEditingController();
  var _notesSeeded = false;
  var _persisting = false;
  var _persistAttempted = false;
  var _continuing = false;
  String? _notesError;
  Future<void>? _inFlightPersist;

  @override
  void initState() {
    super.initState();
    final initial = widget.summary?.taughtNotes ?? '';
    if (initial.trim().isNotEmpty) {
      _notesController.text = initial;
      _notesSeeded = true;
    }
    _notesController.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).courseStore;
    _lectureStream ??= store.watchLecture(widget.session.id);
    _attendeesStream ??= store.watchLectureAttendees(widget.session.id);
  }

  CourseModel? _course() {
    final id = widget.session.courseId;
    for (final course in AppScope.of(context).courseStore.courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  String _teacherId() {
    if (widget.teacherId.isNotEmpty) {
      return widget.teacherId;
    }
    return AppScope.of(context).sessionController.user?.id ??
        widget.session.teacherId;
  }

  bool get _hasTaughtNotes => _notesController.text.trim().isNotEmpty;

  void _onNotesChanged() {
    if (_notesError == null || !_hasTaughtNotes) {
      return;
    }
    setState(() => _notesError = null);
  }

  void _seedNotes(LectureModel? lecture) {
    if (_notesSeeded) {
      return;
    }
    if (_notesController.text.trim().isNotEmpty) {
      _notesSeeded = true;
      return;
    }
    final notes = lecture?.resolvedTaughtNotes.isNotEmpty == true
        ? lecture!.resolvedTaughtNotes
        : (widget.summary?.taughtNotes ?? '');
    if (notes.trim().isEmpty) {
      return;
    }
    _notesController.text = notes;
    _notesSeeded = true;
  }

  LectureSummary _summaryToSave(LectureModel? lecture) {
    final course = _course();
    final source =
        lecture ??
        LectureModel(
          id: widget.session.id,
          courseId: widget.session.courseId,
          courseName: widget.courseName,
          teacherId: _teacherId(),
          teacherName: course?.teacherName ?? '',
          chapterId: widget.session.chapterId,
          chapterTitle: widget.session.chapterTitle,
          topicId: widget.session.topicId,
          topicTitle: widget.session.topicTitle,
          durationMinutes: widget.session.durationMinutes,
          status: LectureStatus.ended,
          startedAt: widget.session.startedAt,
          endedAt: widget.session.endedAt,
          actualDurationMinutes: widget.summary?.actualDurationMinutes ?? 0,
          studentCount: widget.summary?.attendeeCount ?? 0,
          lectureDate: widget.summary?.lectureDate ?? '',
        );
    return LectureSummary.fromLecture(
      source,
      courseCode: widget.courseCode.isNotEmpty
          ? widget.courseCode
          : (course?.code ?? ''),
      department: widget.department.isNotEmpty
          ? widget.department
          : (course?.department ?? ''),
      semester: widget.semester.isNotEmpty
          ? widget.semester
          : (course?.semester ?? ''),
      section: course?.section ?? '',
      attendeeCount:
          lecture?.studentCount ?? widget.summary?.attendeeCount ?? 0,
      actualDurationMinutes:
          lecture?.actualDurationMinutes ??
          widget.summary?.actualDurationMinutes ??
          0,
      taughtNotes: _notesController.text.trim(),
    );
  }

  Future<void> _persistSummary({required LectureModel? lecture}) async {
    if (_persistAttempted || _persisting) {
      return;
    }
    if (lecture == null || lecture.isActive) {
      return;
    }
    final teacherId = _teacherId();
    if (teacherId.isEmpty) {
      return;
    }
    _persistAttempted = true;
    _persisting = true;
    final future = () async {
      try {
        await AppScope.of(context).courseStore.saveLectureSummary(
          lectureId: widget.session.id,
          teacherId: teacherId,
          summary: _summaryToSave(lecture),
        );
      } catch (error, stackTrace) {
        debugPrint('saveLectureSummary failed: $error');
        debugPrint('$stackTrace');
      } finally {
        _persisting = false;
      }
    }();
    _inFlightPersist = future;
    await future;
  }

  Future<void> _backToDashboard() async {
    if (_continuing) {
      return;
    }
    setState(() => _continuing = true);
    final inFlight = _inFlightPersist;
    if (inFlight != null) {
      await inFlight;
    }
    if (!mounted) {
      return;
    }
    _goHome();
  }

  int _actualMinutes(LectureModel? lecture) {
    if (lecture != null && lecture.actualDurationMinutes > 0) {
      return lecture.actualDurationMinutes;
    }
    if (widget.summary != null && widget.summary!.actualDurationMinutes > 0) {
      return widget.summary!.actualDurationMinutes;
    }
    final start = lecture?.startedAt ?? widget.session.startedAt;
    final end = lecture?.endedAt ?? widget.session.endedAt;
    if (start == null || end == null) {
      return lecture?.actualDurationMinutes ?? 0;
    }
    return end.difference(start).inMinutes.clamp(0, 24 * 60);
  }


  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.teacherDashboard, (_) => false);
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat.jm(
      Localizations.localeOf(context).toString(),
    ).format(value);
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final course = _course();

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.headerNavy,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 4,
              bottom: 18,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.navDashboard,
                      color: Colors.white,
                      onPressed: _goHome,
                      icon: const Icon(Icons.home_rounded),
                    ),
                    Expanded(
                      child: StreamBuilder<List<LiveSessionModel>>(
                        stream: AppScope.of(context).courseStore
                            .watchEndedSessionsForTopic(
                              courseId: widget.session.courseId,
                              chapterId: widget.session.chapterId,
                              topicId: widget.session.topicId,
                            ),
                        builder: (context, endedSnap) {
                          final ended = endedSnap.data;
                          final title = ended == null
                              ? l10n.lectureSummaryTitle
                              : l10n.lectureSummaryTitleNumbered(
                                  lectureOrdinalForTopic(
                                    session: widget.session,
                                    endedForTopic: ended,
                                  ),
                                );
                          return Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    l10n.lectureSummarySubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<LectureModel?>(
              stream: _lectureStream,
              builder: (context, lectureSnap) {
                return StreamBuilder<List<LectureAttendee>>(
                  stream: _attendeesStream,
                  builder: (context, attendeesSnap) {
                    final lecture = lectureSnap.data;
                    final attendees = attendeesSnap.data ?? const [];
                    final fallback = widget.summary;
                    final attendeeCount = attendees.isNotEmpty
                        ? attendees.length
                        : (lecture?.studentCount ??
                              fallback?.attendeeCount ??
                              0);
                    if (lectureSnap.connectionState !=
                            ConnectionState.waiting ||
                        lecture != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        _seedNotes(lecture);
                        unawaited(_persistSummary(lecture: lecture));
                      });
                    }

                    final started =
                        lecture?.startedAt ?? widget.session.startedAt;
                    final ended = lecture?.endedAt ?? widget.session.endedAt;
                    final chapterTitle =
                        (lecture?.chapterTitle ??
                                fallback?.chapterTitle ??
                                widget.session.chapterTitle)
                            .trim();
                    final topicTitle =
                        (lecture?.topicTitle ??
                                fallback?.topicTitle ??
                                widget.session.topicTitle)
                            .trim();
                    final courseName =
                        lecture?.courseName.trim().isNotEmpty == true
                        ? lecture!.courseName
                        : (fallback?.courseName.trim().isNotEmpty == true
                              ? fallback!.courseName
                              : widget.courseName);
                    final courseCode = widget.courseCode.trim().isNotEmpty
                        ? widget.courseCode
                        : (fallback?.courseCode ?? course?.code ?? '');
                    final semester = widget.semester.trim().isNotEmpty
                        ? widget.semester
                        : (fallback?.semester ?? course?.semester ?? '');
                    final department = widget.department.trim().isNotEmpty
                        ? widget.department
                        : (fallback?.department ?? course?.department ?? '');
                    final planned =
                        lecture?.durationMinutes ??
                        fallback?.durationMinutes ??
                        widget.session.durationMinutes;
                    final actual = _actualMinutes(lecture);

                    return ListView(
                      padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
                      children: [
                        _HeroCard(
                          courseName: courseName,
                          courseCode: courseCode,
                          semester: semester,
                          department: department,
                          completedLabel: l10n.completedStatus,
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: l10n.lectureInformation,
                          icon: Icons.play_circle_outline_rounded,
                          child: Column(
                            children: [
                              _DetailRow(
                                icon: Icons.menu_book_outlined,
                                label: l10n.topicTitle,
                                value: topicTitle.isEmpty ? '—' : topicTitle,
                              ),
                              _DetailRow(
                                icon: Icons.layers_outlined,
                                label: l10n.chapterTitle,
                                value: chapterTitle.isEmpty
                                    ? '—'
                                    : chapterTitle,
                              ),
                              _DetailRow(
                                icon: Icons.school_outlined,
                                label: l10n.courseName,
                                value: courseName,
                              ),
                              if (courseCode.trim().isNotEmpty)
                                _DetailRow(
                                  icon: Icons.tag_rounded,
                                  label: l10n.courseCode,
                                  value: courseCode,
                                ),
                              if (department.trim().isNotEmpty)
                                _DetailRow(
                                  icon: Icons.apartment_outlined,
                                  label: l10n.department,
                                  value: department,
                                ),
                              if (semester.trim().isNotEmpty)
                                _DetailRow(
                                  icon: Icons.calendar_month_outlined,
                                  label: l10n.semester,
                                  value: semester,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: l10n.sessionDetails,
                          icon: Icons.schedule_rounded,
                          child: Column(
                            children: [
                              _DetailRow(
                                icon: Icons.play_arrow_rounded,
                                label: l10n.startTime,
                                value: _formatTime(started),
                                subtitle: _formatDate(started),
                              ),
                              _DetailRow(
                                icon: Icons.stop_rounded,
                                label: l10n.endTime,
                                value: _formatTime(ended),
                                subtitle: _formatDate(ended),
                              ),
                              _DetailRow(
                                icon: Icons.timer_outlined,
                                label: l10n.plannedDuration,
                                value: l10n.durationMinutes(planned),
                              ),
                              _DetailRow(
                                icon: Icons.hourglass_bottom_rounded,
                                label: l10n.actualDuration,
                                value: l10n.durationMinutes(actual),
                                last: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: l10n.attendeesCount(attendeeCount),
                          icon: Icons.groups_rounded,
                          child: attendees.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    l10n.noStudentsYet,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(
                                        brightness,
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (var i = 0; i < attendees.length; i++)
                                      _AttendeeRow(
                                        name: attendees[i].studentName,
                                        email: attendees[i].studentEmail.isEmpty
                                            ? attendees[i].memberId
                                            : attendees[i].studentEmail,
                                        joined: attendees[i].joinedAt == null
                                            ? null
                                            : l10n.joinedAt(
                                                _formatTime(
                                                  attendees[i].joinedAt,
                                                ),
                                              ),
                                        last: i == attendees.length - 1,
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Material(
            color: AppColors.fieldFill(brightness),
            elevation: 8,
            shadowColor: AppColors.navy.withValues(alpha: 0.12),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: CustomButton(
                  label: l10n.backToDashboard,
                  onPressed: _backToDashboard,
                  isLoading: _continuing,
                  variant: AppButtonVariant.signup,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.courseName,
    required this.courseCode,
    required this.semester,
    required this.department,
    required this.completedLabel,
  });

  final String courseName;
  final String courseCode;
  final String semester;
  final String department;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.teal),
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
                        _Chip(text: courseCode, color: AppColors.teal),
                      if (semester.trim().isNotEmpty)
                        _Chip(text: semester, color: const Color(0xFF4A90C8)),
                    ],
                  ),
                  if (department.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      department,
                      style: TextStyle(
                        color: AppColors.textSecondary(brightness),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    completedLabel,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
        boxShadow: [
          if (brightness == Brightness.light)
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.teal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary(brightness),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({
    required this.name,
    required this.email,
    required this.joined,
    this.last = false,
  });

  final String name;
  final String email;
  final String? joined;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 8 : 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.teal.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.tealDark,
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
                  name,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.trim().isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (joined != null)
            Text(
              joined!,
              style: TextStyle(
                color: AppColors.textSecondary(brightness),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
