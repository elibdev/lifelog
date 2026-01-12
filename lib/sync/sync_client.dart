import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'crypto_identity.dart';
import 'event.dart';
import 'gset.dart';

class Peer {
  final String deviceId;
  final String deviceName;
  final String address;
  final int httpPort;
  final String url;
  final String signPublicKey;
  final String encryptPublicKey;
  final DateTime lastSeen;

  Peer({
    required this.deviceId,
    required this.deviceName,
    required this.address,
    required this.httpPort,
    required this.url,
    required this.signPublicKey,
    required this.encryptPublicKey,
    required this.lastSeen,
  });

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      address: json['address'],
      httpPort: json['httpPort'],
      url: json['url'],
      signPublicKey: json['signPublicKey'],
      encryptPublicKey: json['encryptPublicKey'],
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'address': address,
      'httpPort': httpPort,
      'url': url,
      'signPublicKey': signPublicKey,
      'encryptPublicKey': encryptPublicKey,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }
}

class SyncClient {
  final CryptoIdentity identity;
  final Duration timeout;

  SyncClient({required this.identity, this.timeout = const Duration(seconds: 10)});

  /// Perform complete sync with a peer
  Future<SyncResult> syncWithPeer(Peer peer, GSet localGSet) async {
    try {
      print('🔄 Syncing with ${peer.deviceName} (${peer.url})...');

      // Step 1: Get inventory
      final inventoryResult = await _getInventory(peer);
      if (!inventoryResult.success) {
        return SyncResult(success: false, error: inventoryResult.error);
      }

      final peerHashes = Set<String>.from(inventoryResult.hashes!);
      final localHashes = localGSet.getHashes();

      final weNeed = peerHashes.difference(localHashes);
      final theyNeed = localHashes.difference(peerHashes);

      print('  We need: ${weNeed.length} events');
      print('  They need: ${theyNeed.length} events');

      int pulled = 0;
      int pushed = 0;

      // Step 2: Pull events we need
      if (weNeed.isNotEmpty) {
        final pullResult = await _pullEvents(peer, weNeed);
        if (!pullResult.success) {
          return SyncResult(success: false, error: pullResult.error);
        }
        pulled = pullResult.events!.length;
        print('  ✓ Pulled $pulled events');
      }

      // Step 3: Push events they need
      if (theyNeed.isNotEmpty) {
        final eventsToPush = localGSet.getEvents(theyNeed);
        final pushResult = await _pushEvents(peer, eventsToPush);
        if (!pushResult.success) {
          return SyncResult(success: false, error: pushResult.error);
        }
        pushed = pushResult.added!;
        print('  ✓ Pushed $pushed events');
      }

      print('  ✅ Sync complete!');
      return SyncResult(
        success: true,
        pulled: pulled,
        pushed: pushed,
      );

    } catch (e) {
      print('  ❌ Sync failed: $e');
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Get challenge from peer
  Future<ChallengeResult> _getChallenge(Peer peer) async {
    try {
      final response = await http.get(
        Uri.parse('${peer.url}/sync/challenge'),
      ).timeout(timeout);

      if (response.statusCode != 200) {
        return ChallengeResult(success: false, error: 'HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);
      return ChallengeResult(
        success: true,
        challenge: data['challenge'],
        serverEncryptKey: data['serverEncryptKey'],
      );
    } catch (e) {
      return ChallengeResult(success: false, error: e.toString());
    }
  }

  /// Perform authenticated request
  Future<AuthenticatedResult> _authenticatedRequest(
    Peer peer,
    String endpoint, {
    Map<String, String>? headers,
    String? body,
  }) async {
    try {
      // Step 1: Get challenge
      final challengeResult = await _getChallenge(peer);
      if (!challengeResult.success) {
        return AuthenticatedResult(success: false, error: challengeResult.error);
      }

      // Step 2: Sign challenge
      final signature = await identity.signMessage({'challenge': challengeResult.challenge});
      final authData = {
        'challenge': challengeResult.challenge,
        'signature': signature,
        'signPublicKey': identity.getSignPublicKeyB64(),
      };
      final authHeader = base64.encode(utf8.encode(json.encode(authData)));

      // Step 3: Derive shared key
      final sharedKey = await identity.deriveSharedKey(challengeResult.serverEncryptKey!);

      // Step 4: Make request
      final requestHeaders = <String, String>{
        'X-Auth-Response': authHeader,
        'X-Encrypt-Key': await identity.getEncryptPublicKeyB64(),
        ...?headers,
      };

      http.Response response;
      if (body != null) {
        response = await http.post(
          Uri.parse('${peer.url}$endpoint'),
          headers: requestHeaders,
          body: body,
        ).timeout(timeout);
      } else {
        response = await http.get(
          Uri.parse('${peer.url}$endpoint'),
          headers: requestHeaders,
        ).timeout(timeout);
      }

      if (response.statusCode != 200) {
        return AuthenticatedResult(success: false, error: 'HTTP ${response.statusCode}');
      }

      // Step 5: Decrypt response
      final encryptedData = json.decode(response.body);
      final plaintext = await identity.decryptMessage(encryptedData, sharedKey);

      return AuthenticatedResult(
        success: true,
        data: plaintext,
        sharedKey: sharedKey,
      );

    } catch (e) {
      return AuthenticatedResult(success: false, error: e.toString());
    }
  }

  /// Get inventory from peer
  Future<InventoryResult> _getInventory(Peer peer) async {
    final result = await _authenticatedRequest(peer, '/sync/inventory');
    if (!result.success) {
      return InventoryResult(success: false, error: result.error);
    }

    final data = json.decode(result.data!);
    return InventoryResult(
      success: true,
      hashes: List<String>.from(data['hashes']),
    );
  }

  /// Pull events from peer
  Future<PullResult> _pullEvents(Peer peer, Set<String> hashes) async {
    final hashesStr = hashes.join(',');
    final result = await _authenticatedRequest(peer, '/sync/pull?hashes=$hashesStr');
    if (!result.success) {
      return PullResult(success: false, error: result.error);
    }

    final data = json.decode(result.data!);
    final events = (data['events'] as List)
        .map((e) => Event.fromJson(e))
        .toList();

    return PullResult(success: true, events: events);
  }

  /// Push events to peer
  Future<PushResult> _pushEvents(Peer peer, List<Event> events) async {
    // First get challenge to derive key for encryption
    final challengeResult = await _getChallenge(peer);
    if (!challengeResult.success) {
      return PushResult(success: false, error: challengeResult.error);
    }

    // Sign challenge
    final signature = await identity.signMessage({'challenge': challengeResult.challenge});
    final authData = {
      'challenge': challengeResult.challenge,
      'signature': signature,
      'signPublicKey': identity.getSignPublicKeyB64(),
    };
    final authHeader = base64.encode(utf8.encode(json.encode(authData)));

    // Derive shared key
    final sharedKey = await identity.deriveSharedKey(challengeResult.serverEncryptKey!);

    // Encrypt request body
    final plaintext = json.encode({'events': events.map((e) => e.toJson()).toList()});
    final encryptedBody = await identity.encryptMessage(plaintext, sharedKey);

    // Make request
    final response = await http.post(
      Uri.parse('${peer.url}/sync/push'),
      headers: {
        'X-Auth-Response': authHeader,
        'X-Encrypt-Key': await identity.getEncryptPublicKeyB64(),
        'Content-Type': 'application/json',
      },
      body: json.encode(encryptedBody),
    ).timeout(timeout);

    if (response.statusCode != 200) {
      return PushResult(success: false, error: 'HTTP ${response.statusCode}');
    }

    // Decrypt response
    final encryptedResponse = json.decode(response.body);
    final responseText = await identity.decryptMessage(encryptedResponse, sharedKey);
    final responseData = json.decode(responseText);

    return PushResult(
      success: true,
      added: responseData['added'],
    );
  }
}

// Result classes

class SyncResult {
  final bool success;
  final String? error;
  final int? pulled;
  final int? pushed;
  final List<Event>? events;

  SyncResult({
    required this.success,
    this.error,
    this.pulled,
    this.pushed,
    this.events,
  });
}

class ChallengeResult {
  final bool success;
  final String? error;
  final String? challenge;
  final String? serverEncryptKey;

  ChallengeResult({
    required this.success,
    this.error,
    this.challenge,
    this.serverEncryptKey,
  });
}

class AuthenticatedResult {
  final bool success;
  final String? error;
  final String? data;
  final Uint8List? sharedKey;

  AuthenticatedResult({
    required this.success,
    this.error,
    this.data,
    this.sharedKey,
  });
}

class InventoryResult {
  final bool success;
  final String? error;
  final List<String>? hashes;

  InventoryResult({
    required this.success,
    this.error,
    this.hashes,
  });
}

class PullResult {
  final bool success;
  final String? error;
  final List<Event>? events;

  PullResult({
    required this.success,
    this.error,
    this.events,
  });
}

class PushResult {
  final bool success;
  final String? error;
  final int? added;

  PushResult({
    required this.success,
    this.error,
    this.added,
  });
}