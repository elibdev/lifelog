# Step 3: SQLite Database

**Goal:** Set up SQLite with isolates, schema versioning, and a repository layer.

**Your files:** `lib/database/database_provider.dart`, `lib/database/record_repository.dart`, `lib/models/event.dart`
**Reference:** `reference/lib/database/record_repository.dart`, `reference/lib/database/migration_v3.dart`

## Why sqlite3 FFI (not sqflite)?

| | sqflite | sqlite3 (FFI) |
|---|---|---|
| Architecture | Platform channel (async hop to native) | Direct C binding via FFI |
| Performance | Good | Better (no message passing overhead) |
| Desktop support | Limited | Full (macOS, Linux, Windows) |
| API | Callback-based | Synchronous (you manage async via isolates) |

Dependency in `pubspec.yaml`: `sqlite3: ^2.1.0` + `sqlite3_flutter_libs: ^0.5.0`

> See: https://pub.dev/packages/sqlite3

## Core Architecture

```
UI Thread (main isolate)
    │
    ├── Read queries → run directly (fast, non-blocking with WAL)
    │
    └── Write operations → enqueue to write queue
                              │
                              ↓
                     Background Isolate
                     (processes writes sequentially)
```

### WAL Mode (Write-Ahead Logging)

```sql
PRAGMA journal_mode = WAL;
```

WAL lets readers and writers operate concurrently. Without it, a write locks the entire database and blocks all reads. With WAL, reads see a consistent snapshot while writes happen separately.

### Schema Versioning

```sql
PRAGMA user_version;          -- Read current version
PRAGMA user_version = 3;      -- Set version after migration
```

`user_version` is a SQLite built-in integer you can use however you want. The pattern:

```dart
final version = db.select('PRAGMA user_version').first.values.first as int;

if (version < 1) { _migrateV1(db); }
if (version < 2) { _migrateV2(db); }
if (version < 3) { _migrateV3(db); }
```

Each migration runs once, in order. Idempotent by design.

### The Records Table (v3)

```sql
CREATE TABLE IF NOT EXISTS records (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  type TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  metadata TEXT NOT NULL DEFAULT '{}',   -- JSON blob
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  order_position REAL NOT NULL DEFAULT 0.0
);

CREATE INDEX IF NOT EXISTS idx_records_date ON records(date);
CREATE INDEX IF NOT EXISTS idx_records_type ON records(type);
```

Metadata is stored as a JSON string. SQLite's `json_extract()` can query into it:

```sql
SELECT * FROM records WHERE json_extract(metadata, '$.todo.checked') = 1;
```

### Event Log (Event Sourcing)

```sql
CREATE TABLE IF NOT EXISTS event_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id TEXT NOT NULL,
  event_type TEXT NOT NULL,   -- 'create', 'update', 'delete'
  data TEXT NOT NULL,          -- JSON snapshot of the record
  timestamp TEXT NOT NULL
);
```

Every write to `records` also appends to `event_log`. This gives you:
- Full history of every change
- Ability to undo/redo
- Sync capability (replay events to another device)
- Debugging (see exactly what changed and when)

## Isolates

Dart isolates are like threads but with **no shared memory**. They communicate via message passing.

```dart
// Spawn a background isolate for database writes
final receivePort = ReceivePort();
await Isolate.spawn(_backgroundWorker, receivePort.sendPort);

// Send work to it
sendPort.send({'action': 'save', 'record': record.toJson()});
```

The key insight: the database `Database` object lives in the background isolate. The main isolate sends serialized commands (Maps/JSON), the background isolate executes them and sends results back.

> See: https://dart.dev/language/concurrency
> See: https://api.flutter.dev/flutter/dart-isolate/Isolate-class.html

### Write Queue Pattern

```dart
// Simplified concept:
class WriteQueue {
  final _queue = <Future<void> Function()>[];
  bool _processing = false;

  void enqueue(Future<void> Function() work) {
    _queue.add(work);
    _processNext();
  }

  Future<void> _processNext() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    final work = _queue.removeAt(0);
    await work();

    _processing = false;
    _processNext();  // Process next item
  }
}
```

Writes are serialized — only one runs at a time. This prevents SQLite locking issues without requiring complex transaction management.

## Repository Layer

The repository wraps raw SQL in a clean Dart API:

```dart
class RecordRepository {
  Future<void> saveRecord(Record record) async { ... }
  Future<void> deleteRecord(String id) async { ... }
  Future<List<Record>> getRecordsForDate(DateTime date) async { ... }
  Future<List<Record>> search(String query, {DateTime? start, DateTime? end}) async { ... }
}
```

### Dual-Write Pattern

Every mutation writes to both tables atomically:

```dart
Future<void> saveRecord(Record record) async {
  await _database.execute(() {
    // 1. Upsert into records table
    db.execute('''
      INSERT OR REPLACE INTO records (id, date, type, content, metadata, ...)
      VALUES (?, ?, ?, ?, ?, ...)
    ''', [record.id, ...]);

    // 2. Append to event log
    db.execute('''
      INSERT INTO event_log (record_id, event_type, data, timestamp)
      VALUES (?, 'update', ?, ?)
    ''', [record.id, jsonEncode(record.toJson()), DateTime.now().toIso8601String()]);
  });
}
```

## Exercise

Build in this order:

1. **`lib/models/event.dart`** — Simple `Event` class with `id`, `recordId`, `eventType`, `data`, `timestamp`
2. **`lib/database/database_provider.dart`** — Singleton, opens DB, runs migrations, provides read/write methods
3. **`lib/database/record_repository.dart`** — CRUD methods using `DatabaseProvider`

Start with just `saveRecord` and `getRecordsForDate`. Add `search()` later in Step 9.

## Next

**[Step 4: Adaptive Record Widget →](04-adaptive-widget.md)** — Build the UI that renders any record type.
