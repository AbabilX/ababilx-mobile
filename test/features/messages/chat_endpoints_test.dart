import 'package:ababilx/core/constants/api_constants.dart';
import 'package:ababilx/features/messages/data/chat_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('conversation endpoints never end in a slash', () {
    // Gin does not route `/api/chat/conversations/<id>/`; it answers the
    // trailing slash with a 307 redirect, which Dio raises as a bad response.
    // Deleting or renaming a personal group failed on exactly that.
    const independent = ChatEndpoints(independent: true);
    const workspace = ChatEndpoints(independent: false);

    test('an empty action addresses the conversation itself', () {
      expect(
        independent.action('c1', ''),
        '/api/chat/conversations/c1',
      );
      expect(workspace.action('c1', ''), '/api/teams/chat/channels/c1');
    });

    test('a named action still hangs off the conversation', () {
      expect(
        independent.action('c1', 'members/u2'),
        '/api/chat/conversations/c1/members/u2',
      );
      expect(
        independent.action('c1', 'read'),
        '/api/chat/conversations/c1/read',
      );
    });

    test('the path builder itself refuses to append nothing', () {
      expect(
        ApiConstants.independentChatConversationAction('c1', ''),
        ApiConstants.independentChatConversation('c1'),
      );
    });
  });
}
