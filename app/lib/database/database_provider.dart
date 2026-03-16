import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Singleton that owns the SQLite database connection.
///
/// Same pattern as the reference app: WAL mode, isolate-backed reads,
/// main-thread writes. Schema versioning via PRAGMA user_version.
/// See: https://www.sqlite.org/wal.html
class DatabaseProvider {
  static final DatabaseProvider instance = DatabaseProvider._();

  DatabaseProvider._();

  Database? _database;
  String? _dbPath;

  Future<String> _getDbPath() async {
    if (_dbPath != null) return _dbPath!;
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = p.join(dir.path, 'lifelog_v2.db');
    return _dbPath!;
  }

  // Bump this when adding a new migration in _migrateDb().
  static const int _targetVersion = 1;

  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final dbPath = await _getDbPath();
    _database = sqlite3.open(dbPath);
    _database!.execute('PRAGMA journal_mode = WAL;');

    final currentVersion =
        _database!.select('PRAGMA user_version').first.values.first as int;

    if (currentVersion == 0) {
      _createDb(_database!);
    } else if (currentVersion < _targetVersion) {
      _migrateDb(_database!, from: currentVersion);
    }

    return _database!;
  }

  /// Applies sequential migrations from [from] up to [_targetVersion].
  ///
  /// Each migration block is guarded by `if (from < N)` so migrations
  /// compose correctly regardless of how many versions are skipped.
  /// Always update PRAGMA user_version at the end.
  void _migrateDb(Database db, {required int from}) {
    db.execute('BEGIN TRANSACTION');
    try {
      // Example pattern for future migrations:
      // if (from < 2) { db.execute('ALTER TABLE ...'); }
      // if (from < 3) { db.execute('CREATE TABLE ...'); }

      db.execute('PRAGMA user_version = $_targetVersion');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _createDb(Database db) {
    db.execute('BEGIN TRANSACTION');
    try {
      db.execute('''
        CREATE TABLE databases (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          config TEXT NOT NULL DEFAULT '{}',
          order_position REAL NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      db.execute('''
        CREATE TABLE fields (
          id TEXT PRIMARY KEY,
          database_id TEXT NOT NULL REFERENCES databases(id),
          name TEXT NOT NULL,
          field_type TEXT NOT NULL,
          config TEXT NOT NULL DEFAULT '{}',
          order_position REAL NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      db.execute('CREATE INDEX idx_fields_database ON fields(database_id)');

      db.execute('''
        CREATE TABLE records (
          id TEXT PRIMARY KEY,
          database_id TEXT NOT NULL REFERENCES databases(id),
          content TEXT NOT NULL DEFAULT '',
          values_json TEXT NOT NULL DEFAULT '{}',
          order_position REAL NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      db.execute('CREATE INDEX idx_records_database ON records(database_id)');

      db.execute('''
        CREATE TABLE record_links (
          source_record_id TEXT NOT NULL REFERENCES records(id),
          target_record_id TEXT NOT NULL REFERENCES records(id),
          field_id TEXT NOT NULL REFERENCES fields(id),
          created_at INTEGER NOT NULL,
          PRIMARY KEY (source_record_id, target_record_id, field_id)
        )
      ''');
      db.execute(
          'CREATE INDEX idx_links_target ON record_links(target_record_id)');

      db.execute('''
        CREATE TABLE event_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_type TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          device_id TEXT
        )
      ''');

      db.execute('PRAGMA user_version = 1');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }

    // FTS5 virtual tables can't be created inside a transaction.
    // See: https://www.sqlite.org/fts5.html
    _addFtsIndex(db);
  }

  void _addFtsIndex(Database db) {
    db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS records_fts USING fts5(content)');
  }

  /// Insert an event log entry within an already-open transaction.
  ///
  /// Called from repository transaction callbacks so the event is atomic
  /// with the main write — either both succeed or both roll back.
  static void logEvent(
    Database db, {
    required String eventType,
    required String entityType,
    required String entityId,
    required String payload,
  }) {
    final stmt = db.prepare('''
      INSERT INTO event_log (event_type, entity_type, entity_id, payload, timestamp)
      VALUES (:event_type, :entity_type, :entity_id, :payload, :timestamp)
    ''');
    stmt.executeWith(StatementParameters.named({
      ':event_type': eventType,
      ':entity_type': entityType,
      ':entity_id': entityId,
      ':payload': payload,
      ':timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
    stmt.dispose();
  }

  /// Run a read query off the main isolate.
  /// Opens a short-lived connection inside the isolate — WAL mode allows
  /// concurrent readers. See: https://api.dart.dev/dart-isolate/Isolate/run.html
  Future<List<Map<String, Object?>>> queryAsync(
    String sql,
    Map<String, dynamic> params,
  ) async {
    await _getDatabase();
    final path = _dbPath!;

    return Isolate.run(() {
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
