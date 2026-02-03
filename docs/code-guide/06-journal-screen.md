# Understanding JournalScreen

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (466 lines)

This guide walks you through the main screen of Lifelog - a complex infinite-scrolling journal with optimistic UI, debounced saves, and advanced focus management.

## What You'll Learn

- Infinite scrolling with CustomScrollView
- Lazy loading data as user scrolls
- Optimistic UI patterns
- Per-record debouncing
- GlobalKey registry for cross-widget communication
- Focus management at scale

## Overview

JournalScreen is the heart of the app. It manages:
- An infinite scrolling timeline (past and future dates)
- A cache of loaded records (`_recordsByDate`)
- Debounced saves for each record
- GlobalKey registry for arrow key navigation
- Responsive layout

**File structure:**
```dart
class JournalScreen extends StatefulWidget { }  // 20 lines

class _JournalScreenState extends State<JournalScreen> {
  // State variables
  // Helper methods
  // Build method
  // Navigation methods
}  // 446 lines
```

## State Variables

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 20-35)

```dart
class _JournalScreenState extends State<JournalScreen> {
  // 1. Records cache - Map of date to list of records for that date
  final Map<DateTime, List<Record>> _recordsByDate = {};

  // 2. Debouncers - One debouncer per record ID
  final Map<String, Debouncer> _debouncers = {};

  // 3. GlobalKey registry - For cross-section navigation
  final Map<String, GlobalKey<RecordSectionState>> _sectionKeys = {};

  // 4. Repository - Database access
  final RecordRepository _repository = RecordRepository();
}
```

### 1. _recordsByDate Cache

**Why a Map of DateTime → List<Record>?**

```dart
final Map<DateTime, List<Record>> _recordsByDate = {};

// Example data:
{
  DateTime(2024, 1, 15): [
    TodoRecord(content: 'Buy milk', ...),
    NoteRecord(content: 'Had a great meeting', ...),
  ],
  DateTime(2024, 1, 16): [
    TodoRecord(content: 'Call dentist', ...),
  ],
}
```

**Benefits:**
- ✅ Fast lookup by date: `_recordsByDate[date]`
- ✅ Lazy loading - only load dates as user scrolls
- ✅ Easy to update - just modify the list for that date
- ✅ Memory efficient - can unload distant dates (not implemented yet, see Lesson 11)

**Alternative approaches and why they weren't used:**
- ❌ Single flat list - Hard to group by date, slow to find date ranges
- ❌ Database query per scroll - Too slow, would cause jank
- ❌ Load everything upfront - Memory intensive for large journals

### 2. _debouncers Map

**Why one debouncer per record ID?**

```dart
final Map<String, Debouncer> _debouncers = {};

// When user types in a record:
_debouncers[record.id] = Debouncer(delay: Duration(milliseconds: 500));
_debouncers[record.id]?.call(() async {
  await _repository.updateRecord(record);
});
```

**This means:**
- User types in Record A → starts 500ms timer for Record A
- User types in Record B → starts separate 500ms timer for Record B
- Timer for Record A doesn't affect Record B!

**Why not a single global debouncer?**
- ❌ Global debouncer would delay ALL saves if ANY record is being edited
- ❌ Typing in Record A would prevent Record B from saving
- ✅ Per-record debouncing allows independent save timers

See [Understanding Optimistic UI](11-optimistic-ui.md) for deep dive.

### 3. _sectionKeys Registry

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 80-95)

```dart
final Map<String, GlobalKey<RecordSectionState>> _sectionKeys = {};

// Creating keys for each section:
GlobalKey<RecordSectionState> _getSectionKey(DateTime date, RecordType type) {
  final key = '$date-${type.name}';

  _sectionKeys.putIfAbsent(
    key,
    () => GlobalKey<RecordSectionState>(),
  );

  return _sectionKeys[key]!;
}
```

**What is this for?**

When user presses arrow up/down, we need to move focus between sections. But sections are far apart in the widget tree!

```dart
// User in RecordWidget presses arrow up
// → RecordWidget dispatches NavigateUpNotification
// → JournalScreen catches it
// → JournalScreen needs to focus the section above
// → Uses GlobalKey to access that section's state

final sectionKey = _getSectionKey(previousDate, RecordType.todo);
sectionKey.currentState?.focusLastRecord();  // Access state from anywhere!
```

See [Understanding Focus Management](10-focus-management.md) for details.

## Initialization and Loading

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 40-55)

```dart
@override
void initState() {
  super.initState();

  // Load today's records when app starts
  _loadRecordsForDate(DateTime.now());
}

Future<void> _loadRecordsForDate(DateTime date) async {
  // Normalize date to midnight (ignore time)
  final normalizedDate = DateTime(date.year, date.month, date.day);

  // Skip if already loaded
  if (_recordsByDate.containsKey(normalizedDate)) {
    return;
  }

  // Load from database
  final records = await _repository.getRecordsForDate(normalizedDate);

  // Update cache
  setState(() {
    _recordsByDate[normalizedDate] = records;
  });
}
```

