import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/course_content.dart';
import '../../services/course_file_upload.dart';
import '../../widgets/course_link_chip.dart';
import '../../widgets/custom_text_field.dart';

Future<SyllabusWeek?> showAddWeekDialog(
  BuildContext context, {
  required int nextWeek,
  SyllabusWeek? existing,
  bool readOnly = false,
}) {
  return showDialog<SyllabusWeek>(
    context: context,
    builder: (_) => _AddWeekDialog(
      nextWeek: nextWeek,
      existing: existing,
      readOnly: readOnly,
    ),
  );
}

Future<CourseLecture?> showAddLectureDialog(
  BuildContext context, {
  required String courseId,
  CourseLecture? existing,
  bool readOnly = false,
}) {
  return showDialog<CourseLecture>(
    context: context,
    builder: (_) => _AddLectureDialog(
      courseId: courseId,
      existing: existing,
      readOnly: readOnly,
    ),
  );
}

Future<CourseAssignment?> showAddAssignmentDialog(
  BuildContext context, {
  required String courseId,
  CourseAssignment? existing,
  bool readOnly = false,
}) {
  return showDialog<CourseAssignment>(
    context: context,
    builder: (_) => _AddAssignmentDialog(
      courseId: courseId,
      existing: existing,
      readOnly: readOnly,
    ),
  );
}

Future<CourseResource?> showAddResourceDialog(
  BuildContext context, {
  required String courseId,
  CourseResource? existing,
  bool readOnly = false,
}) {
  return showDialog<CourseResource>(
    context: context,
    builder: (_) => _AddResourceDialog(
      courseId: courseId,
      existing: existing,
      readOnly: readOnly,
    ),
  );
}

List<Widget> _dialogActions<T>(
  BuildContext context, {
  required GlobalKey<FormState> formKey,
  required T Function() value,
  required bool readOnly,
  bool busy = false,
}) {
  final l10n = AppLocalizations.of(context);
  if (readOnly) {
    return [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
        child: Text(l10n.ok),
      ),
    ];
  }
  return [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(l10n.cancel),
    ),
    FilledButton(
      onPressed: busy
          ? null
          : () {
        if (!(formKey.currentState?.validate() ?? false)) {
          return;
        }
        Navigator.of(context).pop(value());
      },
      style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
      child: Text(l10n.saveCourseChanges),
    ),
  ];
}

class _AddWeekDialog extends StatefulWidget {
  const _AddWeekDialog({
    required this.nextWeek,
    this.existing,
    this.readOnly = false,
  });

  final int nextWeek;
  final SyllabusWeek? existing;
  final bool readOnly;

  @override
  State<_AddWeekDialog> createState() => _AddWeekDialogState();
}

class _AddWeekDialogState extends State<_AddWeekDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _readings = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _readings.text = existing.readings;
      _notes.text = existing.notes;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _readings.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locked = widget.readOnly;
    final existing = widget.existing;
    return AlertDialog(
      title: Text(
        locked
            ? l10n.viewWeek
            : existing != null
            ? l10n.editWeek
            : l10n.addWeek,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _title,
                hintText: l10n.weekTitle,
                enabled: !locked,
                readOnly: locked,
                validator: locked
                    ? null
                    : (v) => Validators.requiredField(v, l10n),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _readings,
                hintText: l10n.weekReadings,
                enabled: !locked,
                readOnly: locked,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _notes,
                hintText: l10n.weekNotes,
                maxLines: 3,
                minLines: 2,
                enabled: !locked,
                readOnly: locked,
              ),
            ],
          ),
        ),
      ),
      actions: _dialogActions(
        context,
        formKey: _formKey,
        readOnly: locked,
        value: () => SyllabusWeek(
          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          weekNumber: existing?.weekNumber ?? widget.nextWeek,
          title: _title.text.trim(),
          readings: _readings.text.trim(),
          notes: _notes.text.trim(),
        ),
      ),
    );
  }
}

class _AddLectureDialog extends StatefulWidget {
  const _AddLectureDialog({
    required this.courseId,
    this.existing,
    this.readOnly = false,
  });

  final String courseId;
  final CourseLecture? existing;
  final bool readOnly;

  @override
  State<_AddLectureDialog> createState() => _AddLectureDialogState();
}

