import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/meeting_request.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/meeting_widgets.dart';

class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _noteController = TextEditingController();
  DateTime? _scheduledAt;
  var _busy = false;
  Timer? _clock;
  var _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _accept(MeetingRequest request) async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final teacherId = scope.sessionController.user?.id ?? '';
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chooseMeetingTimeFirst)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await scope.meetingStore.acceptRequest(
        requestId: request.id,
        teacherId: teacherId,
        scheduledAt: _scheduledAt!,
        teacherNote: _noteController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              request.isRescheduleRequested
                  ? l10n.meetingRescheduledToast
                  : l10n.meetingAcceptedToast,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.meetingUpdateFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _decline(MeetingRequest request) async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final teacherId = scope.sessionController.user?.id ?? '';
    setState(() => _busy = true);
    try {
      await scope.meetingStore.declineRequest(
        requestId: request.id,
        teacherId: teacherId,
        teacherNote: _noteController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.meetingDeclinedToast)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.meetingUpdateFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _complete(MeetingRequest request) async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final teacherId = scope.sessionController.user?.id ?? '';
    if (!request.canMarkCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.meetingCompleteAfterSchedule)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await scope.meetingStore.completeRequest(
        requestId: request.id,
        teacherId: teacherId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.meetingCompletedToast)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.meetingUpdateFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _canCompleteNow(MeetingRequest request) {
    final scheduled = request.scheduledAt;
    return request.isAccepted &&
        scheduled != null &&
        !_now.isBefore(scheduled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final locale = Localizations.localeOf(context).toString();

    if (user?.role != UserRole.teacher) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navMeetings)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(l10n.meetingDetails),
      ),
      body: StreamBuilder<MeetingRequest?>(
        stream: scope.meetingStore.watchRequest(widget.requestId),
        builder: (context, snapshot) {
          final request = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              request == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (request == null || request.teacherId != user!.id) {
            return Center(child: Text(l10n.meetingNotFound));
          }

          final canComplete = _canCompleteNow(request);

          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MeetingStatusChip(status: request.status),
              ),
              const SizedBox(height: 16),
              _RowInfo(label: l10n.student, value: request.studentName),
              if (request.studentEmail.isNotEmpty)
                _RowInfo(label: l10n.emailLabel, value: request.studentEmail),
              _RowInfo(label: l10n.courseLabel, value: request.courseName),
              _RowInfo(
                label: l10n.meetingTopicLabel,
                value: request.topicTitle,
              ),
              _RowInfo(
                label: l10n.meetingReasonLabel,
                value: request.reason,
              ),
              if (request.scheduledAt != null)
                _RowInfo(
                  label: l10n.meetingScheduledFor,
                  value: DateFormat.yMMMd(locale)
                      .add_jm()
                      .format(request.scheduledAt!),
                ),
              if (request.rescheduleNote.trim().isNotEmpty)
                _RowInfo(
                  label: l10n.rescheduleNoteLabel,
                  value: request.rescheduleNote,
                ),
              if (request.isPending) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.scheduleMeetingPrompt,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickSchedule,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    _scheduledAt == null
                        ? l10n.chooseMeetingDateTime
                        : DateFormat.yMMMd(locale)
                            .add_jm()
                            .format(_scheduledAt!),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.teacherNoteOptional,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : () => _accept(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.acceptMeeting),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : () => _decline(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.declineMeeting),
                ),
              ],
              if (request.isRescheduleRequested) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.studentAskedReschedule,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickSchedule,
                  icon: const Icon(Icons.event_repeat_rounded),
                  label: Text(
                    _scheduledAt == null
                        ? l10n.chooseNewMeetingDateTime
                        : DateFormat.yMMMd(locale)
                            .add_jm()
                            .format(_scheduledAt!),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.teacherNoteOptional,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : () => _accept(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0A800),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.setNewMeetingTime),
                ),
              ],
              if (request.isAccepted) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: (_busy || !canComplete)
                      ? null
                      : () => _complete(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    disabledBackgroundColor: AppColors.navy.withValues(
                      alpha: 0.35,
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.markMeetingCompleted),
                ),
                if (!canComplete && request.scheduledAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.meetingCompleteAfterScheduleHint(
                      DateFormat.yMMMd(locale)
                          .add_jm()
                          .format(request.scheduledAt!),
                    ),
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  const _RowInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(brightness),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary(brightness),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
