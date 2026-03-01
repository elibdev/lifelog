import 'dart:async';
import 'package:flutter/material.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import 'package:lifelog_reference/notifications/navigation_notifications.dart';
import 'package:lifelog_reference/services/date_service.dart';
import 'package:lifelog_reference/utils/debouncer.dart';
import 'record_section.dart';
import 'day_section.dart';
import 'search_screen.dart';

class JournalScreen extends StatefulWidget {
  // Repository injected at construction so Widgetbook can pass a mock.
  // `required` is a Dart named-parameter modifier — the caller must supply it.
  // See: https://dart.dev/language/functions#named-parameters
  const JournalScreen({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  // widget.repository accesses the StatefulWidget's fields from its State.
  // Flutter keeps State alive across rebuilds; widget ref always points to current.
  // See: https://api.flutter.dev/flutter/widgets/State/widget.html
  RecordRepository get _repository => widget.repository;

  final Map<String, List<Record>> _recordsByDate = {};
  final Map<String, Debouncer> _debouncers = {};

  // One GlobalKey per date (simplified from date+type with old two-section pattern)
  final Map<String, GlobalKey<RecordSectionState>> _sectionKeys = {};
  final GlobalKey _todayKey = GlobalKey();

  // M2: Save feedback — true for 1.5s after each successful debounced write.
  bool _showSaved = false;
  Timer? _savedTimer;

  GlobalKey<RecordSectionState> _getSectionKey(String date) {
    return _sectionKeys.putIfAbsent(
        date, () => GlobalKey<RecordSectionState>());
  }

  // M3: Pre-load adjacent day's data so it's cached when DaySection renders,
  // then post-frame retry handles the focus if the section was off-screen.
  void _navigateDown(String date) {
    final nextDate = DateService.getNextDate(date);
    final state = _getSectionKey(nextDate).currentState;
    if (state != null) {
      state.focusFirstRecord();
    } else {
      _getRecordsForDate(nextDate).then((_) {
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _getSectionKey(nextDate).currentState?.focusFirstRecord();
        });
      });
    }
  }

  void _navigateUp(String date) {
    final prevDate = DateService.getPreviousDate(date);
    final state = _getSectionKey(prevDate).currentState;
    if (state != null) {
      state.focusLastRecord();
    } else {
      _getRecordsForDate(prevDate).then((_) {
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _getSectionKey(prevDate).currentState?.focusLastRecord();
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    for (final debouncer in _debouncers.values) {
      debouncer.dispose();
    }
    super.dispose();
  }

  // M2: Show "Saved" badge briefly after each successful write.
  void _flashSaved() {
    _savedTimer?.cancel();
    setState(() => _showSaved = true);
    _savedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSaved = false);
    });
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
        // M2: Confirm the write succeeded with a brief badge.
        if (mounted) _flashSaved();
      } catch (_) {
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
    final theme = Theme.of(context);

    return Scaffold(
      // M7: endTop keeps the search FAB out of the writing area at the bottom.
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
            builder: (_) => SearchScreen(repository: _repository),
          ),
          );
        },
        tooltip: 'Search',
        child: const Icon(Icons.search),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final bool isDesktop = screenWidth > 900;
                final bool isTablet = screenWidth >= 600 && screenWidth <= 900;
                final double maxWidth =
                    isDesktop ? 700 : (isTablet ? 600 : double.infinity);

                return Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: NotificationListener<NavigateDownNotification>(
                      onNotification: (notification) {
                        _navigateDown(notification.date);
                        return true;
                      },
                      child: NotificationListener<NavigateUpNotification>(
                        onNotification: (notification) {
                          _navigateUp(notification.date);
                          return true;
                        },
                        child: CustomScrollView(
                          center: _todayKey,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
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
                            SliverToBoxAdapter(
                              key: _todayKey,
                              child: const SizedBox.shrink(),
                            ),
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
          // M2: "Saved" badge — fades in after write succeeds, out after 1.5s.
          // Positioned bottom-center to avoid clashing with the top-right FAB.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: _showSaved ? 1.0 : 0.0,
                // AnimatedOpacity cross-fades between opacity values; duration
                // controls how long the fade takes.
                // See: https://api.flutter.dev/flutter/widgets/AnimatedOpacity-class.html
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Saved',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
