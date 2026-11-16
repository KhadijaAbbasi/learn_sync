import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/theme/app_colors.dart';
import '../models/meeting_request.dart';

class MeetingStatusChip extends StatelessWidget {
  const MeetingStatusChip({super.key, required this.status});

  final MeetingRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      MeetingRequestStatus.pending => (l10n.meetingStatusPending, AppColors.gold),
      MeetingRequestStatus.accepted => (l10n.meetingStatusAccepted, AppColors.teal),
      MeetingRequestStatus.declined => (l10n.meetingStatusDeclined, AppColors.coral),
      MeetingRequestStatus.completed => (
        l10n.meetingStatusCompleted,
        AppColors.navy,
      ),
      MeetingRequestStatus.rescheduleRequested => (
        l10n.meetingStatusReschedule,
        const Color(0xFFE0A800),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MeetingRequestCard extends StatelessWidget {
  const MeetingRequestCard({
    super.key,
    required this.request,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final MeetingRequest request;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                  MeetingStatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                request.topicTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
