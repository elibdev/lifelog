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
  // Cached path so isolates can open their own connections without
  // capturing the NativeFinalizer-backed Database object.
  String? _dbPath;

  Future<String> _getDbPath() async {
    if (_dbPath != null) return _dbPath!;
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = p.join(dir.path, 'lifelog.db');
    return _dbPath!;
  }

  /// Opens (or returns cached) database handle.
  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final dbPath = await _getDbPath();
    _database = sqlite3.open(dbPath);

    // WAL mode: readers don't block writers
    _database!.execute('PRAGMA journal_mode = WAL;');

    final currentVersion =
        _database!.select('PRAGMA user_version').first.values.first as int;

    if (currentVersion == 0) {
      _createDb(_database!);
    } else if (currentVersion < 3) {
      _upgradeDb(_database!, currentVersion, 3);
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

      db.execute('PRAGMA user_version = 3');
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

      db.execute('PRAGMA user_version = $newVersion');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Run a read query off the main isolate.
  ///
  /// Dart isolates have separate heaps — you can't send a [Database] (which
  /// holds a NativeFinalizer over a C pointer) across the isolate boundary.
  /// Instead, pass the plain path String and open a short-lived connection
  /// inside the isolate. WAL mode on the main connection allows concurrent
  /// readers without blocking. See: https://api.dart.dev/dart-isolate/Isolate/run.html
  Future<List<Map<String, Object?>>> queryAsync(
    String sql,
    Map<String, dynamic> params,
  ) async {
    // Ensure schema is initialized on the main connection first.
    await _getDatabase();
    final path = _dbPath!;

    return Isolate.run(() {
      // Fresh connection per query — cheap with WAL, no NativeFinalizer issue.
      final db = sqlite3.open(path);
      try {
        final stmt = db.prepare(sql);
        final result = stmt.selectWith(StatementParameters.named(params));
        final rows =
            result.map((row) => Map<String, Object?>.from(row)).toList();
        stmt.dispose();
        return rows;
      } finally {
        db.dispose();
      }
    });
  }

  /// Run a write transaction on the main isolate.
  ///
  /// Write operations in a lifelog are fast (single-record inserts/updates),
  /// so running on the main isolate avoids both the NativeFinalizer
  /// serialization problem and the complexity of a dedicated writer isolate.
  Future<void> transactionAsync(void Function(Database db) callback) async {
    final db = await _getDatabase();

    db.execute('BEGIN TRANSACTION');
    try {
      callback(db);
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
