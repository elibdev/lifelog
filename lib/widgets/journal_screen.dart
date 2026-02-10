import 'package:flutter/material.dart';
import '../models/block.dart';
import '../database/block_repository.dart';
import '../notifications/navigation_notifications.dart';
import '../services/date_service.dart';
import '../utils/debouncer.dart';
import 'block_section.dart';
import 'day_section.dart';
import 'search_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final BlockRepository _repository = BlockRepository();

  // Map of date -> blocks (lazy loaded cache)
  final Map<String, List<Block>> _blocksByDate = {};

  // Per-block debouncing for disk writes (optimistic UI pattern)
  final Map<String, Debouncer> _debouncers = {};

  // CROSS-DAY NAVIGATION: one GlobalKey per date (simplified from date+type)
  // With blocks, there is only one section per day instead of two.
  final Map<String, GlobalKey<BlockSectionState>> _sectionKeys = {};

  final GlobalKey _todayKey = GlobalKey();

  // Get or create a GlobalKey for a specific day's BlockSection
  GlobalKey<BlockSectionState> _getSectionKey(String date) {
    return _sectionKeys.putIfAbsent(date, () => GlobalKey<BlockSectionState>());
  }

  // Navigation simplified: one section per day means just next/prev day
  void _navigateDown(String date, String sectionType) {
    final nextDate = DateService.getNextDate(date);
    _getSectionKey(nextDate).currentState?.focusFirstBlock();
  }

  void _navigateUp(String date, String sectionType) {
    final prevDate = DateService.getPreviousDate(date);
    _getSectionKey(prevDate).currentState?.focusLastBlock();
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
    await _getBlocksForDate(today);
    if (mounted) setState(() {});
  }

  Future<List<Block>> _getBlocksForDate(String date) async {
    if (_blocksByDate.containsKey(date)) {
      return _blocksByDate[date]!;
    }

    final blocks = await _repository.getBlocksForDate(date);
    _blocksByDate[date] = blocks;
    return blocks;
  }

  Future<void> _handleSaveBlock(Block block) async {
    // Optimistic UI: update cache immediately
    setState(() {
      final blocks = _blocksByDate[block.date] ?? [];
      final index = blocks.indexWhere((b) => b.id == block.id);
      if (index >= 0) {
        blocks[index] = block;
      } else {
        blocks.add(block);
      }
      blocks.sort((a, b) => a.orderPosition.compareTo(b.orderPosition));
      _blocksByDate[block.date] = blocks;
    });

    // Debounced disk write
    final debouncer = _debouncers.putIfAbsent(block.id, () => Debouncer());
    debouncer.call(() async {
      await _repository.saveBlock(block);
    });
  }

  Future<void> _handleDeleteBlock(String blockId) async {
    _debouncers[blockId]?.dispose();
    _debouncers.remove(blockId);

    setState(() {
      for (final date in _blocksByDate.keys) {
        _blocksByDate[date] = _blocksByDate[date]!
            .where((b) => b.id != blockId)
            .toList();
      }
    });

    await _repository.deleteBlock(blockId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Search button floats over the journal
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        },
        tooltip: 'Search',
        child: const Icon(Icons.search),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final bool isDesktop = screenWidth > 900;
            final bool isTablet = screenWidth >= 600 && screenWidth <= 900;
            final double maxWidth = isDesktop
                ? 700
                : (isTablet ? 600 : double.infinity);

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: NotificationListener<NavigateDownNotification>(
                  onNotification: (notification) {
                    _navigateDown(notification.date, notification.sectionType);
                    return true;
                  },
                  child: NotificationListener<NavigateUpNotification>(
                    onNotification: (notification) {
                      _navigateUp(notification.date, notification.sectionType);
                      return true;
                    },
                    child: CustomScrollView(
                      center: _todayKey,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        // Past days (before today)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final daysAgo = index + 1;
                              final date =
                                  DateService.getDateForOffset(-daysAgo);
                              return DaySection(
                                date: date,
                                blocksFuture: _getBlocksForDate(date),
                                getSectionKey: _getSectionKey,
                                onSave: _handleSaveBlock,
                                onDelete: _handleDeleteBlock,
                              );
                            },
                          ),
                        ),
                        // Center anchor (today starts here)
                        SliverToBoxAdapter(
                          key: _todayKey,
                          child: const SizedBox.shrink(),
                        ),
                        // Today and future days
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final date = DateService.getDateForOffset(index);
                              return DaySection(
                                date: date,
                                blocksFuture: _getBlocksForDate(date),
                                getSectionKey: _getSectionKey,
                                onSave: _handleSaveBlock,
                                onDelete: _handleDeleteBlock,
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
