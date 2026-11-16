import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/session/course_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/live_join_gate.dart';
import '../../core/utils/responsive.dart';
import '../../models/chapter_model.dart';
import '../../models/course_content.dart';
import '../../models/course_join_request.dart';
import '../../models/course_model.dart';
import '../../models/live_session_model.dart';
import '../../services/course_file_upload.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/course_link_chip.dart';
import '../../widgets/lecture_schedule_section.dart';
import '../../widgets/responsive_card_list.dart';
import 'course_content_screen.dart';
import 'live_session_screen.dart';
import '../teacher/add_course_screen.dart';
import '../teacher/course_lectures_screen.dart';
import '../teacher/course_enrolled_students_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    super.key,
    required this.course,
    this.canDelete = true,
    this.isMember = true,
  });

  final CourseModel course;
  final bool canDelete;

  /// Student membership. Ignored when [canDelete] (teacher) is true.
  final bool isMember;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  var _deleting = false;
  var _uploading = false;
  var _joining = false;

  CourseModel _latest() {
    final id = widget.course.id;
    for (final item in AppScope.of(context).courseStore.courses) {
      if (item.id == id) {
        return item;
      }
    }
    return widget.course;
  }

  String _date(BuildContext context, CourseModel course) {
    final date = course.registrationDate;
    if (date == null) {
      return 'â€”';
    }
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(date);
  }

  Future<void> _onMenu(_CourseMenu action) async {
    switch (action) {
      case _CourseMenu.uploadSyllabus:
        await _uploadSyllabus();
      case _CourseMenu.edit:
        await _editCourse();
      case _CourseMenu.delete:
        await _delete();
    }
  }

  Future<void> _uploadSyllabus() async {
    if (_uploading || _deleting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final store = AppScope.of(context).courseStore;
    try {
      final picked = await CourseFileUpload.pickFiles(
        extensions: CourseFileUpload.syllabusExtensions,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      setState(() => _uploading = true);
      final uploaded = await CourseFileUpload.uploadFiles(
        courseId: _latest().id,
        folder: 'syllabus',
        files: picked,
      );
      if (!mounted || uploaded.isEmpty) {
        return;
      }
      await store.addSyllabusFiles(_latest().id, [
        for (final file in uploaded)
          CourseAttachment(name: file.name, url: file.url),
      ]);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.syllabusUploaded)));
    } on CourseFileException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_fileError(l10n, error.code))));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fileUploadFailed)));
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _editCourse() async {
    await Navigator.of(context).push<CourseModel>(
      MaterialPageRoute<CourseModel>(
        builder: (_) => AddCourseScreen(existing: _latest()),
      ),
    );
  }

  void _openLectureAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseLecturesScreen(course: _latest()),
      ),
    );
  }

  void _openEnrolledStudents() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseEnrolledStudentsScreen(course: _latest()),
      ),
    );
  }

  bool get _studentPreview => !widget.canDelete && !widget.isMember;

  Future<void> _requestJoin() async {
    if (_joining || widget.canDelete) {
      return;
    }
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _joining = true);
    try {
      final sent = await scope.enrollment.requestJoin(
        courseId: _latest().id,
        courseName: _latest().name,
        courseCode: _latest().code,
        studentId: user.id,
        studentName: user.fullName,
        studentEmail: user.email,
        memberId: user.memberId,
      );
      if (!mounted) {
        return;
      }
      if (!sent.isPending) {
        throw StateError('Join request was not sent.');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.joinRequestSent)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.joinRequestFailed)));
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  void _openCourseContent() {
    final course = _latest();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseContentScreen(
          courseId: course.id,
          courseName: course.name,
          canManage: widget.canDelete,
        ),
      ),
    );
  }

  void _openLiveSession(LiveSessionModel session) {
    final scope = AppScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveSessionScreen(
          courseName: _latest().name,
          session: session,
          canManage: widget.canDelete,
          teacherId: scope.sessionController.user?.id ?? '',
        ),
      ),
    );
  }

  Future<void> _joinLiveWithConfirm(LiveSessionModel session) async {
    if (widget.canDelete) {
      _openLiveSession(session);
      return;
    }
    if (!widget.isMember) {
      return;
    }
    final allowed = await LiveJoinGate.confirmIfNeeded(
      context: context,
      session: session,
      courseName: _latest().name,
    );
    if (allowed && mounted) {
      _openLiveSession(session);
    }
  }

  Future<void> _startLecture() async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final course = _latest();
    final teacherId = scope.sessionController.user?.id ?? '';
    try {
      final chapters = await scope.courseStore.watchChapters(course.id).first;
      if (!mounted) {
        return;
      }
      if (chapters.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noTopicsToStart)));
        return;
      }
      final topicLists = await Future.wait([
        for (final chapter in chapters)
          scope.courseStore.watchTopics(course.id, chapter.id).first,
      ]);
      final topicsByChapter = <String, List<TopicModel>>{
        for (var i = 0; i < chapters.length; i++) chapters[i].id: topicLists[i],
      };
      final availableChapters = chapters
          .where((chapter) => topicsByChapter[chapter.id]!.isNotEmpty)
          .toList();
      if (!mounted) {
        return;
      }
      if (availableChapters.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noTopicsToStart)));
        return;
      }
      final selection = await showDialog<_LectureSelection>(
        context: context,
        builder: (_) => _StartLectureDialog(
          chapters: availableChapters,
          topicsByChapter: topicsByChapter,
        ),
      );
      if (!mounted || selection == null) {
        return;
      }
      final session = await scope.courseStore.startLiveSession(
        LiveSessionModel(
          id: '',
          courseId: course.id,
          chapterId: selection.chapter.id,
          chapterTitle: selection.chapter.title,
          topicId: selection.topic.id,
          topicTitle: selection.topic.title,
          teacherId: teacherId,
          durationMinutes: selection.durationMinutes,
        ),
        courseName: course.name,
        teacherName: scope.sessionController.user?.fullName ?? '',
        taughtNotes: '',
      );
      if (mounted) {
        _openLiveSession(session);
      }
    } on TeacherAlreadyLiveException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.teacherAlreadyLive)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.liveSessionStartFailed)));
      }
    }
  }

  Future<void> _delete() async {
    final course = _latest();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteCourse),
          content: Text(l10n.deleteCourseConfirm(course.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.coral),
              child: Text(l10n.deleteCourse),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await AppScope.of(context).courseStore.removeCourse(course.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.courseDeleteFailed)));
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = AppScope.of(context).courseStore;
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final desktop = AppResponsive.isDesktop(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final course = _latest();
        return _buildPage(
          context,
          l10n: l10n,
          course: course,
          brightness: brightness,
          padding: padding,
          desktop: desktop,
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required AppLocalizations l10n,
    required CourseModel course,
    required Brightness brightness,
    required double padding,
    required bool desktop,
  }) {
    final store = AppScope.of(context).courseStore;
    final showFull = !_studentPreview;
    final beforeDays = <_InfoRowData>[
      _InfoRowData(Icons.qr_code_2_rounded, l10n.courseCode, course.code),
      _InfoRowData(Icons.menu_book_outlined, l10n.courseName, course.name),
      if (course.department.trim().isNotEmpty)
        _InfoRowData(
          Icons.apartment_outlined,
          l10n.department,
          course.department,
        ),
      _InfoRowData(
        Icons.calendar_view_month_outlined,
        l10n.semester,
        course.semester,
      ),
      _InfoRowData(
        Icons.hourglass_empty_rounded,
        l10n.creditHours,
        l10n.creditHoursValue(course.creditHours),
      ),
      if (course.teacherName.trim().isNotEmpty)
        _InfoRowData(
          Icons.person_outline_rounded,
          l10n.teacher,
          course.teacherName,
        ),
      if (showFull) ...[
        if (course.teacherEmail.trim().isNotEmpty)
          _InfoRowData(
            Icons.mail_outline_rounded,
            l10n.emailAddress,
            course.teacherEmail,
            compact: true,
          ),
        _InfoRowData(
          Icons.meeting_room_outlined,
          l10n.lectureHall,
          course.lectureHall,
        ),
        _InfoRowData(Icons.group_outlined, l10n.section, course.section),
      ],
    ];
    final afterDays = <_InfoRowData>[
      if (showFull) ...[
        _InfoRowData(
          Icons.schedule_outlined,
          l10n.lectureTime,
          course.lectureTime,
        ),
        _InfoRowData(
          Icons.event_outlined,
          l10n.registrationDate,
          _date(context, course),
        ),
        _InfoRowData(
          Icons.notes_outlined,
          l10n.courseOutlines,
          course.outlines,
          wrap: true,
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          l10n.courseDetails,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (widget.canDelete)
            PopupMenuButton<_CourseMenu>(
              tooltip: l10n.openMenu,
              enabled: !_uploading && !_deleting,
              onSelected: _onMenu,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CourseMenu.uploadSyllabus,
                  child: Text(l10n.uploadSyllabus),
                ),
                PopupMenuItem(
                  value: _CourseMenu.edit,
                  child: Text(l10n.editCourseDetails),
                ),
                PopupMenuItem(
                  value: _CourseMenu.delete,
                  child: Text(l10n.deleteCourse),
                ),
              ],
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 1120 : 560),
          child: ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              StreamBuilder<LiveSessionModel?>(
                stream: store.watchActiveSession(course.id),
                builder: (context, snapshot) {
                  final session = snapshot.data;
                  final isLive = session != null;
                  String? actionLabel;
                  VoidCallback? onAction;
                  if (isLive && (widget.canDelete || widget.isMember)) {
                    actionLabel = l10n.liveLecture;
                    onAction = () => _joinLiveWithConfirm(session);
                  } else if (widget.canDelete) {
                    actionLabel = l10n.startLecture;
                    onAction = _startLecture;
                  }
                  return _CourseHeaderCard(
                    course: course,
                    isLive: isLive,
                    actionLabel: actionLabel,
                    onAction: onAction,
                  );
                },
              ),
              const SizedBox(height: 20),
              ResponsiveCardList(
                children: [for (final row in beforeDays) _InfoRow(data: row)],
              ),
              const SizedBox(height: 8),
              LectureDaysDisplay(course: course),
              const SizedBox(height: 8),
              for (final row in afterDays) _InfoRow(data: row),
              if (_studentPreview) ...[
                const SizedBox(height: 24),
                StreamBuilder<CourseJoinRequest?>(
                  stream: AppScope.of(context).enrollment.watchMyRequest(
                    course.id,
                    AppScope.of(context).sessionController.user?.id ?? '',
                  ),
                  builder: (context, snapshot) {
                    final req = snapshot.data;
                    final pending = req?.isPending ?? false;
                    final accepted = req?.isAccepted ?? false;
                    if (accepted || widget.isMember) {
                      return const SizedBox.shrink();
                    }
                    if (pending) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          l10n.requestSentTag,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      );
                    }
                    return FilledButton(
                      onPressed: _joining ? null : _requestJoin,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.joinCourse,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    );
                  },
                ),
              ],
              if (_uploading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (!_studentPreview && course.syllabusFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 20,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.syllabusFiles,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final file in course.syllabusFiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CourseLinkChip(label: file.name, url: file.url),
                  ),
              ],
              if (!_studentPreview) ...[
                const SizedBox(height: 14),
                _CourseContentLink(
                  title: l10n.chaptersAndTopics,
                  subtitle: widget.canDelete
                      ? l10n.manageCourseContent
                      : l10n.viewCourseContent,
                  icon: Icons.account_tree_outlined,
                  onTap: _openCourseContent,
                ),
              ],
              if (widget.canDelete) ...[
                const SizedBox(height: 12),
                _CourseContentLink(
                  title: l10n.lectureAnalytics,
                  subtitle: l10n.lectureAnalyticsHint,
                  icon: Icons.analytics_outlined,
                  onTap: _openLectureAnalytics,
                ),
                const SizedBox(height: 12),
                _CourseContentLink(
                  title: l10n.enrolledStudents,
                  subtitle: l10n.enrolledStudentsHint,
                  icon: Icons.groups_outlined,
                  onTap: _openEnrolledStudents,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _CourseMenu { uploadSyllabus, edit, delete }

String _fileError(AppLocalizations l10n, String code) {
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

typedef _LectureSelection = ({
  ChapterModel chapter,
  TopicModel topic,
  int durationMinutes,
});

class _StartLectureDialog extends StatefulWidget {
  const _StartLectureDialog({
    required this.chapters,
    required this.topicsByChapter,
  });

  final List<ChapterModel> chapters;
  final Map<String, List<TopicModel>> topicsByChapter;

  @override
  State<_StartLectureDialog> createState() => _StartLectureDialogState();
}

class _StartLectureDialogState extends State<_StartLectureDialog> {
  static const _durations = [15, 30, 45, 60, 90, 120];

  ChapterModel? _chapter;
  TopicModel? _topic;
  var _duration = 45;

  List<TopicModel> get _topicsForChapter {
    final chapter = _chapter;
    if (chapter == null) {
      return const [];
    }
    return widget.topicsByChapter[chapter.id] ?? const <TopicModel>[];
  }

  @override
  void initState() {
    super.initState();
    if (widget.chapters.isNotEmpty) {
      _chapter = widget.chapters.first;
      final topics = _topicsForChapter;
      if (topics.isNotEmpty) {
        _topic = topics.first;
      }
    }
  }

  void _onChapterChanged(String? chapterId) {
    if (chapterId == null) {
      return;
    }
    ChapterModel? next;
    for (final chapter in widget.chapters) {
      if (chapter.id == chapterId) {
        next = chapter;
        break;
      }
    }
    if (next == null) {
      return;
    }
    final topics = widget.topicsByChapter[next.id] ?? const <TopicModel>[];
    setState(() {
      _chapter = next;
      _topic = topics.isEmpty ? null : topics.first;
    });
  }

  void _onTopicChanged(String? topicId) {
    if (topicId == null) {
      return;
    }
    for (final topic in _topicsForChapter) {
      if (topic.id == topicId) {
        setState(() => _topic = topic);
        return;
      }
    }
  }

  void _submit() {
    final chapter = _chapter;
    final topic = _topic;
    if (chapter == null || topic == null) {
      return;
    }
    Navigator.of(
      context,
    ).pop((chapter: chapter, topic: topic, durationMinutes: _duration));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chapter = _chapter;
    final topic = _topic;
    final topics = _topicsForChapter;
    final canStart = chapter != null && topic != null;
    return AlertDialog(
      title: Text(l10n.startLecture),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('chapter-${chapter?.id ?? 'none'}'),
                isExpanded: true,
                initialValue: chapter?.id,
                decoration: InputDecoration(
                  labelText: l10n.selectChapter,
                  prefixIcon: const Icon(Icons.menu_book_outlined),
                ),
                items: [
                  for (final item in widget.chapters)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        item.title.trim().isEmpty
                            ? l10n.chapterTitle
                            : item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _onChapterChanged,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'topic-${chapter?.id ?? 'none'}-${topic?.id ?? 'none'}',
                ),
                isExpanded: true,
                initialValue: topic?.id,
                decoration: InputDecoration(
                  labelText: l10n.selectTopic,
                  prefixIcon: const Icon(Icons.topic_outlined),
                ),
                items: [
                  for (final item in topics)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: topics.isEmpty ? null : _onTopicChanged,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                key: ValueKey(_duration),
                isExpanded: true,
                initialValue: _duration,
                decoration: InputDecoration(
                  labelText: l10n.lectureDuration,
                  prefixIcon: const Icon(Icons.timer_outlined),
                ),
                items: [
                  for (final duration in _durations)
                    DropdownMenuItem(
                      value: duration,
                      child: Text(l10n.durationMinutes(duration)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _duration = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: canStart ? _submit : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l10n.startLecture),
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
        ),
      ],
    );
  }
}

class _CourseContentLink extends StatelessWidget {
  const _CourseContentLink({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.account_tree_outlined,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;

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
          padding: const EdgeInsets.all(15),
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
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary(brightness),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary(brightness),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseHeaderCard extends StatelessWidget {
  const _CourseHeaderCard({
    required this.course,
    this.isLive = false,
    this.actionLabel,
    this.onAction,
  });

  final CourseModel course;
  final bool isLive;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (isLive ? AppColors.coral : AppColors.teal).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isLive ? Icons.podcasts_rounded : Icons.menu_book_rounded,
              color: isLive ? AppColors.coral : AppColors.teal,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (isLive ? AppColors.coral : AppColors.teal)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (isLive ? AppColors.coral : AppColors.teal)
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        actionLabel!,
                        style: TextStyle(
                          color: isLive ? AppColors.coral : AppColors.teal,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.coral.withValues(alpha: 0.9),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (brightness == Brightness.light)
            BoxShadow(
              color: const Color(0xFF0B2545).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRowData {
  const _InfoRowData(
    this.icon,
    this.label,
    this.value, {
    this.compact = false,
    this.wrap = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;
  final bool wrap;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final value = data.value.trim().isEmpty ? 'â€”' : data.value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: AppColors.teal),
          const SizedBox(width: 10),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Text(
                value,
                maxLines: data.wrap ? 6 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: data.compact ? 11 : 14,
                  height: data.wrap ? 1.35 : 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
