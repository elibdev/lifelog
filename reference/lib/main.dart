import 'package:flutter/material.dart';

import 'database/record_repository.dart';
import 'theme/lifelog_theme.dart';
import 'widgets/journal_screen.dart';

void main() {
  runApp(const LifelogReferenceApp());
}

class LifelogReferenceApp extends StatelessWidget {
  const LifelogReferenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LifelogTokens(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lifelog (Reference)',
        theme: LifelogTheme.light(),
        darkTheme: LifelogTheme.dark(),
        themeMode: ThemeMode.system,
        home: JournalScreen(repository: SqliteRecordRepository()),
      ),
    );
  }
}
