# Lesson 1: Building a Settings Screen

**Difficulty:** Beginner
**Estimated Time:** 2-3 hours
**Prerequisites:** Basic Dart knowledge

## Learning Objectives

By completing this lesson, you will understand:

1. ✅ **StatefulWidget** - How to create widgets that maintain state
2. ✅ **State Management** - How `setState()` triggers rebuilds
3. ✅ **Scaffold & AppBar** - Flutter's standard screen structure
4. ✅ **Material Widgets** - SwitchListTile, ListTile, Divider
5. ✅ **Navigation** - How to navigate between screens
6. ✅ **Widget Lifecycle** - initState(), dispose(), and the build cycle

## What You're Building

A settings screen for your Lifelog app with:
- **Auto-save toggle** - Enable/disable automatic saving
- **Date format selector** - Choose how dates are displayed (e.g., "Jan 23" vs "01/23")
- **Records per page** - Configure how many records load at once
- **About section** - App version and info

This will teach you the fundamentals while adding a useful feature!

## Why This Matters

Settings screens are in almost every app, and building one teaches you:
- How Flutter's state system works
- How to build common UI patterns
- How to navigate between screens
- How to handle user input

## Step 1: Create the Settings Screen File

First, create a new file for your settings screen:

**File:** `/home/user/lifelog/lib/widgets/settings_screen.dart`

```dart
import 'package:flutter/material.dart';

// StatefulWidget because we need to track settings values
// Settings can change, so we need mutable state
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// This is the State class where we store mutable data
// The underscore _ makes it private to this file
class _SettingsScreenState extends State<SettingsScreen> {
  // State variables - these can change over time
  bool _autoSaveEnabled = true;
  String _dateFormat = 'MMM dd'; // Default: "Jan 23"
  int _recordsPerPage = 50;

  @override
  Widget build(BuildContext context) {
    // Scaffold provides the basic Material Design structure
    // It gives us AppBar, body, floating action buttons, etc.
    return Scaffold(
      // AppBar is the top bar with title and back button
      appBar: AppBar(
        title: const Text('Settings'),
        // The back button is automatically added by Flutter!
      ),

      // Body contains the main content
      body: ListView(
        children: [
          // Section header
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'General',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // SwitchListTile combines a switch with a list item
          SwitchListTile(
            title: const Text('Auto-save'),
            subtitle: const Text('Automatically save changes as you type'),
            value: _autoSaveEnabled,
            // onChanged is called when user toggles the switch
            onChanged: (bool value) {
              // setState tells Flutter to rebuild this widget
              // This is HOW you update the UI in Flutter!
              setState(() {
                _autoSaveEnabled = value;
              });
              // TODO: Actually save this preference (Lesson 3)
            },
          ),

          const Divider(),

          // Section header
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Display',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // ListTile with a dropdown for date format
          ListTile(
            title: const Text('Date format'),
            subtitle: Text('Current: $_dateFormat'),
            // When tapped, show a dialog with options
            onTap: () => _showDateFormatDialog(),
          ),

          // Slider for records per page
          ListTile(
            title: const Text('Records per page'),
            subtitle: Text('Load $_recordsPerPage records at a time'),
          ),
          Slider(
            value: _recordsPerPage.toDouble(),
            min: 10,
            max: 100,
            divisions: 9, // Creates 10 steps (10, 20, 30...100)
            label: _recordsPerPage.toString(),
            onChanged: (double value) {
              setState(() {
                _recordsPerPage = value.round();
              });
            },
          ),

          const Divider(),

          // About section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),

          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
        ],
      ),
    );
  }

  // Helper method to show date format dialog
  void _showDateFormatDialog() {
    // showDialog is a Flutter function that displays a modal dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // AlertDialog is a Material Design dialog
        return AlertDialog(
          title: const Text('Choose Date Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Don't take up full height
            children: [
              // RadioListTile lets user pick one option
              RadioListTile<String>(
                title: const Text('Jan 23, 2024'),
                value: 'MMM dd, yyyy',
                groupValue: _dateFormat,
                onChanged: (String? value) {
                  setState(() {
                    _dateFormat = value!;
                  });
                  Navigator.of(context).pop(); // Close dialog
                },
              ),
              RadioListTile<String>(
                title: const Text('01/23/2024'),
                value: 'MM/dd/yyyy',
                groupValue: _dateFormat,
                onChanged: (String? value) {
                  setState(() {
                    _dateFormat = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: const Text('Jan 23'),
                value: 'MMM dd',
                groupValue: _dateFormat,
                onChanged: (String? value) {
                  setState(() {
                    _dateFormat = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## Step 2: Add Navigation from Journal Screen

Now we need a way to get to the settings screen. Let's add a button to the `JournalScreen`.

**File to modify:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

Find the `AppBar` in `JournalScreen` (around line 100) and add an actions button:

```dart
appBar: AppBar(
  title: const Text('Journal'),
  actions: [
    // Add this IconButton to the AppBar
    IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'Settings',
      onPressed: () {
        // Navigator.push adds a new screen to the navigation stack
        // MaterialPageRoute creates a platform-appropriate transition
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
      },
    ),
  ],
),
```

Don't forget to import the settings screen at the top of `journal_screen.dart`:

```dart
import 'settings_screen.dart';
```

## Step 3: Test Your Settings Screen

1. **Hot reload** your app (press `r` in the terminal where flutter run is running, or in VS Code press Cmd/Ctrl+S)
2. Click the **settings icon** in the AppBar
3. Try toggling the **Auto-save switch**
4. Try changing the **Date format**
5. Try adjusting the **Records per page slider**
6. Press the **back button** to return to the journal

## Key Concepts Deep Dive

### 1. StatefulWidget vs StatelessWidget

```dart
// StatelessWidget - CANNOT change after being built
class MyStatelessWidget extends StatelessWidget {
  final String title; // This is immutable (final)

