# Lifelog Code Guide

A comprehensive walkthrough of the Lifelog codebase to help you understand how this Flutter app works.

## What is Lifelog?

Lifelog is a sophisticated journal/note-taking application with:
- **Date-based journaling** with infinite scrolling timeline
- **Two record types**: Todos (with checkboxes) and Notes (with bullet points)
- **Keyboard-first navigation** with arrow keys and shortcuts
- **SQLite database** with event sourcing architecture
- **Optimistic UI** with debounced writes
- **Advanced Flutter patterns** you won't find in most tutorials

## Why This Codebase is Valuable for Learning

This app demonstrates **production-level Flutter patterns** that go way beyond beginner tutorials:

- ✅ Custom notification bubbling (like ScrollNotification)
- ✅ GlobalKey for cross-widget state access
- ✅ Optimistic UI with per-record debouncing
- ✅ Event sourcing architecture
- ✅ Async isolates for database operations
- ✅ Complex focus management
- ✅ Infinite scrolling with lazy loading
- ✅ Polymorphic data models

## How to Use This Guide

1. **Start with the Architecture Overview** below to understand the big picture
2. **Follow the Reading Order** to understand components in logical sequence
3. **Use "Ask Claude"** - At any point, ask me to walk you through specific files with teaching comments
4. **Explore connections** - Follow the links between guides to see how components interact

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Your App                             │
│                                                             │
│  ┌──────────────┐                                          │
│  │   main.dart  │  Entry point                             │
│  └──────┬───────┘                                          │
│         │                                                   │
│         ↓                                                   │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          JournalScreen (466 lines)                   │  │
│  │  - Infinite scroll with CustomScrollView             │  │
│  │  - Manages _recordsByDate Map                        │  │
│  │  - Debounced saves                                   │  │
│  │  - GlobalKey registry for navigation                 │  │
│  └────────────────┬────────────────────────────────────┘  │
│                   │                                        │
│         ┌─────────┴─────────┐                             │
│         ↓                   ↓                              │
│  ┌─────────────┐    ┌─────────────┐                       │
│  │ RecordSection│   │RecordSection│  (284 lines each)     │
│  │   (Todos)    │   │  (Notes)    │                       │
│  │              │   │             │                        │
│  │ - Placeholder│   │ - Focus mgmt│                       │
│  │ - Navigation │   │ - Enter key │                       │
│  └──────┬───────┘   └──────┬──────┘                       │
│         │                  │                               │
│         ↓                  ↓                               │
│  ┌──────────────────────────────┐                         │
│  │    RecordWidget (301 lines)   │  (Multiple instances)  │
│  │  - Individual record          │                        │
│  │  - Keyboard shortcuts         │                        │
│  │  - Dispatches notifications   │                        │
│  └───────────────┬───────────────┘                        │
│                  │                                         │
│                  │ saves via callback                      │
│                  ↓                                         │
│         ┌────────────────┐                                │
│         │   Debouncer    │  Per-record 500ms delay        │
│         └────────┬───────┘                                │
│                  │                                         │
│                  ↓                                         │
│         ┌─────────────────────┐                           │
│         │  RecordRepository   │  CRUD operations          │
│         └──────────┬──────────┘                           │
│                    │                                       │
│                    ↓                                       │
│         ┌──────────────────────┐                          │
│         │  DatabaseProvider    │  SQLite + Isolates       │
│         │  (Singleton)         │                          │
│         └──────────────────────┘                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

## Codebase Structure

```
lib/
├── main.dart                          # Entry point (40 lines)
│
├── models/                            # Data models
│   ├── record.dart                    # Abstract Record + subclasses (150 lines)
│   └── event.dart                     # Event sourcing model (50 lines)
│
├── database/                          # Data persistence layer
│   ├── database_provider.dart         # SQLite singleton with isolates (200 lines)
│   └── record_repository.dart         # CRUD operations (250 lines)
│
├── widgets/                           # UI components
│   ├── journal_screen.dart            # Main screen (466 lines)
│   ├── record_section.dart            # Groups records by type (284 lines)
│   └── record_widget.dart             # Individual record (301 lines)
│
├── notifications/                     # Custom notification pattern
│   └── navigation_notifications.dart  # Bubble navigation events (30 lines)
│
└── utils/                            # Utilities
    └── debouncer.dart                # Simple debouncing (40 lines)
```

