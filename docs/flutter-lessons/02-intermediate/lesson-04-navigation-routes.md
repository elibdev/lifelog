# Lesson 4: Navigation & Named Routes

**Difficulty:** Intermediate
**Estimated Time:** 2-3 hours
**Prerequisites:** Lessons 1-3 (Basic navigation, StatefulWidget, state management)

## Learning Objectives

By completing this lesson, you will understand:

1. ✅ **Named routes** - Defining routes with string identifiers
2. ✅ **Route arguments** - Passing data to routes
3. ✅ **onGenerateRoute** - Dynamic route generation
4. ✅ **Navigation patterns** - Different ways to navigate in Flutter
5. ✅ **Route guards** - Validating navigation
6. ✅ **Deep linking** - Opening specific screens from URLs

## What You're Building

A proper navigation system for Lifelog:
- **Named routes** instead of imperative navigation
- **Route arguments** for passing data (like specific dates)
- **Deep linking** to jump to specific dates
- **Statistics screen** as a new destination
- **About screen** with app info

This teaches you production-ready navigation architecture!

## Why This Matters

As apps grow, imperative navigation (`Navigator.push(MaterialPageRoute(...))`) becomes messy. Named routes provide:
- Cleaner, more maintainable code
- Centralized route definitions
- Easier testing and refactoring
- Support for deep linking
- Better separation of concerns

## Current Navigation (Before)

Currently, you navigate like this:

```dart
// Imperative - tightly coupled, hard to test
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SettingsScreen(themeManager: manager),
  ),
);
```

**Problems:**
- Route creation scattered across codebase
- Hard to track all navigation paths
- Can't navigate by name
- No deep linking support

## Step 1: Define Route Names

Create a central place for all route definitions.

**File:** `/home/user/lifelog/lib/utils/routes.dart` (new file)

```dart
// Central route definitions
// Using constants prevents typos and makes refactoring easier
class AppRoutes {
  // Route names as static constants
  static const String home = '/';
  static const String settings = '/settings';
  static const String statistics = '/statistics';
  static const String about = '/about';
  static const String dateDetail = '/date'; // e.g., /date/2024-01-23

  // Private constructor prevents instantiation
  AppRoutes._();
}
```

## Step 2: Create Statistics Screen

Let's add a new screen to demonstrate navigation with arguments.

**File:** `/home/user/lifelog/lib/widgets/statistics_screen.dart` (new file)

```dart
import 'package:flutter/material.dart';
import '../database/record_repository.dart';
import '../models/record.dart';

// Statistics screen shows insights about your journal
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Statistics data
  int _totalRecords = 0;
  int _totalTodos = 0;
  int _totalNotes = 0;
  int _completedTodos = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    // Load all records and calculate statistics
    final repository = RecordRepository();

    // Get all records from database
    // Note: In production, you'd paginate this for large datasets
    final allRecords = await repository.getAllRecords();

    setState(() {
      _totalRecords = allRecords.length;

      // Count todos and notes
      _totalTodos = allRecords.where((r) => r is TodoRecord).length;
      _totalNotes = allRecords.where((r) => r is NoteRecord).length;

      // Count completed todos
      _completedTodos = allRecords
          .whereType<TodoRecord>() // Type-safe filtering
          .where((todo) => todo.completed)
          .length;

      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildStatCard(
                  title: 'Total Records',
                  value: _totalRecords.toString(),
                  icon: Icons.article,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  title: 'Todos',
                  value: _totalTodos.toString(),
                  subtitle: '$_completedTodos completed',
                  icon: Icons.check_box,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  title: 'Notes',
                  value: _totalNotes.toString(),
                  icon: Icons.note,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                if (_totalTodos > 0)
                  _buildCompletionChart(),
              ],
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionChart() {
    final completionRate = _totalTodos > 0 ? _completedTodos / _totalTodos : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todo Completion Rate',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: completionRate,
                minHeight: 20,
                backgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(completionRate * 100).toStringAsFixed(1)}% completed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

## Step 3: Create About Screen

**File:** `/home/user/lifelog/lib/widgets/about_screen.dart` (new file)

```dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Add to pubspec.yaml

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          // App icon/logo
          const Icon(
            Icons.book,
            size: 80,
          ),
          const SizedBox(height: 16),
          // App name
          Text(
            'Lifelog',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          // Version
          Text(
            'Version $_version',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          const Divider(),
          // Description
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Lifelog is a simple, elegant journal app for tracking your daily thoughts, tasks, and notes.',
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(),
          // License button
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Licenses'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show Flutter's built-in license page
              showLicensePage(context: context);
            },
          ),
        ],
      ),
    );
  }
}
```

Add to `pubspec.yaml`:
```yaml
dependencies:
  package_info_plus: ^4.2.0
