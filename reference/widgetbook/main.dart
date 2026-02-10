import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import '../lib/models/record.dart';
import '../lib/widgets/records/adaptive_record_widget.dart';

/// Widgetbook entry point: an isolated environment for developing and
/// previewing widgets with configurable knobs.
///
/// Run with: flutter run -t reference/widgetbook/main.dart
/// Requires `widgetbook: ^3.10.0` in dev_dependencies.
/// See: https://docs.widgetbook.io/
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

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
        DeviceFrameAddon(
          devices: [
            Devices.ios.iPhone13,
            Devices.ios.iPadPro11Inches,
            Devices.linux.laptop,
          ],
        ),
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
  // USE CASES — all metadata keys are namespaced by record type
  // ===========================================================================

  static WidgetbookUseCase _textRecordUseCase() {
    return WidgetbookUseCase(
      name: 'Text Record',
      builder: (context) {
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'A simple text record',
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
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'Section Title',
        );
        final level = context.knobs.int_.input(
          label: 'Heading Level (1-3)',
          initialValue: 1,
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
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'Buy groceries',
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
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'First item in the list',
        );
        final indentLevel = context.knobs.int_.input(
          label: 'Indent Level',
          initialValue: 0,
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
        final habitName = context.knobs.string(
          label: 'Habit Name',
          initialValue: 'Meditation',
        );
        final completionCount = context.knobs.int_.input(
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
              'habit.frequency': 'daily',
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
}

void main() {
  runApp(const WidgetbookApp());
}
