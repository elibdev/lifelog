import 'package:flutter/material.dart';

// FLUTTER NOTIFICATION PATTERN
// ===========================
// Notifications "bubble up" the widget tree, allowing any ancestor to listen.
// This is different from callbacks, which directly connect child to parent.
//
// How it works:
// 1. Child dispatches: NavigateDownNotification().dispatch(context)
// 2. Notification bubbles up through all ancestors
// 3. Any ancestor with NotificationListener<NavigateDownNotification> can handle it
// 4. Listener returns true to STOP bubbling, false to CONTINUE bubbling
//
// Example flow:
//   RecordWidget dispatches NavigateDownNotification
//        ↓ (bubbles up)
//   RecordSection's NotificationListener receives it
//        → Can handle? Focus next record, return true (stop bubbling)
//        → Can't handle? Return false (continue bubbling)
//        ↓ (bubbles up)
//   JournalScreen's NotificationListener receives it
//        → Focus next section/day, return true (stop bubbling)
//
// This is the same pattern Flutter uses for:
// - ScrollNotification (scroll events bubble up from scrollable widgets)
// - SizeChangedLayoutNotification (size changes bubble up)
// - LayoutChangedNotification (layout changes bubble up)

/// Notification dispatched when user wants to navigate down (arrow down key)
///
/// This notification bubbles up through the widget tree, allowing any ancestor
/// to handle the navigation. Typically:
/// - RecordSection tries to focus the next record in its list
/// - If at the end of the section, it returns false to let it bubble up
/// - JournalScreen catches it and focuses the next section or day
class NavigateDownNotification extends Notification {
  /// ID of the record that dispatched this notification
  final String recordId;

  /// Index of the record within its parent RecordSection
  final int recordIndex;

  NavigateDownNotification({
    required this.recordId,
    required this.recordIndex,
  });
}

/// Notification dispatched when user wants to navigate up (arrow up key)
///
/// This notification bubbles up through the widget tree, allowing any ancestor
/// to handle the navigation. Typically:
/// - RecordSection tries to focus the previous record in its list
/// - If at the start of the section, it returns false to let it bubble up
/// - JournalScreen catches it and focuses the previous section or day
class NavigateUpNotification extends Notification {
  /// ID of the record that dispatched this notification
  final String recordId;

  /// Index of the record within its parent RecordSection
  final int recordIndex;

  NavigateUpNotification({
    required this.recordId,
    required this.recordIndex,
  });
}
