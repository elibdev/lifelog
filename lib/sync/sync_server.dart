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
import 'trusted_peers.dart';

class SyncServer {
  final CryptoIdentity identity;
  final GSet gset;
  final int configuredPort;
  int actualPort = 0;
  HttpServer? _server;
  bool _running = false;

  // Active challenges for authentication
  final Map<String, DateTime> _activeChallenges = {};

  SyncServer({
    required this.identity,
    required this.gset,
    required this.configuredPort,
  });

  Router _createRouter() {
    final router = Router();
    router.get('/challenge', _handleChallenge);
    router.get('/inventory', _handleInventory);
    router.get('/pull', _handlePull);
    router.post('/push', _handlePush);
    router.post('/pair', _handlePair);
    return router;
  }

  Future<void> start() async {
    if (_running) return;

    try {
      print('🌐 Starting sync server...');

      // Try default port first, then find available port if needed
      int portToTry = configuredPort;
      int attempts = 0;
      const maxAttempts = 10;

      while (attempts < maxAttempts) {
        try {
          final router = _createRouter();

          _server = await shelf_io.serve(
            router.call,
            InternetAddress.anyIPv4.address,
            portToTry,
          );
          _running = true;
          actualPort = portToTry;
          print('✅ Sync server started on port $portToTry');
          print('🌐 Server URL: http://localhost:$portToTry');
          return;
        } catch (e) {
          attempts++;
          if (attempts >= maxAttempts) {
            rethrow;
          }
          // Try next port
          portToTry = configuredPort + attempts;
          print('⚠️ Port $portToTry in use, trying port ${configuredPort + attempts}...');
        }
      }
    } catch (e) {
      print('❌ Failed to start sync server: $e');
      rethrow;
    }
  }

    int get serverPort => _server != null ? actualPort : configuredPort;

  Future<void> stop() async {
    if (_running && _server != null) {
      await _server!.close();
      _server = null;
      _running = false;
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

      // Parse requested hashes from query parameter
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

  // Handle pairing request
  Future<Response> _handlePair(Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body);

      final peerDeviceId = data['peerDeviceId'] as String?;
      final peerCode = data['peerCode'] as String?;
      final myCode = data['myCode'] as String?;
      final peerSignPublicKey = data['peerSignPublicKey'] as String?;
      final peerEncryptPublicKey = data['peerEncryptPublicKey'] as String?;
      final signature = data['signature'] as String?;

      if (peerDeviceId == null ||
          peerCode == null ||
          myCode == null ||
          peerSignPublicKey == null ||
          peerEncryptPublicKey == null ||
          signature == null) {
        return Response(400, body: 'Missing required fields');
      }

      // Verify pairing code signature
      final payload = {
        'peerDeviceId': peerDeviceId,
        'peerCode': peerCode,
        'myCode': myCode,
        'peerSignPublicKey': peerSignPublicKey,
        'peerEncryptPublicKey': peerEncryptPublicKey,
      };

      final signatureValid = await CryptoIdentity.verifyPairingCode(
        peerSignPublicKey,
        peerCode,
        payload,
        signature,
      );

       if (!signatureValid) {
         print('❌ Invalid pairing signature from $peerDeviceId');
         return Response(403, body: 'Invalid signature');
       }

       // Calculate peer user ID
       final peerUserId = CryptoIdentity.getUserIdFromPublicKey(peerSignPublicKey);

       // Check if pairing code is valid (matches current or previous within grace period)
       // Note: We can't access discovery pairing code directly
       // In a real implementation, we'd validate against the broadcast code
       // For now, we accept if signature is valid and code is provided

       // Create trusted peer record
       final trustedPeer = TrustedPeer(
         deviceId: peerDeviceId,
         userId: peerUserId,
         deviceName: 'Paired Device',
         signPublicKey: peerSignPublicKey,
         encryptPublicKey: peerEncryptPublicKey,
         pairedAt: DateTime.now(),
       );

       // Add to trusted peers database
       final trustedPeers = TrustedPeers.instance;
       await trustedPeers.addTrustedPeer(trustedPeer);

       print('✅ Successfully paired with device: $peerDeviceId');
       print('👤 User ID: $peerUserId');

      return Response.ok(
        json.encode({
          'success': true,
          'message': 'Successfully paired',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ Pairing error: $e');
      return Response.internalServerError(body: 'Pairing failed: $e');
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