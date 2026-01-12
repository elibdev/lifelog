import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'sync/event.dart';
import 'sync/gset.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static bool _isMigrated = false;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('journal.db');
    
    // Run migration if needed
    if (!_isMigrated) {
      await _migrateToSyncProtocol();
      _isMigrated = true;
    }
    
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    if (version == 1) {
      await db.execute('''
        CREATE TABLE entries (
          date TEXT PRIMARY KEY,
          content TEXT
        )
      ''');
    } else if (version >= 2) {
      // Create both tables for new installations
      await db.execute('''
        CREATE TABLE entries (
          date TEXT PRIMARY KEY,
          content TEXT,
          last_event_hash TEXT,
          last_updated INTEGER
        )
      ''');
      
      await db.execute('''
        CREATE TABLE events (
          event_hash TEXT PRIMARY KEY,
          event_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          note_id TEXT NOT NULL,
          content TEXT,
          timestamp INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      
      // Create indexes
      await db.execute('CREATE INDEX idx_events_note_id ON events(note_id)');
      await db.execute('CREATE INDEX idx_events_timestamp ON events(timestamp)');
      await db.execute('CREATE INDEX idx_events_type ON events(event_type)');
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync columns to entries table
      await db.execute('ALTER TABLE entries ADD COLUMN last_event_hash TEXT');
      await db.execute('ALTER TABLE entries ADD COLUMN last_updated INTEGER');
      
      // Create events table
      await db.execute('''
        CREATE TABLE events (
          event_hash TEXT PRIMARY KEY,
          event_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          note_id TEXT NOT NULL,
          content TEXT,
          timestamp INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      
      // Create indexes
      await db.execute('CREATE INDEX idx_events_note_id ON events(note_id)');
      await db.execute('CREATE INDEX idx_events_timestamp ON events(timestamp)');
      await db.execute('CREATE INDEX idx_events_type ON events(event_type)');
    }
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

  // Sync protocol methods
  
  Future<void> _migrateToSyncProtocol() async {
    final db = await database;
    
    // Check if migration is needed
    final result = await db.rawQuery("PRAGMA table_info(entries)");
    final hasLastEventHash = result.any((column) => column['name'] == 'last_event_hash');
    
    if (!hasLastEventHash) {
      print('🔄 Migrating database to sync protocol...');
      
      // Get all existing entries
      final existingEntries = await db.query('entries');
      
      // For each existing entry, create a corresponding CREATE event
      for (final entry in existingEntries) {
        final date = entry['date'] as String;
        final content = entry['content'] as String;
        
        // Generate note ID from date (will need user seed)
        final noteId = await _generateNoteIdFromDate(date);
        
        // Create event
        final event = Event.create(
          noteId: noteId,
          content: content,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        // Insert event
        await _insertEvent(event);
        
        // Update entries table with sync info
        await db.update(
          'entries',
          {
            'last_event_hash': event.hash,
            'last_updated': event.timestamp,
          },
          where: 'date = ?',
          whereArgs: [date],
        );
      }
      
      print('✅ Migration completed: ${existingEntries.length} entries migrated');
    }
  }

  Future<String> _generateNoteIdFromDate(String date) async {
    // For now, use a simple hash. In real implementation, this should use
    // the user's cryptographic identity seed
    final bytes = utf8.encode('lifelog-$date');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  Future<void> _insertEvent(Event event) async {
    final db = await database;
    await db.insert('events', {
      'event_hash': event.hash,
      'event_id': event.id,
      'event_type': event.type.name,
      'note_id': event.noteId,
      'content': event.content,
      'timestamp': event.timestamp,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> saveEntryWithEvent(String date, String content) async {
    final db = await database;
    
    // Generate note ID
    final noteId = await _generateNoteIdFromDate(date);
    
    // Check if this is an update or create
    final existingEntry = await db.query(
      'entries',
      where: 'date = ?',
      whereArgs: [date],
    );
    
    Event event;
    if (existingEntry.isEmpty) {
      // Create new entry
      event = Event.create(
        noteId: noteId,
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      // Update existing entry
      event = Event.update(
        noteId: noteId,
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    
    // Save event
    await _insertEvent(event);
    
    // Update entries table
    await db.insert('entries', {
      'date': date,
      'content': content,
      'last_event_hash': event.hash,
      'last_updated': event.timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Event>> getEventsSince(int? timestamp) async {
    final db = await database;
    
    String where = '';
    List<dynamic> whereArgs = [];
    
    if (timestamp != null) {
      where = 'timestamp >= ?';
      whereArgs = [timestamp];
    }
    
    final result = await db.query(
      'events',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp ASC',
    );
    
    return result.map((row) => Event.fromJson({
      'id': row['event_id'],
      'type': row['event_type'],
      'noteId': row['note_id'],
      'content': row['content'],
      'timestamp': row['timestamp'],
      'hash': row['event_hash'],
    })).toList();
  }

  Future<List<Event>> getEventsForHashes(Set<String> hashes) async {
    if (hashes.isEmpty) return [];
    
    final db = await database;
    final placeholders = List.filled(hashes.length, '?').join(',');
    
    final result = await db.query(
      'events',
      where: 'event_hash IN ($placeholders)',
      whereArgs: hashes.toList(),
      orderBy: 'timestamp ASC',
    );
    
    return result.map((row) => Event.fromJson({
      'id': row['event_id'],
      'type': row['event_type'],
      'noteId': row['note_id'],
      'content': row['content'],
      'timestamp': row['timestamp'],
      'hash': row['event_hash'],
    })).toList();
  }

  Future<int> mergeEvents(List<Event> events) async {
    final db = await database;
    int addedCount = 0;
    
    await db.transaction((txn) async {
      for (final event in events) {
        // Check if event already exists
        final existing = await txn.query(
          'events',
          where: 'event_hash = ?',
          whereArgs: [event.hash],
        );
        
        if (existing.isEmpty) {
          // Insert new event
          await txn.insert('events', {
            'event_hash': event.hash,
            'event_id': event.id,
            'event_type': event.type.name,
            'note_id': event.noteId,
            'content': event.content,
            'timestamp': event.timestamp,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
          
          addedCount++;
          
          // Update entries table if this is the latest event for this note
          await _updateEntryFromEvent(db, event);
        }
      }
    });
    
    return addedCount;
  }

  Future<void> _updateEntryFromEvent(Database txn, Event event) async {
    // Get the latest event for this note
    final latestEvent = await txn.rawQuery('''
      SELECT * FROM events 
      WHERE note_id = ? 
      ORDER BY timestamp DESC, created_at DESC 
      LIMIT 1
    ''', [event.noteId]);
    
    if (latestEvent.isNotEmpty) {
      final latestEventData = latestEvent.first;
      final latestEventHash = latestEventData['event_hash'] as String;
      
      // Only update if this event is the latest
      if (latestEventHash == event.hash) {
        if (event.type == EventType.DELETE) {
          // Remove the entry
          await txn.delete('entries', where: 'date = ?', whereArgs: [event.noteId]);
        } else {
          // Update the entry
          await txn.insert('entries', {
            'date': event.noteId, // For now, use noteId as date
            'content': event.content,
            'last_event_hash': event.hash,
            'last_updated': event.timestamp,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
  }

  Future<Set<String>> getAllEventHashes() async {
    final db = await database;
    final result = await db.query('events', columns: ['event_hash']);
    return result.map((row) => row['event_hash'] as String).toSet();
  }

  Future<GSet> loadGSet() async {
    final gset = GSet();
    final events = await getEventsSince(null);
    
    for (final event in events) {
      gset.add(event);
    }
    
    return gset;
  }
}
