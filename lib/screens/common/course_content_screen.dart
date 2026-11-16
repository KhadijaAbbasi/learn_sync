import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/constants/app_routes.dart';
import '../../core/session/course_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/chapter_model.dart';
import '../../models/course_content.dart';
import '../../services/course_file_upload.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/course_link_chip.dart';

class CourseContentScreen extends StatefulWidget {
  const CourseContentScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.canManage,
  });

  final String courseId;
  final String courseName;
  final bool canManage;

  @override
  State<CourseContentScreen> createState() => _CourseContentScreenState();
}

class _CourseContentScreenState extends State<CourseContentScreen> {
  var _busy = false;

  CourseStore get _store => AppScope.of(context).courseStore;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.contentSaveFailed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addOrEditChapter([ChapterModel? existing]) async {
    final l10n = AppLocalizations.of(context);
    final chapterId =
        existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final value = await _showContentDialog(
      context,
      title: existing == null ? l10n.addChapter : l10n.editChapter,
      titleHint: l10n.chapterTitle,
      descriptionHint: l10n.chapterDescription,
      initialTitle: existing?.title ?? '',
      initialDescription: existing?.description ?? '',
      courseId: widget.courseId,
      uploadFolder: 'chapters/$chapterId',
      initialAttachments: existing?.attachments ?? const [],
    );
    if (!mounted || value == null) {
      return;
    }
    await _run(() async {
      if (existing == null) {
        await _store.addChapter(
          widget.courseId,
          ChapterModel(
            id: chapterId,
            title: value.title,
            description: value.description,
            attachments: value.attachments,
          ),
        );
      } else {
        await _store.updateChapter(
          widget.courseId,
          existing.copyWith(
            title: value.title,
            description: value.description,
            attachments: value.attachments,
          ),
        );
      }
    });
  }

  Future<void> _deleteChapter(ChapterModel chapter) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDelete(
      context,
      title: l10n.deleteChapter,
      message: l10n.deleteChapterConfirm,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _run(() => _store.deleteChapter(widget.courseId, chapter.id));
  }

  Future<void> _moveChapter(
    List<ChapterModel> chapters,
    int index,
    int offset,
  ) async {
    final target = index + offset;
    if (target < 0 || target >= chapters.length) {
      return;
    }
    final reordered = [...chapters];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    await _run(() => _store.reorderChapters(widget.courseId, reordered));
  }

  Future<void> _addOrEditTopic(
    ChapterModel chapter, [
    TopicModel? existing,
  ]) async {
    final l10n = AppLocalizations.of(context);
    final topicId =
        existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final value = await _showContentDialog(
      context,
      title: existing == null ? l10n.addTopic : l10n.editTopic,
      titleHint: l10n.topicTitle,
      descriptionHint: l10n.topicDescription,
      initialTitle: existing?.title ?? '',
      initialDescription: existing?.description ?? '',
      courseId: widget.courseId,
      uploadFolder: 'topics/${chapter.id}/$topicId',
      initialAttachments: existing?.attachments ?? const [],
      requireAttachments: true,
    );
    if (!mounted || value == null) {
      return;
    }
    await _run(() async {
      if (existing == null) {
        await _store.addTopic(
          widget.courseId,
          chapter.id,
          TopicModel(
            id: topicId,
            title: value.title,
            description: value.description,
            attachments: value.attachments,
          ),
        );
      } else {
        await _store.updateTopic(
          widget.courseId,
          chapter.id,
          existing.copyWith(
            title: value.title,
            description: value.description,
            attachments: value.attachments,
          ),
        );
      }
    });
  }

  Future<void> _deleteTopic(ChapterModel chapter, TopicModel topic) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmDelete(
      context,
      title: l10n.deleteTopic,
      message: l10n.deleteTopicConfirm,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _run(() => _store.deleteTopic(widget.courseId, chapter.id, topic.id));
  }

