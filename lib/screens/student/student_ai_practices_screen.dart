import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/lecture_ordinal.dart';
import '../../models/chapter_model.dart';
import '../../models/course_model.dart';
import '../../models/live_session_model.dart';
import '../../widgets/dashboard_scaffold.dart';
import 'ai_practice_screen.dart';
import 'student_past_practice_screen.dart';

class StudentAiPracticesScreen extends StatefulWidget {
  const StudentAiPracticesScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<StudentAiPracticesScreen> createState() =>
      _StudentAiPracticesScreenState();
}

class _StudentAiPracticesScreenState extends State<StudentAiPracticesScreen> {
  CourseModel? _course;
  ChapterModel? _chapter;
  TopicModel? _topic;
  List<ChapterModel> _chapters = const [];
  List<TopicModel> _topics = const [];
  var _loadingFilters = false;

  bool get _selectionComplete =>
      _course != null && _chapter != null && _topic != null;

  Future<void> _selectCourse(CourseModel course) async {
    setState(() {
      _course = course;
      _chapter = null;
      _topic = null;
      _chapters = const [];
      _topics = const [];
      _loadingFilters = true;
    });
    final store = AppScope.of(context).courseStore;
    try {
      final chapters = await store.watchChapters(course.id).first;
      if (!mounted) {
        return;
      }
      setState(() {
        _chapters = chapters;
        _loadingFilters = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingFilters = false);
      }
    }
  }

  Future<void> _selectChapter(ChapterModel chapter) async {
    final course = _course;
    if (course == null) {
      return;
    }
    setState(() {
      _chapter = chapter;
      _topic = null;
      _topics = const [];
      _loadingFilters = true;
    });
    final store = AppScope.of(context).courseStore;
    try {
      final topics = await store.watchTopics(course.id, chapter.id).first;
      if (!mounted) {
        return;
      }
      setState(() {
        _topics = topics;
        _loadingFilters = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingFilters = false);
      }
    }
  }

