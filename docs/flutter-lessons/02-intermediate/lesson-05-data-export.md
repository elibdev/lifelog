# Lesson 5: Data Export (JSON & Markdown)

**Difficulty:** Intermediate
**Estimated Time:** 2-3 hours
**Prerequisites:** Lessons 1-4 (async/await, file I/O concepts)

## Learning Objectives

1. ✅ **File I/O** - Reading and writing files in Flutter
2. ✅ **JSON encoding** - Converting objects to JSON
3. ✅ **String formatting** - Generating markdown text
4. ✅ **Share functionality** - Using platform share dialogs
5. ✅ **Error handling** - Try/catch and user feedback
6. ✅ **Path provider** - Getting platform-specific directories

## What You're Building

Export functionality that lets users:
- **Export to JSON** - Machine-readable format for backups
- **Export to Markdown** - Human-readable format for reading
- **Share exports** - Send via email, messaging, cloud storage
- **Progress indication** - Show export progress
- **Error handling** - Handle failures gracefully

## Why This Matters

Data portability is crucial. This teaches you:
- Working with files in Flutter
- JSON serialization
- Platform integration (sharing)
- Async error handling
- User experience during long operations

## Step 1: Add Dependencies

**File:** `/home/user/lifelog/pubspec.yaml`

```yaml
dependencies:
  path_provider: ^2.0.15  # Already have this
  share_plus: ^7.2.1      # ADD: For sharing files
  intl: ^0.18.1          # Already have this
```

Run: `flutter pub get`

## Step 2: Create Export Service

**File:** `/home/user/lifelog/lib/services/export_service.dart` (new file)

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../database/record_repository.dart';

class ExportService {
  final RecordRepository _repository = RecordRepository();

  // Export all records to JSON
  Future<File> exportToJson() async {
    // 1. Get all records from database
    final records = await _repository.getAllRecords();

    // 2. Convert records to JSON-serializable format
    final jsonData = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'record_count': records.length,
      'records': records.map((r) => r.toJson()).toList(),
    };

    // 3. Encode to JSON string with pretty printing
    final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);

    // 4. Get temporary directory to save file
    final directory = await getTemporaryDirectory();
    final fileName = 'lifelog_export_${_getTimestamp()}.json';
    final file = File('${directory.path}/$fileName');

    // 5. Write to file
    await file.writeAsString(jsonString);

    return file;
  }

  // Export to Markdown format
  Future<File> exportToMarkdown() async {
    final records = await _repository.getAllRecords();

    // Group records by date
    final recordsByDate = <DateTime, List<Record>>{};
    for (var record in records) {
      final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
      recordsByDate.putIfAbsent(dateKey, () => []).add(record);
    }

    // Sort dates descending
    final sortedDates = recordsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Build markdown string
    final buffer = StringBuffer();
    buffer.writeln('# Lifelog Export');
    buffer.writeln();
    buffer.writeln('Exported: ${DateFormat.yMMMMd().add_jm().format(DateTime.now())}');
    buffer.writeln('Total Records: ${records.length}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (var date in sortedDates) {
      final dateRecords = recordsByDate[date]!;

      // Date header
      buffer.writeln('## ${DateFormat.yMMMMd().format(date)}');
      buffer.writeln();

      // Todos section
      final todos = dateRecords.whereType<TodoRecord>().toList();
      if (todos.isNotEmpty) {
        buffer.writeln('### Todos');
        buffer.writeln();
        for (var todo in todos) {
          final checkbox = todo.completed ? '[x]' : '[ ]';
          buffer.writeln('- $checkbox ${todo.content}');
        }
        buffer.writeln();
      }

      // Notes section
      final notes = dateRecords.whereType<NoteRecord>().toList();
      if (notes.isNotEmpty) {
        buffer.writeln('### Notes');
        buffer.writeln();
        for (var note in notes) {
          buffer.writeln('- ${note.content}');
        }
        buffer.writeln();
      }

      buffer.writeln('---');
      buffer.writeln();
    }

    // Save to file
    final directory = await getTemporaryDirectory();
    final fileName = 'lifelog_export_${_getTimestamp()}.md';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file;
  }

  // Helper to generate timestamp for filenames
  String _getTimestamp() {
    return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  }
}
```

## Step 3: Create Export Screen

**File:** `/home/user/lifelog/lib/widgets/export_screen.dart` (new file)

```dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({Key? key}) : super(key: key);

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _exportService = ExportService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Export Your Journal',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a format to export your journal data.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // JSON Export Card
            _buildExportCard(
              title: 'Export as JSON',
              description: 'Machine-readable format. Perfect for backups and data portability.',
              icon: Icons.code,
              color: Colors.blue,
              onTap: _isExporting ? null : () => _handleExport('json'),
            ),

            const SizedBox(height: 16),

            // Markdown Export Card
            _buildExportCard(
              title: 'Export as Markdown',
              description: 'Human-readable format. Great for reading and sharing.',
              icon: Icons.article,
              color: Colors.green,
              onTap: _isExporting ? null : () => _handleExport('markdown'),
            ),

            const SizedBox(height: 32),

            // Progress indicator
            if (_isExporting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Exporting...'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport(String format) async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Export based on format
      final file = format == 'json'
          ? await _exportService.exportToJson()
          : await _exportService.exportToMarkdown();

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Lifelog Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}
```

## Step 4: Add Export to Routes

**File:** `/home/user/lifelog/lib/utils/routes.dart`

```dart
class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';
  static const String statistics = '/statistics';
  static const String about = '/about';
  static const String export = '/export'; // ADD THIS

  AppRoutes._();
}
```

**File:** `/home/user/lifelog/lib/utils/route_generator.dart`

```dart
import '../widgets/export_screen.dart'; // Add import

