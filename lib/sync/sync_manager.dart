import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'crypto_identity.dart';
import 'gset.dart';
import 'event.dart';
import 'peer_discovery.dart';
import 'sync_client.dart';
import 'sync_server.dart';
import '../database_helper.dart';

enum SyncStatus { idle, discovering, syncing, success, error }

class SyncManager {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  // Core components
  late final CryptoIdentity identity;
  late final GSet gset;
  late final PeerDiscovery discovery;
  late final SyncClient client;
  late final SyncServer server;

  // Device information
  late final String deviceId;
  late final String deviceName;
  late final int httpPort;

  // State management
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final Queue<Event> _pendingEvents = Queue<Event>();

  Timer? _syncTimer;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isBackgroundSyncEnabled = true;
  SyncStatus _currentStatus = SyncStatus.idle;
  SyncStatus _initializationError = SyncStatus.idle;
  String? _initializationErrorMessage;

  // Configuration
  static const Duration syncInterval = Duration(seconds: 30);
  static const int defaultHttpPort = 8080;

  // Getters
  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<String> get logStream => _logController.stream;
  SyncStatus get currentStatus => _currentStatus;
  List<Peer> get peers => discovery.getPeers();
  int get pendingEventCount => _pendingEvents.length;
  bool get isBackgroundSyncEnabled => _isBackgroundSyncEnabled;
  bool get isInitializing => _isInitializing;
  bool get hasInitializationError => _initializationError == SyncStatus.error;
  String? get initializationError => _initializationErrorMessage;

  Map<String, dynamic> getSyncInfo() {
    return {
      'deviceId': deviceId,
      'userId': identity.userId,
      'deviceName': deviceName,
      'httpPort': httpPort,
      'isInitialized': _isInitialized,
      'isInitializing': _isInitializing,
      'hasInitializationError': hasInitializationError,
      'initializationError': _initializationError,
      'peerCount': discovery.peerCount,
      'peers': discovery
          .getPeers()
          .map(
            (p) => {
              'deviceId': p.deviceId,
              'deviceName': p.deviceName,
              'address': p.address,
              'url': p.url,
              'lastSeen': p.lastSeen.toIso8601String(),
            },
          )
          .toList(),
      'eventCount': gset.size,
      'pendingEventCount': pendingEventCount,
      'isBackgroundSyncEnabled': _isBackgroundSyncEnabled,
      'isSimulator': Platform.isIOS
          ? Platform.environment.containsKey('SIMULATOR_DEVICE_NAME')
          : false,
    };
  }

