import 'dart:convert';

import 'package:ababilx/features/local_share/engine/protocol/share_envelope.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_file.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_ids.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_peer.dart';
import 'package:flutter_test/flutter_test.dart';

// These strings are the fixtures of LOCAL_SHARE_PROTOCOL.md. The desktop's
// Rust tests pin the same bytes; change them only together.
const _announce =
    '{"app":"ababilx","v":1,"device_id":"ababilx_0123abcd","name":"Murad Pixel","device_type":"mobile","port":12045,"user_id":"u-1","announce":true}';
const _reply =
    '{"app":"ababilx","v":1,"device_id":"ababilx_0123abcd","name":"Murad Pixel","device_type":"mobile","port":12045,"announce":false}';
const _envelope =
    '{"id":"0f8fad5b-d9cb-469f-a165-70867728950e","kind":"folder","sent_at":1790000000000,"text":"here","folder_name":"Trip","files":[{"id":"f1aaaaaa","name":"a.jpg","size":1234,"mime":"image/jpeg","rel_path":"day1/a.jpg","width":800,"height":600},{"id":"f2bbbbbb","name":"v.m4a","size":9,"mime":"audio/mp4","rel_path":"v.m4a","duration_ms":4200}]}';

Map<String, dynamic> _folder(Map<String, dynamic> file) => {
  'id': 'aaaaaaaa',
  'kind': 'folder',
  'sent_at': 1,
  'folder_name': 'F',
  'files': [file],
};

void main() {
  test('announce and reply encode to the fixture bytes', () {
    const peer = SharePeer(
      deviceId: 'ababilx_0123abcd',
      name: 'Murad Pixel',
      deviceType: 'mobile',
      port: 12045,
      userId: 'u-1',
    );
    expect(peer.encode(announce: true), _announce);
    const private = SharePeer(
      deviceId: 'ababilx_0123abcd',
      name: 'Murad Pixel',
      deviceType: 'mobile',
      port: 12045,
    );
    expect(private.encode(announce: false), _reply);
  });

  test('a peer round-trips and a stock LocalSend datagram is ignored', () {
    final peer = SharePeer.fromJson(jsonDecode(_announce), ip: '192.168.1.9');
    expect(peer!.name, 'Murad Pixel');
    expect(peer.userId, 'u-1');
    expect(peer.ip, '192.168.1.9');
    expect(isShareAnnounce(jsonDecode(_announce)), isTrue);
    expect(isShareAnnounce(jsonDecode(_reply)), isFalse);
    expect(
      SharePeer.fromJson({'alias': 'PC', 'fingerprint': 'x', 'port': 53317}),
      isNull,
    );
  });

  test('a name loses controls and bidi overrides, and is capped', () {
    expect(cleanShareName('  Mu\u202Erad \n Pixel '), 'Murad Pixel');
    expect(cleanShareName('\u200B\u200B'), isNull);
    expect(cleanShareName('x' * 90)!.length, shareNameMaxLength);
  });

  test('the envelope round-trips to the fixture bytes', () {
    final envelope = ShareEnvelope.fromJson(jsonDecode(_envelope))!;
    expect(envelope.kind, ShareKind.folder);
    expect(envelope.files[0].relPath, 'day1/a.jpg');
    expect(envelope.files[1].durationMs, 4200);
    expect(envelope.totalBytes, 1243);
    expect(envelope.encode(), _envelope);
  });

  test('paths that could leave the folder are refused', () {
    Map<String, dynamic> file(String rel, [String name = 'a']) => {
      'id': 'bbbbbbbb',
      'name': name,
      'size': 1,
      'mime': 'a/b',
      'rel_path': rel,
    };
    for (final rel in ['../x', '/etc/x', 'a//b', 'a/./b', r'a\b', '']) {
      expect(ShareEnvelope.fromJson(_folder(file(rel))), isNull, reason: rel);
    }
    for (final name in ['a/b', r'a\b', '..', '']) {
      expect(
        ShareEnvelope.fromJson(_folder(file('ok', name))),
        isNull,
        reason: name,
      );
    }
    expect(ShareEnvelope.fromJson(_folder(file('ok/fine.txt'))), isNotNull);
    expect(cleanShareRelPath('a/b/c.txt'), 'a/b/c.txt');
  });

  test('ids and kinds are checked', () {
    expect(isShareId('../../x'), isFalse);
    expect(isShareId('short'), isFalse);
    expect(
      ShareEnvelope.fromJson({
        'id': '../../xxxx',
        'kind': 'text',
        'sent_at': 1,
        'text': 'a',
      }),
      isNull,
    );
    expect(
      ShareEnvelope.fromJson({'id': 'aaaaaaaa', 'kind': 'text', 'sent_at': 1}),
      isNull,
    );
    expect(
      ShareEnvelope.fromJson({
        'id': 'aaaaaaaa',
        'kind': 'delete',
        'sent_at': 1,
      }),
      isNull,
    );
    expect(
      ShareEnvelope.fromJson({
        'id': 'aaaaaaaa',
        'kind': 'delete',
        'sent_at': 1,
        'target_id': 'bbbbbbbb',
      })!.targetId,
      'bbbbbbbb',
    );
    // A loose file may not carry a path.
    expect(
      ShareEnvelope.fromJson({
        'id': 'aaaaaaaa',
        'kind': 'files',
        'sent_at': 1,
        'files': [
          {
            'id': 'bbbbbbbb',
            'name': 'a',
            'size': 1,
            'mime': 'a/b',
            'rel_path': 'x/a',
          },
        ],
      }),
      isNull,
    );
  });

  test('secrets are 256 bits and compared in full', () {
    final token = newPairToken();
    expect(token.length, 64);
    expect(newPairToken(), isNot(token));
    expect(sameSecret(token, token), isTrue);
    expect(sameSecret(token, '${token.substring(1)}0'), isFalse);
    expect(sameSecret(token, token.substring(1)), isFalse);
  });
}
