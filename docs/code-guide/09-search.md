# Step 9: Search

**Goal:** Build a search screen with debounced text search and date-range filtering.

**Your file:** `lib/widgets/search_screen.dart`, update `lib/database/record_repository.dart`
**Reference:** `reference/lib/widgets/search_screen.dart`, `reference/lib/database/record_repository.dart`

## SQL Search Query

```sql
SELECT * FROM records
WHERE content LIKE '%' || ? || '%'
  AND date >= ?
  AND date <= ?
ORDER BY date DESC, order_position ASC
```

`LIKE '%query%'` is case-insensitive substring matching in SQLite. For large datasets, consider FTS5 (full-text search), but LIKE is fine for personal journals.

### Repository Method

```dart
Future<List<Record>> search(
  String query, {
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final conditions = <String>[];
  final params = <dynamic>[];

  if (query.isNotEmpty) {
    conditions.add("content LIKE '%' || ? || '%'");
    params.add(query);
  }
  if (startDate != null) {
    conditions.add('date >= ?');
    params.add(startDate.toIso8601String().substring(0, 10));
  }
  if (endDate != null) {
    conditions.add('date <= ?');
    params.add(endDate.toIso8601String().substring(0, 10));
  }

  final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

  final rows = db.select(
    'SELECT * FROM records $where ORDER BY date DESC',
    params,
  );

  return rows.map((row) => Record.fromJson(/* ... */)).toList();
}
```

## Search Screen UI

```dart
class SearchScreen extends StatefulWidget { }

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
  List<Record> _results = [];
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,  // Keyboard opens immediately
          decoration: const InputDecoration(
            hintText: 'Search records...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final record = _results[index];
          return AdaptiveRecordWidget(
            record: record,
            onChanged: (_) {},  // Read-only in search
          );
        },
      ),
    );
  }
}
```

### Debounced Search

```dart
void _onSearchChanged(String query) {
  // Reuse the Debouncer from Step 6 — same concept
  _debouncer.call(() async {
    final results = await _repository.search(
      query,
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
    );
    setState(() => _results = results);
  });
}
```

### Date Range Picker

Flutter has a built-in date range picker:

```dart
Future<void> _pickDateRange() async {
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    initialDateRange: _dateRange,
  );

  if (range != null) {
    setState(() => _dateRange = range);
    _onSearchChanged(_searchController.text);  // Re-search with date filter
  }
}
```

> See: https://api.flutter.dev/flutter/material/showDateRangePicker.html

## Navigation to Search

Add a FloatingActionButton or AppBar action in JournalScreen:

```dart
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  },
  child: const Icon(Icons.search),
)
```

> See: https://docs.flutter.dev/cookbook/navigation/navigation-basics

## Exercise

1. Add `search()` method to **`lib/database/record_repository.dart`**
2. Create **`lib/widgets/search_screen.dart`** with debounced text input + date picker
3. Add search FAB to **`lib/widgets/journal_screen.dart`**

## Next

**[Step 10: Habits & Widgetbook →](10-habits-widgetbook.md)** — Add habit tracking and visual testing.
