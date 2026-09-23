import 'package:ababilx/core/network/network_class.dart';
import 'package:ababilx/features/attachments/auto_download/auto_download_settings.dart';
import 'package:ababilx/features/attachments/services/attachment_policy.dart';
import 'package:ababilx/features/calls/call_status_text.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:ababilx/features/ghost/protocol/ghost_item_rules.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/privacy-mode/privacy_media.dart';
import 'package:flutter_test/flutter_test.dart';

ChatAttachmentInput _input(String name, String type) => ChatAttachmentInput(
  fileUrl: 'https://assetsbox.ababilx.com/chat/c/$name',
  fileName: name,
  contentType: type,
  sizeBytes: 10,
);

VoiceCall _call({bool calleePrivacy = false}) => VoiceCall.fromJson({
  'id': 'c1',
  'conversation_id': 'conv',
  'caller_id': 'me',
  'callee_id': 'peer',
  'status': 'ringing',
  'expires_at': DateTime.now().toUtc().toIso8601String(),
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'callee_privacy': calleePrivacy,
});

void main() {
  group('call', () {
    test('a private callee reads Calling with the privacy label', () {
      final state = VoiceCallState(
        phase: VoiceCallPhase.outgoingRinging,
        call: _call(calleePrivacy: true),
        currentUserId: 'me',
      );
      expect(voiceCallStatusText(state), 'Calling… · Privacy mode on');
    });

    test('peerPrivate reads the other side of the call', () {
      final call = _call(calleePrivacy: true);
      expect(call.peerPrivate('me'), isTrue);
      expect(call.peerPrivate('peer'), isFalse);
    });
  });

  group('send rules', () {
    test('the server timer set matches Ghost Chat', () {
      expect(viewSecondsOf(GhostViewTimer.off), isNull);
      expect(viewSecondsOf(GhostViewTimer.once), 0);
      expect(viewSecondsOf(GhostViewTimer.s30), 30);
    });

    test(
      'a timer goes on photos only, and a timed photo is never saveable',
      () {
        final photos = applyPrivacyRules([
          _input('a.jpg', 'image/jpeg'),
        ], const GhostItemRules(timer: GhostViewTimer.s5, allowSave: true));
        expect(photos.single.viewSeconds, 5);
        expect(photos.single.noSave, isTrue);

        final mixed = applyPrivacyRules([
          _input('a.jpg', 'image/jpeg'),
          _input('b.pdf', 'application/pdf'),
        ], const GhostItemRules(timer: GhostViewTimer.s5));
        expect(mixed.every((a) => a.viewSeconds == null), isTrue);
        expect(mixed.every((a) => a.noSave), isTrue);
      },
    );

    test('the choice survives the outbox round trip', () {
      final a = _input(
        'a.jpg',
        'image/jpeg',
      ).withPolicy(viewSeconds: 0, noSave: true);
      final back = ChatAttachmentInput.fromJson(a.toJson());
      expect(back.viewSeconds, 0);
      expect(back.noSave, isTrue);
      expect(back.restricted, isTrue);
    });
  });

  group('received', () {
    ChatMessageAttachment parse(Map<String, dynamic> extra) =>
        ChatMessageAttachment.fromJson({
          'id': 'a1',
          'message_id': 'm1',
          'file_name': 'a.jpg',
          'file_url': 'https://assetsbox.ababilx.com/chat/c/a.jpg',
          'content_type': 'image/jpeg',
          'size_bytes': 10,
          ...extra,
        });

    test('protection flags parse and block the ordinary paths', () {
      final timed = parse({'view_seconds': 0});
      expect(timed.timed, isTrue);
      expect(timed.isProtected, isTrue);
      expect(parse({'no_save': true}).isProtected, isTrue);
      expect(parse({}).isProtected, isFalse);
    });

    test('a timed photo is never auto-downloaded', () {
      bool auto(ChatMessageAttachment a) => shouldAutoDownload(
        a,
        settings: AutoDownloadSettings.defaults,
        network: NetworkClass.wifi,
      );
      expect(auto(parse({})), isTrue);
      expect(auto(parse({'view_seconds': 5})), isFalse);
      expect(auto(parse({'expired': true, 'file_url': ''})), isFalse);
    });
  });
}
