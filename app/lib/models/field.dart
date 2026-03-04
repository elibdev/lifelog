import 'dart:convert';

/// Field types supported in the MVP.
///
/// Stored as plain strings in SQLite for forward-compatibility — unknown types
/// from a future version degrade gracefully to [text].
// Dart enhanced enums: each value can have methods and properties.
// See: https://dart.dev/language/enums#declaring-enhanced-enums
enum FieldType {
  text,
  number,
  checkbox,
  date,
  select,
  relation;

  String toDbValue() => name;

  static FieldType fromDbValue(String value) {
    // `tryByName` returns null for unknown strings — future-proofs against
    // new types added in later versions. Falls back to text.
    return FieldType.values.asNameMap()[value] ?? FieldType.text;
  }
}

/// A schema field belonging to a database.
///
/// Defines one column in the user's database. The [config] map holds
/// type-specific settings (select options, relation target, etc.) as JSON.
class Field {
  final String id;
  final String databaseId;
  final String name;
  final FieldType fieldType;
  final Map<String, dynamic> config;
  final double orderPosition;
  final int createdAt;
  final int updatedAt;

  const Field({
    required this.id,
    required this.databaseId,
    required this.name,
    required this.fieldType,
    this.config = const {},
    required this.orderPosition,
    required this.createdAt,
    required this.updatedAt,
  });

  /// For select fields: the list of allowed option values.
  List<String> get selectOptions {
    final raw = config['options'];
    if (raw is List) return raw.cast<String>();
    return [];
  }

  /// For relation fields: the target database ID.
  String? get targetDatabaseId => config['target_database_id'] as String?;

  Field copyWith({
    String? name,
    FieldType? fieldType,
    Map<String, dynamic>? config,
    double? orderPosition,
    int? updatedAt,
  }) {
    return Field(
      id: id,
      databaseId: databaseId,
      name: name ?? this.name,
      fieldType: fieldType ?? this.fieldType,
      config: config ?? this.config,
      orderPosition: orderPosition ?? this.orderPosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'database_id': databaseId,
        'field_type': fieldType.toDbValue(),
        'config': config,
        'order_position': orderPosition,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Field.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    final Map<String, dynamic> config;
    if (rawConfig is String) {
      config = jsonDecode(rawConfig) as Map<String, dynamic>;
    } else if (rawConfig is Map<String, dynamic>) {
      config = rawConfig;
    } else {
      config = {};
    }

    return Field(
      id: json['id'] as String,
      databaseId: json['database_id'] as String,
      name: json['name'] as String,
      fieldType: FieldType.fromDbValue(json['field_type'] as String),
      config: config,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
    );
  }
}