class _AddLectureDialogState extends State<_AddLectureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _date = TextEditingController();
  DateTime _picked = DateTime.now();
  final _files = <UploadedCourseFile>[];
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _description.text = existing.description;
      _picked = existing.date ?? DateTime.now();
      _files.addAll(_uploadedFrom(existing.attachments));
    }
    _date.text = DateFormat.yMMMd().format(_picked);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _picked,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (!mounted || next == null) {
      return;
    }
    setState(() {
      _picked = next;
      _date.text = DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).format(next);
    });
  }

  Future<void> _pickFile() async {
    if (widget.readOnly || _uploading) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await CourseFileUpload.pickFiles(
        extensions: CourseFileUpload.lectureExtensions,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      setState(() => _uploading = true);
      final uploaded = await CourseFileUpload.uploadFiles(
        courseId: widget.courseId,
        folder: 'lectures',
        files: picked,
      );
      if (!mounted || uploaded.isEmpty) {
        return;
      }
      setState(() => _files.addAll(uploaded));
    } on CourseFileException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileError(l10n, error.code))),
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      CourseLecture(
        id: widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        date: _picked,
        description: _description.text.trim(),
        attachments: _attachmentsFrom(_files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locked = widget.readOnly;
    return AlertDialog(
      title: Text(
        locked
            ? l10n.viewLecture
            : widget.existing != null
            ? l10n.editLecture
            : l10n.addLecture,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _title,
                hintText: l10n.lectureTitle,
                enabled: !locked,
                readOnly: locked,
                validator: locked
                    ? null
                    : (v) => Validators.requiredField(v, l10n),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _date,
                hintText: l10n.lectureDate,
                readOnly: true,
                enabled: !locked,
                onTap: locked ? null : _pickDate,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _description,
                hintText: l10n.lectureDescription,
                maxLines: 3,
                minLines: 2,
                enabled: !locked,
                readOnly: locked,
              ),
              const SizedBox(height: 12),
              _FileListEditor(
                hint: l10n.lectureFileHint,
                files: _files,
                locked: locked,
                uploading: _uploading,
                onAdd: _pickFile,
                onRemove: (index) => setState(() => _files.removeAt(index)),
              ),
            ],
          ),
        ),
      ),
      actions: locked
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                child: Text(l10n.ok),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: _uploading ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                child: Text(l10n.saveCourseChanges),
              ),
            ],
    );
  }
}

class _AddAssignmentDialog extends StatefulWidget {
  const _AddAssignmentDialog({
    required this.courseId,
    this.existing,
    this.readOnly = false,
  });

  final String courseId;
  final CourseAssignment? existing;
  final bool readOnly;

  @override
  State<_AddAssignmentDialog> createState() => _AddAssignmentDialogState();
}

class _AddAssignmentDialogState extends State<_AddAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _points = TextEditingController(text: '50');
  final _description = TextEditingController();
  final _due = TextEditingController();
  DateTime _picked = DateTime.now().add(const Duration(days: 7));
  var _published = true;
  final _files = <UploadedCourseFile>[];
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _points.text = existing.points.toString();
      _description.text = existing.description;
      _picked = existing.dueDate ?? _picked;
      _published = existing.published;
      _files.addAll(_uploadedFrom(existing.attachments));
    }
    _due.text = DateFormat.yMMMd().format(_picked);
  }

  @override
  void dispose() {
    _title.dispose();
    _points.dispose();
    _description.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final next = await showDatePicker(
      context: context,
      initialDate: _picked,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (!mounted || next == null) {
      return;
    }
    setState(() {
      _picked = next;
      _due.text = DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).format(next);
    });
  }

  Future<void> _pickFile() async {
    if (widget.readOnly || _uploading) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await CourseFileUpload.pickFiles(
        extensions: CourseFileUpload.documentExtensions,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      setState(() => _uploading = true);
      final uploaded = await CourseFileUpload.uploadFiles(
        courseId: widget.courseId,
        folder: 'assignments',
        files: picked,
      );
      if (!mounted || uploaded.isEmpty) {
        return;
      }
      setState(() => _files.addAll(uploaded));
    } on CourseFileException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileError(l10n, error.code))),
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
    final locked = widget.readOnly;
    return AlertDialog(
      title: Text(
        locked
            ? l10n.viewAssignment
            : widget.existing != null
            ? l10n.editAssignment
            : l10n.addAssignment,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _title,
                hintText: l10n.assignmentTitle,
                enabled: !locked,
                readOnly: locked,
                validator: locked
                    ? null
                    : (v) => Validators.requiredField(v, l10n),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _due,
                hintText: l10n.assignmentDue,
                readOnly: true,
                enabled: !locked,
                onTap: locked ? null : _pickDate,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _points,
                hintText: l10n.assignmentPoints,
                keyboardType: TextInputType.number,
                enabled: !locked,
                readOnly: locked,
                validator: locked
                    ? null
                    : (v) => Validators.requiredField(v, l10n),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _description,
                hintText: l10n.assignmentDescription,
                maxLines: 3,
                minLines: 2,
                enabled: !locked,
                readOnly: locked,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.published),
                value: _published,
                onChanged: locked
                    ? null
                    : (value) => setState(() => _published = value),
              ),
              _FileListEditor(
                hint: l10n.assignmentFileHint,
                files: _files,
                locked: locked,
                uploading: _uploading,
                onAdd: _pickFile,
                onRemove: (index) => setState(() => _files.removeAt(index)),
              ),
            ],
          ),
        ),
      ),
      actions: _dialogActions(
        context,
        formKey: _formKey,
        readOnly: locked,
        busy: _uploading,
        value: () => CourseAssignment(
          id: widget.existing?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          dueDate: _picked,
          points: int.tryParse(_points.text.trim()) ?? 0,
          description: _description.text.trim(),
          published: _published,
          attachments: _attachmentsFrom(_files),
        ),
      ),
    );
  }
}

