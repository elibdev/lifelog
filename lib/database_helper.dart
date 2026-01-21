import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class JournalDatabase {
  static final JournalDatabase instance = JournalDatabase._init();
  static Database? _database;

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            date TEXT PRIMARY KEY,
            content TEXT
          )
        ''');
      },
    );
  }

  String dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

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
