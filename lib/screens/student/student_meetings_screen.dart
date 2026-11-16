import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/meeting_request.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/meeting_widgets.dart';
import 'create_meeting_screen.dart';
import 'student_meeting_detail_screen.dart';

class StudentMeetingsScreen extends StatelessWidget {
  const StudentMeetingsScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user?.role != UserRole.student) {
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
        leading: embeddedInShell ? null : const AppBackButton(),
        automaticallyImplyLeading: !embeddedInShell,
        title: Text(l10n.myMeetingRequests),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CreateMeetingScreen(),
            ),
          );
        },
        backgroundColor: AppColors.teal,
        tooltip: l10n.requestMeeting,
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<MeetingRequest>>(
        stream: scope.meetingStore.watchStudentRequests(user!.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: _EmptyState(
                title: l10n.noMeetingRequestsYet,
                body: l10n.noMeetingRequestsStudentHint,
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 100),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = items[index];
              return MeetingRequestCard(
                request: request,
                title: request.courseName,
                subtitle: request.reason,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StudentMeetingDetailScreen(requestId: request.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: AppColors.teal.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(brightness),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
