import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import '../models/device_model.dart';
import 'local_ip_service.dart';

class LocalDiscoveryService {
  static const String multicastGroupIp = '224.0.0.167';
  static const int defaultPort = 53317;

  final LocalIpService _ipService = LocalIpService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 600),
    receiveTimeout: const Duration(milliseconds: 600),
  ));

  RawDatagramSocket? _socket;
  StreamController<LocalDevice>? _discoveredDevicesController;
  bool _isListening = false;

  Stream<LocalDevice>? get onDeviceDiscovered => _discoveredDevicesController?.stream;

  /// Starts listening on the UDP Multicast socket.
  Future<void> startMulticastListener({
    required LocalDevice currentDevice,
  }) async {
    if (_isListening) return;
    _isListening = true;
    _discoveredDevicesController = StreamController<LocalDevice>.broadcast();

    try {
      final localIps = await _ipService.getLocalIps();
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        defaultPort,
        reuseAddress: true,
        reusePort: true,
      );

      final group = InternetAddress(multicastGroupIp);
      _socket?.joinMulticast(group);
      _socket?.multicastLoopback = false;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram == null) return;

          try {
            final rawMessage = utf8.decode(datagram.data);
            final Map<String, dynamic> json = jsonDecode(rawMessage) as Map<String, dynamic>;
            final senderIp = datagram.address.address;

            // Ignore own announcements
            final fingerprint = json['fingerprint'] as String? ?? '';
            if (fingerprint == currentDevice.fingerprint || localIps.contains(senderIp)) {
              return;
            }

            final device = LocalDevice.fromJson(json, ip: senderIp);
            _discoveredDevicesController?.add(device);
          } catch (_) {
            // Ignore malformed UDP datagrams
          }
        }
      });
    } catch (_) {
      // Multicast binding failed (or not supported on network interface)
    }
  }

  /// Broadcasts an announcement ping over UDP Multicast to nearby devices.
  Future<void> announce({
    required LocalDevice currentDevice,
  }) async {
    try {
      final group = InternetAddress(multicastGroupIp);
      final payload = jsonEncode({
        ...currentDevice.toJson(),
        'announcement': true,
      });
      final bytes = utf8.encode(payload);

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(bytes, group, defaultPort);
      socket.close();
    } catch (_) {
      // Multicast send failed
    }
  }

  /// Scans local subnet IPs over HTTP fallback if multicast is blocked by router AP isolation.
  Future<void> scanSubnet({
    required LocalDevice currentDevice,
    int port = defaultPort,
    Function(LocalDevice)? onFound,
  }) async {
    final localIps = await _ipService.getLocalIps();
    if (localIps.isEmpty) return;

    final futures = <Future<void>>[];

    for (final localIp in localIps) {
      final subnet = LocalIpService.getSubnet(localIp);
      if (subnet == null) continue;

      for (int i = 1; i <= 254; i++) {
        final targetIp = '$subnet.$i';
        if (targetIp == localIp) continue;

        futures.add(_probeDevice(
          targetIp: targetIp,
          port: port,
          currentDevice: currentDevice,
          onFound: onFound,
        ));
      }
    }

    await Future.wait(futures);
  }

  Future<void> _probeDevice({
    required String targetIp,
    required int port,
    required LocalDevice currentDevice,
    Function(LocalDevice)? onFound,
  }) async {
    try {
      final url = 'http://$targetIp:$port/api/localsend/v2/info';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final json = response.data as Map<String, dynamic>;
        final fingerprint = json['fingerprint'] as String? ?? '';

        if (fingerprint != currentDevice.fingerprint) {
          final device = LocalDevice.fromJson(json, ip: targetIp);
          _discoveredDevicesController?.add(device);
          onFound?.call(device);
        }
      }
    } catch (_) {
      // Host unreachable or not a LocalSend server
    }
  }

  /// Stops discovery socket listeners.
  Future<void> stop() async {
    _isListening = false;
    _socket?.close();
    _socket = null;
    await _discoveredDevicesController?.close();
    _discoveredDevicesController = null;
  }
}
