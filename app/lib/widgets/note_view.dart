import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';
import '../utils/debouncer.dart';
import 'display_helpers.dart';

/// Note-style view: content-first, like Apple Notes or a journal app.
/// The text body dominates each card. Structured fields are condensed into a
/// small metadata row at the bottom — just enough context without overwhelming.
/// Inline editing via borderless TextField with debounced auto-save.
///
/// See: https://api.flutter.dev/flutter/widgets/StatelessWidget-class.html
class NoteView extends StatelessWidget {
  final List<Record> records;
  final List<Field> fields;

  /// Called when the user wants to open the full detail screen for a record.
  final ValueChanged<Record> onRecordTap;

  /// Called when inline edits should be persisted. The parent saves to DB.
  final ValueChanged<Record>? onRecordUpdated;

  /// Called when the user drags a record to a new position. When non-null,
  /// the list switches to ReorderableListView with visible drag handles.
  final void Function(int oldIndex, int newIndex)? onRecordReordered;

  const NoteView({
    super.key,
    required this.records,
    required this.fields,
    required this.onRecordTap,
    this.onRecordUpdated,
    this.onRecordReordered,
  });

  @override
  Widget build(BuildContext context) {
    if (onRecordReordered != null) {
      // ReorderableListView requires keys on all children.
      // See: https://api.flutter.dev/flutter/material/ReorderableListView-class.html
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        buildDefaultDragHandles: false,
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return _NoteCard(
            key: ValueKey(record.id),
            record: record,
            fields: fields,
            onRecordUpdated: onRecordUpdated,
            onOpenDetail: () => onRecordTap(record),
            dragIndex: index,
          );
        },
        onReorder: onRecordReordered!,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _NoteCard(
          // Key by record ID so Flutter reuses the right StatefulWidget when
          // the list reorders. Without this, controllers could bind to the
          // wrong record after a sort or insert.
          // See: https://api.flutter.dev/flutter/foundation/Key-class.html
          key: ValueKey(record.id),
          record: record,
          fields: fields,
          onRecordUpdated: onRecordUpdated,
          onOpenDetail: () => onRecordTap(record),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual note card — content-first, always editable
// ---------------------------------------------------------------------------

class _NoteCard extends StatefulWidget {
  final Record record;
  final List<Field> fields;
  final ValueChanged<Record>? onRecordUpdated;
  final VoidCallback onOpenDetail;
  // Non-null when this card is inside a ReorderableListView. The index
  // is required by ReorderableDragStartListener.
  final int? dragIndex;

  const _NoteCard({
    super.key,
    required this.record,
    required this.fields,
    required this.onRecordUpdated,
    required this.onOpenDetail,
    this.dragIndex,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  late TextEditingController _contentController;
  late Record _editingRecord;
  // Debouncer replaces the raw Timer — same semantics but reusable and
  // flushable on app lifecycle events (e.g. background/pause).
  final _saveDebouncer = Debouncer(delay: const Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    _editingRecord = widget.record;
    _contentController = TextEditingController(text: widget.record.content);
    _contentController.addListener(_onEditChanged);
  }

  /// When the parent rebuilds with a new Record (e.g. after DB refresh),
  /// update the controller only if the content actually changed externally.
  /// `didUpdateWidget` fires whenever the parent rebuilds with new props.
  /// See: https://api.flutter.dev/flutter/widgets/State/didUpdateWidget.html
  @override
  void didUpdateWidget(covariant _NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.id != oldWidget.record.id) {
      _contentController.text = widget.record.content;
      _editingRecord = widget.record;
    } else if (widget.record.content != _editingRecord.content &&
        widget.record.content != _contentController.text) {
      _contentController.text = widget.record.content;
      _editingRecord = widget.record;
    }
  }

  @override
  void dispose() {
    _saveDebouncer.flush();
    _saveDebouncer.dispose();
    _contentController.removeListener(_onEditChanged);
    _contentController.dispose();
    super.dispose();
  }

  void _onEditChanged() {
    _editingRecord = _editingRecord.copyWith(
      content: _contentController.text,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _saveDebouncer(() => widget.onRecordUpdated?.call(_editingRecord));
  }

  void _flushSave() {
    _saveDebouncer.flush();
  }

  // Flush pending save before navigating to detail screen.
  void _openDetail() {
    _flushSave();
    widget.onOpenDetail();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build a condensed metadata summary from field values.
    final metaParts = <String>[];
    for (final field in widget.fields) {
      if (field.fieldType == FieldType.relation) continue;
      final value = _editingRecord.getValue(field.id);
      if (value == null) continue;
      if (field.fieldType == FieldType.checkbox) {
        if (value == true) metaParts.add(field.name);
        continue;
      }
      final s = value.toString();
      if (s.isNotEmpty) metaParts.add(s);
    }

    // Append date from createdAt timestamp.
    final dateStr = formatRecordDate(_editingRecord.createdAt);
    if (dateStr.isNotEmpty) metaParts.add(dateStr);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content text field — the main focus of the note view.
            TextField(
              controller: _contentController,
              maxLines: null,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration.collapsed(
                hintText: 'Write here...',
              ),
            ),

            // Condensed metadata row — field values as a single line of text.
            const SizedBox(height: 8),
            Row(
              children: [
                // Drag handle — ReorderableDragStartListener activates drag
                // on press (vs long-press with the default buildDefaultDragHandles).
                // See: https://api.flutter.dev/flutter/material/ReorderableDragStartListener-class.html
                if (widget.dragIndex != null)
                  ReorderableDragStartListener(
                    index: widget.dragIndex!,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: colorScheme.outline,
                    ),
                  ),
                if (widget.dragIndex != null) const SizedBox(width: 4),
                if (metaParts.isNotEmpty)
                  Expanded(
                    child: Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 16),
                  tooltip: 'Open full editor',
                  onPressed: _openDetail,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
