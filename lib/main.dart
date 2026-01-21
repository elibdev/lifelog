import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.yellow)),
      home: const MyHomePage(title: 'lifelog'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _notes = <DateTime, String>{};

  void _upsertNote(DateTime date, String note) {
    setState(() {
      _notes[date] = note;
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    _notes[today] = "This is a test note";

    final dateString = DateFormat('EEEE, MMM d').format(today);
    final yearString = DateFormat('yyyy').format(today);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .start,
          crossAxisAlignment: .start,
          spacing: 10,
          children: [
            Text(
              '$dateString, $yearString',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: null,
              decoration: null,
              controller: TextEditingController(text: _notes[today]),
            ),
          ],
        ),
      ),
    );
  }
}
