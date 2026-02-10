# Step 6: State & Persistence

**Goal:** Wire up optimistic UI with per-record debouncing so edits feel instant.

**Your file:** Updates to `lib/widgets/journal_screen.dart`, `lib/utils/debouncer.dart`
**Reference:** `reference/lib/widgets/journal_screen.dart`

## Optimistic UI

Traditional: user types → save to DB → update UI (laggy).
Optimistic: user types → update UI **immediately** → save to DB later (debounced).

```dart
void _saveRecord(Record record) {
  // 1. Update in-memory cache instantly
  setState(() {
    final records = _recordsByDate[record.date]!;
    final index = records.indexWhere((r) => r.id == record.id);
    records[index] = record.copyWith(updatedAt: DateTime.now());
  });

  // 2. Schedule disk write (debounced)
  _debouncers.putIfAbsent(
    record.id,
    () => Debouncer(delay: const Duration(milliseconds: 500)),
  );
  _debouncers[record.id]!.call(() => _repository.saveRecord(record));
}
```

`setState()` tells Flutter: "my state changed, please call `build()` again." Flutter then diffs the old and new widget trees and only updates what actually changed.

> See: https://api.flutter.dev/flutter/widgets/State/setState.html

## The Debouncer

```dart
import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;
  //     ^
  // Nullable — no timer running initially

  Debouncer({required this.delay});

  void call(void Function() action) {
    _timer?.cancel();              // Cancel previous timer (if any)
    _timer = Timer(delay, action); // Start new timer
  }

  void cancel() => _timer?.cancel();

  // ?. is the null-aware access operator
  // _timer?.cancel() means: if _timer is not null, call cancel()
  // Does nothing if _timer is null (no crash)
}
```

Typing "Hello" with 500ms debounce:
```
H → cancel previous, start 500ms timer
e → cancel previous, start 500ms timer
l → cancel previous, start 500ms timer
l → cancel previous, start 500ms timer
o → cancel previous, start 500ms timer
[pause]
... 500ms ...
→ save "Hello" (one write instead of five)
```

## Per-Record Debouncing

**Why one debouncer per record?**

```dart
final Map<String, Debouncer> _debouncers = {};
```

With a global debouncer: editing Record A, then switching to Record B, would cancel Record A's pending save. Per-record debouncing lets each record save independently.

```
Record A: type "Hello" → A's timer starts
Record B: type "World" → B's timer starts (A's still running!)
... 500ms from A's last edit → A saves "Hello"
... 500ms from B's last edit → B saves "World"
```

## FutureBuilder for Async Loading

```dart
Widget _buildDaySection(DateTime date) {
  return FutureBuilder<List<Record>>(
    future: _repository.getRecordsForDate(date),
    builder: (context, snapshot) {
      // snapshot.connectionState tells you where the Future is:
      //   .waiting → still loading
      //   .done    → complete (check .hasData or .hasError)

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox.shrink();  // Or a shimmer/skeleton
      }

      if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      }

      return DaySection(
        date: date,
        records: snapshot.data ?? [],
        onSave: _saveRecord,
      );
    },
  );
}
```

**Gotcha:** `FutureBuilder` rebuilds every time `build()` is called if you create the Future inline. Cache it:

```dart
// ❌ Creates new Future on every build → loads every time
FutureBuilder(future: _repository.getRecordsForDate(date), ...)

// ✅ Cache the Future
late final _recordsFuture = _repository.getRecordsForDate(date);
FutureBuilder(future: _recordsFuture, ...)  // Same Future, no re-fetch
```

Or use the `_recordsByDate` cache pattern from Step 5, which avoids FutureBuilder entirely.

> See: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html

## Cleanup in dispose()

```dart
@override
void dispose() {
  for (final debouncer in _debouncers.values) {
    debouncer.cancel();
  }
  super.dispose();
}
```

If you don't cancel timers in `dispose()`:
- Timers fire after the widget is gone → `setState()` on a disposed widget → crash
- Memory leak (timer holds reference to closure which holds reference to State)

> See: https://api.flutter.dev/flutter/widgets/State/dispose.html

## Exercise

1. **`lib/utils/debouncer.dart`** — The `Debouncer` class above
2. Update **`lib/widgets/journal_screen.dart`** with:
   - `_recordsByDate` cache
   - `_debouncers` map
   - `_saveRecord()` with optimistic update + debounced write
   - `dispose()` cleanup

## Next

**[Step 7: Focus & Keyboard →](07-focus-keyboard.md)** — Handle keyboard navigation between records.
