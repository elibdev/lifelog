import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

// Run this script to generate test journal data
// Usage: dart run scripts/generate_test_data.dart

const uuid = Uuid();
final random = Random();

final sampleNotes = [
  'Had a great morning coffee and started planning the day ahead. The weather is perfect.',
  'Worked on the new project for about 3 hours. Made good progress on the main features.',
  'Quick lunch break - tried the new sandwich place down the street. Highly recommend!',
  'Afternoon meeting went well. Everyone is aligned on the roadmap for next quarter.',
  'Took a walk in the park. Saw some beautiful birds and enjoyed the fresh air.',
  'Cooked dinner - tried a new recipe from that cookbook. Turned out delicious!',
  'Read a few chapters of my current book. Getting to the good part.',
  'Reflected on the day. Feeling grateful for the small moments of joy.',
  'Morning workout felt great. Finally getting back into a routine.',
  'Coffee with an old friend. Caught up on everything that\'s been happening.',
  'Deep work session on the complex problem I\'ve been thinking about.',
  'Lunch with the team - good conversations about life and work.',
  'Made some progress on organizing my digital files. Long overdue!',
  'Evening yoga session. Feeling relaxed and centered.',
  'Quick note: Remember to follow up on that email tomorrow.',
  'Brainstorming session was productive. Lots of interesting ideas.',
  'Went for a bike ride. Explored a new neighborhood.',
  'Movie night! Watched that film everyone\'s been talking about.',
  'Worked on some personal projects. Making slow but steady progress.',
  'Meal prep for the week. Future me will be grateful.',
];

Future<void> main() async {
  print('Generating test data for lifelog...');

  // Get the database path
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = join(docsDir.path, 'infinite_journal.db');

  print('Database path: $dbPath');

  if (!await File(dbPath).exists()) {
    print('Error: Database not found. Please run the app first to create the database.');
    exit(1);
  }

  final db = await openDatabase(dbPath);

  // Check if schema is v2
  final version = await db.getVersion();
  if (version < 2) {
    print('Error: Database is version $version. Please run the app to migrate to v2.');
    exit(1);
  }

  print('Database version: $version ✓');

  // Generate data for the last 30 days
  final now = DateTime.now();
  int recordCount = 0;
  int eventCount = 0;

  for (int daysAgo = 0; daysAgo < 30; daysAgo++) {
    final date = now.subtract(Duration(days: daysAgo));
    final dateKey = _dateKey(date);

    // Generate 1-4 notes per day
    final notesCount = random.nextInt(4) + 1;

    for (int i = 0; i < notesCount; i++) {
      final recordId = 'rec_${uuid.v4()}';
      final eventId = 'evt_${uuid.v4()}';
      final position = (i + 1).toDouble();
      final content = sampleNotes[random.nextInt(sampleNotes.length)];

      final createdAt = date.add(Duration(hours: 8 + i * 2));

      // Insert record
      await db.insert('records', {
        'id': recordId,
        'date': dateKey,
        'record_type': 'note',
        'position': position,
        'metadata': '{"content":"$content"}',
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': createdAt.millisecondsSinceEpoch,
      });
      recordCount++;

      // Insert event
      await db.insert('events', {
        'id': eventId,
        'event_type': 'record_created',
        'record_id': recordId,
        'date': dateKey,
        'timestamp': createdAt.millisecondsSinceEpoch,
        'payload': '{"record_type":"note","position":$position,"metadata":{"content":"$content"}}',
        'client_id': null,
      });
      eventCount++;
    }

    print('Generated $notesCount notes for $dateKey');
  }

  await db.close();

  print('\n✓ Successfully generated test data:');
  print('  - $recordCount records');
  print('  - $eventCount events');
  print('  - 30 days of journal entries');
  print('\nRestart the app to see the test data!');
}

String _dateKey(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}
