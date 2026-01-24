# Lesson 9: Undo/Redo System with Event Sourcing

**Difficulty:** Advanced
**Estimated Time:** 4-5 hours
**Prerequisites:** Understanding of your existing event sourcing architecture

## Learning Objectives

1. ✅ **Event sourcing** - Event-based state management
2. ✅ **Command pattern** - Encapsulating actions as objects
3. ✅ **Memento pattern** - Capturing and restoring state
4. ✅ **Event replay** - Reconstructing state from events
5. ✅ **Undo stack** - Managing undo/redo history

## What You're Building

A complete undo/redo system:
- **Undo/redo buttons** - UI controls
- **Keyboard shortcuts** - Cmd/Ctrl+Z and Cmd/Ctrl+Shift+Z
- **Event-based history** - Using your existing event_log table
- **State reconstruction** - Replay events to restore state
- **Undo limits** - Keep last N operations

This leverages your existing event sourcing architecture!

## Understanding Your Event Sourcing System

Your app already has event sourcing! Let's explore it:

**File:** `/home/user/lifelog/lib/database/record_repository.dart`

You have an `event_log` table that stores all changes:

```sql
CREATE TABLE event_log (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  record_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  device_id TEXT
);
```

**Current event types:**
- `create` - Record created
- `update` - Record modified
- `delete` - Record deleted

This is perfect for undo/redo!

## Step 1: Understand Event Sourcing Principles

Event sourcing means:
1. **Never delete data** - Only append events
2. **Current state = replay all events** - State is derived
3. **Events are immutable** - Never modify past events
4. **Time travel** - Can reconstruct any past state

**Example:**
```
Events:
1. CREATE todo "Buy milk"
2. UPDATE todo "Buy milk" -> completed=true
3. UPDATE todo "Buy milk" -> content="Buy milk and eggs"

Current state = result of replaying events 1, 2, 3
State at time 2 = result of replaying events 1, 2
Undo event 3 = replay only events 1, 2
```

## Step 2: Create Undo Manager

**File:** `/home/user/lifelog/lib/services/undo_manager.dart` (new file)

```dart
import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../database/record_repository.dart';

class UndoManager with ChangeNotifier {
  final RecordRepository _repository = RecordRepository();

  // Undo/redo stacks
  final List<String> _undoStack = []; // Event IDs
  final List<String> _redoStack = []; // Event IDs

  // Limits
  static const int maxUndoStackSize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Track an event for undo
  void trackEvent(String eventId) {
    _undoStack.add(eventId);

    // Limit stack size
    if (_undoStack.length > maxUndoStackSize) {
      _undoStack.removeAt(0);
    }

    // Clear redo stack when new action performed
    _redoStack.clear();

    notifyListeners();
  }

  // Undo last action
  Future<void> undo() async {
    if (!canUndo) return;

    // Get last event
    final eventId = _undoStack.removeLast();
    final event = await _repository.getEvent(eventId);

    if (event != null) {
      // Create inverse event
      await _createInverseEvent(event);

      // Move to redo stack
      _redoStack.add(eventId);

      notifyListeners();
    }
  }

  // Redo last undone action
  Future<void> redo() async {
    if (!canRedo) return;

    final eventId = _redoStack.removeLast();
    final event = await _repository.getEvent(eventId);

    if (event != null) {
      // Replay the event
      await _replayEvent(event);

      // Move back to undo stack
      _undoStack.add(eventId);

      notifyListeners();
    }
  }

  // Create inverse event (opposite of original)
  Future<void> _createInverseEvent(Event event) async {
    switch (event.eventType) {
      case 'create':
        // Inverse of create is delete
        await _repository.deleteRecord(event.recordId);
        break;

      case 'update':
        // Inverse of update is restore previous state
        final previousState = await _getPreviousState(event.recordId, event);
        if (previousState != null) {
          await _repository.updateRecord(previousState);
        }
        break;

      case 'delete':
        // Inverse of delete is restore
        final record = _reconstructRecord(event);
        if (record != null) {
          await _repository.createRecord(record);
        }
        break;
    }
  }

  // Replay an event (for redo)
  Future<void> _replayEvent(Event event) async {
    switch (event.eventType) {
      case 'create':
        final record = _reconstructRecord(event);
        if (record != null) {
          await _repository.createRecord(record);
        }
        break;

      case 'update':
        final record = _reconstructRecord(event);
        if (record != null) {
          await _repository.updateRecord(record);
        }
        break;

      case 'delete':
        await _repository.deleteRecord(event.recordId);
        break;
    }
  }

  // Get previous state by replaying all events except current
  Future<Record?> _getPreviousState(String recordId, Event currentEvent) async {
    final allEvents = await _repository.getEventsForRecord(recordId);

    // Filter out current event and events after it
    final previousEvents = allEvents
        .where((e) => e.timestamp < currentEvent.timestamp)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (previousEvents.isEmpty) return null;

    // Replay events to reconstruct state
    Record? state;
    for (var event in previousEvents) {
      state = _reconstructRecord(event);
    }

    return state;
  }

  // Reconstruct record from event payload
  Record? _reconstructRecord(Event event) {
    // Parse payload and create Record
    // Implementation depends on your Event.payload structure
    try {
      final payload = jsonDecode(event.payload);
      return Record.fromJson(payload);
    } catch (e) {
      print('Failed to reconstruct record: $e');
      return null;
    }
  }

  // Clear all history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}
```

