// DATABASE MIGRATION REFERENCE
//
// This file shows the changes needed in database_provider.dart for schema v3.
// It is NOT a standalone file — apply these changes to the existing
// lib/database/database_provider.dart in your hand-written implementation.

// ===========================================================================
// 1. Update version check in _initDatabase()
// ===========================================================================

// CHANGE FROM:
//   if (currentVersion < 2) {
//     _upgradeDb(db, currentVersion, 2);
//   }
//
// CHANGE TO:
//   if (currentVersion < 3) {
//     _upgradeDb(db, currentVersion, 3);
//   }

// ===========================================================================
// 2. Update _createDb() for fresh installs — go straight to v3
// ===========================================================================

/*
void _createDb(Database db) {
  db.execute('BEGIN TRANSACTION');

  try {
    // Records table — uniform storage for all record types
    // `content` is a real column for searchability (LIKE queries work directly)
    // `metadata` holds type-specific JSON with namespaced keys
    db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        metadata TEXT NOT NULL DEFAULT '{}',
        order_position REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    db.execute('CREATE INDEX idx_records_date ON records(date)');

    // Event log — append-only history (unchanged)
    db.execute('''
      CREATE TABLE event_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        device_id TEXT
      )
    ''');

    db.execute('PRAGMA user_version = 3');
    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
*/

// ===========================================================================
// 3. Update _upgradeDb() — add v2→v3 migration
// ===========================================================================

/*
void _upgradeDb(Database db, int oldVersion, int newVersion) {
  db.execute('BEGIN TRANSACTION');

  try {
    if (oldVersion < 2) {
      // v1 → v2: Add order_position column
      db.execute('''
        ALTER TABLE records ADD COLUMN order_position REAL NOT NULL DEFAULT 0
      ''');
      db.execute('UPDATE records SET order_position = created_at');
    }

    if (oldVersion < 3) {
      // v2 → v3: Add content column, backfill from metadata JSON
      //
      // Why a separate content column?
      // - Enables LIKE search without json_extract()
      // - Every record type has text content — it's the universal field
      // - metadata stores only type-specific fields with namespaced keys
      db.execute('''
        ALTER TABLE records ADD COLUMN content TEXT NOT NULL DEFAULT ''
      ''');

      // Extract content from metadata JSON into the new column
      db.execute('''
        UPDATE records SET content = json_extract(metadata, '\$.content')
        WHERE json_extract(metadata, '\$.content') IS NOT NULL
      ''');

      // Rename 'note' type → 'text'
      db.execute('''
        UPDATE records SET type = 'text' WHERE type = 'note'
      ''');

      // Namespace existing metadata keys:
      // 'checked' → 'todo.checked' for todo records
      // (text records have no type-specific metadata to namespace)
      // Note: SQLite json_set/json_remove require the json1 extension
      // which is compiled in by default with sqlite3 FFI
      db.execute('''
        UPDATE records
        SET metadata = json_set(
          json_remove(metadata, '\$.checked', '\$.content'),
          '\$.todo.checked', json_extract(metadata, '\$.checked')
        )
        WHERE type = 'todo' AND json_extract(metadata, '\$.checked') IS NOT NULL
      ''');

      // Clean up text records: remove 'content' from metadata (now in its own column)
      db.execute('''
        UPDATE records
        SET metadata = json_remove(metadata, '\$.content')
        WHERE type = 'text'
      ''');
    }

    db.execute('PRAGMA user_version = $newVersion');
    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
*/
