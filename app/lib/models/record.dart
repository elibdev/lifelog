import 'dart:convert';

/// A single record (row) in a user-created database.
///
/// Structured field values live in [values] as {field_id: value}.
/// The [content] field is a built-in plain-text note body, always FTS-indexed.
/// This means every record can also serve as a note without any special type.
class Record {
  final String id;
  final String databaseId;
  final String content;
  final Map<String, dynamic> values;
  final double orderPosition;
  final int createdAt;
  final int updatedAt;

  const Record({
    required this.id,
    required this.databaseId,
    this.content = '',
    this.values = const {},
    required this.orderPosition,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get a field value by field ID, with an optional fallback.
  dynamic getValue(String fieldId, [dynamic defaultValue]) =>
      values[fieldId] ?? defaultValue;

  Record copyWith({
    String? content,
    Map<String, dynamic>? values,
    double? orderPosition,
    int? updatedAt,
  }) {
    return Record(
      id: id,
      databaseId: databaseId,
      content: content ?? this.content,
      values: values ?? this.values,
      orderPosition: orderPosition ?? this.orderPosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Update a single field value without replacing the entire map.
  /// Uses Dart spread operator to merge.
  Record withFieldValue(String fieldId, dynamic value) {
    return copyWith(
      values: {...values, fieldId: value},
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'database_id': databaseId,
        'content': content,
        'values_json': values,
        'order_position': orderPosition,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Record.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values_json'];
    final Map<String, dynamic> values;
    if (rawValues is String) {
      values = jsonDecode(rawValues) as Map<String, dynamic>;
    } else if (rawValues is Map<String, dynamic>) {
      values = rawValues;
    } else {
      values = {};
    }

    return Record(
      id: json['id'] as String,
      databaseId: json['database_id'] as String,
      content: json['content'] as String? ?? '',
      values: values,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
    );
  }
}
