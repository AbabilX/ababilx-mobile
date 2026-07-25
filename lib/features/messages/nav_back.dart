import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back from a conversation opened via notification `go()` (no stack under it).
/// List → chat uses `push`, so [canPop] is true and we just pop.
void popOrGoMessages(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/messages');
  }
}
