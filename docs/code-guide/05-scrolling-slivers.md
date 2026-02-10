# Step 5: Journal Screen & Scrolling

**Goal:** Build an infinite-scrolling journal organized by date.

**Your files:** `lib/widgets/journal_screen.dart`, `lib/widgets/day_section.dart`, `lib/widgets/record_section.dart`
**Reference:** `reference/lib/widgets/journal_screen.dart`, `reference/lib/widgets/day_section.dart`, `reference/lib/widgets/record_section.dart`

## The Sliver System

Flutter has two layout protocols:
- **Box** — Fixed constraints (width × height). Used by `Container`, `Row`, `Column`, etc.
- **Sliver** — Scrollable lazy layout. Only builds visible items. Used inside `CustomScrollView`.

```dart
// ❌ Box-based: builds ALL children upfront
ListView(
  children: dates.map((d) => DaySection(date: d)).toList(),
)

// ✅ Sliver-based: only builds visible children
CustomScrollView(
  slivers: [
    SliverList.builder(
      itemCount: dates.length,
      itemBuilder: (context, index) => DaySection(date: dates[index]),
    ),
  ],
)
```

`SliverList.builder` is lazy — it only calls `itemBuilder` for items that are (or are about to be) visible. Scrolling 10 years of journal entries? Only ~5 days' worth of widgets exist at any time.

> See: https://api.flutter.dev/flutter/widgets/CustomScrollView-class.html
> See: https://docs.flutter.dev/ui/layout/scrolling/slivers

## Bidirectional Infinite Scroll with Center

The trick: `CustomScrollView` has a `center` parameter that splits the slivers into "before" and "after" groups.

```dart
final _centerKey = UniqueKey();

CustomScrollView(
  center: _centerKey,  // Today is the anchor
  slivers: [
    // BEFORE center: past dates (scroll UP to load more)
    SliverList.builder(
      itemCount: _pastDates.length,
      itemBuilder: (context, index) => DaySection(date: _pastDates[index]),
    ),

    // CENTER: today
    SliverToBoxAdapter(
      key: _centerKey,
      child: DaySection(date: DateTime.now()),
    ),

    // AFTER center: future dates (scroll DOWN to load more)
    SliverList.builder(
      itemCount: _futureDates.length,
      itemBuilder: (context, index) => DaySection(date: _futureDates[index]),
    ),
  ],
)
```

On app start, the viewport is positioned at the center sliver (today). User scrolls up to see yesterday, last week, etc. Scrolls down for tomorrow.

> See: https://api.flutter.dev/flutter/widgets/CustomScrollView/center.html

## Lazy Loading Dates

Don't load all dates upfront. Load as the user scrolls:

```dart
final Map<DateTime, List<Record>> _recordsByDate = {};

Future<void> _loadRecordsForDate(DateTime date) async {
  // Normalize to midnight — so Jan 15 10:30 and Jan 15 14:00
  // resolve to the same key
  final normalized = DateTime(date.year, date.month, date.day);

  if (_recordsByDate.containsKey(normalized)) return;  // Already loaded

  final records = await _repository.getRecordsForDate(normalized);
  setState(() {
    _recordsByDate[normalized] = records;
  });
}
```

Each `DaySection` triggers loading when it first builds (via `FutureBuilder` or `initState`).

## Widget Hierarchy

```
JournalScreen (StatefulWidget)
  └─ CustomScrollView
       └─ SliverList
            └─ DaySection (one per date)
                 ├─ Date header ("Monday, January 15")
                 └─ RecordSection
                      └─ Column of AdaptiveRecordWidgets
                           └─ TextRecordWidget / TodoRecordWidget / ...
```

### DaySection

One per date. Contains a header and a single `RecordSection`:

```dart
class DaySection extends StatelessWidget {
  final DateTime date;
  final List<Record> records;
  // ...

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            DateFormat.yMMMEd().format(date),  // "Mon, Jan 15, 2024"
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),

        // Records
        RecordSection(
          date: date,
          records: records,
          onSave: onSave,
          onDelete: onDelete,
        ),
      ],
    );
  }
}
```

### RecordSection

Manages the list of records for a single day. Handles:
- Rendering each record via `AdaptiveRecordWidget`
- Placeholder (empty state: "Start writing...")
- Creating new records when user presses Enter at end of list
- Focus registration for keyboard navigation

```dart
class RecordSection extends StatefulWidget {
  final DateTime date;
  final List<Record> records;
  final ValueChanged<Record> onSave;
  final ValueChanged<String> onDelete;
}
```

## Responsive Layout

```dart
LayoutBuilder(
  // LayoutBuilder gives you the parent's constraints
  // Rebuilds when window resizes
  builder: (context, constraints) {
    final width = constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;

    return Center(
      child: SizedBox(
        width: width,
        child: /* content */,
      ),
    );
  },
)
```

This caps content at 700px on wide screens but uses full width on mobile. `LayoutBuilder` is the Flutter equivalent of CSS media queries.

> See: https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html

## SliverToBoxAdapter

Sometimes you need a non-sliver widget inside a `CustomScrollView`:

```dart
CustomScrollView(
  slivers: [
    // ❌ Can't put a Column directly in slivers
    // Column(...),

    // ✅ Wrap it
    SliverToBoxAdapter(
      child: Column(...),
    ),

    // ✅ SliverList is already a sliver
    SliverList.builder(...),
  ],
)
```

> See: https://api.flutter.dev/flutter/widgets/SliverToBoxAdapter-class.html

## Exercise

Build in this order:

1. **`lib/widgets/record_section.dart`** — Column of `AdaptiveRecordWidget`s for one day
2. **`lib/widgets/day_section.dart`** — Date header + `RecordSection`
3. **`lib/widgets/journal_screen.dart`** — `CustomScrollView` with center anchor, `_recordsByDate` cache, `LayoutBuilder`

Start simple: just show today's records. Add infinite scroll once that works.

## Next

**[Step 6: State & Persistence →](06-state-management.md)** — Wire up optimistic saves with debouncing.
