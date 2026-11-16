import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/di/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../models/lecture_feedback.dart';
import '../models/live_session_model.dart';
import '../models/live_slide_signal.dart';
import '../models/user_model.dart';

/// Student: tap an understanding level for the teacher's current slide.
class LiveSlideFeedbackBar extends StatefulWidget {
  const LiveSlideFeedbackBar({
    super.key,
    required this.session,
    required this.user,
  });

  final LiveSessionModel session;
  final UserModel user;

  @override
  State<LiveSlideFeedbackBar> createState() => _LiveSlideFeedbackBarState();
}

class _LiveSlideFeedbackBarState extends State<LiveSlideFeedbackBar> {
  var _saving = false;

  Future<void> _submit(UnderstandingLevel level) async {
    if (_saving || !widget.session.isActive) {
      return;
    }
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      await AppScope.of(context).courseStore.submitLiveSlideSignal(
        session: widget.session,
        studentId: widget.user.id,
        studentName: widget.user.fullName,
        studentEmail: widget.user.email,
        memberId: widget.user.memberId,
        fileIndex: widget.session.slideFileIndex,
        page: widget.session.slidePage,
        level: level,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.liveSlideSignalSaved)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.liveSlideSignalFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final store = AppScope.of(context).courseStore;
    final file = widget.session.slideFileIndex;
    final page = widget.session.slidePage;

    return StreamBuilder<LiveSlideSignal?>(
      stream: store.watchMyLiveSlideSignal(
        courseId: widget.session.courseId,
        sessionId: widget.session.id,
        studentId: widget.user.id,
        fileIndex: file,
        page: page,
      ),
      builder: (context, snap) {
        final selected = snap.data?.level;
        final options = <(UnderstandingLevel, String, String)>[
          (
            UnderstandingLevel.percent100,
            l10n.understand100,
            l10n.understand100Hint,
          ),
          (
            UnderstandingLevel.percent80,
            l10n.understand80,
            l10n.understand80Hint,
          ),
          (
            UnderstandingLevel.percent60,
            l10n.understand60,
            l10n.understand60Hint,
          ),
          (
            UnderstandingLevel.below50,
            l10n.understandBelow50,
            l10n.understandBelow50Hint,
          ),
        ];

        return Material(
          color: AppColors.fieldFill(brightness),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.liveSlideHowClear,
                  style: TextStyle(
                    color: AppColors.textPrimary(brightness),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.liveSlideOnPage(page),
                  style: TextStyle(
                    color: AppColors.textSecondary(brightness),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      _LevelChip(
                        label: option.$2,
                        hint: option.$3,
                        selected: selected == option.$1,
                        enabled: !_saving && widget.session.isActive,
                        onTap: () => _submit(option.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.hint,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: selected
          ? AppColors.teal.withValues(alpha: 0.18)
          : (brightness == Brightness.dark
                ? AppColors.darkBackground
                : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.teal
                  : AppColors.teal.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.tealDark
                      : AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                hint,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Teacher: live list of who needs help on which slide.
class LiveSlideSignalsPanel extends StatelessWidget {
  const LiveSlideSignalsPanel({
    super.key,
    required this.session,
  });

  final LiveSessionModel session;

  String _levelLabel(AppLocalizations l10n, UnderstandingLevel level) {
    return switch (level) {
      UnderstandingLevel.percent100 => l10n.understand100,
      UnderstandingLevel.percent80 => l10n.understand80,
      UnderstandingLevel.percent60 => l10n.understand60,
      UnderstandingLevel.below50 => l10n.understandBelow50,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final store = AppScope.of(context).courseStore;
    final currentFile = session.slideFileIndex;
    final currentPage = session.slidePage;

    return StreamBuilder<List<LiveSlideSignal>>(
      stream: store.watchLiveSlideSignals(
        courseId: session.courseId,
        sessionId: session.id,
      ),
      builder: (context, snap) {
        final all = snap.data ?? const <LiveSlideSignal>[];
        final onThisSlide = all
            .where(
              (s) =>
                  s.slideFileIndex == currentFile && s.slidePage == currentPage,
            )
            .toList();
        final needHelp = onThisSlide
            .where(
              (s) =>
                  s.level == UnderstandingLevel.percent60 ||
                  s.level == UnderstandingLevel.below50,
            )
            .length;

        return Material(
          color: AppColors.fieldFill(brightness),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.liveSlideSignalsTitle,
                        style: TextStyle(
                          color: AppColors.textPrimary(brightness),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (needHelp > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l10n.liveSlideNeedHelpCount(needHelp),
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.liveSlideOnPage(currentPage),
                  style: TextStyle(
                    color: AppColors.textSecondary(brightness),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (onThisSlide.isEmpty)
                  Text(
                    l10n.liveSlideNoSignals,
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      fontSize: 13,
                    ),
                  )
                else
                  for (final signal in onThisSlide)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              signal.studentName,
                              style: TextStyle(
                                color: AppColors.textPrimary(brightness),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            _levelLabel(l10n, signal.level),
                            style: TextStyle(
                              color:
                                  signal.level == UnderstandingLevel.below50 ||
                                      signal.level ==
                                          UnderstandingLevel.percent60
                                  ? AppColors.error
                                  : AppColors.teal,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
