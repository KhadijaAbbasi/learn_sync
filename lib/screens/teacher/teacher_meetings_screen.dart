import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/meeting_request.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/meeting_widgets.dart';
import 'meeting_detail_screen.dart';

enum TeacherMeetingListFilter { all, pending, scheduled, attended }

class TeacherMeetingsScreen extends StatelessWidget {
  const TeacherMeetingsScreen({
    super.key,
    this.lectureId = '',
    this.courseId = '',
    this.topicId = '',
    this.topicTitle = '',
    this.filter = TeacherMeetingListFilter.all,
    this.embeddedInShell = false,
  });

  final String lectureId;
  final String courseId;
  final String topicId;
  final String topicTitle;
  final TeacherMeetingListFilter filter;
  final bool embeddedInShell;

  bool get _lectureScoped =>
      lectureId.isNotEmpty || courseId.isNotEmpty || topicId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user?.role != UserRole.teacher) {
      return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(l10n.navMeetings)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: (embeddedInShell && !_lectureScoped)
            ? null
            : const AppBackButton(),
        automaticallyImplyLeading: !(embeddedInShell && !_lectureScoped),
        title: Text(_title(l10n)),
      ),
      body: StreamBuilder<List<MeetingRequest>>(
        stream: scope.meetingStore.watchTeacherRequests(user!.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = _applyFilters(snapshot.data ?? const []);
          if (items.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: AppColors.teal.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _emptyTitle(l10n),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _emptyHint(l10n),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (_lectureScoped || filter != TeacherMeetingListFilter.all) {
            return ListView(
              padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
              children: [
                for (final request in items) ...[
                  MeetingRequestCard(
                    request: request,
                    title: request.studentName,
                    subtitle: '${request.courseName} · ${request.reason}',
                    onTap: () => _openDetail(context, request.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          }

          final pending =
              items.where((item) => item.needsTeacherAction).toList();
          final others =
              items.where((item) => !item.needsTeacherAction).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              if (pending.isNotEmpty) ...[
                Text(
                  l10n.pendingMeetings,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 10),
                for (final request in pending) ...[
                  MeetingRequestCard(
                    request: request,
                    title: request.studentName,
                    subtitle: '${request.courseName} · ${request.reason}',
                    onTap: () => _openDetail(context, request.id),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
              ],
              if (others.isNotEmpty) ...[
                Text(
                  l10n.allMeetings,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 10),
                for (final request in others) ...[
                  MeetingRequestCard(
                    request: request,
                    title: request.studentName,
                    subtitle: '${request.courseName} · ${request.topicTitle}',
                    onTap: () => _openDetail(context, request.id),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  List<MeetingRequest> _applyFilters(List<MeetingRequest> items) {
    final scoped = [
      for (final item in items)
        if (!_lectureScoped ||
            meetingMatchesLecture(
              item,
              courseId: courseId,
              lectureId: lectureId,
              topicId: topicId,
              topicTitle: topicTitle,
            ))
          item,
    ];
    return [
      for (final item in scoped)
        if (_matchesStatus(item)) item,
    ];
  }

  bool _matchesStatus(MeetingRequest item) {
    return switch (filter) {
      TeacherMeetingListFilter.all => true,
      TeacherMeetingListFilter.pending => item.needsTeacherAction,
      TeacherMeetingListFilter.scheduled => item.isAccepted,
      TeacherMeetingListFilter.attended => item.isCompleted,
    };
  }

  String _title(AppLocalizations l10n) {
    return switch (filter) {
      TeacherMeetingListFilter.pending => l10n.pendingRequests,
      TeacherMeetingListFilter.scheduled => l10n.scheduledMeetings,
      TeacherMeetingListFilter.attended => l10n.attendedMeetings,
      TeacherMeetingListFilter.all =>
        _lectureScoped ? l10n.lectureMeetingsHubTitle : l10n.meetingRequests,
    };
  }

  String _emptyTitle(AppLocalizations l10n) {
    if (_lectureScoped) {
      return switch (filter) {
        TeacherMeetingListFilter.pending => l10n.noPendingMeetingsForLecture,
        TeacherMeetingListFilter.scheduled => l10n.noScheduledMeetingsForLecture,
        TeacherMeetingListFilter.attended => l10n.noAttendedMeetingsForLecture,
        TeacherMeetingListFilter.all => l10n.noMeetingsForLecture,
      };
    }
    return l10n.noMeetingRequestsYet;
  }

  String _emptyHint(AppLocalizations l10n) {
    if (_lectureScoped) {
      return l10n.lectureMeetingsHubSubtitle;
    }
    return l10n.noMeetingRequestsTeacherHint;
  }

  void _openDetail(BuildContext context, String requestId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(requestId: requestId),
      ),
    );
  }
}
