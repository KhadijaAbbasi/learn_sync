import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Best-effort student focus lockdown during a live lecture.
///
/// Honest limits: a normal Flutter app cannot fully block other apps, calls,
/// or notifications on stock Android/iOS without MDM / Device Owner / Guided
/// Access. This service does the strongest practical actions that App Store /
/// Play policies allow, and reports what actually applied.
class LiveLockdownStatus {
  const LiveLockdownStatus({
    this.keepScreenOn = false,
    this.secureScreen = false,
    this.screenPinning = false,
    this.dnd = false,
    this.needsDndPermission = false,
    this.platform = 'unknown',
    this.note = '',
  });

  final bool keepScreenOn;
  final bool secureScreen;
  final bool screenPinning;
  final bool dnd;
  final bool needsDndPermission;
  final String platform;
  final String note;

  factory LiveLockdownStatus.fromMap(dynamic raw) {
    if (raw is! Map) {
      return const LiveLockdownStatus();
    }
    final map = Map<String, dynamic>.from(raw);
    return LiveLockdownStatus(
      keepScreenOn: map['keepScreenOn'] == true,
      secureScreen: map['secure'] == true || map['secureScreen'] == true,
      screenPinning: map['screenPinning'] == true,
      dnd: map['dnd'] == true,
      needsDndPermission: map['needsDndPermission'] == true,
      platform: (map['platform'] as String?) ?? 'unknown',
      note: (map['note'] as String?) ?? '',
    );
  }
}

class LiveSessionLockdown {
  LiveSessionLockdown._();

  static const MethodChannel _channel = MethodChannel(
    'learnsync/live_lockdown',
  );

  static var _enabled = false;
  static LiveLockdownStatus? lastStatus;

  static bool get isEnabled => _enabled;

  /// Enable keep-awake, screenshot block, optional screen pin + DND (Android).
  static Future<LiveLockdownStatus> enable() async {
    if (kIsWeb) {
      lastStatus = const LiveLockdownStatus(
        platform: 'web',
        note: 'Focus lockdown is not available on web.',
      );
      _enabled = false;
      return lastStatus!;
    }
    try {
      final raw = await _channel.invokeMethod<dynamic>('enable');
      lastStatus = LiveLockdownStatus.fromMap(raw);
      _enabled = true;
      return lastStatus!;
    } on MissingPluginException {
      lastStatus = const LiveLockdownStatus(
        note: 'Native lockdown plugin missing on this build.',
      );
      _enabled = false;
      return lastStatus!;
    } catch (error) {
      lastStatus = LiveLockdownStatus(note: 'Lockdown enable failed: $error');
      _enabled = false;
      return lastStatus!;
    }
  }

  /// Release pin, DND, keep-awake, and secure flag.
  static Future<void> disable() async {
    if (!_enabled && lastStatus == null) {
      return;
    }
    if (kIsWeb) {
      _enabled = false;
      return;
    }
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (_) {
      // Best-effort release.
    } finally {
      _enabled = false;
    }
  }

  static Future<bool> openNotificationPolicySettings() async {
    if (kIsWeb) {
      return false;
    }
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openNotificationPolicySettings',
      );
      return opened == true;
    } catch (_) {
      return false;
    }
  }
}
