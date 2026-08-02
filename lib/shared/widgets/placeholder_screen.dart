// path: lib/shared/widgets/placeholder_screen.dart
import 'package:flutter/material.dart';

/// Temporary scaffold for routes whose feature module is not yet implemented.
/// Replaced by real screens in Prompts 5–16. Exists so the navigation shell and
/// router compile and are demonstrable at the end of Prompt 4A.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title\n(coming in a later build step)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
