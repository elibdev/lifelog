import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/block.dart';
import '../notifications/navigation_notifications.dart';
import 'blocks/adaptive_block_widget.dart';

/// Manages a flat list of mixed-type blocks for a single day.
///
/// Replaces the old two-RecordSection-per-day pattern (one for todos, one for notes)
/// with a single section that can contain blocks of any type interleaved.
/// This simplifies navigation (one section per day instead of two) and allows
/// flexible block ordering.
///
/// Key behaviors:
/// - Maintains a focus node registry for keyboard navigation
/// - Provides a placeholder block at the end (default: text)
/// - Handles Enter key to insert new blocks
/// - Dispatches navigation notifications at section boundaries
class BlockSection extends StatefulWidget {
  final List<Block> blocks;
  final String date;
  final Function(Block) onSave;
  final Function(String) onDelete;

  const BlockSection({
    super.key,
    required this.blocks,
    required this.date,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<BlockSection> createState() => BlockSectionState();
}

/// Public state class so JournalScreen can call focusFirstBlock/focusLastBlock
/// via GlobalKey for cross-day navigation.
class BlockSectionState extends State<BlockSection> {
  late String _placeholderId;

  // Focus node tracking: blockId -> FocusNode
  final Map<String, FocusNode> _focusNodes = {};

  /// Focus the first block in this section (called by JournalScreen via GlobalKey)
  void focusFirstBlock() {
    _tryFocusBlockAt(0);
  }

  /// Focus the last block (or placeholder) in this section
  void focusLastBlock() {
    final allIds = [...widget.blocks.map((b) => b.id), _placeholderId];
    _tryFocusBlockAt(allIds.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _placeholderId = const Uuid().v4();
  }

  @override
  void dispose() {
    _focusNodes.clear();
    super.dispose();
  }

  void _handleFocusNodeCreated(int index, String blockId, FocusNode node) {
    _focusNodes[blockId] = node;
  }

  void _handleFocusNodeDisposed(String blockId) {
    _focusNodes.remove(blockId);
  }

  bool _tryFocusBlockAt(int index) {
    final allIds = [...widget.blocks.map((b) => b.id), _placeholderId];
    if (index < 0 || index >= allIds.length) return false;

    final blockId = allIds[index];
    final focusNode = _focusNodes[blockId];
    if (focusNode != null) {
      focusNode.requestFocus();
      return true;
    }
    return false;
  }

  double _calculateAppendPosition() {
    if (widget.blocks.isEmpty) return 1.0;
    final maxPosition = widget.blocks
        .map((b) => b.orderPosition)
        .reduce((a, b) => a > b ? a : b);
    return maxPosition + 1.0;
  }

  void _handlePlaceholderSave(Block placeholder) {
    widget.onSave(placeholder);
    setState(() {
      _placeholderId = const Uuid().v4();
    });
  }

  void _handleEnterPressed(String fromBlockId) {
    final currentIndex = widget.blocks.indexWhere((b) => b.id == fromBlockId);

    final double newPosition;
    if (currentIndex == -1) {
      newPosition = _calculateAppendPosition();
    } else if (currentIndex == widget.blocks.length - 1) {
      final currentPos = widget.blocks[currentIndex].orderPosition;
      final placeholderPos = _calculateAppendPosition();
      newPosition = (currentPos + placeholderPos) / 2;
    } else {
      final currentPos = widget.blocks[currentIndex].orderPosition;
      final nextPos = widget.blocks[currentIndex + 1].orderPosition;
      newPosition = (currentPos + nextPos) / 2;
    }

    final uuid = const Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = uuid.v4();

    // New blocks default to text type
    final newBlock = Block(
      id: newId,
      date: widget.date,
      type: BlockType.text,
      content: '',
      metadata: {},
      orderPosition: newPosition,
      createdAt: now,
      updatedAt: now,
    );

    widget.onSave(newBlock);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[newId]?.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final placeholderPosition = _calculateAppendPosition();

    final placeholder = Block(
      id: _placeholderId,
      date: widget.date,
      type: BlockType.text,
      content: '',
      metadata: {},
      orderPosition: placeholderPosition,
      createdAt: now,
      updatedAt: now,
    );

    // Notification listeners for keyboard navigation bubbling
    return NotificationListener<NavigateDownNotification>(
      onNotification: (notification) {
        final nextIndex = notification.recordIndex + 1;
        return _tryFocusBlockAt(nextIndex);
      },
      child: NotificationListener<NavigateUpNotification>(
        onNotification: (notification) {
          final prevIndex = notification.recordIndex - 1;
          return _tryFocusBlockAt(prevIndex);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Existing blocks
            ...widget.blocks.asMap().entries.map((entry) {
              final index = entry.key;
              final block = entry.value;
              return AdaptiveBlockWidget(
                key: ValueKey(block.id),
                block: block,
                onSave: widget.onSave,
                onDelete: widget.onDelete,
                onSubmitted: _handleEnterPressed,
                blockIndex: index,
                onFocusNodeCreated: _handleFocusNodeCreated,
                onFocusNodeDisposed: _handleFocusNodeDisposed,
              );
            }),
            // Placeholder
            AdaptiveBlockWidget(
              key: ValueKey(_placeholderId),
              block: placeholder,
              onSave: _handlePlaceholderSave,
              onDelete: (_) {},
              onSubmitted: _handleEnterPressed,
              blockIndex: widget.blocks.length,
              onFocusNodeCreated: _handleFocusNodeCreated,
              onFocusNodeDisposed: _handleFocusNodeDisposed,
            ),
          ],
        ),
      ),
    );
  }
}
