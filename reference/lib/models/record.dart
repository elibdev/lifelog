import 'dart:convert';

/// Record types supported by the adaptive record widget.
///
/// Each type maps to a different visual rendering in AdaptiveRecordWidget.
/// Stored as a string in SQLite for readability and forward-compatibility.
// Dart enum: each value is a compile-time constant; exhaustive switch checking
// ensures we handle all types. See: https://dart.dev/language/enums
enum RecordType {
  text,
  heading,
  todo,
  bulletList,
  habit;

  String toDbValue() {
    switch (this) {
      case RecordType.text:
        return 'text';
      case RecordType.heading:
        return 'heading';
      case RecordType.todo:
        return 'todo';
      case RecordType.bulletList:
        return 'bullet_list';
      case RecordType.habit:
        return 'habit';
    }
  }

  static RecordType fromDbValue(String value) {
    switch (value) {
      case 'text':
        return RecordType.text;
      case 'heading':
        return RecordType.heading;
      case 'todo':
        return RecordType.todo;
      case 'bullet_list':
        return RecordType.bulletList;
      case 'habit':
        return RecordType.habit;
      // Migration: old 'note' records become text
      case 'note':
        return RecordType.text;
      default:
        throw Exception('Unknown record type: $value');
    }
  }
}

/// A single content record in the journal (Notion-style).
///
/// Uses a single concrete class with typed metadata accessors instead of
/// a subclass-per-type hierarchy. This makes type switching trivial
/// (just change the `type` field via copyWith) and keeps serialization simple.
///
/// Metadata keys are namespaced by record type to avoid collisions:
/// - todo: `{ "todo.checked": bool }`
/// - heading: `{ "heading.level": int }` (1, 2, or 3)
/// - bulletList: `{ "bulletList.indentLevel": int }`
/// - habit: `{ "habit.name": String, "habit.frequency": String, "habit.completions": [String], "habit.archived": bool }`
/// - text: `{}` (no extra metadata)
class Record {
  final String id;
  final String date; // ISO8601: '2026-01-21'
  final RecordType type;
  final String content;
  final Map<String, dynamic> metadata;
  final double orderPosition;
  final int createdAt;
  final int updatedAt;

  const Record({
    required this.id,
    required this.date,
    required this.type,
    required this.content,
    required this.metadata,
    required this.orderPosition,
    required this.createdAt,
    required this.updatedAt,
  });

  // ========================================================================
  // TYPED METADATA ACCESSORS
  // Keys are namespaced: "todo.checked", "heading.level", etc.
  // This prevents collisions if a record's type is changed and old metadata
  // keys linger — each type only reads its own namespace.
  // ========================================================================

  /// Whether this todo record is checked (only meaningful for RecordType.todo)
  bool get isChecked => metadata['todo.checked'] as bool? ?? false;

  /// Heading level 1-3 (only meaningful for RecordType.heading)
  int get headingLevel => metadata['heading.level'] as int? ?? 1;

  /// Indent level for bullet lists (only meaningful for RecordType.bulletList)
  int get indentLevel => metadata['bulletList.indentLevel'] as int? ?? 0;

  /// Habit name (only meaningful for RecordType.habit)
  String get habitName => metadata['habit.name'] as String? ?? '';

  /// Habit frequency: 'daily', 'weekly', or custom (only for RecordType.habit)
  String get habitFrequency => metadata['habit.frequency'] as String? ?? 'daily';

  /// List of ISO date strings when habit was completed (only for RecordType.habit)
  List<String> get habitCompletions {
    final raw = metadata['habit.completions'];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  /// Whether this habit is archived (only for RecordType.habit)
  bool get isArchived => metadata['habit.archived'] as bool? ?? false;

  // ========================================================================
  // IMMUTABLE UPDATE METHODS
  // Dart's immutable update pattern: create a new instance with changed fields.
  // `copyWith` returns a new Record; the original is untouched.
  // See: https://dart.dev/language/constructors#redirecting-constructors
  // ========================================================================

  Record copyWith({
    RecordType? type,
    String? content,
    Map<String, dynamic>? metadata,
    double? orderPosition,
    int? updatedAt,
  }) {
    return Record(
      id: id,
      date: date,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      orderPosition: orderPosition ?? this.orderPosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convenience: update specific metadata keys without replacing the whole map.
  /// Uses spread operator to merge existing + new keys.
  Record copyWithMetadata(Map<String, dynamic> updates) {
    return copyWith(
      metadata: {...metadata, ...updates},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ========================================================================
  // SERIALIZATION
  // ========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'type': type.toDbValue(),
      'content': content,
      'metadata': metadata,
      'order_position': orderPosition,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Record.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final Map<String, dynamic> metadata;
    if (rawMetadata is String) {
      metadata = jsonDecode(rawMetadata) as Map<String, dynamic>;
    } else if (rawMetadata is Map<String, dynamic>) {
      metadata = rawMetadata;
    } else {
      metadata = {};
    }

    return Record(
      id: json['id'] as String,
      date: json['date'] as String,
      type: RecordType.fromDbValue(json['type'] as String),
      content: json['content'] as String? ?? '',
      metadata: metadata,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
    );
  }
}
