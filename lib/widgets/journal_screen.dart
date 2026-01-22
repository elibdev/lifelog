import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import '../utils/debouncer.dart';
import 'record_section.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final RecordRepository _repository = RecordRepository();
  final ScrollController _scrollController = ScrollController();

  // Map of date -> records (lazy loaded cache)
  final Map<String, List<Record>> _recordsByDate = {};

  // Map of record ID -> focus callback for navigation
  final Map<String, VoidCallback> _focusCallbacks = {};

  // Per-record debouncing for disk writes (optimistic UI pattern)
  final Map<String, Debouncer> _debouncers = {};

  // Date range to support (1 year in each direction)
  static const int daysBeforeToday = 365;
  static const int daysAfterToday = 365;

  final GlobalKey _todayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // No pre-loading - everything is lazy!
    // No scroll listener needed - SliverList handles lazy loading automatically
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Clean up all debouncers to prevent memory leaks
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    super.dispose();
  }

  String _formatDateHeader(String isoDate) {
    final dateTime = DateTime.parse(isoDate);
    return DateFormat('EEE, MMM d').format(dateTime);
  }

  bool _isToday(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // Get a flat ordered list of all record IDs currently loaded
  List<String> _getAllRecordIdsInOrder() {
    final List<String> ids = [];

    // Generate all loaded dates in order
    final allDates = <String>[];
    for (int i = daysBeforeToday; i >= 1; i--) {
      final date = _getDateForOffset(-i);
      if (_recordsByDate.containsKey(date)) allDates.add(date);
    }
    for (int i = 0; i < daysAfterToday; i++) {
      final date = _getDateForOffset(i);
      if (_recordsByDate.containsKey(date)) allDates.add(date);
    }

    // For each date, add todos then notes
    for (final date in allDates) {
      final records = _recordsByDate[date] ?? [];
      final todos = records.whereType<TodoRecord>().toList();
      final notes = records.whereType<NoteRecord>().toList();
      ids.addAll(todos.map((r) => r.id));
      ids.addAll(notes.map((r) => r.id));
    }

    return ids;
  }

  void _handleNavigate(String currentRecordId, int direction) {
    final allIds = _getAllRecordIdsInOrder();
    final currentIndex = allIds.indexOf(currentRecordId);

    if (currentIndex == -1) return;

    final targetIndex = currentIndex + direction;
    if (targetIndex < 0 || targetIndex >= allIds.length) return;

    final targetId = allIds[targetIndex];
    final focusCallback = _focusCallbacks[targetId];
    focusCallback?.call();
  }

  String _formatDateForDb(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDateForOffset(int offsetFromToday) {
    final date = DateTime.now().add(Duration(days: offsetFromToday));
    return _formatDateForDb(date);
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
      // Use theme's surface color for background (warm cream on larger screens)
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
            final double maxWidth = isDesktop ? 700 : (isTablet ? 600 : double.infinity);

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                // Paper shadow effect on desktop (subtle depth)
                decoration: isDesktop ? BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ) : null,
                child: CustomScrollView(
                  controller: _scrollController,
                  center: _todayKey,
                  slivers: [
            // Past days (before today) - lazy loaded
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // index 0 is yesterday, index 1 is 2 days ago, etc.
                  final daysAgo = index + 1;
                  final date = _getDateForOffset(-daysAgo);

                  return FutureBuilder<List<Record>>(
                    future: _getRecordsForDate(date),
                    builder: (context, snapshot) {
                      final records = snapshot.data ?? [];
                      final todos = records.whereType<TodoRecord>().toList();
                      final notes = records.whereType<NoteRecord>().toList();

                      final isToday = _isToday(date);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header - highlighted if today
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: isToday
                                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                                    : EdgeInsets.zero,
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      )
                                    : null,
                                child: Text(
                                  isToday ? 'Today • ${_formatDateHeader(date)}' : _formatDateHeader(date),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                                        color: isToday
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          // Records
                          RecordSection(
                            key: ValueKey('$date-todos'),
                            title: 'TODOS',
                            records: todos,
                            date: date,
                            recordType: 'todo',
                            onSave: _handleSaveRecord,
                            onDelete: _handleDeleteRecord,
                            onNavigate: _handleNavigate,
                          ),
                          RecordSection(
                            key: ValueKey('$date-notes'),
                            title: 'NOTES',
                            records: notes,
                            date: date,
                            recordType: 'note',
                            onSave: _handleSaveRecord,
                            onDelete: _handleDeleteRecord,
                            onNavigate: _handleNavigate,
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  );
                },
                childCount: daysBeforeToday,
              ),
            ),
            // Center anchor (today starts here)
            SliverToBoxAdapter(key: _todayKey, child: const SizedBox.shrink()),
            // Today and future days - lazy loaded
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // index 0 is today, index 1 is tomorrow, etc.
                  final date = _getDateForOffset(index);

                  return FutureBuilder<List<Record>>(
                    future: _getRecordsForDate(date),
                    builder: (context, snapshot) {
                      final records = snapshot.data ?? [];
                      final todos = records.whereType<TodoRecord>().toList();
                      final notes = records.whereType<NoteRecord>().toList();

                      final isToday = _isToday(date);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header - highlighted if today
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: isToday
                                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                                    : EdgeInsets.zero,
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      )
                                    : null,
                                child: Text(
                                  isToday ? 'Today • ${_formatDateHeader(date)}' : _formatDateHeader(date),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                                        color: isToday
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            ),
                          ),
                          // Records
                          RecordSection(
                            key: ValueKey('$date-todos'),
                            title: 'TODOS',
                            records: todos,
                            date: date,
                            recordType: 'todo',
                            onSave: _handleSaveRecord,
                            onDelete: _handleDeleteRecord,
                            onNavigate: _handleNavigate,
                          ),
                          RecordSection(
                            key: ValueKey('$date-notes'),
                            title: 'NOTES',
                            records: notes,
                            date: date,
                            recordType: 'note',
                            onSave: _handleSaveRecord,
                            onDelete: _handleDeleteRecord,
                            onNavigate: _handleNavigate,
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  );
                },
                childCount: daysAfterToday,
              ),
            ),
          ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
