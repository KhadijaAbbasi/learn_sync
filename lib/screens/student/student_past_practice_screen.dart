import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_practice.dart';
import '../../models/live_session_model.dart';

/// Read-only list of every past AI practice question for one lecture
/// across all of this student's attempts.
class StudentPastPracticeScreen extends StatefulWidget {
  const StudentPastPracticeScreen({
    super.key,
    required this.session,
    required this.courseName,
    required this.studentId,
    this.lectureOrdinal,
  });

  final LiveSessionModel session;
  final String courseName;
  final String studentId;

  /// 1-based lecture number for this session/topic.
  final int? lectureOrdinal;

  @override
  State<StudentPastPracticeScreen> createState() =>
      _StudentPastPracticeScreenState();
}

class _StudentPastPracticeScreenState extends State<StudentPastPracticeScreen> {
  var _loadingRemote = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _optionalRemoteFetch());
  }

  Future<void> _optionalRemoteFetch() async {
    if (!mounted || widget.studentId.isEmpty) {
      return;
    }
    final store = AppScope.of(context).courseStore;
    final local = store.localMyPracticeAttempts(
      lectureId: widget.session.id,
      studentId: widget.studentId,
    );
    // Local mirror is enough when present; still refresh once for completeness.
    setState(() => _loadingRemote = local.isEmpty);
    try {
      await store.fetchMyPracticeAttemptsOnce(
        lectureId: widget.session.id,
        studentId: widget.studentId,
      );
    } finally {
      if (mounted) {
        setState(() => _loadingRemote = false);
      }
    }
  }

  String _bodyHeader(AppLocalizations l10n) {
    final topic = widget.session.topicTitle.trim().isEmpty
        ? widget.courseName
        : widget.session.topicTitle;
    final ordinal = widget.lectureOrdinal;
    if (ordinal != null) {
      return '$topic · ${l10n.lectureNumber(ordinal)}';
    }
    return topic;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final brightness = Theme.of(context).brightness;
    final bodyHeader = _bodyHeader(l10n);

    return ListenableBuilder(
      listenable: scope.courseStore,
      builder: (context, _) {
        final attempts = scope.courseStore.localMyPracticeAttempts(
          lectureId: widget.session.id,
          studentId: widget.studentId,
        );
        // Newest first from store; show oldest→newest for reading history.
        final ordered = attempts.reversed.toList();

        return Scaffold(
          backgroundColor: brightness == Brightness.dark
              ? AppColors.darkBackground
              : AppColors.pageWash,
          appBar: AppBar(
            backgroundColor: AppColors.headerNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(l10n.pastPracticeTitle),
            centerTitle: true,
          ),
          body: ordered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loadingRemote)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: CircularProgressIndicator(),
                          ),
                        Text(
                          l10n.pastPracticeEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: ordered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          bodyHeader,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                      );
                    }
                    final attempt = ordered[index - 1];
                    return _PastAttemptBlock(
                      attemptNumber: index,
                      attempt: attempt,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _PastAttemptBlock extends StatelessWidget {
  const _PastAttemptBlock({
    required this.attemptNumber,
    required this.attempt,
  });

  final int attemptNumber;
  final AiPracticeAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final when = attempt.completedAt ?? attempt.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pastPracticeAttemptLabel(
              attemptNumber,
              attempt.score,
              attempt.total,
              attempt.percent,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.tealDark,
            ),
          ),
          if (when != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatWhen(when),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (attempt.questions.isEmpty)
            Text(
              l10n.pastPracticeEmpty,
              style: TextStyle(color: AppColors.textSecondary(brightness)),
            )
          else
            for (var i = 0; i < attempt.questions.length; i++)
              _PastQuestionTile(
                index: i,
                question: attempt.questions[i],
                selected: i < attempt.selectedIndexes.length
                    ? attempt.selectedIndexes[i]
                    : -1,
              ),
        ],
      ),
    );
  }

  String _formatWhen(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _PastQuestionTile extends StatelessWidget {
  const _PastQuestionTile({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final AiQuizQuestion question;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final letters = const ['A', 'B', 'C', 'D'];
    final hasAnswer = question.correctIndex >= 0;
    final correct = hasAnswer && selected == question.correctIndex;

    String label(int optionIndex) {
      if (optionIndex < 0 || optionIndex >= question.options.length) {
        return '—';
      }
      final letter = optionIndex < letters.length
          ? letters[optionIndex]
          : '${optionIndex + 1}';
      return '$letter. ${question.options[optionIndex]}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.prompt}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (question.slidePage > 0) ...[
            const SizedBox(height: 4),
            Text(
              l10n.liveSlideOnPage(question.slidePage),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
          const SizedBox(height: 6),
          for (var o = 0; o < question.options.length; o++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                label(o),
                style: TextStyle(
                  fontWeight: o == selected || o == question.correctIndex
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: o == question.correctIndex && hasAnswer
                      ? AppColors.tealDark
                      : o == selected && hasAnswer && !correct
                          ? const Color(0xFFE05A5A)
                          : null,
                ),
              ),
            ),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(question.explanation, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
