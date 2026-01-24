# Lesson 11: Performance Optimization

**Difficulty:** Advanced
**Estimated Time:** 4-5 hours
**Prerequisites:** All previous lessons, basic understanding of performance concepts

## Learning Objectives

1. ✅ **Flutter DevTools** - Profiling and debugging tools
2. ✅ **Widget rebuilds** - Identifying and preventing unnecessary rebuilds
3. ✅ **const optimization** - Compile-time constant widgets
4. ✅ **RepaintBoundary** - Isolating repaints
5. ✅ **Lazy loading** - Loading data on demand
6. ✅ **Isolates** - Background processing

## What You're Building

Performance improvements for Lifelog:
- **Profile the app** - Find bottlenecks
- **Optimize rebuilds** - Reduce unnecessary work
- **Add const** - Where possible
- **Isolate expensive operations** - Keep UI smooth
- **Implement virtual scrolling** - Handle large datasets

This teaches production-level optimization!

## Step 1: Profile Your App

### 1.1: Enable Performance Overlay

**File:** `/home/user/lifelog/lib/main.dart`

```dart
MaterialApp(
  // ...
  showPerformanceOverlay: true, // Shows FPS graphs
  // ...
)
```

**What to look for:**
- Green bar = good (60 FPS)
- Red/yellow = bad (dropped frames)
- Spikes indicate expensive operations

### 1.2: Use Flutter DevTools

```bash
# Run your app in profile mode
flutter run --profile

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

**DevTools features:**
- **Performance tab** - Timeline of widget builds
- **Memory tab** - Track memory leaks
- **Inspector tab** - Widget tree visualization

## Step 2: Identify Rebuild Issues

Your `JournalScreen` rebuilds everything when any record changes. Let's find out why:

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

```dart
// PROBLEM: This rebuilds ALL RecordSections when ANY record changes
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(...),
    body: CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // Every RecordSection rebuilds on setState!
              return RecordSection(...);
            },
          ),
        ),
      ],
    ),
  );
}
```

### Solution 1: Extract Stateful Widgets

Extract each date section into its own widget:

```dart
class DateSection extends StatefulWidget {
  final DateTime date;
  final List<Record> records;
  final Function(Record) onSave;
  final Function(String) onDelete;

