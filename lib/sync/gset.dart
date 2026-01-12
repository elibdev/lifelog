import 'event.dart';

class GSet {
  final Map<String, Event> _events = {};

  /// Add an event to the G-Set
  /// Returns true if the event was new and added, false if it already existed
  bool add(Event event) {
    final eventHash = event.hash;
    if (_events.containsKey(eventHash)) {
      return false;
    }
    
    _events[eventHash] = event;
    return true;
  }

  /// Get all event hashes in the G-Set
  Set<String> getHashes() {
    return _events.keys.toSet();
  }

  /// Get events for the specified hashes
  /// Returns only events that exist in the G-Set
  List<Event> getEvents(Set<String> hashes) {
    return hashes
        .map((hash) => _events[hash])
        .where((event) => event != null)
        .cast<Event>()
        .toList();
  }

  /// Get all events in the G-Set
  List<Event> getAllEvents() {
    return _events.values.toList();
  }

  /// Merge events from another G-Set
  /// Returns the number of new events added
  int merge(List<Event> events) {
    int added = 0;
    for (final event in events) {
      if (add(event)) {
        added++;
      }
    }
    return added;
  }

  /// Build current notes state from all events
  /// Applies events in timestamp order (LWW conflict resolution)
  Map<String, Note> buildNotes() {
    // Sort all events by timestamp
    final sortedEvents = _events.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final Map<String, Note> notes = {};

    for (final event in sortedEvents) {
      switch (event.type) {
        case EventType.CREATE:
        case EventType.UPDATE:
          notes[event.noteId] = Note(
            id: event.noteId,
            content: event.content ?? '',
            timestamp: event.timestamp,
            lastEventHash: event.hash,
          );
          break;
        case EventType.DELETE:
          notes.remove(event.noteId);
          break;
      }
    }

    return notes;
  }

  /// Get the current state of a specific note
  Note? getNote(String noteId) {
    final notes = buildNotes();
    return notes[noteId];
  }

  /// Get all events for a specific note ID
  List<Event> getEventsForNote(String noteId) {
    return _events.values
        .where((event) => event.noteId == noteId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get the latest event for a specific note ID
  Event? getLatestEventForNote(String noteId) {
    final events = getEventsForNote(noteId);
    return events.isEmpty ? null : events.last;
  }

  /// Clear all events (for testing/reset purposes)
  void clear() {
    _events.clear();
  }

  /// Get the number of events in the G-Set
  int get size => _events.length;

  /// Check if the G-Set is empty
  bool get isEmpty => _events.isEmpty;

  /// Check if the G-Set is not empty
  bool get isNotEmpty => _events.isNotEmpty;
}

/// Represents a note in its current state
class Note {
  final String id;
  final String content;
  final int timestamp;
  final String lastEventHash;

  Note({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.lastEventHash,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.content == content &&
        other.timestamp == timestamp &&
        other.lastEventHash == lastEventHash;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        content.hashCode ^
        timestamp.hashCode ^
        lastEventHash.hashCode;
  }

  @override
  String toString() {
    return 'Note(id: $id, content: ${content.length > 50 ? content.substring(0, 50) + "..." : content}, timestamp: $timestamp)';
  }
}