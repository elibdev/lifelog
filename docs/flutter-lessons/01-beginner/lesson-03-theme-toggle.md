# Lesson 3: Dark/Light Theme with Persistence

**Difficulty:** Beginner/Intermediate
**Estimated Time:** 3-4 hours
**Prerequisites:** Lessons 1-2 (StatefulWidget, setState, SharedPreferences concept)

## Learning Objectives

By completing this lesson, you will understand:

1. ✅ **ThemeData** - Flutter's theming system
2. ✅ **MaterialApp theming** - How apps apply themes globally
3. ✅ **SharedPreferences** - Persisting simple data locally
4. ✅ **Lifting state up** - Moving state to parent widgets
5. ✅ **Async programming basics** - async/await with Future
6. ✅ **App-level state** - Managing state across the entire app

## What You're Building

A complete dark/light theme system that:
- **Toggles between themes** with a switch in settings
- **Persists the choice** (remembers after app restart)
- **Applies globally** to the entire app
- **Uses Material 3** design system
- **Smooth transitions** between themes

This teaches you app-level state management and data persistence!

## Why This Matters

Theme management teaches you:
- How to structure app-level state
- How to persist user preferences
- How to work with async operations
- How themes propagate through the widget tree
- Real-world state management patterns

## Step 1: Add SharedPreferences Dependency

First, we need to add SharedPreferences to your project.

**File:** `/home/user/lifelog/pubspec.yaml`

Add this under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqlite3: ^2.1.0
  path_provider: ^2.0.15
  uuid: ^3.0.7
  intl: ^0.18.1
  shared_preferences: ^2.2.2  # ADD THIS LINE
```

Then run in your terminal:

```bash
flutter pub get
```

## Step 2: Create a Theme Manager

Let's create a dedicated class to manage theme state and persistence.

**File:** `/home/user/lifelog/lib/utils/theme_manager.dart` (new file)

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ThemeManager handles loading, saving, and notifying about theme changes
// It uses ChangeNotifier to notify listeners when theme changes
class ThemeManager with ChangeNotifier {
  // Private variable to track current theme mode
  ThemeMode _themeMode = ThemeMode.system; // Default: follow system

  // Public getter to access theme mode
  ThemeMode get themeMode => _themeMode;

  // Key for storing theme preference
  static const String _themePrefKey = 'theme_mode';

  // Constructor - load saved theme when created
  ThemeManager() {
    _loadThemeFromPrefs();
  }

  // Load theme preference from disk
  Future<void> _loadThemeFromPrefs() async {
    // SharedPreferences.getInstance() is async (takes time to load from disk)
    // await pauses execution until the Future completes
    final prefs = await SharedPreferences.getInstance();

    // Get saved theme mode (returns null if not found)
    final savedTheme = prefs.getString(_themePrefKey);

    // Convert string to ThemeMode enum
    if (savedTheme != null) {
      switch (savedTheme) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
          _themeMode = ThemeMode.system;
          break;
      }

      // Notify listeners that theme has changed
      // This triggers a rebuild in widgets listening to this manager
      notifyListeners();
    }
  }

  // Change theme mode and save to disk
  Future<void> setThemeMode(ThemeMode mode) async {
    // Update in-memory value
    _themeMode = mode;

    // Save to disk for persistence
    final prefs = await SharedPreferences.getInstance();

    // Convert ThemeMode to string
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }

    await prefs.setString(_themePrefKey, modeString);

    // Notify all listeners (widgets) that theme changed
    // This causes MaterialApp to rebuild with new theme
    notifyListeners();
  }

  // Convenience getters for checking current mode
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;
}
```

## Step 3: Define Your Themes

Let's create beautiful light and dark themes using Material 3.

**File:** `/home/user/lifelog/lib/utils/app_theme.dart` (new file)

```dart
import 'package:flutter/material.dart';

// AppTheme defines the visual appearance of the entire app
class AppTheme {
  // Light theme configuration
  static ThemeData lightTheme = ThemeData(
    // Use Material 3 design
    useMaterial3: true,

    // Color scheme for light mode
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue, // Primary color
      brightness: Brightness.light,
    ),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0, // Flat design
    ),

    // Card theme (for future use)
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Input decoration (TextField borders, etc.)
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
    ),
  );

  // Dark theme configuration
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,

    // Color scheme for dark mode
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),

    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
    ),
  );
}
```

