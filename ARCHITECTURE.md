# Lifelog - High-Level Architecture

## Overview
Event-sourced infinite scrolling bullet journal with polymorphic record types.

## Core Principles

1. **Event Sourcing**: Every change is recorded in an append-only event log for future sync/versioning
2. **Polymorphic Records**: Abstract Record class enables extensible record types (notes, todos, future types)
3. **Separation of Concerns**: Data models handle serialization, widgets handle rendering, repositories handle persistence
4. **Immutable Data**: All records are immutable; updates create new instances via `copyWith()`
5. **Lazy Loading**: Days are loaded on-demand as user scrolls (bidirectional infinite scroll)

## Database Design

### Dual-Table Architecture

**records table** (current state):
- One row per note/todo
- Hard deletes when user removes content
- Indexed by date and type for fast queries

**event_log table** (append-only history):
- Preserves full history including deletions
- Enables future sync conflict resolution
- Each event references a record_id

### Schema

```sql
-- Current state
CREATE TABLE records (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,              -- ISO8601: '2026-01-21'
  type TEXT NOT NULL,              -- 'note', 'todo'
  metadata TEXT NOT NULL,          -- JSON: type-specific data
  created_at INTEGER NOT NULL,     -- Unix timestamp (ms)
  updated_at INTEGER NOT NULL      -- Unix timestamp (ms)
);

-- Append-only history
CREATE TABLE event_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type TEXT NOT NULL,        -- 'record_created', 'record_updated', 'record_deleted'
  record_id TEXT NOT NULL,
  payload TEXT NOT NULL,           -- JSON snapshot
  timestamp INTEGER NOT NULL,      -- Unix timestamp (ms)
  device_id TEXT                   -- For future sync
);
```

## Record Polymorphism

### Abstract Record Class

Every record type must provide:
- `String get content` - The text content
- `Widget get leadingWidget` - Icon/checkbox before the text field
- `String get hintText` - Placeholder text
- `int get createdAt` - Creation timestamp
- `copyWith()` - Immutable update method
- `toJson()` / `fromJson()` - Serialization

### Concrete Types

**NoteRecord**:
- leadingWidget: Bullet point (•)
- metadata: `{"content": "text"}`

**TodoRecord**:
- leadingWidget: Checkbox (toggleable)
- metadata: `{"content": "text", "checked": bool}`

### Factory Pattern

```dart
abstract class Record {
  factory Record.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'todo': return TodoRecord.fromJson(json);
      case 'note': return NoteRecord.fromJson(json);
      default: throw Exception('Unknown type');
    }
  }
}
```

## UI Architecture

### Widget Hierarchy

```
JournalScreen (infinite scroll)
└── CustomScrollView
    └── SliverList of DaySection widgets
        └── DaySection (one per date)
            ├── Date Header
            ├── RecordSection (todos)
            │   ├── RecordWidget (existing todos)
            │   └── RecordWidget (empty placeholder, higher opacity)
            └── RecordSection (notes)
                ├── RecordWidget (existing notes)
                └── RecordWidget (empty placeholder, higher opacity)
```

### RecordWidget (Generic)

Handles ALL record types without type switching:
1. Owns TextEditingController lifecycle
2. Manages debounced saves (500ms)
3. Calls `record.leadingWidget` to render type-specific UI
4. Callbacks to repository for persistence

### Empty Placeholder Pattern

Each RecordSection shows:
- All existing records of that type (opacity: 1.0)
- ONE empty placeholder at the end (opacity: 0.5)

Behavior:
- User types in placeholder → create new record + spawn new placeholder
- User deletes all content from existing record → delete from DB

## Persistence Layer

### Debouncing Strategy

- 500ms delay per record
- On debounce fire: atomic transaction writes to BOTH tables
  1. Upsert record to `records` table
  2. Append event to `event_log` table

### Repository Pattern

**DatabaseProvider**: Singleton managing DB connection and schema

**RecordRepository**: CRUD operations on records table
- `getRecordsForDate(String date)` - Load day's records
- `saveRecord(Record record)` - Debounced upsert + event log
- `deleteRecord(String id)` - Hard delete + event log

**EventRepository**: Append-only event operations
- `appendEvent(Event event)` - Write to event_log

## Infinite Scrolling

### Bidirectional Loading

Start with today centered in viewport:
- Scroll down → load past days
- Scroll up → load future days
- Trigger threshold: 200px from edge

## Key Design Decisions

### Why Abstract Record (Not Metadata)?

Records are fundamentally polymorphic - the rendering logic is type-specific. Rather than scatter type switches across widgets, each record type encapsulates its own behavior.

### Why Hard Delete?

Event log preserves history, so records table can be a clean snapshot of current state. Simplifies queries (no `WHERE deleted_at IS NULL` everywhere).

### Why Record Per Row?

More normalized than storing a day's entries in one JSON blob. Enables:
- Editing individual items without parsing/re-serializing
- Fine-grained event tracking
- Easier querying by type

### Why Debouncing?

Prevents excessive DB writes during typing. User pauses for 500ms → save happens. All changes in that window collapse to one transaction.

## Future Extensibility

### Adding New Record Types

1. Create new class extending `Record`
2. Implement required getters (`leadingWidget`, `content`, etc.)
3. Add case to `Record.fromJson()` factory
4. No changes needed to generic widgets!

### Sync Strategy (Future)

Event log provides foundation:
- Use `device_id` to detect conflicts
- Timestamp-based merge strategies
- Replay events to reconstruct state

### Advanced Features (Future)

- Tags/categories (add to metadata JSON)
- Rich text (change TextField to more advanced editor)
- Attachments (store file paths in metadata)
- Recurring todos (add recurrence rules to TodoRecord metadata)
