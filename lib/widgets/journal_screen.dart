import 'package:flutter/material.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import 'day_section.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final RecordRepository _repository = RecordRepository();
  final ScrollController _scrollController = ScrollController();

  // Track which days are loaded
  int _earliestOffset = -3; // Today - 3 days
  int _latestOffset = 3; // Today + 3 days

  // Map of date -> records
  Map<String, List<Record>> _recordsByDate = {};

  bool _isLoadingPast = false;
  bool _isLoadingFuture = false;

  @override
  void initState() {
    super.initState();
    _loadInitialDays();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getDateForOffset(int offset) {
    final date = DateTime.now().add(Duration(days: offset));
    return _formatDateForDb(date);
  }

  String _formatDateForDb(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadInitialDays() async {
    final dates = List.generate(
      _latestOffset - _earliestOffset + 1,
      (i) => _getDateForOffset(_earliestOffset + i),
    );

    for (final date in dates) {
      final records = await _repository.getRecordsForDate(date);
      _recordsByDate[date] = records;
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadMorePastDays() async {
    if (_isLoadingPast) return;
    _isLoadingPast = true;

    final oldScrollExtent = _scrollController.position.maxScrollExtent;

    // Load 10 more days in the past
    final newEarliestOffset = _earliestOffset - 10;
    final dates = List.generate(
      10,
      (i) => _getDateForOffset(newEarliestOffset + i),
    );

    for (final date in dates) {
      final records = await _repository.getRecordsForDate(date);
      _recordsByDate[date] = records;
    }

    _earliestOffset = newEarliestOffset;

    if (mounted) {
      setState(() {});
      // Adjust scroll position to prevent jump
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newScrollExtent = _scrollController.position.maxScrollExtent;
        final delta = newScrollExtent - oldScrollExtent;
        _scrollController.jumpTo(_scrollController.offset + delta);
      });
    }

    _isLoadingPast = false;
  }

  Future<void> _loadMoreFutureDays() async {
    if (_isLoadingFuture) return;
    _isLoadingFuture = true;

    // Load 10 more days in the future
    final newLatestOffset = _latestOffset + 10;
    final dates = List.generate(
      10,
      (i) => _getDateForOffset(_latestOffset + 1 + i),
    );

    for (final date in dates) {
      final records = await _repository.getRecordsForDate(date);
      _recordsByDate[date] = records;
    }

    _latestOffset = newLatestOffset;

    if (mounted) setState(() {});

    _isLoadingFuture = false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 200) {
      _loadMorePastDays();
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreFutureDays();
    }
  }

  Future<void> _handleSaveRecord(Record record) async {
    // Determine if this is a new record (check if it exists in our map)
    final existingRecords = _recordsByDate[record.date] ?? [];
    final isNew = !existingRecords.any((r) => r.id == record.id);

    await _repository.saveRecord(record, isNew: isNew);

    // Update local state
    setState(() {
      final records = _recordsByDate[record.date] ?? [];
      final index = records.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        records[index] = record;
      } else {
        records.add(record);
      }
      _recordsByDate[record.date] = records;
    });
  }

  Future<void> _handleDeleteRecord(String recordId) async {
    await _repository.deleteRecord(recordId);

    // Update local state
    setState(() {
      for (final date in _recordsByDate.keys) {
        _recordsByDate[date] = _recordsByDate[date]!
            .where((r) => r.id != recordId)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Generate sorted list of dates
    final dates = List.generate(
      _latestOffset - _earliestOffset + 1,
      (i) => _getDateForOffset(_earliestOffset + i),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifelog'),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final date = dates[index];
                final records = _recordsByDate[date] ?? [];

                return DaySection(
                  key: ValueKey(date),
                  date: date,
                  records: records,
                  onSave: _handleSaveRecord,
                  onDelete: _handleDeleteRecord,
                );
              },
              childCount: dates.length,
            ),
          ),
        ],
      ),
    );
  }
}
