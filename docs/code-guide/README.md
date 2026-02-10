# Build Lifelog: A Hands-On Flutter Guide

Build a journaling app from scratch. Use `reference/` to peek when stuck, but write every line yourself in `lib/`.

## Build Order

Work through these in order. Each step builds on the previous.

### Phase 1: Foundation

- [ ] **[Step 1: Flutter Basics](01-flutter-basics.md)** — Widget tree, StatelessWidget, MaterialApp, theming
- [ ] **[Step 2: Data Model](02-data-model.md)** — Single `Record` class, `RecordType` enum, namespaced metadata, `copyWith`
- [ ] **[Step 3: SQLite Database](03-sqlite-database.md)** — sqlite3 FFI, isolates, schema, write queue, event sourcing

### Phase 2: Core UI

- [ ] **[Step 4: Adaptive Record Widget](04-adaptive-widget.md)** — Composition pattern, exhaustive switch, shared text field
- [ ] **[Step 5: Journal Screen & Scrolling](05-scrolling-slivers.md)** — CustomScrollView, SliverList, center anchor, infinite scroll
- [ ] **[Step 6: State & Persistence](06-state-management.md)** — setState, FutureBuilder, optimistic UI, per-record debouncing

### Phase 3: Interaction

- [ ] **[Step 7: Focus & Keyboard](07-focus-keyboard.md)** — FocusNode lifecycle, keyboard events, GlobalKey, cross-widget nav
- [ ] **[Step 8: Notifications](08-notifications.md)** — Custom Notification bubbling (NavigateUp/Down)
- [ ] **[Step 9: Search](09-search.md)** — Debounced search, LIKE queries, date-range picker

### Phase 4: Polish

- [ ] **[Step 10: Habits & Widgetbook](10-habits-widgetbook.md)** — Habit records, streak tracking, Widgetbook for visual testing

## How to Use This Guide

1. Read a step's guide
2. Write the code yourself in `lib/`
3. If stuck, peek at `reference/lib/` for the corresponding file
4. Ask Claude to explain any concept deeper

## Key Architecture Decisions

| Decision | Choice | Why |
|---|---|---|
| Record model | Single class + enum | Enables type switching via `copyWith(type: newType)` |
| Metadata keys | Namespaced (`todo.checked`) | No collision between types sharing same record |
| Sections per day | One mixed-type section | Simpler than separate todo/note sections |
| DB library | sqlite3 FFI (not sqflite) | Direct C binding, better performance |
| Concurrency | Isolates + write queue | Non-blocking UI, no DB locking |
| State persistence | Optimistic UI + debouncing | Instant feel, fewer writes |

## Reference File Map

```
Your code:          →  Reference to peek at:
lib/main.dart       →  (already done — your app entry point)
lib/models/         →  reference/lib/models/record.dart
lib/database/       →  reference/lib/database/
lib/widgets/        →  reference/lib/widgets/
lib/services/       →  reference/lib/services/keyboard_service.dart
```

## Flutter Doc Links (Bookmarks)

### Core Concepts
- [Widget catalog](https://docs.flutter.dev/ui/widgets)
- [StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [Widget lifecycle](https://api.flutter.dev/flutter/widgets/State-class.html)
- [BuildContext](https://api.flutter.dev/flutter/widgets/BuildContext-class.html)

### Layout & Scrolling
- [CustomScrollView](https://api.flutter.dev/flutter/widgets/CustomScrollView-class.html)
- [SliverList](https://api.flutter.dev/flutter/widgets/SliverList-class.html)
- [LayoutBuilder](https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html)
- [ConstrainedBox](https://api.flutter.dev/flutter/widgets/ConstrainedBox-class.html)

### Input & Focus
- [FocusNode](https://api.flutter.dev/flutter/widgets/FocusNode-class.html)
- [TextField](https://api.flutter.dev/flutter/material/TextField-class.html)
- [TextEditingController](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html)
- [KeyboardListener](https://api.flutter.dev/flutter/widgets/KeyboardListener-class.html)

### State & Communication
- [setState](https://api.flutter.dev/flutter/widgets/State/setState.html)
- [FutureBuilder](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html)
- [Notification](https://api.flutter.dev/flutter/widgets/Notification-class.html)
- [NotificationListener](https://api.flutter.dev/flutter/widgets/NotificationListener-class.html)
- [GlobalKey](https://api.flutter.dev/flutter/widgets/GlobalKey-class.html)

### Dart Language
- [Dart enums with members](https://dart.dev/language/enums)
- [Null safety](https://dart.dev/null-safety)
- [Patterns & switch expressions](https://dart.dev/language/patterns)
- [Extension methods](https://dart.dev/language/extension-methods)
- [Cascade notation (..)](https://dart.dev/language/operators#cascade-notation)
