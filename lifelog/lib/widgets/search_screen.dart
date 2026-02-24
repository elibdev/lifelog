import 'package:flutter/material.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import '../constants/grid_constants.dart';
import '../services/date_service.dart';
import '../utils/debouncer.dart';
import 'records/adaptive_record_widget.dart';

/// Full-text search across all records with optional date-range filtering.
///
/// Results grouped by date with Swiss-style uppercase date headers.
/// The search bar uses the design system's InputDecorationTheme for
/// consistent styling.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  RecordRepository get _repository => widget.repository;
  final TextEditingController _queryController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();

  List<Record> _results = [];
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

  Map<String, List<Record>> _groupByDate(List<Record> records) {
    final Map<String, List<Record>> grouped = {};
    for (final record in records) {
      grouped.putIfAbsent(record.date, () => []).add(record);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupByDate(_results);
    final dates = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(
        // "SEARCH" — uppercase, letter-spaced, following design system
        title: const Text('SEARCH'),
        actions: [
          IconButton(
            icon: Icon(
              _startDate != null
                  ? Icons.date_range
                  : Icons.date_range_outlined,
              color: _startDate != null ? theme.colorScheme.primary : null,
              size: 20,
            ),
            onPressed: _pickDateRange,
            tooltip: 'Filter by date range',
          ),
          if (_startDate != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
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
            final double maxWidth =
                isDesktop ? 680 : (isTablet ? 580 : double.infinity);

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  children: [
                    // Search input — uses design system InputDecorationTheme
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: GridConstants.calculateContentLeftPadding(
                          constraints.maxWidth.clamp(0, maxWidth),
                        ),
                        vertical: 12.0,
                      ),
                      child: TextField(
                        controller: _queryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search records...',
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: theme.colorScheme.outline,
                          ),
                          suffixIcon: _queryController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: theme.colorScheme.outline,
                                  ),
                                  onPressed: () {
                                    _queryController.clear();
                                    _onQueryChanged('');
                                  },
                                )
                              : null,
                        ),
                        style: theme.textTheme.bodyMedium,
                        cursorColor: theme.colorScheme.primary,
                        cursorWidth: 1.5,
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    // Date range filter indicator
                    if (_startDate != null && _endDate != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: GridConstants.calculateContentLeftPadding(
                            constraints.maxWidth.clamp(0, maxWidth),
                          ),
                          vertical: 4.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$_startDate — $_endDate',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Results
                    Expanded(
                      child: _isSearching
                          ? Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            )
                          : _results.isEmpty &&
                                  _queryController.text.isNotEmpty
                              ? Center(
                                  child: Text(
                                    'No results',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: dates.length,
                                  itemBuilder: (context, dateIndex) {
                                    final date = dates[dateIndex];
                                    final records = grouped[date]!;
                                    final isToday =
                                        DateService.isToday(date);
                                    final dateLabel = isToday
                                        ? 'TODAY · ${DateService.formatForDisplay(date).toUpperCase()}'
                                        : DateService.formatForDisplay(date)
                                            .toUpperCase();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Date group header
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            GridConstants
                                                .calculateContentLeftPadding(
                                              constraints.maxWidth
                                                  .clamp(0, maxWidth),
                                            ),
                                            20,
                                            GridConstants
                                                .calculateContentRightPadding(
                                              constraints.maxWidth
                                                  .clamp(0, maxWidth),
                                            ),
                                            0,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dateLabel,
                                                style: theme
                                                    .textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 8),
                                              Divider(
                                                height: 0.5,
                                                thickness: 0.5,
                                                color: theme.colorScheme
                                                    .outlineVariant,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...records.map(
                                          (record) =>
                                              AdaptiveRecordWidget(
                                            key: ValueKey(
                                                'search-${record.id}'),
                                            record: record,
                                            onSave: (_) {},
                                            onDelete: (_) {},
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