## Step 3: Integrate with Repository

Update `RecordRepository` to track events:

**File:** `/home/user/lifelog/lib/database/record_repository.dart`

```dart
class RecordRepository {
  final UndoManager? undoManager; // Optional undo tracking

  RecordRepository({this.undoManager});

  Future<void> createRecord(Record record) async {
    // ...existing create code...

    // Track event for undo
    if (undoManager != null) {
      final eventId = await _logEvent('create', record.id, record.toJson());
      undoManager!.trackEvent(eventId);
    }
  }

  // Similar for update and delete...
}
```

## Step 4: Add Undo/Redo UI

**File:** `/home/user/lifelog/lib/widgets/journal_screen.dart`

Add undo manager and buttons:

```dart
class _JournalScreenState extends State<JournalScreen> {
  final UndoManager _undoManager = UndoManager();

  @override
  void initState() {
    super.initState();
    // Listen to undo state changes
    _undoManager.addListener(() {
      setState(() {}); // Rebuild to enable/disable buttons
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        actions: [
          // Undo button
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo (${_platformShortcut}+Z)',
            onPressed: _undoManager.canUndo ? _undoManager.undo : null,
          ),

          // Redo button
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo (${_platformShortcut}+Shift+Z)',
            onPressed: _undoManager.canRedo ? _undoManager.redo : null,
          ),

          // ...other buttons...
        ],
      ),
      // ...rest of UI...
    );
  }

  String get _platformShortcut =>
      Platform.isMacOS ? '⌘' : 'Ctrl';
}
```

## Step 5: Add Keyboard Shortcuts

Add to your intents (from Lesson 8):

```dart
// In intents.dart
class UndoIntent extends Intent {}
class RedoIntent extends Intent {}

// In app_shortcuts.dart
SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
    const UndoIntent(),
SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
    const RedoIntent(),
```

## Key Concepts

### 1. Event Sourcing

```dart
// Traditional CRUD (losing history)
UPDATE records SET content = 'New' WHERE id = '123';

// Event Sourcing (preserving history)
INSERT INTO event_log VALUES (
  uuid(),
  'update',
  '123',
  '{"content": "New"}',
  timestamp()
);

// State is derived by replaying events
```

**Benefits:**
- Complete audit trail
- Time travel (reconstruct any past state)
- Natural undo/redo
- Easier debugging
- Can add new features by processing old events

**Drawbacks:**
- More storage
- More complex queries
- Need to handle schema changes

### 2. Command Pattern

```dart
// Encapsulate actions as objects
abstract class Command {
  Future<void> execute();
  Future<void> undo();
}

class CreateRecordCommand extends Command {
  final Record record;

  CreateRecordCommand(this.record);

  @override
  Future<void> execute() async {
    await repository.create(record);
  }

  @override
  Future<void> undo() async {
    await repository.delete(record.id);
  }
}

// Execute with undo support
final command = CreateRecordCommand(myRecord);
await command.execute();
undoStack.add(command);

// Undo
final command = undoStack.removeLast();
await command.undo();
```

### 3. Event Replay

```dart
// Reconstruct state at any point in time
List<Record> reconstructState(List<Event> events) {
  final records = <String, Record>{};

  for (var event in events) {
    switch (event.type) {
      case 'create':
        records[event.recordId] = Record.fromJson(event.payload);
        break;
      case 'update':
        records[event.recordId] = Record.fromJson(event.payload);
        break;
      case 'delete':
        records.remove(event.recordId);
        break;
    }
  }

  return records.values.toList();
}
```

## Testing Checklist

- [ ] Create record, undo brings it back
- [ ] Update record, undo restores previous value
- [ ] Delete record, undo brings it back
- [ ] Redo re-applies undone action
- [ ] Undo/redo buttons enable/disable correctly
- [ ] Keyboard shortcuts work (Cmd+Z, Cmd+Shift+Z)
- [ ] New action clears redo stack
- [ ] Undo stack respects max size

## Common Patterns

### Pattern 1: Optimistic Undo

```dart
// Undo immediately (optimistic)
void undo() {
  final event = _undoStack.removeLast();
  _applyInverse(event); // Update UI immediately

  // Persist in background
  _repository.saveEvent(event).catchError((e) {
    // Rollback if fails
    _undoStack.add(event);
    _reapply(event);
  });
}
```

### Pattern 2: Grouped Undo

```dart
// Group multiple events as one undo operation
class UndoGroup {
  final List<Event> events;
  final String description;

  void undo() {
    for (var event in events.reversed) {
      _undoEvent(event);
    }
  }
}
```

## Challenges

**Challenge 1:** Add undo/redo history panel showing past actions
**Challenge 2:** Implement selective undo (undo specific action, not just last)
**Challenge 3:** Add undo grouping (batch operations)
**Challenge 4:** Persist undo stack across app restarts

## What You've Learned

- ✅ Event sourcing architecture
- ✅ Command pattern for undoable actions
- ✅ Event replay and state reconstruction
- ✅ Undo/redo stack management
- ✅ Inverse event generation

---

**Previous:** [Lesson 8: Advanced Keyboard Shortcuts](lesson-08-keyboard-shortcuts.md)
**Next:** [Lesson 10: Tags & Filtering](lesson-10-tags-system.md)
