import 'dart:convert';

class JournalEvent {
  final String id;
  final String eventType;
  final String? recordId;
  final DateTime date;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final String? clientId;

  JournalEvent({
    required this.id,
    required this.eventType,
    this.recordId,
    required this.date,
    required this.timestamp,
    required this.payload,
    this.clientId,
  });

  factory JournalEvent.fromDb(Map<String, dynamic> map) {
    return JournalEvent(
      id: map['id'] as String,
      eventType: map['event_type'] as String,
      recordId: map['record_id'] as String?,
      date: DateTime.parse(map['date'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      payload: json.decode(map['payload'] as String) as Map<String, dynamic>,
      clientId: map['client_id'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'event_type': eventType,
      'record_id': recordId,
      'date': _dateKey(date),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'payload': json.encode(payload),
      'client_id': clientId,
    };
  }

  static String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  String toString() {
    return 'JournalEvent(id: $id, type: $eventType, recordId: $recordId, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Event type constants
class EventType {
  static const String recordCreated = 'record_created';
  static const String metadataUpdated = 'metadata_updated';
  static const String recordDeleted = 'record_deleted';
  static const String recordReordered = 'record_reordered';
  static const String batchReorder = 'batch_reorder';
}
