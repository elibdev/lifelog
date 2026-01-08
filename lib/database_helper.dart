import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('journal.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        date TEXT PRIMARY KEY,
        content TEXT
      )
    ''');
  }

  Future<String?> getEntry(String date) async {
    final db = await instance.database;
    final maps = await db.query(
      'entries',
      columns: ['content'],
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isNotEmpty) {
      return maps.first['content'] as String;
    }
    return null;
  }

  Future<void> saveEntry(String date, String content) async {
    final db = await instance.database;
    await db.insert('entries', {
      'date': date,
      'content': content,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
