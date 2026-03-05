import 'dart:async';

import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';

/// Note-style view with inline editing. Tap a note to expand it into an
/// editable state — content becomes a borderless text field and structured
/// fields render as interactive chips. Changes auto-save via a debounce timer.
///
/// This is a StatefulWidget because it manages local editing state:
/// which note is expanded, TextEditingControllers for the active editor,
/// and a debounce [Timer] for auto-save.
/// See: https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html
class NoteView extends StatefulWidget {
  final List<Record> records;
  final List<Field> fields;

  /// Called when the user long-presses a note (navigate to full detail screen).
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
  State<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<NoteView> {
  String? _expandedRecordId;
  Record? _editingRecord;

  // Controller for the currently expanded note's content field.
  // Created on expand, disposed on collapse. Only one note is editable at a
  // time, so we only need one controller.
  TextEditingController? _contentController;
  Timer? _saveTimer;

  @override
  void dispose() {
    _flushSave();
    _cleanupControllers();
    super.dispose();
  }

  void _expandRecord(Record record) {
    if (_expandedRecordId == record.id) return;

    // Save and clean up any currently expanded note.
    _flushSave();
    _cleanupControllers();

    _contentController = TextEditingController(text: record.content);
    _contentController!.addListener(_onEditChanged);

    setState(() {
      _expandedRecordId = record.id;
      _editingRecord = record;
    });
  }

  void _collapseRecord() {
    _flushSave();
    _cleanupControllers();
    setState(() {
      _expandedRecordId = null;
      _editingRecord = null;
    });
  }

  /// Called on every keystroke. Updates the in-memory record and schedules
  /// a debounced save so we don't hit the DB on every character.
  void _onEditChanged() {
    if (_editingRecord == null) return;

    _editingRecord = _editingRecord!.copyWith(
      content: _contentController!.text,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _flushSave);
  }

  /// Immediately persist the current editing state via the parent callback.
  void _flushSave() {
    _saveTimer?.cancel();
    if (_editingRecord != null) {
      widget.onRecordUpdated?.call(_editingRecord!);
    }
  }

  void _cleanupControllers() {
    _contentController?.removeListener(_onEditChanged);
    _contentController?.dispose();
    _contentController = null;
  }

  /// Update a structured field value on the currently-expanded record.
  /// Used by interactive field chips (checkbox toggle, date picker, etc.).
  void _updateFieldValue(String fieldId, dynamic value) {
    if (_editingRecord == null) return;
    setState(() {
      _editingRecord = _editingRecord!.copyWith(
        values: {..._editingRecord!.values, fieldId: value},
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });
    // Save immediately for non-text edits (toggles, pickers).
    _flushSave();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: widget.records.length,
      itemBuilder: (context, index) {
        final record = widget.records[index];
        final isExpanded = record.id == _expandedRecordId;

        if (isExpanded && _editingRecord != null) {
          return _ExpandedNoteCard(
            record: _editingRecord!,
            fields: widget.fields,
            contentController: _contentController!,
            onCollapse: _collapseRecord,
            onFieldValueChanged: _updateFieldValue,
            onOpenDetail: () {
              _collapseRecord();
              widget.onRecordTap(record);
            },
          );
        }

        return _CollapsedNoteCard(
          record: record,
          fields: widget.fields,
          onTap: () => _expandRecord(record),
          // Long-press opens the full RecordDetailScreen.
          onLongPress: () => widget.onRecordTap(record),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsed note card — read-only preview, same visual as original NoteView
// ---------------------------------------------------------------------------

class _CollapsedNoteCard extends StatelessWidget {
  final Record record;
  final List<Field> fields;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CollapsedNoteCard({
    required this.record,
    required this.fields,
    required this.onTap,
    required this.onLongPress,
  });

  String _getHeading() {
    if (record.content.isNotEmpty) {
      return record.content.split('\n').first;
    }
    return 'Untitled';
  }

  String _fieldSummary() {
    final parts = <String>[];
    for (final field in fields) {
      if (field.fieldType == FieldType.relation) continue;
      final value = record.getValue(field.id);
      if (value == null || value.toString().isEmpty) continue;
      final display = field.fieldType == FieldType.checkbox
          ? (value == true ? '\u2713' : '\u2717')
          : value.toString();
      parts.add('${field.name}: $display');
    }
    return parts.join(' \u00b7 ');
  }

  @override
  Widget build(BuildContext context) {
    final title = _getHeading();
    final summary = _fieldSummary();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (record.content.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  record.content,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded note card — inline editor with borderless fields and field chips
// ---------------------------------------------------------------------------

class _ExpandedNoteCard extends StatelessWidget {
  final Record record;
  final List<Field> fields;
  final TextEditingController contentController;
  final VoidCallback onCollapse;
  final void Function(String fieldId, dynamic value) onFieldValueChanged;
  final VoidCallback onOpenDetail;

  const _ExpandedNoteCard({
    required this.record,
    required this.fields,
    required this.contentController,
    required this.onCollapse,
    required this.onFieldValueChanged,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build interactive field chips for all non-relation fields.
    final chipFields =
        fields.where((f) => f.fieldType != FieldType.relation).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      // Elevated + tinted border to show this card is active.
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: heading + action buttons
            Row(
              children: [
                const Spacer(),
                // Open full detail screen
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: 'Open full editor',
                  onPressed: onOpenDetail,
                  visualDensity: VisualDensity.compact,
                ),
                // Collapse / done button
                IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  tooltip: 'Done',
                  onPressed: onCollapse,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // Interactive field chips
            if (chipFields.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final field in chipFields)
                    _FieldChip(
                      field: field,
                      value: record.getValue(field.id),
                      onChanged: (value) =>
                          onFieldValueChanged(field.id, value),
                    ),
                ],
              ),
            ],

            const Divider(height: 16),

            // Content text field — grows with content, capped at a max height.
            // `ConstrainedBox` + `IntrinsicHeight` lets the TextField grow with
            // its content up to maxHeight, then scroll internally.
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 80,
                maxHeight: 300,
              ),
              child: TextField(
                controller: contentController,
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
      // FilterChip is Material's standard for toggleable chips.
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

      // Text / Number: read-only chip (editing via the title field or
      // the full detail screen). Shows current value or field name.
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

    // `showMenu` renders a Material popup menu at the tap position.
    // `RelativeRect.fromLTRB` positions it near the chip.
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
