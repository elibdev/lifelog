# Understanding the Notification Pattern

**Files:**
- [`lib/notifications/navigation_notifications.dart`](/home/user/lifelog/lib/notifications/navigation_notifications.dart) (30 lines)
- Used in: [`lib/widgets/record_widget.dart`](/home/user/lifelog/lib/widgets/record_widget.dart)
- Listened in: [`lib/widgets/record_section.dart`](/home/user/lifelog/lib/widgets/record_section.dart)

This guide explains one of the most advanced patterns in this codebase: **custom notification bubbling**.

## What You'll Learn

- What notifications are in Flutter
- How to create custom notifications
- Why notifications instead of callbacks
- How notifications bubble up the widget tree
- When to use this pattern

## The Problem This Solves

When a deeply nested widget needs to communicate with an ancestor, you have three options:

### Option 1: Callbacks (The Traditional Way)

```dart
// Grandparent
class JournalScreen extends StatefulWidget {
  Widget build() {
    return RecordSection(
      onNavigateUp: () => _handleNavigateUp(),  // Pass callback down
    );
  }
}

// Parent
class RecordSection extends StatefulWidget {
  final VoidCallback onNavigateUp;

  Widget build() {
    return RecordWidget(
      onNavigateUp: widget.onNavigateUp,  // Pass it down again
    );
  }
}

// Child
class RecordWidget extends StatefulWidget {
  final VoidCallback onNavigateUp;

  void _handleArrowUp() {
    widget.onNavigateUp();  // Finally call it!
  }
}
```

**Problems:**
- ❌ **Prop drilling** - Must pass callback through every level
- ❌ **Tight coupling** - RecordSection knows about JournalScreen's concerns
- ❌ **Not scalable** - Adding new events requires changing every layer

### Option 2: GlobalKey (Direct Access)

```dart
// Access child state directly
final key = GlobalKey<RecordWidgetState>();

key.currentState?.doSomething();
```

**Problems:**
- ❌ **Bypasses Flutter's architecture** - Direct state mutation
- ❌ **Hard to test** - Tight coupling to specific widgets
- ❌ **Fragile** - Breaks if widget tree changes

### Option 3: Notifications (The Flutter Way)

```dart
// Child dispatches notification
NavigateUpNotification().dispatch(context);

// Ancestor listens
NotificationListener<NavigateUpNotification>(
  onNotification: (notification) {
    _handleNavigateUp();
    return true;  // Stop bubbling
  },
  child: RecordWidget(...),
)
```

**Benefits:**
- ✅ **Decoupled** - Child doesn't know who's listening
- ✅ **No prop drilling** - Bubbles up automatically
- ✅ **Flexible** - Ancestors can choose to listen or ignore
- ✅ **Composable** - Multiple listeners can respond

## How Notifications Work in Flutter

Flutter has a built-in notification system used throughout the framework:

```dart
// ScrollNotification - built into Flutter
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    print('User scrolled to: ${notification.metrics.pixels}');
    return false;  // Let it bubble up
  },
  child: ListView(...),
)
```

Your app uses this same pattern for navigation!

## The Custom Navigation Notifications

**File:** [`lib/notifications/navigation_notifications.dart`](/home/user/lifelog/lib/notifications/navigation_notifications.dart)

```dart
import 'package:flutter/material.dart';

// Notification for navigating up (arrow up key)
class NavigateUpNotification extends Notification {
  const NavigateUpNotification();
}

// Notification for navigating down (arrow down key)
class NavigateDownNotification extends Notification {
  const NavigateDownNotification();
}
```

**That's it!** Just extend `Notification` and you have custom events.

## How It's Used in RecordWidget

**File:** [`lib/widgets/record_widget.dart`](/home/user/lifelog/lib/widgets/record_widget.dart) (lines 180-220)

When user presses arrow keys:

```dart
class _RecordWidgetState extends State<RecordWidget> {
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          // Arrow up pressed
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            // Dispatch notification - it will bubble up!
            NavigateUpNotification().dispatch(context);
            return KeyEventResult.handled;
          }

          // Arrow down pressed
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            NavigateDownNotification().dispatch(context);
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: TextField(...),
    );
  }
}
```

**What happens when you call `.dispatch(context)`:**

