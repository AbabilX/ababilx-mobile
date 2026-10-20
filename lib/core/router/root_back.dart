import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/start-tab/start_tab.dart';

/// App "home" — system back lands here before the OS can exit. The tab
/// picked at Settings → Open on launch; Messages unless changed.
String get kAppHomePath => StartTab.route;

bool isAppHomeLocation(String location) => location == kAppHomePath;

/// Pop one route if possible; otherwise go to the start tab.
///
/// Returns `true` when back was handled (stay in app).
/// Returns `false` only on the start tab or login — caller may exit.
bool handleRootBack(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    router.pop();
    return true;
  }
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return true;
  }
  if (router == null) return false;
  final loc = GoRouterState.of(context).matchedLocation;
  if (loc == '/login') return false;
  if (!isAppHomeLocation(loc)) {
    router.go(kAppHomePath);
    return true;
  }
  return false;
}

/// AppBar / explicit back — same rules as [handleRootBack].
void popOrGoHome(BuildContext context) {
  handleRootBack(context);
}

/// Catches Android/iOS back when the navigator has nothing left to pop
/// (notification `go()`, shell tabs, cold-start deep links).
class RootBackScope extends StatelessWidget {
  const RootBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final handled = handleRootBack(context);
        if (!handled) {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}
