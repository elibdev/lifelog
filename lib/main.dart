import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'sync/sync_manager.dart';
import 'sync/event.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  

  // Initialize sync manager
  try {
    await SyncManager.instance.initialize();
  } catch (e) {
    print('Failed to initialize sync: $e');
    // Continue without sync if initialization fails
  }

  runApp(
    const MaterialApp(home: JournalHome(), debugShowCheckedModeBanner: false),
  );
}

class SyncStatusIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncManager.instance.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.idle;

        Color color;
        double size;

        switch (status) {
          case SyncStatus.idle:
            color = Colors.grey.shade400;
            size = 6;
            break;
          case SyncStatus.discovering:
            color = Colors.blue.shade300;
            size = 8;
            break;
          case SyncStatus.syncing:
            color = Colors.orange;
            size = 8;
            break;
          case SyncStatus.success:
            color = Colors.green;
            size = 6;
            break;
          case SyncStatus.error:
            color = Colors.red;
            size = 8;
            break;
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      },
    );
  }
}

void _showSyncInfo(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sync Information'),
      content: FutureBuilder<Map<String, dynamic>>(
        future: SyncManager.instance.getSyncStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }

          final stats = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device: ${stats['deviceName']}'),
              Text('User ID: ${stats['userId']}'),
              const SizedBox(height: 8),
              Text('Events: ${stats['eventCount']}'),
              Text('Peers: ${stats['peerCount']}'),
              Text('Pending: ${stats['pendingEventCount']}'),
              const SizedBox(height: 8),
              Text('Status: ${stats['currentStatus']}'),
              Text(
                'Background Sync: ${stats['backgroundSyncEnabled'] ? "On" : "Off"}',
              ),
              if (stats['peers'].isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Peers:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...stats['peers'].map<Widget>(
                  (peer) =>
                      Text('• ${peer['deviceName']} (${peer['address']})'),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            SyncManager.instance.performSync();
            Navigator.of(context).pop();
          },
          child: const Text('Sync Now'),
        ),
      ],
    ),
  );
}

class JournalHome extends StatefulWidget {
  const JournalHome({super.key});

  @override
  State<StatefulWidget> createState() {
    return _JournalHomeState();
  }
}

class _JournalHomeState extends State<JournalHome> {
  void _showSyncInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Information'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: SyncManager.instance.getSyncStats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }

            final stats = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device: ${stats['deviceName']}'),
                Text('User ID: ${stats['userId']}'),
                const SizedBox(height: 8),
                Text('Events: ${stats['eventCount']}'),
                Text('Peers: ${stats['peerCount']}'),
                Text('Pending: ${stats['pendingEventCount']}'),
                const SizedBox(height: 8),
                Text('Status: ${stats['currentStatus']}'),
                Text(
                  'Background Sync: ${stats['backgroundSyncEnabled'] ? "On" : "Off"}',
                ),
                if (stats['peers'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Peers:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...stats['peers'].map<Widget>(
                    (peer) =>
                        Text('• ${peer['deviceName']} (${peer['address']})'),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              SyncManager.instance.performSync();
              Navigator.of(context).pop();
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This key is crucial. It tells the ScrollView where "0" is.
    final Key centerKey = const ValueKey('bottom-sliver');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("lifelog"),
            const SizedBox(width: 8),
            SyncStatusIndicator(),
          ],
        ),
        // backgroundColor: Colors.white,
        // foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () async {
              await SyncManager.instance.performSync();
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showSyncInfo(context),
          ),
        ],
      ),
      // backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        center: centerKey, // The scroll view anchors to the 'Future' list
        slivers: [
          // 1. THE PAST (Scrolls UP from center)
          // Index 0 here is Yesterday, Index 1 is Day Before, etc.
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              // Logic: Today - (index + 1) days
              final date = DateTime.now().subtract(Duration(days: index + 1));
              return JournalEntryCard(date: date);
            }),
          ),

          // 2. THE FUTURE + TODAY (Scrolls DOWN from center)
          // Index 0 here is Today, Index 1 is Tomorrow, etc.
          SliverList(
            key: centerKey, // This matches the 'center' property above
            delegate: SliverChildBuilderDelegate((context, index) {
              // Logic: Today + index days
              final date = DateTime.now().add(Duration(days: index));
              return JournalEntryCard(date: date);
            }),
          ),
        ],
      ),
    );
  }
}

class JournalEntryCard extends StatefulWidget {
  final DateTime date;

  const JournalEntryCard({super.key, required this.date});

  @override
  State<JournalEntryCard> createState() => _JournalEntryCardState();
}

class _JournalEntryCardState extends State<JournalEntryCard> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String get _dbKey => DateFormat('yyyy-MM-dd').format(widget.date);

  // Helper to determine if this card is Today, Future, or Past for styling
  bool get _isToday {
    final now = DateTime.now();
    return now.year == widget.date.year &&
        now.month == widget.date.month &&
        now.day == widget.date.day;
  }

  bool get _isFuture {
    final now = DateTime.now();
    // Normalize to start of day for comparison
    final todayStart = DateTime(now.year, now.month, now.day);
    final dateStart = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    return dateStart.isAfter(todayStart);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final content = await DatabaseHelper.instance.getEntry(_dbKey);
    if (mounted && content != null) {
      _controller.text = content;
    }
  }

  void _onTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _saveData(text);
    });
  }

  Future<void> _saveData(String content) async {
    // Use sync-aware save method
    await DatabaseHelper.instance.saveEntryWithEvent(_dbKey, content);
  }

  @override
  Widget build(BuildContext context) {
    // Style logic
    final isToday = _isToday;
    final isFuture = _isFuture;

    Color headerColor;
    if (isToday) {
      headerColor = Colors.blue.shade700;
    } else if (isFuture) {
      headerColor = Colors.purple.shade300;
    } else {
      headerColor = Colors.grey.shade600;
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600), // Nice on tablets
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: isToday
              ? Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Text(
                        DateFormat('MMM d, yyy').format(widget.date),
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        DateFormat('EEE').format(widget.date),
                        style: TextStyle(
                          color: headerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "TODAY",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Input Area
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _controller,
                maxLines: null,
                minLines: 1,
                style: const TextStyle(fontSize: 12, height: 1.5),
                decoration: InputDecoration(
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                ),
                onChanged: _onTextChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
