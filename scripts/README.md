# Test Data Generation

## Quick Way: Shell Script

Run this command to generate test data for the last 10 days:

```bash
./scripts/generate_test_data.sh
```

This will:
- Generate 2-3 notes per day for the last 10 days
- Use sample journal entries
- Insert data directly into your SQLite database

**Note**: The database path on macOS is `~/Library/Containers/com.example.lifelog/Data/Documents/infinite_journal.db`

## Restart the App

After running the script, restart the app to see your new test data!

## Manual Test Data (via SQLite)

You can also manually add test data using sqlite3:

```bash
# Find your database
find ~ -name "infinite_journal.db" 2>/dev/null

# Connect to it
sqlite3 /path/to/infinite_journal.db

# Insert a test note
INSERT INTO records (id, date, record_type, position, metadata, created_at, updated_at)
VALUES ('rec_test_1', '2026-01-20', 'note', 1.0, '{"content":"This is a test note"}', 1737398400000, 1737398400000);

INSERT INTO events (id, event_type, record_id, date, timestamp, payload, client_id)
VALUES ('evt_test_1', 'record_created', 'rec_test_1', '2026-01-20', 1737398400000, '{"record_type":"note","position":1.0,"metadata":{"content":"This is a test note"}}', NULL);
```
