import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class TrustedPeer {
  final String deviceId;
  final String userId;
  final String? deviceName;
  final String signPublicKey;
  final String encryptPublicKey;
  final DateTime pairedAt;
  final DateTime? lastSeen;

  TrustedPeer({
    required this.deviceId,
    required this.userId,
    this.deviceName,
    required this.signPublicKey,
    required this.encryptPublicKey,
    required this.pairedAt,
    this.lastSeen,
  });

  factory TrustedPeer.fromMap(Map<String, dynamic> map) {
    return TrustedPeer(
      deviceId: map['device_id'] as String,
      userId: map['user_id'] as String,
      deviceName: map['device_name'] as String?,
      signPublicKey: map['sign_public_key'] as String,
      encryptPublicKey: map['encrypt_public_key'] as String,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(map['paired_at'] as int),
      lastSeen: map['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'user_id': userId,
      'device_name': deviceName,
      'sign_public_key': signPublicKey,
      'encrypt_public_key': encryptPublicKey,
      'paired_at': pairedAt.millisecondsSinceEpoch,
      'last_seen': lastSeen?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'signPublicKey': signPublicKey,
      'encryptPublicKey': encryptPublicKey,
      'pairedAt': pairedAt.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}

class TrustedPeers {
  static final TrustedPeers instance = TrustedPeers._();
  TrustedPeers._();

  Future<void> addTrustedPeer(TrustedPeer peer) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'trusted_peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('✅ Added trusted peer: ${peer.deviceId} (${peer.deviceName})');
  }

  Future<void> removeTrustedPeer(String deviceId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'trusted_peers',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    print('🗑️ Removed trusted peer: $deviceId');
  }

  Future<TrustedPeer?> getTrustedPeer(String deviceId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'trusted_peers',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    if (maps.isNotEmpty) {
      return TrustedPeer.fromMap(maps.first);
    }
    return null;
  }

  Future<Set<String>> getAllTrustedUserIds() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('trusted_peers', columns: ['user_id']);
    return result.map((row) => row['user_id'] as String).toSet();
  }

  Future<List<TrustedPeer>> getAllTrustedPeers() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'trusted_peers',
      orderBy: 'paired_at DESC',
    );
    return result.map((map) => TrustedPeer.fromMap(map)).toList();
  }

  Future<bool> isTrustedDevice(String deviceId) async {
    final peer = await getTrustedPeer(deviceId);
    return peer != null;
  }

  Future<void> updateLastSeen(String deviceId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'trusted_peers',
      {'last_seen': DateTime.now().millisecondsSinceEpoch},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> clearAll() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('trusted_peers');
    print('🗑️ Cleared all trusted peers');
  }

  Future<int> getCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM trusted_peers');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> updatePeerInfo(
    String deviceId, {
    String? deviceName,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final updates = <String, dynamic>{};

    if (deviceName != null) {
      updates['device_name'] = deviceName;
    }

    updates['last_seen'] = DateTime.now().millisecondsSinceEpoch;

    if (updates.isNotEmpty) {
      await db.update(
        'trusted_peers',
        updates,
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
    }
  }
}
