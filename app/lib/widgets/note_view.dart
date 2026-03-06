import 'dart:async';

import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

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

  const NoteView({
    super.key,
    required this.records,
    required this.fields,
    required this.onRecordTap,
    this.onRecordUpdated,
  });

  @override
  Widget build(BuildContext context) {
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

  const _NoteCard({
    super.key,
    required this.record,
    required this.fields,
    required this.onRecordUpdated,
    required this.onOpenDetail,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  late TextEditingController _contentController;
  late Record _editingRecord;
  Timer? _saveTimer;

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
    _flushSave();
    _contentController.removeListener(_onEditChanged);
    _contentController.dispose();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _onEditChanged() {
    _editingRecord = _editingRecord.copyWith(
      content: _contentController.text,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _flushSave);
  }

  void _flushSave() {
    _saveTimer?.cancel();
    widget.onRecordUpdated?.call(_editingRecord);
  }

  // P6: Flush pending save before navigating to detail screen.
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
            if (metaParts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // M7: Removed the 28x28 SizedBox constraint — let the
                  // IconButton use its default 48x48 touch target.
                  // See: https://m3.material.io/foundations/accessible-design/accessibility-basics
                  IconButton(
                    icon: const Icon(Icons.open_in_full, size: 16),
                    tooltip: 'Open full editor',
                    onPressed: _openDetail,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.open_in_full, size: 16),
                  tooltip: 'Open full editor',
                  onPressed: _openDetail,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
