import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifelog_reference/models/record.dart';
import 'package:lifelog_reference/widgets/records/text_record_widget.dart';
import 'package:lifelog_reference/widgets/records/heading_record_widget.dart';
import 'package:lifelog_reference/widgets/records/todo_record_widget.dart';
import 'package:lifelog_reference/widgets/records/bullet_list_record_widget.dart';
import 'package:lifelog_reference/widgets/records/habit_record_widget.dart';
import 'package:lifelog_reference/widgets/records/record_text_field.dart';

// Light theme matching the Widgetbook setup so goldens reflect the real app palette.
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

// Wrap a widget in a themed MaterialApp/Scaffold with a fixed 500px content column,
// mirroring the Widgetbook _wrapWidget helper.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: _lightTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 500, child: child),
      ),
    ),
  );
}

// Build a minimal Record fixture. All fields irrelevant to rendering (id, dates,
// orderPosition, createdAt, updatedAt) are set to stable no-op values.
Record _record({
  required RecordType type,
  required String content,
  Map<String, dynamic> metadata = const {},
  String id = 'test-id',
}) {
  return Record(
    id: id,
    date: '2026-01-15',
    type: type,
    content: content,
    metadata: metadata,
    orderPosition: 1.0,
    createdAt: 0,
    updatedAt: 0,
  );
}

