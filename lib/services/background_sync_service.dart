import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../sync/sync_manager.dart';

class BackgroundSyncService {
  static const String channelId = 'lifelog_sync_channel';
  static const String channelName = 'Lifelog Sync';
  static const String channelDescription =
      'Background synchronization for Lifelog app';

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configure for Android
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'Lifelog Sync',
        initialNotificationContent: 'Background sync is active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Start the service
    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // This is required for iOS background execution
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize sync manager
    await SyncManager.instance.initialize();

    // Listen for sync commands
    service.on('sync').listen((event) {
      _performSync(service);
    });

    // Set up periodic sync
    Timer.periodic(Duration(seconds: 30), (timer) async {
      if (SyncManager.instance.isBackgroundSyncEnabled) {
        await _performSync(service);
      }
    });

    // Handle stop event
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  static Future<void> _performSync(ServiceInstance service) async {
    try {
      // Update notification to show syncing
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Lifelog Sync",
          content: "Syncing with peers...",
        );
      }

      // Perform sync
      await SyncManager.instance.performSync();

      // Update notification to show success
      if (service is AndroidServiceInstance) {
        final peerCount = SyncManager.instance.peers.length;
        service.setForegroundNotificationInfo(
          title: "Lifelog Sync",
          content: "Sync completed. $peerCount peers connected.",
        );
      }
    } catch (e) {
      // Update notification to show error
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Lifelog Sync",
          content: "Sync failed: ${e.toString()}",
        );
      }
    }
  }

  static Future<void> startSync() async {
    final service = FlutterBackgroundService();
    service.invoke('sync');
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> isRunning() async {
    return await FlutterBackgroundService().isRunning();
  }

  static void updateNotification(String title, String content) {
    final service = FlutterBackgroundService();
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: title, content: content);
    }
  }
}

// Helper class for managing background sync notifications
class SyncNotificationManager {
  static void showSyncNotification(String status) {
    BackgroundSyncService.updateNotification('Lifelog Sync', status);
  }

  static void showSyncComplete(int peerCount) {
    BackgroundSyncService.updateNotification(
      'Lifelog Sync',
      'Sync completed. $peerCount peers connected.',
    );
  }

  static void showSyncError(String error) {
    BackgroundSyncService.updateNotification(
      'Lifelog Sync Error',
      'Sync failed: $error',
    );
  }
}
