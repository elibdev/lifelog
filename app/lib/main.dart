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

  const _AdaptiveShell({
    required this.selectedDatabase,
    required this.onDatabaseSelected,
  });

  /// Width breakpoint for switching between narrow (stacked) and wide
  /// (side-by-side) layouts. 840px aligns with Material Design's medium
  /// window size class.
  /// See: https://m3.material.io/foundations/layout/applying-layout
  static const double _wideBreakpoint = 840;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return _WideLayout(
            selectedDatabase: selectedDatabase,
            onDatabaseSelected: onDatabaseSelected,
          );
        }
        return _NarrowLayout(
          selectedDatabase: selectedDatabase,
          onDatabaseSelected: onDatabaseSelected,
        );
      },
    );
  }
}

/// Wide layout: permanent side panel + detail area, no Navigator needed.
///
/// The `Row` splits the screen into a fixed-width list panel and a flexible
/// detail area. A `VerticalDivider` provides a visual separator.
class _WideLayout extends StatelessWidget {
  final AppDatabase? selectedDatabase;
  final ValueChanged<AppDatabase> onDatabaseSelected;

  const _WideLayout({
    required this.selectedDatabase,
    required this.onDatabaseSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Fixed-width list panel on the left.
        // `SizedBox` with a fixed width ensures the panel doesn't flex.
        SizedBox(
          width: 300,
          child: Scaffold(
            body: SafeArea(
              child: DatabaseListPanel(
                selectedDatabaseId: selectedDatabase?.id,
                onDatabaseSelected: onDatabaseSelected,
              ),
            ),
          ),
        ),
        // VerticalDivider sits between the two panels. `width: 1` and
        // `thickness: 1` make it a thin line; it takes its color from
        // the theme's dividerColor.
        const VerticalDivider(width: 1, thickness: 1),
        // `Expanded` fills all remaining horizontal space with the detail view.
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
                ),
        ),
      ],
    );
  }
}

/// Narrow layout: database list is the home screen, database view is pushed.
///
/// Uses a nested `Navigator` so that pushing DatabaseViewScreen doesn't
/// replace the entire MaterialApp — the app shell stays in place and only
/// this region navigates. The `GlobalKey<NavigatorState>` lets us push
/// routes programmatically when the selected database changes.
/// See: https://api.flutter.dev/flutter/widgets/Navigator-class.html
class _NarrowLayout extends StatefulWidget {
  final AppDatabase? selectedDatabase;
  final ValueChanged<AppDatabase> onDatabaseSelected;

  const _NarrowLayout({
    required this.selectedDatabase,
    required this.onDatabaseSelected,
  });

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void didUpdateWidget(_NarrowLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When a new database is selected, push the detail view.
    // `didUpdateWidget` fires whenever the parent rebuilds this widget
    // with new properties — here, when `selectedDatabase` changes.
    if (widget.selectedDatabase != null &&
        widget.selectedDatabase?.id != oldWidget.selectedDatabase?.id) {
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
    // A nested Navigator creates a separate navigation stack within this
    // area of the widget tree. The home route is the database list; tapping
    // a database pushes the detail view *inside* this navigator, which
    // gives us a back button without leaving the MaterialApp.
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
              ),
            ),
          ),
        );
      },
    );
  }
}
