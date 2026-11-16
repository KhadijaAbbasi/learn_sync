import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/session/course_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/validators.dart';
import '../../models/course_model.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/lecture_schedule_section.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key, this.existing});

  final CourseModel? existing;

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _department = TextEditingController();
  final _credits = TextEditingController(text: '3');
  final _hall = TextEditingController();
  final _time = TextEditingController();
  final _outlines = TextEditingController();
  final _semester = TextEditingController();
  final _section = TextEditingController();
  final _date = TextEditingController();

  final _days = <int>{};
  DateTime? _regDate;
  bool _saving = false;
  String? _daysError;
  String? _codeError;
  var _didFormatDate = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    _name.text = existing.name;
    _code.text = existing.code;
    _department.text = existing.department;
    _credits.text = '${existing.creditHours}';
    _hall.text = existing.lectureHall;
    _time.text = existing.lectureTime;
    _outlines.text = existing.outlines;
    _semester.text = existing.semester;
    _section.text = existing.section;
    _days.addAll(existing.lectureDays);
    if (_days.isEmpty) {
      _days.addAll({
        for (final slot in existing.resolvedLectureSlots) slot.day,
      });
    }
    _regDate = existing.registrationDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didFormatDate || _regDate == null) {
      return;
    }
    _didFormatDate = true;
    _date.text = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(_regDate!);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _department.dispose();
    _credits.dispose();
    _hall.dispose();
    _time.dispose();
    _outlines.dispose();
    _semester.dispose();
    _section.dispose();
    _date.dispose();
    super.dispose();
  }

  static const _semesterOptions = ['Fall', 'Spring', 'Summer'];

  String _formatLectureTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay? _parseLectureTime(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _regDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() {
        _regDate = picked;
        _date.text = DateFormat.yMMMd(
          Localizations.localeOf(context).toString(),
        ).format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final initial =
        _parseLectureTime(_time.text) ?? const TimeOfDay(hour: 10, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _time.text = _formatLectureTime(picked);
      });
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final formOk = _formKey.currentState?.validate() ?? false;
    final daysOk = _days.isNotEmpty;
    setState(() {
      _daysError = daysOk ? null : l10n.selectLectureDay;
      _codeError = null;
    });
    if (!formOk || !daysOk) {
      return;
    }

    setState(() => _saving = true);
    final teacher = AppScope.of(context).sessionController.user;
    if (teacher == null) {
      setState(() => _saving = false);
      return;
    }
    final existing = widget.existing;
    final course = CourseModel(
      id: existing?.id ?? '',
      teacherId: existing?.teacherId.isNotEmpty == true
          ? existing!.teacherId
          : teacher.id,
      teacherEmail: existing?.teacherEmail.isNotEmpty == true
          ? existing!.teacherEmail
          : teacher.email,
      teacherName: existing?.teacherName.isNotEmpty == true
          ? existing!.teacherName
          : teacher.fullName,
      name: _name.text.trim(),
      code: CourseStore.normalizeCourseCode(_code.text),
      department: _department.text.trim(),
      creditHours: int.parse(_credits.text.trim()),
      lectureHall: _hall.text.trim(),
      lectureDays: _days.toList()..sort(),
      lectureTime: _time.text.trim(),
      lectureSlots: [
        for (final day in (_days.toList()..sort()))
          CourseLectureSlot(day: day, from: _time.text.trim(), to: ''),
      ],
      registrationDate: _regDate,
      outlines: _outlines.text.trim(),
      semester: _semester.text.trim(),
      section: _section.text.trim(),
      topicCount: existing?.topicCount ?? 0,
      isLive: existing?.isLive ?? false,
      announcements: existing?.announcements ?? const [],
      syllabus: existing?.syllabus ?? const [],
      lectures: existing?.lectures ?? const [],
      assignments: existing?.assignments ?? const [],
      resources: existing?.resources ?? const [],
      syllabusFiles: existing?.syllabusFiles ?? const [],
    );
    try {
      final store = AppScope.of(context).courseStore;
      if (_isEditing) {
        await store.updateCourse(course);
      } else {
        await store.addCourse(course);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? l10n.courseUpdated : l10n.courseAdded),
        ),
      );
      Navigator.of(context).pop(_isEditing ? course : null);
    } on DuplicateCourseCodeException {
      if (!mounted) {
        return;
      }
      setState(() => _codeError = l10n.courseCodeTaken);
      _formKey.currentState?.validate();
      _showDuplicateCourseIdDialog();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.courseSaveFailed)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showDuplicateCourseIdDialog() {
    final l10n = AppLocalizations.of(context);
    var closed = false;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          content: const Text(
            "This course can't be saved because course id already exists.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                closed = true;
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    ).whenComplete(() => closed = true);

    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!closed && mounted) {
        Navigator.of(context).pop();
      }
    });
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
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          _isEditing ? l10n.editCourseTitle : l10n.addCourseTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 880 : 560),
          child: Form(
            key: _formKey,
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: Theme.of(context).inputDecorationTheme
                    .copyWith(
                      prefixIconColor: AppColors.teal,
                      suffixIconColor: AppColors.teal,
                    ),
                iconTheme: const IconThemeData(color: AppColors.teal),
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 28),
                children: [
                  Text(
                    _isEditing ? l10n.editCourseTitle : l10n.addCourseTitle,
                    style: AppTextStyles.pageTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isEditing
                        ? l10n.editCourseSubtitle
                        : l10n.addCourseSubtitle,
                    style: AppTextStyles.subtitle(context),
                  ),
                  const SizedBox(height: 18),
                  _FormCard(
                    title: l10n.sectionBasic,
                    child: Column(
                      children: [
                        _TwoFields(
                          first: CustomTextField(
                            controller: _name,
                            hintText: l10n.courseName,
                            prefixIcon: Icons.menu_book_outlined,
                            capitalizeWords: true,
                            validator: (v) => Validators.requiredField(v, l10n),
                          ),
                          second: CustomTextField(
                            controller: _code,
                            hintText: l10n.courseCode,
                            prefixIcon: Icons.tag_rounded,
                            readOnly: _isEditing,
                            enabled: !_isEditing,
                            validator: (v) {
                              final requiredError = Validators.requiredField(
                                v,
                                l10n,
                              );
                              if (requiredError != null) {
                                return requiredError;
                              }
                              return _codeError;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _TwoFields(
                          first: CustomTextField(
                            controller: _department,
                            hintText: l10n.department,
                            prefixIcon: Icons.apartment_outlined,
                            capitalizeWords: true,
                            validator: (v) => Validators.requiredField(v, l10n),
                          ),
                          second: CustomTextField(
                            controller: _credits,
                            hintText: l10n.creditHours,
                            prefixIcon: Icons.hourglass_empty_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              TextInputFormatter.withFunction(
                                (oldValue, newValue) =>
                                    RegExp(r'^[1-5]?$').hasMatch(newValue.text)
                                    ? newValue
                                    : oldValue,
                              ),
                            ],
                            validator: (v) => Validators.creditHours(v, l10n),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormCard(
                    title: l10n.sectionSchedule,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TwoFields(
                          first: CustomTextField(
                            controller: _hall,
                            hintText: l10n.lectureHall,
                            prefixIcon: Icons.meeting_room_outlined,
                            validator: (v) => Validators.requiredField(v, l10n),
                          ),
                          second: CustomTextField(
                            controller: _time,
                            hintText: l10n.lectureTime,
                            prefixIcon: Icons.schedule_outlined,
                            readOnly: true,
                            onTap: _pickTime,
                            suffix: const Icon(Icons.access_time_rounded),
                            validator: (v) => Validators.requiredField(v, l10n),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _date,
                          hintText: l10n.registrationDate,
                          prefixIcon: Icons.event_outlined,
                          readOnly: true,
                          onTap: _pickDate,
                          suffix: const Icon(Icons.keyboard_arrow_down_rounded),
                          validator: (_) =>
                              _regDate == null ? l10n.requiredField : null,
                        ),
                        const SizedBox(height: 14),
                        LectureDaysEditor(
                          selectedDays: _days,
                          errorText: _daysError,
                          onChanged: (days) {
                            setState(() {
                              _days
                                ..clear()
                                ..addAll(days);
                              _daysError = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormCard(
                    title: l10n.sectionAcademic,
                    child: Column(
                      children: [
                        _TwoFields(
                          first: DropdownButtonFormField<String>(
                            initialValue:
                                _semesterOptions.contains(_semester.text)
                                ? _semester.text
                                : null,
                            decoration: InputDecoration(
                              hintText: l10n.semester,
                              prefixIcon: const Icon(
                                Icons.calendar_view_month_outlined,
                              ),
                            ),
                            items: [
                              for (final option in _semesterOptions)
                                DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _semester.text = value);
                            },
                            validator: (value) => Validators.requiredField(
                              value ?? _semester.text,
                              l10n,
                            ),
                          ),
                          second: CustomTextField(
                            controller: _section,
                            hintText: l10n.section,
                            prefixIcon: Icons.group_outlined,
                            validator: (v) => Validators.requiredField(v, l10n),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _outlines,
                          hintText: l10n.courseOutlines,
                          prefixIcon: Icons.notes_outlined,
                          maxLines: 5,
                          minLines: 4,
                          validator: (v) => Validators.requiredField(v, l10n),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: _isEditing
                        ? l10n.saveCourseChanges
                        : l10n.saveCourse,
                    variant: AppButtonVariant.signup,
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(brightness)),
        boxShadow: [
          if (brightness == Brightness.light)
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle(context)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TwoFields extends StatelessWidget {
  const _TwoFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final wide =
        AppResponsive.isDesktop(context) || AppResponsive.isTablet(context);
    if (!wide) {
      return Column(children: [first, const SizedBox(height: 12), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}