**Why normalize dates?**
```dart
// Without normalization:
final date1 = DateTime(2024, 1, 15, 10, 30, 0);  // 10:30 AM
final date2 = DateTime(2024, 1, 15, 14, 45, 0);  // 2:45 PM
date1 == date2  // false! Different times

// With normalization:
final norm1 = DateTime(2024, 1, 15);  // Midnight
final norm2 = DateTime(2024, 1, 15);  // Midnight
norm1 == norm2  // true! Same day
```

This ensures we only load each date once, regardless of time.

## The Build Method - Infinite Scroll

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 100-200)

The build method creates an infinite scrolling timeline using `CustomScrollView`:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Journal'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(...);
          },
        ),
      ],
    ),

    body: LayoutBuilder(
      builder: (context, constraints) {
        // Responsive width
        final maxWidth = constraints.maxWidth;
        final contentWidth = maxWidth > 700 ? 700.0 : maxWidth;

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: CustomScrollView(
              // This is the key to infinite scrolling!
              center: _centerKey,
              slivers: [
                // Dates in the past (scroll up to load more)
                _buildPastDates(),

                // Today (the "center" point)
                _buildTodaySection(),

                // Dates in the future (scroll down to load more)
                _buildFutureDates(),
              ],
            ),
          ),
        );
      },
    ),
  );
}
```

### How CustomScrollView with center Works

```dart
CustomScrollView(
  center: _centerKey,  // Anchor point
  slivers: [
    SliverList(...),  // Items BEFORE center (scroll up to see)
    SliverList(key: _centerKey, ...),  // CENTER (today)
    SliverList(...),  // Items AFTER center (scroll down to see)
  ],
)
```

**What this does:**
- App starts at the `center` widget (today)
- Scrolling down shows future dates
- Scrolling up shows past dates
- Both directions are infinite (lazy loaded)

**Traditional scrolling vs center scrolling:**

```dart
// Traditional - only scrolls one direction
ListView(
  children: [item1, item2, item3, ...]  // Can only scroll down
)

// Center scrolling - scrolls both directions
CustomScrollView(
  center: item2,
  slivers: [
    item1,  // Above center (scroll UP to see)
    item2,  // Center (visible on load)
    item3,  // Below center (scroll DOWN to see)
  ],
)
```

## Building Date Sections

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 220-280)

Each date section is built using `FutureBuilder` for lazy loading:

```dart
Widget _buildDateSection(DateTime date) {
  return FutureBuilder<List<Record>>(
    // Load records for this date
    future: _loadRecordsForDate(date).then((_) => _recordsByDate[date] ?? []),

    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const CircularProgressIndicator();  // Loading...
      }

      final records = snapshot.data!;
      final todos = records.whereType<TodoRecord>().toList();
      final notes = records.whereType<NoteRecord>().toList();

      return Column(
        children: [
          // Date header
          Text(DateFormat.yMMMd().format(date)),

          // Todos section
          RecordSection(
            key: _getSectionKey(date, RecordType.todo),
            date: date,
            recordType: RecordType.todo,
            records: todos,
            onSave: (record) => _saveRecord(record),
            onDelete: (id) => _deleteRecord(date, id),
            onNavigateUp: () => _navigateUp(date, RecordType.todo),
            onNavigateDown: () => _navigateDown(date, RecordType.todo),
          ),

          // Notes section
          RecordSection(
            key: _getSectionKey(date, RecordType.notes),
            date: date,
            recordType: RecordType.notes,
            records: notes,
            onSave: (record) => _saveRecord(record),
            onDelete: (id) => _deleteRecord(date, id),
            onNavigateUp: () => _navigateUp(date, RecordType.notes),
            onNavigateDown: () => _navigateDown(date, RecordType.notes),
          ),
        ],
      );
    },
  );
}
```

**Why FutureBuilder?**
- Handles async loading automatically
- Shows loading state while data loads
- Rebuilds when data arrives
- Clean async UI pattern

## Optimistic UI - The Save Flow

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 300-330)

```dart
void _saveRecord(Record record) {
  // 1. IMMEDIATELY update UI (optimistic)
  setState(() {
    final records = _recordsByDate[record.date] ?? [];
    final index = records.indexWhere((r) => r.id == record.id);

    if (index >= 0) {
      // Update existing record
      records[index] = record.copyWith(updatedAt: DateTime.now());
    } else {
      // Add new record
      records.add(record);
    }

    _recordsByDate[record.date] = records;
  });

  // 2. LATER save to disk (debounced 500ms)
  _debouncers.putIfAbsent(
    record.id,
    () => Debouncer(delay: const Duration(milliseconds: 500)),
  );

  _debouncers[record.id]?.call(() async {
    await _repository.updateRecord(record);
  });
}
```

**The flow:**
```
User types "H" → onSave called → UI updates instantly (setState)
                                → Start 500ms timer

