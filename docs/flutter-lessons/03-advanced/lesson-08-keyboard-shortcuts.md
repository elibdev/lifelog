# Lesson 8: Advanced Keyboard Shortcuts

**Difficulty:** Advanced
**Estimated Time:** 3-4 hours
**Prerequisites:** All previous lessons, understanding of Focus system

## Learning Objectives

1. ✅ **Actions and Shortcuts** - Flutter's keyboard handling system
2. ✅ **Intent system** - Declarative action handling
3. ✅ **FocusTraversal** - Advanced focus management
4. ✅ **Shortcuts widget** - Mapping keys to actions
5. ✅ **Command palette** - Search-based command execution

## What You're Building

Advanced keyboard navigation:
- **Vim-like shortcuts** - h/j/k/l navigation
- **Command palette** - Cmd/Ctrl+K to search commands
- **Custom shortcuts** - Cmd+N for new note, Cmd+T for new todo
- **Shortcut hints** - Show available shortcuts

This explores Flutter's advanced input handling!

## Understanding Current Keyboard Handling

Your app already has basic keyboard handling in `RecordWidget`. Let's study it:

**File to explore:** `/home/user/lifelog/lib/widgets/record_widget.dart` (line 150-200)

```dart
// Current approach: KeyboardListener with raw key events
Focus(
  onKey: (node, event) {
    if (event is RawKeyDownEvent) {
      // Handle arrow keys, enter, etc.
      // This is the "old" way - works but not declarative
    }
    return KeyEventResult.ignored;
  },
  child: TextField(...),
)
```

**Limitations:**
- Not reusable
- Hard to modify shortcuts
- No way to show shortcut hints
- Tightly coupled to widget

## Step 1: Define Intents

Intents represent user intentions, decoupled from specific keys.

**File:** `/home/user/lifelog/lib/utils/intents.dart` (new file)

```dart
import 'package:flutter/widgets.dart';

// Navigation intents
class MoveUpIntent extends Intent {
  const MoveUpIntent();
}

class MoveDownIntent extends Intent {
  const MoveDownIntent();
}

class MoveToStartIntent extends Intent {
  const MoveToStartIntent();
}

class MoveToEndIntent extends Intent {
  const MoveToEndIntent();
}

// Record management intents
class CreateNoteIntent extends Intent {
  const CreateNoteIntent();
}

class CreateTodoIntent extends Intent {
  const CreateTodoIntent();
}

class DeleteRecordIntent extends Intent {
  const DeleteRecordIntent();
}

class ToggleTodoIntent extends Intent {
  const ToggleTodoIntent();
}

// App-level intents
class ShowCommandPaletteIntent extends Intent {
  const ShowCommandPaletteIntent();
}

class ShowSearchIntent extends Intent {
  const ShowSearchIntent();
}

class ShowSettingsIntent extends Intent {
  const ShowSettingsIntent();
}
```

## Step 2: Define Shortcut Mappings

**File:** `/home/user/lifelog/lib/utils/app_shortcuts.dart` (new file)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'intents.dart';

class AppShortcuts {
  // Define platform-aware modifier
  static final _meta = Platform.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control;

  // Shortcut mappings
  static final Map<ShortcutActivator, Intent> shortcuts = {
    // Navigation (Vim-style)
    const SingleActivator(LogicalKeyboardKey.keyJ):
        const MoveDownIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK):
        const MoveUpIntent(),
    SingleActivator(LogicalKeyboardKey.keyG, shift: true):
        const MoveToEndIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG):
        const MoveToStartIntent(),

    // Navigation (Arrow keys - already handled)
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const MoveDownIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const MoveUpIntent(),

    // Record creation
    SingleActivator(LogicalKeyboardKey.keyN, meta: true):
        const CreateNoteIntent(),
    SingleActivator(LogicalKeyboardKey.keyT, meta: true):
        const CreateTodoIntent(),

    // Record actions
    const SingleActivator(LogicalKeyboardKey.delete):
        const DeleteRecordIntent(),
    SingleActivator(LogicalKeyboardKey.enter, control: true):
        const ToggleTodoIntent(),

    // App-level shortcuts
    SingleActivator(LogicalKeyboardKey.keyK, meta: true):
        const ShowCommandPaletteIntent(),
    SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        const ShowSearchIntent(),
    SingleActivator(LogicalKeyboardKey.comma, meta: true):
        const ShowSettingsIntent(),
  };

  // Shortcut descriptions for showing in UI
  static final Map<Type, ShortcutDescription> descriptions = {
    MoveUpIntent: ShortcutDescription(
      label: 'Move up',
      keys: 'k or ↑',
    ),
    MoveDownIntent: ShortcutDescription(
      label: 'Move down',
      keys: 'j or ↓',
    ),
    CreateNoteIntent: ShortcutDescription(
      label: 'New note',
      keys: '${_platformModifier}+N',
    ),
    CreateTodoIntent: ShortcutDescription(
      label: 'New todo',
      keys: '${_platformModifier}+T',
    ),
    ShowCommandPaletteIntent: ShortcutDescription(
      label: 'Command palette',
      keys: '${_platformModifier}+K',
    ),
    ShowSearchIntent: ShortcutDescription(
      label: 'Search',
      keys: '${_platformModifier}+F',
    ),
    ShowSettingsIntent: ShortcutDescription(
      label: 'Settings',
      keys: '${_platformModifier}+,',
    ),
  };

  static String get _platformModifier =>
      Platform.isMacOS ? '⌘' : 'Ctrl';
}

class ShortcutDescription {
  final String label;
  final String keys;

  ShortcutDescription({required this.label, required this.keys});
}
```

## Step 3: Create Actions

Actions handle the intent execution:

**File:** `/home/user/lifelog/lib/utils/app_actions.dart` (new file)

```dart
import 'package:flutter/material.dart';
import 'intents.dart';

