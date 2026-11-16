import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lecture_feedback.dart';

({String emoji, String percent, Color color, String hint})
understandingLevelVisual(AppLocalizations l10n, UnderstandingLevel level) {
  return switch (level) {
    UnderstandingLevel.percent100 => (
      emoji: '😄',
      percent: l10n.understand100,
      color: const Color(0xFF2E9B5A),
      hint: l10n.understoodPerfectly,
    ),
    UnderstandingLevel.percent80 => (
      emoji: '🙂',
      percent: l10n.understand80,
      color: AppColors.teal,
      hint: l10n.understoodMost,
    ),
    UnderstandingLevel.percent60 => (
      emoji: '😐',
      percent: l10n.understand60,
      color: const Color(0xFFE0B03A),
      hint: l10n.understoodSome,
    ),
    UnderstandingLevel.below50 => (
      emoji: '😞',
      percent: l10n.understandBelow50,
      color: const Color(0xFFE05A5A),
      hint: l10n.needMoreHelp,
    ),
  };
}

Color understandingLevelColor(UnderstandingLevel level) {
  return switch (level) {
    UnderstandingLevel.percent100 => const Color(0xFF2E9B5A),
    UnderstandingLevel.percent80 => AppColors.teal,
    UnderstandingLevel.percent60 => const Color(0xFFE0B03A),
    UnderstandingLevel.below50 => const Color(0xFFE05A5A),
  };
}
