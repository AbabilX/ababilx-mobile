import 'package:ababilx/features/local_share/services/local_ip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local networks are swept', () {
    for (final name in [
      'wlan0',
      'swlan0',
      'ap0',
      'eth0',
      'rndis0',
      'en0',
      'bridge100',
    ]) {
      expect(isLanInterface(name), isTrue, reason: name);
    }
  });

  test('the cellular radio, its shim and VPNs are never swept', () {
    for (final name in [
      'rmnet_data0',
      'ccmni0',
      'pdp_ip0',
      'v4-rmnet_data0',
      'clat4',
      'tun0',
      'utun3',
      'dummy0',
    ]) {
      expect(isLanInterface(name), isFalse, reason: name);
    }
  });

  test('RFC 1918 only', () {
    expect(isPrivateIpv4('192.168.1.20'), isTrue);
    expect(isPrivateIpv4('10.0.0.5'), isTrue);
    expect(isPrivateIpv4('172.16.0.1'), isTrue);
    expect(isPrivateIpv4('172.31.255.1'), isTrue);
    expect(isPrivateIpv4('172.32.0.1'), isFalse);
    expect(isPrivateIpv4('100.64.12.9'), isFalse, reason: 'carrier-grade NAT');
    expect(isPrivateIpv4('8.8.8.8'), isFalse);
    expect(isPrivateIpv4('not.an.ip.x'), isFalse);
  });
}