// Actions define what happens when an intent is triggered
class CreateNoteAction extends Action<CreateNoteIntent> {
  final VoidCallback onCreate;

  CreateNoteAction({required this.onCreate});

  @override
  void invoke(CreateNoteIntent intent) {
    onCreate();
  }
}

class CreateTodoAction extends Action<CreateTodoIntent> {
  final VoidCallback onCreate;

  CreateTodoAction({required this.onCreate});

  @override
  void invoke(CreateTodoIntent intent) {
    onCreate();
  }
}

class ShowCommandPaletteAction extends Action<ShowCommandPaletteIntent> {
  final BuildContext context;

  ShowCommandPaletteAction({required this.context});

  @override
  void invoke(ShowCommandPaletteIntent intent) {
    _showCommandPalette(context);
  }

  void _showCommandPalette(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CommandPalette(),
    );
  }
}

// Add more actions as needed...
```

## Step 4: Wrap App with Shortcuts

**File:** `/home/user/lifelog/lib/main.dart`

```dart
@override
Widget build(BuildContext context) {
  return Shortcuts(
    shortcuts: AppShortcuts.shortcuts,
    child: Actions(
      actions: {
        ShowCommandPaletteIntent: ShowCommandPaletteAction(context: context),
        // Add more actions...
      },
      child: MaterialApp(
        // ...existing config...
      ),
    ),
  );
}
```

## Step 5: Create Command Palette

**File:** `/home/user/lifelog/lib/widgets/command_palette.dart` (new file)

```dart
import 'package:flutter/material.dart';
import '../utils/app_shortcuts.dart';
import '../utils/routes.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({Key? key}) : super(key: key);

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  List<Command> _filteredCommands = [];

  final List<Command> _allCommands = [
    Command(
      name: 'Go to Settings',
      description: 'Open settings screen',
      shortcut: '⌘,',
      action: (context) {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.settings);
      },
    ),
    Command(
      name: 'Go to Statistics',
      description: 'View journal statistics',
      action: (context) {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.statistics);
      },
    ),
    Command(
      name: 'Export Data',
      description: 'Export journal to JSON or Markdown',
      action: (context) {
        Navigator.pop(context);
        Navigator.pushNamed(context, AppRoutes.export);
      },
    ),
    Command(
      name: 'Search',
      description: 'Search journal entries',
      shortcut: '⌘F',
      action: (context) {
        Navigator.pop(context);
        // Trigger search
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _filteredCommands = _allCommands;
    _searchController.addListener(_filterCommands);
  }

  void _filterCommands() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCommands = _allCommands
          .where((cmd) =>
              cmd.name.toLowerCase().contains(query) ||
              cmd.description.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type a command or search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Command list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCommands.length,
                itemBuilder: (context, index) {
                  final command = _filteredCommands[index];
                  return ListTile(
                    title: Text(command.name),
                    subtitle: Text(command.description),
                    trailing: command.shortcut != null
                        ? Chip(label: Text(command.shortcut!))
                        : null,
                    onTap: () => command.action(context),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class Command {
  final String name;
  final String description;
  final String? shortcut;
  final Function(BuildContext) action;

  Command({
    required this.name,
    required this.description,
    this.shortcut,
    required this.action,
  });
}
```

## Key Concepts

### 1. Intent vs Action

```dart
// Intent = WHAT to do (declarative)
class SaveIntent extends Intent {}

// Action = HOW to do it (imperative)
class SaveAction extends Action<SaveIntent> {
  @override
  void invoke(SaveIntent intent) {
    // Actual save logic
  }
}

// Shortcut = WHEN to do it (key mapping)
SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent()
```

### 2. Shortcut Activators

```dart
// Single key
SingleActivator(LogicalKeyboardKey.keyA)

// With modifiers
SingleActivator(LogicalKeyboardKey.keyS, meta: true) // Cmd+S
SingleActivator(LogicalKeyboardKey.keyS, control: true) // Ctrl+S
SingleActivator(LogicalKeyboardKey.keyS, shift: true) // Shift+S
SingleActivator(LogicalKeyboardKey.keyS, alt: true) // Alt+S

// Multiple modifiers
SingleActivator(
  LogicalKeyboardKey.keyS,
  control: true,
  shift: true,
) // Ctrl+Shift+S

// Character activator (any key that produces this character)
CharacterActivator('a')
```

### 3. Actions Widget

```dart
Actions(
  actions: {
    SaveIntent: SaveAction(),
    OpenIntent: OpenAction(),
  },
  child: Shortcuts(
    shortcuts: {
      SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
    },
    child: YourWidget(),
  ),
)
```

## Testing Checklist

- [ ] Cmd/Ctrl+K opens command palette
- [ ] Vim keys (j/k) navigate records
- [ ] Cmd/Ctrl+N creates new note
- [ ] Cmd/Ctrl+T creates new todo
- [ ] Command palette search works
- [ ] Shortcuts work across all screens
- [ ] Platform-specific modifiers work

## Challenges

**Challenge 1:** Add keyboard shortcuts help screen (?)
**Challenge 2:** Make shortcuts customizable in settings
**Challenge 3:** Add Ctrl+Z for undo (preview of Lesson 9)
**Challenge 4:** Add number keys for quick navigation

## What You've Learned

- ✅ Intent-based action system
- ✅ Shortcuts widget and activators
- ✅ Command palette pattern
- ✅ Platform-aware keyboard handling
- ✅ Declarative vs imperative shortcuts

---

**Previous:** [Lesson 7: Custom Widgets](../02-intermediate/lesson-07-custom-widgets.md)
**Next:** [Lesson 9: Undo/Redo System](lesson-09-undo-redo.md)
