import 'package:flutter/material.dart';
import '../models/block.dart';
import '../database/block_repository.dart';
import '../constants/grid_constants.dart';
import '../services/date_service.dart';
import '../utils/debouncer.dart';
import 'blocks/adaptive_block_widget.dart';

/// Full-text search across all block content with optional date-range filtering.
///
/// Results are grouped by date and rendered with AdaptiveBlockWidget in read-only mode.
/// Uses debounced input to avoid excessive database queries while typing.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final BlockRepository _repository = BlockRepository();
  final TextEditingController _queryController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();

  List<Block> _results = [];
  bool _isSearching = false;
  String? _startDate;
  String? _endDate;

  @override
  void dispose() {
    _queryController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _searchDebouncer.call(() async {
      final results = await _repository.search(
        query.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(
              start: DateTime.parse(_startDate!),
              end: DateTime.parse(_endDate!),
            )
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start.toIso8601String().substring(0, 10);
        _endDate = picked.end.toIso8601String().substring(0, 10);
      });
      // Re-run search with new date range
      _onQueryChanged(_queryController.text);
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _onQueryChanged(_queryController.text);
  }

  /// Group results by date for display
  Map<String, List<Block>> _groupByDate(List<Block> blocks) {
    final Map<String, List<Block>> grouped = {};
    for (final block in blocks) {
      grouped.putIfAbsent(block.date, () => []).add(block);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupByDate(_results);
    final dates = grouped.keys.toList(); // Already sorted DESC from query

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          // Date range filter button
          IconButton(
            icon: Icon(
              _startDate != null ? Icons.date_range : Icons.date_range_outlined,
              color: _startDate != null ? theme.colorScheme.primary : null,
            ),
            onPressed: _pickDateRange,
            tooltip: 'Filter by date range',
          ),
          if (_startDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateRange,
              tooltip: 'Clear date filter',
            ),
        ],
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
                child: Column(
                  children: [
                    // Search input
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: GridConstants.calculateContentLeftPadding(
                          constraints.maxWidth.clamp(0, maxWidth),
                        ),
                        vertical: 8.0,
                      ),
                      child: TextField(
                        controller: _queryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search blocks...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _queryController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _queryController.clear();
                                    _onQueryChanged('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),

                    // Date range indicator
                    if (_startDate != null && _endDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Text(
                          'Filtering: $_startDate to $_endDate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),

                    // Results
                    Expanded(
                      child: _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : _results.isEmpty && _queryController.text.isNotEmpty
                              ? Center(
                                  child: Text(
                                    'No results found',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: dates.length,
                                  itemBuilder: (context, dateIndex) {
                                    final date = dates[dateIndex];
                                    final blocks = grouped[date]!;
                                    final isToday = DateService.isToday(date);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Date header
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 16, 16, 4),
                                          child: Text(
                                            isToday
                                                ? 'Today · ${DateService.formatForDisplay(date)}'
                                                : DateService.formatForDisplay(
                                                    date),
                                            style: theme.textTheme.titleMedium,
                                          ),
                                        ),
                                        // Blocks for this date (read-only)
                                        ...blocks.map(
                                          (block) => AdaptiveBlockWidget(
                                            key: ValueKey(
                                                'search-${block.id}'),
                                            block: block,
                                            onSave: (_) {}, // Read-only
                                            onDelete: (_) {}, // Read-only
                                          ),
                                        ),
                                      ],
                                    );
                                  },
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
