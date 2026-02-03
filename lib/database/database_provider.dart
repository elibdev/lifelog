import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:isolate';
import 'dart:async';
import 'dart:collection';
import 'dart:io'; // For Directory.create() to ensure Application Support directory exists

class DatabaseProvider {
  static final DatabaseProvider instance = DatabaseProvider._internal();
  static Database? _database;
  String? _dbPath;

  // Write queue ensures database writes happen one-at-a-time
  // Think of it like a single-file line at checkout - even though each operation
  // runs in its own isolate (background thread), they wait their turn
  // This prevents "database is locked" errors from concurrent writes
  final Queue<_QueuedWrite> _writeQueue = Queue<_QueuedWrite>();
  bool _processingQueue = false;

  DatabaseProvider._internal();

  // Initialize database path (async) - call from main() before runApp()
  //
  // CRITICAL iOS FIX: Use getApplicationSupportDirectory() NOT getApplicationDocumentsDirectory()
  //
  // Why this matters on iOS:
  // - Documents directory: Visible in Files app, user-accessible, can cause permission issues
  // - Application Support directory: Hidden from user, backed up to iCloud, recommended by Apple for databases
  //
  // Using Documents directory can cause:
  // - Data not saving properly due to access restrictions
  // - Users accidentally modifying/deleting database files
  // - App Store rejection (Documents should only contain user-created content)
  //
  // Android note: Both directories work the same way on Android, but Application Support
  // is still the better choice for consistency across platforms
  Future<void> initialize() async {
    final appSupportDir = await getApplicationSupportDirectory();

    // IMPORTANT: Ensure the directory exists before using it
    // On iOS, Application Support directory may not exist yet on first launch
    // recursive: true creates parent directories if needed (safe on all platforms)
    if (!await appSupportDir.exists()) {
      await appSupportDir.create(recursive: true);
    }

    _dbPath = join(appSupportDir.path, 'lifelog.db');
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

    // Enable Write-Ahead Logging for better concurrency
    // WAL mode allows readers to access data while a write is in progress
    // Think of it like multiple checkout lanes - readers use one lane,
    // writers use another, so they don't block each other
    // This is the industry standard for mobile SQLite apps
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA busy_timeout = 5000'); // Wait up to 5s for locks

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

  // === Write Queue Methods ===
  // These ensure write operations happen sequentially to prevent locking errors

  /// Enqueues a write operation to run sequentially
  /// Returns a Future that completes when the operation finishes
  /// This is the key to preventing "database is locked" errors:
  /// Even though each write runs in its own isolate, they wait in line
  Future<T> _enqueueWrite<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();
    _writeQueue.add(_QueuedWrite(operation, completer));
    // Use unawaited to start processing without blocking the enqueue
    unawaited(_processQueue());
    return completer.future;
  }

  /// Processes queued writes one at a time
  /// This ensures no concurrent writes can happen
  /// Like a single cashier processing customers one by one
  Future<void> _processQueue() async {
    if (_processingQueue || _writeQueue.isEmpty) return;

    _processingQueue = true;

    while (_writeQueue.isNotEmpty) {
      final op = _writeQueue.removeFirst();
      try {
        final result = await op.operation();
        op.completer.complete(result);
      } catch (e, stackTrace) {
        op.completer.completeError(e, stackTrace);
      }
    }

    _processingQueue = false;
  }

  // === Isolate Wrappers ===
  // These hide Isolate.run() from repositories for cleaner code

  // Query wrapper - for SELECT statements
  // Accepts named parameters (:name in SQL, 'name': value in params map)
  // Note: Include the colon prefix in param keys (e.g., {':id': '123'})
  // NOTE: Reads don't use the queue - WAL mode allows unlimited concurrent reads
  Future<List<Map<String, Object?>>> queryAsync(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final dbPath = _dbPath;
    if (dbPath == null) throw StateError('Database not initialized');

    return await Isolate.run(() {
      final db = sqlite3.open(dbPath);

      try {
        final stmt = db.prepare(sql);
        // Use native named parameter support via selectWith()
        final result = params != null && params.isNotEmpty
            ? stmt.selectWith(StatementParameters.named(params))
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
  // Accepts named parameters (:name in SQL, 'name': value in params map)
  // Note: Include the colon prefix in param keys (e.g., {':id': '123'})
  // IMPORTANT: This method queues the write to prevent concurrent write conflicts
  Future<void> executeAsync(String sql, [Map<String, dynamic>? params]) async {
    final dbPath = _dbPath;
    if (dbPath == null) throw StateError('Database not initialized');

    // Queue this write to run sequentially with other writes
    // This prevents "database is locked" errors from concurrent operations
    return _enqueueWrite(() {
      return Isolate.run(() {
        final db = sqlite3.open(dbPath);

        try {
          final stmt = db.prepare(sql);
          // Use native named parameter support via executeWith()
          params != null && params.isNotEmpty
              ? stmt.executeWith(StatementParameters.named(params))
              : stmt.execute();
          stmt.dispose();
        } finally {
          db.dispose();
        }
      });
    });
  }

  // Transaction wrapper - for atomic multi-statement operations
  // IMPORTANT: This method queues the transaction to prevent concurrent write conflicts
  Future<T> transactionAsync<T>(T Function(Database db) action) async {
    final dbPath = _dbPath;
    if (dbPath == null) throw StateError('Database not initialized');

    // Queue this transaction to run sequentially with other writes
    // Transactions are especially important to serialize because they
    // perform multiple operations that must complete atomically
    return _enqueueWrite(() {
      return Isolate.run(() {
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

// Internal helper to track queued write operations
// Each queued write has an operation (the work to do) and a completer
// (the Future that callers await on)
class _QueuedWrite<T> {
  final Future<T> Function() operation;
  final Completer<T> completer;

  _QueuedWrite(this.operation, this.completer);
}