  const DateSection({
    Key? key,
    required this.date,
    required this.records,
    required this.onSave,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<DateSection> createState() => _DateSectionState();
}

class _DateSectionState extends State<DateSection> {
  @override
  Widget build(BuildContext context) {
    // This widget only rebuilds when ITS data changes
    return Column(
      children: [
        RecordSection(
          date: widget.date,
          records: widget.records.where((r) => r is TodoRecord).toList(),
          onSave: widget.onSave,
          onDelete: widget.onDelete,
        ),
        RecordSection(
          date: widget.date,
          records: widget.records.where((r) => r is NoteRecord).toList(),
          onSave: widget.onSave,
          onDelete: widget.onDelete,
        ),
      ],
    );
  }
}
```

### Solution 2: Use ValueKey

Give each section a unique key:

```dart
DateSection(
  key: ValueKey('date-section-$date'),
  date: date,
  records: records,
  // ...
)
```

**Why this helps:**
- Flutter can identify which widgets actually changed
- Unchanged widgets keep their state and don't rebuild

## Step 3: Add const Everywhere

The compiler can optimize const widgets heavily.

**Before:**
```dart
Text('Journal')  // Rebuilds every time
Padding(padding: EdgeInsets.all(16), child: ...)  // Rebuilds
Icon(Icons.settings)  // Rebuilds
```

**After:**
```dart
const Text('Journal')  // Compiled once
const Padding(padding: EdgeInsets.all(16), child: ...)  // Compiled once
const Icon(Icons.settings)  // Compiled once
```

**Find missing const:**
```bash
# Enable lint rule in analysis_options.yaml
linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true

# Run analysis
flutter analyze
```

## Step 4: Use RepaintBoundary

`RepaintBoundary` prevents repaints from cascading:

```dart
// Without RepaintBoundary:
// Changing one record repaints ALL records

// With RepaintBoundary:
RepaintBoundary(
  child: RecordWidget(
    record: record,
    // ...
  ),
)

// Now only THIS record repaints when it changes
```

**When to use:**
- Complex widgets that change independently
- List items
- Animated widgets
- Anything that repaints frequently

**When NOT to use:**
- Everywhere (adds overhead)
- Simple widgets
- Widgets that change together

## Step 5: Optimize List Rendering

Your current infinite scroll loads all dates. For large journals, this is slow.

### Solution: Implement Virtual Scrolling

```dart
class OptimizedJournalScreen extends StatefulWidget {
  // ...
}

class _OptimizedJournalScreenState extends State<OptimizedJournalScreen> {
  final ScrollController _scrollController = ScrollController();

  // Only keep visible dates in memory
  final Set<DateTime> _loadedDates = {};
  static const int _datesAhead = 10;
  static const int _datesBehind = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVisibleDates();
  }

  void _onScroll() {
    // Calculate visible date range
    final offset = _scrollController.offset;
    final centerDate = _calculateCenterDate(offset);

    // Load dates in visible range
    final startDate = centerDate.subtract(Duration(days: _datesBehind));
    final endDate = centerDate.add(Duration(days: _datesAhead));

    _loadDateRange(startDate, endDate);

    // Unload dates far from view
    _unloadDistantDates(centerDate);
  }

  DateTime _calculateCenterDate(double offset) {
    // Estimate which date is at center of screen
    const avgDayHeight = 400.0;
    final dayOffset = (offset / avgDayHeight).round();
    return DateTime.now().add(Duration(days: dayOffset));
  }

  Future<void> _loadDateRange(DateTime start, DateTime end) async {
    for (var date = start;
        date.isBefore(end);
        date = date.add(const Duration(days: 1))) {
      if (!_loadedDates.contains(date)) {
        await _loadRecordsForDate(date);
        _loadedDates.add(date);
      }
    }
  }

  void _unloadDistantDates(DateTime centerDate) {
    // Remove dates far from view to free memory
    _loadedDates.removeWhere((date) {
      final distance = (date.difference(centerDate).inDays).abs();
      return distance > _datesAhead + 10;
    });

    // Remove from _recordsByDate as well
    _recordsByDate.removeWhere((date, _) {
      final distance = (date.difference(centerDate).inDays).abs();
      return distance > _datesAhead + 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Only build widgets for loaded dates
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final sortedDates = _loadedDates.toList()..sort();
              if (index >= sortedDates.length) return null;

              final date = sortedDates[index];
              final records = _recordsByDate[date] ?? [];

              return DateSection(
                key: ValueKey('date-$date'),
                date: date,
                records: records,
                onSave: _saveRecord,
                onDelete: (id) => _deleteRecord(date, id),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

## Step 6: Use Isolates for Heavy Operations

Your database operations already use isolates (via `DatabaseProvider`). Let's optimize more:

**File:** `/home/user/lifelog/lib/services/export_service.dart`

```dart
// Move JSON encoding to isolate
Future<File> exportToJson() async {
  final records = await _repository.getAllRecords();

  // Heavy operation - run in isolate
  final jsonString = await compute(_encodeToJson, records);

  // Write to file (fast)
  final file = await _getExportFile('json');
  await file.writeAsString(jsonString);

  return file;
}

// Top-level function (required for compute)
String _encodeToJson(List<Record> records) {
  final jsonData = {
    'version': '1.0',
    'exported_at': DateTime.now().toIso8601String(),
    'record_count': records.length,
    'records': records.map((r) => r.toJson()).toList(),
  };

  return JsonEncoder.withIndent('  ').convert(jsonData);
}
```

**What `compute` does:**
- Spawns an isolate (separate thread)
- Runs function in background
- Returns result when done
- UI stays responsive

## Step 7: Measure Performance

Add performance monitoring:

**File:** `/home/user/lifelog/lib/utils/performance_monitor.dart` (new file)

```dart
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};

  static void start(String operation) {
    _timers[operation] = Stopwatch()..start();
  }

  static void end(String operation) {
    final stopwatch = _timers[operation];
    if (stopwatch != null) {
      stopwatch.stop();
      print('$operation took ${stopwatch.elapsedMilliseconds}ms');
      _timers.remove(operation);
    }
  }

  static Future<T> measure<T>(
    String operation,
    Future<T> Function() function,
  ) async {
    start(operation);
    try {
      return await function();
    } finally {
      end(operation);
    }
  }
}

// Usage:
await PerformanceMonitor.measure('Load records', () async {
  return await _repository.getRecordsForDate(date);
});
```

## Step 8: Optimize Images (If Added Later)

If you add images to records:

```dart
// Use cached_network_image for remote images
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  maxWidth: 400, // Resize to screen width
  maxHeight: 400,
)

// Use Image.asset with cacheWidth/cacheHeight
Image.asset(
  'assets/image.png',
  cacheWidth: 400, // Resize to save memory
  cacheHeight: 300,
)
```

## Key Concepts

### 1. Widget Rebuild Lifecycle

```dart
// Parent changes
Parent setState() called
  ↓
Parent build() called
  ↓
Child build() called (even if child data didn't change!)
  ↓
Entire subtree rebuilds

// Solution: const
Parent setState() called
  ↓
Parent build() called
  ↓
const Child() - Flutter skips! (Already built)
```

### 2. const vs final

```dart
// final - runtime constant (can't change after assignment)
final Widget child = Text(userName); // userName is runtime value

// const - compile-time constant (value must be known at compile time)
const Widget child = Text('Hello'); // 'Hello' is compile-time constant

// Nested const
const Padding(
  padding: EdgeInsets.all(16), // const
  child: Text('Hello'), // const
)
// Flutter builds this once at compile time!
```

### 3. Keys and Widget Identity

```dart
// Without keys - Flutter can't tell widgets apart
List<Widget> items = [
  Widget1(),
  Widget2(),
];

// Reorder items
items = [Widget2(), Widget1()]; // Flutter rebuilds both!

// With keys - Flutter knows which is which
List<Widget> items = [
  Widget1(key: ValueKey('widget1')),
  Widget2(key: ValueKey('widget2')),
];

// Reorder items
items = [
  Widget2(key: ValueKey('widget2')),
  Widget1(key: ValueKey('widget1')),
]; // Flutter just reorders! No rebuild!
```

### 4. compute() for CPU-intensive Work

```dart
// UI thread (blocks UI)
final result = expensiveOperation(data); // UI freezes!

// Background isolate (doesn't block UI)
final result = await compute(expensiveOperation, data); // UI stays smooth

// Requirements for compute():
// 1. Function must be top-level or static
// 2. Parameter must be serializable
// 3. Return value must be serializable

// Example:
static List<Record> filterRecords(List<Record> records) {
  // Expensive filtering logic
  return records.where((r) => /* complex logic */).toList();
}

final filtered = await compute(filterRecords, allRecords);
```

## Performance Checklist

- [ ] Profile app with DevTools
- [ ] Find and eliminate unnecessary rebuilds
- [ ] Add const where possible
- [ ] Use RepaintBoundary for complex widgets
- [ ] Implement virtual scrolling for large lists
- [ ] Move CPU-intensive work to isolates
- [ ] Use Keys for list items
- [ ] Optimize images with caching
- [ ] Measure critical operations

## Common Performance Pitfalls

### Pitfall 1: Building in build()

```dart
// ❌ BAD - Creates new controller on every build
@override
Widget build(BuildContext context) {
  final controller = TextEditingController(); // Memory leak + slow!
  return TextField(controller: controller);
}

// ✅ GOOD - Create in initState
late final TextEditingController _controller;

@override
void initState() {
  super.initState();
  _controller = TextEditingController();
}
```

### Pitfall 2: setState on Large Subtrees

```dart
// ❌ BAD - Rebuilds entire screen
class MyScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HugeWidgetTree(),
        SmallCounter(), // Only this needs to rebuild
      ],
    );
  }
}

// ✅ GOOD - Extract SmallCounter to own StatefulWidget
```

### Pitfall 3: Expensive Operations in build()

```dart
// ❌ BAD - Sorts on every build
@override
Widget build(BuildContext context) {
  final sorted = records.sort(); // Runs every frame!
  return ListView(children: sorted);
}

// ✅ GOOD - Sort once, cache result
List<Record> _sortedRecords = [];

void _updateRecords(List<Record> records) {
  _sortedRecords = records.toList()..sort();
  setState(() {});
}
```

## DevTools Tips

### Performance Tab
- Look for bars > 16ms (indicates dropped frame)
- Check "Track widget rebuilds" to see what's rebuilding
- Use timeline to find slow operations

### Memory Tab
- Look for growing memory usage (leak indication)
- Take snapshots to compare
- Check for undisposed controllers

### Inspector Tab
- Visualize widget tree
- See rebuild counts
- Check widget sizes

## Challenges

**Challenge 1:** Reduce widget rebuilds by 50%
**Challenge 2:** Make scrolling smooth with 10,000+ records
**Challenge 3:** Optimize search to handle large datasets
**Challenge 4:** Add performance monitoring dashboard

## What You've Learned

- ✅ Profiling with Flutter DevTools
- ✅ Identifying and fixing unnecessary rebuilds
- ✅ const optimization techniques
- ✅ RepaintBoundary for paint optimization
- ✅ Virtual scrolling for large datasets
- ✅ Isolates for background processing
- ✅ Performance measurement and monitoring

---

**Previous:** [Lesson 10: Tags System](lesson-10-tags-system.md)
**Congratulations!** You've completed all Flutter lessons for Lifelog! 🎉

## What's Next?

You now have a deep understanding of Flutter from basics to advanced patterns. Continue learning by:

1. **Building new features** - Use what you've learned
2. **Contributing to open source** - Apply these patterns elsewhere
3. **Advanced topics** - State management libraries (Provider, Riverpod, Bloc)
4. **Platform integration** - Native platform features
5. **Testing** - Unit, widget, and integration tests

**Keep building!** 🚀
