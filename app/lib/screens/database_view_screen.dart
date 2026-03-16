import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_database.dart';
import '../models/field.dart';
import '../models/record.dart';
import '../database/database_repository.dart';
import '../database/field_repository.dart';
import '../database/record_repository.dart';
import '../utils/debouncer.dart';
import '../widgets/card_view.dart';
import '../widgets/note_view.dart';
import '../widgets/table_view.dart';
import 'record_detail_screen.dart';
import 'schema_editor_screen.dart';

/// Main screen showing records for a single database.
///
/// Supports switching between Card, Note, and Table views via a SegmentedButton.
/// The view preference is persisted in the database's [config] JSON.
class DatabaseViewScreen extends StatefulWidget {
  final AppDatabase database;

  /// Set to false in wide layouts to suppress the automatic back button.
  final bool showBackButton;

  const DatabaseViewScreen({
    super.key,
    required this.database,
    this.showBackButton = true,
  });

  @override
  State<DatabaseViewScreen> createState() => _DatabaseViewScreenState();
}

class _DatabaseViewScreenState extends State<DatabaseViewScreen> {
  final _dbRepo = DatabaseRepository();
  final _fieldRepo = FieldRepository();
  final _recordRepo = RecordRepository();

  late AppDatabase _database;
  List<Field> _fields = [];
  List<Record> _records = [];
  bool _loading = true;
  String? _error;

  // Search state
  bool _searching = false;
  final _searchController = TextEditingController();
  final _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 400));
  List<Record>? _searchResults;

  @override
  void initState() {
    super.initState();
    _database = widget.database;
    _loadData();
  }

  @override
  void didUpdateWidget(DatabaseViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database.id != widget.database.id) {
      _database = widget.database;
      _cancelSearch();
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fields = await _fieldRepo.getFieldsForDatabase(_database.id);
      final records = await _recordRepo.getRecordsForDatabase(_database.id);
      if (mounted) {
        setState(() {
          _fields = fields;
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load data. Tap to retry.';
        });
      }
    }
  }

  Future<void> _switchView(String viewType) async {
    final updated = _database.copyWith(
      config: {..._database.config, 'current_view': viewType},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _dbRepo.save(updated);
    } catch (_) {
      // Non-critical — view preference just won't persist
    }
    if (mounted) setState(() => _database = updated);
  }

  Future<void> _createRecord() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = Record(
      id: const Uuid().v4(),
      databaseId: _database.id,
      orderPosition: _records.length.toDouble(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _recordRepo.save(record);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(
              record: record,
              fields: _fields,
            ),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create record.')),
        );
      }
    }
  }

  Future<void> _openRecord(Record record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordDetailScreen(
          record: record,
          fields: _fields,
        ),
      ),
    );
    _loadData();
  }

  /// Save inline edits from NoteView without a full data reload.
  Future<void> _saveRecordInline(Record updated) async {
    try {
      await _recordRepo.save(updated);
      if (mounted) {
        setState(() {
          final index = _records.indexWhere((r) => r.id == updated.id);
          if (index != -1) {
            _records[index] = updated;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes.')),
        );
      }
    }
  }

  Future<void> _openSchemaEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SchemaEditorScreen(database: _database),
      ),
    );
    _loadData();
  }

  // --- Search ---

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _cancelSearch();
    });
  }

  void _cancelSearch() {
    _searchController.clear();
    _searchDebouncer.cancel();
    setState(() {
      _searchResults = null;
      _searching = false;
    });
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebouncer.cancel();
      setState(() => _searchResults = null);
      return;
    }
    _searchDebouncer(() async {
      try {
        final results = await _recordRepo.search(query);
        final filtered =
            results.where((r) => r.databaseId == _database.id).toList();
        if (mounted) setState(() => _searchResults = filtered);
      } catch (_) {
        // Search failure is non-critical
      }
    });
  }

  Future<void> _reorderRecord(int oldIndex, int newIndex) async {
    // ReorderableListView passes newIndex as if old item is already removed —
    // adjust before mutating the list.
    if (newIndex > oldIndex) newIndex--;
    final updated = [..._records];
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    // Reassign order positions as sequential integers.
    final reordered = updated
        .asMap()
        .entries
        .map((e) => e.value.copyWith(orderPosition: e.key.toDouble()))
        .toList();
    setState(() => _records = reordered);
    try {
      await _recordRepo.updateOrder(reordered);
    } catch (_) {
      // Non-critical — revert to original order on failure
      setState(() => _records = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentView = _database.currentView;
    final displayRecords = _searchResults ?? _records;

    return Scaffold(
      appBar: AppBar(
        // P10: Suppress back button in wide layout where the list is
        // already visible beside the detail view.
        automaticallyImplyLeading: widget.showBackButton,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search records...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(_database.name),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: _toggleSearch,
          ),
          // P4: SegmentedButton for view switching — more discoverable than
          // a plain dropdown. Each segment is visually distinct and tappable.
          // See: https://api.flutter.dev/flutter/material/SegmentedButton-class.html
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'card', icon: Icon(Icons.view_agenda, size: 18)),
              ButtonSegment(
                  value: 'note', icon: Icon(Icons.notes, size: 18)),
              ButtonSegment(
                  value: 'table', icon: Icon(Icons.table_chart, size: 18)),
            ],
            selected: {currentView},
            onSelectionChanged: (selected) => _switchView(selected.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage Fields',
            onPressed: _openSchemaEditor,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : displayRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_searchResults != null
                              ? 'No matching records'
                              : 'No records yet'),
                          const SizedBox(height: 16),
                          if (_searchResults == null)
                            FilledButton.icon(
                              onPressed: _createRecord,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Record'),
                            ),
                        ],
                      ),
                    )
                  : currentView == 'note'
                      ? NoteView(
                          records: displayRecords,
                          fields: _fields,
                          onRecordTap: _openRecord,
                          onRecordUpdated: _saveRecordInline,
                          // Disable reorder during search — results are filtered,
                          // not the full ordered list.
                          onRecordReordered:
                              _searchResults == null ? _reorderRecord : null,
                        )
                      : currentView == 'table'
                          ? TableView(
                              records: displayRecords,
                              fields: _fields,
                              onRecordTap: _openRecord,
                            )
                          : CardView(
                              records: displayRecords,
                              fields: _fields,
                              onRecordTap: _openRecord,
                              onRecordReordered:
                                  _searchResults == null ? _reorderRecord : null,
                            ),
      floatingActionButton: _records.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createRecord,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
