import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'daily_sliver_group.dart';
import 'date_window_manager.dart';
import 'database_helper.dart';
import 'state/journal_state_registry.dart';

class JournalHomePage extends StatefulWidget {
  const JournalHomePage({super.key});

  @override
  State<JournalHomePage> createState() => _JournalHomePageState();
}

class _JournalHomePageState extends State<JournalHomePage> {
  final Key centerKey = const ValueKey('today-key');
  late final ScrollController _scrollController;
  late final DateWindowManager _windowManager;
  late final DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _scrollController = ScrollController();

    // Get registry and database from context
    final registry = context.read<JournalStateRegistry>();
    final database = JournalDatabase.instance;

    _windowManager = DateWindowManager(
      scrollController: _scrollController,
      anchorDate: _today,
      bufferDays: 10,
      database: database,
      stateRegistry: registry,
    );

    // Listen to window changes to rebuild the list
    _windowManager.addListener(_onWindowChanged);
  }

  @override
  void dispose() {
    _windowManager.removeListener(_onWindowChanged);
    _windowManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onWindowChanged() {
    // Clean up old managers outside the active window
    final registry = context.read<JournalStateRegistry>();
    registry.cleanupOldManagers(_windowManager.windowDates);

    setState(() {
      // Rebuild when window changes
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(_today.year, _today.month, _today.day);
    final sortedDates = _windowManager.sortedWindowDates;

    // Split dates into past and future around today
    final pastDates = sortedDates.where((d) => d.isBefore(today)).toList().reversed.toList();
    final futureDates = sortedDates.where((d) => d.isAfter(today)).toList();
    final hasToday = sortedDates.any((d) => d.isAtSameMomentAs(today));

    return Scaffold(
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          center: centerKey,
          slivers: [
            // The Past (Scrolling Up) - reversed order
            SliverList.builder(
              itemCount: pastDates.length,
              itemBuilder: (context, index) {
                return DailySliverGroup(date: pastDates[index]);
              },
            ),

            // Today (The Center Anchor)
            if (hasToday)
              DailySliverGroup(key: centerKey, date: today)
            else
              SliverToBoxAdapter(key: centerKey, child: const SizedBox.shrink()),

            // The Future (Scrolling Down)
            SliverList.builder(
              itemCount: futureDates.length,
              itemBuilder: (context, index) {
                return DailySliverGroup(date: futureDates[index]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
