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

  double _calculateAppendPosition() {
    // Calculate position at end of list
    if (widget.records.isEmpty) {
      return 1.0;
    }
    final maxPosition = widget.records.map((r) => r.orderPosition).reduce((a, b) => a > b ? a : b);
    return maxPosition + 1.0;
  }

  void _handlePlaceholderSave(Record placeholder) {
    // Save the placeholder (it already has an ID)
    widget.onSave(placeholder);
    // Generate a new placeholder ID for next time
    setState(() {
      _placeholderId = const Uuid().v4();
    });
  }

  void _handleEnterPressed(String fromRecordId) {
    // Find which record triggered Enter
    final currentIndex = widget.records.indexWhere((r) => r.id == fromRecordId);

    // Calculate position between current and next record
    final double newPosition;
    if (currentIndex == -1) {
      // Enter pressed from placeholder - append to end
      newPosition = _calculateAppendPosition();
    } else if (currentIndex == widget.records.length - 1) {
      // Last record - insert between it and placeholder
      final currentPos = widget.records[currentIndex].orderPosition;
      final placeholderPos = _calculateAppendPosition();
      newPosition = (currentPos + placeholderPos) / 2;
    } else {
      // Middle of list - insert between current and next
      final currentPos = widget.records[currentIndex].orderPosition;
      final nextPos = widget.records[currentIndex + 1].orderPosition;
      newPosition = (currentPos + nextPos) / 2;
    }

    // Create new record
    final uuid = const Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = uuid.v4();

    final newRecord = widget.recordType == 'todo'
        ? TodoRecord(
            id: newId,
            date: widget.date,
            content: '',
            createdAt: now,
            updatedAt: now,
            orderPosition: newPosition,
          )
        : NoteRecord(
            id: newId,
            date: widget.date,
            content: '',
            createdAt: now,
            updatedAt: now,
            orderPosition: newPosition,
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
    final placeholderPosition = _calculateAppendPosition();

    // Create placeholder
    final Record placeholder = widget.recordType == 'todo'
        ? TodoRecord(
            id: _placeholderId,
            date: widget.date,
            content: '',
            createdAt: now,
            updatedAt: now,
            orderPosition: placeholderPosition,
          )
        : NoteRecord(
            id: _placeholderId,
            date: widget.date,
            content: '',
            createdAt: now,
            updatedAt: now,
            orderPosition: placeholderPosition,
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
