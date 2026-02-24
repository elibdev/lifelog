import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog_reference/models/record.dart';
import 'package:lifelog_reference/theme/lifelog_theme.dart';
import 'package:lifelog_reference/widgets/day_section.dart';
import 'package:lifelog_reference/widgets/record_section.dart';

void _setWindowSize(WidgetTester tester, {double width = 600, double height = 350}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// All five record types, used by the all_types golden.
final _allTypeRecords = [
  const Record(
    id: 'at-1',
    date: '2026-01-15',
    type: RecordType.heading,
    content: 'Morning',
    metadata: {'heading.level': 1},
    orderPosition: 1.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  const Record(
    id: 'at-2',
    date: '2026-01-15',
    type: RecordType.todo,
    content: 'Review PRs',
    metadata: {'todo.checked': false},
    orderPosition: 2.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  const Record(
    id: 'at-3',
    date: '2026-01-15',
    type: RecordType.text,
    content: 'Met with the team about architecture',
    metadata: {},
    orderPosition: 3.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  const Record(
    id: 'at-4',
    date: '2026-01-15',
    type: RecordType.bulletList,
    content: 'Add unit tests',
    metadata: {'bulletList.indentLevel': 0},
    orderPosition: 4.0,
    createdAt: 0,
    updatedAt: 0,
  ),
  Record(
    id: 'at-5',
    date: '2026-01-15',
    type: RecordType.habit,
    content: 'Meditation',
    metadata: const {
      'habit.name': 'Meditation',
      'habit.frequency': 'daily',
      // Two past-only completions: streak = 0, icon = outlined.
      'habit.completions': ['2026-01-01', '2026-01-02'],
    },
    orderPosition: 5.0,
    createdAt: 0,
    updatedAt: 0,
  ),
];

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
    testWidgets('all record types', (tester) async {
      _setWindowSize(tester, height: 500);
      await tester.pumpWidget(
        LifelogTokens(
          child: MaterialApp(
            theme: LifelogTheme.light(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 500,
                  child: RecordSection(
                    records: _allTypeRecords,
                    date: '2026-01-15',
                    onSave: (_) {},
                    onDelete: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_section_all_types.png'),
      );
    });

    testWidgets('mixed record types', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(
        LifelogTokens(
          child: MaterialApp(
            theme: LifelogTheme.light(),
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
    testWidgets('heading only — tests rule-to-H1 spacing', (tester) async {
      _setWindowSize(tester, height: 200);
      final sectionKey = GlobalKey<RecordSectionState>();
      await tester.pumpWidget(
        LifelogTokens(
          child: MaterialApp(
            theme: LifelogTheme.light(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DaySection(
                  date: '2026-01-15',
                  recordsFuture: Future.value(const [
                    Record(
                      id: 'dsh-1',
                      date: '2026-01-15',
                      type: RecordType.heading,
                      content: 'Morning',
                      metadata: {'heading.level': 1},
                      orderPosition: 1.0,
                      createdAt: 0,
                      updatedAt: 0,
                    ),
                  ]),
                  getSectionKey: (_) => sectionKey,
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
        matchesGoldenFile('../goldens/day_section_heading_only.png'),
      );
    });

    testWidgets('mixed records', (tester) async {
      _setWindowSize(tester, height: 400);
      // DaySection uses FutureBuilder internally; Future.value resolves synchronously
      // but still requires a pump cycle to deliver the result to the builder.
      // See: https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html
      final sectionKey = GlobalKey<RecordSectionState>();
      await tester.pumpWidget(
        LifelogTokens(
          child: MaterialApp(
            theme: LifelogTheme.light(),
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
