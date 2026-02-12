import 'package:flutter/material.dart';
import '../models/record.dart';
import '../database/record_repository.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';
import 'package:lifelog_reference/services/date_service.dart';
import 'package:lifelog_reference/utils/debouncer.dart';
import 'records/adaptive_record_widget.dart';

/// Full-text search across all record content with optional date-range filtering.
///
/// Results are grouped by date and rendered with AdaptiveRecordWidget in read-only mode.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final RecordRepository _repository = RecordRepository();
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
        title: const Text('Search'),
        actions: [
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
            final double maxWidth =
                isDesktop ? 700 : (isTablet ? 600 : double.infinity);

            return Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  children: [
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
                          hintText: 'Search records...',
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
                    Expanded(
                      child: _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : _results.isEmpty &&
                                  _queryController.text.isNotEmpty
                              ? Center(
                                  child: Text(
                                    'No results found',
                                    style:
                                        theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: dates.length,
                                  itemBuilder: (context, dateIndex) {
                                    final date = dates[dateIndex];
                                    final records = grouped[date]!;
                                    final isToday =
                                        DateService.isToday(date);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 16, 16, 4),
                                          child: Text(
                                            isToday
                                                ? 'Today · ${DateService.formatForDisplay(date)}'
                                                : DateService
                                                    .formatForDisplay(
                                                        date),
                                            style: theme
                                                .textTheme.titleMedium,
                                          ),
                                        ),
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