  void _selectTopic(TopicModel topic) {
    setState(() => _topic = topic);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.sessionController,
        scope.courseStore,
      ]),
      builder: (context, _) {
        final user = scope.sessionController.user;
        final courses = scope.courseStore.courses;

        return DashboardScaffold(
          embeddedInShell: widget.embeddedInShell,
          roleLabel: l10n.student,
          appBarTitle: l10n.aiPractice,
          appBarCenterTitle: true,
          appBarBackButton: !widget.embeddedInShell,
          appBarActions: [
            Builder(
              builder: (buttonContext) {
                return IconButton(
                  tooltip: l10n.aiPracticeColorLegendTooltip,
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => _showAiPracticeColorLegend(
                    buttonContext,
                    l10n,
                  ),
                );
              },
            ),
          ],
          body: !scope.sessionController.hasTeacherLink
              ? _EmptyState(
                  icon: Icons.link_off_rounded,
                  text: l10n.noCoursesStudent,
                )
              : courses.isEmpty
                  ? _EmptyState(
                      icon: Icons.school_outlined,
                      text: l10n.teacherHasNoCourses,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FilterCard(
                          courses: courses,
                          chapters: _chapters,
                          topics: _topics,
                          course: _course,
                          chapter: _chapter,
                          topic: _topic,
                          loading: _loadingFilters,
                          onCourse: _selectCourse,
                          onChapter: _selectChapter,
                          onTopic: _selectTopic,
                        ),
                        const SizedBox(height: 16),
                        if (!_selectionComplete)
                          _EmptyState(
                            icon: Icons.filter_alt_outlined,
                            text: 'Select course, chapter, and topic',
                            accent: AppColors.teal,
                          )
                        else
                          StreamBuilder<List<LiveSessionModel>>(
                            stream: scope.courseStore.watchEndedSessionsForTopic(
                              courseId: _course!.id,
                              chapterId: _chapter!.id,
                              topicId: _topic!.id,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return _EmptyState(
                                  icon: Icons.error_outline_rounded,
                                  text: snapshot.error.toString(),
                                  accent: AppColors.coral,
                                );
                              }
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final sessions =
                                  snapshot.data ?? const <LiveSessionModel>[];
                              if (sessions.isEmpty) {
                                return _EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  text: l10n.aiPracticesEmpty,
                                  accent: AppColors.gold,
                                );
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sessions.length,
                                itemBuilder: (context, index) {
                                  final session = sessions[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _PracticeLectureTile(
                                      session: session,
                                      courseName: _course!.name,
                                      studentId: user?.id ?? '',
                                      studentName: user?.fullName ?? '',
                                      lectureOrdinal: lectureOrdinalForTopic(
                                        session: session,
                                        endedForTopic: sessions,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
        );
      },
    );
  }
}



Future<void> _showAiPracticeColorLegend(
  BuildContext buttonContext,
  AppLocalizations l10n,
) async {
  final button = buttonContext.findRenderObject() as RenderBox?;
  if (button == null || !button.hasSize) {
    return;
  }
  final overlayState = Overlay.of(buttonContext);
  final overlay =
      overlayState.context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    return;
  }

  final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
  final size = button.size;
  final media = MediaQuery.sizeOf(buttonContext);
  final isRtl = Directionality.of(buttonContext) == TextDirection.rtl;
  const cardWidth = 300.0;
  const gap = 2.0;

  // Anchor under the info icon, trailing-aligned like the mock.
  final top = topLeft.dy + size.height + gap;
  double? left;
  double? right;
  if (isRtl) {
    left = topLeft.dx.clamp(12.0, media.width - cardWidth - 12.0);
  } else {
    right = (media.width - topLeft.dx - size.width).clamp(
      12.0,
      media.width - cardWidth - 12.0,
    );
  }

  await showDialog<void>(
    context: buttonContext,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    useSafeArea: false,
    builder: (dialogContext) {
      return SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              right: right,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: cardWidth,
                  child: _AiPracticeColorLegendPopup(l10n: l10n),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.courses,
    required this.chapters,
    required this.topics,
    required this.course,
    required this.chapter,
    required this.topic,
    required this.loading,
    required this.onCourse,
    required this.onChapter,
    required this.onTopic,
  });

  final List<CourseModel> courses;
  final List<ChapterModel> chapters;
  final List<TopicModel> topics;
  final CourseModel? course;
  final ChapterModel? chapter;
  final TopicModel? topic;
  final bool loading;
  final ValueChanged<CourseModel> onCourse;
  final ValueChanged<ChapterModel> onChapter;
  final ValueChanged<TopicModel> onTopic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final courseReady = !loading;
    final chapterEnabled = courseReady && course != null && chapters.isNotEmpty;
    final topicEnabled = courseReady && chapter != null && topics.isNotEmpty;

    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brightness == Brightness.dark
              ? [
                  AppColors.darkSurface,
                  AppColors.teal.withValues(alpha: 0.22),
                ]
              : [
                  const Color(0xFFE8F6F6),
                  AppColors.teal.withValues(alpha: 0.14),
                  const Color(0xFFF7FBFC),
                ],
        ),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                _FilterDropdown(
                  key: ValueKey('ai-course-${course?.id ?? 'none'}'),
                  label: l10n.courseLabel,
                  value: course?.id,
                  icon: Icons.school_outlined,
                  accent: AppColors.teal,
                  enabled: courseReady,
                  items: [
                    for (final item in courses)
                      (id: item.id, label: item.name),
                  ],
                  onChanged: (id) {
                    final match =
                        courses.where((c) => c.id == id).firstOrNull;
                    if (match != null) {
                      onCourse(match);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _FilterDropdown(
                  key: ValueKey(
                    'ai-chapter-${course?.id ?? 'none'}-${chapter?.id ?? 'none'}-${chapters.length}',
                  ),
                  label: l10n.selectChapter,
                  value: chapter?.id,
                  icon: Icons.menu_book_outlined,
                  accent: AppColors.tealDark,
                  enabled: chapterEnabled,
                  items: [
                    for (final item in chapters)
                      (id: item.id, label: item.title),
                  ],
                  onChanged: (id) {
                    final match =
                        chapters.where((c) => c.id == id).firstOrNull;
                    if (match != null) {
                      onChapter(match);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _FilterDropdown(
                  key: ValueKey(
                    'ai-topic-${chapter?.id ?? 'none'}-${topic?.id ?? 'none'}-${topics.length}',
                  ),
                  label: l10n.selectTopic,
                  value: topic?.id,
                  icon: Icons.topic_outlined,
                  accent: AppColors.teal,
                  enabled: topicEnabled,
                  items: [
                    for (final item in topics)
                      (id: item.id, label: item.title),
                  ],
                  onChanged: (id) {
                    final match =
                        topics.where((t) => t.id == id).firstOrNull;
                    if (match != null) {
                      onTopic(match);
                    }
                  },
                ),
          if (loading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.teal,
              backgroundColor: AppColors.teal.withValues(alpha: 0.18),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final List<({String id, String label})> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? AppColors.navy : AppColors.lightMuted,
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(
          icon,
          color: enabled ? accent : accent.withValues(alpha: 0.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.22)),
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.label)),
      ],
      onChanged: enabled
          ? (id) {
              if (id != null) {
                onChanged(id);
              }
            }
          : null,
    );
  }
}

class _PracticeLectureTile extends StatefulWidget {
  const _PracticeLectureTile({
    required this.session,
    required this.courseName,
    required this.studentId,
    required this.studentName,
    required this.lectureOrdinal,
  });

  final LiveSessionModel session;
  final String courseName;
  final String studentId;
  final String studentName;
  final int lectureOrdinal;

  @override
  State<_PracticeLectureTile> createState() => _PracticeLectureTileState();
}

class _PracticeLectureTileState extends State<_PracticeLectureTile> {
  var _remoteChecked = false;

  /// Accent from saved attempt count for this lecture:
  /// 0 = never (coral/red), 1-2 = partial (gold/yellow), 3+ = practiced more (teal).
  Color _accentForAttemptCount(int attemptCount) {
    if (attemptCount <= 0) return AppColors.coral;
    if (attemptCount <= 2) return AppColors.gold;
    return AppColors.teal;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _optionalRemoteCheck());
  }

  @override
  void didUpdateWidget(covariant _PracticeLectureTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.studentId != widget.studentId) {
      _remoteChecked = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _optionalRemoteCheck());
    }
  }

  Future<void> _optionalRemoteCheck() async {
    if (!mounted || _remoteChecked || widget.studentId.isEmpty) {
      return;
    }
    _remoteChecked = true;
    final store = AppScope.of(context).courseStore;
    // One-shot get with short timeout; merges into local mirror for attempt counts.
    await store.fetchMyPracticeAttemptsOnce(
      lectureId: widget.session.id,
      studentId: widget.studentId,
    );
  }

  void _startPractice() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiPracticeScreen(
          session: widget.session,
          courseName: widget.courseName,
          studentId: widget.studentId,
          studentName: widget.studentName,
          lectureOrdinal: widget.lectureOrdinal,
        ),
      ),
    );
  }

  void _openPastPractice() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentPastPracticeScreen(
          session: widget.session,
          courseName: widget.courseName,
          studentId: widget.studentId,
          lectureOrdinal: widget.lectureOrdinal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final when = widget.session.endedAt ?? widget.session.startedAt;
    final store = AppScope.of(context).courseStore;
    final attemptCount = store
        .localMyPracticeAttempts(
          lectureId: widget.session.id,
          studentId: widget.studentId,
        )
        .length;
    final accent = _accentForAttemptCount(attemptCount);
    final practiced = attemptCount > 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white,
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: practiced ? 96 : 72,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_outlined, color: accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.topicTitle.isEmpty
                                ? l10n.aiPractice
                                : widget.session.topicTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(brightness),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              widget.courseName,
                              if (widget.session.chapterTitle.isNotEmpty)
                                widget.session.chapterTitle,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            when == null
                                ? l10n.lectureNumber(widget.lectureOrdinal)
                                : '${l10n.lectureNumber(widget.lectureOrdinal)} · ${_formatWhen(when)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (practiced)
                      IntrinsicWidth(
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              onPressed: _openPastPractice,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.tealDark,
                                side: const BorderSide(color: AppColors.teal),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                l10n.alreadyPracticed,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 32,
                            child: FilledButton(
                              onPressed: _startPractice,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                l10n.practiceMore,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      )
                    else
                      FilledButton(
                        onPressed: _startPractice,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          l10n.startPractice,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWhen(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.text,
    this.accent = AppColors.teal,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: accent),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(brightness),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPracticeColorLegendPopup extends StatelessWidget {
  const _AiPracticeColorLegendPopup({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final headerTint = isDark
        ? AppColors.navy.withValues(alpha: 0.35)
        : const Color(0xFFE8F1FA);
    final titleColor = isDark ? AppColors.darkText : AppColors.navy;
    final subtitleColor =
        isDark ? AppColors.darkMuted : const Color(0xFF6B7C93);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 18),
          child: CustomPaint(
            size: const Size(16, 9),
            painter: _LegendCaretPainter(color: headerTint),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: headerTint,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.palette_rounded,
                        size: 20,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.aiPracticeColorLegendTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              height: 1.2,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.aiPracticeColorLegendSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  children: [
                    _ColorLegendRow(
                      color: AppColors.coral,
                      label: l10n.aiPracticeColorNone,
                      colorName: l10n.aiPracticeColorRed,
                      titleColor: titleColor,
                    ),
                    const SizedBox(height: 8),
                    _ColorLegendRow(
                      color: AppColors.gold,
                      label: l10n.aiPracticeColorFew,
                      colorName: l10n.aiPracticeColorYellow,
                      titleColor: titleColor,
                    ),
                    const SizedBox(height: 8),
                    _ColorLegendRow(
                      color: AppColors.teal,
                      label: l10n.aiPracticeColorMany,
                      colorName: l10n.aiPracticeColorTeal,
                      titleColor: titleColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorLegendRow extends StatelessWidget {
  const _ColorLegendRow({
    required this.color,
    required this.label,
    required this.colorName,
    required this.titleColor,
  });

  final Color color;
  final String label;
  final String colorName;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  colorName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendCaretPainter extends CustomPainter {
  const _LegendCaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LegendCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
