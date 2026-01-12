import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'crypto_identity.dart';
import 'sync_client.dart';
import 'trusted_peers.dart';

class PeerDiscovery {
  static const int discoveryPort = 37520;
  static const Duration broadcastInterval = Duration(seconds: 5);
  static const Duration peerTimeout = Duration(seconds: 15);

  final String deviceId;
  final String deviceName;
  final CryptoIdentity identity;
  final int httpPort;
  
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _restartTimer;
  bool _running = false;
  bool _hasListenedToStream = false;
  bool _isStartingUp = false;
  bool _pairingMode = false;
  String? _pairingCode;
  DateTime? _pairingCodeExpiry;
  String? _previousPairingCode;
  DateTime? _previousPairingCodeExpiry;
  Timer? _pairingModeTimer;
  
  final Map<String, Peer> _peers = {};
  final StreamController<Peer> _peerDiscoveredController = StreamController<Peer>.broadcast();
  final StreamController<String> _peerLostController = StreamController<String>.broadcast();
  final StreamController<PairingInvitation> _pairingInvitationController = StreamController<PairingInvitation>.broadcast();

  PeerDiscovery({
    required this.deviceId,
    required this.deviceName,
    required this.identity,
    required this.httpPort,
  });

  Stream<Peer> get peerDiscovered => _peerDiscoveredController.stream;
  Stream<String> get peerLost => _peerLostController.stream;
  Stream<PairingInvitation> get pairingInvitations => _pairingInvitationController.stream;

  String? get pairingCode => _pairingCode;
  DateTime? get pairingCodeExpiry => _pairingCodeExpiry;
  bool get isPairingMode => _pairingMode;

  String? get previousPairingCode => _previousPairingCode;
  DateTime? get previousPairingCodeExpiry => _previousPairingCodeExpiry;

