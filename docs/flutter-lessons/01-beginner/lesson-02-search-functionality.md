# Lesson 2: Adding Search Functionality

**Difficulty:** Beginner
**Estimated Time:** 2-3 hours
**Prerequisites:** Lesson 1 (StatefulWidget, setState, basic widgets)

## Learning Objectives

By completing this lesson, you will understand:

1. ✅ **TextEditingController** - Managing text input state
2. ✅ **Filtering data** - How to filter lists based on user input
3. ✅ **TextField widget** - Creating search inputs
4. ✅ **Performance basics** - Why some approaches are faster than others
5. ✅ **List operations** - Using `where()`, `contains()`, `toLowerCase()`
6. ✅ **Controller lifecycle** - When to create and dispose controllers

## What You're Building

A search bar for your Lifelog app that:
- **Filters records in real-time** as you type
- **Searches through record content** (both todos and notes)
- **Highlights search UI** with Material Design
- **Clears search** with a button
- **Shows result count**

This teaches you text input handling and list filtering - essential Flutter skills!

## Why This Matters

Search is fundamental to most apps. This lesson teaches you:
- How Flutter handles text input
- How to efficiently filter large lists
- How to update UI based on user input
- Performance considerations

## Step 1: Understand Current Architecture

Before we add search, let's understand how `JournalScreen` currently loads data:

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

The screen stores records in `_recordsByDate`:
```dart
// This Map holds all loaded records, grouped by date
final Map<DateTime, List<Record>> _recordsByDate = {};
```

When you scroll, it loads more dates using `_loadRecordsForDate()`. We'll need to filter these records based on search text.

## Step 2: Add Search State to JournalScreen

Let's add search functionality to `JournalScreen`.

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

### 2.1: Add controller and search state

Add these at the top of `_JournalScreenState` class (around line 20):

```dart
class _JournalScreenState extends State<JournalScreen> {
  // Existing variables...
  final Map<DateTime, List<Record>> _recordsByDate = {};

  // NEW: Add these for search functionality
  // TextEditingController manages the text in a TextField
  // It lets us read, write, and listen to changes in the text field
  final TextEditingController _searchController = TextEditingController();

  // Track whether we're in search mode
  bool _isSearching = false;

  // Store the current search query
  String _searchQuery = '';
```

### 2.2: Initialize the controller listener

In `initState()`, add a listener to the search controller:

```dart
@override
void initState() {
  super.initState();

  // NEW: Add listener for search text changes
  // This callback runs every time the user types
  _searchController.addListener(() {
    setState(() {
      // Update the search query when text changes
      _searchQuery = _searchController.text.toLowerCase();
    });
  });

  // Load today's records...
  _loadRecordsForDate(DateTime.now());
}
```

### 2.3: Dispose the controller

**CRITICAL:** Always dispose controllers to prevent memory leaks!

```dart
@override
void dispose() {
  // NEW: Clean up the controller when widget is destroyed
  // Without this, the controller stays in memory forever (memory leak!)
  _searchController.dispose();

  // Existing dispose code...
  for (var debouncer in _debouncers.values) {
    debouncer.cancel();
  }
  super.dispose();
}
```

### 2.4: Add search filtering method

Add this method to filter records based on search:

```dart
// Filter records based on search query
List<Record> _filterRecords(List<Record> records) {
  // If no search query, return all records
  if (_searchQuery.isEmpty) {
    return records;
  }

  // Filter records where content contains the search query
  return records.where((record) {
    // Get the record's content based on its type
    String content = '';
    if (record is TodoRecord) {
      content = record.content.toLowerCase();
    } else if (record is NoteRecord) {
      content = record.content.toLowerCase();
    }

    // Check if content contains the search query
    // toLowerCase() makes search case-insensitive
    return content.contains(_searchQuery);
  }).toList();
}
```

## Step 3: Update the UI with Search Bar

Now let's add the search UI. We'll modify the `build()` method to include a search bar.

### 3.1: Add search bar to AppBar

Replace the existing `appBar` in `build()` method:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    // NEW: AppBar with search functionality
    appBar: AppBar(
      // If searching, show search field; otherwise show title
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true, // Automatically focus when search starts
              decoration: const InputDecoration(
                hintText: 'Search your journal...',
                border: InputBorder.none, // No border in AppBar
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              // Listen for text changes (controller listener handles this)
            )
          : const Text('Journal'),

      actions: [
        // Search icon button
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),

        // Clear search button (shown when searching)
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear search',
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear(); // Clear the text field
              });
            },
          ),

        // Settings icon
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    ),

    // Rest of the build method stays the same...
    body: LayoutBuilder(
      // ...existing code...
    ),
  );
}
```

### 3.2: Apply filtering to record sections

Find where `RecordSection` widgets are built (in the `SliverList` builder). Update it to filter records:

Look for this code around line 150-180:

```dart
// Inside the SliverList itemBuilder
final date = dates[index];
final records = _recordsByDate[date] ?? [];

