import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import '../notifications/navigation_notifications.dart';
import 'record_widget.dart';

class RecordSection extends StatefulWidget {
  final String title;
  final List<Record> records;
  final String date;
  final String recordType; // 'todo' or 'note'
  final Function(Record) onSave;
  final Function(String) onDelete;

  const RecordSection({
    super.key,
    required this.title,
    required this.records,
    required this.date,
    required this.recordType,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<RecordSection> createState() => RecordSectionState();
}

// Made public so JournalScreen can access it via GlobalKey for cross-section navigation
class RecordSectionState extends State<RecordSection> {
  late String _placeholderId;
  String? _autoFocusRecordId;

  // FOCUS NODE TRACKING: Map of recordId -> FocusNode
  // RecordSection tracks FocusNodes so it can call requestFocus() during navigation
  final Map<String, FocusNode> _focusNodes = {};

  // PUBLIC API: Focus the first record in this section
  // Called by JournalScreen via GlobalKey for cross-section navigation
  //
  // WHY PUBLIC: When a navigation notification bubbles up to JournalScreen
  // (user at end/start of section), JournalScreen needs to directly tell
  // the next section "focus your first/last record". This ensures we focus
  // TEXT FIELDS, not checkboxes or other focusable widgets.
  void focusFirstRecord() {
    _tryFocusRecordAt(0);
  }

  // PUBLIC API: Focus the last record in this section (or placeholder)
  // Called by JournalScreen via GlobalKey for cross-section navigation
  void focusLastRecord() {
    final allRecordIds = [
      ...widget.records.map((r) => r.id),
      _placeholderId,
    ];
    _tryFocusRecordAt(allRecordIds.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _placeholderId = const Uuid().v4();
  }

  @override
  void dispose() {
    // Clean up focus nodes when section is disposed
    _focusNodes.clear();
    super.dispose();
  }

  // FOCUS NODE LIFECYCLE: Called by RecordWidget when FocusNode is created
  void _handleFocusNodeCreated(int index, String recordId, FocusNode node) {
    _focusNodes[recordId] = node;
  }

  // FOCUS NODE LIFECYCLE: Called by RecordWidget when FocusNode is disposed
  void _handleFocusNodeDisposed(String recordId) {
    _focusNodes.remove(recordId);
  }

  // NAVIGATION: Try to focus a specific record by index
  // Returns true if successful, false if index is out of bounds
  bool _tryFocusRecordAt(int index) {
    // Calculate actual index (including placeholder)
    final allRecordIds = [
      ...widget.records.map((r) => r.id),
      _placeholderId,
    ];

    if (index < 0 || index >= allRecordIds.length) {
      return false; // Out of bounds
    }

    final recordId = allRecordIds[index];
    final focusNode = _focusNodes[recordId];

    if (focusNode != null) {
      focusNode.requestFocus();
      return true;
    }

    return false;
  }

  double _calculateAppendPosition() {
    // Calculate position at end of list
    if (widget.records.isEmpty) {
      return 1.0;
    }
    final maxPosition = widget.records
        .map((r) => r.orderPosition)
        .reduce((a, b) => a > b ? a : b);
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

    // NOTIFICATION LISTENERS: Handle navigation events from child RecordWidgets
    // This is where the "bubbling up" pattern happens:
    // 1. RecordWidget dispatches NavigateDownNotification
    // 2. This listener receives it
    // 3. Try to handle it (focus next record in this section)
    // 4. If we can handle it: return true (stop bubbling)
    // 5. If we can't (at end of section): return false (bubble up to JournalScreen)
    return NotificationListener<NavigateDownNotification>(
      onNotification: (notification) {
        // Try to focus the next record
        final nextIndex = notification.recordIndex + 1;
        final handled = _tryFocusRecordAt(nextIndex);

        // Return true to stop bubbling, false to let it bubble up
        return handled;
      },
      child: NotificationListener<NavigateUpNotification>(
        onNotification: (notification) {
          // Try to focus the previous record
          final prevIndex = notification.recordIndex - 1;
          final handled = _tryFocusRecordAt(prevIndex);

          // Return true to stop bubbling, false to let it bubble up
          return handled;
        },
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing records
        ...widget.records.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final record = entry.value;
            return RecordWidget(
              key: ValueKey(record.id),
              record: record,
              onSave: widget.onSave,
              onDelete: widget.onDelete,
              onSubmitted: _handleEnterPressed,
              autofocus: record.id == _autoFocusRecordId,
              // Focus node lifecycle tracking
              recordIndex: index,
              onFocusNodeCreated: _handleFocusNodeCreated,
              onFocusNodeDisposed: _handleFocusNodeDisposed,
            );
          },
        ),
        // Placeholder
        RecordWidget(
          key: ValueKey(_placeholderId),
          record: placeholder,
          onSave: _handlePlaceholderSave,
          onDelete: (_) {}, // Can't delete placeholder
          onSubmitted: _handleEnterPressed,
          // Placeholder is last in order
          recordIndex: widget.records.length,
          onFocusNodeCreated: _handleFocusNodeCreated,
          onFocusNodeDisposed: _handleFocusNodeDisposed,
        ),
      ],
    ),
      ), // End NotificationListener<NavigateUpNotification>
    ); // End NotificationListener<NavigateDownNotification>
  }
}