User types "e" → onSave called → UI updates instantly (setState)
                                → Reset 500ms timer

User types "l" → onSave called → UI updates instantly (setState)
                                → Reset 500ms timer

User types "l" → onSave called → UI updates instantly (setState)
                                → Reset 500ms timer

User types "o" → onSave called → UI updates instantly (setState)
                                → Reset 500ms timer

User stops typing...

                500ms later → Save "Hello" to database
```

**Benefits:**
- ✅ UI feels instant (no wait for database)
- ✅ Reduces disk writes (500ms delay)
- ✅ Prevents database locking (fewer concurrent writes)
- ✅ Saves battery (fewer disk operations)

See [Understanding Optimistic UI](11-optimistic-ui.md) for full details.

## Navigation Between Sections

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 380-450)

When user presses arrow keys, focus moves between records and sections:

```dart
void _navigateUp(DateTime date, RecordType type) {
  // Figure out which section is above current one
  final previousSection = _getPreviousSection(date, type);

  if (previousSection != null) {
    // Use GlobalKey to access that section's state
    final key = _getSectionKey(previousSection.date, previousSection.type);

    // Call method on that section to focus its last record
    key.currentState?.focusLastRecord();
  }
}

void _navigateDown(DateTime date, RecordType type) {
  final nextSection = _getNextSection(date, type);

  if (nextSection != null) {
    final key = _getSectionKey(nextSection.date, nextSection.type);
    key.currentState?.focusFirstRecord();
  }
}
```

**Why this pattern?**

Without GlobalKeys, you'd need to:
- ❌ Pass callbacks all the way down the tree
- ❌ Maintain focus state at top level
- ❌ Rebuild entire tree when focus changes

With GlobalKeys:
- ✅ Directly access child state from parent
- ✅ No prop drilling
- ✅ Precise, surgical state updates

## Responsive Layout

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 110-130)

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final maxWidth = constraints.maxWidth;

    // Responsive width breakpoints
    final contentWidth = maxWidth > 700
        ? 700.0   // Desktop: max 700px
        : maxWidth > 600
            ? 600.0  // Tablet: max 600px
            : maxWidth;  // Mobile: full width

    return Center(
      child: SizedBox(
        width: contentWidth,
        child: /* content */,
      ),
    );
  },
)
```

**Result:**
- Mobile (< 600px): Full width
- Tablet (600-700px): 600px centered
- Desktop (> 700px): 700px centered

## Cleanup

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 60-70)

```dart
@override
void dispose() {
  // Cancel all pending debounce timers
  for (var debouncer in _debouncers.values) {
    debouncer.cancel();
  }

  super.dispose();
}
```

**Why critical:**
- Prevents memory leaks
- Cancels pending database writes
- Cleans up timers

**What happens if you forget?**
- Timers keep running after widget disposed
- Pending saves may execute on disposed widget
- Memory leak (debouncers stay in memory)

## Key Patterns Summary

1. **Infinite scroll with center anchor** - CustomScrollView with center key
2. **Lazy loading** - Only load dates as user scrolls to them
3. **Optimistic UI** - Update UI immediately, save to disk later
4. **Per-record debouncing** - Independent save timers for each record
5. **GlobalKey registry** - Access child state for navigation
6. **Responsive layout** - LayoutBuilder with breakpoints
7. **FutureBuilder** - Clean async loading pattern

## Data Flow Diagram

```
User types in RecordWidget
        ↓
RecordWidget calls onSave callback
        ↓
JournalScreen._saveRecord()
        ↓
    ┌───┴───┐
    ↓       ↓
setState()  Debouncer
(instant)   (delayed 500ms)
    ↓           ↓
UI updates  Repository.updateRecord()
            ↓
        Database writes
```

## Questions to Check Understanding

1. Why use a Map<DateTime, List<Record>> instead of a single flat list?
2. Why does each record have its own debouncer?
3. What would happen without the GlobalKey registry?
4. Why normalize dates to midnight?
5. What's the difference between setState and the debounced save?
6. How does CustomScrollView enable infinite scrolling in both directions?

## Next Steps

- **[Understanding RecordSection](07-record-section.md)** - How sections manage groups of records
- **[Understanding Optimistic UI](11-optimistic-ui.md)** - Deep dive into the debouncing pattern
- **[Understanding Focus Management](10-focus-management.md)** - How GlobalKeys enable navigation

---

**Ask me:** "Walk me through journal_screen.dart with teaching comments" to add detailed explanations to the source file!
