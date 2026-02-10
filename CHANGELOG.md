# Changelog

## Implemented

### Widgetbook Setup
- [x] Add `widgetbook` dependency to `pubspec.yaml`
- [x] Create `widgetbook/main.dart` entry point (run with `flutter run -t widgetbook/main.dart`)
- [x] Configure widgetbook knobs for theme (light/dark) and device frames (iPhone, iPad, Laptop)
- [x] Add use-cases for all block types (text, heading, todo, bullet list, habit)

### Adaptive Block Widget
A composable block widget (Notion-style) that renders differently based on block type while using a single underlying data model.

- [x] Define `Block` model with a uniform schema: `id`, `date`, `type`, `content`, `metadata`, `orderPosition`, `createdAt`, `updatedAt`
  - Block types: `text`, `heading`, `todo`, `bulletList`, `habit`
  - `metadata` stores type-specific fields (e.g. heading level, checked state, habit schedule)
- [x] Create `AdaptiveBlockWidget` that takes a `Block` and delegates to the appropriate sub-widget:
  - `TextBlockWidget` — plain paragraph text with bullet point
  - `HeadingBlockWidget` — heading with configurable level (h1/h2/h3)
  - `TodoBlockWidget` — checkbox + text with strikethrough when checked
  - `BulletListBlockWidget` — bulleted list item with indent support and visual hierarchy
  - `HabitBlockWidget` — repeating habit with streak count and tap-to-complete
- [x] Extract shared `BlockTextField` for common text editing, focus, and keyboard behavior
- [x] Add widgetbook use-cases for each block sub-widget and the adaptive block itself
- [x] Wire up keyboard navigation across adaptive blocks (extend existing notification pattern)

### Database: Uniform Block Storage
- [x] Design `blocks` table schema: `id`, `date`, `type`, `content`, `metadata` (JSON), `order_position`, `created_at`, `updated_at`
- [x] Write migration from `records` → `blocks` table (schema version 2 → 3), mapping `note` → `text`
- [x] Fresh installs create `blocks` table directly (skip old `records` table)
- [x] Create `BlockRepository` with CRUD operations (`saveBlock`, `deleteBlock`, `getBlocksForDate`, `search`)
- [x] Event log captures block-level events using existing event sourcing architecture

### Journal View (Chronological)
- [x] Refactor `JournalScreen` to use `BlockRepository` and `Block` model
- [x] Maintain infinite scroll and lazy loading with the new block model
- [x] Replace two-section-per-day (todos/notes) with single `BlockSection` per day
- [x] Simplify cross-day navigation (one section key per date instead of per date+type)
- [x] Update `DaySection` to render `BlockSection` instead of two `RecordSection`s
- [x] Add search entry point (floating action button)

### Search View
- [x] Create `SearchScreen` with debounced text input for full-text search
- [x] Add date-range filter (date range picker)
- [x] Implement `BlockRepository.search(query, {startDate, endDate})` using SQLite LIKE
- [x] Display results grouped by date, reusing `AdaptiveBlockWidget` for rendering

### Habit Blocks
- [x] Define habit metadata schema: `habitName`, `frequency`, `completions` (list of dates), `archived`
- [x] Create `HabitBlockWidget` showing habit name, current streak, total completions, and tap-to-complete
- [x] Store completions as an append-only list in block metadata
- [x] Streak calculation walks backwards from today counting consecutive completions

## Planned (Future)

- [ ] Support inline block type switching (e.g. typing `/` to change a text block into a heading or todo)
- [ ] Add navigation from search results back to the block's position in the journal view
- [ ] Add a habits summary view showing all habits with cumulative completion counts
- [ ] Support habit reset/archival without deleting history
- [ ] Drop old `records` table in a future schema version 4
