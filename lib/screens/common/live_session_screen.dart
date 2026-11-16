import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/session/course_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/lecture_ordinal.dart';
import '../../models/chapter_model.dart';
import '../../models/course_content.dart';
import '../../models/course_model.dart';
import '../../models/lecture_model.dart';
import '../../models/live_session_model.dart';
import 'course_detail_screen.dart';
import '../student/student_slide_feedback_summary_screen.dart';
import '../teacher/teacher_lecture_summary_screen.dart';
import '../../services/live_session_lockdown.dart';
import '../../services/course_file_upload.dart';
import '../../widgets/topic_slides_viewer.dart';
import '../../widgets/live_lecture_workspace.dart';
import '../../widgets/live_slide_feedback_bar.dart';

List<TopicModel> _topicsInChapterOrder(List<TopicModel> topics) {
  final ordered = [...topics]..sort((a, b) => a.position.compareTo(b.position));
  return ordered;
}

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    super.key,
    required this.courseName,
    required this.session,
    required this.canManage,
    this.teacherId = '',
  });

  final String courseName;
  final LiveSessionModel session;
  final bool canManage;
  final String teacherId;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  Stream<LiveSessionModel?>? _sessionStream;
  Stream<List<ChapterModel>>? _chaptersStream;
  Stream<List<TopicModel>>? _topicsStream;
  Stream<List<LectureAttendee>>? _attendeesStream;
  DateTime? _startedAtAnchor;
  DateTime? _autoEndScheduledFor;
  Timer? _autoEndTimer;
  var _ending = false;
  var _addingTopic = false;
  var _autoEndAttempted = false;
  var _attendanceMarked = false;
  var _studentJoinedLive = false;
  var _openedFeedbackScreen = false;
  var _sessionEffectsScheduled = false;
  var _lockdownStarted = false;
  var _leftAppWhileLive = false;
  var _lockdownHintShown = false;
  LiveSessionModel? _pendingSession;
  final _scrollController = ScrollController();

  bool get _studentLiveFocus =>
      !widget.canManage && _studentJoinedLive && !_openedFeedbackScreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startedAtAnchor = widget.session.startedAt;
    _studentJoinedLive = !widget.canManage && widget.session.isActive;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAttendance();
      if (_studentJoinedLive) {
        unawaited(_startStudentLockdown());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).courseStore;
    _sessionStream ??= store.watchLiveSession(
      widget.session.courseId,
      widget.session.id,
    );
    _chaptersStream ??= store.watchChapters(widget.session.courseId);
    _topicsStream ??= store
        .watchTopics(widget.session.courseId, widget.session.chapterId)
        .asBroadcastStream();
    _attendeesStream ??= store.watchLectureAttendees(widget.session.id);
  }

  Future<void> _markAttendance() async {
    if (_attendanceMarked || widget.canManage || !widget.session.isActive) {
      return;
    }
    _attendanceMarked = true;
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user == null) {
      return;
    }
    try {
      await scope.courseStore.markLectureAttendance(
        lectureId: widget.session.id,
        studentId: user.id,
        studentName: user.fullName,
        studentEmail: user.email,
        memberId: user.memberId,
      );
    } catch (_) {
      _attendanceMarked = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoEndTimer?.cancel();
    _scrollController.dispose();
    _pulse.dispose();
    if (_lockdownStarted) {
      unawaited(LiveSessionLockdown.disable());
      _lockdownStarted = false;
    }
    super.dispose();
  }

  CourseStore? _presenceStore;
  String? _presenceStudentId;

  void _cachePresenceHandles() {
    if (!mounted || widget.canManage) {
      return;
    }
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      return;
    }
    _presenceStore = scope.courseStore;
    _presenceStudentId = scope.sessionController.user?.id;
  }

  Future<void> _setPresence(bool inApp) async {
    final store = _presenceStore;
    final studentId = _presenceStudentId;
    if (store == null || studentId == null || studentId.isEmpty) {
      return;
    }
    await store.updateAttendeePresence(
      lectureId: widget.session.id,
      studentId: studentId,
      inApp: inApp,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_studentLiveFocus) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _leftAppWhileLive = true;
      unawaited(_setPresence(false));
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_setPresence(true));
      if (_leftAppWhileLive && mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _startStudentLockdown() async {
    if (widget.canManage || _lockdownStarted || !mounted) {
      return;
    }
    _lockdownStarted = true;
    _cachePresenceHandles();
    final status = await LiveSessionLockdown.enable();
    if (!mounted) {
      return;
    }
    _cachePresenceHandles();
    unawaited(_setPresence(true));
    if (!_lockdownHintShown) {
      _lockdownHintShown = true;
      _showLockdownHint(status);
    }
  }

  Future<void> _stopStudentLockdown() async {
    if (!_lockdownStarted) {
      return;
    }
    _lockdownStarted = false;
    await LiveSessionLockdown.disable();
  }

  void _showLockdownHint(LiveLockdownStatus status) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          status.platform == 'ios'
              ? l10n.liveFocusModeIosHint
              : l10n.liveFocusModeAndroidHint,
        ),
        action: status.needsDndPermission
            ? SnackBarAction(
                label: l10n.liveFocusOpenDndSettings,
                onPressed: () {
                  unawaited(
                    LiveSessionLockdown.openNotificationPolicySettings(),
                  );
                },
              )
            : null,
      ),
    );
  }

  void _showStayInLectureDialog() {
    final l10n = AppLocalizations.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.liveFocusStayTitle),
          content: Text(l10n.liveFocusStayBody),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
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

  void _openStudentFeedback(LiveSessionModel session) {
    if (_openedFeedbackScreen || widget.canManage || !_studentJoinedLive) {
      return;
    }
    _openedFeedbackScreen = true;
    final course = _course();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => StudentSlideFeedbackSummaryScreen(
            session: session,
            courseName: course?.name ?? widget.courseName,
            courseCode: course?.code ?? '',
            department: course?.department ?? '',
            teacherName: course?.teacherName ?? '',
          ),
        ),
      );
    });
    // The callback is often registered from another post-frame callback, after
    // the header ticker has been stopped. Schedule a frame so it cannot sit
    // unrun until some unrelated event.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _openTeacherSummary(
    LiveSessionModel session, {
    LectureSummary? summary,
  }) {
    if (_openedFeedbackScreen || !widget.canManage) {
      return;
    }
    _openedFeedbackScreen = true;
    final course = _course();
    final endedSession = session.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: session.endedAt ?? DateTime.now(),
    );
    final resolvedSummary =
        summary ??
        LectureSummary.fromLecture(
          LectureModel(
            id: endedSession.id,
            courseId: endedSession.courseId,
            courseName: course?.name ?? widget.courseName,
            teacherId: widget.teacherId.isNotEmpty
                ? widget.teacherId
                : endedSession.teacherId,
            teacherName: course?.teacherName ?? '',
            chapterId: endedSession.chapterId,
            chapterTitle: endedSession.chapterTitle,
            topicId: endedSession.topicId,
            topicTitle: endedSession.topicTitle,
            durationMinutes: endedSession.durationMinutes,
            status: LectureStatus.ended,
            startedAt: endedSession.startedAt,
            endedAt: endedSession.endedAt,
          ),
          courseCode: course?.code ?? '',
          department: course?.department ?? '',
          semester: course?.semester ?? '',
          section: course?.section ?? '',
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TeacherLectureSummaryScreen(
            session: endedSession,
            courseName: course?.name ?? widget.courseName,
            courseCode: course?.code ?? '',
            department: course?.department ?? '',
            semester: course?.semester ?? '',
            teacherId: widget.teacherId.isNotEmpty
                ? widget.teacherId
                : session.teacherId,
            summary: resolvedSummary,
          ),
        ),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _end(LiveSessionModel session) async {
    if (_ending) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.endLecture),
            content: Text(l10n.endLectureConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: Text(l10n.endLecture),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _finish(session);
  }

  Future<void> _finish(
    LiveSessionModel session, {
    bool showError = true,
  }) async {
    if (_ending || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _ending = true);
    try {
      final summary = await AppScope.of(context).courseStore.endLiveSession(
        session.courseId,
        session.id,
        widget.teacherId,
      );
      if (mounted && widget.canManage) {
        _openTeacherSummary(session, summary: summary);
      }
    } catch (error, stackTrace) {
      debugPrint('endLiveSession failed: $error');
      debugPrint('$stackTrace');
      if (mounted && showError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.liveSessionEndFailed)));
      }
    } finally {
      if (mounted && !_openedFeedbackScreen) {
        setState(() => _ending = false);
      }
    }
  }

  DateTime? _stableStartedAt(LiveSessionModel session) {
    final started = session.startedAt;
    // Lock the first resolved start time so Firestore timestamp
    // corrections don't make the elapsed timer jump.
    if (_startedAtAnchor != null) {
      return _startedAtAnchor;
    }
    if (started != null) {
      _startedAtAnchor = started;
    }
    return _startedAtAnchor;
  }

  void _scheduleAutoEnd(LiveSessionModel session, DateTime startedAt) {
    if (!widget.canManage || !session.isActive || _autoEndAttempted) {
      return;
    }
    if (_autoEndScheduledFor == startedAt && _autoEndTimer != null) {
      return;
    }
    _autoEndTimer?.cancel();
    _autoEndScheduledFor = startedAt;
    final remaining = startedAt
        .add(Duration(minutes: session.durationMinutes))
        .difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _autoEndAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finish(session, showError: false);
      });
      return;
    }
    _autoEndTimer = Timer(remaining, () {
      if (!mounted || _autoEndAttempted) {
        return;
      }
      _autoEndAttempted = true;
      _finish(session, showError: false);
    });
  }

  Future<void> _changeTopicDuringLecture(LiveSessionModel session) async {
    if (!widget.canManage || _addingTopic) {
      return;
    }
    final chapterId = session.chapterId.trim();
    if (session.courseId.isEmpty || chapterId.isEmpty) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final newTopicId = DateTime.now().microsecondsSinceEpoch.toString();
    var existingTopics = const <TopicModel>[];
    try {
      existingTopics = _topicsInChapterOrder(
        await AppScope.of(
          context,
        ).courseStore.watchTopics(session.courseId, chapterId).first,
      );
    } catch (error, stackTrace) {
      debugPrint('load topics before change failed: $error');
      debugPrint('$stackTrace');
    }
    if (!mounted) {
      return;
    }

    // Dialog returns either an existing topic pick or a brand-new topic draft.
    // Controllers live in the dialog state so dispose stays tied to the route.
    final choice = await showDialog<_LiveTopicChoice>(
      context: context,
      builder: (dialogContext) {
        return _ChangeTopicDuringLectureDialog(
          l10n: l10n,
          courseId: session.courseId,
          uploadFolder: 'topics/$chapterId/$newTopicId',
          existingTopics: existingTopics,
          currentTopicId: session.topicId,
        );
      },
    );

    await Future<void>.delayed(Duration.zero);
    if (!mounted || choice == null) {
      return;
    }

    if (choice.existing != null && choice.existing!.id == session.topicId) {
      return;
    }

    setState(() => _addingTopic = true);
    final store = AppScope.of(context).courseStore;
    try {
      late final String topicId;
      late final String topicTitle;
      if (choice.existing != null) {
        topicId = choice.existing!.id;
        topicTitle = choice.existing!.title.trim();
      } else {
        final draft = choice.draft!;
        topicId = newTopicId;
        topicTitle = draft.title;
        await store.addTopic(
          session.courseId,
          chapterId,
          TopicModel(
            id: topicId,
            title: draft.title,
            description: draft.description,
            attachments: draft.attachments,
          ),
        );
      }

      // Same live session + lecture docs — only the topic pointer moves.
      await store.updateLiveSessionTopic(
        courseId: session.courseId,
        sessionId: session.id,
        topicId: topicId,
        topicTitle: topicTitle,
      );
      // New topic deck starts at the first slide for everyone.
      await store.updateLiveSlidePosition(
        courseId: session.courseId,
        sessionId: session.id,
        fileIndex: 0,
        page: 1,
      );
      await store.updateLiveSlideView(
        courseId: session.courseId,
        sessionId: session.id,
        view: LiveSlideView(
          fileIndex: 0,
          page: 1,
          zoom: 1,
          cx: 0.5,
          cy: 0.5,
          ts: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.lectureTopicSwitched(topicTitle))),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('changeTopic during lecture failed: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.contentSaveFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _addingTopic = false);
      }
    }
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

  /// Session-end work must not run inside [build]. Stopping [_pulse] notifies
  /// the header [AnimatedBuilder], and [Navigator.pushReplacement] then removes
  /// the live route while that rebuild is still registering [AppScope]
  /// dependents, which fails `InheritedElement._dependents.isEmpty`.
  void _scheduleSessionEffects(LiveSessionModel session) {
    _pendingSession = session;
    if (_sessionEffectsScheduled) {
      return;
    }
    _sessionEffectsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionEffectsScheduled = false;
      final pending = _pendingSession;
      if (!mounted || pending == null) {
        return;
      }
      _applySessionEffects(pending);
    });
  }

  void _applySessionEffects(LiveSessionModel session) {
    if (!mounted) {
      return;
    }
    final startedAt = _stableStartedAt(session);
    if (session.isActive && startedAt != null) {
      _scheduleAutoEnd(session, startedAt);
    } else {
      _autoEndTimer?.cancel();
      _autoEndTimer = null;
    }
    if (session.isActive) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    } else if (_pulse.isAnimating || _pulse.value != 0) {
      // Stop before scheduling navigation so the header ticker is idle
      // before the route is replaced on the following frame.
      _pulse.stop();
      if (_pulse.value != 0) {
        _pulse.value = 0;
      }
    }
    if (!session.isActive &&
        !widget.canManage &&
        _studentJoinedLive &&
        !_openedFeedbackScreen) {
      unawaited(_stopStudentLockdown());
      _openStudentFeedback(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return StreamBuilder<LiveSessionModel?>(
      stream: _sessionStream,
      initialData: widget.session,
      builder: (context, snapshot) {
        final session = snapshot.data ?? widget.session;
        final l10n = AppLocalizations.of(context);
        final course = _course();
        final startedAt = _stableStartedAt(session);
        _scheduleSessionEffects(session);

        final studentFocusActive =
            !widget.canManage && session.isActive && _studentJoinedLive;

        return PopScope(
          canPop: !studentFocusActive,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && studentFocusActive) {
              _showStayInLectureDialog();
            }
          },
          child: Scaffold(
            backgroundColor: brightness == Brightness.dark
                ? AppColors.darkBackground
                : const Color(0xFFF3F6FA),
            body: Column(
              children: [
                _Header(
                  pulse: _pulse,
                  active: session.isActive,
                  liveLabel: session.isActive
                      ? l10n.liveLecture
                      : l10n.lectureComplete,
                  startedAt: startedAt,
                  title: l10n.liveLecture,
                  subtitle: widget.canManage
                      ? l10n.teachingLiveHint
                      : l10n.attendingLiveHint,
                  onHome: studentFocusActive
                      ? _showStayInLectureDialog
                      : () => Navigator.of(context).pushNamedAndRemoveUntil(
                          widget.canManage
                              ? AppRoutes.teacherDashboard
                              : AppRoutes.studentDashboard,
                          (route) => false,
                        ),
                ),
                StreamBuilder<List<LiveSessionModel>>(
                  stream: AppScope.of(context).courseStore
                      .watchEndedSessionsForTopic(
                        courseId: session.courseId,
                        chapterId: session.chapterId,
                        topicId: session.topicId,
                      ),
                  builder: (context, endedSnap) {
                    final ended = endedSnap.data;
                    if (ended == null) {
                      return const SizedBox.shrink();
                    }
                    final number = lectureOrdinalForTopic(
                      session: session,
                      endedForTopic: ended,
                    );
                    final labelBrightness = Theme.of(context).brightness;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.lectureNumber(number),
                          style: TextStyle(
                            color: AppColors.textPrimary(labelBrightness),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (studentFocusActive && _leftAppWhileLive)
                  Material(
                    color: AppColors.error.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.liveFocusLeftAppWarn,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _leftAppWhileLive = false),
                            child: Text(l10n.ok),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: LiveLectureWorkspace(
                    controller: _scrollController,
                    courseIdentity: _CourseIdentityCard(
                      name: course?.name ?? widget.courseName,
                      code: course?.code ?? '',
                      semester: course?.semester ?? '',
                      department: course?.department ?? '',
                      creditHours: course?.creditHours,
                      viewDetailsLabel: l10n.viewDetails,
                      onViewDetails: course == null || studentFocusActive
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CourseDetailScreen(
                                  course: course,
                                  canDelete: widget.canManage,
                                ),
                              ),
                            ),
                    ),
                    lectureInfo: StreamBuilder(
                      stream: _chaptersStream,
                      builder: (context, chaptersSnap) {
                        final chapters = chaptersSnap.data ?? const [];
                        final chapterIndex = chapters.indexWhere(
                          (c) => c.id == session.chapterId,
                        );
                        final chapterLine = session.chapterTitle.trim().isEmpty
                            ? '—'
                            : chapterIndex < 0
                            ? session.chapterTitle
                            : '${l10n.chapterNumber(chapterIndex + 1)} · ${session.chapterTitle}';
                        return _SectionCard(
                          title: l10n.lectureInformation,
                          icon: Icons.play_circle_outline_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                chapterLine,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: AppColors.textPrimary(brightness),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                session.topicTitle.trim().isEmpty
                                    ? '—'
                                    : session.topicTitle,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: AppColors.textSecondary(brightness),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _LectureMeta(
                                label: l10n.startTime,
                                title: _formatTime(startedAt),
                                subtitle: _formatDate(startedAt),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    slides: StreamBuilder<List<TopicModel>>(
                      stream: _topicsStream,
                      builder: (context, topicsSnap) {
                        final topics = topicsSnap.data ?? const <TopicModel>[];
                        TopicModel? topic;
                        for (final item in topics) {
                          if (item.id == session.topicId) {
                            topic = item;
                            break;
                          }
                        }
                        final attachments =
                            topic?.attachments ?? const <CourseAttachment>[];
                        if (attachments.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TopicSlidesViewer(
                              attachments: attachments,
                              courseId: session.courseId,
                              isPresenter: widget.canManage,
                              followFileIndex: session.slideFileIndex,
                              followPage: session.slidePage,
                              hideFileInLabel: true,
                              followViewport: session.slideView == null
                                  ? null
                                  : (
                                      fileIndex: session.slideView!.fileIndex,
                                      page: session.slideView!.page,
                                      zoom: session.slideView!.zoom,
                                      cx: session.slideView!.cx,
                                      cy: session.slideView!.cy,
                                      ts: session.slideView!.ts,
                                    ),
                              onSlideChanged: widget.canManage
                                  ? (pos) {
                                      unawaited(
                                        AppScope.of(
                                          context,
                                        ).courseStore.updateLiveSlidePosition(
                                          courseId: session.courseId,
                                          sessionId: session.id,
                                          fileIndex: pos.fileIndex,
                                          page: pos.page,
                                        ),
                                      );
                                    }
                                  : null,
                              onViewportChanged: widget.canManage
                                  ? (vp) {
                                      unawaited(() async {
                                        try {
                                          await AppScope.of(
                                            context,
                                          ).courseStore.updateLiveSlideView(
                                            courseId: session.courseId,
                                            sessionId: session.id,
                                            view: LiveSlideView(
                                              fileIndex: vp.fileIndex,
                                              page: vp.page,
                                              zoom: vp.zoom,
                                              cx: vp.cx,
                                              cy: vp.cy,
                                              ts: vp.ts > 0
                                                  ? vp.ts
                                                  : DateTime.now()
                                                        .millisecondsSinceEpoch,
                                            ),
                                          );
                                        } catch (error, stackTrace) {
                                          debugPrint(
                                            'updateLiveSlideView failed: $error',
                                          );
                                          debugPrint('$stackTrace');
                                        }
                                      }());
                                    }
                                  : null,
                            ),
                            if (session.isActive) ...[
                              const SizedBox(height: 10),
                              if (widget.canManage)
                                LiveSlideSignalsPanel(session: session)
                              else if (_studentJoinedLive &&
                                  AppScope.of(context).sessionController.user !=
                                      null)
                                LiveSlideFeedbackBar(
                                  session: session,
                                  user: AppScope.of(
                                    context,
                                  ).sessionController.user!,
                                ),
                            ],
                            const SizedBox(height: 14),
                          ],
                        );
                      },
                    ),
                    controls: [
                      if (widget.canManage) ...[
                        OutlinedButton.icon(
                          onPressed:
                              _addingTopic ||
                                  session.courseId.isEmpty ||
                                  session.chapterId.trim().isEmpty
                              ? null
                              : () => _changeTopicDuringLecture(session),
                          icon: _addingTopic
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.swap_horiz_rounded, size: 20),
                          label: Text(l10n.changeTopic),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.teal,
                            side: BorderSide(
                              color: AppColors.teal.withValues(alpha: 0.55),
                            ),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                    attendees: StreamBuilder<List<LectureAttendee>>(
                      stream: _attendeesStream,
                      builder: (context, attendeesSnap) {
                        final attendees = attendeesSnap.data ?? const [];
                        return _SectionCard(
                          title: l10n.attendeesCount(attendees.length),
                          icon: Icons.groups_rounded,
                          child: attendees.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    session.isActive
                                        ? l10n.waitingForStudents
                                        : l10n.noStudentsYet,
                                    style: TextStyle(
                                      color: AppColors.textSecondary(
                                        brightness,
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (final student in attendees)
                                      _AttendeeRow(
                                        name: student.studentName,
                                        email: student.studentEmail.isEmpty
                                            ? student.memberId
                                            : student.studentEmail,
                                        joined: student.joinedAt == null
                                            ? null
                                            : l10n.joinedAt(
                                                _formatTime(student.joinedAt),
                                              ),
                                        inApp: student.inApp,
                                        awayLabel: l10n.liveFocusStudentAway,
                                      ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ),
                if (widget.canManage && session.isActive)
                  _BottomBar(ending: _ending, onEnd: () => _end(session)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pulse,
    required this.active,
    required this.liveLabel,
    required this.startedAt,
    required this.title,
    required this.subtitle,
    required this.onHome,
  });

  final AnimationController pulse;
  final bool active;
  final String liveLabel;
  final DateTime? startedAt;
  final String title;
  final String subtitle;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 4,
        bottom: 16,
      ),
      decoration: const BoxDecoration(color: AppColors.headerNavy),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 12, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).navDashboard,
                  onPressed: onHome,
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: active
                              ? AppColors.coral.withValues(alpha: 0.85)
                              : Colors.white24,
                        ),
                        boxShadow: [
                          if (active)
                            BoxShadow(
                              color: AppColors.coral.withValues(
                                alpha: 0.2 + pulse.value * 0.25,
                              ),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active ? AppColors.coral : AppColors.teal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            liveLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  _ElapsedTimer(
                    key: const ValueKey('live-elapsed'),
                    startedAt: startedAt,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer({super.key, required this.startedAt});

  final DateTime? startedAt;

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _compute();
      if (next != _elapsed && mounted) {
        setState(() => _elapsed = next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMs = oldWidget.startedAt?.millisecondsSinceEpoch;
    final nextMs = widget.startedAt?.millisecondsSinceEpoch;
    if (oldMs != nextMs) {
      setState(() => _elapsed = _compute());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _compute() {
    final started = widget.startedAt;
    if (started == null) {
      return Duration.zero;
    }
    final seconds = DateTime.now()
        .difference(started)
        .inSeconds
        .clamp(0, 359999);
    return Duration(seconds: seconds);
  }

  @override
  Widget build(BuildContext context) {
    final total = _elapsed.inSeconds;
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return Text(
      '$hours:$minutes:$seconds',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: 1,
      ),
    );
  }
}

class _CourseIdentityCard extends StatelessWidget {
  const _CourseIdentityCard({
    required this.name,
    required this.code,
    required this.semester,
    required this.department,
    required this.creditHours,
    required this.viewDetailsLabel,
    this.onViewDetails,
  });

  final String name;
  final String code;
  final String semester;
  final String department;
  final int? creditHours;
  final String viewDetailsLabel;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.teal,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AppColors.textPrimary(brightness),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (onViewDetails != null)
                      TextButton(
                        onPressed: onViewDetails,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          viewDetailsLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (code.trim().isNotEmpty) _Tag(text: code, filled: true),
                    if (semester.trim().isNotEmpty)
                      _Tag(text: semester, filled: false),
                    if (creditHours != null)
                      _Tag(
                        text: AppLocalizations.of(
                          context,
                        ).creditHoursValue(creditHours!),
                        filled: false,
                      ),
                  ],
                ),
                if (department.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    department,
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      fontSize: 12.5,
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.filled});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.teal.withValues(alpha: 0.14)
            : const Color(0xFFE8F0FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? AppColors.tealDark : AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LectureMeta extends StatelessWidget {
  const _LectureMeta({
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
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
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary(brightness),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary(brightness),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({
    required this.name,
    required this.email,
    required this.joined,
    this.inApp = true,
    this.awayLabel = 'Away',
  });

  final String name;
  final String email;
  final String? joined;
  final bool inApp;
  final String awayLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final statusColor = inApp
        ? const Color(0xFF1B9E5A)
        : const Color(0xFFE2A336);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.teal.withValues(alpha: 0.14),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
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
                if (!inApp)
                  Text(
                    awayLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.ending, required this.onEnd});

  final bool ending;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.fieldFill(brightness),
      elevation: 8,
      shadowColor: AppColors.navy.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: ending ? null : onEnd,
            icon: ending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.stop_rounded, size: 18),
            label: Text(l10n.endLecture),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveTopicChoice {
  const _LiveTopicChoice.existing(this.existing) : draft = null;
  const _LiveTopicChoice.draft(this.draft) : existing = null;

  final TopicModel? existing;
  final ({
    String title,
    String description,
    List<CourseAttachment> attachments,
  })?
  draft;
}

class _ChangeTopicDuringLectureDialog extends StatefulWidget {
  const _ChangeTopicDuringLectureDialog({
    required this.l10n,
    required this.courseId,
    required this.uploadFolder,
    required this.existingTopics,
    required this.currentTopicId,
  });

  final AppLocalizations l10n;
  final String courseId;
  final String uploadFolder;
  final List<TopicModel> existingTopics;
  final String currentTopicId;

  @override
  State<_ChangeTopicDuringLectureDialog> createState() =>
      _ChangeTopicDuringLectureDialogState();
}

class _ChangeTopicDuringLectureDialogState
    extends State<_ChangeTopicDuringLectureDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _attachments = <CourseAttachment>[];
  var _uploading = false;
  var _addingNew = false;
  String? _attachmentsError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickExisting(TopicModel topic) {
    if (_uploading) {
      return;
    }
    Navigator.of(context).pop(_LiveTopicChoice.existing(topic));
  }

  void _submitNew() {
    if (_uploading || _formKey.currentState?.validate() != true) {
      return;
    }
    final l10n = widget.l10n;
    if (_attachments.isEmpty) {
      setState(() => _attachmentsError = l10n.topicFilesRequired);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.topicFilesRequired)));
      return;
    }
    Navigator.of(context).pop(
      _LiveTopicChoice.draft((
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        attachments: List<CourseAttachment>.unmodifiable(_attachments),
      )),
    );
  }

  Future<void> _addFile() async {
    if (_uploading) {
      return;
    }
    final l10n = widget.l10n;
    try {
      final picked = await CourseFileUpload.pickFiles(
        extensions: CourseFileUpload.syllabusExtensions,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      setState(() => _uploading = true);
      final files = await CourseFileUpload.uploadFiles(
        courseId: widget.courseId,
        folder: widget.uploadFolder,
        files: picked,
      );
      if (!mounted || files.isEmpty) {
        return;
      }
      setState(() {
        _attachments.addAll(
          files.map((file) => CourseAttachment(name: file.name, url: file.url)),
        );
        _attachmentsError = null;
      });
    } on CourseFileException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileUploadError(l10n, error.code))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fileUploadFailed)));
    } finally {
      if (mounted && _uploading) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final brightness = Theme.of(context).brightness;
    final topics = widget.existingTopics;
    return AlertDialog(
      title: Text(l10n.changeTopic),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.continueLectureHint,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  fontSize: 13,
                ),
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.selectTopic,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                for (final topic in topics)
                  if (topic.title.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: topic.id == widget.currentTopicId
                            ? AppColors.teal.withValues(alpha: 0.12)
                            : AppColors.fieldFill(brightness),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _uploading ? null : () => _pickExisting(topic),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              12,
                              10,
                              10,
                              10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  topic.id == widget.currentTopicId
                                      ? Icons.check_circle_rounded
                                      : Icons.topic_outlined,
                                  size: 20,
                                  color: AppColors.teal,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        topic.title.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textPrimary(
                                            brightness,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (topic.id == widget.currentTopicId)
                                        Text(
                                          l10n.currentTopic,
                                          style: TextStyle(
                                            color: AppColors.textSecondary(
                                              brightness,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.teal,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 8),
              if (!_addingNew)
                OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => setState(() => _addingNew = true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.addTopic),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: BorderSide(
                      color: AppColors.teal.withValues(alpha: 0.55),
                    ),
                  ),
                )
              else ...[
                const Divider(height: 22),
                Text(
                  l10n.addTopic,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.topicTitle,
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 240,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.topicDescription,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  onFieldSubmitted: (_) => _submitNew(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.topicFilesRequiredHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: _attachmentsError != null
                          ? Theme.of(context).colorScheme.error
                          : AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
                if (_attachmentsError != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _attachmentsError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (_attachments.isNotEmpty)
                  for (var i = 0; i < _attachments.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        11,
                        7,
                        4,
                        7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            color: AppColors.teal,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _attachments[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.removeFile,
                            visualDensity: VisualDensity.compact,
                            onPressed: _uploading
                                ? null
                                : () => setState(() {
                                    _attachments.removeAt(i);
                                    if (_attachments.isEmpty) {
                                      _attachmentsError =
                                          l10n.topicFilesRequired;
                                    }
                                  }),
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (_addingNew) ...[
          IconButton(
            tooltip: l10n.addFiles,
            onPressed: _uploading ? null : _addFile,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file_rounded),
            color: AppColors.teal,
          ),
          FilledButton(
            onPressed: _uploading ? null : _submitNew,
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text(l10n.add),
          ),
        ],
      ],
    );
  }
}

String _fileUploadError(AppLocalizations l10n, String code) {
  switch (code) {
    case 'file_too_large':
      return l10n.fileTooLarge;
    case 'file_unreadable':
      return l10n.fileUnreadable;
    case 'storage_denied':
      return l10n.storageDenied;
    default:
      return l10n.fileUploadFailed;
  }
}
