#!/bin/bash

# Generate test data for lifelog
# Usage: ./scripts/generate_test_data.sh

# macOS path (Flutter uses app container)
DB_PATH="$HOME/Library/Containers/com.example.lifelog/Data/Documents/infinite_journal.db"

if [ ! -f "$DB_PATH" ]; then
    echo "Error: Database not found at $DB_PATH"
    echo "Please run the app first to create the database."
    echo ""
    echo "Searching for database in common locations..."
    find ~/Library/Containers -name "infinite_journal.db" 2>/dev/null
    exit 1
fi

echo "Generating test data..."

# Sample notes
NOTES=(
    "Had a great morning coffee and started planning the day ahead. The weather is perfect."
    "Worked on the new project for about 3 hours. Made good progress on the main features."
    "Quick lunch break - tried the new sandwich place down the street. Highly recommend!"
    "Afternoon meeting went well. Everyone is aligned on the roadmap for next quarter."
    "Took a walk in the park. Saw some beautiful birds and enjoyed the fresh air."
    "Cooked dinner - tried a new recipe from that cookbook. Turned out delicious!"
    "Read a few chapters of my current book. Getting to the good part."
    "Reflected on the day. Feeling grateful for the small moments of joy."
    "Morning workout felt great. Finally getting back into a routine."
    "Coffee with an old friend. Caught up on everything that has been happening."
)

# Generate data for the last 10 days
for days_ago in {0..9}; do
    DATE=$(date -v-${days_ago}d +%Y-%m-%d 2>/dev/null || date -d "${days_ago} days ago" +%Y-%m-%d)
    TIMESTAMP=$(date -v-${days_ago}d +%s 2>/dev/null || date -d "${days_ago} days ago" +%s)
    TIMESTAMP_MS=$((TIMESTAMP * 1000))

    # Generate 2-3 notes per day
    NUM_NOTES=$((RANDOM % 2 + 2))

    for i in $(seq 1 $NUM_NOTES); do
        RECORD_ID="rec_test_${DATE}_${i}"
        EVENT_ID="evt_test_${DATE}_${i}"
        POSITION="${i}.0"

        # Pick a random note
        NOTE_INDEX=$((RANDOM % ${#NOTES[@]}))
        CONTENT="${NOTES[$NOTE_INDEX]}"

        # Insert record
        sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO records (id, date, record_type, position, metadata, created_at, updated_at) VALUES ('$RECORD_ID', '$DATE', 'note', $POSITION, '{\"content\":\"$CONTENT\"}', $TIMESTAMP_MS, $TIMESTAMP_MS);"

        # Insert event
        sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO events (id, event_type, record_id, date, timestamp, payload, client_id) VALUES ('$EVENT_ID', 'record_created', '$RECORD_ID', '$DATE', $TIMESTAMP_MS, '{\"record_type\":\"note\",\"position\":$POSITION,\"metadata\":{\"content\":\"$CONTENT\"}}', NULL);"
    done

    echo "Generated $NUM_NOTES notes for $DATE"
done

echo ""
echo "✓ Test data generated successfully!"
echo "Restart the app to see the changes."
