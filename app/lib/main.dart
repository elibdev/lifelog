import 'package:flutter/material.dart';

import 'models/app_database.dart';
import 'screens/database_view_screen.dart';
import 'widgets/database_list_panel.dart';

void main() {
  runApp(const LifelogApp());
}

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

  void _onDatabaseDeleted() {
    setState(() => _selectedDatabase = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lifelog',
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
      home: _AdaptiveShell(
        selectedDatabase: _selectedDatabase,
        onDatabaseSelected: _onDatabaseSelected,
        onDatabaseDeleted: _onDatabaseDeleted,
      ),
    );
  }
}

/// The root layout widget that adapts between narrow and wide screens.
///
/// Uses `LayoutBuilder` to measure available width and pick a layout:
/// - **Narrow (<840px)**: Database list is the home screen. Tapping a database
///   pushes DatabaseViewScreen via Navigator, giving a natural back button.
/// - **Wide (>=840px)**: Side-by-side master-detail. The database list is a
///   permanent panel on the left; the detail view fills the right.
///
/// `LayoutBuilder` rebuilds its child whenever the parent's constraints change
/// (e.g. window resize on desktop), so the layout adapts in real time.
/// See: https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
class _AdaptiveShell extends StatelessWidget {
  final AppDatabase? selectedDatabase;
  final ValueChanged<AppDatabase> onDatabaseSelected;
  final VoidCallback onDatabaseDeleted;

  const _AdaptiveShell({
    required this.selectedDatabase,
    required this.onDatabaseSelected,
    required this.onDatabaseDeleted,
  });

  static const double _wideBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return _WideLayout(
            selectedDatabase: selectedDatabase,
            onDatabaseSelected: onDatabaseSelected,
            onDatabaseDeleted: onDatabaseDeleted,
          );
        }
        return _NarrowLayout(
          selectedDatabase: selectedDatabase,
          onDatabaseSelected: onDatabaseSelected,
          onDatabaseDeleted: onDatabaseDeleted,
        );
      },
    );
  }
}

/// Wide layout: permanent side panel + detail area, no Navigator needed.
class _WideLayout extends StatelessWidget {
  final AppDatabase? selectedDatabase;
  final ValueChanged<AppDatabase> onDatabaseSelected;
  final VoidCallback onDatabaseDeleted;

  const _WideLayout({
    required this.selectedDatabase,
    required this.onDatabaseSelected,
    required this.onDatabaseDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Scaffold(
            // P5: Show app name in wide layout too.
            appBar: AppBar(title: const Text('Lifelog')),
            body: SafeArea(
              child: DatabaseListPanel(
                selectedDatabaseId: selectedDatabase?.id,
                onDatabaseSelected: onDatabaseSelected,
                onDatabaseDeleted: onDatabaseDeleted,
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: selectedDatabase == null
              ? const Scaffold(
                  body: Center(
                    child: Text('Select a database'),
                  ),
                )
              : DatabaseViewScreen(
                  key: ValueKey(selectedDatabase!.id),
                  database: selectedDatabase!,
                  // P10: Don't show back button in wide layout.
                  showBackButton: false,
                ),
        ),
      ],
    );
  }
}

/// Narrow layout: database list is the home screen, database view is pushed.
///
/// Uses a nested `Navigator` so that pushing DatabaseViewScreen doesn't
/// replace the entire MaterialApp.
/// See: https://api.flutter.dev/flutter/widgets/Navigator-class.html
class _NarrowLayout extends StatefulWidget {
  final AppDatabase? selectedDatabase;
  final ValueChanged<AppDatabase> onDatabaseSelected;
  final VoidCallback onDatabaseDeleted;

  const _NarrowLayout({
    required this.selectedDatabase,
    required this.onDatabaseSelected,
    required this.onDatabaseDeleted,
  });

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void didUpdateWidget(_NarrowLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // C4: When switching databases, pop to root first, then push the new one.
    // This prevents stacking duplicate routes (List → DB_A → DB_B → ...).
    if (widget.selectedDatabase != null &&
        widget.selectedDatabase?.id != oldWidget.selectedDatabase?.id) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => DatabaseViewScreen(
            key: ValueKey(widget.selectedDatabase!.id),
            database: widget.selectedDatabase!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Lifelog')),
            body: SafeArea(
              child: DatabaseListPanel(
                selectedDatabaseId: widget.selectedDatabase?.id,
                onDatabaseSelected: widget.onDatabaseSelected,
                onDatabaseDeleted: widget.onDatabaseDeleted,
              ),
            ),
          ),
        );
      },
    );
  }
}
