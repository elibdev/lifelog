import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'crypto_identity.dart';
import 'sync_client.dart';

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
  bool _running = false;
  bool _hasListenedToStream = false;
  
  final Map<String, Peer> _peers = {};
  final StreamController<Peer> _peerDiscoveredController = StreamController<Peer>.broadcast();
  final StreamController<String> _peerLostController = StreamController<String>.broadcast();

  PeerDiscovery({
    required this.deviceId,
    required this.deviceName,
    required this.identity,
    required this.httpPort,
  });

  Stream<Peer> get peerDiscovered => _peerDiscoveredController.stream;
  Stream<String> get peerLost => _peerLostController.stream;

  Future<void> start() async {
    if (_running) return;

    try {
      // Create UDP socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      
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
      
    } catch (e) {
      print('❌ Failed to start peer discovery: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_running) return;

    _running = false;
    
    _broadcastTimer?.cancel();
    _socket?.close();
    
    _peerDiscoveredController.close();
    _peerLostController.close();
    
    print('🔍 Peer discovery stopped');
  }

  void _listenLoop() {
    if (!_running || _socket == null) return;
    if (_hasListenedToStream) return;

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
      },
      onDone: () {
        if (_running) {
          print('🔍 Socket closed, restarting...');
          _hasListenedToStream = false;
          Future.delayed(Duration(seconds: 1), () {
            if (_running) start();
          });
        }
      },
    );

    // Schedule next listen iteration
    Future.delayed(Duration(milliseconds: 100), () {
      if (_running) _listenLoop();
    });
  }

  Future<void> _broadcast() async {
    if (!_running || _socket == null) return;

    try {
      final payload = {
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
        print('📱 Simulator detected, using loopback address');
      } else {
        // Fallback to default broadcast
        broadcastAddress = InternetAddress('255.255.255.255');
        print('🌐 Using default broadcast address');
      }

      _socket!.send(messageBytes, broadcastAddress, discoveryPort);
      
      // Clean up stale peers
      _cleanupStalePeers();
      
    } catch (e) {
      print('⚠️ Broadcast error: $e');
    }
  }

  Future<void> _handleIncomingPacket(Datagram datagram) async {
    try {
      print('📨 Received broadcast from: ${datagram.address.address}');

          final message = json.decode(utf8.decode(datagram.data));
          final payload = message['payload'] as Map<String, dynamic>;
          final signature = message['signature'] as String;

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

    // Skip broadcasts from different users
    if (peerUserId != identity.userId) {
      return;
    }

    // VALIDATE ADDRESS
    final sourceAddress = datagram.address.address;
    if (!_isValidIpAddress(sourceAddress)) {
      print('⚠️ Invalid source address: $sourceAddress, skipping peer');
      return;
    }

    final peerDeviceId = payload['deviceId'] as String;
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

      if (wasNew) {
        print('✨ Discovered peer: ${peer.deviceName} at ${peer.url}');
        _peerDiscoveredController.add(peer);
      }

} catch (e) {
          print('⚠️ Error processing packet from ${datagram.address.address}: $e');
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