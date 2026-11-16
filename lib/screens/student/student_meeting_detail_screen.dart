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

class StudentMeetingDetailScreen extends StatefulWidget {
  const StudentMeetingDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<StudentMeetingDetailScreen> createState() =>
      _StudentMeetingDetailScreenState();
}

class _StudentMeetingDetailScreenState
    extends State<StudentMeetingDetailScreen> {
  final _noteController = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _requestReschedule(MeetingRequest request) async {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final studentId = scope.sessionController.user?.id ?? '';
    setState(() => _busy = true);
    try {
      await scope.meetingStore.requestReschedule(
        requestId: request.id,
        studentId: studentId,
        note: _noteController.text,
      );
      if (mounted) {
        _noteController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rescheduleRequestedToast)),
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

  String _statusMessage(AppLocalizations l10n, MeetingRequest request) {
    switch (request.status) {
      case MeetingRequestStatus.pending:
        return l10n.meetingPendingHint;
      case MeetingRequestStatus.accepted:
        return l10n.meetingAcceptedHint;
      case MeetingRequestStatus.declined:
        return l10n.meetingDeclinedHint;
      case MeetingRequestStatus.completed:
        return l10n.meetingCompletedHint;
      case MeetingRequestStatus.rescheduleRequested:
        return l10n.meetingRescheduleHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);

    if (user?.role != UserRole.student) {
      return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(l10n.navMeetings)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        centerTitle: true,
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
          if (request == null || request.studentId != user!.id) {
            return Center(child: Text(l10n.meetingNotFound));
          }
          final locale = Localizations.localeOf(context).toString();
          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MeetingStatusChip(status: request.status),
              ),
              const SizedBox(height: 16),
              _InfoBlock(
                label: l10n.courseLabel,
                value: request.courseName,
              ),
              _InfoBlock(
                label: l10n.meetingTopicLabel,
                value: request.topicTitle,
              ),
              if (request.chapterTitle.isNotEmpty)
                _InfoBlock(
                  label: l10n.selectChapter,
                  value: request.chapterTitle,
                ),
              _InfoBlock(
                label: l10n.meetingReasonLabel,
                value: request.reason,
              ),
              if (request.scheduledAt != null)
                _InfoBlock(
                  label: l10n.meetingScheduledFor,
                  value: DateFormat.yMMMd(locale)
                      .add_jm()
                      .format(request.scheduledAt!),
                ),
              if (request.teacherNote.trim().isNotEmpty)
                _InfoBlock(
                  label: l10n.teacherNote,
                  value: request.teacherNote,
                ),
              const SizedBox(height: 12),
              Text(
                _statusMessage(l10n, request),
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  height: 1.4,
                ),
              ),
              if (request.isAccepted) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.requestRescheduleHint,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.rescheduleNoteOptional,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _requestReschedule(request),
                  icon: const Icon(Icons.event_repeat_rounded),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE0A800),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  label: Text(l10n.requestReschedule),
                ),
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

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
