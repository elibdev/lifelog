import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_database.dart';
import '../models/field.dart';
import '../database/field_repository.dart';

/// Screen for managing a database's schema (add, edit, reorder, delete fields).
///
/// Uses a ReorderableListView for drag-to-reorder.
/// See: https://api.flutter.dev/flutter/material/ReorderableListView-class.html
class SchemaEditorScreen extends StatefulWidget {
  final AppDatabase database;

  const SchemaEditorScreen({super.key, required this.database});

  @override
  State<SchemaEditorScreen> createState() => _SchemaEditorScreenState();
}

class _SchemaEditorScreenState extends State<SchemaEditorScreen> {
  final _repo = FieldRepository();
  List<Field> _fields = [];

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final fields = await _repo.getFieldsForDatabase(widget.database.id);
    if (mounted) setState(() => _fields = fields);
  }

  Future<void> _addField() async {
    final result = await showDialog<_FieldDialogResult>(
      context: context,
      builder: (context) => _FieldDialog(),
    );
    if (result == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final field = Field(
      id: const Uuid().v4(),
      databaseId: widget.database.id,
      name: result.name,
      fieldType: result.type,
      config: result.config,
      orderPosition: _fields.length.toDouble(),
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(field);
    _loadFields();
  }

  Future<void> _editField(Field field) async {
    final result = await showDialog<_FieldDialogResult>(
      context: context,
      builder: (context) => _FieldDialog(existing: field),
    );
    if (result == null) return;

    final updated = field.copyWith(
      name: result.name,
      fieldType: result.type,
      config: result.config,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.save(updated);
    _loadFields();
  }

  Future<void> _deleteField(Field field) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Delete "${field.name}"? Data in this field will be lost.'),
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
      await _repo.delete(field.id);
      _loadFields();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });

    // Reassign order positions
    final updated = <Field>[];
    for (var i = 0; i < _fields.length; i++) {
      updated.add(_fields[i].copyWith(orderPosition: i.toDouble()));
    }
    _fields = updated;
    await _repo.updateOrder(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fields: ${widget.database.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Field',
            onPressed: _addField,
          ),
        ],
      ),
      body: _fields.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No fields defined yet'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addField,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              itemCount: _fields.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final field = _fields[index];
                return ListTile(
                  // `key` is required for ReorderableListView to track items.
                  // ValueKey uses the field's unique ID.
                  // See: https://api.flutter.dev/flutter/foundation/Key-class.html
                  key: ValueKey(field.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(field.name),
                  subtitle: Text(field.fieldType.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editField(field),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteField(field),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _FieldDialogResult {
  final String name;
  final FieldType type;
  final Map<String, dynamic> config;
  _FieldDialogResult(this.name, this.type, this.config);
}

class _FieldDialog extends StatefulWidget {
  final Field? existing;
  const _FieldDialog({this.existing});

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  late final TextEditingController _nameController;
  late FieldType _selectedType;
  late final TextEditingController _optionsController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _selectedType = widget.existing?.fieldType ?? FieldType.text;
    _optionsController = TextEditingController(
      text: widget.existing?.selectOptions.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Field' : 'Add Field'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Field name'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<FieldType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: FieldType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedType = value);
            },
          ),
          if (_selectedType == FieldType.select) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _optionsController,
              decoration: const InputDecoration(
                labelText: 'Options (comma separated)',
                hintText: 'e.g. To Do, In Progress, Done',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            final config = <String, dynamic>{};
            if (_selectedType == FieldType.select) {
              config['options'] = _optionsController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            }

            Navigator.pop(
              context,
              _FieldDialogResult(name, _selectedType, config),
            );
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