  Future<void> _moveTopic(
    ChapterModel chapter,
    List<TopicModel> topics,
    int index,
    int offset,
  ) async {
    final target = index + offset;
    if (target < 0 || target >= topics.length) {
      return;
    }
    final reordered = [...topics];
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    await _run(
      () => _store.reorderTopics(widget.courseId, chapter.id, reordered),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final desktop = AppResponsive.isDesktop(context);

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          l10n.chaptersAndTopics,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.navDashboard,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              widget.canManage
                  ? AppRoutes.teacherDashboard
                  : AppRoutes.studentDashboard,
              (route) => false,
            ),
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ),
      floatingActionButton: widget.canManage
          ? FloatingActionButton(
              onPressed: _busy ? null : _addOrEditChapter,
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              tooltip: l10n.addChapter,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 760 : 600),
          child: StreamBuilder<List<ChapterModel>>(
            stream: _store.watchChapters(widget.courseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ContentMessage(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.contentSaveFailed,
                );
              }
              final chapters = snapshot.data ?? const [];
              return ListView(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 104),
                children: [
                  _CourseContentHeader(
                    courseName: widget.courseName,
                    subtitle: widget.canManage
                        ? l10n.manageCourseContent
                        : l10n.viewCourseContent,
                  ),
                  const SizedBox(height: 18),
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  if (chapters.isEmpty)
                    _ContentMessage(
                      icon: Icons.auto_stories_outlined,
                      title: l10n.noChapters,
                      subtitle: widget.canManage
                          ? l10n.noChaptersTeacherHint
                          : l10n.noChaptersStudentHint,
                      actionLabel: widget.canManage ? l10n.addChapter : null,
                      onAction: widget.canManage ? _addOrEditChapter : null,
                    )
                  else
                    for (var i = 0; i < chapters.length; i++) ...[
                      _ChapterCard(
                        store: _store,
                        courseId: widget.courseId,
                        chapter: chapters[i],
                        chapterNumber: i + 1,
                        canManage: widget.canManage,
                        canMoveUp: i > 0,
                        canMoveDown: i < chapters.length - 1,
                        onEdit: () => _addOrEditChapter(chapters[i]),
                        onDelete: () => _deleteChapter(chapters[i]),
                        onMoveUp: () => _moveChapter(chapters, i, -1),
                        onMoveDown: () => _moveChapter(chapters, i, 1),
                        onAddTopic: () => _addOrEditTopic(chapters[i]),
                        onEditTopic: (topic) =>
                            _addOrEditTopic(chapters[i], topic),
                        onDeleteTopic: (topic) =>
                            _deleteTopic(chapters[i], topic),
                        onMoveTopic: (topics, index, offset) =>
                            _moveTopic(chapters[i], topics, index, offset),
                      ),
                      if (i < chapters.length - 1) const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CourseContentHeader extends StatelessWidget {
  const _CourseContentHeader({
    required this.courseName,
    required this.subtitle,
  });

  final String courseName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.headerNavy, Color(0xFF176E78)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12.5,
                    height: 1.3,
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

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.store,
    required this.courseId,
    required this.chapter,
    required this.chapterNumber,
    required this.canManage,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onAddTopic,
    required this.onEditTopic,
    required this.onDeleteTopic,
    required this.onMoveTopic,
  });

  final CourseStore store;
  final String courseId;
  final ChapterModel chapter;
  final int chapterNumber;
  final bool canManage;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onAddTopic;
  final ValueChanged<TopicModel> onEditTopic;
  final ValueChanged<TopicModel> onDeleteTopic;
  final void Function(List<TopicModel>, int, int) onMoveTopic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(brightness)),
        boxShadow: [
          if (brightness == Brightness.light)
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$chapterNumber',
              style: const TextStyle(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chapterNumber(chapterNumber),
                style: const TextStyle(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                chapter.title,
                style: TextStyle(
                  color: AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
            ],
          ),
          subtitle: chapter.description.isEmpty
              ? null
              : Text(
                  chapter.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary(brightness),
                    fontSize: 12.5,
                  ),
                ),
          trailing: canManage
              ? PopupMenuButton<_ChapterAction>(
                  tooltip: l10n.openMenu,
                  onSelected: (action) {
                    switch (action) {
                      case _ChapterAction.edit:
                        onEdit();
                      case _ChapterAction.moveUp:
                        onMoveUp();
                      case _ChapterAction.moveDown:
                        onMoveDown();
                      case _ChapterAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    _menuItem(
                      _ChapterAction.edit,
                      Icons.edit_outlined,
                      l10n.editChapter,
                    ),
                    _menuItem(
                      _ChapterAction.moveUp,
                      Icons.arrow_upward_rounded,
                      l10n.moveUp,
                      enabled: canMoveUp,
                    ),
                    _menuItem(
                      _ChapterAction.moveDown,
                      Icons.arrow_downward_rounded,
                      l10n.moveDown,
                      enabled: canMoveDown,
                    ),
                    _menuItem(
                      _ChapterAction.delete,
                      Icons.delete_outline_rounded,
                      l10n.deleteChapter,
                      destructive: true,
                    ),
                  ],
                )
              : const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.teal,
                ),
          children: [
            if (chapter.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    for (var i = 0; i < chapter.attachments.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: CourseLinkChip(
                          label: chapter.attachments[i].name,
                          url: chapter.attachments[i].url,
                          courseId: courseId,
                          siblings: chapter.attachments,
                          siblingIndex: i,
                        ),
                      ),
                  ],
                ),
              ),
            StreamBuilder<List<TopicModel>>(
              stream: store.watchTopics(courseId, chapter.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final topics = snapshot.data ?? const [];
                return Column(
                  children: [
                    if (topics.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          l10n.noTopics,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary(brightness),
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < topics.length; i++)
                        _TopicRow(
                          courseId: courseId,
                          topic: topics[i],
                          number: i + 1,
                          canManage: canManage,
                          canMoveUp: i > 0,
                          canMoveDown: i < topics.length - 1,
                          onEdit: () => onEditTopic(topics[i]),
                          onDelete: () => onDeleteTopic(topics[i]),
                          onMoveUp: () => onMoveTopic(topics, i, -1),
                          onMoveDown: () => onMoveTopic(topics, i, 1),
                        ),
                    if (canManage) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onAddTopic,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          side: BorderSide(
                            color: AppColors.teal.withValues(alpha: 0.55),
                          ),
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.add_rounded, size: 22),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.courseId,
    required this.topic,
    required this.number,
    required this.canManage,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String courseId;
  final TopicModel topic;
  final int number;
  final bool canManage;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkBackground.withValues(alpha: 0.55)
            : AppColors.pageWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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
                  topic.title,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (topic.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    topic.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (topic.attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (var i = 0; i < topic.attachments.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: CourseLinkChip(
                        label: topic.attachments[i].name,
                        url: topic.attachments[i].url,
                        courseId: courseId,
                        siblings: topic.attachments,
                        siblingIndex: i,
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<_TopicAction>(
              tooltip: l10n.openMenu,
              iconSize: 20,
              onSelected: (action) {
                switch (action) {
                  case _TopicAction.edit:
                    onEdit();
                  case _TopicAction.moveUp:
                    onMoveUp();
                  case _TopicAction.moveDown:
                    onMoveDown();
                  case _TopicAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                _menuItem(
                  _TopicAction.edit,
                  Icons.edit_outlined,
                  l10n.editTopic,
                ),
                _menuItem(
                  _TopicAction.moveUp,
                  Icons.arrow_upward_rounded,
                  l10n.moveUp,
                  enabled: canMoveUp,
                ),
                _menuItem(
                  _TopicAction.moveDown,
                  Icons.arrow_downward_rounded,
                  l10n.moveDown,
                  enabled: canMoveDown,
                ),
                _menuItem(
                  _TopicAction.delete,
                  Icons.delete_outline_rounded,
                  l10n.deleteTopic,
                  destructive: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ContentMessage extends StatelessWidget {
  const _ContentMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.teal, size: 27),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary(brightness),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(brightness),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ChapterAction { edit, moveUp, moveDown, delete }

enum _TopicAction { edit, moveUp, moveDown, delete }

PopupMenuItem<T> _menuItem<T>(
  T value,
  IconData icon,
  String label, {
  bool enabled = true,
  bool destructive = false,
}) {
  final color = destructive ? AppColors.error : null;
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );
}

typedef _ContentEditorValue = ({
  String title,
  String description,
  List<CourseAttachment> attachments,
});

Future<_ContentEditorValue?> _showContentDialog(
  BuildContext context, {
  required String title,
  required String titleHint,
  required String descriptionHint,
  required String initialTitle,
  required String initialDescription,
  String? courseId,
  String? uploadFolder,
  List<CourseAttachment> initialAttachments = const [],
  bool requireAttachments = false,
}) {
  return showDialog<_ContentEditorValue>(
    context: context,
    builder: (_) => _ContentEditorDialog(
      title: title,
      titleHint: titleHint,
      descriptionHint: descriptionHint,
      initialTitle: initialTitle,
      initialDescription: initialDescription,
      courseId: courseId,
      uploadFolder: uploadFolder,
      initialAttachments: initialAttachments,
      requireAttachments: requireAttachments,
    ),
  );
}

class _ContentEditorDialog extends StatefulWidget {
  const _ContentEditorDialog({
    required this.title,
    required this.titleHint,
    required this.descriptionHint,
    required this.initialTitle,
    required this.initialDescription,
    required this.courseId,
    required this.uploadFolder,
    required this.initialAttachments,
    this.requireAttachments = false,
  });

  final String title;
  final String titleHint;
  final String descriptionHint;
  final String initialTitle;
  final String initialDescription;
  final String? courseId;
  final String? uploadFolder;
  final List<CourseAttachment> initialAttachments;
  final bool requireAttachments;

  @override
  State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

class _ContentEditorDialogState extends State<_ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _attachments = <CourseAttachment>[];
  var _uploading = false;
  String? _attachmentsError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _attachments.addAll(widget.initialAttachments);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_uploading || _formKey.currentState?.validate() != true) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (widget.requireAttachments && _attachments.isEmpty) {
      setState(() => _attachmentsError = l10n.topicFilesRequired);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.topicFilesRequired)));
      return;
    }
    Navigator.of(context).pop((
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      attachments: List<CourseAttachment>.unmodifiable(_attachments),
    ));
  }

  Future<void> _addFile() async {
    final courseId = widget.courseId;
    final folder = widget.uploadFolder;
    if (_uploading || courseId == null || folder == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await CourseFileUpload.pickFiles(
        extensions: CourseFileUpload.syllabusExtensions,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      setState(() => _uploading = true);
      final files = await CourseFileUpload.uploadFiles(
        courseId: courseId,
        folder: folder,
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.titleHint,
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.requiredField
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 240,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.descriptionHint,
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
                onFieldSubmitted: (_) => _save(),
              ),
              if (widget.courseId != null && widget.uploadFolder != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    widget.requireAttachments
                        ? l10n.topicFilesRequiredHint
                        : l10n.lectureFileHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: _attachmentsError != null
                          ? Theme.of(context).colorScheme.error
                          : AppColors.textSecondary(
                              Theme.of(context).brightness,
                            ),
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
                                      if (widget.requireAttachments &&
                                          _attachments.isEmpty) {
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (widget.courseId != null && widget.uploadFolder != null)
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
          onPressed: _uploading ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(title),
            ),
          ],
        ),
      ) ??
      false;
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
