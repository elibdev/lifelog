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
  final String sectionType;

  const NavigateDownNotification({
    required this.recordId,
    required this.recordIndex,
    required this.date,
    required this.sectionType,
  });
}

/// Notification dispatched when the user presses Arrow Up inside a record.
class NavigateUpNotification extends Notification {
  final String recordId;
  final int recordIndex;
  final String date;
  final String sectionType;

  const NavigateUpNotification({
    required this.recordId,
    required this.recordIndex,
    required this.date,
    required this.sectionType,
  });
}

/// Notification dispatched after a slash command converts a record's type.
///
/// The widget tree is rebuilt with a new sub-widget type for the same record ID.
/// RecordSection listens for this and refocuses the record after the rebuild
/// completes, restoring keyboard focus across the type-change transition.
class RefocusRecordNotification extends Notification {
  final String recordId;

  const RefocusRecordNotification({required this.recordId});
}
