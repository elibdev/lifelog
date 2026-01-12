import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'crypto_identity.dart';
import 'event.dart';
import 'gset.dart';

class SyncServer {
  final CryptoIdentity identity;
  final GSet gset;
  final int port;
  HttpServer? _server;

  // Active challenges for authentication
  final Map<String, DateTime> _activeChallenges = {};

  SyncServer({
    required this.identity,
    required this.gset,
    required this.port,
  });

  Future<void> start() async {
    final router = Router();

    // Challenge endpoint
    router.get('/sync/challenge', _handleChallenge);

    // Authenticated endpoints
    router.get('/sync/inventory', _handleInventory);
    router.get('/sync/pull', _handlePull);
    router.post('/sync/push', _handlePush);

    // Middleware for authentication
    final handler = const Pipeline()
        .addMiddleware(_logRequests())
        .addHandler(router);

    try {
      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      print('🌐 Sync server started on port ${_server!.port}');
      
      // Clean up old challenges periodically
      Timer.periodic(Duration(seconds: 30), (_) => _cleanupStaleChallenges());
    } catch (e) {
      print('❌ Failed to start sync server: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('🌐 Sync server stopped');
    }
  }

  // Middleware for logging
  Middleware _logRequests() {
    return (Handler innerHandler) {
      return (Request request) async {
        final start = DateTime.now();
        final response = await innerHandler(request);
        final end = DateTime.now();
        final duration = end.difference(start);
        
        print('${request.method} ${request.requestedUri} - ${response.statusCode} (${duration.inMilliseconds}ms)');
        return response;
      };
    };
  }

  // Handle challenge request
  Future<Response> _handleChallenge(Request request) async {
    try {
      // Generate random challenge
      final challenge = _generateChallenge();
      final timestamp = DateTime.now();
      
      // Store challenge with 30-second expiration
      _activeChallenges[challenge] = timestamp;

      final encryptKey = await identity.getEncryptPublicKeyB64();
      final response = {
        'challenge': challenge,
        'serverEncryptKey': encryptKey,
      };

      return Response.ok(
        json.encode(response),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Challenge error: $e');
      return Response.internalServerError(body: 'Challenge generation failed');
    }
  }

  // Handle inventory request
  Future<Response> _handleInventory(Request request) async {
    try {
      // Verify authentication
      final authResult = await _verifyAuthentication(request);
      if (!authResult.success) {
        return Response(401, body: authResult.error);
      }

      final sharedKey = authResult.sharedKey!;
      final hashes = gset.getHashes().toList();

      final response = {'hashes': hashes};
      final encryptedResponse = await identity.encryptMessage(
        json.encode(response),
        sharedKey,
      );

      return Response.ok(
        json.encode(encryptedResponse),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Inventory error: $e');
      return Response.internalServerError(body: 'Inventory request failed');
    }
  }

  // Handle pull request
  Future<Response> _handlePull(Request request) async {
    try {
      // Verify authentication
      final authResult = await _verifyAuthentication(request);
      if (!authResult.success) {
        return Response(401, body: authResult.error);
      }

      // Parse requested hashes
      final queryParams = request.url.queryParameters;
      final hashesParam = queryParams['hashes'] ?? '';
      final requestedHashes = hashesParam.isEmpty
          ? <String>{}
          : hashesParam.split(',').where((h) => h.isNotEmpty).toSet();

      final sharedKey = authResult.sharedKey!;
      final events = gset.getEvents(requestedHashes);
      
      final response = {
        'events': events.map((e) => e.toJson()).toList(),
      };
      
      final encryptedResponse = await identity.encryptMessage(
        json.encode(response),
        sharedKey,
      );

      return Response.ok(
        json.encode(encryptedResponse),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Pull error: $e');
      return Response.internalServerError(body: 'Pull request failed');
    }
  }

  // Handle push request
  Future<Response> _handlePush(Request request) async {
    try {
      // Verify authentication
      final authResult = await _verifyAuthentication(request);
      if (!authResult.success) {
        return Response(401, body: authResult.error);
      }

      final sharedKey = authResult.sharedKey!;

      // Decrypt request body
      final body = await request.readAsString();
      final encryptedData = json.decode(body);
      final plaintext = await identity.decryptMessage(encryptedData, sharedKey);
      final data = json.decode(plaintext);

      // Merge events
      final eventsData = data['events'] as List;
      final events = eventsData.map((e) => Event.fromJson(e)).toList();
      final added = gset.merge(events);

      final response = {'added': added};
      final encryptedResponse = await identity.encryptMessage(
        json.encode(response),
        sharedKey,
      );

      return Response.ok(
        json.encode(encryptedResponse),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Push error: $e');
      return Response.internalServerError(body: 'Push request failed');
    }
  }

  // Verify authentication for requests
  Future<AuthResult> _verifyAuthentication(Request request) async {
    try {
      final authHeader = request.headers['x-auth-response'];
      final peerEncryptKey = request.headers['x-encrypt-key'];

      if (authHeader == null || peerEncryptKey == null) {
        return AuthResult(success: false, error: 'Missing authentication headers');
      }

      // Decode auth data
      final authData = json.decode(utf8.decode(base64.decode(authHeader)));
      final challenge = authData['challenge'] as String;
      final signature = authData['signature'] as String;
      final peerSignKey = authData['signPublicKey'] as String;

      // Verify challenge exists and not expired
      final challengeTimestamp = _activeChallenges[challenge];
      if (challengeTimestamp == null) {
        return AuthResult(success: false, error: 'Invalid or expired challenge');
      }

      final now = DateTime.now();
      if (now.difference(challengeTimestamp).inSeconds > 30) {
        _activeChallenges.remove(challenge);
        return AuthResult(success: false, error: 'Challenge expired');
      }

      // Verify signature
      final signatureValid = await CryptoIdentity.verifyMessage(
        peerSignKey,
        {'challenge': challenge},
        signature,
      );

      if (!signatureValid) {
        return AuthResult(success: false, error: 'Invalid signature');
      }

      // Verify peer is same user
      final peerUserId = CryptoIdentity.getUserIdFromPublicKey(peerSignKey);
      if (peerUserId != identity.userId) {
        return AuthResult(success: false, error: 'Peer user ID mismatch');
      }

      // Remove challenge (one-time use)
      _activeChallenges.remove(challenge);

      // Derive shared key
      final sharedKey = await identity.deriveSharedKey(peerEncryptKey);

      return AuthResult(success: true, sharedKey: sharedKey);
    } catch (e) {
      return AuthResult(success: false, error: 'Authentication failed: $e');
    }
  }

  // Generate random challenge
  String _generateChallenge() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  // Clean up stale challenges
  void _cleanupStaleChallenges() {
    final now = DateTime.now();
    final staleChallenges = <String>[];
    
    _activeChallenges.forEach((challenge, timestamp) {
      if (now.difference(timestamp).inSeconds > 30) {
        staleChallenges.add(challenge);
      }
    });
    
    for (final challenge in staleChallenges) {
      _activeChallenges.remove(challenge);
    }
    
    if (staleChallenges.isNotEmpty) {
      print('🧹 Cleaned up ${staleChallenges.length} stale challenges');
    }
  }
}

// Authentication result
class AuthResult {
  final bool success;
  final String? error;
  final Uint8List? sharedKey;

  AuthResult({
    required this.success,
    this.error,
    this.sharedKey,
  });
}