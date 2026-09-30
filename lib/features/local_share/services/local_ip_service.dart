import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class LocalIpService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Gets a list of available local IPv4 addresses.
  Future<List<String>> getLocalIps() async {
    final ips = <String>{};

    // 1. Try network_info_plus first for active Wi-Fi IP
    final wifiIp = await _wifiIp();
    if (wifiIp != null) ips.add(wifiIp);

    // 2. Scan native NetworkInterface list
    for (final interface in await _interfaces()) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && _isValidIpv4(addr.address)) {
          ips.add(addr.address);
        }
      }
    }

    return ips.toList();
  }

  /// The addresses worth sweeping for peers: Wi-Fi, a hotspot, ethernet, USB
  /// or Bluetooth tethering — never the cellular radio.
  ///
  /// [getLocalIps] includes the mobile-data interface (`rmnet*`, `ccmni*`),
  /// and the subnet sweep used to run over it on every launch and resume:
  /// 253 HTTP probes into the carrier's network, each one keeping the modem
  /// awake, for peers that can never be there.
  Future<List<String>> getLanIps() async {
    final ips = <String>{};
    final wifiIp = await _wifiIp();
    if (wifiIp != null && isPrivateIpv4(wifiIp)) ips.add(wifiIp);
    for (final interface in await _interfaces()) {
      if (!isLanInterface(interface.name)) continue;
      for (final addr in interface.addresses) {
        if (_isValidIpv4(addr.address) && isPrivateIpv4(addr.address)) {
          ips.add(addr.address);
        }
      }
    }
    return ips.toList();
  }

  Future<String?> _wifiIp() async {
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && _isValidIpv4(wifiIp)) {
        return wifiIp;
      }
    } catch (_) {
      // Ignore network info error on non-supported platforms/emulators
    }
    return null;
  }

  Future<List<NetworkInterface>> _interfaces() async {
    try {
      return await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Calculates subnet prefix (e.g. "192.168.1" from "192.168.1.100").
  static String? getSubnet(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return null;
  }

  static bool _isValidIpv4(String ip) {
    if (ip.startsWith('127.') || ip == '0.0.0.0') return false;
    final parts = ip.split('.');
    return parts.length == 4 && parts.every((p) => int.tryParse(p) != null);
  }
}

/// Interface names that are a local network: Wi-Fi (`wlan`, iOS `en`), a
/// hotspot this phone serves (`swlan`, `ap`, iOS `bridge`), ethernet and
/// tethering. Cellular (`rmnet`, `ccmni`, iOS `pdp_ip`), its IPv4 shim
/// (`v4-`, `clat`) and VPN tunnels are not.
bool isLanInterface(String name) {
  const lan = [
    'wlan',
    'swlan',
    'ap',
    'eth',
    'rndis',
    'usb',
    'bt-pan',
    'en',
    'bridge',
  ];
  final lower = name.toLowerCase();
  return lan.any(lower.startsWith);
}

/// RFC 1918 only. Carrier-grade NAT (100.64/10) is a cellular address.
bool isPrivateIpv4(String ip) {
  final parts = ip.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return false;
  final a = parts[0]!, b = parts[1]!;
  return a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}