  Future<void> start() async {
    if (_running) return;

    // Stop and clean up any existing socket
    await stop();

    _isStartingUp = true;

    try {
      // Create UDP socket
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reusePort: true,
      );

      // Enable broadcast
      _socket!.broadcastEnabled = true;

      // Note: RawDatagramSocket doesn't have timeout setter in this version

      _running = true;

      // Start broadcast timer
      _broadcastTimer = Timer.periodic(broadcastInterval, (_) => _broadcast());

      // Start listen loop
      _listenLoop();

      print('🔍 Peer discovery started on port $discoveryPort');
      print('📱 Device ID: $deviceId');
      _isStartingUp = false;

    } catch (e) {
      print('❌ Failed to start peer discovery: $e');
      rethrow;
    }
  }

  Future<void> startPairingMode() async {
    if (_pairingMode) return;

    print('🔗 Starting pairing mode...');
    _pairingMode = true;
    _previousPairingCode = null;
    _previousPairingCodeExpiry = null;

    // If not already running, start discovery
    if (!_running) {
      await start();
    }

    print('🔗 Pairing mode started (code will be set by UI)');
  }

  void updatePairingCode(String code) {
    // Move current code to previous with 5-second grace period
    if (_pairingCode != null) {
      _previousPairingCode = _pairingCode;
      _previousPairingCodeExpiry = DateTime.now().add(Duration(seconds: 5));
    }

    _pairingCode = code;
    _pairingCodeExpiry = DateTime.now().add(Duration(seconds: 30));

    // Set pairing mode timer (35 seconds total: 30 for new + 5 grace for old)
    _pairingModeTimer?.cancel();
    _pairingModeTimer = Timer(Duration(seconds: 35), () {
      stopPairingMode();
    });

    // Send pairing invitation immediately
    _broadcastPairingInvitation();

    print('🔗 Pairing code updated: $_pairingCode (valid for 30s)');
    if (_previousPairingCode != null) {
      print('🔗 Previous code: $_previousPairingCode (valid for 5s grace period)');
    }
  }

  bool isPairingCodeValid(String code, {int? timestamp}) {
    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    // Check if code matches current code
    if (_pairingCode == code) {
      if (_pairingCodeExpiry != null) {
        final expiryTime = _pairingCodeExpiry!.millisecondsSinceEpoch;
        if (now <= expiryTime) {
          return true;
        }
      }
    }

    // Check if code matches previous code (grace period)
    if (_previousPairingCode == code && _previousPairingCodeExpiry != null) {
      final expiryTime = _previousPairingCodeExpiry!.millisecondsSinceEpoch;
      if (now <= expiryTime) {
        return true;
      }
    }

    return false;
  }

  Future<void> stopPairingMode() async {
    if (!_pairingMode) return;

    print('🔗 Stopping pairing mode...');

    _pairingMode = false;
    _pairingCode = null;
    _pairingCodeExpiry = null;
    _pairingModeTimer?.cancel();
    _pairingModeTimer = null;

    print('🔗 Pairing mode stopped');
  }

  Future<void> stop() async {
    if (!_running) return;

    _running = false;
    _isStartingUp = false;

    _broadcastTimer?.cancel();
    _restartTimer?.cancel();
    _socket?.close();

    _peerDiscoveredController.close();
    _peerLostController.close();
    _pairingInvitationController.close();

    print('🔍 Peer discovery stopped');
  }

  void _listenLoop() {
    if (!_running || _socket == null || _hasListenedToStream) return;

    _hasListenedToStream = true;

    _socket!.listen(
      (event) {
        switch (event) {
          case RawSocketEvent.read:
            final datagram = _socket!.receive();
            if (datagram == null) return;

            try {
              _handleIncomingPacket(datagram!);
            } catch (e) {
              print('⚠️ Error handling packet: $e');
            }
            break;
          case RawSocketEvent.write:
          case RawSocketEvent.readClosed:
          case RawSocketEvent.closed:
            _hasListenedToStream = false;
            _scheduleRestart();
            break;
          default:
            break;
        }
      },
      onError: (error) {
        if (_running) {
          print('⚠️ Socket error: $error');
        }
        _hasListenedToStream = false;
        _scheduleRestart();
      },
      onDone: () {
        if (_running) {
          print('🔍 Socket closed, restarting...');
          _hasListenedToStream = false;
          _scheduleRestart();
        }
      },
    );
  }

  void _scheduleRestart() {
    if (!_running || _isStartingUp) return;

    _isStartingUp = true;
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(seconds: 1), () {
      _isStartingUp = false;
      if (_running) start();
    });
  }

  Future<void> _broadcast() async {
    if (!_running || _socket == null) return;

    // If in pairing mode, send pairing invitations instead
    if (_pairingMode) {
      _broadcastPairingInvitation();
      return;
    }

    _broadcastDiscovery();
  }

  Future<void> _broadcastDiscovery() async {
    if (!_running || _socket == null) return;

    try {
      final payload = {
        'type': 'discovery',
        'deviceId': deviceId,
        'deviceName': deviceName,
        'httpPort': httpPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'signPublicKey': await identity.getSignPublicKeyB64(),
        'encryptPublicKey': await identity.getEncryptPublicKeyB64(),
      };

      final signature = await identity.signMessage(payload);
      final message = {
        'payload': payload,
        'signature': signature,
      };

      final messageBytes = utf8.encode(json.encode(message));

      // Broadcast to local network (use loopback for simulators)
      InternetAddress broadcastAddress;
      if (_isSimulator) {
        broadcastAddress = InternetAddress.loopbackIPv4;
        print('📱 Simulator detected, using loopback address: ${broadcastAddress.address}');
      } else {
        // Fallback to default broadcast
        broadcastAddress = InternetAddress('255.255.255.255');
        print('🌐 Using default broadcast address: ${broadcastAddress.address}');
      }

      final bytesSent = _socket!.send(messageBytes, broadcastAddress, discoveryPort);
      print('📡 Sent $bytesSent bytes to broadcast');

      // Clean up stale peers
      _cleanupStalePeers();

    } catch (e) {
      print('⚠️ Broadcast error: $e');
    }
  }

  Future<void> _broadcastPairingInvitation() async {
    if (!_running || _socket == null || !_pairingMode || _pairingCode == null) return;

    try {
      final payload = {
        'type': 'pairing_invitation',
        'deviceId': deviceId,
        'deviceName': deviceName,
        'httpPort': httpPort,
        'pairingCode': _pairingCode,
        'validUntil': _pairingCodeExpiry!.millisecondsSinceEpoch,
        'signPublicKey': await identity.getSignPublicKeyB64(),
        'encryptPublicKey': await identity.getEncryptPublicKeyB64(),
      };

      final signature = await identity.signPairingCode(_pairingCode!, payload);
      final message = {
        'payload': payload,
        'signature': signature,
      };

      final messageBytes = utf8.encode(json.encode(message));

      // Broadcast to local network
      InternetAddress broadcastAddress;
      if (_isSimulator) {
        broadcastAddress = InternetAddress.loopbackIPv4;
      } else {
        broadcastAddress = InternetAddress('255.255.255.255');
      }

      final bytesSent = _socket!.send(messageBytes, broadcastAddress, discoveryPort);
      print('🔗 Sent pairing invitation: $_pairingCode');

    } catch (e) {
      print('⚠️ Pairing invitation broadcast error: $e');
    }
  }

  Future<void> _handleIncomingPacket(Datagram datagram) async {
    try {
      print('📨 Received broadcast from: ${datagram.address.address}');

      final message = json.decode(utf8.decode(datagram.data));
      final payload = message['payload'] as Map<String, dynamic>;
      final signature = message['signature'] as String;

      final messageType = payload['type'] as String? ?? 'discovery';

      // Handle pairing invitations
      if (messageType == 'pairing_invitation') {
        _handlePairingInvitation(datagram, payload, signature);
        return;
      }

      // Regular discovery message
      _handleDiscoveryMessage(datagram, payload, signature);

    } catch (e) {
      print('⚠️ Error processing packet from ${datagram.address.address}: $e');
    }
  }

  Future<void> _handleDiscoveryMessage(
    Datagram datagram,
    Map<String, dynamic> payload,
    String signature,
  ) async {
    try {
      // Verify signature
      final signPublicKey = payload['signPublicKey'] as String;
      final signatureValid = await CryptoIdentity.verifyMessage(
        signPublicKey,
        payload,
        signature,
      );

      if (!signatureValid) {
        print('⚠️ Invalid signature from ${datagram.address.address}');
        return;
      }

      // Get peer user ID
      final peerUserId = CryptoIdentity.getUserIdFromPublicKey(signPublicKey);

      // Skip our own broadcasts
      if (payload['deviceId'] == deviceId) {
        return;
      }

      // Check if peer is trusted
      final peerDeviceId = payload['deviceId'] as String;
      final isTrusted = await TrustedPeers.instance.isTrustedDevice(peerDeviceId);

      // Skip broadcasts from different users (unless pairing mode or trusted)
      if (!_pairingMode &&
          peerUserId != identity.userId &&
          !isTrusted) {
        return;
      }

      // VALIDATE ADDRESS
      final sourceAddress = datagram.address.address;
      if (!_isValidIpAddress(sourceAddress)) {
        print('⚠️ Invalid source address: $sourceAddress, skipping peer');
        return;
      }

      final wasNew = !_peers.containsKey(peerDeviceId);

      // Update or add peer
      final peer = Peer(
        deviceId: peerDeviceId,
        deviceName: payload['deviceName'] as String,
        address: datagram.address.address,
        httpPort: payload['httpPort'] as int,
        url: 'http://${datagram.address.address}:${payload['httpPort']}',
        signPublicKey: signPublicKey,
        encryptPublicKey: payload['encryptPublicKey'] as String,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(payload['timestamp']),
      );

      _peers[peerDeviceId] = peer;

      // Update last seen for trusted peers
      if (isTrusted) {
        await TrustedPeers.instance.updateLastSeen(peerDeviceId);
        await TrustedPeers.instance.updatePeerInfo(
          peerDeviceId,
          deviceName: peer.deviceName,
        );
      }

      if (wasNew) {
        print('✨ Discovered peer: ${peer.deviceName} at ${peer.url}');
        _peerDiscoveredController.add(peer);
      }

    } catch (e) {
      print('⚠️ Error handling discovery message: $e');
    }
  }

  Future<void> _handlePairingInvitation(
    Datagram datagram,
    Map<String, dynamic> payload,
    String signature,
  ) async {
    try {
      final signPublicKey = payload['signPublicKey'] as String;
      final pairingCode = payload['pairingCode'] as String?;

      // Skip our own invitations
      if (payload['deviceId'] == deviceId) {
        return;
      }

      // Verify pairing code signature
      if (pairingCode == null) {
        return;
      }

      final signatureValid = await CryptoIdentity.verifyPairingCode(
        signPublicKey,
        pairingCode,
        payload,
        signature,
      );

      if (!signatureValid) {
        print('⚠️ Invalid pairing invitation signature');
        return;
      }

      // Check if pairing invitation has expired
      final validUntil = payload['validUntil'] as int?;
      if (validUntil != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(validUntil);
        if (DateTime.now().isAfter(expiry)) {
          print('⚠️ Expired pairing invitation from ${payload['deviceId']}');
          return;
        }
      }

      // Emit pairing invitation to stream
      final invitation = PairingInvitation(
        deviceId: payload['deviceId'] as String,
        deviceName: payload['deviceName'] as String,
        address: datagram.address.address,
        httpPort: payload['httpPort'] as int,
        pairingCode: pairingCode,
        signPublicKey: signPublicKey,
        encryptPublicKey: payload['encryptPublicKey'] as String,
        validUntil: DateTime.fromMillisecondsSinceEpoch(validUntil ?? 0),
      );

      print('🔗 Received pairing invitation from ${invitation.deviceName} (${invitation.pairingCode})');
      _pairingInvitationController.add(invitation);

    } catch (e) {
      print('⚠️ Error handling pairing invitation: $e');
    }
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    final stalePeers = <String>[];

    _peers.forEach((deviceId, peer) {
      if (now.difference(peer.lastSeen) > peerTimeout) {
        stalePeers.add(deviceId);
      }
    });

    for (final deviceId in stalePeers) {
      final peer = _peers.remove(deviceId)!;
      print('❌ Lost peer: ${peer.deviceName}');
      _peerLostController.add(deviceId);
    }
  }

  List<Peer> getPeers() {
    return _peers.values.toList();
  }

  Peer? getPeerByName(String name) {
    try {
      return _peers.values.firstWhere(
        (peer) => peer.deviceName.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  Peer? getPeerById(String deviceId) {
    return _peers[deviceId];
  }

  int get peerCount => _peers.length;

  bool get isRunning => _running;

  bool _isValidIpAddress(String address) {
    if (address == '0.0.0.0' || address.isEmpty) return false;

    final parts = address.split('.');
    if (parts.length != 4) return false;

    try {
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  bool get _isSimulator {
    if (Platform.isIOS) {
      return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
             Platform.environment.containsKey('XCODE_VERSION');
    }
    if (Platform.isAndroid) {
      return Platform.environment.containsKey('ANDROID_EMULATOR');
    }
    return false;
  }
}

// Utility class for managing device information
class DeviceInfo {
  static String getDeviceName() {
    // For now, use a simple name. In real implementation,
    // this could use device_info package to get actual device name
    return Platform.isIOS ? 'iOS Device' :
           Platform.isMacOS ? 'Mac' :
           Platform.isAndroid ? 'Android Device' :
           'Unknown Device';
  }

  static String generateDeviceId() {
    return const Uuid().v4();
  }
}

class PairingInvitation {
  final String deviceId;
  final String deviceName;
  final String address;
  final int httpPort;
  final String pairingCode;
  final String signPublicKey;
  final String encryptPublicKey;
  final DateTime validUntil;

  PairingInvitation({
    required this.deviceId,
    required this.deviceName,
    required this.address,
    required this.httpPort,
    required this.pairingCode,
    required this.signPublicKey,
    required this.encryptPublicKey,
    required this.validUntil,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'address': address,
      'httpPort': httpPort,
      'pairingCode': pairingCode,
      'signPublicKey': signPublicKey,
      'encryptPublicKey': encryptPublicKey,
      'validUntil': validUntil.toIso8601String(),
    };
  }
}