  @override
  Widget build(BuildContext context) {
    return Text(title); // Always shows the same title
  }
}

// StatefulWidget - CAN change over time
class MyStatefulWidget extends StatefulWidget {
  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  int _counter = 0; // This can change!

  @override
  Widget build(BuildContext context) {
    return Text('Count: $_counter'); // Shows updated counter
  }
}
```

**When to use StatefulWidget:**
- User can interact with the widget (toggles, text input, etc.)
- The widget needs to change appearance over time
- You need to maintain state across rebuilds

**When to use StatelessWidget:**
- The widget is purely presentational
- All data comes from constructor parameters
- Nothing changes after the widget is built

### 2. The setState() Method

`setState()` is **THE** way to update the UI in Flutter's vanilla state management:

```dart
// ❌ WRONG - UI won't update
void _onToggle(bool value) {
  _autoSaveEnabled = value; // Variable changes, but Flutter doesn't know!
}

// ✅ CORRECT - UI updates
void _onToggle(bool value) {
  setState(() {
    _autoSaveEnabled = value; // Flutter rebuilds the widget!
  });
}
```

**What setState() does:**
1. Runs the callback function (updates your variables)
2. Marks the widget as "dirty" (needs rebuilding)
3. Schedules a rebuild for the next frame
4. Flutter calls `build()` again
5. The new UI appears on screen

**Important:** Only call `setState()` in State classes, never in StatelessWidget!

### 3. The Widget Lifecycle

Every StatefulWidget goes through these phases:

```dart
class _MyWidgetState extends State<MyWidget> {

  // 1. CONSTRUCTOR - Called when widget is created
  _MyWidgetState() {
    print('Constructor called');
  }

  // 2. initState - Called once when widget is inserted into the tree
  // Use this for: Setup, subscriptions, initial data loading
  @override
  void initState() {
    super.initState();
    print('initState called - widget is being created');
    // Good place to initialize controllers, load data, etc.
  }

  // 3. build - Called to build the UI
  // Called: After initState, after setState, after didUpdateWidget
  @override
  Widget build(BuildContext context) {
    print('build called - rendering UI');
    return Container();
  }

  // 4. didUpdateWidget - Called when parent rebuilds with new configuration
  @override
  void didUpdateWidget(MyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('didUpdateWidget - parent passed new data');
  }

  // 5. dispose - Called when widget is removed permanently
  // Use this for: Cleanup, canceling subscriptions, disposing controllers
  @override
  void dispose() {
    print('dispose called - widget is being destroyed');
    // IMPORTANT: Always clean up resources here!
    super.dispose();
  }
}
```

**For our settings screen:**
- `initState()` would be used to load saved preferences (we'll do this in Lesson 3)
- `build()` is called when we use `setState()`
- `dispose()` would clean up any controllers (we don't have any yet)

### 4. Navigation Basics

Flutter uses a **stack-based navigation** system:

```dart
// PUSH - Add a new screen on top of the stack
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => SettingsScreen()),
);
// Stack: [JournalScreen, SettingsScreen] <- top

