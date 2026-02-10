import 'dart:convert';

/// Block types supported by the adaptive block widget.
///
/// Each type maps to a different visual rendering in AdaptiveBlockWidget.
/// Stored as a string in SQLite for readability and forward-compatibility.
// Dart enum: each value is a compile-time constant; exhaustive switch checking
// ensures we handle all types. See: https://dart.dev/language/enums
enum BlockType {
  text,
  heading,
  todo,
  bulletList,
  habit;

  String toDbValue() {
    switch (this) {
      case BlockType.text:
        return 'text';
      case BlockType.heading:
        return 'heading';
      case BlockType.todo:
        return 'todo';
      case BlockType.bulletList:
        return 'bullet_list';
      case BlockType.habit:
        return 'habit';
    }
  }

  static BlockType fromDbValue(String value) {
    switch (value) {
      case 'text':
        return BlockType.text;
      case 'heading':
        return BlockType.heading;
      case 'todo':
        return BlockType.todo;
      case 'bullet_list':
        return BlockType.bulletList;
      case 'habit':
        return BlockType.habit;
      // Migration: old 'note' records become text blocks
      case 'note':
        return BlockType.text;
      default:
        throw Exception('Unknown block type: $value');
    }
  }
}

/// A single content block in the journal (Notion-style).
///
/// Uses a single concrete class with typed metadata accessors instead of
/// a subclass-per-type hierarchy. This makes type switching trivial
/// (just change the `type` field via copyWith) and keeps serialization simple.
///
/// The `metadata` map stores type-specific fields:
/// - todo: `{ "checked": bool }`
/// - heading: `{ "level": int }` (1, 2, or 3)
/// - bulletList: `{ "indentLevel": int }`
/// - habit: `{ "habitName": String, "frequency": String, "completions": [String] }`
/// - text: `{}` (no extra metadata)
class Block {
  final String id;
  final String date; // ISO8601: '2026-01-21'
  final BlockType type;
  final String content;
  final Map<String, dynamic> metadata;
  final double orderPosition;
  final int createdAt;
  final int updatedAt;

  const Block({
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
  // Provide type-safe access to metadata fields with sensible defaults.
  // Using `as Type? ?? default` is a Dart null-safety pattern:
  // cast to nullable type, then use ?? to provide fallback.
  // ========================================================================

  /// Whether this todo block is checked (only meaningful for BlockType.todo)
  bool get isChecked => metadata['checked'] as bool? ?? false;

  /// Heading level 1-3 (only meaningful for BlockType.heading)
  int get headingLevel => metadata['level'] as int? ?? 1;

  /// Indent level for bullet lists (only meaningful for BlockType.bulletList)
  int get indentLevel => metadata['indentLevel'] as int? ?? 0;

  /// Habit name (only meaningful for BlockType.habit)
  String get habitName => metadata['habitName'] as String? ?? '';

  /// Habit frequency: 'daily', 'weekly', or custom (only for BlockType.habit)
  String get habitFrequency => metadata['frequency'] as String? ?? 'daily';

  /// List of ISO date strings when habit was completed (only for BlockType.habit)
  List<String> get habitCompletions {
    final raw = metadata['completions'];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  /// Whether this habit is archived (only for BlockType.habit)
  bool get isArchived => metadata['archived'] as bool? ?? false;

  // ========================================================================
  // IMMUTABLE UPDATE METHODS
  // Dart's immutable update pattern: create a new instance with changed fields.
  // `copyWith` returns a new Block; the original is untouched.
  // See: https://dart.dev/language/constructors#redirecting-constructors
  // ========================================================================

  Block copyWith({
    BlockType? type,
    String? content,
    Map<String, dynamic>? metadata,
    double? orderPosition,
    int? updatedAt,
  }) {
    return Block(
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

  /// Convenience: update specific metadata keys without replacing the whole map
  Block copyWithMetadata(Map<String, dynamic> updates) {
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

  factory Block.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final Map<String, dynamic> metadata;
    if (rawMetadata is String) {
      metadata = jsonDecode(rawMetadata) as Map<String, dynamic>;
    } else if (rawMetadata is Map<String, dynamic>) {
      metadata = rawMetadata;
    } else {
      metadata = {};
    }

    return Block(
      id: json['id'] as String,
      date: json['date'] as String,
      type: BlockType.fromDbValue(json['type'] as String),
      content: json['content'] as String? ?? '',
      metadata: metadata,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
    );
  }
}