// In generateRoute switch:
case AppRoutes.export:
  return MaterialPageRoute(
    builder: (_) => const ExportScreen(),
  );
```

## Step 5: Add Export Button to Settings

**File:** `/home/user/lifelog/lib/widgets/settings_screen.dart`

```dart
// In the ListView, add a new section:
const Padding(
  padding: EdgeInsets.all(16.0),
  child: Text(
    'Data',
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
    ),
  ),
),

ListTile(
  leading: const Icon(Icons.upload),
  title: const Text('Export Data'),
  subtitle: const Text('Export your journal to JSON or Markdown'),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.pushNamed(context, AppRoutes.export);
  },
),
```

## Key Concepts

### 1. File I/O in Flutter

```dart
// Get directories
final tempDir = await getTemporaryDirectory();      // Temporary files
final appDocDir = await getApplicationDocumentsDirectory(); // App documents
final downloadDir = await getDownloadsDirectory();  // Downloads (Android)

// Write file
final file = File('${tempDir.path}/myfile.txt');
await file.writeAsString('content');

// Read file
final content = await file.readAsString();

// Check if exists
if (await file.exists()) { ... }

// Delete file
await file.delete();
```

### 2. JSON Encoding

```dart
// Object to JSON
final json = record.toJson(); // Returns Map<String, dynamic>

// List to JSON
final jsonList = records.map((r) => r.toJson()).toList();

// Encode to string
final jsonString = jsonEncode(jsonList);

// Pretty print
final prettyJson = JsonEncoder.withIndent('  ').convert(jsonList);

// Decode from string
final decoded = jsonDecode(jsonString);
```

### 3. StringBuffer for Efficient String Building

```dart
// ❌ BAD - Creates new string each time (slow for large strings)
String markdown = '';
markdown += '# Title\n';
markdown += 'Content\n';

// ✅ GOOD - Efficient string building
final buffer = StringBuffer();
buffer.writeln('# Title');
buffer.writeln('Content');
final markdown = buffer.toString();
```

### 4. Error Handling with Try/Catch

```dart
try {
  // Risky operation
  final file = await _exportService.exportToJson();
  await Share.shareXFiles([XFile(file.path)]);

} on FileSystemException catch (e) {
  // Handle file errors specifically
  print('File error: $e');

} catch (e) {
  // Handle any other errors
  print('Unknown error: $e');

} finally {
  // Always runs (cleanup)
  setState(() { _isExporting = false; });
}
```

### 5. Share Plus Plugin

```dart
// Share text
await Share.share('Check out my app!');

// Share file
await Share.shareXFiles([XFile('/path/to/file.pdf')]);

// Share with subject (email)
await Share.share(
  'Message',
  subject: 'Email subject',
);
```

## Testing Checklist

- [ ] Export screen opens from settings
- [ ] JSON export creates valid JSON file
- [ ] Markdown export creates readable markdown
- [ ] Share dialog appears after export
- [ ] Progress indicator shows during export
- [ ] Success message appears after export
- [ ] Error handling works (try with no records)
- [ ] File names include timestamp

## Common Mistakes

### Mistake 1: Not awaiting async operations

```dart
// ❌ WRONG
final file = _exportService.exportToJson(); // Missing await!
Share.shareXFiles([XFile(file.path)]); // Error!

// ✅ CORRECT
final file = await _exportService.exportToJson();
await Share.shareXFiles([XFile(file.path)]);
```

### Mistake 2: Using setState after dispose

```dart
// ❌ WRONG
try {
  // ...
} finally {
  setState(() { ... }); // Might be called after widget disposed!
}

// ✅ CORRECT
try {
  // ...
} finally {
  if (mounted) { // Check if still mounted
    setState(() { ... });
  }
}
```

## Challenges

**Challenge 1:** Add import functionality (import JSON)
**Challenge 2:** Add date range filter for exports
**Challenge 3:** Add CSV export format
**Challenge 4:** Add automatic cloud backup

## What You've Learned

- ✅ File I/O with path_provider
- ✅ JSON encoding and decoding
- ✅ String building with StringBuffer
- ✅ Platform sharing with share_plus
- ✅ Async error handling
- ✅ User feedback during long operations

---

**Previous:** [Lesson 4: Navigation & Routes](lesson-04-navigation-routes.md)
**Next:** [Lesson 6: Date Picker Widget](lesson-06-date-picker.md)
