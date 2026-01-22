import 'package:flutter/material.dart';

abstract class Record {
  String get id;
  String get date; // ISO8601: '2026-01-21'
  String get type; // 'note', 'todo'
  String get content;
  String get hintText;
  int get createdAt;
  int get updatedAt;
  double get orderPosition;

  // Polymorphic widget - each subclass provides its own
  Widget get leadingWidget;

  // Constructor for subclasses
  Record();

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

// Forward declarations so factory can reference them
class NoteRecord extends Record {
  @override
  final String id;
  @override
  final String date;
  @override
  final String content;
  @override
  final int createdAt;
  @override
  final int updatedAt;
  @override
  final double orderPosition;

  NoteRecord({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.orderPosition,
  }) : super();

  @override
  String get type => 'note';

  @override
  String get hintText => 'Add a note...';

  @override
  Widget get leadingWidget => const Icon(Icons.circle, size: 8);

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

class TodoRecord extends Record {
  @override
  final String id;
  @override
  final String date;
  @override
  final String content;
  @override
  final int createdAt;
  @override
  final int updatedAt;
  @override
  final double orderPosition;
  final bool checked;

  TodoRecord({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.orderPosition,
    this.checked = false,
  }) : super();

  @override
  String get type => 'todo';

  @override
  String get hintText => 'Add a todo...';

  @override
  Widget get leadingWidget => Checkbox(
        value: checked,
        onChanged: null, // Read-only here, handled by RecordWidget
      );

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

  // Need a todo-specific copyWith for toggling checked state
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
      'metadata': {
        'content': content,
        'checked': checked,
      },
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
