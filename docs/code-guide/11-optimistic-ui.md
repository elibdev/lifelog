# Understanding Optimistic UI with Debouncing

**Files:**
- [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 300-350)
- [`lib/utils/debouncer.dart`](/home/user/lifelog/lib/utils/debouncer.dart)

This guide explains the optimistic UI pattern with per-record debouncing - a sophisticated approach to making the UI feel instant while reducing disk writes.

## What You'll Learn

- What is optimistic UI?
- Why debounce writes?
- Per-record vs global debouncing
- How the Debouncer class works
- Trade-offs and edge cases

## The Problem

Traditional CRUD apps work like this:

```dart
// User types → wait for database → update UI

void onTextChanged(String text) {
  // 1. Save to database (slow! 10-50ms)
  await database.update(record.copyWith(content: text));

  // 2. Update UI
  setState(() {
    _record = _record.copyWith(content: text);
  });
}
```

**Problems:**
- ❌ UI freezes while waiting for database
- ❌ Typing feels laggy (10-50ms delay per keystroke)
- ❌ Every keystroke writes to disk (wear on SSD)
- ❌ Battery drain (constant disk I/O)

## The Solution: Optimistic UI

**Optimistic UI** means: Update the UI immediately, save to disk later.

```dart
// User types → update UI instantly → later save to database

void onTextChanged(String text) {
  // 1. Update UI FIRST (instant!)
  setState(() {
    _record = _record.copyWith(content: text);
  });

  // 2. Save to database LATER (debounced)
  _debouncer.call(() async {
    await database.update(_record);
  });
}
```

**Benefits:**
- ✅ UI feels instant (no waiting)
- ✅ Reduced disk writes (debouncing)
- ✅ Better battery life
- ✅ Less database locking

**Trade-off:**
- ⚠️ Data is in UI before it's in database
- ⚠️ If app crashes before save, data is lost
- ⚠️ Must handle save failures

## Debouncing Explained

**Debouncing** means: Wait for user to stop typing before saving.

```
User types: H e l l o

Without debouncing:
H → save "H"
He → save "He"
Hel → save "Hel"
Hell → save "Hell"
Hello → save "Hello"
Total: 5 saves

With 500ms debouncing:
H → start timer (500ms)
He → reset timer (500ms)
Hel → reset timer (500ms)
Hell → reset timer (500ms)
Hello → reset timer (500ms)
[User stops typing]
... 500ms passes ...
→ save "Hello" (once!)
Total: 1 save
```

**Result:** Instead of 5 saves, we do 1 save.

## The Debouncer Class

**File:** [`lib/utils/debouncer.dart`](/home/user/lifelog/lib/utils/debouncer.dart)

```dart
import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  // Call this method repeatedly - it will only execute
  // the function after 'delay' has passed without new calls
  void call(void Function() action) {
    // Cancel previous timer if it exists
    _timer?.cancel();

    // Start new timer
    _timer = Timer(delay, action);
  }

  // Cancel pending action
  void cancel() {
    _timer?.cancel();
  }
}
```

**How it works:**

```dart
final debouncer = Debouncer(delay: Duration(milliseconds: 500));

// Call 1
debouncer.call(() => print('Hello'));
// → Starts 500ms timer

// Call 2 (after 100ms)
debouncer.call(() => print('World'));
// → Cancels previous timer
// → Starts new 500ms timer

// Call 3 (after 200ms)
debouncer.call(() => print('!!!'));
// → Cancels previous timer
// → Starts new 500ms timer

// ... user stops calling ...
// ... 500ms passes ...
// → Executes: print('!!!')

// Result: Only the last call executes!
```

## Per-Record Debouncing in JournalScreen

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 300-330)

The key insight: **Each record has its own debouncer**

```dart
class _JournalScreenState extends State<JournalScreen> {
  // Map of record ID → Debouncer
  final Map<String, Debouncer> _debouncers = {};

  void _saveRecord(Record record) {
    // 1. Update UI immediately (optimistic!)
    setState(() {
      final records = _recordsByDate[record.date] ?? [];
      final index = records.indexWhere((r) => r.id == record.id);

      if (index >= 0) {
        records[index] = record.copyWith(updatedAt: DateTime.now());
      } else {
        records.add(record);
      }

      _recordsByDate[record.date] = records;
    });

    // 2. Get or create debouncer for THIS record
    _debouncers.putIfAbsent(
      record.id,
      () => Debouncer(delay: const Duration(milliseconds: 500)),
    );

    // 3. Schedule save (will be debounced)
    _debouncers[record.id]?.call(() async {
      await _repository.updateRecord(record);
    });
  }
}
```

