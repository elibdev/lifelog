# Step 4: Adaptive Record Widget

**Goal:** Build a widget that renders any `RecordType` by delegating to specialized sub-widgets.

**Your files:** `lib/widgets/records/adaptive_record_widget.dart` + sub-widgets
**Reference:** `reference/lib/widgets/records/`

## Architecture: Composition Over Inheritance

Each record type has its own widget, and they all compose a shared `RecordTextField`:

```
AdaptiveRecordWidget
  │
  ├─ switch (record.type)
  │    ├─ text       → TextRecordWidget
  │    ├─ heading    → HeadingRecordWidget
  │    ├─ todo       → TodoRecordWidget
  │    ├─ bulletList → BulletListRecordWidget
  │    └─ habit      → HabitRecordWidget
  │
  └─ Each sub-widget composes RecordTextField (shared editing behavior)
```

Why composition (HAS-A) instead of inheritance (IS-A)? In Flutter, widgets don't inherit UI from parent classes — the `build()` method constructs the tree from scratch. A `TodoRecordWidget` doesn't "extend" `TextRecordWidget`; it **contains** a `RecordTextField`.

## Exhaustive Switch

```dart
class AdaptiveRecordWidget extends StatelessWidget {
  final Record record;
  final ValueChanged<Record> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // Switch expression — Dart guarantees every RecordType is handled.
    // Add a new enum value → compiler error here until you add the case.
    return switch (record.type) {
      RecordType.text => TextRecordWidget(record: record, onChanged: onChanged),
      RecordType.heading => HeadingRecordWidget(record: record, onChanged: onChanged),
      RecordType.todo => TodoRecordWidget(record: record, onChanged: onChanged),
      RecordType.bulletList => BulletListRecordWidget(record: record, onChanged: onChanged),
      RecordType.habit => HabitRecordWidget(record: record, onChanged: onChanged),
    };
  }
}
```

This is a **StatelessWidget** — it has no internal state, just routes to the right sub-widget. The sub-widgets are StatefulWidgets because they manage `TextEditingController` and `FocusNode`.

> See: https://dart.dev/language/branches#switch-expressions

## Multi-Line Support: ConstrainedBox vs SizedBox

```dart
// ❌ SizedBox clips content to fixed height
SizedBox(height: 24, child: TextField(...))

// ✅ ConstrainedBox sets minimum height but grows with content
ConstrainedBox(
  constraints: const BoxConstraints(minHeight: 24),
  child: TextField(
    maxLines: null,   // null = unlimited lines
    // ...
  ),
)
```

`maxLines: null` tells TextField to grow vertically as the user types. `ConstrainedBox(minHeight)` ensures even empty fields maintain the grid baseline height.

> See: https://api.flutter.dev/flutter/widgets/ConstrainedBox-class.html

## RecordTextField: Shared Editing Behavior

Every record type needs a text field with:
- `TextEditingController` — Holds and manipulates text content
- `FocusNode` — Tracks whether this field has keyboard focus
- `onChanged` callback — Notifies parent when content changes
- Keyboard shortcut handling

Extract this into a reusable widget:

```dart
class RecordTextField extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onTextChanged;
  final TextStyle? style;
  final String? hintText;
  final FocusNode? focusNode;

  // ...
}

class _RecordTextFieldState extends State<RecordTextField> {
  late final TextEditingController _controller;
  //   ^^^^
  // 'late' means: I promise to initialize this before it's used.
  // Needed because we can't call widget.initialText in field initializer.

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();  // CRITICAL: prevents memory leak
    super.dispose();
  }

  // ...
}
```

### The `late` keyword

`late` defers initialization. Without it:
```dart
// ❌ Can't access widget.initialText here — widget isn't available yet
final _controller = TextEditingController(text: widget.initialText);

// ✅ Initialize in initState where widget IS available
late final TextEditingController _controller;

@override
void initState() {
  super.initState();
  _controller = TextEditingController(text: widget.initialText);
}
```

> See: https://dart.dev/language/variables#late-variables

### Widget Lifecycle

```
Constructor → createState() → initState() → build() → ... → dispose()
                                  ↑                              ↑
                          Create controllers,          Dispose controllers,
                          subscribe to streams          cancel timers
```

- `initState()` — Called once. Create controllers, start listeners.
- `build()` — Called every time `setState()` is called. Return the widget tree. Must be pure (no side effects).
- `didUpdateWidget(oldWidget)` — Called when parent rebuilds with new props. Compare old vs new to decide if you need to update internal state.
- `dispose()` — Called once. Clean up everything created in `initState()`.

> See: https://api.flutter.dev/flutter/widgets/State-class.html

## Sub-Widget Examples

### TextRecordWidget

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Padding(
      padding: EdgeInsets.only(top: 4, right: 8),
      child: Text('•'),  // Bullet character
    ),
    Expanded(child: RecordTextField(...)),
    // Expanded fills remaining horizontal space
  ],
)
```

### TodoRecordWidget

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Checkbox(
      value: record.isChecked,   // Uses the typed metadata getter
      onChanged: (checked) {
        onChanged(record.copyWithMetadata({'todo.checked': checked}));
      },
    ),
    Expanded(
      child: RecordTextField(
        style: record.isChecked
          ? const TextStyle(decoration: TextDecoration.lineThrough)
          : null,
        // ...
      ),
    ),
  ],
)
```

### HeadingRecordWidget

```dart
// Grid-aligned heights per heading level
final height = switch (record.headingLevel) {
  1 => 48.0,   // 2 × 24px grid
  2 => 36.0,   // 1.5 × 24px grid
  _ => 24.0,   // 1 × 24px grid (H3)
};

final fontSize = switch (record.headingLevel) {
  1 => 24.0,
  2 => 20.0,
  _ => 16.0,
};
```

## Exercise

Build in this order:

1. **`lib/widgets/records/record_text_field.dart`** — Shared text field with controller + focus
2. **`lib/widgets/records/text_record_widget.dart`** — Bullet + text (simplest)
3. **`lib/widgets/records/todo_record_widget.dart`** — Checkbox + strikethrough
4. **`lib/widgets/records/heading_record_widget.dart`** — Font sizes + grid heights
5. **`lib/widgets/records/bullet_list_record_widget.dart`** — Indent levels (•, ◦, ▪)
6. **`lib/widgets/records/adaptive_record_widget.dart`** — The router

Skip `HabitRecordWidget` for now (Step 10).

## Next

**[Step 5: Journal Screen & Scrolling →](05-scrolling-slivers.md)** — Put records on screen with infinite scroll.
