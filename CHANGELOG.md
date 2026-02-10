# Changelog

## Planned

### Widgetbook Setup
- [ ] Add `widgetbook` and `widgetbook_annotation` dependencies to `pubspec.yaml`
- [ ] Add `widgetbook_generator` and `build_runner` to dev dependencies
- [ ] Create `widgetbook/` directory with app entry point
- [ ] Configure widgetbook knobs for theme (light/dark) and device frames
- [ ] Add a use-case for each existing widget (`RecordWidget`, `DaySection`, `RecordSection`)

### Adaptive Block Widget
A composable block widget (Notion-style) that renders differently based on block type while using a single underlying data model.

- [ ] Define `Block` model with a uniform schema: `id`, `date`, `type`, `content`, `metadata`, `orderPosition`, `createdAt`, `updatedAt`
  - Block types: `text`, `heading`, `todo`, `bulletList`, `habit`
  - `metadata` stores type-specific fields (e.g. heading level, checked state, habit schedule)
- [ ] Create `AdaptiveBlockWidget` that takes a `Block` and delegates to the appropriate sub-widget:
  - `TextBlockWidget` — plain paragraph text
  - `HeadingBlockWidget` — heading with configurable level (h1/h2/h3)
  - `TodoBlockWidget` — checkbox + text (replaces current `TodoRecord` rendering)
  - `BulletListBlockWidget` — bulleted list item with indent support
  - `HabitBlockWidget` — repeating habit with completion count display
- [ ] Add widgetbook use-cases for each block sub-widget and the adaptive block itself
- [ ] Wire up keyboard navigation across adaptive blocks (extend existing notification pattern)

### Database: Uniform Block Storage
- [ ] Design `blocks` table schema to store all block types uniformly (type + JSON metadata column)
- [ ] Write migration from current `records` table to `blocks` table (schema version 3)
- [ ] Create `BlockRepository` with CRUD operations that deserialize into typed `Block` models
- [ ] Ensure event log captures block-level events for the existing event sourcing architecture

### Journal View (Chronological)
- [ ] Refactor `JournalScreen` to render `AdaptiveBlockWidget` instead of `RecordWidget`
- [ ] Maintain infinite scroll and lazy loading with the new block model
- [ ] Group blocks by date with existing `DaySection` pattern
- [ ] Support inline block type switching (e.g. typing `/` to change a text block into a heading or todo)

### Search View
- [ ] Create `SearchScreen` with a text input for full-text search across block content
- [ ] Add date-range filter (start date / end date picker)
- [ ] Implement `BlockRepository.search(query, {startDate, endDate})` using SQLite FTS or LIKE
- [ ] Display results grouped by date, reusing `AdaptiveBlockWidget` for rendering
- [ ] Add navigation from search results back to the block's position in the journal view

### Habit Blocks
- [ ] Define habit metadata schema: `name`, `frequency` (daily/weekly/custom), `completions` (list of dates), `streak`
- [ ] Create `HabitBlockWidget` showing habit name, current streak, and a tap-to-complete action
- [ ] Store completions as an append-only list in block metadata (or a separate `habit_completions` table)
- [ ] Add a habits summary view showing all habits with cumulative completion counts
- [ ] Support habit reset/archival without deleting history
