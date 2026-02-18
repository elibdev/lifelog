import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:lifelog_reference/models/record.dart';
import 'package:lifelog_reference/widgets/records/adaptive_record_widget.dart';
import 'package:lifelog_reference/widgets/records/text_record_widget.dart';
import 'package:lifelog_reference/widgets/records/heading_record_widget.dart';
import 'package:lifelog_reference/widgets/records/todo_record_widget.dart';
import 'package:lifelog_reference/widgets/records/bullet_list_record_widget.dart';
import 'package:lifelog_reference/widgets/records/habit_record_widget.dart';
import 'package:lifelog_reference/widgets/records/record_text_field.dart';
import 'package:lifelog_reference/widgets/day_section.dart';
import 'package:lifelog_reference/widgets/record_section.dart';
import 'package:lifelog_reference/widgets/dotted_grid_decoration.dart';
import 'package:lifelog_reference/constants/grid_constants.dart';

/// Widgetbook entry point: an isolated environment for developing and
/// previewing widgets with configurable knobs.
///
/// Run with: flutter run -t reference/widgetbook/main.dart
/// Requires `widgetbook: ^3.10.0` in dev_dependencies.
/// See: https://docs.widgetbook.io/
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  // GlobalKey must be stable across rebuilds — recreating it every build()
  // call would remount the keyed subtree. Static final ensures one instance.
  static final _daySectionKey = GlobalKey<RecordSectionState>();

  // ===========================================================================
  // TEXT SAMPLE PRESETS
  // Each map key is the knob display label; the value is the actual content.
  // Covers: short, long/wrapping, RTL (Arabic), CJK (Japanese), long compound
  // word (German), emoji-heavy, and empty — to catch layout edge cases.
  // ===========================================================================

  /// General content for text records, todos, bullet items, and text fields.
  static const _generalSamples = <String, String>{
    'Short': 'Buy groceries',
    'Long (wrapping)':
        'Review all open pull requests and provide detailed feedback for the team before the end of the week',
    'Arabic (RTL)': 'شراء البقالة من السوق',
    'Japanese': 'ミーティングの準備をする',
    'German (long word)': 'Aufgabenverwaltungssystem',
    'With emoji': 'Fix the bug 🐛 and write unit tests ✅',
    'Empty': '',
  };

  /// Content for heading records — shorter, title-appropriate strings.
  static const _headingSamples = <String, String>{
    'Short': 'Morning',
    'Long': 'Weekly Team Retrospective and Planning Session',
    'Arabic (RTL)': 'ملاحظات الصباح',
    'Japanese': '今朝の記録',
    'With emoji': 'Sprint Review 🚀',
  };

  /// Names for habit records — action-oriented, habit-appropriate strings.
  static const _habitSamples = <String, String>{
    'Short': 'Meditation',
    'Long': 'Daily morning stretching and breathing exercises',
    'Arabic (RTL)': 'التأمل اليومي',
    'Japanese': '毎日の瞑想',
    'With emoji': 'Morning workout 💪',
  };

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: _lightTheme()),
            WidgetbookTheme(name: 'Dark', data: _darkTheme()),
          ],
        ),
        ViewportAddon([
          IosViewports.iPhone13,
          IosViewports.iPadPro11Inches,
          LinuxViewports.desktop,
        ]),
      ],
      directories: [
        WidgetbookFolder(
          name: 'Records',
          children: [
            WidgetbookComponent(
              name: 'AdaptiveRecordWidget',
              useCases: [
                _textRecordUseCase(),
                _headingRecordUseCase(),
                _todoRecordUseCase(),
                _bulletListRecordUseCase(),
                _habitRecordUseCase(),
              ],
            ),
            WidgetbookComponent(
              name: 'TextRecordWidget',
              useCases: [_directTextRecordUseCase()],
            ),
            WidgetbookComponent(
              name: 'HeadingRecordWidget',
              useCases: [
                _directHeadingRecordUseCase(level: 1, name: 'H1'),
                _directHeadingRecordUseCase(level: 2, name: 'H2'),
                _directHeadingRecordUseCase(level: 3, name: 'H3'),
              ],
            ),
            WidgetbookComponent(
              name: 'TodoRecordWidget',
              useCases: [
                _todoUncheckedUseCase(),
                _todoCheckedUseCase(),
              ],
            ),
            WidgetbookComponent(
              name: 'BulletListRecordWidget',
              useCases: [
                _directBulletListRecordUseCase(indent: 0, name: 'Indent 0'),
                _directBulletListRecordUseCase(indent: 1, name: 'Indent 1'),
                _directBulletListRecordUseCase(indent: 2, name: 'Indent 2'),
              ],
            ),
            WidgetbookComponent(
              name: 'HabitRecordWidget',
              useCases: [
                _habitNotCompletedUseCase(),
                _habitCompletedUseCase(),
                _habitLongStreakUseCase(),
              ],
            ),
            WidgetbookComponent(
              name: 'RecordTextField',
              useCases: [
                _recordTextFieldDefaultUseCase(),
                _recordTextFieldBoldUseCase(),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Layout',
          children: [
            WidgetbookComponent(
              name: 'DaySection',
              useCases: [_daySectionUseCase()],
            ),
            WidgetbookComponent(
              name: 'RecordSection',
              useCases: [_recordSectionUseCase()],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Decorations',
          children: [
            WidgetbookComponent(
              name: 'DottedGridDecoration',
              useCases: [_dottedGridDecorationUseCase()],
            ),
          ],
        ),
      ],
    );
  }

  static ThemeData _lightTheme() {
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

  static ThemeData _darkTheme() {
    const surface = Color.fromARGB(255, 30, 29, 29);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Wraps a specific widget directly (no AdaptiveRecordWidget routing).
  static Widget _wrapWidget(Widget child) {
    return Scaffold(
      body: Center(
        child: SizedBox(width: 500, child: child),
      ),
    );
  }

  /// Returns a content string picked from [samples] via a list knob.
  /// The knob label is [label]; [initialKey] is the key selected by default.
  static String _contentKnob(
    BuildContext context, {
    required Map<String, String> samples,
    required String label,
    String initialKey = 'Short',
  }) {
    // context.knobs.object.dropdown<T>: dropdown knob with fixed options.
    // labelBuilder converts each option to a display string in the panel.
    // See: https://docs.widgetbook.io/knobs/list-knob
    final selectedLabel = context.knobs.object.dropdown<String>(
      label: label,
      options: samples.keys.toList(),
      initialOption: initialKey,
    );
    return samples[selectedLabel] ?? '';
  }

  // ===========================================================================
  // USE CASES — AdaptiveRecordWidget
  // all metadata keys are namespaced by record type
  // ===========================================================================

  static WidgetbookUseCase _textRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Text Record',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        return _wrapRecord(
          Record(
            id: 'wb-text-1',
            date: '2026-02-10',
            type: RecordType.text,
            content: content,
            metadata: {},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _headingRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Heading Record',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _headingSamples,
          label: 'Content',
        );
        // object.dropdown<int> constrains input to valid values, unlike int.input
        final level = context.knobs.object.dropdown<int>(
          label: 'Heading Level',
          options: [1, 2, 3],
          initialOption: 1,
        );
        return _wrapRecord(
          Record(
            id: 'wb-heading-1',
            date: '2026-02-10',
            type: RecordType.heading,
            content: content,
            metadata: {'heading.level': level},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _todoRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Todo Record',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        final checked = context.knobs.boolean(
          label: 'Checked',
          initialValue: false,
        );
        return _wrapRecord(
          Record(
            id: 'wb-todo-1',
            date: '2026-02-10',
            type: RecordType.todo,
            content: content,
            metadata: {'todo.checked': checked},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _bulletListRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Bullet List Record',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        // object.dropdown<int> constrains input to valid values (0, 1, 2)
        final indentLevel = context.knobs.object.dropdown<int>(
          label: 'Indent Level',
          options: [0, 1, 2],
          initialOption: 0,
        );
        return _wrapRecord(
          Record(
            id: 'wb-bullet-1',
            date: '2026-02-10',
            type: RecordType.bulletList,
            content: content,
            metadata: {'bulletList.indentLevel': indentLevel},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _habitRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Habit Record',
      builder: (context) {
        final habitName = _contentKnob(
          context,
          samples: _habitSamples,
          label: 'Habit Name',
        );
        final frequency = context.knobs.object.dropdown<String>(
          label: 'Frequency',
          options: ['daily', 'weekly'],
          initialOption: 'daily',
        );
        final completionCount = context.knobs.int.input(
          label: 'Completions',
          initialValue: 5,
        );
        final completions = List.generate(
          completionCount,
          (i) => '2026-02-${(10 - i).toString().padLeft(2, '0')}',
        );
        return _wrapRecord(
          Record(
            id: 'wb-habit-1',
            date: '2026-02-10',
            type: RecordType.habit,
            content: habitName,
            metadata: {
              'habit.name': habitName,
              'habit.frequency': frequency,
              'habit.completions': completions,
            },
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static Widget _wrapRecord(Record record) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: AdaptiveRecordWidget(
            record: record,
            onSave: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // USE CASES — individual record widgets
  // ===========================================================================

  static WidgetbookUseCase _directTextRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Default',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        return _wrapWidget(
          TextRecordWidget(
            record: Record(
              id: 'wb-direct-text-1',
              date: '2026-02-10',
              type: RecordType.text,
              content: content,
              metadata: {},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  /// Produces one use case per heading level so each level is visually distinct
  /// in the component navigator. [level] is fixed; content is a list knob.
  static WidgetbookUseCase _directHeadingRecordUseCase({
    required int level,
    required String name,
  }) {
    return WidgetbookUseCase(
      name: name,
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _headingSamples,
          label: 'Content',
        );
        return _wrapWidget(
          HeadingRecordWidget(
            record: Record(
              id: 'wb-direct-heading-$level',
              date: '2026-02-10',
              type: RecordType.heading,
              content: content,
              metadata: {'heading.level': level},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _todoUncheckedUseCase() {
    return WidgetbookUseCase(
      name: 'Unchecked',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        return _wrapWidget(
          TodoRecordWidget(
            record: Record(
              id: 'wb-direct-todo-1',
              date: '2026-02-10',
              type: RecordType.todo,
              content: content,
              metadata: {'todo.checked': false},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _todoCheckedUseCase() {
    return WidgetbookUseCase(
      name: 'Checked',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        return _wrapWidget(
          TodoRecordWidget(
            record: Record(
              id: 'wb-direct-todo-2',
              date: '2026-02-10',
              type: RecordType.todo,
              content: content,
              metadata: {'todo.checked': true},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  /// Produces one use case per indent level so each bullet style (•, ◦, ▪) and
  /// its left-padding is visually distinct in the component navigator.
  static WidgetbookUseCase _directBulletListRecordUseCase({
    required int indent,
    required String name,
  }) {
    return WidgetbookUseCase(
      name: name,
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        return _wrapWidget(
          BulletListRecordWidget(
            record: Record(
              id: 'wb-direct-bullet-$indent',
              date: '2026-02-10',
              type: RecordType.bulletList,
              content: content,
              metadata: {'bulletList.indentLevel': indent},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _habitNotCompletedUseCase() {
    return WidgetbookUseCase(
      name: 'Not Completed Today',
      builder: (context) {
        final habitName = _contentKnob(
          context,
          samples: _habitSamples,
          label: 'Habit Name',
        );
        final frequency = context.knobs.object.dropdown<String>(
          label: 'Frequency',
          options: ['daily', 'weekly'],
          initialOption: 'daily',
        );
        return _wrapWidget(
          HabitRecordWidget(
            record: Record(
              id: 'wb-direct-habit-1',
              date: '2026-02-10',
              type: RecordType.habit,
              content: habitName,
              metadata: {
                'habit.name': habitName,
                'habit.frequency': frequency,
                'habit.completions': ['2026-02-08', '2026-02-09'],
              },
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _habitCompletedUseCase() {
    return WidgetbookUseCase(
      name: 'Completed Today',
      builder: (context) {
        final habitName = _contentKnob(
          context,
          samples: _habitSamples,
          label: 'Habit Name',
        );
        final frequency = context.knobs.object.dropdown<String>(
          label: 'Frequency',
          options: ['daily', 'weekly'],
          initialOption: 'daily',
        );
        // Compute today's date dynamically so _isCompletedToday returns true
        // regardless of when Widgetbook is opened.
        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        return _wrapWidget(
          HabitRecordWidget(
            record: Record(
              id: 'wb-direct-habit-2',
              date: '2026-02-10',
              type: RecordType.habit,
              content: habitName,
              metadata: {
                'habit.name': habitName,
                'habit.frequency': frequency,
                'habit.completions': [todayStr, '2026-02-09', '2026-02-08'],
              },
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  /// Shows the streak + total display with a large number of completions,
  /// including today — useful for testing layout with long stat strings.
  static WidgetbookUseCase _habitLongStreakUseCase() {
    return WidgetbookUseCase(
      name: 'Long Streak',
      builder: (context) {
        final habitName = _contentKnob(
          context,
          samples: _habitSamples,
          label: 'Habit Name',
        );
        final frequency = context.knobs.object.dropdown<String>(
          label: 'Frequency',
          options: ['daily', 'weekly'],
          initialOption: 'daily',
        );
        final now = DateTime.now();
        // Generate 30 consecutive daily completions ending today
        final completions = List.generate(30, (i) {
          final date = now.subtract(Duration(days: i));
          return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        });
        return _wrapWidget(
          HabitRecordWidget(
            record: Record(
              id: 'wb-direct-habit-3',
              date: '2026-02-10',
              type: RecordType.habit,
              content: habitName,
              metadata: {
                'habit.name': habitName,
                'habit.frequency': frequency,
                'habit.completions': completions,
              },
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _recordTextFieldDefaultUseCase() {
    return WidgetbookUseCase(
      name: 'Default Style',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _generalSamples,
          label: 'Content',
        );
        return _wrapWidget(
          RecordTextField(
            record: Record(
              id: 'wb-rtf-1',
              date: '2026-02-10',
              type: RecordType.text,
              content: content,
              metadata: {},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _recordTextFieldBoldUseCase() {
    return WidgetbookUseCase(
      name: 'Bold Style',
      builder: (context) {
        final content = _contentKnob(
          context,
          samples: _headingSamples,
          label: 'Content',
        );
        return _wrapWidget(
          RecordTextField(
            record: Record(
              id: 'wb-rtf-2',
              date: '2026-02-10',
              type: RecordType.text,
              content: content,
              metadata: {},
              orderPosition: 1.0,
              createdAt: 0,
              updatedAt: 0,
            ),
            onSave: (_) {},
            onDelete: (_) {},
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // USE CASES — Layout widgets
  // ===========================================================================

  static WidgetbookUseCase _daySectionUseCase() {
    return WidgetbookUseCase(
      name: 'With Mixed Records',
      builder: (context) {
        final mockRecords = [
          Record(
            id: 'wb-ds-1',
            date: '2026-02-10',
            type: RecordType.heading,
            content: 'Morning',
            metadata: {'heading.level': 1},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
          Record(
            id: 'wb-ds-2',
            date: '2026-02-10',
            type: RecordType.todo,
            content: 'Review PRs',
            metadata: {'todo.checked': false},
            orderPosition: 2.0,
            createdAt: 0,
            updatedAt: 0,
          ),
          Record(
            id: 'wb-ds-3',
            date: '2026-02-10',
            type: RecordType.text,
            content: 'Met with the team about architecture',
            metadata: {},
            orderPosition: 3.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        ];
        return Scaffold(
          body: SingleChildScrollView(
            child: DaySection(
              date: '2026-02-10',
              recordsFuture: Future.value(mockRecords),
              getSectionKey: (_) => _daySectionKey,
              onSave: (_) {},
              onDelete: (_) {},
            ),
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _recordSectionUseCase() {
    return WidgetbookUseCase(
      name: 'Mixed Record Types',
      builder: (context) {
        final mockRecords = [
          Record(
            id: 'wb-rs-1',
            date: '2026-02-10',
            type: RecordType.text,
            content: 'First note',
            metadata: {},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
          Record(
            id: 'wb-rs-2',
            date: '2026-02-10',
            type: RecordType.todo,
            content: 'A todo item',
            metadata: {'todo.checked': false},
            orderPosition: 2.0,
            createdAt: 0,
            updatedAt: 0,
          ),
          Record(
            id: 'wb-rs-3',
            date: '2026-02-10',
            type: RecordType.bulletList,
            content: 'Bullet point',
            metadata: {'bulletList.indentLevel': 0},
            orderPosition: 3.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        ];
        return _wrapWidget(
          RecordSection(
            records: mockRecords,
            date: '2026-02-10',
            onSave: (_) {},
            onDelete: (_) {},
          ),
        );
      },
    );
  }

  // ===========================================================================
  // USE CASES — Decorations
  // ===========================================================================

  static WidgetbookUseCase _dottedGridDecorationUseCase() {
    return WidgetbookUseCase(
      name: 'Grid Pattern',
      builder: (context) {
        final horizontalOffset = context.knobs.int.input(
          label: 'Horizontal Offset',
          initialValue: 16,
        );
        final brightness = Theme.of(context).brightness;
        final dotColor = brightness == Brightness.light
            ? GridConstants.dotColorLight
            : GridConstants.dotColorDark;
        return Scaffold(
          body: Container(
            decoration: DottedGridDecoration(
              horizontalOffset: horizontalOffset.toDouble(),
              color: dotColor,
            ),
          ),
        );
      },
    );
  }
}

void main() {
  runApp(const WidgetbookApp());
}
