import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_database.dart';
import '../database/database_repository.dart';

/// Reusable panel that lists all databases with a "New Database" action.
///
/// Unlike a Drawer, this widget has no overlay chrome — it's just the content.
/// The parent decides how to display it: as a permanent side panel on wide
/// screens, or as the body of a full-screen Scaffold on narrow screens.
///
/// See: https://docs.flutter.dev/ui/adaptive-responsive
class DatabaseListPanel extends StatefulWidget {
  final String? selectedDatabaseId;
  final ValueChanged<AppDatabase> onDatabaseSelected;

  /// Called when a database is deleted so the parent can clear selection.
  final VoidCallback? onDatabaseDeleted;

  const DatabaseListPanel({
    super.key,
    this.selectedDatabaseId,
    required this.onDatabaseSelected,
    this.onDatabaseDeleted,
  });

  @override
  State<DatabaseListPanel> createState() => _DatabaseListPanelState();
}

class _DatabaseListPanelState extends State<DatabaseListPanel> {
  final _repo = DatabaseRepository();
  List<AppDatabase> _databases = [];

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<void> _loadDatabases() async {
    try {
      final databases = await _repo.getAll();
      if (mounted) setState(() => _databases = databases);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load databases.')),
        );
      }
    }
  }

  Future<void> _createDatabase() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateDatabaseDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final database = AppDatabase(
      id: const Uuid().v4(),
      name: name.trim(),
      orderPosition: _databases.length.toDouble(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _repo.save(database);
      await _loadDatabases();
      if (mounted) widget.onDatabaseSelected(database);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create database.')),
        );
      }
    }
  }

  // M3: Rename a database via dialog.
  Future<void> _renameDatabase(AppDatabase db) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDatabaseDialog(currentName: db.name),
    );
    if (newName == null || newName.trim().isEmpty) return;

    final updated = db.copyWith(
      name: newName.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _repo.save(updated);
      await _loadDatabases();
      // If this was the selected database, re-select to update the title
      if (db.id == widget.selectedDatabaseId) {
        widget.onDatabaseSelected(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not rename database.')),
        );
      }
    }
  }

  // M3: Delete a database with confirmation.
  Future<void> _deleteDatabase(AppDatabase db) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Database'),
        content: Text(
          'Delete "${db.name}" and all its records and fields? '
          'This cannot be undone.',
        ),
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
    if (confirm != true) return;

    try {
      await _repo.delete(db.id);
      await _loadDatabases();
      if (db.id == widget.selectedDatabaseId) {
        widget.onDatabaseDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete database.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Databases',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _databases.isEmpty
              ? const Center(child: Text('No databases yet'))
              : ListView.builder(
                  itemCount: _databases.length,
                  itemBuilder: (context, index) {
                    final db = _databases[index];
                    final selected = db.id == widget.selectedDatabaseId;
                    return ListTile(
                      leading: const Icon(Icons.table_chart_outlined),
                      title: Text(db.name),
                      selected: selected,
                      onTap: () => widget.onDatabaseSelected(db),
                      // M3: Trailing popup menu for rename/delete.
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Rename'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error),
                              title: Text('Delete',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'rename':
                              _renameDatabase(db);
                            case 'delete':
                              _deleteDatabase(db);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New Database'),
          onTap: _createDatabase,
        ),
      ],
    );
  }
}

// P8: Validation added — Create button disabled when name is empty/whitespace.
class _CreateDatabaseDialog extends StatefulWidget {
  const _CreateDatabaseDialog();

  @override
  State<_CreateDatabaseDialog> createState() => _CreateDatabaseDialogState();
}

class _CreateDatabaseDialogState extends State<_CreateDatabaseDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('New Database'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Database name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _RenameDatabaseDialog extends StatefulWidget {
  final String currentName;
  const _RenameDatabaseDialog({required this.currentName});

  @override
  State<_RenameDatabaseDialog> createState() => _RenameDatabaseDialogState();
}

class _RenameDatabaseDialogState extends State<_RenameDatabaseDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Rename Database'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Database name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('Rename'),
        ),
      ],
    );
  }
}
