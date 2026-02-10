# Step 8: Custom Notifications

**Goal:** Use Flutter's Notification pattern for loosely-coupled child-to-ancestor communication.

**Your file:** `lib/notifications/navigation_notifications.dart`
**Reference:** `reference/lib/widgets/` (see how notifications are dispatched and caught)

## The Problem

A `RecordWidget` deep in the tree needs to tell `JournalScreen` (far up the tree) to navigate. Three options:

| Approach | Pros | Cons |
|---|---|---|
| Callbacks | Simple, direct | Prop drilling through every intermediate widget |
| GlobalKey | Direct state access | Tight coupling, fragile |
| **Notification** | **Decoupled, no prop drilling** | Slightly more setup |

## How Flutter Notifications Work

Notifications bubble **up** the widget tree (child → ancestor), the opposite of how data flows **down** (parent → child via constructors).

```
JournalScreen ← catches NavigateUpNotification
  └─ DaySection  (notification passes through, unaware)
       └─ RecordSection  (notification passes through)
            └─ RecordWidget  ← dispatches NavigateUpNotification
```

Built-in examples: `ScrollNotification`, `OverscrollNotification`, `KeepAliveNotification`.

> See: https://api.flutter.dev/flutter/widgets/Notification-class.html

## Define Custom Notifications

```dart
// lib/notifications/navigation_notifications.dart

import 'package:flutter/widgets.dart';

class NavigateUpNotification extends Notification {
  const NavigateUpNotification();
}

class NavigateDownNotification extends Notification {
  const NavigateDownNotification();
}
```

That's it — just extend `Notification`. You can add fields for data:

```dart
class DeleteRecordNotification extends Notification {
  final String recordId;
  const DeleteRecordNotification(this.recordId);
}
```

## Dispatch from Child

```dart
// In RecordWidget, when user presses arrow up:
NavigateUpNotification().dispatch(context);
//                                ^^^^^^^
// 'context' is the BuildContext — it knows where this widget
// lives in the tree, so Flutter knows which direction to bubble.
```

## Catch in Ancestor

```dart
// In RecordSection or JournalScreen:
NotificationListener<NavigateUpNotification>(
  onNotification: (notification) {
    _handleNavigateUp();
    return true;   // true = stop bubbling (I handled it)
    //     ^^^^
    // return false to let it continue bubbling to higher ancestors
  },
  child: /* subtree containing the dispatching widget */,
)
```

`NotificationListener` is generic — `<NavigateUpNotification>` means it only catches that specific type. Other notifications pass through.

> See: https://api.flutter.dev/flutter/widgets/NotificationListener-class.html

## return true vs false

```dart
onNotification: (notification) {
  _handleIt();
  return true;   // STOP — no ancestor sees this notification
  return false;  // CONTINUE — ancestors can also catch it
}
```

Use `false` for logging/analytics where multiple listeners need to see the event.

## When to Use Each Pattern

```
Child → Ancestor (upward):  Notification
Parent → Child (downward):  Constructor params, or GlobalKey.currentState
Sibling → Sibling:          Lift state to common ancestor, or use Notification
Distant widgets:            InheritedWidget / Provider (not covered here)
```

## Exercise

1. **`lib/notifications/navigation_notifications.dart`** — `NavigateUpNotification`, `NavigateDownNotification`
2. Dispatch from record widgets on arrow key press
3. Catch in `RecordSection` — navigate within section or call `onNavigateUp`
4. Catch in `JournalScreen` — use GlobalKey to jump to adjacent day's section

## Next

**[Step 9: Search →](09-search.md)** — Build the search screen with text and date filtering.
