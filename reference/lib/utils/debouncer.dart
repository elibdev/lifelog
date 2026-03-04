import 'dart:async';

/// Delays execution until a pause in calls.
///
/// Used for debouncing record saves (one DB write per pause in typing)
/// and search queries (one query per pause in input).
class Debouncer {
  final Duration delay;
  Timer? _timer;
  // M7: Store the pending action so flush() can fire it immediately.
  void Function()? _pendingAction;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  /// Schedule [action] after [delay]. Resets the timer if called again
  /// before the delay expires.
  void call(void Function() action) {
    _timer?.cancel();
    _pendingAction = action;
    _timer = Timer(delay, () {
      action();
      _pendingAction = null;
    });
  }

  void cancel() => _timer?.cancel();

  // M7: Flush immediately fires the pending action (if any) without waiting
  // for the delay to expire. Called on app background/pause so in-flight
  // keystrokes are written to the DB before the OS might kill the process.
  void flush() {
    if (_timer?.isActive == true) {
      _timer!.cancel();
      _pendingAction?.call();
      _pendingAction = null;
    }
  }

  void dispose() {
    _timer?.cancel();
    _pendingAction = null;
  }
}
