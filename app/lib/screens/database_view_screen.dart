import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_database.dart';
import '../models/field.dart';
import '../models/record.dart';
import '../database/database_repository.dart';
import '../database/field_repository.dart';
import '../database/record_repository.dart';
import '../widgets/card_view.dart';
import '../widgets/note_view.dart';
import 'record_detail_screen.dart';
import 'schema_editor_screen.dart';

/// Main screen showing records for a single database.
///
/// Supports switching between Card and Note views via a dropdown in the AppBar.
/// The view preference is persisted in the database's [config] JSON.
class DatabaseViewScreen extends StatefulWidget {
  final AppDatabase database;

  const DatabaseViewScreen({super.key, required this.database});

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

  @override
  void initState() {
    super.initState();
    _database = widget.database;
    _loadData();
  }

  // didUpdateWidget fires when the parent rebuilds this widget with a new
  // `database` value (e.g. user picks a different database from the drawer).
  // See: https://api.flutter.dev/flutter/widgets/State/didUpdateWidget.html
  @override
  void didUpdateWidget(DatabaseViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database.id != widget.database.id) {
      _database = widget.database;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final fields = await _fieldRepo.getFieldsForDatabase(_database.id);
    final records = await _recordRepo.getRecordsForDatabase(_database.id);
    if (mounted) {
      setState(() {
        _fields = fields;
        _records = records;
        _loading = false;
      });
    }
  }

  Future<void> _switchView(String viewType) async {
    final updated = _database.copyWith(
      config: {..._database.config, 'current_view': viewType},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _dbRepo.save(updated);
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
  /// Updates the local list so the UI stays consistent.
  Future<void> _saveRecordInline(Record updated) async {
    await _recordRepo.save(updated);
    if (mounted) {
      setState(() {
        final index = _records.indexWhere((r) => r.id == updated.id);
        if (index != -1) {
          _records[index] = updated;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final currentView = _database.currentView;

    return Scaffold(
      appBar: AppBar(
        title: Text(_database.name),
        actions: [
          // View switcher dropdown
          DropdownButton<String>(
            value: currentView,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'note', child: Text('Note')),
            ],
            onChanged: (value) {
              if (value != null) _switchView(value);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage Fields',
            onPressed: _openSchemaEditor,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No records yet'),
                      const SizedBox(height: 16),
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
                      records: _records,
                      fields: _fields,
                      onRecordTap: _openRecord,
                      onRecordUpdated: _saveRecordInline,
                    )
                  : CardView(
                      records: _records,
                      fields: _fields,
                      onRecordTap: _openRecord,
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
