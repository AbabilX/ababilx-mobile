import 'package:ababilx/features/jpack/data/jpack_status.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _sentAt(String createdAt) => ChatMessage(
  id: 'm1',
  conversationId: 'c1',
  userId: 'u1',
  body: '',
  createdAt: createdAt,
);

void main() {
  final sent = DateTime.utc(2026, 9, 1, 10);
  final message = _sentAt(sent.toIso8601String());

  test('claimable for 48 hours, expired from the 48th hour on', () {
    final almost = sent.add(const Duration(hours: 47, minutes: 59));
    expect(jpackIsExpired(message, now: almost), isFalse);
    expect(jpackTimeLeft(message, now: almost), const Duration(minutes: 1));
    expect(jpackIsExpired(message, now: sent.add(jpackLifetime)), isTrue);
    expect(
      jpackTimeLeft(message, now: sent.add(const Duration(days: 9))),
      Duration.zero,
    );
  });

  test('an unknown send time never expires by mistake', () {
    expect(jpackIsExpired(_sentAt('')), isFalse);
  });

  test('opening in time beats expiry; ours never reads as expired', () {
    expect(
      jpackStatus(isOwn: false, claimed: true, expired: true),
      JPackStatus.opened,
    );
    expect(
      jpackStatus(isOwn: false, claimed: false, expired: true),
      JPackStatus.expired,
    );
    expect(
      jpackStatus(isOwn: false, claimed: false, expired: false),
      JPackStatus.claimable,
    );
    expect(
      jpackStatus(isOwn: true, claimed: false, expired: true),
      JPackStatus.claimClosed,
    );
    expect(
      jpackStatus(isOwn: true, claimed: false, expired: false),
      JPackStatus.sent,
    );
  });
}
