import 'package:flutter/material.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import '../notifications/navigation_notifications.dart';
import '../services/date_service.dart';
import '../utils/debouncer.dart';
import 'record_section.dart';
import 'day_section.dart';
import 'search_screen.dart';

/// The main journal view — infinite scroll centered on today.
///
/// Uses CustomScrollView with a `center` key so the user can scroll
/// both into the past (upward) and future (downward). Each day gets
/// a DaySection with a Swiss-style date header and thin rule divider.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  RecordRepository get _repository => widget.repository;

  final Map<String, List<Record>> _recordsByDate = {};
  final Map<String, Debouncer> _debouncers = {};
  final Map<String, GlobalKey<RecordSectionState>> _sectionKeys = {};
  final GlobalKey _todayKey = GlobalKey();

  GlobalKey<RecordSectionState> _getSectionKey(String date) {
    return _sectionKeys.putIfAbsent(
        date, () => GlobalKey<RecordSectionState>());
  }

  void _navigateDown(String date, String sectionType) {
    final nextDate = DateService.getNextDate(date);
    _getSectionKey(nextDate).currentState?.focusFirstRecord();
  }

  void _navigateUp(String date, String sectionType) {
    final prevDate = DateService.getPreviousDate(date);
    _getSectionKey(prevDate).currentState?.focusLastRecord();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final today = DateService.today();
    await _getRecordsForDate(today);
    if (mounted) setState(() {});
  }

  Future<List<Record>> _getRecordsForDate(String date) async {
    if (_recordsByDate.containsKey(date)) {
      return _recordsByDate[date]!;
    }
    final records = await _repository.getRecordsForDate(date);
    _recordsByDate[date] = records;
    return records;
  }

  Future<void> _handleSaveRecord(Record record) async {
    setState(() {
      final records = _recordsByDate[record.date] ?? [];
      final index = records.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        records[index] = record;
      } else {
        records.add(record);
      }
      records.sort((a, b) => a.orderPosition.compareTo(b.orderPosition));
      _recordsByDate[record.date] = records;
    });

    final debouncer =
        _debouncers.putIfAbsent(record.id, () => Debouncer());
    debouncer.call(() async {
      try {
        await _repository.saveRecord(record);
      } catch (_) {
        // C3: surface DB failures — in-memory state already updated optimistically
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save — check available storage'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<void> _handleDeleteRecord(String recordId) async {
    _debouncers[recordId]?.dispose();
    _debouncers.remove(recordId);

    setState(() {
      for (final date in _recordsByDate.keys) {
        _recordsByDate[date] = _recordsByDate[date]!
            .where((r) => r.id != recordId)
            .toList();
      }
    });

    try {
      await _repository.deleteRecord(recordId);
    } catch (_) {
      // C3: surface DB failures — in-memory state already updated optimistically
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete — check available storage'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Search FAB — uses design system's FAB theme (dark, rounded)
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchScreen(repository: _repository),
            ),
          );
        },
        tooltip: 'Search',
        child: const Icon(Icons.search, size: 20),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final bool isDesktop = screenWidth > 900;
            final bool isTablet = screenWidth >= 600 && screenWidth <= 900;
            // Content max-width keeps lines readable — Swiss grid principle
            final double maxWidth =
                isDesktop ? 680 : (isTablet ? 580 : double.infinity);

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: NotificationListener<NavigateDownNotification>(
                  onNotification: (notification) {
                    _navigateDown(
                        notification.date, notification.sectionType);
                    return true;
                  },
                  child: NotificationListener<NavigateUpNotification>(
                    onNotification: (notification) {
                      _navigateUp(
                          notification.date, notification.sectionType);
                      return true;
                    },
                    child: CustomScrollView(
                      center: _todayKey,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        // Past days (scroll up)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final daysAgo = index + 1;
                              final date =
                                  DateService.getDateForOffset(-daysAgo);
                              return DaySection(
                                date: date,
                                recordsFuture: _getRecordsForDate(date),
                                getSectionKey: _getSectionKey,
                                onSave: _handleSaveRecord,
                                onDelete: _handleDeleteRecord,
                              );
                            },
                          ),
                        ),
                        // Today anchor
                        SliverToBoxAdapter(
                          key: _todayKey,
                          child: const SizedBox.shrink(),
                        ),
                        // Today and future days (scroll down)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final date =
                                  DateService.getDateForOffset(index);
                              return DaySection(
                                date: date,
                                recordsFuture: _getRecordsForDate(date),
                                getSectionKey: _getSectionKey,
                                onSave: _handleSaveRecord,
                                onDelete: _handleDeleteRecord,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
