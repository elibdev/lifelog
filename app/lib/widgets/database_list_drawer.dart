import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_database.dart';
import '../database/database_repository.dart';

/// Drawer that lists all user-created databases with a "New Database" action.
///
/// Uses a StatefulWidget because it owns the async load lifecycle and
/// manages the database list state locally. The [onDatabaseSelected] callback
/// lets the parent screen react to taps without coupling the drawer to
/// navigation logic.
/// See: https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html
class DatabaseListDrawer extends StatefulWidget {
  final String? selectedDatabaseId;
  final ValueChanged<AppDatabase> onDatabaseSelected;

  const DatabaseListDrawer({
    super.key,
    this.selectedDatabaseId,
    required this.onDatabaseSelected,
  });

  @override
  State<DatabaseListDrawer> createState() => _DatabaseListDrawerState();
}

class _DatabaseListDrawerState extends State<DatabaseListDrawer> {
  final _repo = DatabaseRepository();
  List<AppDatabase> _databases = [];

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<void> _loadDatabases() async {
    final databases = await _repo.getAll();
    // `mounted` check: the widget might have been disposed while the async
    // call was in flight. Calling setState on a disposed widget throws.
    // See: https://api.flutter.dev/flutter/widgets/State/mounted.html
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
    return Drawer(
      child: SafeArea(
        child: Column(
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
              child: ListView.builder(
                itemCount: _databases.length,
                itemBuilder: (context, index) {
                  final db = _databases[index];
                  final selected = db.id == widget.selectedDatabaseId;
                  return ListTile(
                    leading: const Icon(Icons.table_chart_outlined),
                    title: Text(db.name),
                    selected: selected,
                    onTap: () {
                      widget.onDatabaseSelected(db);
                      Navigator.pop(context); // close drawer
                    },
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
        ),
      ),
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
