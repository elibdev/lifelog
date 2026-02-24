import 'package:flutter/material.dart';
import 'theme/lifelog_theme.dart';
import 'database/record_repository.dart';
import 'widgets/journal_screen.dart';

void main() {
  runApp(const LifelogApp());
}

/// Root widget — wraps the app in [LifelogTokens] (design system tokens)
/// and applies the Swiss-Italian notebook theme.
///
/// LifelogTokens is an InheritedWidget that makes spacing/sizing tokens
/// available to any descendant via LifelogTokens.of(context).
/// See: https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html
class LifelogApp extends StatelessWidget {
  const LifelogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LifelogTokens(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lifelog',
        // Design system themes — warm paper tones, Swiss typography
        theme: LifelogTheme.light(),
        darkTheme: LifelogTheme.dark(),
        themeMode: ThemeMode.system,
        home: JournalScreen(repository: SqliteRecordRepository()),
      ),
    );
  }
}
