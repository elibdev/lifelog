import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_database.dart';
import '../models/field.dart';
import '../database/database_repository.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() => _loading = true);
    try {
      final fields = await _repo.getFieldsForDatabase(widget.database.id);
      if (mounted) {
        setState(() {
          _fields = fields;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load fields.')),
        );
      }
    }
  }

  Future<void> _addField() async {
    final result = await showDialog<_FieldDialogResult>(
      context: context,
      builder: (context) => const _FieldDialog(),
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
    try {
      await _repo.save(field);
      _loadFields();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add field.')),
        );
      }
    }
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
    try {
      await _repo.save(updated);
      _loadFields();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save field.')),
        );
      }
    }
  }

  Future<void> _deleteField(Field field) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content:
            Text('Delete "${field.name}"? Data in this field will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.delete(field.id);
        _loadFields();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete field.')),
          );
        }
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });

    final updated = <Field>[];
    for (var i = 0; i < _fields.length; i++) {
      updated.add(_fields[i].copyWith(orderPosition: i.toDouble()));
    }
    _fields = updated;
    try {
      await _repo.updateOrder(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save field order.')),
        );
      }
    }
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
      // M9: Show loading spinner while fields load.
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _fields.isEmpty
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

  // P7: Track whether we're editing to lock the type dropdown.
  bool get _isEdit => widget.existing != null;

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
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Field' : 'Add Field'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Field name'),
          ),
          const SizedBox(height: 16),
          // P7: Disable the type dropdown when editing — changing types
          // would silently break existing record data.
          DropdownButtonFormField<FieldType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Type'),
            items: FieldType.values
                .map(
                    (t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: _isEdit
                ? null
                : (value) {
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
          if (_selectedType == FieldType.relation) ...[
            const SizedBox(height: 16),
            _RelationTargetPicker(
              initialTargetId: widget.existing?.targetDatabaseId,
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
            if (_selectedType == FieldType.relation) {
              final picker = context
                  .findAncestorStateOfType<_RelationTargetPickerState>();
              if (picker != null && picker.selectedId != null) {
                config['target_database_id'] = picker.selectedId;
              }
            }

            Navigator.pop(
              context,
              _FieldDialogResult(name, _selectedType, config),
            );
          },
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

/// Picker widget for selecting the target database of a relation field.
class _RelationTargetPicker extends StatefulWidget {
  final String? initialTargetId;
  const _RelationTargetPicker({this.initialTargetId});

  @override
  State<_RelationTargetPicker> createState() => _RelationTargetPickerState();
}

class _RelationTargetPickerState extends State<_RelationTargetPicker> {
  final _dbRepo = DatabaseRepository();
  List<AppDatabase> _databases = [];
  String? selectedId;

  @override
  void initState() {
    super.initState();
    selectedId = widget.initialTargetId;
    _load();
  }

  Future<void> _load() async {
    try {
      final dbs = await _dbRepo.getAll();
      if (mounted) setState(() => _databases = dbs);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_databases.isEmpty) {
      return const Text('Loading databases...');
    }
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: const InputDecoration(labelText: 'Target database'),
      items: _databases
          .map((db) => DropdownMenuItem(value: db.id, child: Text(db.name)))
          .toList(),
      onChanged: (value) => setState(() => selectedId = value),
    );
  }
}
