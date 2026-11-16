import 'dart:async';

import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/session/course_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_errors.dart';
import '../../core/utils/live_join_gate.dart';
import '../../models/course_join_request.dart';
import '../../models/course_model.dart';
import '../../models/live_session_model.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/course_enrollment_service.dart';
import '../../widgets/course_card.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/responsive_card_list.dart';
import '../../widgets/student_home_header.dart';
import '../common/course_detail_screen.dart';
import '../common/live_session_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _linking = false;
  bool _showCourses = false;
  String _lastLinkedQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    if (at <= 0) {
      return false;
    }
    final dot = value.indexOf('.', at + 1);
    return dot > at + 1 && dot < value.length - 1 && !value.contains(' ');
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      if (_showCourses || _lastLinkedQuery.isNotEmpty) {
        setState(() {
          _showCourses = false;
          _lastLinkedQuery = '';
        });
      }
      return;
    }

    if (_showCourses && query != _lastLinkedQuery) {
      setState(() => _showCourses = false);
    }

    if (!_looksLikeEmail(query)) {
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      if (_searchController.text.trim() != query) {
        return;
      }
      _searchTeacher(fromTyping: true);
    });
  }

  Future<void> _searchTeacher({bool fromTyping = false}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _linking) {
      return;
    }
    if (fromTyping && !_looksLikeEmail(query)) {
      return;
    }
    if (query == _lastLinkedQuery && _showCourses) {
      return;
    }

    final scope = AppScope.of(context);
    final existing = scope.sessionController.user;
    final existingEmail = (existing?.connectedTeacherEmail ?? '')
        .trim()
        .toLowerCase();
    if (existing != null &&
        existingEmail.isNotEmpty &&
        existingEmail == query.toLowerCase() &&
        (existing.connectedTeacherId ?? '').isNotEmpty) {
      scope.courseStore.watchTeacher(existing.connectedTeacherId);
      setState(() {
        _showCourses = true;
        _lastLinkedQuery = query;
      });
      return;
    }

    setState(() => _linking = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = await scope.authService.linkTeacher(query: query);
      if (!mounted) {
        return;
      }
      if (user.role != UserRole.student) {
        return;
      }
      scope.sessionController.signIn(user);
      scope.courseStore.watchTeacher(user.connectedTeacherId);
      setState(() {
        _showCourses = true;
        _lastLinkedQuery = query;
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(authErrorMessage(l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() => _linking = false);
      }
    }
  }

  String _courseSubtitle(CourseModel course, AppLocalizations l10n) {
    final parts = <String>[
      if (course.code.isNotEmpty) course.code,
      if (course.department.isNotEmpty) course.department,
    ];
    return parts.isEmpty
        ? l10n.topicsCount(course.topicCount)
        : parts.join(' · ');
  }

  void _openCourse(CourseModel course, {required bool isMember}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailScreen(
          course: course,
          canDelete: false,
          isMember: isMember,
        ),
      ),
    );
  }

  Future<void> _openLiveLecture(
    LiveSessionModel session,
    String courseName,
  ) async {
    final scope = AppScope.of(context);
    if (scope.sessionController.user?.role != UserRole.student) {
      return;
    }
    final allowed = await LiveJoinGate.confirmIfNeeded(
      context: context,
      session: session,
      courseName: courseName,
    );
    if (!allowed || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveSessionScreen(
          courseName: courseName,
          session: session,
          canManage: false,
        ),
      ),
    );
  }

  Future<void> _onLiveIconPressed(List<_LiveCourseSession> lives) async {
    if (lives.isEmpty) {
      return;
    }
    if (lives.length == 1) {
      final item = lives.first;
      await _openLiveLecture(item.session, item.courseName);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<_LiveCourseSession>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.liveLectures,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.chooseLiveLecture,
                  style: TextStyle(color: AppColors.textSecondary(brightness)),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: lives.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = lives[index];
                      return _LiveLecturePickTile(
                        courseName: item.courseName,
                        topicTitle: item.session.topicTitle,
                        joinLabel: l10n.joinLecture,
                        onJoin: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    await _openLiveLecture(selected.session, selected.courseName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final session = scope.sessionController;

    return ListenableBuilder(
      listenable: Listenable.merge([session, scope.courseStore]),
      builder: (context, _) {
        final user = session.user;
        final isStudent = user?.role == UserRole.student;
        final name = user?.fullName ?? l10n.student;
        final courses = scope.courseStore.courses;
        final teacherId = user?.connectedTeacherId ?? '';
        // Live icon: student role + linked teacher — even before search.
        final showLiveIcon =
            isStudent && session.hasTeacherLink && teacherId.isNotEmpty;

        return DashboardScaffold(
          embeddedInShell: true,
          roleLabel: l10n.student,
          showAppBar: false,
          header: StudentHomeHeader(
            userName: name,
            photoUrl: user?.photoUrl ?? '',
            searchController: _searchController,
            onSearch: _searchTeacher,
            appBarActions: [
              if (showLiveIcon)
                _LiveLectureAppBarAction(
                  courses: courses,
                  studentId: user?.id ?? '',
                  onPressed: _onLiveIconPressed,
                ),
            ],
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              if (_linking)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.8),
                    ),
                  ),
                )
              else if (!_showCourses)
                _EmptyNote(text: l10n.noCoursesStudent)
              else if (courses.isEmpty)
                _EmptyNote(text: l10n.teacherHasNoCourses)
              else
                ResponsiveCardList(
                  children: courses
                      .map(
                        (course) => _StudentCourseEntry(
                          course: course,
                          subtitle: _courseSubtitle(course, l10n),
                          studentId: user?.id ?? '',
                          onCourseTap: (isMember) =>
                              _openCourse(course, isMember: isMember),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveCourseSession {
  const _LiveCourseSession({required this.courseName, required this.session});

  final String courseName;
  final LiveSessionModel session;
}

class _LiveLectureAppBarAction extends StatefulWidget {
  const _LiveLectureAppBarAction({
    required this.courses,
    required this.studentId,
    required this.onPressed,
  });

  final List<CourseModel> courses;
  final String studentId;
  final Future<void> Function(List<_LiveCourseSession> lives) onPressed;

  @override
  State<_LiveLectureAppBarAction> createState() =>
      _LiveLectureAppBarActionState();
}

class _LiveLectureAppBarActionState extends State<_LiveLectureAppBarAction> {
  Stream<List<_LiveCourseSession>>? _lives;
  String _signature = '';
  CourseStore? _store;
  CourseEnrollmentService? _enrollment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncStream();
  }

  @override
  void didUpdateWidget(covariant _LiveLectureAppBarAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncStream();
  }

  void _syncStream() {
    final courses = widget.courses;
    final studentId = widget.studentId;
    if (courses.isEmpty || studentId.isEmpty) {
      _signature = '';
      _lives = null;
      _store = null;
      _enrollment = null;
      return;
    }

    final scope = AppScope.of(context);
    final store = scope.courseStore;
    final enrollment = scope.enrollment;
    final signature = _liveIconSignature(studentId, courses);
    if (_lives != null &&
        signature == _signature &&
        identical(store, _store) &&
        identical(enrollment, _enrollment)) {
      return;
    }
    _signature = signature;
    _store = store;
    _enrollment = enrollment;
    _lives = _watchJoinedLiveSessions(
      courses: courses,
      studentId: studentId,
      enrollment: enrollment,
      store: store,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lives = _lives;
    if (lives == null) {
      return IconButton(
        tooltip: l10n.liveLectures,
        onPressed: null,
        icon: const Icon(Icons.podcasts_rounded),
      );
    }
    // Joined courses only. Stay subscribed so a lecture that starts later
    // turns the icon red without rebuilding the future.
    return StreamBuilder<List<_LiveCourseSession>>(
      stream: lives,
      builder: (context, snapshot) {
        final active = snapshot.data ?? const <_LiveCourseSession>[];
        final hasLive = active.isNotEmpty;
        return IconButton(
          tooltip: l10n.liveLectures,
          onPressed: hasLive ? () => widget.onPressed(active) : null,
          icon: Icon(
            Icons.podcasts_rounded,
            color: hasLive ? AppColors.coral : null,
          ),
        );
      },
    );
  }
}

String _liveIconSignature(String studentId, List<CourseModel> courses) {
  final buffer = StringBuffer(studentId)
    ..write('|')
    ..write(courses.length);
  for (final course in courses) {
    buffer
      ..write('|')
      ..write(course.id)
      ..write(':')
      ..write(course.name);
  }
  return buffer.toString();
}

/// Membership + active session per course. Emits again whenever either changes.
Stream<List<_LiveCourseSession>> _watchJoinedLiveSessions({
  required List<CourseModel> courses,
  required String studentId,
  required CourseEnrollmentService enrollment,
  required CourseStore store,
}) {
  late final StreamController<List<_LiveCourseSession>> controller;
  final joined = <String, bool>{for (final course in courses) course.id: false};
  final sessions = <String, LiveSessionModel?>{
    for (final course in courses) course.id: null,
  };
  final joinedReady = <String>{};
  final sessionReady = <String>{};
  final subscriptions = <StreamSubscription<dynamic>>[];

  void emit() {
    if (controller.isClosed ||
        joinedReady.length < courses.length ||
        sessionReady.length < courses.length) {
      return;
    }
    controller.add(<_LiveCourseSession>[
      for (final course in courses)
        if (joined[course.id] == true && sessions[course.id] != null)
          _LiveCourseSession(
            courseName: course.name,
            session: sessions[course.id]!,
          ),
    ]);
  }

  controller = StreamController<List<_LiveCourseSession>>(
    onListen: () {
      for (final course in courses) {
        subscriptions.add(
          enrollment
              .watchIsMember(course.id, studentId)
              .listen(
                (isMember) {
                  joined[course.id] = isMember;
                  joinedReady.add(course.id);
                  emit();
                },
                onError: (Object _, StackTrace _) {
                  joined[course.id] = false;
                  joinedReady.add(course.id);
                  emit();
                },
              ),
        );
        subscriptions.add(
          store
              .watchActiveSession(course.id)
              .listen(
                (session) {
                  sessions[course.id] = session;
                  sessionReady.add(course.id);
                  emit();
                },
                onError: (Object _, StackTrace _) {
                  sessions[course.id] = null;
                  sessionReady.add(course.id);
                  emit();
                },
              ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      subscriptions.clear();
    },
  );
  return controller.stream;
}

class _LiveLecturePickTile extends StatelessWidget {
  const _LiveLecturePickTile({
    required this.courseName,
    required this.topicTitle,
    required this.joinLabel,
    required this.onJoin,
  });

  final String courseName;
  final String topicTitle;
  final String joinLabel;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : const Color(0xFFF4F6FA),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.podcasts_rounded, color: AppColors.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  Text(
                    topicTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onJoin,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(joinLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCourseEntry extends StatelessWidget {
  const _StudentCourseEntry({
    required this.course,
    required this.subtitle,
    required this.studentId,
    required this.onCourseTap,
  });

  final CourseModel course;
  final String subtitle;
  final String studentId;
  final void Function(bool isMember) onCourseTap;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).courseStore;
    final enrollment = AppScope.of(context).enrollment;
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<bool>(
      stream: enrollment.watchIsMember(course.id, studentId),
      builder: (context, memberSnap) {
        final isMember = memberSnap.data ?? false;
        return StreamBuilder<CourseJoinRequest?>(
          stream: enrollment.watchMyRequest(course.id, studentId),
          builder: (context, reqSnap) {
            final request = reqSnap.data;
            var tag = CourseJoinTag.none;
            // Membership doc is the source of truth (teacher remove deletes it).
            if (isMember) {
              tag = CourseJoinTag.joined;
            } else if (request?.isPending ?? false) {
              tag = CourseJoinTag.requestSent;
            }
            return StreamBuilder<LiveSessionModel?>(
              stream: store.watchActiveSession(course.id),
              builder: (context, snapshot) {
                final session = snapshot.data;
                // Live subtitle only when joined
                final showLive = session != null && tag == CourseJoinTag.joined;
                return CourseCard(
                  course: showLive ? course.copyWith(isLive: true) : course,
                  subtitle: showLive
                      ? l10n.liveTopic(session.topicTitle)
                      : subtitle,
                  joinTag: tag,
                  requestSentLabel: l10n.requestSentTag,
                  joinedLabel: l10n.courseJoinedTag,
                  onTap: () => onCourseTap(tag == CourseJoinTag.joined),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary(brightness)),
      ),
    );
  }
}
