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

// M7: WidgetsBindingObserver lets the State listen for app lifecycle changes
// (foreground, background, paused) so we can flush pending debouncers before
// the process might be killed. Mix it in alongside State<T>.
// See: https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html
class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  // widget.repository accesses the StatefulWidget's fields from its State.
  // Flutter keeps State alive across rebuilds; widget ref always points to current.
  // See: https://api.flutter.dev/flutter/widgets/State/widget.html
  RecordRepository get _repository => widget.repository;

  final Map<String, List<Record>> _recordsByDate = {};
  // P6: Track insertion order for LRU eviction — LinkedHashMap iteration is
  // insertion-ordered, so removing+reinserting moves an entry to the "newest" end.
  final List<String> _cachedDateOrder = [];
  static const int _maxCachedDates = 30;

  final Map<String, Debouncer> _debouncers = {};

  // One GlobalKey per date (simplified from date+type with old two-section pattern)
  final Map<String, GlobalKey<RecordSectionState>> _sectionKeys = {};
  final GlobalKey _todayKey = GlobalKey();

  // M6: ScrollController lets us read offset to show/hide the "today" button.
  late final ScrollController _scrollController;
  bool _showTodayButton = false;

  // M2: Save feedback — true for 1.5s after each successful debounced write.
  bool _showSaved = false;
  Timer? _savedTimer;

  GlobalKey<RecordSectionState> _getSectionKey(String date) {
    return _sectionKeys.putIfAbsent(
        date, () => GlobalKey<RecordSectionState>());
  }

  void _navigateDown(String date) => _focusAdjacentDay(
        DateService.getNextDate(date),
        focus: (s) => s.focusFirstRecord(),
      );

  void _navigateUp(String date) => _focusAdjacentDay(
        DateService.getPreviousDate(date),
        focus: (s) => s.focusLastRecord(),
      );

  // M3: Pre-load adjacent day's data so it's cached when DaySection renders,
  // then post-frame retry handles the focus if the section was off-screen.
  void _focusAdjacentDay(
    String date, {
    required void Function(RecordSectionState) focus,
  }) {
    final state = _getSectionKey(date).currentState;
    if (state != null) {
      focus(state);
    } else {
      _getRecordsForDate(date).then((_) {
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final s = _getSectionKey(date).currentState;
          if (s != null) focus(s);
        });
      });
    }
  }

  // M6: Pre-load records for a date, then attempt to scroll to it via
  // Scrollable.ensureVisible. Works for dates already rendered in the SliverList;
  // for dates far off-screen, a SnackBar informs the user what to scroll to.
  Future<void> _scrollToDate(String date) async {
    await _getRecordsForDate(date);
    if (!mounted) return;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _getSectionKey(date);
      final sectionContext = key.currentContext;
      if (sectionContext != null) {
        // Scrollable.ensureVisible walks up the tree to find the nearest
        // scrollable ancestor and animates until the widget is visible.
        // See: https://api.flutter.dev/flutter/widgets/Scrollable/ensureVisible.html
        Scrollable.ensureVisible(
          sectionContext,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else {
        // Date is too far off-screen to render — inform the user.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scroll to ${DateService.formatForDisplay(date)} to see your entry',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // M7: Register this State as a lifecycle observer.
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadInitialData();
  }

  // M7: didChangeAppLifecycleState fires when the user backgrounds the app.
  // Flush all pending debouncers so in-flight keystrokes are persisted before
  // the OS might kill the process.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      for (final debouncer in _debouncers.values) {
        debouncer.flush();
      }
    }
  }

  // M6: Show the "today" button whenever the scroll offset is non-zero
  // (user has scrolled away from the today anchor in either direction).
  void _onScroll() {
    final away = _scrollController.offset.abs() > 200;
    if (away != _showTodayButton) {
      setState(() => _showTodayButton = away);
    }
  }

  // M6: Jump back to the today anchor.
  void _scrollToToday() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
      // P6: Move this date to the end of the LRU order (most recently accessed).
      _cachedDateOrder.remove(date);
      _cachedDateOrder.add(date);
      return _recordsByDate[date]!;
    }

    final records = await _repository.getRecordsForDate(date);
    _recordsByDate[date] = records;
    _cachedDateOrder.add(date);

    // P6: Evict the oldest entry when the cache exceeds the limit.
    if (_cachedDateOrder.length > _maxCachedDates) {
      final oldest = _cachedDateOrder.removeAt(0);
      _recordsByDate.remove(oldest);
      // Discard the section key too — it will be recreated on next access.
      _sectionKeys.remove(oldest);
    }

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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'search',
            onPressed: () async {
              // M1: await the pop result — SearchScreen returns the tapped date string.
              // Typed push: Navigator.push<String> enforces the return type at compile time.
              final date = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => SearchScreen(repository: _repository),
                ),
              );
              if (date != null && mounted) {
                _scrollToDate(date);
              }
            },
            tooltip: 'Search',
            child: const Icon(Icons.search),
          ),
          // M6: Scroll-to-today button — only visible when user has scrolled away.
          // AnimatedSize smoothly collapses/expands the button.
          // See: https://api.flutter.dev/flutter/widgets/AnimatedSize-class.html
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _showTodayButton
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FloatingActionButton.small(
                      heroTag: 'today',
                      onPressed: _scrollToToday,
                      tooltip: 'Jump to today',
                      child: const Icon(Icons.today),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
                          controller: _scrollController,
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
                      // P5: 1px border makes the badge visible in dark mode where
                      // surfaceContainerHighest blends into the dark background.
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
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
