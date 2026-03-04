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
  // Grouped + sorted are computed once when _results changes, not on every build.
  Map<String, List<Record>> _grouped = {};
  List<String> _sortedDates = [];

  bool _isSearching = false;
  String? _startDate;
  String? _endDate;

  @override
  void dispose() {
    _queryController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _setResults(List<Record> results) {
    _results = results;
    _grouped = {};
    for (final record in results) {
      _grouped.putIfAbsent(record.date, () => []).add(record);
    }
    // M4: Sort descending so most-recent results appear first.
    _sortedDates = _grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  }

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebouncer.cancel();
      setState(() {
        _setResults([]);
        _isSearching = false;
      });
      return;
    }

    // P9: Only show spinner after debounce fires, not on every keystroke.
    _searchDebouncer.call(() async {
      if (mounted) setState(() => _isSearching = true);
      final results = await _repository.search(
        query.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _setResults(results);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Shared style for empty-state labels ('Start typing…' and 'No results found').
    final emptyLabelStyle =
        theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline);

    return Scaffold(
      appBar: AppBar(
        // P7: Title removed — the search field below makes "SEARCH" redundant.
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
                          // Explicit fill here (not in theme) so record TextFields
                          // don't inherit the white surface background.
                          filled: true,
                          fillColor: theme.colorScheme.surface,
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
                          // P1: Use human-readable dates instead of raw ISO strings.
                          'Filtering: ${DateService.formatForDisplay(_startDate!)} — ${DateService.formatForDisplay(_endDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    Expanded(
                      child: _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          // P8: Show prompt when no query instead of blank screen.
                          : _queryController.text.isEmpty
                              ? Center(
                                  child: Text(
                                    'Start typing to search…',
                                    style: emptyLabelStyle,
                                  ),
                                )
                              : _results.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No results found',
                                        style: emptyLabelStyle,
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _sortedDates.length,
                                      itemBuilder: (context, dateIndex) {
                                        final date = _sortedDates[dateIndex];
                                        final records = _grouped[date]!;
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
                                                    ? 'TODAY · ${DateService.formatForDisplay(date).toUpperCase()}'
                                                    : DateService.formatForDisplay(date).toUpperCase(),
                                                style: theme
                                                    .textTheme.titleMedium,
                                              ),
                                            ),
                                            ...records.map(
                                              (record) => AdaptiveRecordWidget(
                                                key: ValueKey(
                                                    'search-${record.id}'),
                                                record: record,
                                                onSave: (_) {},
                                                onDelete: (_) {},
                                                readOnly: true,
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
