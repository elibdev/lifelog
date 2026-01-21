import 'dart:async';
import 'package:flutter/material.dart';
import 'database_helper.dart';

class DailyEntryField extends StatefulWidget {
  final DateTime date;
  const DailyEntryField({super.key, required this.date});

  @override
  State<DailyEntryField> createState() => _DailyEntryFieldState();
}

class _DailyEntryFieldState extends State<DailyEntryField>
    with AutomaticKeepAliveClientMixin {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final text = await JournalDatabase.instance.getEntry(widget.date);
    if (mounted) {
      setState(() {
        _controller.text = text ?? "";
      });
    }
  }

  void _onTextChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      JournalDatabase.instance.upsertEntry(widget.date, text);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: _controller,
        onChanged: _onTextChanged,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
