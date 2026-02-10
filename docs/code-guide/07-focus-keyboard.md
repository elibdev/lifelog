# Step 7: Focus & Keyboard

**Goal:** Implement keyboard-first navigation between records using FocusNode and GlobalKey.

**Your files:** `lib/services/keyboard_service.dart`, updates to record widgets
**Reference:** `reference/lib/services/keyboard_service.dart`

## FocusNode Lifecycle

Every interactive widget (TextField, Button) has a `FocusNode` that tracks keyboard focus.

```dart
class _RecordTextFieldState extends State<RecordTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    // Use provided FocusNode or create own
  }

  @override
  void dispose() {
    // Only dispose if WE created it
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }
}
```

**Why the conditional dispose?** If the parent passed in a FocusNode, the parent owns its lifecycle. If we created it ourselves, we must clean it up.

> See: https://api.flutter.dev/flutter/widgets/FocusNode-class.html

## Requesting Focus

```dart
// Give focus to a specific node
_focusNode.requestFocus();

// Check if a node has focus
if (_focusNode.hasFocus) { ... }

// Listen to focus changes
_focusNode.addListener(() {
  if (_focusNode.hasFocus) {
    // This field just gained focus
  } else {
    // This field just lost focus
  }
});
```

## Keyboard Event Handling

Two approaches in Flutter:

### 1. KeyboardListener (simpler)

```dart
KeyboardListener(
  focusNode: _focusNode,
  onKeyEvent: (event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      // Handle arrow up
    }
  },
  child: TextField(...),
)
```

### 2. Focus with onKeyEvent (more control)

```dart
Focus(
  focusNode: _focusNode,
  onKeyEvent: (node, event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateUp();
        return KeyEventResult.handled;
        // 'handled' stops the event from propagating further
      }
    }
    return KeyEventResult.ignored;
    // 'ignored' lets the event propagate (e.g., to TextField for typing)
  },
  child: TextField(...),
)
```

**`KeyEventResult.handled` vs `.ignored`:**
- `handled` = "I consumed this event, don't let anything else process it"
- `ignored` = "Not my event, pass it along"

Regular typing (letters, numbers) should return `.ignored` so TextField can process them. Navigation keys (arrows) should return `.handled`.

> See: https://api.flutter.dev/flutter/widgets/Focus-class.html

## GlobalKey for Cross-Widget Navigation

When user presses arrow-up at the top of a RecordSection, focus needs to jump to the previous day's section. These widgets are far apart in the tree.

```dart
// JournalScreen holds keys for each day's section
final Map<DateTime, GlobalKey<RecordSectionState>> _sectionKeys = {};

GlobalKey<RecordSectionState> _getSectionKey(DateTime date) {
  return _sectionKeys.putIfAbsent(
    date,
    () => GlobalKey<RecordSectionState>(),
  );
}
```

`GlobalKey<RecordSectionState>` does two things:
1. Uniquely identifies a widget across the entire app
2. Provides access to the State object via `key.currentState`

```dart
// Navigate to previous day's last record
void _navigateUp(DateTime fromDate) {
  final previousDate = fromDate.subtract(const Duration(days: 1));
  final key = _getSectionKey(previousDate);

  // Access the section's State directly — no callbacks needed!
  key.currentState?.focusLastRecord();
}
```

The `?.` is critical — `currentState` is null if the widget isn't mounted (e.g., scrolled off screen).

> See: https://api.flutter.dev/flutter/widgets/GlobalKey-class.html

## RecordSection Focus Methods

```dart
class RecordSectionState extends State<RecordSection> {
  // List of FocusNodes, one per record
  final List<FocusNode> _focusNodes = [];

  // Called by JournalScreen via GlobalKey
  void focusFirstRecord() {
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
  }

  void focusLastRecord() {
    if (_focusNodes.isNotEmpty) {
      _focusNodes.last.requestFocus();
    }
  }

  // Called when a record's arrow-up can't go higher within this section
  void _handleNavigateUp(int currentIndex) {
    if (currentIndex > 0) {
      _focusNodes[currentIndex - 1].requestFocus();
    } else {
      // At top of section — tell JournalScreen to navigate to previous day
      widget.onNavigateUp?.call();
    }
  }
}
```

## Keyboard Shortcuts

Common shortcuts to implement:

| Key | Action |
|---|---|
| Arrow Up/Down | Move focus between records |
| Enter | Create new record below current |
| Backspace (empty) | Delete current record, focus previous |
| Ctrl+Enter | Toggle todo checkbox |
| Tab / Shift+Tab | Indent / outdent bullet list |

## Exercise

1. **`lib/services/keyboard_service.dart`** — Centralized keyboard shortcut definitions
2. Add focus handling to **`lib/widgets/records/record_text_field.dart`**
3. Add `focusFirstRecord()` / `focusLastRecord()` to **`lib/widgets/record_section.dart`**
4. Wire up GlobalKey navigation in **`lib/widgets/journal_screen.dart`**

Start with just arrow-up/down navigation. Add Enter and Backspace later.

## Next

**[Step 8: Notifications →](08-notifications.md)** — Decouple navigation with the Notification pattern.