## Why Per-Record Debouncing?

**Alternative 1: Global Debouncer (❌ Bad)**

```dart
final _globalDebouncer = Debouncer(delay: Duration(milliseconds: 500));

void _saveRecord(Record record) {
  setState(() { /* update UI */ });

  // All records share one debouncer
  _globalDebouncer.call(() async {
    await _repository.updateRecord(record);
  });
}
```

**Problem:**
```
User types in Record A:  H e l l o
  → Global timer started

User switches to Record B and types:  W o r l d
  → Global timer restarted
  → Record A's "Hello" is lost! Never saved!

After 500ms:
  → Only "World" from Record B is saved
  → "Hello" from Record A was never saved!
```

**Alternative 2: Per-Record Debouncer (✅ Good)**

```dart
final Map<String, Debouncer> _debouncers = {};  // One per record

void _saveRecord(Record record) {
  setState(() { /* update UI */ });

  // Each record has its own debouncer
  _debouncers[record.id]?.call(() async {
    await _repository.updateRecord(record);
  });
}
```

**Better:**
```
User types in Record A:  H e l l o
  → Record A's timer started

User switches to Record B and types:  W o r l d
  → Record B's timer started (separate!)
  → Record A's timer still running

After 500ms:
  → Record A saves "Hello"
  → Record B saves "World"
  → Both saved correctly!
```

## The Complete Flow

Let's trace a keystroke through the system:

```
1. User types "H" in Record ABC-123
   ↓
2. RecordWidget calls onSave callback
   ↓
3. JournalScreen._saveRecord() is called
   ↓
4. setState(() {
     // Update _recordsByDate immediately
     _recordsByDate[date][index] = record.copyWith(content: "H")
   })
   ↓
5. UI rebuilds immediately (user sees "H" instantly)
   ↓
6. Get debouncer for "ABC-123"
   _debouncers["ABC-123"] = Debouncer(...)
   ↓
7. Schedule save:
   _debouncers["ABC-123"].call(() {
     await _repository.updateRecord(record)
   })
   ↓
8. Debouncer starts 500ms timer
   ↓
9. User types "e" (within 500ms)
   → Steps 2-8 repeat
   → Debouncer CANCELS previous timer
   → Debouncer starts NEW 500ms timer
   ↓
10. User types "l" "l" "o"
   → Steps 2-8 repeat for each keystroke
   → Each time cancels and restarts timer
   ↓
11. User stops typing
   ↓
12. 500ms passes with no new keystrokes
   ↓
13. Timer fires → execute save function
   ↓
14. _repository.updateRecord(record) runs
   ↓
15. Database updated with "Hello"
```

**Total time for user:** Instant (step 5)
**Total saves to database:** 1 (step 14)

## Edge Cases and Trade-offs

### Edge Case 1: App Closed Before Save

```
User types "Hello"
  → UI shows "Hello" (optimistic)
  → Debouncer starts 500ms timer
  → User closes app after 200ms
  → Timer never fires
  → "Hello" is lost!
```

**Mitigation:**
- Save in `dispose()` method
- Reduce debounce delay for critical data
- Show "unsaved changes" indicator

**In this app:**
```dart
@override
void dispose() {
  // Trigger all pending saves immediately
  for (var debouncer in _debouncers.values) {
    debouncer.cancel();  // Cancel timers
  }

  // Could add: Save all dirty records here
  // _repository.batchUpdate(_getDirtyRecords());

  super.dispose();
}
```

### Edge Case 2: Database Write Fails

```
User types "Hello"
  → UI shows "Hello"
  → Save to database fails (disk full, permission error)
  → User thinks it's saved, but it's not!
```

**Mitigation:**
```dart
_debouncers[record.id]?.call(() async {
  try {
    await _repository.updateRecord(record);
  } catch (e) {
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save: $e')),
    );

    // Optionally: Retry
    await Future.delayed(Duration(seconds: 2));
    await _repository.updateRecord(record);
  }
});
```

### Edge Case 3: Concurrent Edits

```
User has app open on phone AND computer

Phone: Types "Hello"
  → Phone's UI: "Hello"
  → Phone's debouncer: waiting...

Computer: Types "World"
  → Computer's UI: "World"
  → Computer's debouncer: waiting...

After 500ms:
  → Phone saves "Hello" to database
  → Computer saves "World" to database
  → Last write wins! "World" overwrites "Hello"
```

