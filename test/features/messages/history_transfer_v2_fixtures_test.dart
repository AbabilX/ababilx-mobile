import 'dart:convert';
import 'dart:io';

import 'package:ababilx/features/attachments/data/models/attachment_url_key.dart';
import 'package:ababilx/features/messages/history-transfer/v2/history_merge.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixtures here are byte-for-byte copies of
/// `ababilx-server/docs/fixtures/*` and of the web repo's
/// `src/lib/history/fixtures/*`. A case that passes on one platform and not on
/// the other is a message that settles differently in a browser.
Map<String, dynamic> _fixture(String name) => Map<String, dynamic>.from(
  jsonDecode(File('test/fixtures/history_transfer/$name').readAsStringSync())
      as Map,
);

HistoryMergeSide? _side(Object? raw) {
  if (raw is! Map) return null;
  return HistoryMergeSide(
    raw['provenance'] == 'server'
        ? HistoryProvenance.server
        : HistoryProvenance.phone,
    HistoryMergeMessage.fromJson(Map<String, dynamic>.from(raw['message'] as Map)),
  );
}

void main() {
  group('merge contract (protocol section 7)', () {
    for (final raw in _fixture('history-transfer-v2-merge.json')['cases'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      test('row ${item['row']}: ${item['name']}', () {
        final decision = decideHistoryMerge(
          _side(item['existing']),
          _side(item['incoming'])!,
          (item['markers'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList(),
        );
        expect(decision.name, item['expect']);
      });
    }
  });

  group('attachment url key (the file identity across platforms)', () {
    for (final raw in _fixture('history-transfer-v2-url-key.json')['cases'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      test('"${item['url']}"', () {
        expect(normaliseAttachmentUrl(item['url'] as String), item['normalised']);
        expect(attachmentUrlKey(item['url'] as String), item['url_key']);
      });
    }
  });
}
