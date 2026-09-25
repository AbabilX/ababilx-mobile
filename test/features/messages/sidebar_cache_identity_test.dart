import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a cached group row keeps its own photo and identity', () {
    final conv = ChatConversation.fromJson(const {
      'id': 'g1',
      'scope': 'personal',
      'type': 'group',
      'name': 'Team',
      'avatar_url': 'https://cdn.example/chat/g1/photo.jpg',
      'banner_url': 'https://cdn.example/chat/g1/banner.jpg',
      'description': 'hello',
      'edit_info_role': 'member',
      'add_members_role': 'member',
      'my_role': 'admin',
    });
    final back = ChatConversation.fromJson(conv.toJson());
    expect(back.avatarUrl, 'https://cdn.example/chat/g1/photo.jpg');
    expect(back.bannerUrl, 'https://cdn.example/chat/g1/banner.jpg');
    expect(back.description, 'hello');
    expect(back.editInfoRole, 'member');
    expect(back.addMembersRole, 'member');
    expect(back.myRole, 'admin');
  });
}
