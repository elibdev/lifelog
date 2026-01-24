# Lesson 10: Tags & Advanced Filtering

**Difficulty:** Advanced
**Estimated Time:** 3-4 hours
**Prerequisites:** Lessons 1-9, understanding of complex state management

## Learning Objectives

1. ✅ **Tag system architecture** - Modeling many-to-many relationships
2. ✅ **Autocomplete** - Smart tag suggestions
3. ✅ **Complex filtering** - Multiple criteria filtering
4. ✅ **Chips widgets** - Tag display and interaction
5. ✅ **Custom text parsing** - Extracting tags from text

## What You're Building

A hashtag-based tagging system:
- **Hashtag parsing** - Auto-detect #tags in content
- **Tag autocomplete** - Suggest existing tags
- **Tag filtering** - Filter journal by tags
- **Tag management** - View and manage all tags
- **Tag analytics** - Most used tags, tag cloud

This teaches advanced data modeling and UI patterns!

## Step 1: Update Database Schema

Add tags support to your database:

**File:** `/home/user/lifelog/lib/database/database_provider.dart`

```dart
Future<void> _createTables() async {
  // ...existing tables...

  // Tags table
  _db.execute('''
    CREATE TABLE IF NOT EXISTS tags (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      color TEXT,
      created_at INTEGER NOT NULL
    )
  ''');

  // Record-Tag junction table (many-to-many)
  _db.execute('''
    CREATE TABLE IF NOT EXISTS record_tags (
      record_id TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (record_id, tag_id),
      FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
    )
  ''');

  // Index for faster tag queries
  _db.execute('''
    CREATE INDEX IF NOT EXISTS idx_record_tags_tag_id
    ON record_tags(tag_id)
  ''');
}
```

## Step 2: Create Tag Model

**File:** `/home/user/lifelog/lib/models/tag.dart` (new file)

```dart
import 'package:flutter/material.dart';

class Tag {
  final String id;
  final String name;
  final Color? color;
  final DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color?.value.toRadixString(16),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  // Create from JSON
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      color: json['color'] != null
          ? Color(int.parse(json['color'], radix: 16))
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at']),
    );
  }

  // Copy with modifications
  Tag copyWith({
    String? id,
    String? name,
    Color? color,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

## Step 3: Create Tag Repository

**File:** `/home/user/lifelog/lib/database/tag_repository.dart` (new file)

```dart
import 'package:uuid/uuid.dart';
import '../models/tag.dart';
import 'database_provider.dart';

class TagRepository {
  final _db = DatabaseProvider.instance;

  // Get or create tag by name
  Future<Tag> getOrCreateTag(String name) async {
    // Normalize tag name (lowercase, remove #)
    final normalizedName = name.toLowerCase().replaceAll('#', '');

    // Try to find existing tag
    final existing = await _db.query(
      'tags',
      where: 'name = ?',
      whereArgs: [normalizedName],
    );

    if (existing.isNotEmpty) {
      return Tag.fromJson(existing.first);
    }

    // Create new tag
    final tag = Tag(
      id: const Uuid().v4(),
      name: normalizedName,
      createdAt: DateTime.now(),
    );

    await _db.insert('tags', tag.toJson());
    return tag;
  }

