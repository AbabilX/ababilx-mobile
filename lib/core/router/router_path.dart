import 'package:go_router/go_router.dart';

/// The route actually on top of the stack.
///
/// Not `routerDelegate.currentConfiguration.uri.path`, which is a trap:
/// `RouteMatchList.push` appends an `ImperativeRouteMatch` through
/// `copyWith(matches: …)` and carries the base `uri` over untouched, so after
/// `push('/group-call')` from a chat the location still reads
/// `/messages/<id>`. Every guard written against `uri.path` therefore reads
/// the route the user pushed *from*, and imperatively-pushed screens are
/// invisible to it — the call screen was left on top after Leave because its
/// "am I still on /group-call?" check said no, and the return-to-call banner
/// drew over the very call it was offering to return to.
///
/// The last match's `matchedLocation` is what `push` does update:
/// `ImperativeRouteMatch` takes it from the pushed match list.
String currentRoutePath(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  if (configuration.matches.isEmpty) return configuration.uri.path;
  return configuration.last.matchedLocation;
}
