import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog_reference/models/record.dart';
import 'package:lifelog_reference/widgets/day_section.dart';
import 'package:lifelog_reference/widgets/record_section.dart';

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

void _setWindowSize(WidgetTester tester, {double width = 600, double height = 350}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// A fixed set of mixed-type records used by both RecordSection and DaySection tests.
final _mixedRecords = [
  const Record(
    id: 'rs-1',
    date: '2026-01-15',
    type: RecordType.heading,
    content: 'Morning',
    metadata: {'heading.level': 1},
    orderPosition: 1.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  const Record(
    id: 'rs-2',
    date: '2026-01-15',
    type: RecordType.todo,
    content: 'Review PRs',
    metadata: {'todo.checked': false},
    orderPosition: 2.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  const Record(
    id: 'rs-3',
    date: '2026-01-15',
    type: RecordType.text,
    content: 'Met with the team about architecture',
    metadata: {},
    orderPosition: 3.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  const Record(
    id: 'rs-4',
    date: '2026-01-15',
    type: RecordType.bulletList,
    content: 'Add unit tests',
    metadata: {'bulletList.indentLevel': 0},
    orderPosition: 4.0,
    createdAt: 0,
    updatedAt: 0,
  ),
];

void main() {
  group('RecordSection', () {
    testWidgets('mixed record types', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                child: RecordSection(
                  records: _mixedRecords,
                  date: '2026-01-15',
                  onSave: (_) {},
                  onDelete: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_section_mixed.png'),
      );
    });
  });

  group('DaySection', () {
    testWidgets('mixed records', (tester) async {
      _setWindowSize(tester, height: 400);
      // DaySection uses FutureBuilder internally; Future.value resolves synchronously
      // but still requires a pump cycle to deliver the result to the builder.
      // See: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html
      final sectionKey = GlobalKey<RecordSectionState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: _lightTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DaySection(
                date: '2026-01-15',
                recordsFuture: Future.value(_mixedRecords),
                getSectionKey: (_) => sectionKey,
                onSave: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      );
      // pumpAndSettle drains all pending timers/frames including the FutureBuilder cycle.
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/day_section_mixed.png'),
      );
    });
  });
}
