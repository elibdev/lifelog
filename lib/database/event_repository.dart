import 'package:sqflite/sqflite.dart';
import '../models/event.dart';
import 'database_provider.dart';

class EventRepository {
  Future<void> logEvent(Event event) async {
    final db = await DatabaseProvider.instance.database;
    await db.insert('event_log', event.toJson());
  }

  Future<List<Event>> getEventsForRecord(String recordId) async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      'event_log',
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'timestamp ASC',
    );
    return results.map((json) => Event.fromJson(json)).toList();
  }

  Future<List<Event>> getAllEvents({int? limit}) async {
    final db = await DatabaseProvider.instance.database;
    final results = await db.query(
      'event_log',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((json) => Event.fromJson(json)).toList();
  }
}
