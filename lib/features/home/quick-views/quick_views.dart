import 'package:hugeicons/hugeicons.dart';

/// The cards along the top of Home (Slack's "quick views"). Each one opens
/// its own page. Only views with something real behind them are listed —
/// Threads, Tasks, Saved and Pins join when their server lists exist, since a
/// card that opens nothing is worse than a missing one. Unread is not a card:
/// the focus card above the row says it louder. Locked chats only appear while
/// at least one chat is locked on this phone.
enum HomeQuickView { drafts, groups, flock, localShare, locked }

/// One shortcut's label, icon and route. Icons take the chip's ink colour —
/// no per-view accent or circle fill.
class QuickViewSpec {
  const QuickViewSpec({
    required this.labelKey,
    required this.icon,
    required this.route,
  });

  /// [AppTranslations] key of the card's title.
  final String labelKey;
  final List<List<dynamic>> icon;
  final String route;
}

const Map<HomeQuickView, QuickViewSpec> quickViewSpecs = {
  HomeQuickView.drafts: QuickViewSpec(
    labelKey: 'home_drafts',
    icon: HugeIcons.strokeRoundedSent,
    route: '/home/drafts',
  ),
  HomeQuickView.groups: QuickViewSpec(
    labelKey: 'home_groups',
    icon: HugeIcons.strokeRoundedUserGroup,
    route: '/home/groups',
  ),
  HomeQuickView.flock: QuickViewSpec(
    labelKey: 'chat_filter_webhooks',
    icon: HugeIcons.strokeRoundedWebhook,
    route: '/home/flock',
  ),
  HomeQuickView.localShare: QuickViewSpec(
    labelKey: 'chat_filter_local_share',
    icon: HugeIcons.strokeRoundedWifi01,
    route: '/local-share',
  ),
  HomeQuickView.locked: QuickViewSpec(
    labelKey: 'home_locked',
    icon: HugeIcons.strokeRoundedSquareLock02,
    route: '/messages/locked',
  ),
};

/// Stored order applied to [HomeQuickView.values]: a view the stored order has
/// never heard of (added by a newer build) keeps its default place after the
/// known ones.
List<HomeQuickView> orderQuickViews(List<String> order) {
  int rank(HomeQuickView v) {
    final i = order.indexOf(v.name);
    return i < 0 ? order.length + v.index : i;
  }

  return [...HomeQuickView.values]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// [arranged] with Locked left out while this phone has no locked chat —
/// a card that opens an empty folder is worse than a missing one.
List<HomeQuickView> visibleQuickViews(
  List<HomeQuickView> arranged, {
  required bool hasLocked,
}) => [
  for (final v in arranged)
    if (v != HomeQuickView.locked || hasLocked) v,
];
