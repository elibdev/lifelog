import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Singleton that owns the SQLite database connection.
///
/// All reads go through [queryAsync] (runs on an isolate to avoid jank).
/// All writes go through [transactionAsync] (also isolate-backed).
///
/// Uses WAL mode for concurrent reads during writes.
/// Schema versioning via PRAGMA user_version.
class DatabaseProvider {
  static final DatabaseProvider instance = DatabaseProvider._();

  DatabaseProvider._();

  Database? _database;

  /// Opens (or returns cached) database handle.
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'lifelog.db');
    _database = sqlite3.open(dbPath);

    // WAL mode: readers don't block writers
    _database!.execute('PRAGMA journal_mode = WAL;');

    final currentVersion =
        _database!.select('PRAGMA user_version').first.values.first as int;

    if (currentVersion == 0) {
      _createDb(_database!);
    } else if (currentVersion < 4) {
      _upgradeDb(_database!, currentVersion, 4);
    }

    return _database!;
  }

  void _createDb(Database db) {
    db.execute('BEGIN TRANSACTION');
    try {
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

      _createFts(db);

      db.execute('PRAGMA user_version = 4');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _upgradeDb(Database db, int oldVersion, int newVersion) {
    db.execute('BEGIN TRANSACTION');
    try {
      if (oldVersion < 2) {
        db.execute(
            'ALTER TABLE records ADD COLUMN order_position REAL NOT NULL DEFAULT 0');
        db.execute('UPDATE records SET order_position = created_at');
      }

      if (oldVersion < 3) {
        db.execute(
            "ALTER TABLE records ADD COLUMN content TEXT NOT NULL DEFAULT ''");
        db.execute('''
          UPDATE records SET content = json_extract(metadata, '\$.content')
          WHERE json_extract(metadata, '\$.content') IS NOT NULL
        ''');
        db.execute("UPDATE records SET type = 'text' WHERE type = 'note'");
        db.execute('''
          UPDATE records
          SET metadata = json_set(
            json_remove(metadata, '\$.checked', '\$.content'),
            '\$.todo.checked', json_extract(metadata, '\$.checked')
          )
          WHERE type = 'todo' AND json_extract(metadata, '\$.checked') IS NOT NULL
        ''');
        db.execute('''
          UPDATE records
          SET metadata = json_remove(metadata, '\$.content')
          WHERE type = 'text'
        ''');
      }

      if (oldVersion < 4) {
        // FTS5 table can't be created inside a transaction, so commit first.
        // See: https://www.sqlite.org/fts5.html
        db.execute('COMMIT');
        _createFts(db);
        // Backfill FTS index from existing records
        db.execute(
            "INSERT INTO records_fts(rowid, content) SELECT rowid, content FROM records");
        db.execute('PRAGMA user_version = 4');
        return;
      }

      db.execute('PRAGMA user_version = $newVersion');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Creates the FTS5 virtual table and triggers that keep it in sync.
  ///
  /// FTS5 external content table: index lives separately from data, so we need
  /// triggers to propagate inserts/updates/deletes into the FTS index.
  /// See: https://www.sqlite.org/fts5.html#external_content_tables
  void _createFts(Database db) {
    // External content table: FTS stores only the index, not the content.
    // content='records' tells FTS5 where to read content for snippets/highlights.
    // content_rowid='rowid' maps FTS rowids to the records table rowids.
    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS records_fts USING fts5(
        content,
        content='records',
        content_rowid='rowid'
      )
    ''');

    // Trigger: after INSERT, add to FTS index
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS records_ai AFTER INSERT ON records BEGIN
        INSERT INTO records_fts(rowid, content) VALUES (new.rowid, new.content);
      END
    ''');

    // Trigger: before DELETE, remove from FTS index
    // FTS5 delete uses the special 'delete' command with the old content.
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS records_ad AFTER DELETE ON records BEGIN
        INSERT INTO records_fts(records_fts, rowid, content)
          VALUES ('delete', old.rowid, old.content);
      END
    ''');

    // Trigger: after UPDATE, remove old content then add new content
    db.execute('''
      CREATE TRIGGER IF NOT EXISTS records_au AFTER UPDATE ON records BEGIN
        INSERT INTO records_fts(records_fts, rowid, content)
          VALUES ('delete', old.rowid, old.content);
        INSERT INTO records_fts(rowid, content) VALUES (new.rowid, new.content);
      END
    ''');
  }

  /// Run a read query off the main isolate.
  Future<List<Map<String, Object?>>> queryAsync(
    String sql,
    Map<String, dynamic> params,
  ) async {
    final db = await _getDatabase();

    return Isolate.run(() {
      final stmt = db.prepare(sql);
      final result = stmt.selectWith(StatementParameters.named(params));
      final rows = result.map((row) => Map<String, Object?>.from(row)).toList();
      stmt.dispose();
      return rows;
    });
  }

  /// Run a write transaction off the main isolate.
  Future<void> transactionAsync(void Function(Database db) callback) async {
    final db = await _getDatabase();

    return Isolate.run(() {
      db.execute('BEGIN TRANSACTION');
      try {
        callback(db);
        db.execute('COMMIT');
      } catch (e) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
  }
}
