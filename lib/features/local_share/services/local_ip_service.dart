import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class LocalIpService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Gets a list of available local IPv4 addresses.
  Future<List<String>> getLocalIps() async {
    final ips = <String>{};

    // 1. Try network_info_plus first for active Wi-Fi IP
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && _isValidIpv4(wifiIp)) {
        ips.add(wifiIp);
      }
    } catch (_) {
      // Ignore network info error on non-supported platforms/emulators
    }

    // 2. Scan native NetworkInterface list
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && _isValidIpv4(addr.address)) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}

    return ips.toList();
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
