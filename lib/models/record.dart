// Base class holds all common fields - subclasses only add type-specific fields
abstract class Record {
  final String id;
  final String date; // ISO8601: '2026-01-21'
  final String content;
  final int createdAt;
  final int updatedAt;
  final double orderPosition;

  // Type is computed by subclasses
  String get type;

  // Base constructor used by subclasses
  Record({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.orderPosition,
  });

  // Immutable update pattern
  Record copyWith({String? content, int? updatedAt});

  // Serialization
  Map<String, dynamic> toJson();

  // Factory pattern for polymorphic deserialization
  factory Record.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'note':
        return NoteRecord.fromJson(json);
      case 'todo':
        return TodoRecord.fromJson(json);
      default:
        throw Exception('Unknown record type: ${json['type']}');
    }
  }
}

// NoteRecord has no additional fields beyond the base Record
class NoteRecord extends Record {
  NoteRecord({
    required super.id,
    required super.date,
    required super.content,
    required super.createdAt,
    required super.updatedAt,
    required super.orderPosition,
  });

  @override
  String get type => 'note';

  @override
  Record copyWith({String? content, int? updatedAt}) {
    return NoteRecord(
      id: id,
      date: date,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderPosition: orderPosition,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'metadata': {'content': content},
      'created_at': createdAt,
      'updated_at': updatedAt,
      'order_position': orderPosition,
    };
  }

  factory NoteRecord.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    return NoteRecord(
      id: json['id'] as String,
      date: json['date'] as String,
      content: metadata['content'] as String,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// TodoRecord adds only the todo-specific 'checked' field
class TodoRecord extends Record {
  final bool checked;

  TodoRecord({
    required super.id,
    required super.date,
    required super.content,
    required super.createdAt,
    required super.updatedAt,
    required super.orderPosition,
    this.checked = false,
  });

  @override
  String get type => 'todo';

  @override
  Record copyWith({String? content, int? updatedAt}) {
    return TodoRecord(
      id: id,
      date: date,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderPosition: orderPosition,
      checked: checked,
    );
  }

  // Todo-specific copyWith for toggling checked state
  TodoRecord copyWithChecked({bool? checked, int? updatedAt}) {
    return TodoRecord(
      id: id,
      date: date,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderPosition: orderPosition,
      checked: checked ?? this.checked,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'metadata': {'content': content, 'checked': checked},
      'created_at': createdAt,
      'updated_at': updatedAt,
      'order_position': orderPosition,
    };
  }

  factory TodoRecord.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    return TodoRecord(
      id: json['id'] as String,
      date: json['date'] as String,
      content: metadata['content'] as String,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
      checked: metadata['checked'] as bool? ?? false,
    );
  }
}