  Future<void> initialize({int? port}) async {
    if (_isInitialized || _isInitializing) {
      print('⚠️ SyncManager already initializing or initialized');
      return;
    }

    _isInitializing = true;
    _initializationError = SyncStatus.idle;
    _initializationErrorMessage = null;

    try {
      _log('🚀 Initializing SyncManager...');
      _updateStatus(SyncStatus.discovering);

      // Initialize components
      deviceId = DeviceInfo.generateDeviceId();
      deviceName = DeviceInfo.getDeviceName();
      httpPort = port ?? defaultHttpPort;
      _log('📱 Device ID: $deviceId');
      _log('💻 Device name: $deviceName');
      _log('🌐 HTTP port: $httpPort');

      // Initialize cryptographic identity
      _log('🔑 Loading or creating cryptographic identity...');
      identity = await CryptoIdentity.loadOrCreate();
      _log('👤 User ID: ${identity.userId}');

      // Load G-Set from database
      _log('📚 Loading events from database...');
      gset = await DatabaseHelper.instance.loadGSet();
      _log('📊 Loaded ${gset.size} events from database');

      // Initialize peer discovery
      _log('🔍 Initializing peer discovery...');
      discovery = PeerDiscovery(
        deviceId: deviceId,
        deviceName: deviceName,
        identity: identity,
        httpPort: httpPort,
      );

      // Initialize sync client
      client = SyncClient(identity: identity);

      // Initialize sync server
      _log('🌐 Starting sync server...');
      server = SyncServer(identity: identity, gset: gset, port: httpPort);

      // Start services
      await server.start();
      _log('✅ Sync server started on port $httpPort');

      await discovery.start();
      _log('✅ Peer discovery started');

      // Set up peer discovery listeners
      discovery.peerDiscovered.listen(_onPeerDiscovered);
      discovery.peerLost.listen(_onPeerLost);

       // Start background sync
      if (_isBackgroundSyncEnabled) {
        startBackgroundSync();
      }

      _isInitialized = true;
      _isInitializing = false;
      _updateStatus(SyncStatus.idle);
      _log('✅ SyncManager initialized successfully');
      _log('📱 Device: $deviceName ($deviceId)');
      _log('🌐 Server: http://localhost:$httpPort');
    } catch (e) {
      _isInitializing = false;
      _isInitialized = false;
      _initializationError = SyncStatus.error;
      _initializationErrorMessage = e.toString();
      _log('❌ Failed to initialize SyncManager: $e');
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  Future<void> shutdown() async {
    if (!_isInitialized) return;

    _log('🛑 Shutting down SyncManager...');

    stopBackgroundSync();
    await discovery.stop();
    await server.stop();

    _statusController.close();
    _logController.close();

    _isInitialized = false;
    _log('✅ SyncManager shut down');
  }

  void startBackgroundSync() {
    if (_syncTimer?.isActive == true) return;

    _syncTimer = Timer.periodic(syncInterval, (_) {
      if (_isBackgroundSyncEnabled && _isInitialized) {
        performSync();
      }
    });

    _log('🔄 Background sync started (interval: ${syncInterval.inSeconds}s)');
  }

  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _log('⏹️ Background sync stopped');
  }

  void setBackgroundSyncEnabled(bool enabled) {
    _isBackgroundSyncEnabled = enabled;
    if (enabled) {
      startBackgroundSync();
    } else {
      stopBackgroundSync();
    }
    _log('🔧 Background sync ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<void> performSync() async {
    if (_isInitializing) {
      _log('⏳ SyncManager is still initializing, please wait...');
      return;
    }

    if (_initializationError == SyncStatus.error) {
      _log('❌ SyncManager initialization failed: $_initializationErrorMessage');
      _updateStatus(SyncStatus.error);
      return;
    }

    if (!_isInitialized) {
      _log('⚠️ SyncManager not initialized');
      _updateStatus(SyncStatus.error);
      return;
    }

    if (discovery.peerCount == 0) {
      _log('📡 No peers discovered, skipping sync');
      return;
    }

    _updateStatus(SyncStatus.syncing);
    _log('🔄 Starting sync with ${discovery.peerCount} peers...');

    try {
      final peers = discovery.getPeers();
      int totalPulled = 0;
      int totalPushed = 0;
      int successCount = 0;

      for (final peer in peers) {
        try {
          _log('🔄 Syncing with ${peer.deviceName}...');

          final result = await client.syncWithPeer(peer, gset);

          if (result.success) {
            successCount++;
            totalPulled += result.pulled ?? 0;
            totalPushed += result.pushed ?? 0;

            // Merge pulled events into our G-Set
            if (result.events != null && result.events!.isNotEmpty) {
              final added = gset.merge(result.events!);
              _log('📥 Merged $added new events from ${peer.deviceName}');

              // Save to database
              await DatabaseHelper.instance.mergeEvents(result.events!);
            }
          } else {
            _log('❌ Sync failed with ${peer.deviceName}: ${result.error}');
          }
        } catch (e) {
          _log('❌ Exception syncing with ${peer.deviceName}: $e');
        }
      }

      _updateStatus(SyncStatus.success);
      _log('✅ Sync completed: $successCount/${peers.length} peers successful');
      _log('📊 Stats: +$totalPulled events, -$totalPushed events');

      // Process pending events
      await _processPendingEvents();
    } catch (e) {
      _updateStatus(SyncStatus.error);
      _log('❌ Sync failed: $e');
    } finally {
      // Return to idle after a delay
      Timer(Duration(seconds: 3), () {
        if (_currentStatus == SyncStatus.success ||
            _currentStatus == SyncStatus.error) {
          _updateStatus(SyncStatus.idle);
        }
      });
    }
  }

  Future<void> queueEvent(Event event) async {
    _pendingEvents.add(event);
    gset.add(event);

    _log('📝 Queued event: ${event.type.name} for ${event.noteId}');

    // Trigger immediate sync attempt
    Timer(Duration(milliseconds: 500), () {
      if (_isInitialized) {
        performSync();
      }
    });
  }

  Future<void> _processPendingEvents() async {
    if (_pendingEvents.isEmpty) return;

    _log('📋 Processing ${_pendingEvents.length} pending events...');

    while (_pendingEvents.isNotEmpty) {
      final event = _pendingEvents.removeFirst();
      // Events are already added to G-Set and database when queued
    }

    _log('✅ Processed all pending events');
  }

  void _onPeerDiscovered(Peer peer) {
    _log('👤 Peer discovered: ${peer.deviceName} at ${peer.url}');
  }

  void _onPeerLost(String deviceId) {
    _log('👤 Peer lost: $deviceId');
  }

  Future<void> syncWithPeerByName(String name) async {
    final peer = discovery.getPeerByName(name);
    if (peer == null) {
      _log('❌ Peer not found: $name');
      return;
    }

    _log('🔄 Manual sync with ${peer.deviceName}...');
    _updateStatus(SyncStatus.syncing);

    try {
      final result = await client.syncWithPeer(peer, gset);

      if (result.success) {
        _updateStatus(SyncStatus.success);
        _log('✅ Manual sync completed with ${peer.deviceName}');

        // Merge events
        if (result.events != null && result.events!.isNotEmpty) {
          await DatabaseHelper.instance.mergeEvents(result.events!);
        }
      } else {
        _updateStatus(SyncStatus.error);
        _log('❌ Manual sync failed: ${result.error}');
      }
    } catch (e) {
      _updateStatus(SyncStatus.error);
      _log('❌ Manual sync exception: $e');
    }
  }

  Future<void> syncWithAllPeers() async {
    await performSync();
  }

  Future<Map<String, dynamic>> getSyncStats() async {
    return {
      'isInitialized': _isInitialized,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'httpPort': httpPort,
      'userId': identity.userId,
      'eventCount': gset.size,
      'peerCount': discovery.peerCount,
      'pendingEventCount': _pendingEvents.length,
      'backgroundSyncEnabled': _isBackgroundSyncEnabled,
      'currentStatus': _currentStatus.name,
      'peers': discovery.getPeers().map((p) => p.toJson()).toList(),
    };
  }

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logController.add(logMessage);
    print(logMessage); // Also print to console
  }

  // Utility methods for testing
  Future<void> clearAllData() async {
    if (!_isInitialized) return;

    _log('🗑️ Clearing all sync data...');

    gset.clear();
    _pendingEvents.clear();

    // Clear database (be careful with this in production!)
    // await DatabaseHelper.instance.clearAllEvents();

    _log('✅ All sync data cleared');
  }

  Future<void> createTestEvent() async {
    if (!_isInitialized) return;

    final testEvent = Event.create(
      noteId: 'test-${const Uuid().v4()}',
      content: 'Test event created at ${DateTime.now()}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await queueEvent(testEvent);
    _log('🧪 Created test event');
  }
}
