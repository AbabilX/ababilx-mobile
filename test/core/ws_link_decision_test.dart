import 'package:ababilx/core/network/ws_link_decision.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decideWsLinkAction', () {
    test('the first reading is a baseline, never a change', () {
      // Bootstrap has just opened the socket; the stream's opening value must
      // not be read as the network having moved under it.
      expect(
        decideWsLinkAction(null, [ConnectivityResult.wifi]),
        WsLinkAction.none,
      );
      expect(decideWsLinkAction(null, const []), WsLinkAction.none);
    });

    test('the same interfaces in another order are the same network', () {
      expect(
        decideWsLinkAction(
          [ConnectivityResult.wifi, ConnectivityResult.mobile],
          [ConnectivityResult.mobile, ConnectivityResult.wifi],
        ),
        WsLinkAction.none,
      );
    });

    test('wifi to mobile reconnects — the old socket cannot have survived', () {
      expect(
        decideWsLinkAction(
          [ConnectivityResult.wifi],
          [ConnectivityResult.mobile],
        ),
        WsLinkAction.reconnect,
      );
    });

    test('a route appearing reconnects', () {
      expect(
        decideWsLinkAction(
          [ConnectivityResult.none],
          [ConnectivityResult.wifi],
        ),
        WsLinkAction.reconnect,
      );
    });

    test('losing the network drops without retrying into nothing', () {
      expect(
        decideWsLinkAction(
          [ConnectivityResult.wifi],
          [ConnectivityResult.none],
        ),
        WsLinkAction.drop,
      );
      expect(
        decideWsLinkAction([ConnectivityResult.wifi], const []),
        WsLinkAction.drop,
      );
    });

    test('gaining a second interface still scraps the old socket', () {
      // The connection was bound to one of them; the platform is free to have
      // moved it, and there is no way to ask which from here.
      expect(
        decideWsLinkAction(
          [ConnectivityResult.mobile],
          [ConnectivityResult.mobile, ConnectivityResult.wifi],
        ),
        WsLinkAction.reconnect,
      );
    });
  });
}
