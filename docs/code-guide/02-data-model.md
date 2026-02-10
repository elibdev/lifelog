# Step 2: Data Model

**Goal:** Create a single `Record` class that represents every type of journal entry.

**Your file:** `lib/models/record.dart`
**Reference:** `reference/lib/models/record.dart`

## Architecture: Single Class vs Subclass Hierarchy

The old approach used abstract `Record` + `TodoRecord` / `NoteRecord` subclasses. The new approach uses one concrete class with a `RecordType` enum. Why?

| | Subclass hierarchy | Single class + enum |
|---|---|---|
| Type switching | Impossible (must delete & recreate) | `record.copyWith(type: RecordType.heading)` |
| Pattern matching | `if (record is TodoRecord)` | `switch (record.type)` — exhaustive! |
| New types | New file + class + factory case | Add enum value, compiler shows every missing case |
| Metadata | Scattered across subclasses | All in one `Map<String, dynamic>` |

## What to Build

### RecordType Enum

```dart
enum RecordType {
  text,
  heading,
  todo,
  bulletList,
  habit,
}
```

Dart enums can have methods and fields. You could add a `displayName` getter:

```dart
enum RecordType {
  text,
  heading,
  todo,
  bulletList,
  habit;

  // Dart enum members — each value can have methods
  // See: https://dart.dev/language/enums#declaring-enhanced-enums
  String get displayName => switch (this) {
    RecordType.text => 'Text',
    RecordType.heading => 'Heading',
    RecordType.todo => 'Todo',
    RecordType.bulletList => 'Bullet List',
    RecordType.habit => 'Habit',
  };
}
```

The `switch` expression (not statement) is exhaustive — the compiler errors if you miss a case. This is a huge advantage over string-based type discrimination.

> See: https://dart.dev/language/enums
> See: https://dart.dev/language/branches#switch-expressions

### Record Class

Core fields every record has:

```dart
class Record {
  final String id;           // UUID
  final DateTime date;       // Which day this belongs to
  final RecordType type;     // What kind of record
  final String content;      // The text content
  final Map<String, dynamic> metadata;  // Type-specific data
  final DateTime createdAt;
  final DateTime updatedAt;
  final double orderPosition; // For sorting within a day
}
```

### Namespaced Metadata

Metadata keys are prefixed with the record type to avoid collisions:

```dart
// Todo metadata
{'todo.checked': true}

// Heading metadata
{'heading.level': 1}   // 1=H1, 2=H2, 3=H3

// Bullet list metadata
{'bulletList.indentLevel': 0}   // 0, 1, 2 for nesting

// Habit metadata
{
  'habit.name': 'Exercise',
  'habit.frequency': 'daily',
  'habit.completions': ['2024-01-15', '2024-01-16'],  // Append-only list
  'habit.archived': false,
}
```

Why namespace? If a user converts a record from `todo` to `text`, leftover `todo.checked` metadata is clearly associated with the old type and won't interfere.

### Typed Metadata Accessors

Instead of raw map access everywhere, add getters:

```dart
// Convenience getters — read metadata with type safety and defaults
bool get isChecked => metadata['todo.checked'] as bool? ?? false;
int get headingLevel => metadata['heading.level'] as int? ?? 1;
int get indentLevel => metadata['bulletList.indentLevel'] as int? ?? 0;
```

The `as bool?` is a **type cast** — it returns `null` if the value is the wrong type rather than crashing. The `??` provides a default.

> See: https://dart.dev/null-safety/understanding-null-safety

### The copyWith Pattern

Immutable data + functional updates. Every field is `final`, so to "change" a record you create a new one:

```dart
Record copyWith({
  String? id,
  DateTime? date,
  RecordType? type,
  String? content,
  Map<String, dynamic>? metadata,
  DateTime? createdAt,
  DateTime? updatedAt,
  double? orderPosition,
}) {
  return Record(
    id: id ?? this.id,
    date: date ?? this.date,
    type: type ?? this.type,
    content: content ?? this.content,
    metadata: metadata ?? this.metadata,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    orderPosition: orderPosition ?? this.orderPosition,
  );
}
```

The `??` (null coalescing) means: "use the new value if provided, otherwise keep the existing one."

> See: https://dart.dev/null-safety/understanding-null-safety#null-aware-operators

### copyWithMetadata — Partial Metadata Updates

`copyWith(metadata: {...})` replaces the entire metadata map. For partial updates:

```dart
Record copyWithMetadata(Map<String, dynamic> updates) {
  return copyWith(
    metadata: {...metadata, ...updates},
    //        ^^^^^^^^^^^^^^^^^^^^^^^^
    // Spread operator: merge existing + new entries
    // New entries overwrite existing ones with same key
  );
}
```

Usage:
```dart
final checked = record.copyWithMetadata({'todo.checked': true});
// Only changes 'todo.checked', preserves all other metadata
```

> See: https://dart.dev/language/collections#spread-operators

### JSON Serialization

```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'date': date.toIso8601String(),
  'type': type.name,   // enum .name gives the string: 'todo', 'heading', etc.
  'content': content,
  'metadata': metadata,
  'created_at': createdAt.toIso8601String(),
  'updated_at': updatedAt.toIso8601String(),
  'order_position': orderPosition,
};

factory Record.fromJson(Map<String, dynamic> json) {
  return Record(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    type: RecordType.values.byName(json['type'] as String),
    //                     ^^^^^^^
    // Dart enum method: looks up enum value by its .name string
    content: json['content'] as String? ?? '',
    metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
  );
}
```

`factory` constructors can return existing instances or different types. Here it's used for deserialization — a common Dart pattern.

> See: https://dart.dev/language/constructors#factory-constructors

## Exercise

Create `lib/models/record.dart` with:
1. `RecordType` enum with all 5 types
2. `Record` class with all fields, `const` constructor
3. `copyWith()` and `copyWithMetadata()`
4. Typed metadata getters (`isChecked`, `headingLevel`, etc.)
5. `toJson()` and `Record.fromJson()` factory

Test it mentally: can you `record.copyWith(type: RecordType.heading)` to change a text record into a heading?

## Next

**[Step 3: SQLite Database →](03-sqlite-database.md)** — Store records in SQLite with isolates.
