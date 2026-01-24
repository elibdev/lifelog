# Lesson 7: Creating Reusable Custom Widgets

**Difficulty:** Intermediate
**Estimated Time:** 2-3 hours
**Prerequisites:** Lessons 1-6 (Widget composition, const constructors)

## Learning Objectives

1. ✅ **Widget extraction** - Breaking down large widgets
2. ✅ **const constructors** - Performance optimization
3. ✅ **Composition over inheritance** - Flutter's widget philosophy
4. ✅ **Keys** - When and why to use them
5. ✅ **Callback patterns** - Passing functions to widgets

## What You're Building

Extract and refactor existing code into reusable widgets:
- **StatCard** - Reusable statistics card
- **EmptyState** - "No data" placeholder widget
- **SectionHeader** - Consistent section headers
- **LoadingOverlay** - Reusable loading indicator

This teaches you proper widget architecture!

## Why This Matters

Custom widgets:
- Make code DRY (Don't Repeat Yourself)
- Improve readability and maintainability
- Enable reuse across screens
- Simplify testing
- Improve performance with const

## Step 1: Extract StatCard Widget

You've already seen stat cards in StatisticsScreen. Let's make it reusable!

**File:** `/home/user/lifelog/lib/widgets/common/stat_card.dart` (new file)

```dart
import 'package:flutter/material.dart';

// Reusable statistics card widget
// Uses const constructor for performance
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),

            // Optional trailing icon if tappable
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );

    // Wrap in InkWell if tappable
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}
```

Now use it in StatisticsScreen:

```dart
// Before (in StatisticsScreen):
_buildStatCard(
  title: 'Total Records',
  value: _totalRecords.toString(),
  icon: Icons.article,
  color: Colors.blue,
)

// After:
StatCard(
  title: 'Total Records',
  value: _totalRecords.toString(),
  icon: Icons.article,
  color: Colors.blue,
)
```

## Step 2: Create EmptyState Widget

**File:** `/home/user/lifelog/lib/widgets/common/empty_state.dart`

```dart
import 'package:flutter/material.dart';

// Reusable empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Usage:
// EmptyState(
//   icon: Icons.article_outlined,
//   title: 'No records yet',
//   message: 'Start writing your first journal entry!',
//   actionLabel: 'Add Entry',
//   onAction: () => ...,
// )
```

## Step 3: Create SectionHeader Widget

**File:** `/home/user/lifelog/lib/widgets/common/section_header.dart`

```dart
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({
    Key? key,
    required this.title,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// Usage:
// SectionHeader(
//   title: 'General',
//   trailing: TextButton(
//     onPressed: () {},
//     child: Text('Edit'),
//   ),
// )
```

## Step 4: Create LoadingOverlay Widget

**File:** `/home/user/lifelog/lib/widgets/common/loading_overlay.dart`

```dart
import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget child;

  const LoadingOverlay({
    Key? key,
    required this.isLoading,
    this.message,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(message!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Usage:
// LoadingOverlay(
//   isLoading: _isExporting,
//   message: 'Exporting data...',
//   child: YourMainContent(),
// )
```

## Step 5: Use These Widgets Throughout the App

Update existing screens to use these widgets:

**SettingsScreen:**
```dart
// Replace Padding with SectionHeader
SectionHeader(title: 'General'),
// ...settings items...

SectionHeader(title: 'Appearance'),
// ...appearance items...
```

**ExportScreen:**
```dart
LoadingOverlay(
  isLoading: _isExporting,
  message: 'Exporting...',
  child: /* your export UI */,
)
```

## Key Concepts

### 1. When to Extract a Widget

Extract when:
- ✅ Widget appears multiple times
- ✅ Widget is logically distinct
- ✅ Widget exceeds ~100 lines
- ✅ You want to test it separately
- ✅ You want to use const optimization

Don't extract:
- ❌ Simple one-off UI
- ❌ Tightly coupled to parent state
- ❌ Just to reduce line count

### 2. const Constructors

```dart
// Define const constructor
class MyWidget extends StatelessWidget {
  final String title;

  const MyWidget({
    Key? key,
    required this.title,
  }) : super(key: key);
}

// Use const when possible
const MyWidget(title: 'Hello'); // ✅ Doesn't rebuild if parent rebuilds

MyWidget(title: _dynamicValue); // Can't use const with dynamic values
```

**Benefits of const:**
- Widget is compiled once
- Never rebuilds unnecessarily
- Better performance
- Less memory

### 3. Widget Keys

Keys tell Flutter which widgets are which:

```dart
// When to use keys:
// 1. List items that can reorder
ListView(
  children: items.map((item) =>
    ListTile(
      key: ValueKey(item.id), // ✅ Use key
      title: Text(item.name),
    ),
  ).toList(),
)

// 2. StatefulWidgets that preserve state
TextField(
  key: ValueKey('email'), // Preserve state when rebuilt
)

// 3. Multiple widgets of same type switching
_showA ? WidgetA(key: ValueKey('a')) : WidgetB(key: ValueKey('b'))

// Types of keys:
// - ValueKey(value) - Based on value
// - ObjectKey(object) - Based on object
// - UniqueKey() - Always unique
// - GlobalKey() - Access widget state from anywhere (use sparingly!)
```

### 4. Callback Patterns

```dart
// Simple callback
typedef VoidCallback = void Function();
final VoidCallback? onTap;

// Callback with value
typedef ValueChanged<T> = void Function(T value);
final ValueChanged<String>? onChanged;

// Multiple parameters
typedef OnSave = void Function(String id, String value);
final OnSave? onSave;

// Using callbacks
class MyWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const MyWidget({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Pass through
      child: Container(),
    );
  }
}
```

## Common Patterns

### Pattern 1: Builder Pattern

```dart
class MyCard extends StatelessWidget {
  final WidgetBuilder? builder;

  const MyCard({this.builder});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: builder?.call(context) ?? const SizedBox(),
    );
  }
}
```

### Pattern 2: Conditional Children

```dart
Column(
  children: [
    const Text('Always shown'),
    if (condition) const Text('Conditional'),
    ...items.map((i) => Text(i)), // Spread operator
  ],
)
```

## Testing Checklist

- [ ] Extracted widgets work identically to originals
- [ ] const constructors used where possible
- [ ] Widgets are reusable across screens
- [ ] No unnecessary rebuilds (use Flutter DevTools)
- [ ] Keys used appropriately for stateful widgets

## Challenges

**Challenge 1:** Create a reusable DateHeader widget
**Challenge 2:** Create a customizable AppBar widget
**Challenge 3:** Create a reusable form field widget
**Challenge 4:** Create a badge widget (for notifications)

## What You've Learned

- ✅ When and how to extract widgets
- ✅ const constructors for performance
- ✅ Proper use of Keys
- ✅ Callback patterns
- ✅ Widget composition best practices

---

**Previous:** [Lesson 6: Date Picker](lesson-06-date-picker.md)
**Next:** [Lesson 8: Advanced Keyboard Shortcuts](../03-advanced/lesson-08-keyboard-shortcuts.md)
