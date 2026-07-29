import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App "home" — system back lands here before the OS can exit.
const kAppHomePath = '/messages';

bool isAppHomeLocation(String location) => location == kAppHomePath;

/// Pop one route if possible; otherwise go to Messages home.
///
/// Returns `true` when back was handled (stay in app).
/// Returns `false` only on Messages home or login — caller may exit.
bool handleRootBack(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return true;
  }
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
    return BackButtonListener(
      onBackButtonPressed: () async => handleRootBack(context),
      child: child,
    );
  }
}
