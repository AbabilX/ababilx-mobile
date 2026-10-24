import 'package:ababilx/features/messages/data/models/chat_connection.dart';
import 'package:ababilx/features/settings/message-policy/message_policy_provider.dart';
import 'package:ababilx/shared/text/display_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a nameless person reads as their handle, then AbabilX user', () {
    expect(personLabel('Rahim', 'rahim'), 'Rahim');
    expect(personLabel('', 'rahim'), '@rahim');
    expect(personLabel('  ', ''), namelessUserLabel);
  });

  test('people rows fold the handle into an empty name', () {
    final named = ChatUserSummary.fromJson({'name': 'Rahim', 'username': 'r'});
    final handle = ChatUserSummary.fromJson({'name': '', 'username': 'rahim'});
    final nobody = ChatUserSummary.fromJson({'name': ''});
    expect(named.name, 'Rahim');
    expect(handle.name, '@rahim');
    expect(nobody.name, namelessUserLabel);
  });

  test('connections_only and message policy wire values', () {
    final user = ChatUserSummary.fromJson({'connections_only': true});
    expect(user.connectionsOnly, isTrue);
    expect(MessagePolicy.fromWire('connections'), MessagePolicy.connections);
    expect(MessagePolicy.fromWire(null), MessagePolicy.requests);
    expect(MessagePolicy.connections.wire, 'connections');
  });
}
