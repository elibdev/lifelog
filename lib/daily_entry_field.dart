import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/journal_state_registry.dart';
import 'state/daily_state_manager.dart';
import 'renderers/record_renderer_registry.dart';
import 'renderers/record_renderer.dart';
import 'focus_manager.dart';

class DailyEntryField extends StatefulWidget {
  final DateTime date;
  const DailyEntryField({super.key, required this.date});

  @override
  State<DailyEntryField> createState() => _DailyEntryFieldState();
}

class _DailyEntryFieldState extends State<DailyEntryField>
    with AutomaticKeepAliveClientMixin {
  late DailyStateManager _stateManager;
  TextEditingController? _ephemeralController;
  Timer? _ephemeralDebounce;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    final registry = context.read<JournalStateRegistry>();
    _stateManager = registry.getOrCreateManager(widget.date);
  }

  void _ensureLoaded() {
    if (!_hasLoaded) {
      _hasLoaded = true;
      // Load asynchronously after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stateManager.load();
      });
    }
  }

  @override
  void dispose() {
    _ephemeralDebounce?.cancel();
    _ephemeralController?.dispose();
    super.dispose();
  }

  void _onEphemeralTextChanged(String text) {
    if (text.isEmpty) return;

    // First keystroke creates the record
    if (_ephemeralDebounce?.isActive ?? false) _ephemeralDebounce!.cancel();
    _ephemeralDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (text.isNotEmpty) {
        await _stateManager.createRecord('note', 1.0, {'content': text});
        if (mounted) {
          setState(() {
            _ephemeralController?.dispose();
            _ephemeralController = null;
          });
        }
      }
    });
  }

  RecordActions _buildActions() {
    return RecordActions(
      updateMetadata: (recordId, changes) async {
        await _stateManager.updateMetadata(recordId, changes);
      },
      deleteRecord: (recordId) async {
        await _stateManager.deleteRecord(recordId);
      },
      reorderRecord: (recordId, newPosition) async {
        await _stateManager.reorderRecord(recordId, newPosition);
      },
      createNewRecordAfter: (recordType, position, metadata) async {
        return await _stateManager.createRecord(recordType, position, metadata);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Trigger load on first build (lazy loading)
    _ensureLoaded();

    final rendererRegistry = context.read<RecordRendererRegistry>();
    final actions = _buildActions();

    return ChangeNotifierProvider<DailyStateManager>.value(
      value: _stateManager,
      child: Consumer<DailyStateManager>(
        builder: (context, manager, child) {
          final state = manager.state;

          // Don't show spinners - just show empty field while loading
          final records = state.sortedRecords;

          // Update focus manager with current record order
          if (records.isNotEmpty) {
            final focusManager = context.read<JournalFocusManager>();
            final recordIds = records.map((r) => r.id).toList();
            focusManager.updateDateOrder(widget.date, recordIds);
          }

          if (records.isEmpty) {
            // Show ephemeral empty note field (even while loading)
            _ephemeralController ??= TextEditingController();

            return Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bullet point
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, right: 8.0),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B7355),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Note content
                  Expanded(
                    child: TextField(
                      controller: _ephemeralController,
                      onChanged: _onEphemeralTextChanged,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Render all records
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: records.map((record) {
              return rendererRegistry.buildRecord(
                context,
                record,
                actions,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
