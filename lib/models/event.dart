import 'dart:convert';

enum EventType {
  recordSaved,  // Unified event for both create and update (database uses upsert)
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
      // Legacy support for old event types
      case 'record_created':
      case 'record_updated':
        return EventType.recordSaved;
      case 'record_deleted':
        return EventType.recordDeleted;
      default:
        throw Exception('Unknown event type: $value');
    }
  }
}

class Event {
  final EventType eventType;
  final String recordId;
  final Map<String, dynamic> payload; // Arbitrary JSON - will be encoded to string for DB
  final int timestamp;
  final String? deviceId;

  Event({
    required this.eventType,
    required this.recordId,
    required this.payload,
    required this.timestamp,
    this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventType.toDbValue(),
      'record_id': recordId,
      'payload': jsonEncode(payload), // Encode to string for SQLite
      'timestamp': timestamp,
      'device_id': deviceId,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      eventType: EventType.fromDbValue(json['event_type'] as String),
      recordId: json['record_id'] as String,
      payload: jsonDecode(json['payload'] as String) as Map<String, dynamic>,
      timestamp: json['timestamp'] as int,
      deviceId: json['device_id'] as String?,
    );
  }
}
