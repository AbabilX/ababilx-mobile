import 'package:flutter/material.dart';

import '../group-privacy/group_privacy_lock.dart';
import 'conversation_media_tab.dart';

/// Everything ever shared in one conversation, behind "See all".
///
/// Two tabs rather than one mixed list: the grid answers "where is that photo"
/// and a list answers "where is that PDF", and a photo laid out as a file row
/// is unfindable. Voice notes count as files — they are played from the row.
class ConversationMediaScreen extends StatelessWidget {
  const ConversationMediaScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return GroupPrivacyLock(
      conversationId: conversationId,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Shared media'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Media'),
                Tab(text: 'Files'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ConversationMediaTab(
                conversationId: conversationId,
                kind: 'media',
              ),
              ConversationMediaTab(
                conversationId: conversationId,
                kind: 'files',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
