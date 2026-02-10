# Step 1: Flutter Basics

**Goal:** Understand the widget tree, how `build()` works, and how theming flows down.

**Your file:** `lib/main.dart` (already done)

## Key Concepts

### Everything is a Widget

Flutter UIs are trees of widgets. Each widget's `build()` method returns child widgets, forming a tree:

```
MaterialApp
  └─ Scaffold
       ├─ AppBar
       │    └─ Text('Lifelog')
       └─ body: Center
              └─ Text('Hello')
```

- **StatelessWidget** — Immutable. Output depends only on constructor args. Use when no internal state changes.
- **StatefulWidget** — Has mutable `State` object. Use when the widget needs to change over time (user input, async data, animations).

> See: https://api.flutter.dev/flutter/widgets/StatelessWidget-class.html

### The `const` Constructor

```dart
const LifelogApp({super.key});
//    ^^^^^
```

`const` constructors create compile-time constants. Flutter can skip rebuilding `const` widgets because it knows they never change. Use `const` wherever possible.

> See: https://dart.dev/language/constructors#constant-constructors

### `super.key`

```dart
const LifelogApp({super.key});
//                ^^^^^^^^^
```

Dart 3 shorthand for forwarding the `key` parameter to the parent class. Equivalent to the old:
```dart
const LifelogApp({Key? key}) : super(key: key);
```

Keys help Flutter identify which widgets changed during rebuilds. You'll use explicit keys later for `GlobalKey`.

> See: https://api.flutter.dev/flutter/foundation/Key-class.html

### ThemeData & ColorScheme

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  ),
)
```

`ColorScheme.fromSeed()` generates a full Material 3 color palette from a single seed color. The `brightness` parameter flips light/dark. `ThemeMode.system` follows the OS setting.

Any descendant widget can access theme colors via:
```dart
Theme.of(context).colorScheme.primary
```

`Theme.of(context)` walks up the widget tree to find the nearest `Theme` — this is the **InheritedWidget** pattern you'll see everywhere in Flutter.

> See: https://api.flutter.dev/flutter/material/ThemeData-class.html
> See: https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html

## Exercise

Your `lib/main.dart` is ready. Run `flutter run` and verify you see "Lifelog" centered on screen, with light/dark theme following your OS.

## Next

**[Step 2: Data Model →](02-data-model.md)** — Build the `Record` class that represents every journal entry.
