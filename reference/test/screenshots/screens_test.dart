import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog_reference/database/mock_record_repository.dart';
import 'package:lifelog_reference/models/record.dart';
import 'package:lifelog_reference/services/date_service.dart';
import 'package:lifelog_reference/widgets/journal_screen.dart';
import 'package:lifelog_reference/widgets/search_screen.dart';

ThemeData _lightTheme() {
  const surface = Color.fromARGB(255, 188, 183, 173);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
      surface: surface,
    ),
    scaffoldBackgroundColor: surface,
  );
}

void _setWindowSize(WidgetTester tester,
    {double width = 400, double height = 800}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// Fixture data spanning today and yesterday so the journal has something to render.
// Computed at call-time (not const) because DateService.today() reads DateTime.now().
Map<String, List<Record>> _fixtureData() {
  final today = DateService.today();
  final yesterday = DateService.getPreviousDate(today);
  return {
    today: [
      Record(
        id: 'sc-1',
        date: today,
        type: RecordType.heading,
        content: 'Morning',
        metadata: {'heading.level': 1},
        orderPosition: 1.0,
        createdAt: 0,
        updatedAt: 0,
      ),
      Record(
        id: 'sc-2',
        date: today,
        type: RecordType.todo,
        content: 'Review PRs',
        metadata: {'todo.checked': false},
        orderPosition: 2.0,
        createdAt: 0,
        updatedAt: 0,
      ),
      Record(
        id: 'sc-3',
        date: today,
        type: RecordType.text,
        content: 'Met with the team about architecture',
        metadata: {},
        orderPosition: 3.0,
        createdAt: 0,
        updatedAt: 0,
      ),
    ],
    yesterday: [
      Record(
        id: 'sc-4',
        date: yesterday,
        type: RecordType.habit,
        content: '',
        metadata: {
          'habit.name': 'Exercise',
          // Dart list-in-map literal: list<String> stored as dynamic metadata value.
          'habit.completions': [yesterday],
        },
        orderPosition: 1.0,
        createdAt: 0,
        updatedAt: 0,
      ),
    ],
  };
}

void main() {
  group('JournalScreen', () {
    testWidgets('with records', (tester) async {
      _setWindowSize(tester);
      // MockRecordRepository satisfies JournalScreen's required RecordRepository
      // without touching SQLite — same interface, in-memory Map backing.
      final repo = MockRecordRepository(initialData: _fixtureData());

      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          debugShowCheckedModeBanner: false,
          home: JournalScreen(repository: repo),
        ),
      );

      // pumpAndSettle drains initState's async _loadInitialData() Future
      // and the subsequent setState() rebuild before capturing the golden.
      // See: https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/journal_screen_with_records.png'),
      );
    });
  });

  group('SearchScreen', () {
    testWidgets('empty state', (tester) async {
      _setWindowSize(tester);
      final repo = MockRecordRepository(initialData: _fixtureData());

      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          debugShowCheckedModeBanner: false,
          home: SearchScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/search_screen_empty.png'),
      );
    });

    testWidgets('with results', (tester) async {
      _setWindowSize(tester);
      final repo = MockRecordRepository(initialData: _fixtureData());

      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          debugShowCheckedModeBanner: false,
          home: SearchScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // enterText triggers onChanged, which starts the 500ms Debouncer timer.
      // pumpAndSettle() advances fake time in tests, firing the timer, then
      // drains the resulting async search Future before the next frame.
      // See: https://api.flutter.dev/flutter/flutter_test/WidgetTester/enterText.html
      await tester.enterText(find.byType(TextField), 'morning');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/search_screen_with_results.png'),
      );
    });

    testWidgets('no results', (tester) async {
      _setWindowSize(tester);
      final repo = MockRecordRepository(initialData: _fixtureData());

      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          debugShowCheckedModeBanner: false,
          home: SearchScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyzzy');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/search_screen_no_results.png'),
      );
    });
  });
}
