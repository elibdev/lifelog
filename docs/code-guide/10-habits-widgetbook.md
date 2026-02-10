# Step 10: Habits & Widgetbook

**Goal:** Build the habit record widget and set up Widgetbook for visual testing.

**Your files:** `lib/widgets/records/habit_record_widget.dart`, `widgetbook/main.dart`
**Reference:** `reference/lib/widgets/records/habit_record_widget.dart`, `reference/widgetbook/main.dart`

## Habit Records

Habits use append-only metadata for tracking completions:

```dart
// Habit metadata
{
  'habit.name': 'Exercise',
  'habit.frequency': 'daily',
  'habit.completions': ['2024-01-15', '2024-01-16', '2024-01-18'],
  'habit.archived': false,
}
```

### Why Append-Only Completions?

Instead of a counter (`completions: 3`), store each date:
- See **which** days you completed (not just how many)
- Calculate streaks (consecutive days)
- Render a calendar heatmap later
- Can't accidentally double-count (check if today's date exists)

### Streak Calculation

```dart
int get currentStreak {
  final completions = (metadata['habit.completions'] as List<dynamic>? ?? [])
      .map((s) => DateTime.parse(s as String))
      .toList()
    ..sort();  // Cascade: sort in-place and return the list
    //^^ .. is the cascade operator — calls sort() on the list
    //   then continues the expression with the same list

  if (completions.isEmpty) return 0;

  int streak = 0;
  var checkDate = DateTime.now();
  checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

  for (final date in completions.reversed) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == checkDate || normalized == checkDate.subtract(const Duration(days: 1))) {
      streak++;
      checkDate = normalized;
    } else {
      break;
    }
  }
  return streak;
}
```

> See: https://dart.dev/language/operators#cascade-notation

### Tap to Complete

```dart
void _toggleToday() {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final completions = List<String>.from(
    record.metadata['habit.completions'] as List? ?? [],
  );

  if (completions.contains(today)) {
    completions.remove(today);  // Undo today
  } else {
    completions.add(today);     // Complete today
  }

  onChanged(record.copyWithMetadata({
    'habit.completions': completions,
  }));
}
```

## Widgetbook

Widgetbook is a tool for developing and testing widgets in isolation — like Storybook for Flutter.

### Setup

`pubspec.yaml` dev_dependencies:
```yaml
dev_dependencies:
  widgetbook: ^3.10.0
```

### Creating Use Cases

```dart
// widgetbook/main.dart
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:lifelog/widgets/records/adaptive_record_widget.dart';
import 'package:lifelog/models/record.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Records',
          children: [
            WidgetbookComponent(
              name: 'AdaptiveRecordWidget',
              useCases: [
                WidgetbookUseCase(
                  name: 'Text Record',
                  builder: (context) => AdaptiveRecordWidget(
                    record: Record(
                      id: '1',
                      date: DateTime.now(),
                      type: RecordType.text,
                      content: context.knobs.string(
                        label: 'Content',
                        initialValue: 'Hello world',
                      ),
                      metadata: {},
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      orderPosition: 0,
                    ),
                    onChanged: (_) {},
                  ),
                ),

                WidgetbookUseCase(
                  name: 'Todo Record',
                  builder: (context) => AdaptiveRecordWidget(
                    record: Record(
                      id: '2',
                      date: DateTime.now(),
                      type: RecordType.todo,
                      content: 'Buy groceries',
                      metadata: {
                        'todo.checked': context.knobs.boolean(
                          label: 'Checked',
                          initialValue: false,
                        ),
                      },
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      orderPosition: 0,
                    ),
                    onChanged: (_) {},
                  ),
                ),

                // Add use cases for heading, bulletList, habit...
              ],
            ),
          ],
        ),
      ],
    );
  }
}
```

### Knobs

Knobs are interactive controls in the Widgetbook sidebar:

```dart
context.knobs.string(label: 'Content', initialValue: 'Hello')
context.knobs.boolean(label: 'Checked', initialValue: false)
context.knobs.double.slider(label: 'Font size', initialValue: 16, min: 12, max: 32)
context.knobs.list(label: 'Type', initialOption: RecordType.text, options: RecordType.values)
```

### Running Widgetbook

```bash
flutter run -t widgetbook/main.dart
```

The `-t` flag specifies a different entry point than `lib/main.dart`.

> See: https://pub.dev/packages/widgetbook

## Exercise

1. **`lib/widgets/records/habit_record_widget.dart`** — Streak display, tap-to-complete, completion count
2. **`widgetbook/main.dart`** — Use cases for all 5 record types with knobs

## You're Done!

You've built the full Lifelog app. Check the [CHANGELOG.md](../../CHANGELOG.md) for planned future features to tackle next.