**This is why event sourcing matters!** See [Understanding Event Sourcing](02-event-sourcing.md).

### Edge Case 4: Memory Leaks

```dart
// Potential leak: Debouncers never cleaned up
void _saveRecord(Record record) {
  _debouncers[record.id] = Debouncer(...);  // Keeps growing!
}

// After 10,000 records:
// _debouncers has 10,000 entries!
```

**Mitigation:**
```dart
// Remove debouncer after save completes
_debouncers[record.id]?.call(() async {
  await _repository.updateRecord(record);

  // Clean up
  _debouncers.remove(record.id);
});
```

## Tuning the Delay

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (line 310)

```dart
Debouncer(delay: const Duration(milliseconds: 500))
```

**Too short (100ms):**
- ✅ Less data loss risk
- ✅ Faster sync to database
- ❌ More disk writes
- ❌ More battery drain
- ❌ Might save while user is still typing

**Too long (2000ms):**
- ✅ Fewer disk writes
- ✅ Better battery
- ❌ Higher data loss risk
- ❌ Longer delay before sync
- ❌ Feels less "saved"

**Sweet spot (500ms):**
- ✅ Balances all concerns
- ✅ Most users pause > 500ms between thoughts
- ✅ Battery friendly
- ✅ Responsive enough

## Comparison: Different Patterns

### 1. No Debouncing (Immediate Save)

```dart
void onTextChanged(String text) {
  await database.update(text);
  setState(() => _text = text);
}
```
- Typing: Laggy (10-50ms per keystroke)
- Disk writes: Excessive (one per keystroke)
- Data loss: None
- Complexity: Low

### 2. Global Debouncing

```dart
final globalDebouncer = Debouncer(delay: 500ms);

void onTextChanged(String text) {
  setState(() => _text = text);
  globalDebouncer.call(() => database.update(text));
}
```
- Typing: Instant
- Disk writes: Reduced
- Data loss: High (records interfere with each other)
- Complexity: Low

### 3. Per-Record Debouncing (This App)

```dart
final Map<String, Debouncer> debouncers = {};

void onTextChanged(String text) {
  setState(() => _text = text);
  debouncers[recordId].call(() => database.update(text));
}
```
- Typing: Instant
- Disk writes: Minimal
- Data loss: Low (only if app crashes)
- Complexity: Medium

### 4. Throttling (Different from Debouncing)

```dart
// Save at most once every 500ms, regardless of typing

void onTextChanged(String text) {
  setState(() => _text = text);

  if (_canSave()) {  // Check if 500ms passed
    database.update(text);
    _lastSaveTime = now;
  }
}
```
- Typing: Instant
- Disk writes: Regular interval
- Data loss: Higher (misses edits between saves)
- Complexity: Medium

**This app uses #3: Per-record debouncing** - best balance for this use case.

## Visualizing Debounce vs Throttle

```
Keystrokes: H.e.l.l.o....w.o.r.l.d....!

Debouncing (wait for pause):
H.e.l.l.o....w.o.r.l.d....!
         ↑Save            ↑Save
Saves: "o" (after pause), "!" (after pause)

Throttling (regular interval):
H.e.l.l.o....w.o.r.l.d....!
    ↑Save    ↑Save    ↑Save
Saves: "l" (500ms), "o" (1000ms), "d" (1500ms)

This app uses debouncing!
```

## Key Takeaways

1. **Optimistic UI** updates instantly, saves later
2. **Debouncing** reduces disk writes by waiting for pauses
3. **Per-record** debouncing prevents records from interfering
4. **Trade-off:** Instant UI vs risk of data loss
5. **500ms** is a good balance for typing
6. **Clean up** debouncers to prevent memory leaks

## Questions to Check Understanding

1. What's the difference between optimistic UI and traditional save-then-update?
2. Why does this app use one debouncer per record instead of a global debouncer?
3. What happens if the app crashes before the debouncer fires?
4. What's the difference between debouncing and throttling?
5. Why 500ms instead of 100ms or 2000ms?

## Next Steps

- **[Understanding JournalScreen](06-journal-screen.md)** - See how it all fits together
- **[Understanding Event Sourcing](02-event-sourcing.md)** - How to handle concurrent edits
- **[Understanding the Database Layer](03-database-layer.md)** - What happens when we save

---

**Ask me:** "Walk me through the debouncer.dart implementation" or "Show me all the places debouncing is used"!
