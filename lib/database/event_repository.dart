import '../models/event.dart';
import 'database_provider.dart';

class EventRepository {
  Future<void> logEvent(Event event) async {
    await DatabaseProvider.instance.executeAsync(
      '''
      INSERT INTO event_log (event_type, record_id, payload, timestamp, device_id)
      VALUES (:event_type, :record_id, :payload, :timestamp, :device_id)
      ''',
      event.toJson(),
    );
  }

  Future<List<Event>> getEventsForRecord(String recordId) async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM event_log WHERE record_id = :record_id ORDER BY timestamp ASC',
      {'record_id': recordId},
    );
    return results.map((row) => Event.fromJson(row)).toList();
  }

  Future<List<Event>> getAllEvents({int? limit}) async {
    if (limit != null) {
      final results = await DatabaseProvider.instance.queryAsync(
        'SELECT * FROM event_log ORDER BY timestamp DESC LIMIT :limit',
        {'limit': limit},
      );
      return results.map((row) => Event.fromJson(row)).toList();
    } else {
      final results = await DatabaseProvider.instance.queryAsync(
        'SELECT * FROM event_log ORDER BY timestamp DESC',
      );
      return results.map((row) => Event.fromJson(row)).toList();
    }
  }
}