1. Flutter looks at the context (widget's position in tree)
2. Walks up the widget tree
3. Checks each ancestor for `NotificationListener<NavigateUpNotification>`
4. Calls `onNotification` on any listeners it finds
5. Stops if a listener returns `true`, continues if `false`

## How It's Caught in RecordSection

**File:** [`lib/widgets/record_section.dart`](/home/user/lifelog/lib/widgets/record_section.dart) (lines 120-160)

RecordSection wraps its content in NotificationListeners:

```dart
class _RecordSectionState extends State<RecordSection> {
  Widget build(BuildContext context) {
    return NotificationListener<NavigateUpNotification>(
      onNotification: (notification) {
        // A RecordWidget below us dispatched NavigateUpNotification
        _handleNavigateUp();
        return true;  // Stop bubbling (don't let it reach JournalScreen)
      },
      child: NotificationListener<NavigateDownNotification>(
        onNotification: (notification) {
          _handleNavigateDown();
          return true;
        },
        child: Column(
          children: [
            // RecordWidgets that will dispatch notifications
            ...records.map((record) => RecordWidget(record: record)),
          ],
        ),
      ),
    );
  }

  void _handleNavigateUp() {
    // Try to focus previous record in this section
    final currentIndex = _getCurrentFocusedIndex();

    if (currentIndex > 0) {
      // There's a record above in this section
      _focusRecordAt(currentIndex - 1);
    } else {
      // No record above - let JournalScreen handle it
      widget.onNavigateUp();  // Callback to parent
    }
  }
}
```

**The logic:**
1. Notification bubbles up from RecordWidget
2. RecordSection catches it
3. If it can handle navigation within section → handles it, returns `true` (stop)
4. If it needs to navigate to another section → calls callback, returns `true`

## The Bubbling Process Visualized

```
Widget Tree:

┌─────────────────────────────────────┐
│ JournalScreen                       │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ RecordSection                   │ │
│ │ (NotificationListener)          │ │
│ │                                 │ │
│ │ ┌─────────────────────────────┐ │ │
│ │ │ RecordWidget (Record 1)     │ │ │
│ │ └─────────────────────────────┘ │ │
│ │                                 │ │
│ │ ┌─────────────────────────────┐ │ │
│ │ │ RecordWidget (Record 2)     │ │ │
│ │ │ ← User presses arrow up     │ │ │
│ │ │   NavigateUp.dispatch()     │ │ │
│ │ └───────────┬─────────────────┘ │ │
│ │             ↑ Bubbles up        │ │
│ │             │                   │ │
│ │ ┌─────────────────────────────┐ │ │
│ │ │ RecordWidget (Record 3)     │ │ │
│ │ └─────────────────────────────┘ │ │
│ │                                 │ │
│ │ ← NotificationListener catches │ │
│ │   Handles navigation            │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

## Notification with Data

You can pass data in notifications:

```dart
// Define notification with data
class RecordSelectedNotification extends Notification {
  final String recordId;
  final Record record;

  const RecordSelectedNotification({
    required this.recordId,
    required this.record,
  });
}

// Dispatch with data
RecordSelectedNotification(
  recordId: record.id,
  record: record,
).dispatch(context);

// Listen and access data
NotificationListener<RecordSelectedNotification>(
  onNotification: (notification) {
    print('Selected record: ${notification.record.content}');
    return true;
  },
  child: ...,
)
```

## Returning true vs false

**File:** [`lib/widgets/record_section.dart`](/home/user/lifelog/lib/widgets/record_section.dart) (lines 130-145)

```dart
NotificationListener<NavigateUpNotification>(
  onNotification: (notification) {
    _handleNavigateUp();
    return true;  // What does this do?
  },
  child: ...,
)
```

**return true** - "I handled this, stop bubbling"
- Notification stops at this listener
- No ancestor listeners will see it
- Use when you fully handled the event

**return false** - "I saw this, but keep bubbling"
- Notification continues up the tree
- Other listeners can also respond
- Use for logging, analytics, etc.

**Example with false:**

```dart
// Analytics listener
NotificationListener<NavigateUpNotification>(
  onNotification: (notification) {
    analytics.logEvent('navigation_up');
    return false;  // Let it continue to actual handler
  },
  child: NotificationListener<NavigateUpNotification>(
    onNotification: (notification) {
      _actuallyNavigate();
      return true;  // Now stop it
    },
    child: ...,
  ),
)
```

## When to Use Notifications

**✅ Use notifications when:**
- Child needs to communicate with distant ancestor
- Multiple ancestors might want to listen
- You want loose coupling
- Event should "bubble up" through layers
- You're building a reusable widget library

**❌ Use callbacks when:**
- Direct parent-child communication
- Only one listener ever needed
- Tight coupling is okay
- Performance critical (notifications have tiny overhead)

**❌ Use GlobalKey when:**
- You need to call methods on specific widget instances
- Bottom-up communication (parent → child)
- Managing focus (FocusNode with GlobalKey)

## Comparison: All Three Approaches

**Scenario:** User presses arrow up in a deeply nested widget

### With Callbacks (Prop Drilling)

```dart
class GrandParent extends StatefulWidget {
  Widget build() => Parent(onUp: _handleUp);
  void _handleUp() { /* handle */ }
}

class Parent extends StatefulWidget {
  final VoidCallback onUp;
  Widget build() => Child(onUp: widget.onUp);  // Pass through
}

class Child extends StatefulWidget {
  final VoidCallback onUp;
  void _onKey() => widget.onUp();  // Call it
}
```

### With Notifications (Bubbling)

```dart
class GrandParent extends StatefulWidget {
  Widget build() {
    return NotificationListener<NavigateUpNotification>(
      onNotification: (_) { _handleUp(); return true; },
      child: Parent(),  // No props needed!
    );
  }
}

class Parent extends StatefulWidget {
  Widget build() => Child();  // Just passes children
}

class Child extends StatefulWidget {
  void _onKey() => NavigateUpNotification().dispatch(context);
}
```

### With GlobalKey (Direct Access)

```dart
class GrandParent extends StatefulWidget {
  final key = GlobalKey<ChildState>();

  Widget build() => Parent(childKey: key);

  void someMethod() {
    key.currentState?.doSomething();  // Direct call
  }
}
```

## Built-in Flutter Notifications

Flutter uses this pattern extensively:

```dart
// ScrollNotification - scrolling events
NotificationListener<ScrollNotification>()

// OverscrollNotification - scroll past edge
NotificationListener<OverscrollNotification>()

// SizeChangedLayoutNotification - widget size changed
NotificationListener<SizeChangedLayoutNotification>()

// KeepAliveNotification - AutomaticKeepAlive
NotificationListener<KeepAliveNotification>()
```

You can listen to these in your app!

## Building Your Own Notifications

Let's say you want to add a "record long-pressed" event:

**Step 1: Define notification**

```dart
class RecordLongPressedNotification extends Notification {
  final String recordId;
  final Offset position;

  const RecordLongPressedNotification({
    required this.recordId,
    required this.position,
  });
}
```

**Step 2: Dispatch from child**

```dart
// In RecordWidget
GestureDetector(
  onLongPress: () {
    RecordLongPressedNotification(
      recordId: widget.record.id,
      position: /* tap position */,
    ).dispatch(context);
  },
  child: ...,
)
```

**Step 3: Listen in ancestor**

```dart
// In JournalScreen or RecordSection
NotificationListener<RecordLongPressedNotification>(
  onNotification: (notification) {
    _showContextMenu(
      recordId: notification.recordId,
      position: notification.position,
    );
    return true;
  },
  child: ...,
)
```

Done! No callbacks needed.

## Performance Considerations

**Are notifications slower than callbacks?**

Slightly, but negligible:

- Callbacks: Direct function call (~1 nanosecond)
- Notifications: Walk widget tree (~100 nanoseconds)

For UI events (user input), this difference is unmeasurable.

**When to worry:**
- ❌ Don't use for high-frequency events (mouse move, scroll)
- ✅ Perfect for user actions (taps, key presses)
- ✅ Perfect for state changes (expand/collapse)

## Key Takeaways

1. **Notifications bubble up** the widget tree automatically
2. **No prop drilling** - child doesn't know who's listening
3. **return true** stops bubbling, **return false** continues
4. **Pass data** in notification constructor
5. **Use for loose coupling** between distant widgets
6. **Built into Flutter** - ScrollNotification, etc.

## Questions to Check Understanding

1. What happens when you call `.dispatch(context)` on a notification?
2. What's the difference between returning `true` vs `false` from `onNotification`?
3. Why use notifications instead of callbacks for navigation in this app?
4. How would you pass additional data in a notification?
5. When should you use callbacks instead of notifications?

## Next Steps

- **[Understanding RecordWidget](08-record-widget.md)** - See how notifications are dispatched
- **[Understanding RecordSection](07-record-section.md)** - See how notifications are caught
- **[Understanding Focus Management](10-focus-management.md)** - How navigation actually works

---

**Ask me:** "Walk me through navigation_notifications.dart and show me all the places it's used" for a complete tour!