class _AddResourceDialog extends StatefulWidget {
  const _AddResourceDialog({
    required this.courseId,
    this.existing,
    this.readOnly = false,
  });

  final String courseId;
  final CourseResource? existing;
  final bool readOnly;

  @override
  State<_AddResourceDialog> createState() => _AddResourceDialogState();
}

class _AddResourceDialogState extends State<_AddResourceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _type = TextEditingController();
  final _detail = TextEditingController();
  late final List<TextEditingController> _links;
  final _files = <UploadedCourseFile>[];
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing.title;
      _type.text = existing.type;
      _detail.text = existing.detail;
      _files.addAll(_uploadedFrom(existing.attachments));
      _links = existing.links.isEmpty
          ? [TextEditingController()]
          : existing.links
                .map((link) => TextEditingController(text: link))
                .toList();
    } else {
      _links = [TextEditingController()];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _type.dispose();
    _detail.dispose();
    for (final link in _links) {
      link.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (widget.readOnly || _uploading) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await CourseFileUpload.pickFiles(
        extensions: CourseFileUpload.documentExtensions,
      );
      if (!mounted || picked.isEmpty) {
        return;
      }
      setState(() => _uploading = true);
      final uploaded = await CourseFileUpload.uploadFiles(
        courseId: widget.courseId,
        folder: 'resources',
        files: picked,
      );
      if (!mounted || uploaded.isEmpty) {
        return;
      }
      setState(() => _files.addAll(uploaded));
    } on CourseFileException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileError(l10n, error.code))),
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
    final locked = widget.readOnly;
    return AlertDialog(
      title: Text(
        locked
            ? l10n.viewResource
            : widget.existing != null
            ? l10n.editResource
            : l10n.addResource,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _title,
                hintText: l10n.resourceTitle,
                enabled: !locked,
                readOnly: locked,
                validator: locked
                    ? null
                    : (v) => Validators.requiredField(v, l10n),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _type,
                hintText: l10n.resourceType,
                enabled: !locked,
                readOnly: locked,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _detail,
                hintText: l10n.resourceDetail,
                enabled: !locked,
                readOnly: locked,
              ),
              const SizedBox(height: 12),
              _FileListEditor(
                hint: l10n.resourceFileHint,
                files: _files,
                locked: locked,
                uploading: _uploading,
                onAdd: _pickFile,
                onRemove: (index) => setState(() => _files.removeAt(index)),
              ),
              const SizedBox(height: 12),
              if (locked)
                for (final link in _links)
                  if (link.text.trim().isNotEmpty) ...[
                    CourseLinkChip(
                      label: link.text.trim(),
                      url: _normalizeLink(link.text),
                      icon: Icons.link_rounded,
                    ),
                    const SizedBox(height: 8),
                  ]
              else
                for (var i = 0; i < _links.length; i++) ...[
                  CustomTextField(
                    controller: _links[i],
                    hintText: l10n.resourceLink,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                ],
              if (!locked)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _links.add(TextEditingController()));
                    },
                    icon: const Icon(Icons.add_link_rounded),
                    label: Text(l10n.addLink),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: _dialogActions(
        context,
        formKey: _formKey,
        readOnly: locked,
        busy: _uploading,
        value: () => CourseResource(
          id: widget.existing?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          type: _type.text.trim().isNotEmpty
              ? _type.text.trim()
              : (_files.isNotEmpty ? 'Document' : 'Link'),
          detail: _detail.text.trim(),
          attachments: _attachmentsFrom(_files),
          links: _links
              .map((controller) => _normalizeLink(controller.text))
              .where((link) => link.isNotEmpty)
              .toList(),
        ),
      ),
    );
  }
}

class _FileListEditor extends StatelessWidget {
  const _FileListEditor({
    required this.hint,
    required this.files,
    required this.locked,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final String hint;
  final List<UploadedCourseFile> files;
  final bool locked;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < files.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: CourseLinkChip(label: files[i].name, url: files[i].url),
              ),
              if (!locked)
                IconButton(
                  tooltip: l10n.removeFile,
                  onPressed: uploading ? null : () => onRemove(i),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!locked)
          OutlinedButton.icon(
            onPressed: uploading ? null : onAdd,
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: Text(uploading ? l10n.uploadingFiles : hint),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: AppColors.border(brightness)),
            ),
          ),
      ],
    );
  }
}

List<UploadedCourseFile> _uploadedFrom(List<CourseAttachment> attachments) {
  return [
    for (final item in attachments)
      UploadedCourseFile(name: item.name, url: item.url),
  ];
}

List<CourseAttachment> _attachmentsFrom(List<UploadedCourseFile> files) {
  return [
    for (final file in files)
      CourseAttachment(name: file.name, url: file.url),
  ];
}

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

String _normalizeLink(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return 'https://$value';
}

