import 'dart:convert';

enum EventType {
  recordCreated,
  recordUpdated,
  recordDeleted;

  String toDbValue() {
    switch (this) {
      case EventType.recordCreated:
        return 'record_created';
      case EventType.recordUpdated:
        return 'record_updated';
      case EventType.recordDeleted:
        return 'record_deleted';
    }
  }

  static EventType fromDbValue(String value) {
    switch (value) {
      case 'record_created':
        return EventType.recordCreated;
      case 'record_updated':
        return EventType.recordUpdated;
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
