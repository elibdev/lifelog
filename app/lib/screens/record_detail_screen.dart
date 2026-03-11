import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/field.dart';
import '../models/record.dart';
import '../models/record_link.dart';
import '../database/database_repository.dart';
import '../database/record_repository.dart';
import '../widgets/display_helpers.dart';

/// Possible states for the auto-save indicator.
enum _SaveState { idle, saving, saved, error }

/// Full editing screen for a single record.
///
/// Inline chips at top for structured fields, borderless notes area below.
/// Auto-saves on pop via `PopScope`.
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
    _loadLinkedRecords();
  }

  @override
  void dispose() {
    _contentController.dispose();
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
            // Field chips — compact, tappable inline editors.
            if (widget.fields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final field in widget.fields)
                        _buildFieldChip(field),
                    ],
                  ),
                ),
              ),

            // Borderless notes area fills remaining space.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _contentController,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Write here...',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field chips — each field type gets a compact, tappable chip.
  // ---------------------------------------------------------------------------

  Widget _buildFieldChip(Field field) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (field.fieldType) {
      case FieldType.checkbox:
        final checked = _record.getValue(field.id, false) == true;
        // ActionChip: tapping toggles the boolean. Star icon matches the
        // card view's "show star when true" pattern.
        return ActionChip(
          avatar: Icon(
            checked ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: checked ? colorScheme.primary : null,
          ),
          label: Text(field.name),
          onPressed: () {
            setState(() => _onFieldChanged(field.id, !checked));
          },
        );

      case FieldType.select:
        final value = _record.getValue(field.id) as String?;
        final hasValue = value != null && value.isNotEmpty;
        // Semantic colors for select badges — same palette as card/table views.
        final colors = hasValue
            ? selectOptionColors(
                value: value,
                options: field.selectOptions,
                colorScheme: colorScheme,
              )
            : null;
        // PopupMenuButton wrapping a Chip — tap shows options inline.
        return PopupMenuButton<String?>(
          onSelected: (v) => setState(() => _onFieldChanged(field.id, v)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: null,
              child:
                  Text('None', style: TextStyle(fontStyle: FontStyle.italic)),
            ),
            ...field.selectOptions.map(
              (opt) => PopupMenuItem(value: opt, child: Text(opt)),
            ),
          ],
          child: Chip(
            label: Text(
              hasValue ? value : field.name,
              style: colors != null
                  ? TextStyle(color: colors.fg)
                  : null,
            ),
            backgroundColor: colors?.bg,
            side: colors != null ? BorderSide.none : null,
          ),
        );

      case FieldType.text:
        final value = (_record.getValue(field.id, '') as String?) ?? '';
        return ActionChip(
          label: Text(value.isEmpty ? field.name : '${field.name}: $value'),
          onPressed: () => _showTextEditor(field),
        );

      case FieldType.number:
        final value = (_record.getValue(field.id, '') ?? '').toString();
        return ActionChip(
          label: Text(
              value.isEmpty ? field.name : '${field.name}: $value'),
          onPressed: () => _showNumberEditor(field),
        );

      case FieldType.date:
        final value = (_record.getValue(field.id, '') as String?) ?? '';
        return ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(value.isEmpty ? field.name : value),
          onPressed: () => _showDateEditor(field),
        );

      case FieldType.relation:
        final linked = _linkedRecords[field.id] ?? [];
        return ActionChip(
          avatar: const Icon(Icons.link, size: 16),
          label: Text(linked.isEmpty
              ? field.name
              : '${field.name} (${linked.length})'),
          onPressed: () => _showLinkPicker(field),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Field editor dialogs — lightweight pickers launched from chip taps.
  // ---------------------------------------------------------------------------

  Future<void> _showTextEditor(Field field) async {
    final current = (_record.getValue(field.id, '') as String?) ?? '';
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(field.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: field.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _onFieldChanged(field.id, result));
    }
  }

  Future<void> _showNumberEditor(Field field) async {
    final current = (_record.getValue(field.id, '') ?? '').toString();
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(field.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          decoration: InputDecoration(hintText: field.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _onFieldChanged(field.id, result));
    }
  }

  Future<void> _showDateEditor(Field field) async {
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
  }

  // ---------------------------------------------------------------------------
  // Relation link management
  // ---------------------------------------------------------------------------

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

}
