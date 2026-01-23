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

  // Map of date -> records (lazy loaded cache)
  final Map<String, List<Record>> _recordsByDate = {};

  // Per-record debouncing for disk writes (optimistic UI pattern)
  final Map<String, Debouncer> _debouncers = {};

  // No date range limits - truly infinite scrolling!

  final GlobalKey _todayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // No pre-loading - everything is lazy!
    // No scroll listener needed - SliverList handles lazy loading automatically
  }

  @override
  void dispose() {
    // Clean up all debouncers to prevent memory leaks
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    super.dispose();
  }

  String _formatDateHeader(String isoDate) {
    final dateTime = DateTime.parse(isoDate);
    // Always show year for clarity (e.g., "Mon, Jan 23, 2025")
    return DateFormat('EEE, MMM d, y').format(dateTime);
  }

  bool _isToday(String isoDate) {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
                // No decorations - just responsive width constraints
                child: CustomScrollView(
                  center: _todayKey,
                  slivers: [
                    // Past days (before today) - lazy loaded
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        // index 0 is yesterday, index 1 is 2 days ago, etc.
                        final daysAgo = index + 1;
                        final date = _getDateForOffset(-daysAgo);

                        return FutureBuilder<List<Record>>(
                          future: _getRecordsForDate(date),
                          builder: (context, snapshot) {
                            final records = snapshot.data ?? [];
                            final todos = records
                                .whereType<TodoRecord>()
                                .toList();
                            final notes = records
                                .whereType<NoteRecord>()
                                .toList();

                            final isToday = _isToday(date);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date header - compact spacing for information density
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    16.0, // Reduced from 24.0
                                    16.0,
                                    8.0,  // Reduced from 12.0
                                  ),
                                  child: Text(
                                    isToday
                                        ? 'Today • ${_formatDateHeader(date)}'
                                        : _formatDateHeader(date),
                                    style: Theme.of(context).textTheme.titleMedium,
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
                                ),
                                RecordSection(
                                  key: ValueKey('$date-notes'),
                                  title: 'NOTES',
                                  records: notes,
                                  date: date,
                                  recordType: 'note',
                                  onSave: _handleSaveRecord,
                                  onDelete: _handleDeleteRecord,
                                ),
                                const SizedBox(height: 24), // Reduced from 32 for compactness
                              ],
                            );
                          },
                        );
                      } // No childCount = infinite scrolling!
                      ),
                    ),
                    // Center anchor (today starts here)
                    SliverToBoxAdapter(
                      key: _todayKey,
                      child: const SizedBox.shrink(),
                    ),
                    // Today and future days - lazy loaded
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        // index 0 is today, index 1 is tomorrow, etc.
                        final date = _getDateForOffset(index);

                        return FutureBuilder<List<Record>>(
                          future: _getRecordsForDate(date),
                          builder: (context, snapshot) {
                            final records = snapshot.data ?? [];
                            final todos = records
                                .whereType<TodoRecord>()
                                .toList();
                            final notes = records
                                .whereType<NoteRecord>()
                                .toList();

                            final isToday = _isToday(date);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date header - compact spacing for information density
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    16.0, // Reduced from 24.0
                                    16.0,
                                    8.0,  // Reduced from 12.0
                                  ),
                                  child: Text(
                                    isToday
                                        ? 'Today • ${_formatDateHeader(date)}'
                                        : _formatDateHeader(date),
                                    style: Theme.of(context).textTheme.titleMedium,
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
                                ),
                                RecordSection(
                                  key: ValueKey('$date-notes'),
                                  title: 'NOTES',
                                  records: notes,
                                  date: date,
                                  recordType: 'note',
                                  onSave: _handleSaveRecord,
                                  onDelete: _handleDeleteRecord,
                                ),
                                const SizedBox(height: 24), // Reduced from 32 for compactness
                              ],
                            );
                          },
                        );
                      } // No childCount = infinite scrolling!
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
