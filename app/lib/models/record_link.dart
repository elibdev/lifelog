/// A directional link between two records, created by a relation field.
///
/// The [fieldId] ties this link to the specific relation field on the source
/// record's database, allowing multiple relation fields between the same
/// pair of databases.
class RecordLink {
  final String sourceRecordId;
  final String targetRecordId;
  final String fieldId;
  final int createdAt;

  const RecordLink({
    required this.sourceRecordId,
    required this.targetRecordId,
    required this.fieldId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'source_record_id': sourceRecordId,
        'target_record_id': targetRecordId,
        'field_id': fieldId,
        'created_at': createdAt,
      };

  factory RecordLink.fromJson(Map<String, dynamic> json) {
    return RecordLink(
      sourceRecordId: json['source_record_id'] as String,
      targetRecordId: json['target_record_id'] as String,
      fieldId: json['field_id'] as String,
      createdAt: json['created_at'] as int,
    );
  }
}
