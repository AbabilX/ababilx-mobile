import 'package:connectivity_plus/connectivity_plus.dart';

/// What a connectivity change means for a socket that is already open.
enum WsLinkAction {
  /// Nothing moved that the connection cares about.
  none,

  /// The socket cannot have survived, and there is nowhere to reopen it yet.
  drop,

  /// The socket cannot have survived, but a route exists — reopen now.
  reconnect,
}

/// Reads a connectivity change the way the socket experiences it.
///
/// An interface swap kills a TCP connection without closing it: nothing arrives
/// on the old socket and nothing it sends leaves, but no FIN can reach a phone
/// that no longer has a route to the peer. So a change of interface is always
/// [WsLinkAction.drop] at minimum — the old socket is scrap either way, and
/// keeping it is what leaves a client believing it is connected for hours.
///
/// [previous] is null before any change has been seen. The first value from
/// `onConnectivityChanged` is the current state rather than a change, and
/// acting on it would tear down the socket that was just opened.
WsLinkAction decideWsLinkAction(
  List<ConnectivityResult>? previous,
  List<ConnectivityResult> current,
) {
  if (previous == null || _same(previous, current)) return WsLinkAction.none;
  return _offline(current) ? WsLinkAction.drop : WsLinkAction.reconnect;
}

bool _offline(List<ConnectivityResult> results) =>
    results.isEmpty || results.every((r) => r == ConnectivityResult.none);

/// Order is not meaning here: a phone reporting wifi+mobile is on the same
/// footing as one reporting mobile+wifi, and reconnecting on that would churn
/// the socket every time the platform reshuffled its list.
bool _same(List<ConnectivityResult> a, List<ConnectivityResult> b) =>
    a.length == b.length && a.toSet().containsAll(b);
