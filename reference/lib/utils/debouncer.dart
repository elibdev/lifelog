import 'dart:async';

/// Delays execution until a pause in calls.
///
/// Used for debouncing record saves (one DB write per pause in typing)
/// and search queries (one query per pause in input).
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  /// Schedule [action] after [delay]. Resets the timer if called again
  /// before the delay expires.
  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
