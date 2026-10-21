import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quick-views/quick_view_summary.dart';
import 'home_drafts_list.dart';
import 'home_page_scaffold.dart';

/// Home's Drafts page; the list itself is [HomeDraftsList].
class HomeDraftsPage extends ConsumerWidget {
  const HomeDraftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => HomePageScaffold(
    title: homeText(context, ref, 'home_drafts'),
    body: const HomeDraftsList(),
  );
}
