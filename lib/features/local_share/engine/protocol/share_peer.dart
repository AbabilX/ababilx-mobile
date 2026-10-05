import 'dart:convert';

import 'share_ids.dart';

const shareApp = 'ababilx';
const shareProtocolVersion = 1;
const shareMulticastGroup = '224.0.0.167';
const shareDefaultPort = 12045;
const shareNameMaxLength = 40;

/// One AbabilX device on the local network, as it describes itself.
///
/// [userId] is a claim, never proved: show an account for it only when it is
/// one of the viewer's own accepted connections.
class SharePeer {
  const SharePeer({
    required this.deviceId,
    required this.name,
    required this.deviceType,
    required this.port,
    this.userId,
    this.ip = '',
  });

  final String deviceId;
  final String name;
  final String deviceType;
  final int port;
  final String? userId;

  /// Where the datagram or request came from; never part of the wire form.
  final String ip;

  SharePeer at(String address) => SharePeer(
    deviceId: deviceId,
    name: name,
    deviceType: deviceType,
    port: port,
    userId: userId,
    ip: address,
  );

  /// Key order is part of the protocol fixtures (LOCAL_SHARE_PROTOCOL.md).
  Map<String, dynamic> toJson({required bool announce}) => {
    'app': shareApp,
    'v': shareProtocolVersion,
    'device_id': deviceId,
    'name': name,
    'device_type': deviceType,
    'port': port,
    if (userId != null && userId!.isNotEmpty) 'user_id': userId,
    'announce': announce,
  };

  String encode({required bool announce}) =>
      jsonEncode(toJson(announce: announce));

  /// Null for anything that is not a well-formed AbabilX peer — a stock
  /// LocalSend client included.
  static SharePeer? fromJson(Object? json, {String ip = ''}) {
    if (json is! Map) return null;
    if (json['app'] != shareApp || json['v'] != shareProtocolVersion) {
      return null;
    }
    final id = json['device_id'];
    final name = cleanShareName(json['name']);
    final port = json['port'];
    final type = json['device_type'];
    if (!isShareId(id) || name == null) return null;
    if (port is! int || port < 1 || port > 65535) return null;
    final userId = json['user_id'];
    return SharePeer(
      deviceId: id as String,
      name: name,
      deviceType: type == 'desktop' ? 'desktop' : 'mobile',
      port: port,
      userId: userId is String && userId.isNotEmpty && userId.length <= 64
          ? userId
          : null,
      ip: ip,
    );
  }
}

/// Whether a decoded datagram asks for a reply.
bool isShareAnnounce(Object? json) => json is Map && json['announce'] == true;

final _invisible = RegExp(
  r'[\u0000-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2060-\u2069\uFEFF]',
  unicode: true,
);

/// A device name as it may be shown: controls and bidi overrides stripped,
/// whitespace collapsed, 1–[shareNameMaxLength] characters. Null when nothing
/// readable is left.
String? cleanShareName(Object? raw) {
  if (raw is! String) return null;
  final cleaned = raw
      .replaceAll(_invisible, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return null;
  final runes = cleaned.runes.toList();
  return runes.length <= shareNameMaxLength
      ? cleaned
      : String.fromCharCodes(runes.take(shareNameMaxLength)).trim();
}
