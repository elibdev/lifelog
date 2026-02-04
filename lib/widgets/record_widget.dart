import 'package:flutter/material.dart';
import '../models/record.dart';
import '../services/keyboard_service.dart';
import '../constants/grid_constants.dart';

class RecordWidget extends StatefulWidget {
  final Record record;
  final Function(Record) onSave;
  final Function(String) onDelete;
  final Function(String)?
      onSubmitted; // Called when user presses Enter, passes record ID

  // FOCUS NODE LIFECYCLE CALLBACKS
  // RecordSection needs to track FocusNodes so it can call requestFocus() during navigation
  final int? recordIndex; // Position in parent's list (needed for tracking)
  final void Function(int index, String recordId, FocusNode node)?
      onFocusNodeCreated;
  final void Function(String recordId)? onFocusNodeDisposed;

  const RecordWidget({
    super.key,
    required this.record,
    required this.onSave,
    required this.onDelete,
    this.onSubmitted,
    // Focus node lifecycle callbacks - optional
    this.recordIndex,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  });

  @override
  State<RecordWidget> createState() => _RecordWidgetState();
}

class _RecordWidgetState extends State<RecordWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.record.content);
    _setupFocusNode();
  }

  // FOCUS LIFECYCLE: Setup
  void _setupFocusNode() {
    // Create FocusNode
    _focusNode = FocusNode();

    // Register with parent if callback provided (for custom focus registry)
    widget.onFocusNodeCreated?.call(
      widget.recordIndex ?? -1,
      widget.record.id,
      _focusNode,
    );

    // Attach focus change listener (deletes empty records on blur)
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    // No rebuild needed - TextField handles its own focus styling
    // Removing setState prevents interference with keyboard dismiss animation

    // When focus is lost, delete if content is empty/whitespace
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onDelete(widget.record.id);
    }
  }

  @override
  void didUpdateWidget(RecordWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the record ID changed, update the controller
    if (widget.record.id != oldWidget.record.id) {
      _controller.text = widget.record.content;
    }
    // If content changed externally, update controller
    else if (widget.record.content != oldWidget.record.content &&
        widget.record.content != _controller.text) {
      _controller.text = widget.record.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _teardownFocusNode();
    super.dispose();
  }

  // FOCUS LIFECYCLE: Cleanup
  void _teardownFocusNode() {
    // Remove listener first (good practice before disposal)
    _focusNode.removeListener(_handleFocusChange);

    // Unregister from parent if callback provided
    widget.onFocusNodeDisposed?.call(widget.record.id);

    // Dispose FocusNode to prevent memory leaks
    _focusNode.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;

    // Save immediately (no debouncing at widget level - parent handles it)
    // Note: We no longer delete immediately when empty - deletion happens on focus loss or delete key
    if (text != widget.record.content) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updatedRecord = widget.record.copyWith(
        content: text,
        updatedAt: now,
      );
      widget.onSave(updatedRecord);
    }
  }

  void _handleCheckboxToggle(bool? value) {
    if (value == null || widget.record is! TodoRecord) return;
    final todo = widget.record as TodoRecord;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = todo.copyWithChecked(
      checked: value,
      updatedAt: now,
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final isEmpty = record.content.isEmpty;
    final isChecked = record is TodoRecord && record.checked;

    // LAYOUTBUILDER: Get container width to calculate grid-aligned padding
    // This ensures checkboxes align with column 2 of the dotted grid
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPadding = GridConstants.calculateContentLeftPadding(
          constraints.maxWidth,
        );
        final rightPadding = GridConstants.calculateContentRightPadding(
          constraints.maxWidth,
        );

        return Padding(
          padding: EdgeInsets.only(
            left: leftPadding,
            right: rightPadding,
            top: GridConstants.itemVerticalSpacing,
            bottom: GridConstants.itemVerticalSpacing,
          ),
          // GRID ALIGNMENT: Force exact 24px height
          // This ensures each record aligns perfectly with the grid
          child: SizedBox(
            height: GridConstants.spacing,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Leading widget (polymorphic!) - checkbox or bullet
              // Aligns with column 2 of the grid
              Padding(
                padding: const EdgeInsets.only(
                  right: GridConstants.checkboxToTextGap,
                ),
                child: SizedBox(
                  width: GridConstants.checkboxSize,
                  height: GridConstants.checkboxSize,
              child: record is TodoRecord
                  // Checkbox is now focusable (Tab includes it, arrow keys skip it)
                  ? Checkbox(
                      value: record.checked,
                      onChanged: isEmpty ? null : _handleCheckboxToggle,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )
                  : const Center(
                      // Simple bullet point for notes
                      child: Text('•'),
                    ),
            ),
          ),
          // Text field
          Expanded(
            // KEYBOARD SHORTCUTS: Delegated to KeyboardService
            // This keeps RecordWidget focused on UI rendering, while
            // KeyboardService handles all input logic (arrow keys, Ctrl+Enter, Delete)
            //
            // SEPARATION OF CONCERNS:
            // - RecordWidget (this file): UI rendering, focus lifecycle
            // - KeyboardService: Input handling logic
            //
            // See lib/services/keyboard_service.dart for keyboard handling details
            child: Focus(
              onKeyEvent: (node, event) {
                return KeyboardService.handleRecordKeyEvent(
                  event: event,
                  node: node,
                  record: widget.record,
                  recordIndex: widget.recordIndex ?? -1,
                  textController: _controller,
                  context: context,
                  onDelete: widget.onDelete,
                  onToggleCheckbox: _handleCheckboxToggle,
                );
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                // Strikethrough for completed todos - uses default Material styling
                // LINE HEIGHT: Set to match grid spacing for vertical alignment
                // See: https://api.flutter.dev/flutter/painting/TextStyle/height.html
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  height: GridConstants.textLineHeightMultiplier,
                ),
                maxLines: null,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  _handleTextChange();
                },
                onSubmitted: (_) {
                  // Save current text immediately
                  if (_controller.text.isNotEmpty &&
                      _controller.text != widget.record.content) {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final updatedRecord = widget.record.copyWith(
                      content: _controller.text,
                      updatedAt: now,
                    );
                    widget.onSave(updatedRecord);
                  }
                  // Notify parent which record triggered Enter
                  widget.onSubmitted?.call(widget.record.id);
                },
              ),
            ),
          ),
        ],
            ), // End Row
          ), // End SizedBox
        ); // End Padding
      },
    );
  }
}
