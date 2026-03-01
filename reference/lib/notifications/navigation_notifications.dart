import 'package:flutter/widgets.dart';

/// Notification dispatched when the user presses Arrow Down inside a record.
///
/// Flutter Notifications bubble up the widget tree from child to ancestor.
/// This replaces direct callback prop-drilling for cross-section navigation.
/// See: https://api.flutter.dev/flutter/widgets/Notification-class.html
class NavigateDownNotification extends Notification {
  final String recordId;
  final int recordIndex;
  final String date;
  // P10: sectionType removed — was hardcoded 'records' at every call site and never read.

  const NavigateDownNotification({
    required this.recordId,
    required this.recordIndex,
    required this.date,
  });
}

/// Notification dispatched when the user presses Arrow Up inside a record.
class NavigateUpNotification extends Notification {
  final String recordId;
  final int recordIndex;
  final String date;

  const NavigateUpNotification({
    required this.recordId,
    required this.recordIndex,
    required this.date,
  });
}

/// Notification dispatched after a slash command or type-picker converts a record.
///
/// RecordSection's listener calls addPostFrameCallback so the new widget's
/// FocusNode has time to register before focus is restored.
class RefocusRecordNotification extends Notification {
  final String recordId;

  const RefocusRecordNotification({required this.recordId});
}
