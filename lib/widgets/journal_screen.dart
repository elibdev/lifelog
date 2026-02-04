import 'package:flutter/material.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import '../notifications/navigation_notifications.dart';
import '../services/date_service.dart';
import '../utils/debouncer.dart';
import 'record_section.dart';
import 'day_section.dart';
import 'dotted_grid_background.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final RecordRepository _repository = RecordRepository();

  // Map of date -> records (lazy loaded cache)
  final Map<String, List<Record>> _recordsByDate = {};

  // Per-record debouncing for disk writes (optimistic UI pattern)
  final Map<String, Debouncer> _debouncers = {};

  // CROSS-SECTION NAVIGATION: Map of (date, sectionType) -> GlobalKey
  //
  // WHAT IS A GLOBALKEY?
  // A GlobalKey is like a "remote control" for a widget. It lets us access
  // a widget's state from anywhere in the app, even if that widget is deep
  // in the widget tree and we don't have a direct reference to it.
  //
  // WHY DO WE NEED IT HERE?
  // When a navigation notification bubbles up to JournalScreen, we need to
  // tell a specific RecordSection "focus your first/last record". Without
  // GlobalKey, we'd have no way to call methods on RecordSection's state.
  //
  // EXAMPLE:
  // User presses arrow down on last todo of Jan 23:
  //   1. Notification bubbles up to JournalScreen
  //   2. JournalScreen knows: "go to first note of Jan 23"
  //   3. JournalScreen looks up: _sectionKeys['2026-01-23-note']
  //   4. Calls: key.currentState?.focusFirstRecord()
  //   5. Notes section focuses its first text field
  //
  // This is how we avoid FocusScope.nextFocus() which would focus ANY
  // widget (checkboxes, buttons, etc.) instead of specifically text fields.
  final Map<String, GlobalKey<RecordSectionState>> _sectionKeys = {};

  // No date range limits - truly infinite scrolling!

  final GlobalKey _todayKey = GlobalKey();

  // Get or create a GlobalKey for a specific RecordSection
  //
  // WHY USE A MAP INSTEAD OF CREATING NEW KEYS?
  // GlobalKeys must be STABLE across rebuilds. If we created a new
  // GlobalKey() every time build() runs, Flutter would think we're
  // creating a completely new widget and lose the connection to the
  // RecordSection's state.
  //
  // By storing keys in a Map, we ensure the SAME key is used for the
  // SAME section across rebuilds, so currentState stays connected.
  //
  // AVOIDING THE GLOBALKEY PITFALL:
  // ❌ BAD:  key: GlobalKey<RecordSectionState>()  // New key every build!
  // ✅ GOOD: key: _getSectionKey(date, type)       // Returns same key
  //
  // putIfAbsent ensures:
  // - First call: Creates key, stores in map, returns it
  // - Subsequent calls: Returns EXISTING key from map (no recreation)
  //
  // EXAMPLE:
  // - First build: Creates GlobalKey for '2026-01-23-todo', attaches to RecordSection
  // - Second build: Returns SAME key, maintains connection to RecordSection
  // - Later: key.currentState points to the RecordSection's state
  GlobalKey<RecordSectionState> _getSectionKey(String date, String sectionType) {
    final key = '$date-$sectionType';
    return _sectionKeys.putIfAbsent(key, () => GlobalKey<RecordSectionState>());
  }

  // SMART NAVIGATION: Handle arrow down from end of section
  // Navigate to the first record of the next logical section
  //
  // PROBLEM: FocusScope.nextFocus() is too generic - it traverses the entire
  // focus tree and focuses ANY focusable widget (checkboxes, buttons, etc.)
  //
  // SOLUTION: Use the notification's metadata (date, sectionType) to directly
  // access the next RecordSection's state and call focusFirstRecord() on it.
  // This ensures we ALWAYS focus a text field, never a checkbox.
  void _navigateDown(String date, String sectionType) {
    if (sectionType == 'todo') {
      // From last todo → first note (same day)
      _focusFirstRecordOfSection(date, 'note');
    } else {
      // From last note → first todo of next day
      final nextDate = DateService.getNextDate(date);
      _focusFirstRecordOfSection(nextDate, 'todo');
    }
  }

  // SMART NAVIGATION: Handle arrow up from start of section
  // Navigate to the last record of the previous logical section
  //
  // Same logic as _navigateDown but in reverse direction
  void _navigateUp(String date, String sectionType) {
    if (sectionType == 'note') {
      // From first note → last todo (same day)
      _focusLastRecordOfSection(date, 'todo');
    } else {
      // From first todo → last note of previous day
      final prevDate = DateService.getPreviousDate(date);
      _focusLastRecordOfSection(prevDate, 'note');
    }
  }

  // Focus the first record of a specific section
  // Uses GlobalKey to access RecordSection's state and call its public method
  //
  // HOW IT WORKS:
  //   1. Get the GlobalKey for the target section
  //   2. Access the key's currentState (RecordSectionState instance)
  //   3. Call the public method focusFirstRecord() on that state
  //
  // VISUAL FLOW:
  //   JournalScreen (here)
  //        ↓ key.currentState?.focusFirstRecord()
  //   RecordSectionState (in record_section.dart)
  //        ↓ _tryFocusRecordAt(0)
  //        ↓ _focusNodes[firstRecordId]?.requestFocus()
  //   TextField gets focus ✅
  void _focusFirstRecordOfSection(String date, String sectionType) {
    final key = _getSectionKey(date, sectionType);
    // currentState may be null if the section hasn't been built yet (lazy loading)
    // In that case, navigation simply doesn't happen (stay in place)
    key.currentState?.focusFirstRecord();
  }

  // Focus the last record of a specific section
  // Uses GlobalKey to access RecordSection's state and call its public method
  void _focusLastRecordOfSection(String date, String sectionType) {
    final key = _getSectionKey(date, sectionType);
    // currentState may be null if the section hasn't been built yet (lazy loading)
    // In that case, navigation simply doesn't happen (stay in place)
    key.currentState?.focusLastRecord();
  }

  @override
  void initState() {
    super.initState();
    // Pre-load today's data so it's visible immediately on app start
    // This is crucial for iOS where app termination clears the in-memory cache
    _loadInitialData();
  }

  @override
  void dispose() {
    // Clean up all debouncers to prevent memory leaks
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    super.dispose();
  }

  // WHAT: Pre-loads today's data on app startup
  // WHY: On iOS, app termination clears RAM → _recordsByDate is empty → UI blank
  // HOW: Eagerly load today's date into cache before first build
  // WHEN: Called once during initState, before first build() call
  //
  // TEACHING POINTS:
  // - async in initState is allowed (unlike build)
  // - We don't await in initState (widget must mount immediately)
  // - setState triggers rebuild after data loads
  // - This pattern: "optimistic mounting + async load + setState update"
  //
  // FLUTTER LIFECYCLE:
  // 1. initState() called → _loadInitialData() starts (doesn't block)
  // 2. Widget mounts immediately → build() runs with empty cache
  // 3. _loadInitialData() completes → today's data loaded into cache
  // 4. setState() called → triggers rebuild
  // 5. build() runs again → today's DaySection shows data via cache
  Future<void> _loadInitialData() async {
    final today = DateService.today();

    // EXPLANATION: We call _getRecordsForDate which:
    //   1. Checks cache (_recordsByDate) - empty on app restart
    //   2. Queries database via _repository.getRecordsForDate(today)
    //   3. Populates cache with today's records
    //   4. Returns the records
    //
    // This is the same method used by lazy loading when you scroll!
    // We're just calling it early to "warm up" the cache.
    await _getRecordsForDate(today);

    // EXPLANATION: setState triggers a rebuild
    // Even though _recordsByDate was updated by _getRecordsForDate,
    // we need setState to:
    //   - Notify Flutter that state changed
    //   - Trigger rebuild of DaySection FutureBuilders
    //   - Make today's data visible in the UI
    //
    // WHY CHECK 'mounted'?
    // In rare cases, the widget might be disposed before the async
    // operation completes. Calling setState on a disposed widget
    // causes an error, so we check 'mounted' first.
    //
    // EXAMPLE SCENARIO:
    // - User opens app → _loadInitialData() starts
    // - User immediately navigates away → JournalScreen disposed
    // - _loadInitialData() completes → if (mounted) prevents crash
    if (mounted) setState(() {});
  }

  // Lazy load records for a date (only when needed)
  Future<List<Record>> _getRecordsForDate(String date) async {
    if (_recordsByDate.containsKey(date)) {
      return _recordsByDate[date]!;
    }

    final records = await _repository.getRecordsForDate(date);
    _recordsByDate[date] = records;
    return records;
  }

  Future<void> _handleSaveRecord(Record record) async {
    // OPTIMISTIC UI: Update UI cache immediately (no delay)
    setState(() {
      final records = _recordsByDate[record.date] ?? [];
      final index = records.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        records[index] = record;
      } else {
        records.add(record);
      }
      // Sort by orderPosition to maintain correct order
      records.sort((a, b) => a.orderPosition.compareTo(b.orderPosition));
      _recordsByDate[record.date] = records;
    });

    // DEBOUNCED DISK WRITE: Per-record debouncing prevents excessive writes
    // Each record gets its own debouncer to avoid interference between edits
    final debouncer = _debouncers.putIfAbsent(record.id, () => Debouncer());
    debouncer.call(() async {
      await _repository.saveRecord(record);
    });
  }

  Future<void> _handleDeleteRecord(String recordId) async {
    // Cancel any pending saves for this record (prevents race condition)
    _debouncers[recordId]?.dispose();
    _debouncers.remove(recordId);

    // Update local cache first
    setState(() {
      for (final date in _recordsByDate.keys) {
        _recordsByDate[date] = _recordsByDate[date]!
            .where((r) => r.id != recordId)
            .toList();
      }
    });

    // Delete from database
    await _repository.deleteRecord(recordId);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use default Material theme background
      body: SafeArea(
        // LayoutBuilder lets us adapt layout based on available width
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive breakpoints:
            // Mobile: < 600px - full width with edge padding
            // Tablet: 600-900px - constrained to 600px
            // Desktop: > 900px - constrained to 700px with paper shadow

            final screenWidth = constraints.maxWidth;
            final bool isDesktop = screenWidth > 900;
            final bool isTablet = screenWidth >= 600 && screenWidth <= 900;

            // Max content width (like paper on a desk)
            final double maxWidth = isDesktop
                ? 700
                : (isTablet ? 600 : double.infinity);

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                // Dotted grid background wraps all content for visual structure
                // WIDGET COMPOSITION: DottedGridBackground is a wrapper that adds
                // a scrollable grid behind the content, ensuring all UI elements
                // can align to a consistent visual grid system
                child: DottedGridBackground(
                  child: NotificationListener<NavigateDownNotification>(
                  onNotification: (notification) {
                    // RecordSection couldn't handle it (at end of section)
                    // Navigate to next logical section (todos→notes, notes→next day's todos)
                    _navigateDown(notification.date, notification.sectionType);
                    return true; // We handled it
                  },
                  child: NotificationListener<NavigateUpNotification>(
                    onNotification: (notification) {
                      // RecordSection couldn't handle it (at start of section)
                      // Navigate to previous logical section (notes→todos, todos→prev day's notes)
                      _navigateUp(notification.date, notification.sectionType);
                      return true; // We handled it
                    },
                    child: CustomScrollView(
                  center: _todayKey,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    // Past days (before today) - lazy loaded
                    // Each day is rendered by DaySection widget (eliminates duplication)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // index 0 is yesterday, index 1 is 2 days ago, etc.
                          final daysAgo = index + 1;
                          final date = DateService.getDateForOffset(-daysAgo);

                          // REFACTORED: All day rendering logic moved to DaySection widget
                          // This eliminates 74 lines of duplicated code between past/future lists
                          return DaySection(
                            date: date,
                            recordsFuture: _getRecordsForDate(date),
                            getSectionKey: _getSectionKey,
                            onSave: _handleSaveRecord,
                            onDelete: _handleDeleteRecord,
                          );
                        }, // No childCount = infinite scrolling!
                      ),
                    ),
                    // Center anchor (today starts here)
                    SliverToBoxAdapter(
                      key: _todayKey,
                      child: const SizedBox.shrink(),
                    ),
                    // Today and future days - lazy loaded
                    // Each day is rendered by DaySection widget (eliminates duplication)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // index 0 is today, index 1 is tomorrow, etc.
                          final date = DateService.getDateForOffset(index);

                          // REFACTORED: All day rendering logic moved to DaySection widget
                          // This eliminates 74 lines of duplicated code between past/future lists
                          return DaySection(
                            date: date,
                            recordsFuture: _getRecordsForDate(date),
                            getSectionKey: _getSectionKey,
                            onSave: _handleSaveRecord,
                            onDelete: _handleDeleteRecord,
                          );
                        }, // No childCount = infinite scrolling!
                      ),
                    ),
                  ],
                ), // End CustomScrollView
                  ), // End NotificationListener<NavigateUpNotification>
                ), // End NotificationListener<NavigateDownNotification>
                ), // End DottedGridBackground
              ),
            );
          },
        ),
      ),
    );
  }
}