## Reading Order

Follow this sequence to understand the codebase from foundation to UI:

### Part 1: Foundation (Data Layer)

**Start here if:** You want to understand how data flows through the app

1. **[Understanding the Data Models](01-data-models.md)** - `lib/models/record.dart`
   - Abstract classes and polymorphism
   - Immutable patterns with copyWith
   - JSON serialization
   - TodoRecord vs NoteRecord

2. **[Understanding Event Sourcing](02-event-sourcing.md)** - `lib/models/event.dart`
   - What is event sourcing and why use it?
   - The Event model
   - How events enable sync and undo

3. **[Understanding the Database Layer](03-database-layer.md)** - `lib/database/`
   - SQLite with FFI (not sqflite)
   - Singleton pattern
   - Isolates for background processing
   - Write queue to prevent locking

4. **[Understanding the Repository Pattern](04-repository-pattern.md)** - `lib/database/record_repository.dart`
   - CRUD operations
   - Why separate repository from provider?
   - Dual-write pattern (records + events)

### Part 2: UI Architecture

**Start here if:** You want to understand the widget tree and state management

5. **[Understanding the Widget Hierarchy](05-widget-hierarchy.md)** - `lib/widgets/`
   - Three-tier architecture (Screen → Section → Widget)
   - Why this structure?
   - State management at each level

6. **[Understanding JournalScreen](06-journal-screen.md)** - `lib/widgets/journal_screen.dart`
   - Infinite scroll with CustomScrollView
   - Lazy loading dates
   - The _recordsByDate cache
   - GlobalKey registry for navigation

7. **[Understanding RecordSection](07-record-section.md)** - `lib/widgets/record_section.dart`
   - Grouping records by type
   - Placeholder management
   - Focus tracking
   - Enter key handling

8. **[Understanding RecordWidget](08-record-widget.md)** - `lib/widgets/record_widget.dart`
   - Polymorphic rendering (checkbox vs bullet)
   - Keyboard shortcut handling
   - Focus lifecycle
   - Text input management

### Part 3: Advanced Patterns

**Start here if:** You want to understand the sophisticated patterns

9. **[Understanding the Notification Pattern](09-notification-pattern.md)** - `lib/notifications/`
   - Custom notification bubbling
   - How NavigateUpNotification works
   - Why not use callbacks?
   - Building your own notifications

10. **[Understanding Focus Management](10-focus-management.md)** - Throughout codebase
    - FocusNode lifecycle
    - GlobalKey for cross-widget access
    - Focus registration pattern
    - Arrow key navigation

11. **[Understanding Optimistic UI](11-optimistic-ui.md)** - `lib/widgets/journal_screen.dart` + `lib/utils/debouncer.dart`
    - Instant UI updates
    - Per-record debouncing (500ms)
    - Why debounce per record?
    - Handling rapid changes

12. **[Understanding Isolates and Background Work](12-isolates.md)** - `lib/database/database_provider.dart`
    - What are isolates?
    - Database in isolate
    - Write queue pattern
    - When to use isolates

## Key Files Reference

Quick links to important files (open these in your editor):

### Core Application
- [`lib/main.dart`](/home/user/lifelog/lib/main.dart) - App entry point

### Models
- [`lib/models/record.dart`](/home/user/lifelog/lib/models/record.dart) - Record data models
- [`lib/models/event.dart`](/home/user/lifelog/lib/models/event.dart) - Event sourcing

### Database
- [`lib/database/database_provider.dart`](/home/user/lifelog/lib/database/database_provider.dart) - SQLite with isolates
- [`lib/database/record_repository.dart`](/home/user/lifelog/lib/database/record_repository.dart) - CRUD operations