  // Link tag to record
  Future<void> linkTagToRecord(String tagId, String recordId) async {
    await _db.insert('record_tags', {
      'record_id': recordId,
      'tag_id': tagId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Get all tags for a record
  Future<List<Tag>> getTagsForRecord(String recordId) async {
    final result = await _db.query('''
      SELECT t.* FROM tags t
      INNER JOIN record_tags rt ON t.id = rt.tag_id
      WHERE rt.record_id = ?
    ''', [recordId]);

    return result.map((json) => Tag.fromJson(json)).toList();
  }

  // Get all records with a specific tag
  Future<List<String>> getRecordIdsWithTag(String tagId) async {
    final result = await _db.query(
      'record_tags',
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );

    return result.map((row) => row['record_id'] as String).toList();
  }

  // Get all tags
  Future<List<Tag>> getAllTags() async {
    final result = await _db.query('tags', orderBy: 'name ASC');
    return result.map((json) => Tag.fromJson(json)).toList();
  }

  // Get tag statistics
  Future<Map<String, int>> getTagUsageCount() async {
    final result = await _db.query('''
      SELECT t.name, COUNT(rt.record_id) as count
      FROM tags t
      LEFT JOIN record_tags rt ON t.id = rt.tag_id
      GROUP BY t.id, t.name
      ORDER BY count DESC
    ''');

    return Map.fromEntries(
      result.map((row) => MapEntry(
            row['name'] as String,
            row['count'] as int,
          )),
    );
  }

  // Delete tag
  Future<void> deleteTag(String tagId) async {
    await _db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }
}
```

## Step 4: Parse Hashtags from Content

**File:** `/home/user/lifelog/lib/utils/tag_parser.dart` (new file)

```dart
class TagParser {
  // Extract hashtags from text
  static List<String> extractTags(String content) {
    // Regex to find hashtags: #word or #word-with-dashes
    final regex = RegExp(r'#([a-zA-Z0-9_-]+)');
    final matches = regex.allMatches(content);

    return matches
        .map((match) => match.group(1)!)
        .toSet() // Remove duplicates
        .toList();
  }

  // Replace hashtags with styled text
  static List<InlineSpan> styleHashtags(String content, Color tagColor) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(#[a-zA-Z0-9_-]+)|([^#]+)');
    final matches = regex.allMatches(content);

    for (var match in matches) {
      final text = match.group(0)!;

      if (text.startsWith('#')) {
        // Hashtag - style it
        spans.add(TextSpan(
          text: text,
          style: TextStyle(
            color: tagColor,
            fontWeight: FontWeight.bold,
          ),
        ));
      } else {
        // Regular text
        spans.add(TextSpan(text: text));
      }
    }

    return spans;
  }

  // Suggest tags based on partial input
  static List<String> suggestTags(String partial, List<String> allTags) {
    final query = partial.toLowerCase().replaceAll('#', '');

    if (query.isEmpty) return [];

    return allTags
        .where((tag) => tag.toLowerCase().startsWith(query))
        .take(5)
        .toList();
  }
}
```

## Step 5: Add Tag Autocomplete to RecordWidget

**File:** `/home/user/lifelog/lib/widgets/record_widget.dart`

Update the TextField to show tag suggestions:

```dart
class _RecordWidgetState extends State<RecordWidget> {
  List<String> _tagSuggestions = [];
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Extract tags from content
    final tags = TagParser.extractTags(_controller.text);

    // Get current word being typed
    final cursorPos = _controller.selection.baseOffset;
    final text = _controller.text;

    if (cursorPos > 0 && cursorPos <= text.length) {
      final beforeCursor = text.substring(0, cursorPos);
      final words = beforeCursor.split(RegExp(r'\s+'));
      final currentWord = words.isNotEmpty ? words.last : '';

      if (currentWord.startsWith('#')) {
        _showTagSuggestions(currentWord);
      } else {
        _hideTagSuggestions();
      }
    }

    // Auto-link tags when saving
    widget.onSave(widget.record.copyWith(
      content: _controller.text,
      // Store tags in metadata
      metadata: {
        ...widget.record.metadata,
        'tags': tags,
      },
    ));
  }

  void _showTagSuggestions(String partial) async {
    final allTags = await TagRepository().getAllTags();
    final suggestions = TagParser.suggestTags(
      partial,
      allTags.map((t) => t.name).toList(),
    );

    setState(() {
      _tagSuggestions = suggestions;
    });

    // Show overlay with suggestions
    _showSuggestionsOverlay();
  }

  void _showSuggestionsOverlay() {
    // Implementation similar to autocomplete
    // Show positioned overlay with suggestion chips
  }

  void _hideTagSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _tagSuggestions = [];
    });
  }
}
```

## Step 6: Create Tags Screen

**File:** `/home/user/lifelog/lib/widgets/tags_screen.dart` (new file)

```dart
class TagsScreen extends StatefulWidget {
  const TagsScreen({Key? key}) : super(key: key);

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  Map<String, int> _tagCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final counts = await TagRepository().getTagUsageCount();
    setState(() {
      _tagCounts = counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _tagCounts.length,
              itemBuilder: (context, index) {
                final entry = _tagCounts.entries.elementAt(index);
                return ListTile(
                  leading: Chip(
                    label: Text('#${entry.key}'),
                  ),
                  title: Text('${entry.value} entries'),
                  onTap: () {
                    // Navigate to filtered view
                    _showRecordsWithTag(entry.key);
                  },
                );
              },
            ),
    );
  }

  void _showRecordsWithTag(String tagName) {
    // Navigate to journal with tag filter
    Navigator.pushNamed(
      context,
      AppRoutes.home,
      arguments: {'filterTag': tagName},
    );
  }
}
```

## Key Concepts

### 1. Many-to-Many Relationships

```dart
// Junction table pattern
// One record can have many tags
// One tag can be on many records

records  ←→  record_tags  ←→  tags
  (1)          (many)         (1)

// Query all tags for a record
SELECT t.* FROM tags t
INNER JOIN record_tags rt ON t.id = rt.tag_id
WHERE rt.record_id = ?

// Query all records with a tag
SELECT r.* FROM records r
INNER JOIN record_tags rt ON r.id = rt.record_id
WHERE rt.tag_id = ?
```

### 2. Text Parsing with Regex

```dart
// Match hashtags
final regex = RegExp(r'#([a-zA-Z0-9_-]+)');

// Find all matches
final matches = regex.allMatches('Hello #world and #flutter');
// Result: ['world', 'flutter']

// Replace matches
final styled = content.replaceAllMapped(
  regex,
  (match) => '<strong>${match.group(0)}</strong>',
);
```

### 3. Autocomplete Pattern

```dart
// 1. Track cursor position
// 2. Get word before cursor
// 3. Show suggestions
// 4. Handle selection

// Show overlay at cursor position
final renderBox = context.findRenderObject() as RenderBox;
final position = renderBox.localToGlobal(Offset.zero);

OverlayEntry(
  builder: (context) => Positioned(
    left: position.dx,
    top: position.dy + renderBox.size.height,
    child: SuggestionsList(),
  ),
)
```

## Testing Checklist

- [ ] Hashtags detected in content
- [ ] Tags saved to database
- [ ] Tag autocomplete shows suggestions
- [ ] Selecting suggestion inserts tag
- [ ] Tags screen shows all tags with counts
- [ ] Tapping tag filters journal
- [ ] Tag colors display correctly

## Challenges

**Challenge 1:** Add tag renaming and merging
**Challenge 2:** Create tag cloud visualization
**Challenge 3:** Add tag relationships (related tags)
**Challenge 4:** Export tags to separate file

## What You've Learned

- ✅ Many-to-many database relationships
- ✅ Text parsing with regex
- ✅ Autocomplete patterns
- ✅ Complex filtering logic
- ✅ Chips and tag UI patterns

---

**Previous:** [Lesson 9: Undo/Redo System](lesson-09-undo-redo.md)
**Next:** [Lesson 11: Performance Optimization](lesson-11-performance.md)