// NEW: Filter records based on search
final filteredRecords = _filterRecords(records);

// If searching and no results for this date, skip it
if (_isSearching && filteredRecords.isEmpty) {
  return const SizedBox.shrink(); // Return empty widget
}
```

Then update the `RecordSection` widgets to use `filteredRecords`:

```dart
// Update todos section
RecordSection(
  key: _sectionKeys['$date-todo'],
  date: date,
  recordType: RecordType.todo,
  records: filteredRecords.where((r) => r is TodoRecord).toList(), // Filtered!
  onSave: (record) => _saveRecord(record),
  onDelete: (id) => _deleteRecord(date, id),
  onNavigateUp: () => _navigateUp(date, RecordType.todo),
  onNavigateDown: () => _navigateDown(date, RecordType.todo),
),

// Update notes section
RecordSection(
  key: _sectionKeys['$date-notes'],
  date: date,
  recordType: RecordType.notes,
  records: filteredRecords.where((r) => r is NoteRecord).toList(), // Filtered!
  onSave: (record) => _saveRecord(record),
  onDelete: (id) => _deleteRecord(date, id),
  onNavigateUp: () => _navigateUp(date, RecordType.notes),
  onNavigateDown: () => _navigateDown(date, RecordType.notes),
),
```

## Step 4: Add Search Results Counter

Let's show how many results were found. Add this below the AppBar:

```dart
body: Column(
  children: [
    // NEW: Search results banner
    if (_isSearching && _searchQuery.isNotEmpty)
      Container(
        padding: const EdgeInsets.all(8.0),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              '${_countSearchResults()} result(s) found',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),

    // Existing LayoutBuilder with journal content
    Expanded(
      child: LayoutBuilder(
        // ...existing code...
      ),
    ),
  ],
),
```

Add the count method:

```dart
// Count total search results across all dates
int _countSearchResults() {
  int count = 0;
  for (var records in _recordsByDate.values) {
    count += _filterRecords(records).length;
  }
  return count;
}
```

## Step 5: Test Your Search

1. **Run the app** with `flutter run`
2. Click the **search icon** in the AppBar
3. Type a word that appears in your journal (e.g., "meeting" or "buy")
4. Watch records **filter in real-time** as you type
5. See the **result count** update
6. Click the **X** to clear search
7. Verify you're back to the full journal view

## Key Concepts Deep Dive

### 1. TextEditingController

`TextEditingController` is how you work with `TextField` in Flutter:

```dart
// Create a controller
final _controller = TextEditingController();

// Read the current text
String text = _controller.text;

// Set the text programmatically
_controller.text = 'Hello';

// Clear the text
_controller.clear();

// Listen to changes
_controller.addListener(() {
  print('Text changed to: ${_controller.text}');
});

// ALWAYS dispose when done!
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

**Why use a controller instead of just onChange?**
- You can read the current value anytime
- You can programmatically change the text
- You get a single listener for all changes
- More efficient for complex text handling

### 2. List Filtering with where()

Dart's `where()` method filters lists:

```dart
// Original list
List<int> numbers = [1, 2, 3, 4, 5];

// Filter even numbers
List<int> evenNumbers = numbers.where((n) => n % 2 == 0).toList();
// Result: [2, 4]

// For records
List<Record> todos = allRecords.where((r) => r is TodoRecord).toList();
```

**Important:** `where()` returns an `Iterable`, so call `.toList()` to convert back to a List.

### 3. String Comparison Best Practices

```dart
// ❌ BAD - Case sensitive
'Hello'.contains('hello'); // false

// ✅ GOOD - Case insensitive
'Hello'.toLowerCase().contains('hello'.toLowerCase()); // true

// For search, always convert both to lowercase
String searchQuery = userInput.toLowerCase();
bool matches = record.content.toLowerCase().contains(searchQuery);
```

### 4. Performance Considerations

Our current implementation has a **performance issue** - can you spot it?

```dart
// This runs on EVERY keystroke!
_searchController.addListener(() {
  setState(() {
    _searchQuery = _searchController.text.toLowerCase();
  });
});
```

**The problem:** Every keystroke triggers:
1. setState() → rebuild entire widget tree
2. Filter all records in all dates
3. Rebuild all RecordSection widgets

**For small journals:** Not a problem
**For journals with 10,000+ records:** Noticeable lag!

**Solution for Lesson 11:** We'll add debouncing and optimization.

