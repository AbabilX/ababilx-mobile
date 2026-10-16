import 'package:ababilx/features/messages/chat-forward/forward_resend.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/profile/delivery/delivery_only.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Delivery-only chat (server 0173): `held` is storage, `private_chat` is the
// quiet rules. Custody and private ops read heldForPhones; nothing a user may
// do with a message reads `held`.

ChatMessage _msg(Map<String, dynamic> extra) => ChatMessage.fromJson({
  'id': 'm1',
  'conversation_id': 'c1',
  'user_id': 'u1',
  'body': 'hi',
  'created_at': '2026-10-16T00:00:00Z',
  ...extra,
});

DioException _status(int code) => DioException(
  requestOptions: RequestOptions(path: '/forward'),
  response: Response(
    requestOptions: RequestOptions(path: '/forward'),
    statusCode: code,
  ),
);

void main() {
  resendRules();
  deliveryStrings();
  test('held is read, kept on disk, and is not private chat', () {
    final held = _msg({'held': true});
    expect(held.held, isTrue);
    expect(held.privateChat, isFalse);
    expect(held.heldForPhones, isTrue);
    final back = ChatMessage.fromJson(held.toJson());
    expect(back.held, isTrue);
    expect(back, equals(held));
  });

  test('a private-chat message is held for the phones too', () {
    final quiet = _msg({'private_chat': true});
    expect(quiet.heldForPhones, isTrue);
    expect(_msg({}).heldForPhones, isFalse);
  });

  test('a 404 forward of a held message falls back to the local copy', () {
    expect(sourceLeftServer(_status(404), _msg({'held': true})), isTrue);
    expect(sourceLeftServer(_status(404), _msg({})), isFalse);
    expect(sourceLeftServer(_status(403), _msg({'held': true})), isFalse);
    expect(sourceLeftServer(StateError('x'), _msg({'held': true})), isFalse);
  });
}

ChatConversation _conv(Map<String, dynamic> extra) => ChatConversation.fromJson(
  {'id': 'c1', 'type': 'group', 'scope': 'personal', ...extra},
);

void resendRules() {
  group('a forward re-sent from this phone keeps the server rules', () {
    test('an ordinary message of mine goes', () {
      expect(
        resendRefusal(
          _msg({'held': true}),
          source: _conv({}),
          currentUserId: 'u1',
        ),
        isNull,
      );
    });
    test('a private-chat message never goes', () {
      expect(
        resendRefusal(
          _msg({'private_chat': true}),
          source: null,
          currentUserId: 'u1',
        ),
        isNotNull,
      );
    });
    test('a timed photo never goes, mine included', () {
      final timed = _msg({
        'attachments': [
          {
            'id': 'a',
            'file_url': 'https://cdn/x.jpg',
            'file_name': 'x.jpg',
            'content_type': 'image/jpeg',
            'view_seconds': 5,
          },
        ],
      });
      expect(
        resendRefusal(timed, source: null, currentUserId: 'u1'),
        isNotNull,
      );
    });
    test("someone else's no-save photo stays with them", () {
      final noSave = _msg({
        'attachments': [
          {
            'id': 'a',
            'file_url': 'https://cdn/x.jpg',
            'file_name': 'x.jpg',
            'content_type': 'image/jpeg',
            'no_save': true,
          },
        ],
      });
      expect(resendRefusal(noSave, source: null, currentUserId: 'u1'), isNull);
      expect(
        resendRefusal(noSave, source: null, currentUserId: 'me'),
        isNotNull,
      );
    });
    test('a private group forwards nothing out', () {
      expect(
        resendRefusal(
          _msg({}),
          source: _conv({'group_privacy': true}),
          currentUserId: 'u1',
        ),
        isNotNull,
      );
    });
  });
}

void deliveryStrings() {
  test(
    'every delivery-only wording exists in both languages, beside its base',
    () {
      for (final lang in ['en', 'bn']) {
        final keys = AppTranslations.keysOf(lang);
        final variants = keys.where((k) => k.endsWith('_delivery'));
        expect(variants, isNotEmpty);
        for (final variant in variants) {
          final base = variant.substring(
            0,
            variant.length - '_delivery'.length,
          );
          expect(keys, contains(base), reason: '$lang: $variant has no base');
        }
        for (final k in [
          'delivery_backup_notice_title',
          'delivery_backup_notice_body',
          'delivery_backup_off_warning',
        ]) {
          expect(keys, contains(k), reason: '$lang: $k');
        }
      }
      expect(
        AppTranslations.keysOf(
          'bn',
        ).where((k) => k.endsWith('_delivery')).toSet(),
        AppTranslations.keysOf(
          'en',
        ).where((k) => k.endsWith('_delivery')).toSet(),
      );
      expect(deliveryKey('x', deliveryOnly: false), 'x');
      expect(deliveryKey('x', deliveryOnly: true), 'x_delivery');
    },
  );
}
