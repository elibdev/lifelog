import 'dart:convert';

class JournalRecord {
  final String id;
  final DateTime date;
  final String recordType;
  final double position;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalRecord({
    required this.id,
    required this.date,
    required this.recordType,
    required this.position,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalRecord.fromDb(Map<String, dynamic> map) {
    return JournalRecord(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      recordType: map['record_type'] as String,
      position: map['position'] as double,
      metadata: json.decode(map['metadata'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'date': _dateKey(date),
      'record_type': recordType,
      'position': position,
      'metadata': json.encode(metadata),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  JournalRecord copyWith({
    String? id,
    DateTime? date,
    String? recordType,
    double? position,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      recordType: recordType ?? this.recordType,
      position: position ?? this.position,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  String toString() {
    return 'JournalRecord(id: $id, date: $date, type: $recordType, position: $position)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
