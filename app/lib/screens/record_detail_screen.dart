import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/field.dart';
import '../models/record.dart';
import '../models/record_link.dart';
import '../database/database_repository.dart';
import '../database/record_repository.dart';

/// Possible states for the auto-save indicator.
enum _SaveState { idle, saving, saved, error }

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
  final _dbRepo = DatabaseRepository();
  late Record _record;
  late TextEditingController _contentController;

  // One TextEditingController per text/number field, keyed by field ID.
  final Map<String, TextEditingController> _fieldControllers = {};

  bool _dirty = false;
  _SaveState _saveState = _SaveState.idle;

  // For relation fields: cached linked records keyed by field ID.
  final Map<String, List<Record>> _linkedRecords = {};

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _contentController = TextEditingController(text: _record.content);
    _contentController.addListener(_onContentChanged);

    for (final field in widget.fields) {
      if (field.fieldType == FieldType.text ||
          field.fieldType == FieldType.number) {
        final value = _record.getValue(field.id, '') ?? '';
        final controller = TextEditingController(text: value.toString());
        controller
            .addListener(() => _onFieldChanged(field.id, controller.text));
        _fieldControllers[field.id] = controller;
      }
    }

    _loadLinkedRecords();
  }

  @override
  void dispose() {
    _contentController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLinkedRecords() async {
    try {
      final links = await _repo.getLinksForRecord(_record.id);
      for (final field in widget.fields) {
        if (field.fieldType != FieldType.relation) continue;
        final fieldLinks = links.where((l) => l.fieldId == field.id).toList();
        final records = <Record>[];
        for (final link in fieldLinks) {
          final targetId = link.sourceRecordId == _record.id
              ? link.targetRecordId
              : link.sourceRecordId;
          final record = await _repo.getById(targetId);
          if (record != null) records.add(record);
        }
        if (mounted) {
          setState(() => _linkedRecords[field.id] = records);
        }
      }
    } catch (_) {
      // Non-critical — relations just won't show
    }
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

  Future<bool> _save() async {
    if (!_dirty) return true;
    setState(() => _saveState = _SaveState.saving);
    try {
      await _repo.save(_record);
      _dirty = false;
      if (mounted) {
        setState(() => _saveState = _SaveState.saved);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saveState = _SaveState.idle);
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saveState = _SaveState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
      return false;
    }
  }

  Future<void> _deleteRecord() async {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.delete(_record.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete record.')),
          );
        }
      }
    }
  }

  /// Derive a title from the first text field value, falling back to
  /// content first line, then "New Record".
  String get _title {
    for (final field in widget.fields) {
      if (field.fieldType == FieldType.text) {
        final value = _record.getValue(field.id, '') as String? ?? '';
        if (value.trim().isNotEmpty) return value.trim();
      }
    }
    final firstLine = _record.content.trim().split('\n').first;
    if (firstLine.isNotEmpty) return firstLine;
    return 'New Record';
  }

  /// Build the save state indicator widget for the AppBar.
  /// AnimatedSwitcher provides a smooth fade transition between states.
  /// See: https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html
  Widget _buildSaveIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_saveState) {
          _SaveState.saving => const SizedBox(
              key: ValueKey('saving'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          _SaveState.saved => const Icon(
              Icons.cloud_done_outlined,
              key: ValueKey('saved'),
              size: 20,
              color: Colors.green,
            ),
          _SaveState.error => Icon(
              Icons.cloud_off,
              key: ValueKey('error'),
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
          _SaveState.idle =>
            const SizedBox(key: ValueKey('idle'), width: 20),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, overflow: TextOverflow.ellipsis),
          actions: [
            _buildSaveIndicator(),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _deleteRecord,
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.fields.isNotEmpty)
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    shrinkWrap: true,
                    children: [
                      for (final field in widget.fields)
                        _buildFieldEditor(field),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Write notes here...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
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
        // C3: FilteringTextInputFormatter restricts keyboard input to valid
        // numeric characters. keyboardType alone only affects soft keyboards.
        // See: https://api.flutter.dev/flutter/services/FilteringTextInputFormatter-class.html
        FieldType.number => TextField(
            controller: _fieldControllers[field.id],
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
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
        // M5: Parse existing date to use as initialDate.
        FieldType.date => ListTile(
            title: Text(field.name),
            subtitle: Text(
              (_record.getValue(field.id, '') as String? ?? '').isEmpty
                  ? 'No date set'
                  : _record.getValue(field.id, '') as String,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((_record.getValue(field.id, '') as String? ?? '')
                    .isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() => _onFieldChanged(field.id, ''));
                    },
                  ),
                const Icon(Icons.calendar_today),
              ],
            ),
            onTap: () async {
              final existing = _record.getValue(field.id, '') as String?;
              final initialDate = (existing != null && existing.isNotEmpty)
                  ? DateTime.tryParse(existing) ?? DateTime.now()
                  : DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                final iso = date.toIso8601String().split('T').first;
                setState(() => _onFieldChanged(field.id, iso));
              }
            },
          ),
        // M6: Prepend null/"None" option so users can clear a selection.
        FieldType.select => DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: field.name,
              border: const OutlineInputBorder(),
            ),
            initialValue: _record.getValue(field.id) as String?,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('None',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ),
              ...field.selectOptions.map(
                (opt) => DropdownMenuItem(value: opt, child: Text(opt)),
              ),
            ],
            onChanged: (value) {
              setState(() => _onFieldChanged(field.id, value));
            },
          ),
        // M8: Relation field with link picker.
        FieldType.relation => _buildRelationField(field),
      },
    );
  }

  Widget _buildRelationField(Field field) {
    final linked = _linkedRecords[field.id] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(field.name),
          subtitle: linked.isEmpty ? const Text('No linked records') : null,
          trailing: IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Link record',
            onPressed: () => _showLinkPicker(field),
          ),
        ),
        if (linked.isNotEmpty)
          ...linked.map((r) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text(
                    _recordDisplayName(r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () => _removeLink(field, r),
                  ),
                ),
              )),
      ],
    );
  }

  String _recordDisplayName(Record record) {
    if (record.content.trim().isNotEmpty) {
      return record.content.trim().split('\n').first;
    }
    return 'Record';
  }

  Future<void> _showLinkPicker(Field field) async {
    final targetDbId = field.targetDatabaseId;
    if (targetDbId == null) return;

    try {
      final targetRecords = await _repo.getRecordsForDatabase(targetDbId);
      final alreadyLinked =
          (_linkedRecords[field.id] ?? []).map((r) => r.id).toSet();
      final available = targetRecords
          .where((r) => !alreadyLinked.contains(r.id) && r.id != _record.id)
          .toList();

      if (!mounted) return;

      final targetDb = await _dbRepo.getById(targetDbId);
      final dbName = targetDb?.name ?? 'Records';

      if (!mounted) return;

      final selected = await showDialog<Record>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Link to $dbName'),
          children: available.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No available records to link.'),
                  ),
                ]
              : available.map((r) {
                  return SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, r),
                    child: Text(
                      _recordDisplayName(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
        ),
      );

      if (selected != null) {
        final link = RecordLink(
          sourceRecordId: _record.id,
          targetRecordId: selected.id,
          fieldId: field.id,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _repo.saveLink(link);
        await _loadLinkedRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not load records for linking.')),
        );
      }
    }
  }

  Future<void> _removeLink(Field field, Record target) async {
    try {
      await _repo.deleteLink(_record.id, target.id, field.id);
      await _repo.deleteLink(target.id, _record.id, field.id);
      await _loadLinkedRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove link.')),
        );
      }
    }
  }
}
