# Lesson 6: Date Picker & Quick Navigation

**Difficulty:** Intermediate
**Estimated Time:** 2 hours
**Prerequisites:** Lessons 1-5 (ScrollController, custom widgets)

## Learning Objectives

1. ✅ **ScrollController** - Programmatic scrolling
2. ✅ **showDatePicker** - Flutter's date picker dialog
3. ✅ **Calendar calculations** - Working with dates
4. ✅ **FloatingActionButton** - Adding quick actions
5. ✅ **Custom scroll positions** - Jumping to specific items

## What You're Building

Quick navigation features:
- **Date picker button** - Jump to any date instantly
- **Today button** - Quick return to today
- **Smooth scrolling** - Animated navigation
- **Visual feedback** - Show current date

This teaches you scrolling control and date handling!

## Step 1: Add FloatingActionButton to JournalScreen

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      // ...existing code...
    ),
    body: LayoutBuilder(
      // ...existing code...
    ),

    // NEW: Add floating action buttons
    floatingActionButton: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Jump to date button
        FloatingActionButton.small(
          heroTag: 'jump_to_date',
          tooltip: 'Jump to date',
          onPressed: _showDatePickerDialog,
          child: const Icon(Icons.calendar_today),
        ),
        const SizedBox(height: 8),
        // Jump to today button
        FloatingActionButton(
          heroTag: 'jump_to_today',
          tooltip: 'Jump to today',
          onPressed: _jumpToToday,
          child: const Icon(Icons.today),
        ),
      ],
    ),
  );
}
```

## Step 2: Implement Date Picker

Add these methods to `_JournalScreenState`:

```dart
// Show date picker and jump to selected date
Future<void> _showDatePickerDialog() async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2000), // Allow dates from year 2000
    lastDate: DateTime(2100),  // Allow dates up to 2100
    helpText: 'Jump to date',
    confirmText: 'GO',
  );

  if (picked != null) {
    await _jumpToDate(picked);
  }
}

// Jump to today's date
Future<void> _jumpToToday() async {
  await _jumpToDate(DateTime.now());
}

// Jump to specific date
Future<void> _jumpToDate(DateTime targetDate) async {
  // Normalize to midnight
  final date = DateTime(targetDate.year, targetDate.month, targetDate.day);

  // Ensure the date's records are loaded
  if (!_recordsByDate.containsKey(date)) {
    await _loadRecordsForDate(date);
  }

  // Calculate scroll position
  // This is a simplified version - you may need to adjust based on your layout
  final daysSinceEpoch = date.difference(DateTime(1970)).inDays;
  final todayDays = DateTime.now().difference(DateTime(1970)).inDays;
  final daysDifference = daysSinceEpoch - todayDays;

  // Scroll to approximate position
  // Note: This requires a ScrollController on your CustomScrollView
  if (_scrollController.hasClients) {
    final targetPosition = _scrollController.position.pixels +
        (daysDifference * 400.0); // Approximate height per day

    await _scrollController.animateTo(
      targetPosition.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Show confirmation
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Jumped to ${DateFormat.yMMMd().format(date)}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
```

## Step 3: Add ScrollController

Add controller as class member:

```dart
class _JournalScreenState extends State<JournalScreen> {
  final ScrollController _scrollController = ScrollController();
  // ...other variables...

  @override
  void dispose() {
    _scrollController.dispose(); // Clean up!
    // ...other dispose code...
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
      body: LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            controller: _scrollController, // ADD THIS
            // ...rest of CustomScrollView...
          );
        },
      ),
    );
  }
}
```

## Step 4: Improve with Date Header

Create a floating date indicator that shows current date while scrolling:

```dart
// Add state variable
DateTime? _visibleDate;

// Add listener in initState
@override
void initState() {
  super.initState();
  _scrollController.addListener(_onScroll);
  // ...
}

// Handle scroll to update visible date
void _onScroll() {
  // Calculate which date is currently visible
  // This is simplified - adjust based on your layout
  final offset = _scrollController.offset;
  final daysDifference = (offset / 400.0).round();
  final newDate = DateTime.now().add(Duration(days: daysDifference));

  if (_visibleDate == null ||
      _visibleDate!.day != newDate.day ||
      _visibleDate!.month != newDate.month ||
      _visibleDate!.year != newDate.year) {
    setState(() {
      _visibleDate = newDate;
    });
  }
}

// Add floating date indicator to build
@override
Widget build(BuildContext context) {
  return Scaffold(
    // ...
    body: Stack(
      children: [
        // Existing CustomScrollView
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              controller: _scrollController,
              // ...
            );
          },
        ),

        // Floating date indicator
        if (_visibleDate != null)
          Positioned(
            top: 16,
            left: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat.yMMMd().format(_visibleDate!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
```

## Key Concepts

### 1. ScrollController

```dart
final controller = ScrollController();

// Listen to scroll events
controller.addListener(() {
  print('Scroll position: ${controller.offset}');
});

// Animate to position
controller.animateTo(
  500.0,
  duration: Duration(milliseconds: 300),
  curve: Curves.easeOut,
);

// Jump instantly (no animation)
controller.jumpTo(500.0);

// Check if attached
if (controller.hasClients) {
  // Safe to use position
  final pixels = controller.position.pixels;
  final minExtent = controller.position.minScrollExtent;
  final maxExtent = controller.position.maxScrollExtent;
}

// ALWAYS dispose!
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

### 2. showDatePicker

```dart
final DateTime? picked = await showDatePicker(
  context: context,
  initialDate: DateTime.now(),     // Initially selected date
  firstDate: DateTime(2000),       // Earliest selectable date
  lastDate: DateTime(2100),        // Latest selectable date

  // Customization
  helpText: 'Select date',
  cancelText: 'Cancel',
  confirmText: 'OK',

  // Can also customize colors via theme
);

if (picked != null) {
  // User selected a date
  print(picked);
} else {
  // User cancelled
}
```

### 3. DateTime Operations

```dart
// Create dates
final now = DateTime.now();
final specific = DateTime(2024, 1, 15, 14, 30); // Year, month, day, hour, min

// Normalize to midnight (remove time)
final midnight = DateTime(now.year, now.month, now.day);

// Add/subtract time
final tomorrow = now.add(Duration(days: 1));
final yesterday = now.subtract(Duration(days: 1));

// Compare dates
if (date1.isAfter(date2)) { }
if (date1.isBefore(date2)) { }
if (date1.isAtSameMomentAs(date2)) { }

// Difference between dates
final difference = date1.difference(date2);
final daysDiff = difference.inDays;
final hoursDiff = difference.inHours;
```

## Testing Checklist

- [ ] Calendar icon button appears
- [ ] Date picker opens when tapped
- [ ] Selecting date scrolls to that date
- [ ] Today button jumps to today
- [ ] Scroll animation is smooth
- [ ] Date indicator updates while scrolling
- [ ] Controllers are disposed properly

## Challenges

**Challenge 1:** Add week/month navigation buttons
**Challenge 2:** Add keyboard shortcuts (Ctrl+G for "go to date")
**Challenge 3:** Remember last visited dates
**Challenge 4:** Add a mini calendar widget

## What You've Learned

- ✅ ScrollController for programmatic scrolling
- ✅ showDatePicker for date selection
- ✅ DateTime calculations and normalization
- ✅ FloatingActionButton for quick actions
- ✅ Scroll listeners and position tracking

---

**Previous:** [Lesson 5: Data Export](lesson-05-data-export.md)
**Next:** [Lesson 7: Custom Widgets](lesson-07-custom-widgets.md)
