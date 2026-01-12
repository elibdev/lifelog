import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

enum EventType { CREATE, UPDATE, DELETE }

class Event {
  final String id;
  final EventType type;
  final String noteId;
  final String? content;
  final int timestamp;
  final String hash;

  Event({
    required this.id,
    required this.type,
    required this.noteId,
    this.content,
    required this.timestamp,
    required this.hash,
  });

  factory Event.create({
    required String noteId,
    required String content,
    int? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final eventId = const Uuid().v4();
    
    final event = Event(
      id: eventId,
      type: EventType.CREATE,
      noteId: noteId,
      content: content,
      timestamp: ts,
      hash: '', // Will be set below
    );
    
    return event.copyWith(hash: event._calculateHash());
  }

  factory Event.update({
    required String noteId,
    required String content,
    int? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final eventId = const Uuid().v4();
    
    final event = Event(
      id: eventId,
      type: EventType.UPDATE,
      noteId: noteId,
      content: content,
      timestamp: ts,
      hash: '', // Will be set below
    );
    
    return event.copyWith(hash: event._calculateHash());
  }

  factory Event.delete({
    required String noteId,
    int? timestamp,
  }) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final eventId = const Uuid().v4();
    
    final event = Event(
      id: eventId,
      type: EventType.DELETE,
      noteId: noteId,
      content: null,
      timestamp: ts,
      hash: '', // Will be set below
    );
    
    return event.copyWith(hash: event._calculateHash());
  }

  String _calculateHash() {
    final input = '$id$type$noteId$timestamp$content';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  Event copyWith({
    String? id,
    EventType? type,
    String? noteId,
    String? content,
    int? timestamp,
    String? hash,
  }) {
    return Event(
      id: id ?? this.id,
      type: type ?? this.type,
      noteId: noteId ?? this.noteId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      hash: hash ?? this.hash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'noteId': noteId,
      'content': content,
      'timestamp': timestamp,
      'hash': hash,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      noteId: json['noteId'] as String,
      content: json['content'] as String?,
      timestamp: json['timestamp'] as int,
      hash: json['hash'] as String,
    );
  }

  static String generateNoteIdFromDate(String date, String userSeed) {
    final input = '$date$userSeed';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    
    // Generate UUID from hash bytes using Uuid class
    final uuidBytes = Uint8List(16);
    final hashBytes = digest.bytes;
    for (int i = 0; i < 16; i++) {
      uuidBytes[i] = hashBytes[i];
    }
    
    // Set UUID version 4 and variant bits
    uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40; // Version 4
    uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80; // Variant 10
    
    // Simple UUID v4 generation from bytes
    uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40; // Version 4
    uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80; // Variant 10
    
    // Format as UUID string
    final hex = uuidBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.hash == hash;
  }

  @override
  int get hashCode => hash.hashCode;

  @override
  String toString() {
    return 'Event(id: $id, type: $type, noteId: $noteId, hash: $hash)';
  }
}