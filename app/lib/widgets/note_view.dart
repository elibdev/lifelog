import 'dart:async';

import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

/// Note-style view where every record is always an inline editor. Content is a
/// borderless text field, structured fields render as interactive chips.
/// Changes auto-save via a per-card debounce timer.
///
/// This is a StatelessWidget — each individual _NoteCard is a StatefulWidget
/// that owns its own TextEditingController and save timer.
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
// Individual note card — always editable, owns its own controller + timer
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
  /// `didUpdateWidget` fires whenever the parent rebuilds with new props —
  /// it's Flutter's equivalent of React's componentDidUpdate / getDerivedState.
  /// See: https://api.flutter.dev/flutter/widgets/State/didUpdateWidget.html
  @override
  void didUpdateWidget(covariant _NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.record.id != oldWidget.record.id) {
      // Different record entirely (list reorder without matching Key).
      _contentController.text = widget.record.content;
      _editingRecord = widget.record;
    } else if (widget.record.content != _editingRecord.content &&
        widget.record.content != _contentController.text) {
      // External update (e.g. another screen edited this record).
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

  void _updateFieldValue(String fieldId, dynamic value) {
    setState(() {
      _editingRecord = _editingRecord.copyWith(
        values: {..._editingRecord.values, fieldId: value},
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });
    _flushSave();
  }

  @override
  Widget build(BuildContext context) {
    final chipFields =
        widget.fields.where((f) => f.fieldType != FieldType.relation).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action buttons row
            Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: 'Open full editor',
                  onPressed: widget.onOpenDetail,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // Interactive field chips
            if (chipFields.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final field in chipFields)
                    _FieldChip(
                      field: field,
                      value: _editingRecord.getValue(field.id),
                      onChanged: (value) =>
                          _updateFieldValue(field.id, value),
                    ),
                ],
              ),
              const Divider(height: 16),
            ],

            // Content text field — grows with content, capped at a max height.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 80,
                maxHeight: 300,
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Write notes here...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interactive field chip — renders a single structured field as a tappable chip
// ---------------------------------------------------------------------------

class _FieldChip extends StatelessWidget {
  final Field field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _FieldChip({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return switch (field.fieldType) {
      // Checkbox: FilterChip toggles on/off directly.
      // See: https://api.flutter.dev/flutter/material/FilterChip-class.html
      FieldType.checkbox => FilterChip(
          label: Text(field.name),
          selected: value == true,
          onSelected: onChanged,
          visualDensity: VisualDensity.compact,
        ),

      // Select: ActionChip opens a popup menu with the allowed options.
      FieldType.select => ActionChip(
          label: Text(value != null && value.toString().isNotEmpty
              ? '${field.name}: $value'
              : field.name),
          visualDensity: VisualDensity.compact,
          onPressed: () => _showSelectMenu(context),
        ),

      // Date: ActionChip opens a date picker.
      FieldType.date => ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 14),
          label: Text(value != null && value.toString().isNotEmpty
              ? value.toString()
              : field.name),
          visualDensity: VisualDensity.compact,
          onPressed: () => _showDatePicker(context),
        ),

      // Text / Number: read-only chip showing current value or field name.
      _ => Chip(
          label: Text(value != null && value.toString().isNotEmpty
              ? '${field.name}: $value'
              : field.name),
          visualDensity: VisualDensity.compact,
        ),
    };
  }

  void _showSelectMenu(BuildContext context) {
    final options = field.selectOptions;
    if (options.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy,
      ),
      items: [
        for (final opt in options)
          PopupMenuItem(value: opt, child: Text(opt)),
      ],
    ).then((selected) {
      if (selected != null) onChanged(selected);
    });
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final current = value is String && value.toString().isNotEmpty
        ? DateTime.tryParse(value.toString())
        : null;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onChanged(picked.toIso8601String().split('T').first);
    }
  }
}
