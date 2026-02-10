import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import 'package:lifelog/notifications/navigation_notifications.dart';
import 'records/adaptive_record_widget.dart';

/// Manages a flat list of mixed-type records for a single day.
///
/// Replaces the old two-section-per-day pattern (one for todos, one for notes)
/// with a single section that can contain records of any type interleaved.
/// This simplifies navigation (one section per day instead of two) and allows
/// flexible record ordering.
class RecordSection extends StatefulWidget {
  final List<Record> records;
  final String date;
  final Function(Record) onSave;
  final Function(String) onDelete;

  const RecordSection({
    super.key,
    required this.records,
    required this.date,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<RecordSection> createState() => RecordSectionState();
}

/// Public state class so JournalScreen can call focusFirstRecord/focusLastRecord
/// via GlobalKey for cross-day navigation.
class RecordSectionState extends State<RecordSection> {
  late String _placeholderId;

  final Map<String, FocusNode> _focusNodes = {};

  void focusFirstRecord() {
    _tryFocusRecordAt(0);
  }

  void focusLastRecord() {
    final allIds = [...widget.records.map((r) => r.id), _placeholderId];
    _tryFocusRecordAt(allIds.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _placeholderId = const Uuid().v4();
  }

  @override
  void dispose() {
    _focusNodes.clear();
    super.dispose();
  }

  void _handleFocusNodeCreated(int index, String recordId, FocusNode node) {
    _focusNodes[recordId] = node;
  }

  void _handleFocusNodeDisposed(String recordId) {
    _focusNodes.remove(recordId);
  }

  bool _tryFocusRecordAt(int index) {
    final allIds = [...widget.records.map((r) => r.id), _placeholderId];
    if (index < 0 || index >= allIds.length) return false;

    final recordId = allIds[index];
    final focusNode = _focusNodes[recordId];
    if (focusNode != null) {
      focusNode.requestFocus();
      return true;
    }
    return false;
  }

  double _calculateAppendPosition() {
    if (widget.records.isEmpty) return 1.0;
    final maxPosition = widget.records
        .map((r) => r.orderPosition)
        .reduce((a, b) => a > b ? a : b);
    return maxPosition + 1.0;
  }

  void _handlePlaceholderSave(Record placeholder) {
    widget.onSave(placeholder);
    setState(() {
      _placeholderId = const Uuid().v4();
    });
  }

  void _handleEnterPressed(String fromRecordId) {
    final currentIndex =
        widget.records.indexWhere((r) => r.id == fromRecordId);

    final double newPosition;
    if (currentIndex == -1) {
      newPosition = _calculateAppendPosition();
    } else if (currentIndex == widget.records.length - 1) {
      final currentPos = widget.records[currentIndex].orderPosition;
      final placeholderPos = _calculateAppendPosition();
      newPosition = (currentPos + placeholderPos) / 2;
    } else {
      final currentPos = widget.records[currentIndex].orderPosition;
      final nextPos = widget.records[currentIndex + 1].orderPosition;
      newPosition = (currentPos + nextPos) / 2;
    }

    final uuid = const Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = uuid.v4();

    // New records default to text type
    final newRecord = Record(
      id: newId,
      date: widget.date,
      type: RecordType.text,
      content: '',
      metadata: {},
      orderPosition: newPosition,
      createdAt: now,
      updatedAt: now,
    );

    widget.onSave(newRecord);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[newId]?.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final placeholderPosition = _calculateAppendPosition();

    final placeholder = Record(
      id: _placeholderId,
      date: widget.date,
      type: RecordType.text,
      content: '',
      metadata: {},
      orderPosition: placeholderPosition,
      createdAt: now,
      updatedAt: now,
    );

    return NotificationListener<NavigateDownNotification>(
      onNotification: (notification) {
        final nextIndex = notification.recordIndex + 1;
        return _tryFocusRecordAt(nextIndex);
      },
      child: NotificationListener<NavigateUpNotification>(
        onNotification: (notification) {
          final prevIndex = notification.recordIndex - 1;
          return _tryFocusRecordAt(prevIndex);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...widget.records.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              return AdaptiveRecordWidget(
                key: ValueKey(record.id),
                record: record,
                onSave: widget.onSave,
                onDelete: widget.onDelete,
                onSubmitted: _handleEnterPressed,
                recordIndex: index,
                onFocusNodeCreated: _handleFocusNodeCreated,
                onFocusNodeDisposed: _handleFocusNodeDisposed,
              );
            }),
            AdaptiveRecordWidget(
              key: ValueKey(_placeholderId),
              record: placeholder,
              onSave: _handlePlaceholderSave,
              onDelete: (_) {},
              onSubmitted: _handleEnterPressed,
              recordIndex: widget.records.length,
              onFocusNodeCreated: _handleFocusNodeCreated,
              onFocusNodeDisposed: _handleFocusNodeDisposed,
            ),
          ],
        ),
      ),
    );
  }
}
