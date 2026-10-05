import '../../services/local_ip_service.dart';
import '../client/share_client.dart';
import '../protocol/share_peer.dart';

/// Asks every address of each local /24 whether it is an AbabilX device.
///
/// The fallback for networks that drop multicast. Thirty-two at a time: a
/// phone that opens 250 sockets at once fails some of them for no reason
/// that has anything to do with the peer.
Future<void> sweepShareSubnets({
  required ShareClient client,
  required List<String> localAddresses,
  required void Function(SharePeer peer) onFound,
  int port = shareDefaultPort,
  int batch = 32,
}) async {
  final targets = <String>[];
  for (final local in localAddresses) {
    final subnet = LocalIpService.getSubnet(local);
    if (subnet == null || !isPrivateIpv4(local)) continue;
    for (var host = 1; host <= 254; host++) {
      final ip = '$subnet.$host';
      if (ip != local) targets.add(ip);
    }
  }
  for (var i = 0; i < targets.length; i += batch) {
    final end = i + batch > targets.length ? targets.length : i + batch;
    await Future.wait([
      for (final ip in targets.sublist(i, end))
        client.info(ip, port, timeout: const Duration(milliseconds: 600)).then((
          peer,
        ) {
          if (peer != null) onFound(peer);
        }),
    ]);
  }
}