// POP - Remove the top screen, go back
Navigator.pop(context);
// Stack: [JournalScreen] <- top
```

The back button automatically calls `Navigator.pop()` for you!

**Why MaterialPageRoute?**
- Provides platform-specific transitions (slide on iOS, fade on Android)
- Handles the navigation animation
- Manages the build context

### 5. Understanding Context

You'll see `context` everywhere in Flutter. But what is it?

```dart
// context is a BuildContext object
// It represents the widget's location in the widget tree
Navigator.push(context, ...);  // "Navigate from THIS widget"
Theme.of(context);              // "Get the theme for THIS widget's location"
MediaQuery.of(context);         // "Get screen size for THIS widget"
```

**Think of context as:** "Where am I in the widget tree?"

It's how Flutter knows:
- What theme to use
- What Navigator to push to
- What screen size we're on
- And much more!

## Testing Checklist

- [ ] Settings screen opens when clicking the settings icon
- [ ] Auto-save toggle switches on and off
- [ ] Date format dialog opens and changes the format display
- [ ] Records per page slider moves smoothly
- [ ] Back button returns to journal screen
- [ ] UI updates immediately when changing settings (no lag)

## Common Mistakes & How to Fix Them

### Mistake 1: Forgetting setState

```dart
// ❌ WRONG
onChanged: (value) {
  _autoSaveEnabled = value; // UI won't update!
}

// ✅ CORRECT
onChanged: (value) {
  setState(() {
    _autoSaveEnabled = value;
  });
}
```

### Mistake 2: Using const incorrectly

```dart
// ❌ WRONG - Can't use const with dynamic values
Text('Current: $_dateFormat', const: true);

// ✅ CORRECT - Only use const for values that never change
const Text('Settings') // Good - title never changes
Text('Current: $_dateFormat') // Good - value changes
```

### Mistake 3: Calling setState in build()

```dart
// ❌ WRONG - Infinite loop!
@override
Widget build(BuildContext context) {
  setState(() { ... }); // This triggers another build, which calls setState again!
  return Container();
}

// ✅ CORRECT - setState in response to user action
void _handleTap() {
  setState(() { ... }); // Only when user does something
}
```

## Challenges to Extend Your Learning

Once you've completed the basic implementation, try these:

### Challenge 1: Add More Settings
Add a setting for:
- First day of week (Sunday/Monday)
- Compact mode (smaller text)
- Sound effects on/off

### Challenge 2: Reset to Defaults
Add a "Reset to Defaults" button that resets all settings.

Hint: Create a method `_resetToDefaults()` that uses `setState()` to reset all variables.

### Challenge 3: Confirmation Dialog
When user enables auto-save, show a confirmation dialog explaining what it does.

Hint: Use `showDialog()` similar to the date format dialog.

## What You've Learned

- ✅ How to create a StatefulWidget
- ✅ How setState() updates the UI
- ✅ How to build a settings screen with Material widgets
- ✅ How to navigate between screens
- ✅ The widget lifecycle (initState, build, dispose)
- ✅ How to handle user input (switches, sliders, dialogs)

## Further Learning

**Official Flutter Documentation:**
- [StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [State management intro](https://docs.flutter.dev/development/data-and-backend/state-mgmt/intro)
- [Navigation basics](https://docs.flutter.dev/cookbook/navigation/navigation-basics)
- [Material Components](https://docs.flutter.dev/development/ui/widgets/material)

**Flutter Widget Catalog:**
- [Scaffold](https://api.flutter.dev/flutter/material/Scaffold-class.html)
- [AppBar](https://api.flutter.dev/flutter/material/AppBar-class.html)
- [ListView](https://api.flutter.dev/flutter/widgets/ListView-class.html)
- [SwitchListTile](https://api.flutter.dev/flutter/material/SwitchListTile-class.html)

## Next Steps

In **Lesson 2: Search Functionality**, you'll learn:
- Working with TextEditingController
- Filtering lists based on user input
- Building a search UI
- Performance considerations when filtering large lists

But first, make sure you understand:
- What StatefulWidget is and when to use it
- How setState() works
- The basic widget lifecycle

**Questions to check your understanding:**
1. Why do we use StatefulWidget for the settings screen instead of StatelessWidget?
2. What happens if you change `_autoSaveEnabled` without calling `setState()`?
3. When is the `build()` method called?
4. How does the back button know to pop the navigation stack?

If you can answer these, you're ready for Lesson 2! 🚀

---

**Previous:** [Main README](../README.md)
**Next:** [Lesson 2: Search Functionality](lesson-02-search-functionality.md)
