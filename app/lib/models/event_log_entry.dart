import 'dart:convert';

/// A single entry in the append-only event log.
///
/// Events are written on every create/update/delete of records and databases.
/// The log is intended for auditing and debugging — it is never modified,
/// only appended to.
class EventLogEntry {
  final int id;
  final String eventType;   // 'created' | 'updated' | 'deleted'
  final String entityType;  // 'record' | 'database'
  final String entityId;
  final Map<String, dynamic> payload;
  final int timestamp;

  const EventLogEntry({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.timestamp,
  });

  factory EventLogEntry.fromJson(Map<String, Object?> json) {
    final rawPayload = json['payload'] as String? ?? '{}';
    return EventLogEntry(
      id: json['id'] as int,
      eventType: json['event_type'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      payload: jsonDecode(rawPayload) as Map<String, dynamic>,
      timestamp: json['timestamp'] as int,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
