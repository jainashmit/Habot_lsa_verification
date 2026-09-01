import 'dart:async';

class FrictionLogger {
  final String fieldName;
  final Duration threshold;
  final void Function(String message)? onLog;
  Timer? _timer;

  FrictionLogger({
    required this.fieldName,
    this.threshold = const Duration(seconds: 5),
    this.onLog,
  });

  void onInteractionStart() {
    _timer?.cancel();
    _timer = Timer(threshold, _logFriction);
  }

  void onInteractionEnd() {
    _timer?.cancel();
  }

  void _logFriction() {
    final now = DateTime.now().toUtc().toIso8601String();
    final durationStr = '${(threshold.inMilliseconds / 1000).toStringAsFixed(1)}s';
    final message =
        '[UI_FRICTION_LOG] Timestamp: $now | Field: $fieldName | Hesitation Duration: $durationStr';
    // ignore: avoid_print
    print(message);
    onLog?.call(message);
  }

  void dispose() {
    _timer?.cancel();
  }
}