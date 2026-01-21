import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'models/journal_record.dart';
import 'models/journal_event.dart';

class JournalDatabase {
  static final JournalDatabase instance = JournalDatabase._init();
  static Database? _database;
  static const _uuid = Uuid();

  JournalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('infinite_journal.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Schema version tracking
    await db.execute('''
      CREATE TABLE schema_version (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      )
    ''');

    // Records table (current state)
    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        record_type TEXT NOT NULL,
        metadata TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_records_date ON records(date)');
    await db.execute('CREATE INDEX idx_records_date_created ON records(date, created_at)');
    await db.execute('CREATE INDEX idx_records_type ON records(record_type)');

    // Events table (immutable log)
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        record_id TEXT,
        date TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        payload TEXT NOT NULL,
        client_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_events_record ON events(record_id)');
    await db.execute('CREATE INDEX idx_events_date ON events(date)');
    await db.execute('CREATE INDEX idx_events_timestamp ON events(timestamp)');
    await db.execute('CREATE INDEX idx_events_type ON events(event_type)');

    // Snapshots table (optional performance cache)
    await db.execute('''
      CREATE TABLE snapshots (
        date TEXT PRIMARY KEY,
        records_json TEXT NOT NULL,
        last_event_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_snapshots_created ON snapshots(created_at)');

    // Insert schema version
    await db.insert('schema_version', {
      'version': 3,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from v1 to v2
      // Drop old table and recreate
      await db.execute('DROP TABLE IF EXISTS entries');
      await db.execute('DROP TABLE IF EXISTS records');
      await db.execute('DROP TABLE IF EXISTS events');
      await db.execute('DROP TABLE IF EXISTS snapshots');
      await db.execute('DROP TABLE IF EXISTS schema_version');
      await _createDB(db, newVersion);
    }

    if (oldVersion < 3) {
      // Migrate from v2 to v3: Remove position column
      // Create new table without position
      await db.execute('''
        CREATE TABLE records_new (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          record_type TEXT NOT NULL,
          metadata TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Copy data (excluding position column)
      await db.execute('''
        INSERT INTO records_new (id, date, record_type, metadata, created_at, updated_at)
        SELECT id, date, record_type, metadata, created_at, updated_at
        FROM records
      ''');

      // Drop old table and rename new one
      await db.execute('DROP TABLE records');
      await db.execute('ALTER TABLE records_new RENAME TO records');

      // Recreate indexes without position
      await db.execute('CREATE INDEX idx_records_date ON records(date)');
      await db.execute('CREATE INDEX idx_records_date_created ON records(date, created_at)');
      await db.execute('CREATE INDEX idx_records_type ON records(record_type)');

      // Update schema version
      await db.update('schema_version', {
        'version': 3,
        'applied_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  String dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Record CRUD operations
  Future<void> createRecord(JournalRecord record, JournalEvent event) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('records', record.toDb());
      await txn.insert('events', event.toDb());
    });
  }

  Future<void> updateRecord(JournalRecord record, JournalEvent event) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'records',
        record.toDb(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      await txn.insert('events', event.toDb());
    });
  }

  Future<void> deleteRecord(String recordId, JournalEvent event) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'records',
        where: 'id = ?',
        whereArgs: [recordId],
      );
      await txn.insert('events', event.toDb());
    });
  }

  Future<List<JournalRecord>> getRecordsForDate(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'records',
      where: 'date = ?',
      whereArgs: [dateKey(date)],
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => JournalRecord.fromDb(map)).toList();
  }

  /// Batch query for multiple dates - more efficient than individual queries
  Future<Map<String, List<JournalRecord>>> getRecordsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [dateKey(startDate), dateKey(endDate)],
      orderBy: 'date ASC, created_at ASC',
    );

    // Group by date
    final Map<String, List<JournalRecord>> grouped = {};
    for (final map in maps) {
      final date = map['date'] as String;
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(JournalRecord.fromDb(map));
    }
    return grouped;
  }

  Future<Map<String, dynamic>?> getSnapshot(DateTime date) async {
    final db = await database;
    final maps = await db.query(
      'snapshots',
      where: 'date = ?',
      whereArgs: [dateKey(date)],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return {
      'records': (json.decode(map['records_json'] as String) as List)
          .map((r) => JournalRecord.fromDb(r as Map<String, dynamic>))
          .toList(),
      'last_event_id': map['last_event_id'],
    };
  }

  Future<void> createSnapshot(DateTime date, List<JournalRecord> records, String lastEventId) async {
    final db = await database;
    final recordsJson = json.encode(records.map((r) => r.toDb()).toList());

    await db.insert(
      'snapshots',
      {
        'date': dateKey(date),
        'records_json': recordsJson,
        'last_event_id': lastEventId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Legacy methods (kept for backward compatibility during transition)
  Future<void> upsertEntry(DateTime date, String content) async {
    final db = await instance.database;
    await db.insert('entries', {
      'date': dateKey(date),
      'content': content,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getEntry(DateTime date) async {
    final db = await instance.database;
    final maps = await db.query(
      'entries',
      columns: ['content'],
      where: 'date = ?',
      whereArgs: [dateKey(date)],
    );

    if (maps.isNotEmpty) {
      return maps.first['content'] as String;
    }
    return null;
  }
}

