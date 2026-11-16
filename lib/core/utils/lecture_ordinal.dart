import '../../models/live_session_model.dart';

/// 1-based lecture ordinal for [session] among ended live sessions on the same
/// course/chapter/topic (active session = ended count + 1).
int lectureOrdinalForTopic({
  required LiveSessionModel session,
  required List<LiveSessionModel> endedForTopic,
}) {
  final ended = [...endedForTopic]
    ..sort((a, b) {
      final left =
          a.startedAt ?? a.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.startedAt ?? b.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return left.compareTo(right);
    });
  final index = ended.indexWhere((item) => item.id == session.id);
  if (index >= 0) {
    return index + 1;
  }
  return ended.length + 1;
}