### 5. Controller Lifecycle Management

**Critical rule:** Every controller MUST be disposed!

```dart
// ✅ CORRECT Pattern
class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController(); // Create in declaration

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChange); // Add listener
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange); // Remove listener
    _controller.dispose(); // Dispose controller
    super.dispose();
  }
}
```

**What happens if you forget to dispose?**
- Memory leak (controller stays in memory forever)
- Listener keeps running even after widget is destroyed
- Eventually crashes the app

### 6. Conditional Rendering

We used several conditional rendering techniques:

```dart
// Ternary operator - choose between two widgets
title: _isSearching ? TextField(...) : Text('Journal')

// if statement in collection - conditionally include widget
actions: [
  if (_isSearching) IconButton(...),
  if (!_isSearching) IconButton(...),
]

// Null-aware operator - show widget or nothing
_searchQuery.isNotEmpty ? Container(...) : null
```

## Testing Checklist

- [ ] Search icon appears in AppBar
- [ ] Clicking search icon shows TextField
- [ ] Typing filters records in real-time
- [ ] Search is case-insensitive
- [ ] Result count shows correct number
- [ ] Clear button clears search and shows all records
- [ ] Search works across all dates
- [ ] Empty search shows all records

## Common Mistakes & How to Fix Them

### Mistake 1: Forgetting to convert to lowercase

```dart
// ❌ WRONG - Case sensitive
content.contains(_searchQuery);

// ✅ CORRECT - Case insensitive
content.toLowerCase().contains(_searchQuery.toLowerCase());
```

### Mistake 2: Not disposing controller

```dart
// ❌ WRONG - Memory leak!
@override
void dispose() {
  super.dispose(); // Forgot to dispose controller!
}

// ✅ CORRECT
@override
void dispose() {
  _searchController.dispose(); // Clean up!
  super.dispose();
}
```

### Mistake 3: Calling setState too often

```dart
// ❌ WRONG - setState on every keystroke
_controller.addListener(() {
  setState(() { ... });
});

// ✅ BETTER - Use debouncing (we'll learn in Lesson 11)
// For now, the simple approach is fine for small datasets
```

### Mistake 4: Forgetting .toList()

```dart
// ❌ WRONG - Returns Iterable, not List
var filtered = records.where((r) => condition);

// ✅ CORRECT - Convert to List
var filtered = records.where((r) => condition).toList();
```

## Challenges to Extend Your Learning

### Challenge 1: Search History
Store the last 5 search queries and show them as suggestions.

Hint: Use a `List<String>` to store queries and `ListView` to display them.

### Challenge 2: Search Options
Add checkboxes to search only Todos or only Notes.

Hint: Add `bool _searchTodos` and `bool _searchNotes` state variables.

### Challenge 3: Highlight Matches
Highlight the search term in the filtered results.

Hint: Look into `RichText` and `TextSpan` widgets.

### Challenge 4: Search by Date Range
Add date pickers to search within a specific date range.

Hint: Use `showDatePicker()` and filter by `record.date`.

## What You've Learned

- ✅ How to use TextEditingController to manage text input
- ✅ How to filter lists with `where()` and `contains()`
- ✅ How to update UI based on text input
- ✅ The importance of disposing controllers
- ✅ Case-insensitive string comparison
- ✅ Conditional rendering in Flutter
- ✅ Basic performance considerations

## Further Learning

**Official Flutter Documentation:**
- [TextField widget](https://api.flutter.dev/flutter/material/TextField-class.html)
- [TextEditingController](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html)
- [List filtering](https://api.dart.dev/stable/dart-core/Iterable/where.html)

**Dart Language Tour:**
- [Collections](https://dart.dev/guides/language/language-tour#lists)
- [String manipulation](https://api.dart.dev/stable/dart-core/String-class.html)

**Performance:**
- [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices)

## Next Steps

In **Lesson 3: Theme Toggle with Persistence**, you'll learn:
- Working with `ThemeData` and `MaterialApp`
- Using SharedPreferences for data persistence
- Lifting state up to parent widgets
- Creating a provider-like pattern

Make sure you understand:
1. How TextEditingController works
2. When to call dispose()
3. How to filter lists with where()
4. Why we use setState()

**Questions to check your understanding:**
1. What happens if you forget to call `_searchController.dispose()`?
2. Why do we convert strings to lowercase before comparing?
3. What's the difference between `TextField` and `TextEditingController`?
4. How does `where()` filter a list?

Ready? Let's move on to Lesson 3! 🚀

---

**Previous:** [Lesson 1: Settings Screen](lesson-01-settings-screen.md)
**Next:** [Lesson 3: Theme Toggle](lesson-03-theme-toggle.md)
