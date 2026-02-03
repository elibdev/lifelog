# Understanding the Data Models

**File:** [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart)

This guide walks you through how Lifelog models data using abstract classes, polymorphism, and immutable patterns.

## What You'll Learn

- Abstract classes in Dart
- Polymorphic data models
- Immutable patterns with `copyWith`
- JSON serialization
- Factory constructors

## The Record Model Hierarchy

Lifelog has two types of records: **Todos** (with checkboxes) and **Notes** (with bullet points). They share common properties but have different behavior.

### The Abstract Base Class

**File:** [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart) (lines 1-50)

```dart
abstract class Record {
  final String id;
  final DateTime date;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double orderPosition;

  const Record({...});

  // Subclasses must implement these
  RecordType get type;
  Map<String, dynamic> toJson();
  Record copyWith({...});
}
```

**Why abstract?**
- ✅ Ensures all records have common properties (id, date, content)
- ✅ Defines interface that all record types must implement
- ✅ Allows polymorphic lists: `List<Record>` can hold both TodoRecord and NoteRecord
- ✅ Enforces consistency across record types

**Key pattern: Immutable data**
- All fields are `final` - they can't be changed after creation
- To "modify" a record, you create a new one with `copyWith()`
- This prevents accidental mutations and makes state management predictable

### TodoRecord Implementation

**File:** [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart) (lines 52-100)

```dart
class TodoRecord extends Record {
  final bool completed;  // The only TodoRecord-specific property

  const TodoRecord({
    required String id,
    required DateTime date,
    required String content,
    required this.completed,  // Additional parameter
    required DateTime createdAt,
    required DateTime updatedAt,
    required double orderPosition,
  }) : super(
    id: id,
    date: date,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt,
    orderPosition: orderPosition,
  );

  @override
  RecordType get type => RecordType.todo;

  @override
  TodoRecord copyWith({
    String? id,
    DateTime? date,
    String? content,
    bool? completed,  // Can update completion status
    DateTime? createdAt,
    DateTime? updatedAt,
    double? orderPosition,
  }) {
    return TodoRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      content: content ?? this.content,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderPosition: orderPosition ?? this.orderPosition,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': 'todo',
      'content': content,
      'metadata': {'completed': completed},  // Todo-specific data
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_position': orderPosition,
    };
  }

  factory TodoRecord.fromJson(Map<String, dynamic> json) {
    return TodoRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      content: json['content'],
      completed: json['metadata']['completed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      orderPosition: json['order_position'],
    );
  }
}
```

**Key patterns:**

1. **Extends Record** - Inherits common properties, adds `completed`
2. **copyWith pattern** - Create modified copies without mutation
3. **toJson/fromJson** - Serialization for database storage
4. **metadata field** - Type-specific data stored in JSON object

### NoteRecord Implementation

**File:** [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart) (lines 102-150)

```dart
class NoteRecord extends Record {
  // No additional properties - just the base Record properties

  const NoteRecord({
    required String id,
    required DateTime date,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    required double orderPosition,
  }) : super(
    id: id,
    date: date,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt,
    orderPosition: orderPosition,
  );

  @override
  RecordType get type => RecordType.notes;

  // ... similar copyWith and JSON methods
}
```

**Why separate classes if NoteRecord has no extra properties?**
- ✅ Type safety - compiler knows if you have a todo or note
- ✅ Polymorphic rendering - widgets can check `record is TodoRecord`
- ✅ Future extensibility - easy to add note-specific properties later
- ✅ Clear intent - code explicitly shows what type it expects

## The copyWith Pattern

**Why not just modify properties directly?**

```dart
// ❌ WRONG - Can't do this with final fields
record.content = "New content";  // Error!

// ✅ CORRECT - Create a new record with changes
final updatedRecord = record.copyWith(content: "New content");
```

**Benefits:**
- Immutability prevents bugs (no accidental changes)
- Makes state changes explicit and traceable
- Enables time-travel debugging
- Works perfectly with Flutter's rebuild system

**How it works:**

```dart
TodoRecord copyWith({
  String? content,    // Nullable parameters
  bool? completed,
  // ... other fields
}) {
  return TodoRecord(
    content: content ?? this.content,  // Use new value OR keep existing
    completed: completed ?? this.completed,
    // ... other fields
  );
}

// Usage:
final todo = TodoRecord(content: "Buy milk", completed: false, ...);
final done = todo.copyWith(completed: true);  // New record with completed=true
// original 'todo' is unchanged!
```

## Polymorphic Factory Constructor

**File:** [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart) (lines 30-48)

```dart
factory Record.fromJson(Map<String, dynamic> json) {
  final type = json['type'];

  switch (type) {
    case 'todo':
      return TodoRecord.fromJson(json);
    case 'notes':
      return NoteRecord.fromJson(json);
    default:
      throw Exception('Unknown record type: $type');
  }
}
```

**Why a factory constructor?**

This enables polymorphic deserialization:

```dart
// Loading from database - we don't know the type yet
final json = {'type': 'todo', 'content': '...', ...};

// Factory figures out the right subclass to create
final record = Record.fromJson(json);  // Returns TodoRecord!

// Now we can use it polymorphically
if (record is TodoRecord) {
  print('Todo completed: ${record.completed}');
} else if (record is NoteRecord) {
  print('Note content: ${record.content}');
}
```

