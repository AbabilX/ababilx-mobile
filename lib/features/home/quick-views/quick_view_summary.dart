import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../data/home_chats.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/providers/local_share_providers.dart';
import '../data/home_drafts.dart';
import 'quick_views.dart';

/// What one card says under its title, and whether it asks for attention.
class QuickViewSummary {
  const QuickViewSummary(
    this.subtitle, {
    this.attention = false,
    this.alert = false,
  });

  final String subtitle;
  final bool attention;
  final bool alert;
}

String homeText(BuildContext context, WidgetRef ref, String key, [int? n]) {
  final text = AppTranslations.translate(context, ref, key);
  return n == null ? text : text.replaceAll('{n}', '$n');
}

QuickViewSummary summarizeQuickView(
  BuildContext context,
  WidgetRef ref,
  HomeQuickView view,
) {
  switch (view) {
    case HomeQuickView.drafts:
      final drafts = ref.watch(homeDraftsProvider).valueOrNull?.length ?? 0;
      final scheduled =
          ref.watch(homeScheduledProvider).valueOrNull ?? const [];
      final failed = scheduled.where((s) => s.failed).length;
      if (failed > 0) {
        return QuickViewSummary(
          homeText(context, ref, 'home_n_not_sent', failed),
          alert: true,
        );
      }
      final parts = [
        if (drafts > 0 || scheduled.isEmpty)
          homeText(context, ref, 'home_n_drafts', drafts),
        if (scheduled.isNotEmpty)
          homeText(context, ref, 'home_n_scheduled', scheduled.length),
      ];
      return QuickViewSummary(parts.join(' · '));
    case HomeQuickView.groups:
      final groups = ref.watch(homeGroupsProvider);
      final unread = unreadMessageCount(groups);
      return unread > 0
          ? QuickViewSummary(
              homeText(context, ref, 'home_n_new', unread),
              attention: true,
            )
          : QuickViewSummary(
              homeText(context, ref, 'home_n_groups', groups.length),
            );
    case HomeQuickView.flock:
      final feeds = ref.watch(homeFlockProvider);
      final unread = unreadMessageCount(feeds);
      return unread > 0
          ? QuickViewSummary(
              homeText(context, ref, 'home_n_new', unread),
              attention: true,
            )
          : QuickViewSummary(
              homeText(context, ref, 'home_n_feeds', feeds.length),
            );
    case HomeQuickView.localShare:
      final nearby =
          ref.watch(localSharePeersProvider).valueOrNull?.length ?? 0;
      final threads =
          ref.watch(localShareThreadsProvider).valueOrNull ??
          const <ShareThread>[];
      final unread = threads.fold(0, (n, t) => n + t.unread);
      if (unread > 0) {
        return QuickViewSummary(
          homeText(context, ref, 'home_n_new', unread),
          attention: true,
        );
      }
      return nearby > 0
          ? QuickViewSummary(
              homeText(context, ref, 'home_n_nearby', nearby),
              attention: true,
            )
          : QuickViewSummary(
              homeText(context, ref, 'home_n_devices', threads.length),
            );
  }
}
