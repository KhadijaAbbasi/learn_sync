import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/chapter_model.dart';
import '../../models/course_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({
    super.key,
    this.initialCourseId = '',
    this.initialTopicTitle = '',
  });

  final String initialCourseId;
  final String initialTopicTitle;

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _reasonController = TextEditingController();
  final _topicController = TextEditingController();
  CourseModel? _course;
  ChapterModel? _chapter;
  TopicModel? _topic;
  List<ChapterModel> _chapters = const [];
  List<TopicModel> _topics = const [];
  var _loadingContent = false;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTopicTitle.isNotEmpty) {
      _topicController.text = widget.initialTopicTitle;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final courses = AppScope.of(context).courseStore.courses;
    if (courses.isEmpty) {
      return;
    }
    final match = widget.initialCourseId.isEmpty
        ? courses.first
        : courses.where((c) => c.id == widget.initialCourseId).firstOrNull ??
              courses.first;
    await _selectCourse(match);
  }

  Future<void> _selectCourse(CourseModel course) async {
    setState(() {
      _course = course;
      _chapter = null;
      _topic = null;
      _chapters = const [];
      _topics = const [];
      _loadingContent = true;
    });
    final store = AppScope.of(context).courseStore;
    try {
      final chapters = await store.watchChapters(course.id).first;
      if (!mounted) {
        return;
      }
      setState(() {
        _chapters = chapters;
        _loadingContent = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingContent = false);
      }
    }
  }

  Future<void> _selectChapter(ChapterModel chapter) async {
    setState(() {
      _chapter = chapter;
      _topic = null;
      _topics = const [];
      _loadingContent = true;
    });
    final store = AppScope.of(context).courseStore;
    try {
      final topics = await store
          .watchTopics(_course!.id, chapter.id)
          .first;
      if (!mounted) {
        return;
      }
      setState(() {
        _topics = topics;
        _loadingContent = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingContent = false);
      }
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    final course = _course;
    if (user?.role != UserRole.student || course == null) {
      return;
    }
    final teacherId = user!.connectedTeacherId ?? '';
    if (teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.linkTeacherFirstForMeeting)),
      );
      return;
    }
    final topicTitle = (_topic?.title ?? _topicController.text).trim();
    final reason = _reasonController.text.trim();
    if (topicTitle.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.meetingFormIncomplete)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await scope.meetingStore.createRequest(
        studentId: user.id,
        studentName: user.fullName,
        studentEmail: user.email,
        memberId: user.memberId,
        teacherId: teacherId,
        teacherName: user.connectedTeacherName ?? '',
        courseId: course.id,
        courseName: course.name,
        chapterId: _chapter?.id ?? '',
        chapterTitle: _chapter?.title ?? '',
        topicId: _topic?.id ?? '',
        topicTitle: topicTitle,
        reason: reason,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.meetingRequestSent)),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.meetingRequestFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final courses = scope.courseStore.courses;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(l10n.requestMeeting),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
        children: [
          Text(
            l10n.createMeetingIntro,
            style: TextStyle(
              color: AppColors.textSecondary(brightness),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _course?.id,
            decoration: InputDecoration(labelText: l10n.selectCourse),
            items: [
              for (final course in courses)
                DropdownMenuItem(
                  value: course.id,
                  child: Text(
                    course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              final course = courses.where((c) => c.id == id).firstOrNull;
              if (course != null) {
                _selectCourse(course);
              }
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _chapter?.id,
            decoration: InputDecoration(labelText: l10n.selectChapter),
            items: [
              for (final chapter in _chapters)
                DropdownMenuItem(
                  value: chapter.id,
                  child: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _chapters.isEmpty
                ? null
                : (id) {
                    final chapter =
                        _chapters.where((c) => c.id == id).firstOrNull;
                    if (chapter != null) {
                      _selectChapter(chapter);
                    }
                  },
          ),
          const SizedBox(height: 14),
          if (_topics.isNotEmpty)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _topic?.id,
              decoration: InputDecoration(labelText: l10n.selectTopic),
              items: [
                for (final topic in _topics)
                  DropdownMenuItem(
                    value: topic.id,
                    child: Text(
                      topic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                final topic = _topics.where((t) => t.id == id).firstOrNull;
                if (topic == null) {
                  return;
                }
                setState(() {
                  _topic = topic;
                  _topicController.text = topic.title;
                });
              },
            )
          else
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: l10n.meetingTopicLabel,
                hintText: l10n.meetingTopicHint,
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: l10n.meetingReasonLabel,
              hintText: l10n.meetingReasonHint,
              alignLabelWithHint: true,
            ),
          ),
          if (_loadingContent) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.8),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.sendMeetingRequest),
          ),
        ],
      ),
    );
  }
}
