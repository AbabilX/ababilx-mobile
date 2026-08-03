import 'package:flutter/material.dart';

void showComposerSoon(BuildContext context, String label) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label coming soon')));
}
