import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:lifelog/models/block.dart';
import 'package:lifelog/widgets/blocks/adaptive_block_widget.dart';

/// Widgetbook entry point: an isolated environment for developing and
/// previewing widgets with configurable knobs.
///
/// Run with: flutter run -t widgetbook/main.dart
/// See: https://docs.widgetbook.io/
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        // Theme addon: toggle between light and dark mode
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: _lightTheme()),
            WidgetbookTheme(name: 'Dark', data: _darkTheme()),
          ],
        ),
        // Device frame addon: preview on different screen sizes
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
          name: 'Blocks',
          children: [
            WidgetbookComponent(
              name: 'AdaptiveBlockWidget',
              useCases: [
                _textBlockUseCase(),
                _headingBlockUseCase(),
                _todoBlockUseCase(),
                _bulletListBlockUseCase(),
                _habitBlockUseCase(),
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
  // USE CASES
  // Each use case creates a mock Block and renders AdaptiveBlockWidget.
  // Knobs let you tweak properties interactively in the Widgetbook sidebar.
  // ===========================================================================

  static WidgetbookUseCase _textBlockUseCase() {
    return WidgetbookUseCase(
      name: 'Text Block',
      builder: (context) {
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'A simple text block',
        );
        return _wrapBlock(
          Block(
            id: 'wb-text-1',
            date: '2026-02-10',
            type: BlockType.text,
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

  static WidgetbookUseCase _headingBlockUseCase() {
    return WidgetbookUseCase(
      name: 'Heading Block',
      builder: (context) {
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'Section Title',
        );
        final level = context.knobs.int_.input(
          label: 'Heading Level (1-3)',
          initialValue: 1,
        );
        return _wrapBlock(
          Block(
            id: 'wb-heading-1',
            date: '2026-02-10',
            type: BlockType.heading,
            content: content,
            metadata: {'level': level},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _todoBlockUseCase() {
    return WidgetbookUseCase(
      name: 'Todo Block',
      builder: (context) {
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'Buy groceries',
        );
        final checked = context.knobs.boolean(
          label: 'Checked',
          initialValue: false,
        );
        return _wrapBlock(
          Block(
            id: 'wb-todo-1',
            date: '2026-02-10',
            type: BlockType.todo,
            content: content,
            metadata: {'checked': checked},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _bulletListBlockUseCase() {
    return WidgetbookUseCase(
      name: 'Bullet List Block',
      builder: (context) {
        final content = context.knobs.string(
          label: 'Content',
          initialValue: 'First item in the list',
        );
        final indentLevel = context.knobs.int_.input(
          label: 'Indent Level',
          initialValue: 0,
        );
        return _wrapBlock(
          Block(
            id: 'wb-bullet-1',
            date: '2026-02-10',
            type: BlockType.bulletList,
            content: content,
            metadata: {'indentLevel': indentLevel},
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  static WidgetbookUseCase _habitBlockUseCase() {
    return WidgetbookUseCase(
      name: 'Habit Block',
      builder: (context) {
        final habitName = context.knobs.string(
          label: 'Habit Name',
          initialValue: 'Meditation',
        );
        final completionCount = context.knobs.int_.input(
          label: 'Completions',
          initialValue: 5,
        );
        // Generate mock completion dates
        final completions = List.generate(
          completionCount,
          (i) => '2026-02-${(10 - i).toString().padLeft(2, '0')}',
        );
        return _wrapBlock(
          Block(
            id: 'wb-habit-1',
            date: '2026-02-10',
            type: BlockType.habit,
            content: habitName,
            metadata: {
              'habitName': habitName,
              'frequency': 'daily',
              'completions': completions,
            },
            orderPosition: 1.0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      },
    );
  }

  /// Wraps a Block in AdaptiveBlockWidget with no-op callbacks for previewing.
  static Widget _wrapBlock(Block block) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 500,
          child: AdaptiveBlockWidget(
            block: block,
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
