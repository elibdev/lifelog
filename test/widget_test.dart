// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog/main.dart';
import 'package:lifelog/database_helper.dart';
import 'package:lifelog/state/journal_state_registry.dart';
import 'package:lifelog/renderers/record_renderer_registry.dart';
import 'package:lifelog/focus_manager.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize test registries
    final stateRegistry = JournalStateRegistry(db: JournalDatabase.instance);
    final rendererRegistry = RecordRendererRegistry.createDefault();
    final focusManager = JournalFocusManager();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      stateRegistry: stateRegistry,
      rendererRegistry: rendererRegistry,
      focusManager: focusManager,
    ));

    // Verify that the app loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
