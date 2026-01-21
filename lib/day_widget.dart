import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'models/journal_record.dart';
import 'models/journal_event.dart';
import 'widgets/note_widget.dart';
import 'widgets/todo_widget.dart';

class DayWidget extends StatefulWidget {
  final DateTime date;
  const DayWidget({super.key, required this.date});

  @override
  State<DayWidget> createState() => _DayWidgetState();
}

class _DayWidgetState extends State<DayWidget>
    with AutomaticKeepAliveClientMixin {
  final _uuid = const Uuid();
  List<JournalRecord> _records = [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Lazy load - only when widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoaded) {
        _loadRecords();
      }
    });
  }

  Future<void> _loadRecords() async {
    if (_isLoaded) return;

    final records = await JournalDatabase.instance.getRecordsForDate(widget.date);
    if (mounted) {
      setState(() {
        _records = records;
        _isLoaded = true;
      });
    }
  }

  Future<void> _createRecord(String type, double position, Map<String, dynamic> metadata) async {
    final now = DateTime.now();
    final recordId = 'rec_${_uuid.v4()}';

    final record = JournalRecord(
      id: recordId,
      date: widget.date,
      recordType: type,
      position: position,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.recordCreated,
      recordId: recordId,
      date: widget.date,
      timestamp: now,
      payload: {
        'record_type': type,
        'position': position,
        'metadata': metadata,
      },
    );

    await JournalDatabase.instance.createRecord(record, event);

    if (mounted) {
      setState(() {
        _records.add(record);
        _records.sort((a, b) => a.position.compareTo(b.position));
      });
    }
  }

  Future<void> _updateRecord(JournalRecord record, Map<String, dynamic> changes) async {
    final now = DateTime.now();
    final updatedRecord = record.copyWith(
      metadata: {...record.metadata, ...changes},
      updatedAt: now,
    );

    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.metadataUpdated,
      recordId: record.id,
      date: widget.date,
      timestamp: now,
      payload: {
        'changes': changes,
        'previous': record.metadata,
      },
    );

    await JournalDatabase.instance.updateRecord(updatedRecord, event);

    if (mounted) {
      setState(() {
        final index = _records.indexWhere((r) => r.id == record.id);
        if (index != -1) {
          _records[index] = updatedRecord;
        }
      });
    }
  }

  Future<void> _deleteRecord(JournalRecord record) async {
    final now = DateTime.now();
    final event = JournalEvent(
      id: 'evt_${_uuid.v4()}',
      eventType: EventType.recordDeleted,
      recordId: record.id,
      date: widget.date,
      timestamp: now,
      payload: {
        'record': record.toDb(),
      },
    );

    await JournalDatabase.instance.deleteRecord(record.id, event);

    if (mounted) {
      setState(() {
        _records.removeWhere((r) => r.id == record.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Sort records: todos first, then notes (by type, then position)
    final sortedRecords = List<JournalRecord>.from(_records);
    sortedRecords.sort((a, b) {
      if (a.recordType == b.recordType) {
        return a.position.compareTo(b.position);
      }
      return a.recordType == 'todo' ? -1 : 1;
    });

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: SelectableText(
                DateFormat('EEEE, MMM d, yyyy').format(widget.date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

            // Records
            ...sortedRecords.map((record) {
              if (record.recordType == 'note') {
                return NoteWidget(
                  key: ValueKey(record.id),
                  record: record,
                  isEmpty: false,
                  onUpdate: (changes) => _updateRecord(record, changes),
                  onDelete: () => _deleteRecord(record),
                  onCreateAfter: () {
                    final nextPos = sortedRecords.indexOf(record) + 1;
                    final newPosition = nextPos < sortedRecords.length
                        ? (record.position + sortedRecords[nextPos].position) / 2
                        : record.position + 1.0;
                    _createRecord('note', newPosition, {'content': ''});
                  },
                );
              } else if (record.recordType == 'todo') {
                return TodoWidget(
                  key: ValueKey(record.id),
                  record: record,
                  isEmpty: false,
                  onUpdate: (changes) => _updateRecord(record, changes),
                  onDelete: () => _deleteRecord(record),
                  onCreateAfter: () {
                    final nextPos = sortedRecords.indexOf(record) + 1;
                    final newPosition = nextPos < sortedRecords.length
                        ? (record.position + sortedRecords[nextPos].position) / 2
                        : record.position + 1.0;
                    _createRecord('todo', newPosition, {'content': '', 'checked': false});
                  },
                );
              }
              return const SizedBox.shrink();
            }),

            // Always show 2 ephemeral fields at bottom when loaded
            if (_isLoaded) ...[
              TodoWidget(
                isEmpty: true,
                onCreate: (text) {
                  final maxPos = _records.isEmpty ? 1.0 : _records.map((r) => r.position).reduce((a, b) => a > b ? a : b) + 1.0;
                  _createRecord('todo', maxPos, {'content': text, 'checked': false});
                },
              ),
              NoteWidget(
                isEmpty: true,
                onCreate: (text) {
                  final maxPos = _records.isEmpty ? 1.0 : _records.map((r) => r.position).reduce((a, b) => a > b ? a : b) + 1.0;
                  _createRecord('note', maxPos, {'content': text});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true; // Keep state when scrolling away
}
