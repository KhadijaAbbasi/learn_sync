import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/live_session_model.dart';
import '../../services/ai_practice_generator.dart';
import '../../widgets/custom_button.dart';
import 'ai_practice_chrome.dart';
import 'ai_practice_screen.dart';

class AiPracticeResultsScreen extends StatelessWidget {
  const AiPracticeResultsScreen({
    super.key,
    required this.session,
    required this.courseName,
    required this.studentId,
    required this.studentName,
    required this.attempt,
    this.lectureOrdinal,
    this.generator,
  });

  final LiveSessionModel session;
  final String courseName;
  final String studentId;
  final String studentName;
  final AiPracticeAttempt attempt;
  /// 1-based lecture number for this session/topic; shown under Topic.
  final int? lectureOrdinal;
  final AiPracticeGenerator? generator;

  void _goHome(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.studentDashboard, (_) => false);
  }

  void _practiceAgain(BuildContext context) {
    // Keep this results screen on the stack so Back from the new quiz
    // returns here (pushReplacement would discard it).
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiPracticeScreen(
          session: session,
          courseName: courseName,
          studentId: studentId,
          studentName: studentName,
          lectureOrdinal: lectureOrdinal,
          generator: generator,
        ),
      ),
    );
  }

  void _reviewExplanations(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text(
                  l10n.reviewExplanations,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < attempt.questions.length; i++)
                  _ExplanationTile(
                    index: i,
                    question: attempt.questions[i],
                    selected: i < attempt.selectedIndexes.length
                        ? attempt.selectedIndexes[i]
                        : -1,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final topic = session.topicTitle.trim().isEmpty
        ? courseName
        : session.topicTitle;
    final passed = attempt.passed;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      body: Column(
        children: [
          AiPracticeAppBar(
            title: l10n.aiQuizResultsTitle,
            badge: l10n.completedBadgeCaps,
            completed: true,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(padding, 18, padding, 24),
              children: [
                Text(
                  l10n.topicPrefix(topic),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                if (lectureOrdinal != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.lectureNumber(lectureOrdinal!),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  l10n.resultsSecureHint,
                  style: TextStyle(color: AppColors.textSecondary(brightness)),
                ),
                const SizedBox(height: 16),
                _ScoreCard(attempt: attempt, passed: passed),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: '${attempt.total}',
                        label: l10n.totalQuestionsLabel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        value: '${attempt.score}',
                        label: l10n.correctAnswersLabel,
                        emphasize: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        value: '${attempt.wrongCount}',
                        label: l10n.wrongAnswersLabel,
                        danger: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DiagnosticCard(text: attempt.diagnostic),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _reviewExplanations(context),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    l10n.reviewExplanations,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.teal),
                ),
                const SizedBox(height: 8),
                CustomButton(
                  label: l10n.practiceAgain,
                  onPressed: () => _practiceAgain(context),
                  variant: AppButtonVariant.signup,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => _goHome(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    child: Text(l10n.endPractice),
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.attempt, required this.passed});

  final AiPracticeAttempt attempt;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: CustomPaint(
                painter: _RingPainter(progress: attempt.percent / 100),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${attempt.percent}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      Text(
                        l10n.completedBadgeCaps,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.quizCompletedTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    passed ? l10n.quizPassedMessage : l10n.quizFailedMessage,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (passed ? AppColors.teal : const Color(0xFFE05A5A))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      passed ? '✓ ${l10n.passedBadge}' : l10n.needsReviewBadge,
                      style: TextStyle(
                        color: passed
                            ? AppColors.tealDark
                            : const Color(0xFFE05A5A),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 9.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = const Color(0xFFDDE5EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress.clamp(0, 1) * math.pi * 2,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.emphasize = false,
    this.danger = false,
  });

  final String value;
  final String label;
  final bool emphasize;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFE05A5A)
        : emphasize
        ? AppColors.teal
        : AppColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: danger
            ? const Color(0xFFE05A5A).withValues(alpha: 0.08)
            : emphasize
            ? AppColors.teal.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: danger
              ? const Color(0xFFE05A5A).withValues(alpha: 0.45)
              : emphasize
              ? AppColors.teal.withValues(alpha: 0.45)
              : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.aiTutorBadge,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.diagnosticTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? l10n.quizPassedMessage : text,
            style: const TextStyle(
              height: 1.4,
              fontSize: 13.5,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationTile extends StatelessWidget {
  const _ExplanationTile({
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
    final correct = selected == question.correctIndex;
    final letters = const ['A', 'B', 'C', 'D'];
    String label(int index) {
      if (index < 0 || index >= question.options.length) {
        return '—';
      }
      return '${letters[index]}. ${question.options[index]}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.prompt}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (question.slidePage > 0) ...[
            const SizedBox(height: 4),
            Text(
              l10n.liveSlideOnPage(question.slidePage),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.navy,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${l10n.explanationYourAnswer}: ${label(selected)}',
            style: TextStyle(
              color: correct ? AppColors.tealDark : const Color(0xFFE05A5A),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!correct)
            Text(
              '${l10n.explanationCorrectLabel}: ${label(question.correctIndex)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(question.explanation),
          ],
        ],
      ),
    );
  }
}
