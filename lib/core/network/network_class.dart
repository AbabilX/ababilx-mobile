import 'package:connectivity_plus/connectivity_plus.dart';

/// What this connection costs, which is the only thing auto-download cares
/// about.
///
/// Not the same question as "am I online" — a VPN over Wi-Fi is still Wi-Fi,
/// and a phone abroad on the same carrier is still charged differently from
/// one at home. [offline] exists so a decision can be *declined* rather than
/// guessed: nothing auto-downloads with no route out.
enum NetworkClass { wifi, cellular, roaming, offline }

/// Which auto-download boxes a class satisfies.
///
/// Roaming is deliberately NOT cellular here. A user who leaves "Cellular" on
/// and "Roaming" off is asking for exactly one thing, and folding the two
/// together is what would run up the bill this setting exists to prevent.
enum AutoDownloadNetwork {
  wifi(1),
  cellular(2),
  roaming(4);

  const AutoDownloadNetwork(this.bit);

  final int bit;

  static AutoDownloadNetwork? forClass(NetworkClass network) =>
      switch (network) {
        NetworkClass.wifi => AutoDownloadNetwork.wifi,
        NetworkClass.cellular => AutoDownloadNetwork.cellular,
        NetworkClass.roaming => AutoDownloadNetwork.roaming,
        NetworkClass.offline => null,
      };

  String get label => switch (this) {
    AutoDownloadNetwork.wifi => 'Wi-Fi',
    AutoDownloadNetwork.cellular => 'Cellular',
    AutoDownloadNetwork.roaming => 'Roaming',
  };
}

/// Pure classification, so the interesting part is testable without a device.
///
/// [roaming] comes from the platform and is only consulted for a mobile
/// connection: `connectivity_plus` cannot answer it, and a Wi-Fi network has
/// no roaming state to report.
///
/// Ethernet counts as Wi-Fi (an unmetered wire), and a VPN reports as `vpn`
/// with the real transport hidden — treated as Wi-Fi rather than blocking
/// every download, since the alternative is an app that quietly stops
/// fetching media the moment a VPN comes up.
NetworkClass resolveNetworkClass(
  List<ConnectivityResult> results, {
  required bool roaming,
}) {
  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return NetworkClass.offline;
  }
  if (results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet)) {
    return NetworkClass.wifi;
  }
  if (results.contains(ConnectivityResult.mobile)) {
    return roaming ? NetworkClass.roaming : NetworkClass.cellular;
  }
  if (results.contains(ConnectivityResult.vpn)) return NetworkClass.wifi;
  return NetworkClass.cellular;
}
