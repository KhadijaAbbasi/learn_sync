import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_practice.dart';
import 'ai_practice_generator.dart';

const _qwen25Repo = 'litert-community/Qwen2.5-0.5B-Instruct';
const _qwen25Url =
    'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';

const _prefsCompleteKey = 'ai_model_prefetch_complete_qwen25_05b_task';
const _prefsProgressKey = 'ai_model_prefetch_progress_qwen25_05b_task';
const _prefsIncompleteKey = 'ai_model_prefetch_incomplete_qwen25_05b_task';

/// Coordinates a single shared on-device Qwen 2.5 0.5B (.task) install for AI
/// Practice and first-launch prefetch (singleflight). Public HF model - no token.
/// Uses MediaPipeEngine so Android API 29 devices work (LiteRT FFI needs API 30+).
class AiModelPrefetch {
  AiModelPrefetch._();

  static final AiModelPrefetch instance = AiModelPrefetch._();

  final List<AiDownloadProgress> _listeners = <AiDownloadProgress>[];
  Future<void>? _inFlight;
  var _initialized = false;
  var _complete = false;
  var _lastProgress = 0.0;

  bool get isSupported => !kIsWeb;

  bool get isComplete => _complete;

  double get lastProgress => _lastProgress;

  void addProgressListener(AiDownloadProgress listener) {
    _listeners.add(listener);
  }

  void removeProgressListener(AiDownloadProgress listener) {
    _listeners.remove(listener);
  }

  /// Best-effort background download on app start. Does not throw to callers
  /// of [start]; failures are logged and retried on the next launch / ensureReady.
  Future<void> start() async {
    if (!isSupported) {
      return;
    }
    try {
      await ensureReady();
    } catch (error, stackTrace) {
      debugPrint('AiModelPrefetch.start failed: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Ensures Qwen 2.5 0.5B (.task) is installed. Concurrent callers share one
  /// in-flight Future (singleflight).
  Future<void> ensureReady({AiDownloadProgress? onProgress}) async {
    if (!isSupported) {
      throw const AiPracticeException(
        AiPracticeException.unsupported,
        'On-device AI practice is not available in the browser.',
      );
    }

    if (onProgress != null) {
      addProgressListener(onProgress);
    }
    try {
      await _restorePrefs();
      await _initialize();

      if (FlutterGemma.activeModelSpec != null) {
        await _markComplete(progress: 1);
        _notify(1);
        return;
      }
      if (_complete) {
        // Prefs said complete but runtime has no active spec - reinstall.
        _complete = false;
        await _setIncomplete();
      }

      final existing = _inFlight;
      if (existing != null) {
        await existing;
        return;
      }

      final future = _installUntilReady();
      _inFlight = future;
      try {
        await future;
      } finally {
        if (identical(_inFlight, future)) {
          _inFlight = null;
        }
      }
    } finally {
      if (onProgress != null) {
        removeProgressListener(onProgress);
      }
    }
  }

  Future<void> _installUntilReady() async {
    try {
      await _setIncomplete();
      await _installModel();
      if (FlutterGemma.activeModelSpec == null) {
        throw StateError('Model install finished without an active model spec.');
      }
      await _markComplete(progress: 1);
      _notify(1);
    } catch (error, stackTrace) {
      debugPrint('Qwen 2.5 0.5B install failed: $error');
      debugPrint('$stackTrace');
      await _setIncomplete();
      throw AiPracticeException(
        AiPracticeException.downloadFailed,
        'Could not download Qwen 2.5 0.5B. $error',
      );
    }
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    await FlutterGemma.initialize(
      inferenceEngines: const [MediaPipeEngine()],
    );
    _initialized = true;
  }

  Future<void> _installModel() async {
    try {
      await FlutterGemma.installModel(
            modelType: ModelType.qwen,
            fileType: ModelFileType.task,
          )
          .fromHuggingFace(_qwen25Repo, foreground: true)
          .withProgress(_onInstallProgress)
          .install();
    } catch (error) {
      debugPrint('HuggingFace manifest install failed: $error');
      await FlutterGemma.installModel(
            modelType: ModelType.qwen,
            fileType: ModelFileType.task,
          )
          .fromNetwork(_qwen25Url, foreground: true)
          .withProgress(_onInstallProgress)
          .install();
    }
  }

  void _onInstallProgress(int progress) {
    final value = (progress / 100).clamp(0.0, 1.0);
    _lastProgress = value;
    _notify(value);
    unawaited(_persistProgress(value));
  }

  void _notify(double progress) {
    _lastProgress = progress;
    for (final listener in List<AiDownloadProgress>.from(_listeners)) {
      listener(progress);
    }
  }

  Future<void> _restorePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _complete = prefs.getBool(_prefsCompleteKey) ?? false;
      _lastProgress = prefs.getDouble(_prefsProgressKey) ?? 0;
      if (_lastProgress > 0 && _lastProgress < 1) {
        _notify(_lastProgress);
      }
    } catch (error) {
      debugPrint('AiModelPrefetch prefs restore failed: $error');
    }
  }

  Future<void> _markComplete({required double progress}) async {
    _complete = true;
    _lastProgress = progress;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsCompleteKey, true);
      await prefs.setBool(_prefsIncompleteKey, false);
      await prefs.setDouble(_prefsProgressKey, progress);
    } catch (error) {
      debugPrint('AiModelPrefetch markComplete failed: $error');
    }
  }

  Future<void> _setIncomplete() async {
    _complete = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsCompleteKey, false);
      await prefs.setBool(_prefsIncompleteKey, true);
    } catch (error) {
      debugPrint('AiModelPrefetch setIncomplete failed: $error');
    }
  }

  Future<void> _persistProgress(double progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsProgressKey, progress);
      await prefs.setBool(_prefsIncompleteKey, progress < 1);
      if (progress >= 1) {
        await prefs.setBool(_prefsCompleteKey, true);
        await prefs.setBool(_prefsIncompleteKey, false);
      }
    } catch (_) {
      // Ignore persistence errors during download ticks.
    }
  }
}