```

## Step 4: Implement Route Generation

Now let's create the route generator that maps route names to screens.

**File:** `/home/user/lifelog/lib/utils/route_generator.dart` (new file)

```dart
import 'package:flutter/material.dart';
import '../widgets/journal_screen.dart';
import '../widgets/settings_screen.dart';
import '../widgets/statistics_screen.dart';
import '../widgets/about_screen.dart';
import '../utils/theme_manager.dart';
import '../utils/routes.dart';

// RouteGenerator handles all route navigation
class RouteGenerator {
  // Generate routes based on settings
  // This is called by MaterialApp when you use Navigator.pushNamed()
  static Route<dynamic> generateRoute(RouteSettings settings, ThemeManager themeManager) {
    // Extract route name and arguments
    final routeName = settings.name;
    final args = settings.arguments;

    // Route to the appropriate screen based on name
    switch (routeName) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => JournalScreen(themeManager: themeManager),
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => SettingsScreen(themeManager: themeManager),
        );

      case AppRoutes.statistics:
        return MaterialPageRoute(
          builder: (_) => const StatisticsScreen(),
        );

      case AppRoutes.about:
        return MaterialPageRoute(
          builder: (_) => const AboutScreen(),
        );

      case AppRoutes.dateDetail:
        // Example of passing arguments
        // Usage: Navigator.pushNamed(context, AppRoutes.dateDetail, arguments: DateTime.now())
        if (args is DateTime) {
          return MaterialPageRoute(
            builder: (_) => JournalScreen(
              themeManager: themeManager,
              initialDate: args, // Scroll to this date
            ),
          );
        }
        // Invalid arguments, show error
        return _errorRoute('Invalid arguments for date detail');

      default:
        // Route not found
        return _errorRoute('Route not found: $routeName');
    }
  }

  // Error route shown when navigation fails
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## Step 5: Update main.dart to Use Route Generator

**File:** `/home/user/lifelog/lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'utils/theme_manager.dart';
import 'utils/app_theme.dart';
import 'utils/routes.dart';
import 'utils/route_generator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeManager _themeManager = ThemeManager();

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _themeManager.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lifelog',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeManager.themeMode,

      // NEW: Use named routes
      initialRoute: AppRoutes.home, // Start at home screen

      // NEW: Route generator
      // This is called whenever you use Navigator.pushNamed()
      onGenerateRoute: (settings) {
        return RouteGenerator.generateRoute(settings, _themeManager);
      },

      // Remove the old 'home' parameter (replaced by initialRoute)
    );
  }
}
```

## Step 6: Update Navigation Calls

Now update all navigation to use named routes.

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

Update the settings button:

```dart
// OLD WAY:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SettingsScreen(themeManager: widget.themeManager),
  ),
);

// NEW WAY:
Navigator.pushNamed(context, AppRoutes.settings);
```

Add a statistics button:

```dart
// In AppBar actions
IconButton(
  icon: const Icon(Icons.bar_chart),
  tooltip: 'Statistics',
  onPressed: () {
    Navigator.pushNamed(context, AppRoutes.statistics);
  },
),
```

**File:** `/home/user/lifelog/lib/widgets/settings_screen.dart`

Update the "About" button to use named routes:

```dart
ListTile(
  leading: const Icon(Icons.info),
  title: const Text('About'),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.pushNamed(context, AppRoutes.about);
  },
),
```

## Step 7: Add Deep Linking (Optional Advanced)

This allows opening specific dates from URLs or notifications.

Update `JournalScreen` to accept an initial date:

```dart
class JournalScreen extends StatefulWidget {
  final ThemeManager themeManager;
  final DateTime? initialDate; // NEW: Optional initial date

  const JournalScreen({
    Key? key,
    required this.themeManager,
    this.initialDate,
  }) : super(key: key);

  // ...
}

class _JournalScreenState extends State<JournalScreen> {
  @override
  void initState() {
    super.initState();

    // Load initial date if provided, otherwise load today
    final dateToLoad = widget.initialDate ?? DateTime.now();
    _loadRecordsForDate(dateToLoad);

    // If initial date provided, scroll to it
    if (widget.initialDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDate(widget.initialDate!);
      });
    }
  }

  // Add method to scroll to specific date
  void _scrollToDate(DateTime date) {
    // Implementation depends on your scrolling logic
    // This is a placeholder for the concept
  }
}
```

