import 'package:flutter/material.dart';

import 'models/app_database.dart';
import 'screens/database_view_screen.dart';
import 'widgets/database_list_drawer.dart';

void main() {
  runApp(const LifelogApp());
}

/// Root widget. Uses a StatefulWidget to track the currently selected database.
///
/// The Drawer (DatabaseListDrawer) lets users pick a database. The body shows
/// DatabaseViewScreen for the selected database, or a welcome message if none
/// is selected yet.
class LifelogApp extends StatefulWidget {
  const LifelogApp({super.key});

  @override
  State<LifelogApp> createState() => _LifelogAppState();
}

class _LifelogAppState extends State<LifelogApp> {
  AppDatabase? _selectedDatabase;

  void _onDatabaseSelected(AppDatabase database) {
    setState(() => _selectedDatabase = database);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lifelog',
      // Material 3 is Flutter's current design system.
      // See: https://docs.flutter.dev/ui/design/material
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: _selectedDatabase == null
            ? AppBar(title: const Text('Lifelog'))
            : null,
        drawer: DatabaseListDrawer(
          selectedDatabaseId: _selectedDatabase?.id,
          onDatabaseSelected: _onDatabaseSelected,
        ),
        body: _selectedDatabase == null
            ? const Center(
                child: Text('Open the drawer to select or create a database'),
              )
            : DatabaseViewScreen(
                // `key` forces a full rebuild when switching databases,
                // ensuring initState runs fresh with new data.
                key: ValueKey(_selectedDatabase!.id),
                database: _selectedDatabase!,
              ),
      ),
    );
  }
}
