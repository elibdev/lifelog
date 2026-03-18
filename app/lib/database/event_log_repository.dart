import '../models/event_log_entry.dart';
import 'database_provider.dart';

/// Read-only access to the event log.
///
/// Events are written inside other repositories' transactions via
/// [DatabaseProvider.logEvent]. This repository only reads.
class EventLogRepository {
  Future<List<EventLogEntry>> getAll() async {
    final results = await DatabaseProvider.instance.queryAsync(
      'SELECT * FROM event_log ORDER BY timestamp DESC',
      {},
    );
    return results.map((row) => EventLogEntry.fromJson(row)).toList();
  }
}