Now you can navigate with arguments:

```dart
// Jump to a specific date
Navigator.pushNamed(
  context,
  AppRoutes.dateDetail,
  arguments: DateTime(2024, 1, 15),
);
```

## Testing Checklist

- [ ] App starts on home screen
- [ ] Settings button navigates using named route
- [ ] Statistics button opens statistics screen
- [ ] About screen shows from settings
- [ ] Back button works on all screens
- [ ] Invalid route shows error screen
- [ ] Statistics load correctly
- [ ] All navigation is smooth

## Key Concepts Deep Dive

### 1. Named Routes vs Imperative Navigation

```dart
// Imperative (old way)
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => SettingsScreen()),
);

// Named routes (new way)
Navigator.pushNamed(context, '/settings');
```

**Benefits of named routes:**
- Centralized route definitions
- Easier to refactor
- Can be called from anywhere with just a string
- Better for analytics and tracking
- Supports deep linking

### 2. RouteSettings

Every route has settings with useful info:

```dart
class RouteSettings {
  final String? name;        // Route name (e.g., '/settings')
  final Object? arguments;   // Data passed to route
}
```

### 3. Passing Arguments

```dart
// Sending side
Navigator.pushNamed(
  context,
  '/user-profile',
  arguments: {'userId': '123', 'name': 'John'},
);

// Receiving side (in onGenerateRoute)
static Route<dynamic> generateRoute(RouteSettings settings) {
  final args = settings.arguments as Map<String, dynamic>?;

  if (settings.name == '/user-profile') {
    return MaterialPageRoute(
      builder: (_) => UserProfile(
        userId: args?['userId'],
        name: args?['name'],
      ),
    );
  }
}
```

### 4. Navigation Stack

Flutter uses a stack for navigation:

```dart
// Stack: [Home]
Navigator.pushNamed(context, '/settings');
// Stack: [Home, Settings]

Navigator.pushNamed(context, '/about');
// Stack: [Home, Settings, About]

Navigator.pop(context);
// Stack: [Home, Settings]

Navigator.popUntil(context, ModalRoute.withName('/'));
// Stack: [Home]
```

### 5. Different Navigation Methods

```dart
// Push - add to stack
Navigator.pushNamed(context, '/settings');

// Pop - remove from stack
Navigator.pop(context);

// Push replacement - replace current route
Navigator.pushReplacementNamed(context, '/login');

// Push and remove all previous
Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);

// Can pop? - check if can go back
if (Navigator.canPop(context)) {
  Navigator.pop(context);
}
```

## Common Mistakes

### Mistake 1: Forgetting to return in switch

```dart
// ❌ WRONG
static Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/home':
      MaterialPageRoute(builder: (_) => HomeScreen()); // Missing return!
  }
}

// ✅ CORRECT
static Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/home':
      return MaterialPageRoute(builder: (_) => HomeScreen());
  }
}
```

### Mistake 2: Wrong argument type

```dart
// Sending DateTime
Navigator.pushNamed(context, '/date', arguments: DateTime.now());

// ❌ WRONG - Assuming String
if (args is String) { // Will never be true!
  // ...
}

// ✅ CORRECT - Check actual type
if (args is DateTime) {
  // ...
}
```

## Challenges

### Challenge 1: Route Transitions
Customize the transition animation between screens.

Hint: Create a custom `PageRouteBuilder` with custom transitions.

### Challenge 2: Route Guards
Prevent navigation to settings if user hasn't agreed to terms.

Hint: Check condition in `generateRoute` before returning route.

### Challenge 3: Bottom Navigation
Add a bottom navigation bar to switch between Journal, Statistics, and Settings.

Hint: Use `BottomNavigationBar` widget with named routes.

## What You've Learned

- ✅ Named routes with string identifiers
- ✅ Route arguments for passing data
- ✅ onGenerateRoute for dynamic routing
- ✅ Different navigation methods (push, pop, replace)
- ✅ Error handling for invalid routes
- ✅ Deep linking basics

## Further Learning

- [Navigation and routing](https://docs.flutter.dev/development/ui/navigation)
- [Named routes](https://docs.flutter.dev/cookbook/navigation/named-routes)
- [Deep linking](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [go_router package](https://pub.dev/packages/go_router) (advanced routing)

---

**Previous:** [Lesson 3: Theme Toggle](../01-beginner/lesson-03-theme-toggle.md)
**Next:** [Lesson 5: Data Export](lesson-05-data-export.md)
