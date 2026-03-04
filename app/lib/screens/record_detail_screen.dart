import 'package:flutter/material.dart';

import '../models/field.dart';
import '../models/record.dart';
import '../database/record_repository.dart';

/// Full editing screen for a single record.
///
/// Renders each field with an appropriate input widget and shows the
/// content/notes area below. Auto-saves on pop via `PopScope`.
/// See: https://api.flutter.dev/flutter/widgets/PopScope-class.html
class RecordDetailScreen extends StatefulWidget {
  final Record record;
  final List<Field> fields;

  const RecordDetailScreen({
    super.key,
    required this.record,
    required this.fields,
  });

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  final _repo = RecordRepository();
  late Record _record;
  late TextEditingController _contentController;

  // One TextEditingController per text/number field, keyed by field ID.
  // Controllers are created lazily and disposed in `dispose()`.
  final Map<String, TextEditingController> _fieldControllers = {};

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _contentController = TextEditingController(text: _record.content);
    _contentController.addListener(_onContentChanged);

    // Initialize controllers for text and number fields
    for (final field in widget.fields) {
      if (field.fieldType == FieldType.text ||
          field.fieldType == FieldType.number) {
        final value = _record.getValue(field.id, '') ?? '';
        final controller = TextEditingController(text: value.toString());
        controller.addListener(() => _onFieldChanged(field.id, controller.text));
        _fieldControllers[field.id] = controller;
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onContentChanged() {
    _record = _record.copyWith(
      content: _contentController.text,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _dirty = true;
  }

  void _onFieldChanged(String fieldId, dynamic value) {
    _record = _record.copyWith(
      values: {..._record.values, fieldId: value},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _dirty = true;
  }

  Future<void> _save() async {
    if (!_dirty) return;
    await _repo.save(_record);
    _dirty = false;
  }

  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _repo.delete(_record.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: save when navigating back. `onPopInvokedWithResult` fires
    // before the pop completes, giving us a chance to persist.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Record'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteRecord,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Structured fields
            for (final field in widget.fields) _buildFieldEditor(field),

            const SizedBox(height: 16),
            Text('Notes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Write notes here...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldEditor(Field field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (field.fieldType) {
        FieldType.text => TextField(
            controller: _fieldControllers[field.id],
            decoration: InputDecoration(
              labelText: field.name,
              border: const OutlineInputBorder(),
            ),
          ),
        FieldType.number => TextField(
            controller: _fieldControllers[field.id],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: field.name,
              border: const OutlineInputBorder(),
            ),
          ),
        FieldType.checkbox => CheckboxListTile(
            title: Text(field.name),
            value: _record.getValue(field.id, false) == true,
            onChanged: (value) {
              setState(() => _onFieldChanged(field.id, value));
            },
          ),
        FieldType.date => ListTile(
            title: Text(field.name),
            subtitle: Text(
              _record.getValue(field.id, '') as String? ?? 'No date set',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                final iso = date.toIso8601String().split('T').first;
                setState(() => _onFieldChanged(field.id, iso));
              }
            },
          ),
        FieldType.select => DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: field.name,
              border: const OutlineInputBorder(),
            ),
            initialValue: _record.getValue(field.id) as String?,
            items: field.selectOptions
                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
            onChanged: (value) {
              setState(() => _onFieldChanged(field.id, value));
            },
          ),
        // Relation fields are shown but editing links is a future enhancement
        FieldType.relation => ListTile(
            title: Text(field.name),
            subtitle: const Text('Linked records'),
            trailing: const Icon(Icons.link),
          ),
      },
    );
  }
}
