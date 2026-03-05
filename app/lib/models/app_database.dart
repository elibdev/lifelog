import 'dart:convert';

/// Represents a user-created database (e.g. "Books", "Projects").
///
/// Each database has a schema defined by its [Field] rows and contains
/// [Record] entries. The [config] map stores view preferences and future
/// settings as JSON — no schema changes needed to add new config keys.
class AppDatabase {
  final String id;
  final String name;
  final Map<String, dynamic> config;
  final double orderPosition;
  final int createdAt;
  final int updatedAt;

  const AppDatabase({
    required this.id,
    required this.name,
    this.config = const {},
    required this.orderPosition,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Which view is currently active for this database.
  /// Defaults to 'card' — stored in config so new views are additive.
  String get currentView => config['current_view'] as String? ?? 'card';

  AppDatabase copyWith({
    String? name,
    Map<String, dynamic>? config,
    double? orderPosition,
    int? updatedAt,
  }) {
    return AppDatabase(
      id: id,
      name: name ?? this.name,
      config: config ?? this.config,
      orderPosition: orderPosition ?? this.orderPosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'config': config,
        'order_position': orderPosition,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory AppDatabase.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    final Map<String, dynamic> config;
    if (rawConfig is String) {
      config = jsonDecode(rawConfig) as Map<String, dynamic>;
    } else if (rawConfig is Map<String, dynamic>) {
      config = rawConfig;
    } else {
      config = {};
    }

    return AppDatabase(
      id: json['id'] as String,
      name: json['name'] as String,
      config: config,
      orderPosition: (json['order_position'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
    );
  }
}
