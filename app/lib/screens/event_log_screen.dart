import 'package:flutter/material.dart';

import '../models/event_log_entry.dart';
import '../database/event_log_repository.dart';

/// Displays all event log entries in reverse-chronological order.
///
/// Events are emitted by repositories on every create/update/delete.
/// This screen is read-only — it shows what happened and when.
class EventLogScreen extends StatefulWidget {
  const EventLogScreen({super.key});

  @override
  State<EventLogScreen> createState() => _EventLogScreenState();
}

class _EventLogScreenState extends State<EventLogScreen> {
  final _repo = EventLogRepository();
  List<EventLogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await _repo.getAll();
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    'No events yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return _EventTile(entry: entry);
                  },
                ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventLogEntry entry;
  const _EventTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (badgeColor, badgeLabel) = switch (entry.eventType) {
      'created' => (const Color(0xFF166534), 'created'),
      'updated' => (const Color(0xFF1E40AF), 'updated'),
      'deleted' => (const Color(0xFF991B1B), 'deleted'),
      _ => (colorScheme.outline, entry.eventType),
    };

    final preview = entry.payload['preview'] as String?;
    final name = entry.payload['name'] as String?;
    final subtitle = preview ?? name ?? '';

    // Format: "Mar 16, 3:42 PM"
    final dt = entry.dateTime;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final timeStr = '${months[dt.month - 1]} ${dt.day}, '
        '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:'
        '${dt.minute.toString().padLeft(2, '0')} '
        '${dt.hour < 12 ? 'AM' : 'PM'}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event type badge.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeLabel,
              style: theme.textTheme.labelSmall?.copyWith(color: badgeColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.entityType,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
