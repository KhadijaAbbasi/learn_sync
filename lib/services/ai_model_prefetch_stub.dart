import 'ai_practice_generator.dart';

/// No-op prefetch for web / unsupported platforms.
class AiModelPrefetch {
  AiModelPrefetch._();

  static final AiModelPrefetch instance = AiModelPrefetch._();

  bool get isSupported => false;

  bool get isComplete => false;

  double get lastProgress => 0;

  void addProgressListener(AiDownloadProgress listener) {}

  void removeProgressListener(AiDownloadProgress listener) {}

  /// Fire-and-forget start; safe no-op on unsupported platforms.
  Future<void> start() async {}

  Future<void> ensureReady({AiDownloadProgress? onProgress}) async {
    onProgress?.call(1);
  }
}