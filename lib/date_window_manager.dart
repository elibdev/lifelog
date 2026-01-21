import 'dart:async';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'state/journal_state_registry.dart';

/// Manages the "window" of visible dates for virtual scrolling
/// Tracks scroll position and maintains a buffer of dates around the visible area
class DateWindowManager extends ChangeNotifier {
  final ScrollController scrollController;
  final DateTime anchorDate; // The "today" date used as reference
  final int bufferDays; // Number of days to keep in buffer beyond visible
  final JournalDatabase? database;
  final JournalStateRegistry? stateRegistry;

  Set<DateTime> _windowDates = {};
  Timer? _updateDebounce;
  Timer? _prefetchDebounce;

  // Estimated dimensions for scroll calculations
  static const double estimatedHeaderHeight = 50.0;
  static const double estimatedContentHeight = 100.0;
  static const double estimatedDateHeight = estimatedHeaderHeight + estimatedContentHeight;

  DateWindowManager({
    required this.scrollController,
    required this.anchorDate,
    this.bufferDays = 10,
    this.database,
    this.stateRegistry,
  }) {
    scrollController.addListener(_onScroll);
    _updateWindow();
  }

  Set<DateTime> get windowDates => _windowDates;

  /// Get a sorted list of dates in the window
  List<DateTime> get sortedWindowDates {
    final list = _windowDates.toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  void _onScroll() {
    // Debounce updates to avoid excessive recalculations
    _updateDebounce?.cancel();
    _updateDebounce = Timer(const Duration(milliseconds: 100), () {
      _updateWindow();
    });
  }

  void _updateWindow() {
    final oldWindow = _windowDates;

    // Calculate the estimated visible date range based on scroll offset
    final offset = scrollController.hasClients ? scrollController.offset : 0.0;
    final viewportHeight = scrollController.hasClients
        ? scrollController.position.viewportDimension
        : 800.0; // Default viewport height

    // Estimate which date index is at the top of the viewport
    // Negative offset means we're scrolling into past dates
    final estimatedCenterIndex = (offset / estimatedDateHeight).round();

    // Calculate how many dates are visible in the viewport
    final visibleDateCount = (viewportHeight / estimatedDateHeight).ceil();

    // Calculate the range of dates to include in the window (visible + buffer)
    final startIndex = estimatedCenterIndex - visibleDateCount - bufferDays;
    final endIndex = estimatedCenterIndex + visibleDateCount + bufferDays;

    // Generate the new window of dates
    final newWindow = <DateTime>{};
    for (int i = startIndex; i <= endIndex; i++) {
      // Positive i = future dates, negative i = past dates, 0 = anchor (today)
      final date = anchorDate.add(Duration(days: -i));
      newWindow.add(_normalizeDate(date));
    }

    // Only notify listeners if the window actually changed
    if (!_setsEqual(oldWindow, newWindow)) {
      _windowDates = newWindow;
      notifyListeners();

      // Trigger prefetch after scroll settles
      _schedulePrefetch();
    }
  }

  void _schedulePrefetch() {
    if (database == null || stateRegistry == null) return;

    // Debounce prefetch to wait for scroll to settle
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(const Duration(milliseconds: 200), () {
      _prefetchWindowData();
    });
  }

  Future<void> _prefetchWindowData() async {
    if (database == null || stateRegistry == null || _windowDates.isEmpty) {
      return;
    }

    try {
      // Find the date range for the window
      final sortedDates = _windowDates.toList()..sort();
      final startDate = sortedDates.first;
      final endDate = sortedDates.last;

      // Batch query for all records in the date range
      final recordsByDate = await database!.getRecordsForDateRange(
        startDate,
        endDate,
      );

      // Update state managers with batch data
      for (final date in _windowDates) {
        final dateKey = database!.dateKey(date);
        final records = recordsByDate[dateKey] ?? [];

        // Get or create manager and load from batch
        final manager = stateRegistry!.getOrCreateManager(date);
        manager.loadFromBatch(records);
      }
    } catch (e) {
      // Silently fail - individual managers will fall back to regular load
      debugPrint('Prefetch failed: $e');
    }
  }

  /// Normalize a date to midnight (ignore time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if two sets are equal
  bool _setsEqual(Set<DateTime> a, Set<DateTime> b) {
    if (a.length != b.length) return false;
    return a.every((date) => b.contains(date));
  }

  /// Force an immediate window update (useful after initial render)
  void forceUpdate() {
    _updateWindow();
  }

  @override
  void dispose() {
    _updateDebounce?.cancel();
    _prefetchDebounce?.cancel();
    scrollController.removeListener(_onScroll);
    super.dispose();
  }
}
