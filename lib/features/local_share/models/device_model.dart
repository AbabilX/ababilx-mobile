import 'package:equatable/equatable.dart';

/// Represents a peer device found on the local network running LocalSend or AbabilX.
class LocalDevice extends Equatable {
  final String alias;
  final String version;
  final String? deviceModel;
  final String deviceType; // 'mobile', 'desktop', 'web', 'headless', 'server'
  final String fingerprint; // Unique device fingerprint
  final String ip;
  final int port;
  final String protocol; // 'http' or 'https'
  final bool download;

  const LocalDevice({
    required this.alias,
    required this.version,
    this.deviceModel,
    required this.deviceType,
    required this.fingerprint,
    required this.ip,
    required this.port,
    required this.protocol,
    this.download = true,
  });

  /// Parse from LocalSend v2 JSON payload.
  factory LocalDevice.fromJson(Map<String, dynamic> json, {required String ip}) {
    return LocalDevice(
      alias: json['alias'] as String? ?? 'Unknown Device',
      version: json['version'] as String? ?? '2.1',
      deviceModel: json['deviceModel'] as String?,
      deviceType: json['deviceType'] as String? ?? 'mobile',
      fingerprint: json['fingerprint'] as String? ?? '',
      ip: ip,
      port: json['port'] as int? ?? 53317,
      protocol: json['protocol'] as String? ?? 'http',
      download: json['download'] as bool? ?? true,
    );
  }

  /// Convert to JSON payload compatible with LocalSend protocol v2.
  Map<String, dynamic> toJson() {
    return {
      'alias': alias,
      'version': version,
      if (deviceModel != null) 'deviceModel': deviceModel,
      'deviceType': deviceType,
      'fingerprint': fingerprint,
      'port': port,
      'protocol': protocol,
      'download': download,
    };
  }

  LocalDevice copyWith({
    String? alias,
    String? version,
    String? deviceModel,
    String? deviceType,
    String? fingerprint,
    String? ip,
    int? port,
    String? protocol,
    bool? download,
  }) {
    return LocalDevice(
      alias: alias ?? this.alias,
      version: version ?? this.version,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceType: deviceType ?? this.deviceType,
      fingerprint: fingerprint ?? this.fingerprint,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      download: download ?? this.download,
    );
  }

  @override
  List<Object?> get props => [
        alias,
        version,
        deviceModel,
        deviceType,
        fingerprint,
        ip,
        port,
        protocol,
        download,
      ];
}
