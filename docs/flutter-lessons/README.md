# Flutter Learning Path for Lifelog

Welcome! This is a comprehensive series of hands-on Flutter lessons designed specifically for your Lifelog application. Each lesson teaches Flutter concepts while building real features that improve your app.

## About Your Codebase

Lifelog is a sophisticated journal/note-taking application with:
- **Date-based journaling** with infinite scrolling timeline
- **Two record types**: Todos (checkboxes) and Notes (bullet points)
- **Keyboard-first navigation** with arrow keys and shortcuts
- **SQLite database** with event sourcing architecture
- **Optimistic UI** with debounced writes
- **Advanced Flutter patterns** (notification bubbling, GlobalKeys, focus management)

This codebase is **excellent** for learning because it demonstrates patterns from basic StatefulWidget through advanced architectural concepts.

## How to Use These Lessons

1. **Start at your skill level** - Beginners start at Lesson 1, experienced developers can jump ahead
2. **Build each feature** - Don't just read, actually implement the features
3. **Experiment and break things** - Git makes it safe to try changes
4. **Ask questions** - Use Claude to explain any concepts you don't understand
5. **Delete teaching comments** - After you understand the code, clean up the comments

## Lesson Structure

Each lesson includes:
- **Learning Objectives**: What Flutter concepts you'll master
- **Feature Description**: What you're building and why it improves the app
- **Prerequisites**: What you should understand before starting
- **Step-by-Step Guide**: Detailed implementation instructions
- **Key Concepts**: Deep dives into Flutter patterns
- **Testing Guide**: How to verify your implementation works
- **Further Learning**: Links to official Flutter documentation
- **Next Steps**: What to learn next

## Lessons Overview

### 🌱 Beginner Level (Lessons 1-3)

**Start here if:**
- You're new to Flutter
- You understand basic programming but not Flutter specifics
- You want to learn StatefulWidget, State management, and basic UI

| Lesson | Feature | Flutter Concepts |
|--------|---------|------------------|
| [01: Settings Screen](01-beginner/lesson-01-settings-screen.md) | Add a settings screen with user preferences | StatefulWidget, State, Scaffold, AppBar, Navigation |
| [02: Search Functionality](01-beginner/lesson-02-search-functionality.md) | Search through your journal entries | TextField, filtering, setState, performance basics |
| [03: Theme Toggle](01-beginner/lesson-03-theme-toggle.md) | Dark/light mode with persistence | ThemeData, MaterialApp, SharedPreferences, State lifting |

### 🚀 Intermediate Level (Lessons 4-7)

**Start here if:**
- You understand StatefulWidget and basic state management
- You've built a few Flutter screens before
- You want to learn navigation, async programming, and custom widgets

| Lesson | Feature | Flutter Concepts |
|--------|---------|------------------|
| [04: Navigation & Routes](02-intermediate/lesson-04-navigation-routes.md) | Proper multi-screen navigation system | Navigator 2.0, Named routes, Route arguments, Deep linking |
| [05: Data Export](02-intermediate/lesson-05-data-export.md) | Export journal to JSON/Markdown | Async programming, File I/O, FutureBuilder, Error handling |
| [06: Date Picker Widget](02-intermediate/lesson-06-date-picker.md) | Jump to specific dates quickly | Custom widgets, Callbacks, DatePicker, ScrollController |
| [07: Reusable Components](02-intermediate/lesson-07-custom-widgets.md) | Extract and refactor into reusable widgets | Widget composition, const constructors, Keys |

### 🔥 Advanced Level (Lessons 8-11)

**Start here if:**
- You're comfortable with Flutter basics and intermediate concepts
- You want to understand the advanced patterns in this codebase
- You're ready to tackle focus management, undo/redo, and performance

| Lesson | Feature | Flutter Concepts |
|--------|---------|------------------|
| [08: Advanced Keyboard Shortcuts](03-advanced/lesson-08-keyboard-shortcuts.md) | Vim-like shortcuts, command palette | Actions/Shortcuts, Intent system, Focus traversal |
| [09: Undo/Redo System](03-advanced/lesson-09-undo-redo.md) | Full undo/redo using event sourcing | Event sourcing, Command pattern, Memento pattern |
| [10: Tags & Filtering](03-advanced/lesson-10-tags-system.md) | Tag system with autocomplete | Custom notifications, AutocompleteTextField, Complex state |
| [11: Performance Optimization](03-advanced/lesson-11-performance.md) | Profile and optimize the app | DevTools, RepaintBoundary, const, Keys, Isolates |

## Learning Path Recommendations

### Path 1: Complete Beginner
```
Lesson 1 → Lesson 2 → Lesson 3 → Lesson 4 → Lesson 5 → Continue in order
```

### Path 2: Some Flutter Experience
```
Lesson 3 → Lesson 4 → Lesson 5 → Lesson 6 → Lesson 7 → Advanced lessons
```

### Path 3: Experienced Developer, New to Flutter
```
Read Lesson 1-3 → Build Lesson 4-7 → Focus on Lessons 8-11
```

### Path 4: Focus on Architecture
```
Lesson 9 (Undo/Redo) → Lesson 11 (Performance) → Study existing notification pattern
```

## Getting Help

As you work through these lessons:

1. **Use Claude to explain code**: Ask "Walk me through how RecordWidget works" and Claude will annotate the code with teaching comments
2. **Ask "why" questions**: "Why did you use StatefulWidget here instead of StatelessWidget?"
3. **Request debugging help**: "This isn't working, help me debug" (use debugger, not print statements!)
4. **Explore documentation**: Each lesson links to official Flutter docs

## Your Codebase Architecture

Before diving in, understand the current structure:

```
lib/
├── main.dart                          # App entry point
├── widgets/
│   ├── journal_screen.dart           # Main infinite-scroll journal (466 lines)
│   ├── record_section.dart           # Groups records by type per date (284 lines)
│   └── record_widget.dart            # Individual todo/note widget (301 lines)
├── models/
│   ├── record.dart                   # Abstract Record + NoteRecord + TodoRecord
│   └── event.dart                    # Event sourcing model
├── database/
│   ├── database_provider.dart        # SQLite singleton with isolates
│   └── record_repository.dart        # CRUD operations
├── notifications/
│   └── navigation_notifications.dart # Custom notification pattern
└── utils/
    └── debouncer.dart                # Debouncing utility
```

### Key Patterns You'll Learn

This codebase demonstrates:

**Beginner:**
- StatefulWidget vs StatelessWidget
- TextEditingController and FocusNode
- Callbacks for parent-child communication

**Intermediate:**
- CustomScrollView with SliverList
- FutureBuilder for async data
- Responsive design with LayoutBuilder
- Keyboard event handling

**Advanced:**
- **Notification bubbling pattern** (like ScrollNotification)
- **GlobalKey for cross-widget communication**
- **Optimistic UI with debouncing**
- **Async isolates for background work**
- **Event sourcing architecture**
- **Focus management and custom navigation**

## Ready to Start?

Pick your starting lesson based on your experience level and dive in! Remember:

- **Build, don't just read** - Type the code yourself
- **Experiment** - Try changing things to see what happens
- **Use the debugger** - Set breakpoints and inspect state
- **Ask questions** - Claude is your mentor throughout

Happy learning! 🚀

---

**Next:** [Lesson 1: Building a Settings Screen](01-beginner/lesson-01-settings-screen.md)
