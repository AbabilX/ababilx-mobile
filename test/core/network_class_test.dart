import 'package:ababilx/core/network/network_class.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('network class', () {
    test('mobile splits on the roaming flag', () {
      expect(
        resolveNetworkClass([ConnectivityResult.mobile], roaming: false),
        NetworkClass.cellular,
      );
      expect(
        resolveNetworkClass([ConnectivityResult.mobile], roaming: true),
        NetworkClass.roaming,
      );
    });

    test('roaming is only asked about a mobile connection', () {
      // A phone with a roaming SIM sitting on hotel Wi-Fi is not paying for
      // roaming data; reporting otherwise would withhold every download.
      expect(
        resolveNetworkClass([ConnectivityResult.wifi], roaming: true),
        NetworkClass.wifi,
      );
    });

    test('a wire counts as Wi-Fi and a VPN does not block downloads', () {
      expect(
        resolveNetworkClass([ConnectivityResult.ethernet], roaming: false),
        NetworkClass.wifi,
      );
      expect(
        resolveNetworkClass([ConnectivityResult.vpn], roaming: false),
        NetworkClass.wifi,
      );
    });

    test('no route out is its own answer', () {
      expect(
        resolveNetworkClass([ConnectivityResult.none], roaming: false),
        NetworkClass.offline,
      );
      expect(
        resolveNetworkClass(const [], roaming: false),
        NetworkClass.offline,
      );
      expect(AutoDownloadNetwork.forClass(NetworkClass.offline), isNull);
    });

    test('wifi wins when both transports are up', () {
      expect(
        resolveNetworkClass([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ], roaming: true),
        NetworkClass.wifi,
      );
    });
  });
}
