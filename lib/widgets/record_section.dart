import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import 'record_widget.dart';

class RecordSection extends StatefulWidget {
  final String title;
  final List<Record> records;
  final String date;
  final String recordType; // 'todo' or 'note'
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String recordId, int direction)? onNavigate;

  const RecordSection({
    super.key,
    required this.title,
    required this.records,
    required this.date,
    required this.recordType,
    required this.onSave,
    required this.onDelete,
    this.onNavigate,
  });

  @override
  State<RecordSection> createState() => _RecordSectionState();
}

class _RecordSectionState extends State<RecordSection> {
  late String _placeholderId;
  String? _autoFocusRecordId;

  @override
  void initState() {
    super.initState();
    _placeholderId = const Uuid().v4();
  }

  void _handlePlaceholderSave(Record placeholder) {
    // Save the placeholder (it already has an ID)
    widget.onSave(placeholder);
    // Generate a new placeholder ID for next time
    setState(() {
      _placeholderId = const Uuid().v4();
    });
  }

  void _handleEnterPressed() {
    // Create a new empty record
    final uuid = const Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = uuid.v4();

    final newRecord = widget.recordType == 'todo'
        ? TodoRecord(
            id: newId,
            date: widget.date,
            content: '',
            createdAt: now + 1,
            updatedAt: now + 1,
          )
        : NoteRecord(
            id: newId,
            date: widget.date,
            content: '',
            createdAt: now + 1,
            updatedAt: now + 1,
          );

    // Mark the new record for autofocus
    setState(() {
      _autoFocusRecordId = newId;
    });

    // Save the new record
    widget.onSave(newRecord);
  }

  @override
  void didUpdateWidget(RecordSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear autofocus after one build cycle
    if (_autoFocusRecordId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _autoFocusRecordId = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Create placeholder
    final Record placeholder = widget.recordType == 'todo'
        ? TodoRecord(
            id: _placeholderId,
            date: widget.date,
            content: '',
            createdAt: now,
            updatedAt: now,
          )
        : NoteRecord(
            id: _placeholderId,
            date: widget.date,
            content: '',
            createdAt: now,
            updatedAt: now,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing records
        ...widget.records.map(
          (record) => RecordWidget(
            key: ValueKey(record.id),
            record: record,
            onSave: widget.onSave,
            onDelete: widget.onDelete,
            onSubmitted: _handleEnterPressed,
            onNavigateUp: widget.onNavigate != null ? () => widget.onNavigate!(record.id, -1) : null,
            onNavigateDown: widget.onNavigate != null ? () => widget.onNavigate!(record.id, 1) : null,
            autofocus: record.id == _autoFocusRecordId,
          ),
        ),
        // Placeholder
        RecordWidget(
          key: ValueKey(_placeholderId),
          record: placeholder,
          onSave: _handlePlaceholderSave,
          onDelete: (_) {}, // Can't delete placeholder
          onSubmitted: _handleEnterPressed,
          onNavigateUp: widget.onNavigate != null ? () => widget.onNavigate!(_placeholderId, -1) : null,
          onNavigateDown: widget.onNavigate != null ? () => widget.onNavigate!(_placeholderId, 1) : null,
        ),
      ],
    );
  }
}
