import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseProvider {
  static final DatabaseProvider instance = DatabaseProvider._internal();
  static Database? _database;

  DatabaseProvider._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lifelog.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // Records table - current state, mutable
    await db.execute('''
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
    await db.execute('''
      CREATE INDEX idx_records_date ON records(date)
    ''');

    // Event log - append-only history
    await db.execute('''
      CREATE TABLE event_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        device_id TEXT
      )
    ''');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add order_position column
      await db.execute('''
        ALTER TABLE records ADD COLUMN order_position REAL NOT NULL DEFAULT 0
      ''');

      // Backfill order_position with created_at values (normalized to floating point)
      // This maintains current ordering while allowing future fractional inserts
      await db.execute('''
        UPDATE records SET order_position = created_at
      ''');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