// Set a fixed logical pixel window for stable golden output.
// tester.view replaces the deprecated tester.binding.window in Flutter 3.3+.
// See: https://api.flutter.dev/flutter/flutter_test/TestFlutterView-class.html
void _setWindowSize(WidgetTester tester, {double width = 600, double height = 120}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('TextRecordWidget', () {
    testWidgets('default', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        TextRecordWidget(
          record: _record(
            type: RecordType.text,
            content: 'Buy groceries',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/text_record_default.png'),
      );
    });

    testWidgets('wrapping', (tester) async {
      _setWindowSize(tester, height: 200);
      await tester.pumpWidget(_wrap(
        TextRecordWidget(
          record: _record(
            type: RecordType.text,
            content: 'Review all open pull requests and provide detailed feedback for the team before the end of the week',
            id: 'text-wrapping',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/text_record_wrapping.png'),
      );
    });
  });

  group('HeadingRecordWidget', () {
    for (final level in [1, 2, 3]) {
      testWidgets('H$level', (tester) async {
        _setWindowSize(tester, height: 80);
        await tester.pumpWidget(_wrap(
          HeadingRecordWidget(
            record: _record(
              type: RecordType.heading,
              content: 'Morning',
              metadata: {'heading.level': level},
              id: 'heading-$level',
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../goldens/heading_h$level.png'),
        );
      });
    }

    testWidgets('H1 wrapping', (tester) async {
      _setWindowSize(tester, height: 200);
      await tester.pumpWidget(_wrap(
        HeadingRecordWidget(
          record: _record(
            type: RecordType.heading,
            content: 'Weekly Team Retrospective and Planning Session',
            metadata: {'heading.level': 1},
            id: 'heading-h1-wrapping',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/heading_h1_wrapping.png'),
      );
    });
  });

  group('TodoRecordWidget', () {
    testWidgets('wrapping', (tester) async {
      _setWindowSize(tester, height: 200);
      await tester.pumpWidget(_wrap(
        TodoRecordWidget(
          record: _record(
            type: RecordType.todo,
            content: 'Review all open pull requests and provide detailed feedback for the team before the end of the week',
            metadata: {'todo.checked': false},
            id: 'todo-wrapping',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/todo_wrapping.png'),
      );
    });

    testWidgets('unchecked', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        TodoRecordWidget(
          record: _record(
            type: RecordType.todo,
            content: 'Review PRs',
            metadata: {'todo.checked': false},
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/todo_unchecked.png'),
      );
    });

    testWidgets('checked', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        TodoRecordWidget(
          record: _record(
            type: RecordType.todo,
            content: 'Review PRs',
            metadata: {'todo.checked': true},
            id: 'todo-checked',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/todo_checked.png'),
      );
    });
  });

  group('BulletListRecordWidget', () {
    testWidgets('wrapping', (tester) async {
      _setWindowSize(tester, height: 200);
      await tester.pumpWidget(_wrap(
        BulletListRecordWidget(
          record: _record(
            type: RecordType.bulletList,
            content: 'Review all open pull requests and provide detailed feedback for the team before the end of the week',
            metadata: {'bulletList.indentLevel': 0},
            id: 'bullet-wrapping',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/bullet_wrapping.png'),
      );
    });

    for (final indent in [0, 1, 2]) {
      testWidgets('indent $indent', (tester) async {
        _setWindowSize(tester);
        await tester.pumpWidget(_wrap(
          BulletListRecordWidget(
            record: _record(
              type: RecordType.bulletList,
              content: 'Buy groceries',
              metadata: {'bulletList.indentLevel': indent},
              id: 'bullet-$indent',
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        ));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../goldens/bullet_indent$indent.png'),
        );
      });
    }
  });

  group('HabitRecordWidget', () {
    testWidgets('wrapping name', (tester) async {
      _setWindowSize(tester, height: 200);
      await tester.pumpWidget(_wrap(
        HabitRecordWidget(
          record: _record(
            type: RecordType.habit,
            content: 'Daily morning stretching, breathing exercises, and ten minutes of mindfulness meditation',
            metadata: {
              'habit.name': 'Daily morning stretching, breathing exercises, and ten minutes of mindfulness meditation',
              'habit.frequency': 'daily',
              'habit.completions': ['2026-01-01', '2026-01-02'],
            },
            id: 'habit-wrapping',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/habit_wrapping.png'),
      );
    });

    testWidgets('not completed today', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        HabitRecordWidget(
          record: _record(
            type: RecordType.habit,
            content: 'Meditation',
            // Completions are past-only: streak = 0, total = 2, icon = outlined.
            metadata: {
              'habit.name': 'Meditation',
              'habit.frequency': 'daily',
              'habit.completions': ['2026-01-01', '2026-01-02'],
            },
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/habit_not_completed.png'),
      );
    });

    testWidgets('completed today', (tester) async {
      _setWindowSize(tester);
      // Completions include today + 2 preceding days so HabitRecordWidget._isCompletedToday
      // returns true and _currentStreak = 3 on every run — visual output is stable.
      final now = DateTime.now();
      final completions = List.generate(3, (i) {
        final date = now.subtract(Duration(days: i));
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
      await tester.pumpWidget(_wrap(
        HabitRecordWidget(
          record: _record(
            type: RecordType.habit,
            content: 'Meditation',
            metadata: {
              'habit.name': 'Meditation',
              'habit.frequency': 'daily',
              'habit.completions': completions,
            },
            id: 'habit-completed',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/habit_completed_today.png'),
      );
    });

    testWidgets('long streak', (tester) async {
      _setWindowSize(tester);
      // 30 consecutive completions ending today → streak = 30, total = 30.
      final now = DateTime.now();
      final completions = List.generate(30, (i) {
        final date = now.subtract(Duration(days: i));
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
      await tester.pumpWidget(_wrap(
        HabitRecordWidget(
          record: _record(
            type: RecordType.habit,
            content: 'Daily morning stretching and breathing exercises',
            metadata: {
              'habit.name': 'Daily morning stretching and breathing exercises',
              'habit.frequency': 'daily',
              'habit.completions': completions,
            },
            id: 'habit-streak',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/habit_long_streak.png'),
      );
    });
  });

  group('RecordTextField', () {
    testWidgets('default style', (tester) async {
      _setWindowSize(tester);
      await tester.pumpWidget(_wrap(
        RecordTextField(
          record: _record(
            type: RecordType.text,
            content: 'Buy groceries',
            id: 'rtf-default',
          ),
          onSave: (_) {},
          onDelete: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_text_field_default.png'),
      );
    });

    testWidgets('bold style', (tester) async {
      _setWindowSize(tester, height: 80);
      await tester.pumpWidget(_wrap(
        RecordTextField(
          record: _record(
            type: RecordType.text,
            content: 'Morning',
            id: 'rtf-bold',
          ),
          onSave: (_) {},
          onDelete: (_) {},
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/record_text_field_bold.png'),
      );
    });
  });
}
