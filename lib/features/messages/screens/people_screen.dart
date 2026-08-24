import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-people/connections_tab.dart';
import '../chat-people/find_people_tab.dart';
import '../chat-people/requests_tab.dart';
import '../providers/chat_connections_provider.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(chatConnectionsProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatConnectionsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppTranslations.translate(context, ref, 'chat_people')),
          bottom: TabBar(
            tabs: [
              Tab(
                text: AppTranslations.translate(
                  context,
                  ref,
                  'chat_find_people',
                ),
              ),
              Tab(
                text:
                    '${AppTranslations.translate(context, ref, 'chat_requests')}'
                    '${state.requests.isEmpty ? '' : ' (${state.requests.length})'}',
              ),
              Tab(
                text: AppTranslations.translate(
                  context,
                  ref,
                  'chat_connections',
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [FindPeopleTab(), RequestsTab(), ConnectionsTab()],
        ),
      ),
    );
  }
}