## Step 4: Update main.dart to Use ThemeManager

Now we need to "lift state up" to the root of the app.

**File:** `/home/user/lifelog/lib/main.dart`

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'widgets/journal_screen.dart';
import 'utils/theme_manager.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const MyApp());
}

// MyApp is now StatefulWidget because it needs to manage theme state
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Create theme manager instance
  // This will persist throughout the app's lifetime
  final ThemeManager _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();

    // Listen to theme changes
    // When ThemeManager calls notifyListeners(), this rebuilds MyApp
    _themeManager.addListener(() {
      setState(() {
        // This setState causes MaterialApp to rebuild with new theme
      });
    });
  }

  @override
  void dispose() {
    // Clean up listener
    _themeManager.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lifelog',
      debugShowCheckedModeBanner: false,

      // Apply themes
      theme: AppTheme.lightTheme, // Used when themeMode is light
      darkTheme: AppTheme.darkTheme, // Used when themeMode is dark
      themeMode: _themeManager.themeMode, // Current mode (light/dark/system)

      // Pass themeManager down to screens that need it
      home: JournalScreen(themeManager: _themeManager),
    );
  }
}
```

## Step 5: Update JournalScreen to Accept ThemeManager

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

Update the widget to accept and use the theme manager:

```dart
class JournalScreen extends StatefulWidget {
  // Add themeManager parameter
  final ThemeManager themeManager;

  const JournalScreen({
    Key? key,
    required this.themeManager, // Make it required
  }) : super(key: key);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  // Access themeManager via widget.themeManager
  // ...rest of the class stays the same...
}
```

Update the settings navigation to pass themeManager:

```dart
// In the settings button onPressed
IconButton(
  icon: const Icon(Icons.settings),
  tooltip: 'Settings',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          themeManager: widget.themeManager, // Pass it down
        ),
      ),
    );
  },
),
```

## Step 6: Add Theme Toggle to Settings Screen

**File:** `/home/user/lifelog/lib/widgets/settings_screen.dart`

Update to use the theme manager:

```dart
import 'package:flutter/material.dart';
import '../utils/theme_manager.dart'; // Import ThemeManager

class SettingsScreen extends StatefulWidget {
  // Accept theme manager
  final ThemeManager themeManager;

  const SettingsScreen({
    Key? key,
    required this.themeManager,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ...existing state variables...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // ...existing General section...

          // NEW: Appearance section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // Theme mode selector
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_getThemeModeText()),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showThemeModeDialog,
          ),

          const Divider(),

