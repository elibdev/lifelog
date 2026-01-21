import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database_helper.dart';
import 'journal_home.dart';
import 'state/journal_state_registry.dart';
import 'renderers/record_renderer_registry.dart';
import 'focus_manager.dart';

void main() async {
  // Required to ensure plugin tools (like path_provider and sqflite)
  // are initialized before the app runs.
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize the database singleton.
  await JournalDatabase.instance.database;

  // Create state registry
  final stateRegistry = JournalStateRegistry(db: JournalDatabase.instance);

  // Create renderer registry with default renderers
  final rendererRegistry = RecordRendererRegistry.createDefault();

  // Create focus manager for keyboard navigation
  final focusManager = JournalFocusManager();

  runApp(MyApp(
    stateRegistry: stateRegistry,
    rendererRegistry: rendererRegistry,
    focusManager: focusManager,
  ));
}

class MyApp extends StatelessWidget {
  final JournalStateRegistry stateRegistry;
  final RecordRendererRegistry rendererRegistry;
  final JournalFocusManager focusManager;

  const MyApp({
    super.key,
    required this.stateRegistry,
    required this.rendererRegistry,
    required this.focusManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<JournalStateRegistry>.value(value: stateRegistry),
        Provider<RecordRendererRegistry>.value(value: rendererRegistry),
        Provider<JournalFocusManager>.value(value: focusManager),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lifelog',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B7355), // Warm brown
            surface: const Color(0xFFFAF8F3), // Cream/paper color
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF8F3), // Cream paper
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontSize: 14,
              height: 1.5,
              letterSpacing: 0.1,
              color: Color(0xFF2C2416),
            ),
            titleMedium: TextStyle(
              fontSize: 14,
              height: 1.5,
              letterSpacing: 0.1,
              color: Color(0xFF2C2416),
            ),
          ),
        ),
        home: const JournalHomePage(),
      ),
    );
  }
}
