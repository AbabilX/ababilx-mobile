import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../services/local_ip_service.dart';
import '../protocol/share_peer.dart';

/// One decoded datagram and the address it came from.
typedef ShareDatagram = ({Object? json, String ip});

/// The UDP half of discovery: one listening socket joined to the group on
/// every LAN interface, and one sending socket per LAN address.
///
/// Sending from a socket bound to an interface's own address is what puts the
/// announce on THAT network; a single wildcard socket goes out wherever the
/// default route points, which on a phone with mobile data on is the carrier.
class ShareMulticast {
  RawDatagramSocket? _listener;
  final _senders = <RawDatagramSocket>[];
  final _incoming = StreamController<ShareDatagram>.broadcast();
  final _group = InternetAddress(shareMulticastGroup);

  Stream<ShareDatagram> get incoming => _incoming.stream;
  bool get open => _listener != null;

  /// The private IPv4 addresses of this device's LAN interfaces.
  List<String> localAddresses = const [];

  /// False when no LAN interface is up or the port could not be bound.
  Future<bool> start() async {
    if (_listener != null) return true;
    final interfaces = await _lanInterfaces();
    localAddresses = [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (isPrivateIpv4(a.address)) a.address,
    ];
    if (interfaces.isEmpty) return false;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        shareDefaultPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      socket.multicastLoopback = false;
      for (final interface in interfaces) {
        try {
          socket.joinMulticast(_group, interface);
        } catch (_) {}
      }
      socket.listen(_read, onError: (Object _) {});
      _listener = socket;
    } catch (_) {
      return false;
    }
    for (final address in localAddresses) {
      try {
        final sender = await RawDatagramSocket.bind(
          InternetAddress(address),
          0,
        );
        sender.multicastHops = 1;
        _senders.add(sender);
      } catch (_) {}
    }
    return true;
  }

  void _read(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _listener;
    Datagram? datagram;
    while ((datagram = socket?.receive()) != null) {
      final ip = datagram!.address.address;
      if (localAddresses.contains(ip)) continue;
      try {
        _incoming.add((json: jsonDecode(utf8.decode(datagram.data)), ip: ip));
      } catch (_) {
        // Not ours.
      }
    }
  }

  /// To everyone in the group, on every LAN interface.
  void broadcast(String payload) {
    final bytes = utf8.encode(payload);
    for (final sender in _senders) {
      try {
        sender.send(bytes, _group, shareDefaultPort);
      } catch (_) {}
    }
  }

  /// To one device that just announced itself.
  void reply(String payload, String ip) {
    final sender = _senders.isEmpty ? _listener : _senders.first;
    try {
      sender?.send(utf8.encode(payload), InternetAddress(ip), shareDefaultPort);
    } catch (_) {}
  }

  Future<void> stop() async {
    _listener?.close();
    _listener = null;
    for (final sender in _senders) {
      sender.close();
    }
    _senders.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _incoming.close();
  }

  static Future<List<NetworkInterface>> _lanInterfaces() async {
    try {
      final all = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      return [
        for (final i in all)
          if (isLanInterface(i.name) &&
              i.addresses.any((a) => isPrivateIpv4(a.address)))
            i,
      ];
    } catch (_) {
      return const [];
    }
  }
}