          // ...rest of existing sections...
        ],
      ),
    );
  }

  // Get current theme mode as text
  String _getThemeModeText() {
    switch (widget.themeManager.themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }

  // Show dialog to select theme mode
  void _showThemeModeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                subtitle: const Text('Always use light theme'),
                value: ThemeMode.light,
                groupValue: widget.themeManager.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    // This will save to SharedPreferences AND update the UI
                    widget.themeManager.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                subtitle: const Text('Always use dark theme'),
                value: ThemeMode.dark,
                groupValue: widget.themeManager.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.themeManager.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('System default'),
                subtitle: const Text('Follow system theme settings'),
                value: ThemeMode.system,
                groupValue: widget.themeManager.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.themeManager.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
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

## Step 7: Test Your Theme System

1. **Run the app**: `flutter run`
2. **Open Settings** and tap "Theme"
3. **Select "Dark"** - watch the app instantly switch to dark mode
4. **Close and restart the app** - it should remember dark mode!
5. **Try "System default"** - change your device theme and watch the app follow
6. **Try "Light"** - switch back to light mode

## Key Concepts Deep Dive

### 1. Lifting State Up

When multiple widgets need access to the same state, move it to their common ancestor:

```dart
// ❌ BAD - Theme state in SettingsScreen
// JournalScreen can't access it!
class SettingsScreen {
  ThemeMode _themeMode = ThemeMode.light;
}

// ✅ GOOD - Theme state in MyApp (common ancestor)
// Both JournalScreen and SettingsScreen can access it!
class MyApp {
  ThemeManager _themeManager = ThemeManager();
  // Pass down to children via constructor
}
```

**The rule:** State should live at the lowest common ancestor of all widgets that need it.

### 2. ChangeNotifier Pattern

`ChangeNotifier` is Flutter's built-in observer pattern:

```dart
// Step 1: Create a class that extends ChangeNotifier
class ThemeManager with ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  void setTheme(ThemeMode mode) {
    _mode = mode;
    notifyListeners(); // Notify all listeners
  }
}

// Step 2: Add listener in widget
@override
void initState() {
  super.initState();
  _themeManager.addListener(_onThemeChanged);
}

void _onThemeChanged() {
  setState(() {}); // Rebuild when notified
}

// Step 3: Clean up
@override
void dispose() {
  _themeManager.removeListener(_onThemeChanged);
  super.dispose();
}
```

**This pattern is the foundation of Provider** (a popular state management library).

### 3. Async/Await Basics

Asynchronous operations don't block the UI:

```dart
// Without async/await (callback hell)
void loadTheme() {
  SharedPreferences.getInstance().then((prefs) {
    final theme = prefs.getString('theme');
    setState(() {
      _theme = theme;
    });
  });
}

// With async/await (clean and readable)
Future<void> loadTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final theme = prefs.getString('theme');
  setState(() {
    _theme = theme;
  });
}
```

**Key points:**
- `async` marks a function as asynchronous
- `await` pauses execution until the Future completes
- The UI doesn't freeze while waiting
- Always handle errors with try/catch

### 4. SharedPreferences

SharedPreferences stores simple key-value pairs on disk:

```dart
// Save data
final prefs = await SharedPreferences.getInstance();
await prefs.setString('key', 'value');
await prefs.setInt('count', 42);
await prefs.setBool('flag', true);

// Load data
final value = prefs.getString('key'); // Returns null if not found
final count = prefs.getInt('count') ?? 0; // Use ?? for defaults
final flag = prefs.getBool('flag') ?? false;

// Remove data
await prefs.remove('key');

// Clear all data
await prefs.clear();
```

**What it's good for:**
- User preferences (theme, language, etc.)
- Simple settings
- Small amounts of data

**What it's NOT good for:**
- Large data (use SQLite instead)
- Sensitive data (use flutter_secure_storage)
- Complex objects (use JSON + SQLite)

### 5. ThemeData and Material 3

Flutter's theming system is powerful:

```dart
ThemeData(
  useMaterial3: true, // Use Material 3 design

  // Color scheme (auto-generates many colors)
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue, // All colors derived from this
    brightness: Brightness.light,
  ),

  // Or define colors manually
  colorScheme: const ColorScheme.light(
    primary: Colors.blue,
    secondary: Colors.green,
    error: Colors.red,
    background: Colors.white,
  ),

  // Component themes
  appBarTheme: AppBarTheme(...),
  cardTheme: CardTheme(...),
  textTheme: TextTheme(...),
);
```

**Accessing theme in widgets:**
```dart
// Get the current theme
final theme = Theme.of(context);

// Use theme colors
Container(color: theme.colorScheme.primary);
Text('Hello', style: theme.textTheme.headlineMedium);

// Check if dark mode
final isDark = theme.brightness == Brightness.dark;
```

### 6. Data Flow in This Architecture

```
User taps "Dark mode"
    ↓
SettingsScreen.onChanged()
    ↓
themeManager.setThemeMode(ThemeMode.dark)
    ↓
1. Update _themeMode in memory
2. Save to SharedPreferences (disk)
3. Call notifyListeners()
    ↓
MyApp listener triggered
    ↓
MyApp calls setState()
    ↓
MaterialApp rebuilds with darkTheme
    ↓
Entire app switches to dark mode
```

## Testing Checklist

- [ ] Theme toggle appears in Settings
- [ ] Selecting "Light" switches to light mode
- [ ] Selecting "Dark" switches to dark mode
- [ ] Selecting "System" follows device theme
- [ ] Theme persists after app restart
- [ ] Transition is smooth and instant
- [ ] All screens update when theme changes

## Common Mistakes & How to Fix Them

### Mistake 1: Forgetting to await

```dart
// ❌ WRONG - Doesn't wait for prefs to load
void loadTheme() async {
  final prefs = SharedPreferences.getInstance(); // Missing await!
  final theme = prefs.getString('theme'); // Error!
}

// ✅ CORRECT
Future<void> loadTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final theme = prefs.getString('theme');
}
```

### Mistake 2: Not removing listeners

```dart
// ❌ WRONG - Memory leak
@override
void initState() {
  manager.addListener(_onChange);
  // No dispose = listener stays forever
}

// ✅ CORRECT
@override
void dispose() {
  manager.removeListener(_onChange);
  super.dispose();
}
```

### Mistake 3: Modifying state without notifyListeners

```dart
// ❌ WRONG - Listeners not notified
void setTheme(ThemeMode mode) {
  _themeMode = mode; // Changed but no notification
}

// ✅ CORRECT
void setTheme(ThemeMode mode) {
  _themeMode = mode;
  notifyListeners(); // Tell listeners!
}
```

### Mistake 4: Calling async in constructor

```dart
// ❌ WRONG - Constructors can't be async
ThemeManager() {
  await _loadTheme(); // Error!
}

// ✅ CORRECT - Call async method from constructor
ThemeManager() {
  _loadTheme(); // Don't await in constructor
}

Future<void> _loadTheme() async {
  // Async operations here
}
```

## Challenges to Extend Your Learning

### Challenge 1: Accent Color Picker
Let users choose a custom accent color (red, green, blue, etc.).

Hint: Store color value in SharedPreferences and rebuild theme.

### Challenge 2: Font Size Setting
Add a setting to increase/decrease text size app-wide.

Hint: Modify `textTheme` in ThemeData based on user preference.

### Challenge 3: Animation
Add a fade animation when switching themes.

Hint: Use `AnimatedTheme` or `AnimatedContainer`.

### Challenge 4: AMOLED Black Mode
Add a third dark theme option with pure black background (#000000) for AMOLED screens.

Hint: Create a third theme and add it to ThemeManager.

## What You've Learned

- ✅ How to structure app-level state with ChangeNotifier
- ✅ How to persist data with SharedPreferences
- ✅ How to lift state up to common ancestors
- ✅ How to use async/await for asynchronous operations
- ✅ How to apply themes globally with MaterialApp
- ✅ The observer pattern (addListener/notifyListeners)
- ✅ How to pass data down the widget tree

## Further Learning

**Official Flutter Documentation:**
- [ThemeData](https://api.flutter.dev/flutter/material/ThemeData-class.html)
- [Material 3 theming](https://m3.material.io/)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
- [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)
- [Async programming](https://dart.dev/codelabs/async-await)

**State Management:**
- [Provider package](https://pub.dev/packages/provider) (built on ChangeNotifier)
- [State management intro](https://docs.flutter.dev/development/data-and-backend/state-mgmt/intro)

## Next Steps

Congratulations! You've completed the beginner lessons. You now understand:
- StatefulWidget and state management
- Text input and filtering
- App-level state and persistence
- Themes and Material Design

In **Lesson 4: Navigation & Routes**, you'll learn:
- Proper navigation architecture
- Named routes
- Passing data between screens
- Deep linking

**Questions to check your understanding:**
1. Why do we "lift state up" to MyApp instead of keeping it in SettingsScreen?
2. What does `notifyListeners()` do?
3. Why must we use `await` with SharedPreferences?
4. What happens if you forget to remove a listener in dispose()?

Ready for intermediate lessons? Let's go! 🚀

---

**Previous:** [Lesson 2: Search Functionality](lesson-02-search-functionality.md)
**Next:** [Lesson 4: Navigation & Routes](../02-intermediate/lesson-04-navigation-routes.md)
