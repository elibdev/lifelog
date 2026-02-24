import 'dart:convert';

/// Event types for the append-only event log.
///
/// Every write (save/delete) to the records table also appends an event
/// to the event_log table. This enables sync via event replay.
enum EventType {
  recordSaved,
  recordDeleted;

  String toDbValue() {
    switch (this) {
      case EventType.recordSaved:
        return 'record_saved';
      case EventType.recordDeleted:
        return 'record_deleted';
    }
  }

  static EventType fromDbValue(String value) {
    switch (value) {
      case 'record_saved':
        return EventType.recordSaved;
      case 'record_deleted':
        return EventType.recordDeleted;
      default:
        throw Exception('Unknown event type: $value');
    }
  }
}

/// A single entry in the append-only event log.
///
/// Events capture every mutation for later sync/replay.
/// The payload is the full record JSON at the time of the event.
class Event {
  final String? id;
  final String recordId;
  final EventType eventType;
  final Map<String, dynamic> payload;
  final int timestamp;
  final String? deviceId;

  const Event({
    this.id,
    required this.recordId,
    required this.eventType,
    required this.payload,
    required this.timestamp,
    this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType.toDbValue(),
      'record_id': recordId,
      'payload': jsonEncode(payload),
      'timestamp': timestamp,
      'device_id': deviceId,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final Map<String, dynamic> payload;
    if (rawPayload is String) {
      payload = jsonDecode(rawPayload) as Map<String, dynamic>;
    } else if (rawPayload is Map<String, dynamic>) {
      payload = rawPayload;
    } else {
      payload = {};
    }

    return Event(
      id: json['id']?.toString(),
      recordId: json['record_id'] as String,
      eventType: EventType.fromDbValue(json['event_type'] as String),
      payload: payload,
      timestamp: json['timestamp'] as int,
      deviceId: json['device_id'] as String?,
    );
  }
}
