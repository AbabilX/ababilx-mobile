import 'package:ababilx/features/messages/chat-forward/forward_targets.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attachment_seal_harness.dart';

/// Forwarding an encrypted file (server 0168): the object is not uploaded
/// again, but its key is sealed again under each destination's own key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SealHarness h;
  setUp(() => h = SealHarness());

  ChatConversation dm(String id) => ChatConversation.fromJson({
    'id': id,
    'scope': 'personal',
    'type': 'dm',
    'created_at': '2026-10-06T00:00:00Z',
  });

  test('each destination gets the key sealed under its own key', () async {
    final vault = await h.unlocked();
    final source = await vault.decryptMessage(
      await h.send(vault, 'dm', files: [SealHarness.upload()]),
      'me',
    );
    final targets = await buildForwardTargets(
      vault: vault,
      currentUserId: 'me',
      text: source.body,
      conversations: [dm('other')],
      attachments: source.attachments,
    );
    final target = targets.single;
    // Sealed even with no text: the file key names the body's key version.
    final message = target['message'] as Map<String, dynamic>;
    expect(message['encrypted_body'], isNotEmpty);
    final seal = (target['attachments'] as List).single as Map<String, dynamic>;
    expect(seal['file_url'], 'https://cdn/chat/dm/1.bin');
    expect(seal['enc_meta'], isNot(source.attachments.single.encMeta));

    // The destination's reader opens it there, and nowhere else.
    final copy = source.attachments.single.forwardedAs(
      seal,
      message['encryption_key_version'] as int,
    );
    final there = await vault.openAttachment(
      conversationId: 'other',
      currentUserId: 'me',
      attachment: copy,
    );
    expect(there.fileName, 'IMG_0012.jpg');
    final here = await vault.openAttachment(
      conversationId: 'dm',
      currentUserId: 'me',
      attachment: copy,
    );
    expect(here.needsKey, isTrue);
  });

  test('a file whose key never opened here is not forwarded', () async {
    final vault = await h.unlocked();
    final sealed = await h.send(vault, 'dm', files: [SealHarness.upload()]);
    await expectLater(
      buildForwardTargets(
        vault: vault,
        currentUserId: 'me',
        text: '',
        conversations: [dm('other')],
        attachments: sealed.attachments,
      ),
      throwsStateError,
    );
  });

  test('an encrypted file is not forwarded into a plaintext chat', () async {
    final vault = await h.unlocked();
    final source = await vault.decryptMessage(
      await h.send(vault, 'dm', files: [SealHarness.upload()]),
      'me',
    );
    final feed = ChatConversation.fromJson({
      'id': 'feed',
      'scope': 'personal',
      'type': 'webhook',
      'name': 'Orders',
      'created_at': '2026-10-06T00:00:00Z',
    });
    await expectLater(
      buildForwardTargets(
        vault: vault,
        currentUserId: 'me',
        text: '',
        conversations: [feed],
        attachments: source.attachments,
      ),
      throwsStateError,
    );
  });
}