### Widgets
- [`lib/widgets/journal_screen.dart`](/home/user/lifelog/lib/widgets/journal_screen.dart) - Main screen (466 lines)
- [`lib/widgets/record_section.dart`](/home/user/lifelog/lib/widgets/record_section.dart) - Section grouping (284 lines)
- [`lib/widgets/record_widget.dart`](/home/user/lifelog/lib/widgets/record_widget.dart) - Individual record (301 lines)

### Advanced Patterns
- [`lib/notifications/navigation_notifications.dart`](/home/user/lifelog/lib/notifications/navigation_notifications.dart) - Custom notifications
- [`lib/utils/debouncer.dart`](/home/user/lifelog/lib/utils/debouncer.dart) - Debouncing utility

## Flutter Concepts You'll Learn

This codebase teaches you:

### Beginner Concepts
- StatefulWidget vs StatelessWidget
- setState and rebuilds
- TextEditingController and FocusNode
- Callbacks for parent-child communication
- Widget lifecycle (initState, dispose, didUpdateWidget)

### Intermediate Concepts
- CustomScrollView with SliverList
- FutureBuilder for async data
- Responsive design with LayoutBuilder
- Keyboard event handling
- GlobalKey usage

### Advanced Concepts
- **Custom notification pattern** (beyond ScrollNotification)
- **Optimistic UI** with debouncing
- **Event sourcing** architecture
- **Isolates** for background work
- **Focus management** at scale
- **Polymorphic rendering**
- **Write queue** to prevent database locking

## How to Get the Most Out of This Guide

### 1. Ask Me to Explain Code

At any point, you can ask me:

```
"Walk me through how RecordWidget handles keyboard input"
"Explain the notification pattern in record_section.dart"
"How does the debouncing work in journal_screen.dart?"
```

I'll add teaching comments directly to the source files explaining:
- What each part does
- Why it's structured this way
- How it connects to other parts
- Common Flutter patterns used

### 2. Follow the Links

Each guide links to:
- ✅ Specific files and line numbers
- ✅ Related guides
- ✅ Official Flutter documentation
- ✅ Code examples in the codebase

### 3. Experiment

After reading a guide:
- Open the file in your editor
- Set breakpoints and use the debugger
- Try modifying code to see what happens
- Git makes it safe to experiment!

### 4. Build on Top

Once you understand a pattern, try:
- Applying it elsewhere in the code
- Building a new feature using the same pattern
- Refactoring to improve it

## Questions to Guide Your Learning

As you read the code, ask yourself:

**About Architecture:**
- Why three widget layers (Screen → Section → Widget)?
- Why separate Repository from DatabaseProvider?
- Why is state managed at different levels?

**About Patterns:**
- Why notification bubbling instead of callbacks?
- Why GlobalKey instead of passing FocusNodes down?
- Why per-record debouncing instead of global?

**About Performance:**
- Why lazy load dates instead of loading all?
- Why isolates for database operations?
- Why const constructors where possible?

**About Flutter:**
- How does CustomScrollView enable infinite scroll?
- How does FocusNode track keyboard focus?
- How does NotificationListener bubble events?

## What Makes This Code Special

Most Flutter tutorials show you:
- ❌ Simple CRUD apps
- ❌ Basic state management
- ❌ Standard widgets only
- ❌ Toy examples

This codebase shows you:
- ✅ Production patterns
- ✅ Advanced state management
- ✅ Custom patterns (notifications, focus)
- ✅ Real-world complexity
- ✅ Performance optimization
- ✅ Architectural decisions

## Ready to Start?

Pick a starting point based on your interest:

- **Understand data flow?** → Start with Part 1 (Data Layer)
- **Understand the UI?** → Start with Part 2 (UI Architecture)
- **Understand advanced patterns?** → Start with Part 3 (Advanced Patterns)
- **Just want to explore?** → Ask me to walk you through any file!

---

**Next:** [Understanding the Data Models](01-data-models.md) or ask me to explain any file!
