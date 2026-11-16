import 'package:flutter_test/flutter_test.dart';
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/services/live_session_lockdown.dart';

void main() {
  test('LiveLockdownStatus parses native map', () {
    final status = LiveLockdownStatus.fromMap({
      'keepScreenOn': true,
      'secure': true,
      'screenPinning': true,
      'dnd': false,
      'needsDndPermission': true,
      'platform': 'android',
      'note': 'best-effort',
    });
    expect(status.keepScreenOn, isTrue);
    expect(status.secureScreen, isTrue);
    expect(status.screenPinning, isTrue);
    expect(status.dnd, isFalse);
    expect(status.needsDndPermission, isTrue);
    expect(status.platform, 'android');
  });

  test('LectureAttendee presence defaults and maps', () {
    final attendee = LectureAttendee.fromMap('s1', {
      'studentId': 's1',
      'studentName': 'Alex',
      'studentEmail': 'a@x.com',
      'memberId': 'M1',
      'inApp': false,
    });
    expect(attendee.inApp, isFalse);
    expect(attendee.toMap()['inApp'], isFalse);
    expect(attendee.copyWith(inApp: true).inApp, isTrue);
  });
}
