import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:isolate';

class DatabaseProvider {
  static final DatabaseProvider instance = DatabaseProvider._internal();
  static Database? _database;
  String? _dbPath;

  DatabaseProvider._internal();

  // Initialize database path (async) - call from main() before runApp()
  Future<void> initialize() async {
    final docDir = await getApplicationDocumentsDirectory();
    _dbPath = join(docDir.path, 'lifelog.db');
  }

  // Synchronous database getter (sqlite3 is synchronous)
  Database get database {
    if (_database != null) return _database!;
    if (_dbPath == null) throw StateError('Call initialize() first');
    _database = _initDatabase();
    return _database!;
  }

  // Initialize database with version management
  Database _initDatabase() {
    final db = sqlite3.open(_dbPath!);

    // Check schema version using PRAGMA
    final result = db.select('PRAGMA user_version');
    final currentVersion = result.first['user_version'] as int;

    if (currentVersion == 0) {
      _createDb(db);
    } else if (currentVersion < 2) {
      _upgradeDb(db, currentVersion, 2);
    }

    return db;
  }

  // Create initial schema with manual transaction
  void _createDb(Database db) {
    db.execute('BEGIN TRANSACTION');

    try {
      // Records table - current state, mutable
      db.execute('''
        CREATE TABLE records (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          type TEXT NOT NULL,
          metadata TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          order_position REAL NOT NULL DEFAULT 0
        )
      ''');

      // Index for fast date queries
      db.execute('CREATE INDEX idx_records_date ON records(date)');

      // Event log - append-only history
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

      // Set schema version
      db.execute('PRAGMA user_version = 2');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Upgrade schema with manual transaction
  void _upgradeDb(Database db, int oldVersion, int newVersion) {
    db.execute('BEGIN TRANSACTION');

    try {
      if (oldVersion < 2) {
        // Add order_position column
        db.execute('''
          ALTER TABLE records ADD COLUMN order_position REAL NOT NULL DEFAULT 0
        ''');

        // Backfill order_position with created_at values
        db.execute('UPDATE records SET order_position = created_at');
      }

      db.execute('PRAGMA user_version = $newVersion');
      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // === Isolate Wrappers ===
  // These hide Isolate.run() from repositories for cleaner code

  // Helper: Convert named parameters map to positional list based on SQL
  // ELI: What is this? seems like a hacky anti pattern
  static List<Object?> _convertNamedToPositional(
    String sql,
    Map<String, dynamic> params,
  ) {
    // Extract parameter names from SQL in order of appearance
    final paramPattern = RegExp(r':(\w+)');
    final matches = paramPattern.allMatches(sql);
    final paramNames = matches.map((m) => m.group(1)!).toList();

    // Build positional list matching SQL parameter order
    return paramNames.map((name) {
      if (!params.containsKey(name)) {
        throw ArgumentError('Missing parameter: $name');
      }
      return params[name];
    }).toList();
  }

  // Query wrapper - for SELECT statements
  // Accepts named parameters (:name in SQL, 'name' in params map)
  Future<List<Map<String, Object?>>> queryAsync(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final dbPath = _dbPath;
    if (dbPath == null) throw StateError('Database not initialized');

    return await Isolate.run(() {
      // Open database in this isolate
      final db = sqlite3.open(dbPath);

      try {
        // Convert SQL with :name to ? and convert params to positional list
        String positionalSql = sql;
        List<Object?>? positionalParams;

        if (params != null && params.isNotEmpty) {
          positionalParams = _convertNamedToPositional(sql, params);
          // Replace all :name with ?
          positionalSql = sql.replaceAll(RegExp(r':\w+'), '?');
        }

        final stmt = db.prepare(positionalSql);
        final result = positionalParams != null
            ? stmt.select(positionalParams)
            : stmt.select();
        final rows = result
            .map((row) => Map<String, Object?>.from(row))
            .toList();
        stmt.dispose();
        return rows;
      } finally {
        db.dispose();
      }
    });
  }

  // Execute wrapper - for INSERT/UPDATE/DELETE without results
  Future<void> executeAsync(String sql, [Map<String, dynamic>? params]) async {
    final dbPath = _dbPath;
    if (dbPath == null) throw StateError('Database not initialized');

    return await Isolate.run(() {
      final db = sqlite3.open(dbPath);

      try {
        String positionalSql = sql;
        List<Object?>? positionalParams;

        if (params != null && params.isNotEmpty) {
          positionalParams = _convertNamedToPositional(sql, params);
          positionalSql = sql.replaceAll(RegExp(r':\w+'), '?');
        }

        final stmt = db.prepare(positionalSql);
        positionalParams != null
            ? stmt.execute(positionalParams)
            : stmt.execute();
        stmt.dispose();
      } finally {
        db.dispose();
      }
    });
  }

  // Transaction wrapper - for atomic multi-statement operations
  Future<T> transactionAsync<T>(T Function(Database db) action) async {
    final dbPath = _dbPath;
    if (dbPath == null) throw StateError('Database not initialized');

    return await Isolate.run(() {
      final db = sqlite3.open(dbPath);

      try {
        db.execute('BEGIN TRANSACTION');
        try {
          final result = action(db);
          db.execute('COMMIT');
          return result;
        } catch (e) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } finally {
        db.dispose();
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      db.dispose();
      _database = null;
    }
  }
}
