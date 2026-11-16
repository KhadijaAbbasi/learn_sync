import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/live_session_model.dart';

/// Join confirmation once per live session (app bar + course detail).
class LiveJoinGate {
  LiveJoinGate._();

  static const _prefsKey = 'confirmed_live_session_ids';

  static Future<bool> needsConfirm(String sessionId) async {
    if (sessionId.isEmpty) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? const <String>[];
    return !ids.contains(sessionId);
  }

  static Future<void> markConfirmed(String sessionId) async {
    if (sessionId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final ids = [...?prefs.getStringList(_prefsKey)];
    if (ids.contains(sessionId)) {
      return;
    }
    ids.add(sessionId);
    await prefs.setStringList(_prefsKey, ids);
  }

  /// Returns true if the user may enter the live lecture.
  static Future<bool> confirmIfNeeded({
    required BuildContext context,
    required LiveSessionModel session,
    required String courseName,
  }) async {
    if (!await needsConfirm(session.id)) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.joinLecture),
        content: Text(
          l10n.joinLectureConfirm(courseName, session.topicTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.joinLecture),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await markConfirmed(session.id);
      return true;
    }
    return false;
  }
}
