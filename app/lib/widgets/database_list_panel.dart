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
/// This is a common Flutter pattern for adaptive layouts: extract the content
/// into a plain widget, then wrap it differently depending on screen size.
/// See: https://docs.flutter.dev/ui/adaptive-responsive
class DatabaseListPanel extends StatefulWidget {
  final String? selectedDatabaseId;
  final ValueChanged<AppDatabase> onDatabaseSelected;

  const DatabaseListPanel({
    super.key,
    this.selectedDatabaseId,
    required this.onDatabaseSelected,
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
    final databases = await _repo.getAll();
    if (mounted) setState(() => _databases = databases);
  }

  Future<void> _createDatabase() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreateDatabaseDialog(),
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

    await _repo.save(database);
    await _loadDatabases();
    if (mounted) widget.onDatabaseSelected(database);
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

class _CreateDatabaseDialog extends StatefulWidget {
  @override
  State<_CreateDatabaseDialog> createState() => _CreateDatabaseDialogState();
}

class _CreateDatabaseDialogState extends State<_CreateDatabaseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Database'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Database name',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