**How it works:**
1. Factory constructor reads the 'type' field
2. Calls the appropriate subclass constructor
3. Returns the subclass instance
4. Caller gets a `Record` that's actually a `TodoRecord` or `NoteRecord`

## JSON Serialization Strategy

Records are stored in SQLite as JSON. Here's how it works:

**TodoRecord → JSON:**
```dart
{
  'id': 'abc-123',
  'date': '2024-01-15T00:00:00.000',
  'type': 'todo',
  'content': 'Buy groceries',
  'metadata': {
    'completed': true  // Type-specific data in metadata object
  },
  'created_at': '2024-01-15T10:30:00.000',
  'updated_at': '2024-01-15T11:45:00.000',
  'order_position': 1.0
}
```

**Why metadata object?**
- ✅ Keeps database schema consistent across types
- ✅ Flexible - can add new type-specific fields without schema changes
- ✅ Clean separation - base properties vs type-specific properties

## The RecordType Enum

**File:** [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart) (lines 5-8)

```dart
enum RecordType {
  todo,
  notes,
}
```

**Used for:**
- Filtering: `records.where((r) => r.type == RecordType.todo)`
- Sections: Each RecordSection has a specific RecordType
- Database queries: Query by type

## How These Models Are Used

### In the UI (RecordWidget)

**File:** [`lib/widgets/record_widget.dart`](/home/user/lifelog/lib/widgets/record_widget.dart) (lines 150-180)

```dart
// Polymorphic rendering based on type
Widget build(BuildContext context) {
  return Row(
    children: [
      // Different leading widget based on type
      if (widget.record is TodoRecord)
        Checkbox(
          value: (widget.record as TodoRecord).completed,
          onChanged: _handleToggle,
        )
      else if (widget.record is NoteRecord)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('•', style: TextStyle(fontSize: 20)),
        ),

      // Common content field
      Expanded(
        child: TextField(
          controller: _controller,
          // ...
        ),
      ),
    ],
  );
}
```

### In the Database (RecordRepository)

**File:** [`lib/database/record_repository.dart`](/home/user/lifelog/lib/database/record_repository.dart) (lines 50-80)

```dart
Future<List<Record>> getRecordsForDate(DateTime date) async {
  // Query returns JSON
  final rows = await _database.query(...);

  // Factory constructor handles polymorphic creation
  return rows.map((row) {
    final json = jsonDecode(row['metadata']);
    json['id'] = row['id'];
    json['date'] = row['date'];
    // ...

    return Record.fromJson(json);  // Returns TodoRecord OR NoteRecord
  }).toList();
}
```

### When Updating (JournalScreen)

**File:** [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) (lines 250-270)

```dart
void _saveRecord(Record record) {
  setState(() {
    // Update in-memory cache
    final dateRecords = _recordsByDate[record.date] ?? [];
    final index = dateRecords.indexWhere((r) => r.id == record.id);

    if (index >= 0) {
      // Use copyWith to create updated record
      dateRecords[index] = record.copyWith(
        updatedAt: DateTime.now(),
      );
    }
  });

  // Debounce disk write
  _debouncers[record.id]?.call(() async {
    await _repository.updateRecord(record);
  });
}
```

## Common Patterns You'll See

### Type Checking

```dart
// Check record type
if (record is TodoRecord) {
  // Compiler knows record is TodoRecord here
  print(record.completed);  // Can access completed property
}

// Filter by type
final todos = records.whereType<TodoRecord>().toList();
final notes = records.whereType<NoteRecord>().toList();
```

### Creating Records

```dart
// Create new todo
final todo = TodoRecord(
  id: uuid.v4(),
  date: DateTime.now(),
  content: '',
  completed: false,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  orderPosition: 1.0,
);

// Update todo
final done = todo.copyWith(
  completed: true,
  updatedAt: DateTime.now(),
);
```

### Polymorphic Lists

```dart
// Single list can hold both types
final List<Record> allRecords = [
  TodoRecord(...),
  NoteRecord(...),
  TodoRecord(...),
];

// Process polymorphically
for (var record in allRecords) {
  print(record.content);  // Works for both types

  if (record is TodoRecord) {
    print('Completed: ${record.completed}');  // Type-specific access
  }
}
```

## Key Takeaways

1. **Abstract classes** define interfaces that subclasses must implement
2. **Immutable data** with `copyWith` prevents bugs and makes state predictable
3. **Factory constructors** enable polymorphic deserialization from JSON
4. **Type checks** (`is TodoRecord`) allow type-specific behavior
5. **Metadata object** keeps database schema flexible

## Questions to Check Understanding

1. Why use abstract classes instead of just having TodoRecord and NoteRecord without a base?
2. What would happen if Record fields weren't `final`?
3. Why does `copyWith` use nullable parameters?
4. How does the factory constructor know which subclass to create?
5. What's the difference between `record.type == RecordType.todo` and `record is TodoRecord`?

## Next Steps

Now that you understand the data models, learn how they're persisted:

- **[Understanding Event Sourcing](02-event-sourcing.md)** - How changes are tracked
- **[Understanding the Database Layer](03-database-layer.md)** - How records are stored
- **[Understanding the Repository Pattern](04-repository-pattern.md)** - CRUD operations

---

**Ask me:** "Walk me through record.dart with teaching comments" to add explanations directly to the source file!
