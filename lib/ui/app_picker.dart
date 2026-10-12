import 'package:flutter/material.dart';

import '../apps.dart';
import '../scope.dart';

/// Returns the chosen app, or null if the user backs out.
Future<AppEntry?> pickApp(
  BuildContext context, {
  String title = 'Choose app',
}) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => _AppPickerScreen(title: title)));

class _AppPickerScreen extends StatefulWidget {
  const _AppPickerScreen({required this.title});

  final String title;

  @override
  State<_AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<_AppPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final apps = Launcher.of(context).apps;
    final results = searchApps(apps.all, _query, apps.labelOf);
    final color = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autocorrect: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: color.withValues(alpha: 0.3)),
                border: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) {
                final app = results[i];
                return ListTile(
                  title: Text(apps.labelOf(app)),
                  subtitle: app.work ? const Text('Work') : null,
                  onTap: () => Navigator.pop(context, app),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
