import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import '../utils/debouncer.dart';
import 'record_section.dart';

// Helper class for focus registry - tracks text field FocusNodes across sections
class _FocusNodeEntry {
  final DateTime date;
  final String sectionType; // 'todo' or 'note' to maintain correct section order
  final int index;
  final String recordId;
  final FocusNode node;

  _FocusNodeEntry(this.date, this.sectionType, this.index, this.recordId, this.node);
}

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

  // Global focus registry for arrow key navigation (text fields only)
  final List<_FocusNodeEntry> _textFieldFocusNodes = [];

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

  // FOCUS REGISTRY: Register a text field FocusNode for arrow navigation
  void _registerFocusNode(DateTime date, String sectionType, int index, String recordId, FocusNode node) {
    // Remove existing entry for this record (handles rebuilds)
    _textFieldFocusNodes.removeWhere((e) => e.recordId == recordId);

    // Add new entry
    _textFieldFocusNodes.add(_FocusNodeEntry(date, sectionType, index, recordId, node));

    // Sort by visual order (date, then section, then index within section)
    _sortFocusNodes();
  }

  // FOCUS REGISTRY: Unregister a FocusNode when widget is disposed
  void _unregisterFocusNode(String recordId) {
    _textFieldFocusNodes.removeWhere((e) => e.recordId == recordId);
  }

  // FOCUS REGISTRY: Sort nodes by visual order for correct navigation
  void _sortFocusNodes() {
    _textFieldFocusNodes.sort((a, b) {
      // Sort by date first (chronological order)
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      // Then by section type (todos before notes)
      final sectionOrder = {'todo': 0, 'note': 1};
      final sectionCompare = (sectionOrder[a.sectionType] ?? 0).compareTo(sectionOrder[b.sectionType] ?? 0);
      if (sectionCompare != 0) return sectionCompare;

      // Finally by index within the same section
      return a.index.compareTo(b.index);
    });
  }

  // ARROW KEY NAVIGATION: Move to previous text field (skips checkboxes)
  void _focusPreviousTextField(FocusNode currentNode) {
    final index = _textFieldFocusNodes.indexWhere((e) => e.node == currentNode);
    if (index > 0) {
      _textFieldFocusNodes[index - 1].node.requestFocus();
    }
    // At top - stay in place
  }

  // ARROW KEY NAVIGATION: Move to next text field (skips checkboxes)
  void _focusNextTextField(FocusNode currentNode) {
    final index = _textFieldFocusNodes.indexWhere((e) => e.node == currentNode);
    if (index >= 0 && index < _textFieldFocusNodes.length - 1) {
      _textFieldFocusNodes[index + 1].node.requestFocus();
    }
    // At bottom - stay in place
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                                      8.0, // Reduced from 12.0
                                    ),
                                    child: Text(
                                      isToday
                                          ? 'Today • ${_formatDateHeader(date)}'
                                          : _formatDateHeader(date),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
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
                                    // Focus management callbacks
                                    onFocusNodeCreated: (int index, String recordId, FocusNode node) {
                                      _registerFocusNode(DateTime.parse(date), 'todo', index, recordId, node);
                                    },
                                    onFocusNodeDisposed: _unregisterFocusNode,
                                    onArrowUp: _focusPreviousTextField,
                                    onArrowDown: _focusNextTextField,
                                  ),
                                  RecordSection(
                                    key: ValueKey('$date-notes'),
                                    title: 'NOTES',
                                    records: notes,
                                    date: date,
                                    recordType: 'note',
                                    onSave: _handleSaveRecord,
                                    onDelete: _handleDeleteRecord,
                                    // Focus management callbacks
                                    onFocusNodeCreated: (int index, String recordId, FocusNode node) {
                                      _registerFocusNode(DateTime.parse(date), 'note', index, recordId, node);
                                    },
                                    onFocusNodeDisposed: _unregisterFocusNode,
                                    onArrowUp: _focusPreviousTextField,
                                    onArrowDown: _focusNextTextField,
                                  ),
                                ],
                              );
                            },
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
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                                      8.0, // Reduced from 12.0
                                    ),
                                    child: Text(
                                      isToday
                                          ? 'Today • ${_formatDateHeader(date)}'
                                          : _formatDateHeader(date),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
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
                                    // Focus management callbacks
                                    onFocusNodeCreated: (int index, String recordId, FocusNode node) {
                                      _registerFocusNode(DateTime.parse(date), 'todo', index, recordId, node);
                                    },
                                    onFocusNodeDisposed: _unregisterFocusNode,
                                    onArrowUp: _focusPreviousTextField,
                                    onArrowDown: _focusNextTextField,
                                  ),
                                  RecordSection(
                                    key: ValueKey('$date-notes'),
                                    title: 'NOTES',
                                    records: notes,
                                    date: date,
                                    recordType: 'note',
                                    onSave: _handleSaveRecord,
                                    onDelete: _handleDeleteRecord,
                                    // Focus management callbacks
                                    onFocusNodeCreated: (int index, String recordId, FocusNode node) {
                                      _registerFocusNode(DateTime.parse(date), 'note', index, recordId, node);
                                    },
                                    onFocusNodeDisposed: _unregisterFocusNode,
                                    onArrowUp: _focusPreviousTextField,
                                    onArrowDown: _focusNextTextField,
                                  ),
                                ],
                              );
                            },
                          );
                        }, // No childCount = infinite scrolling!
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
