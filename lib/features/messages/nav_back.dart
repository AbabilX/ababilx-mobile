import 'package:flutter/material.dart';

import '../../../core/router/root_back.dart';

/// Back from a conversation opened via notification `go()` (no stack under it).
/// List → chat uses `push`, so [canPop] is true and we just pop.
///
/// Prefer [popOrGoHome] for new call sites — this name stays for chat imports.
void popOrGoMessages(BuildContext context) => popOrGoHome(context);
