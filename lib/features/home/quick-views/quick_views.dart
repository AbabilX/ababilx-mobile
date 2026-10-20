import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// The cards along the top of Home (Slack's "quick views"). Each one opens
/// its own page. Only views with something real behind them are listed —
/// Threads, Tasks, Saved and Pins join when their server lists exist, since a
/// card that opens nothing is worse than a missing one. Unread is not a card:
/// the focus card above the row says it louder.
enum HomeQuickView { drafts, groups, flock, localShare }

/// One shortcut's label, icon, route and pastel accent (mock: blue / green /
/// purple / teal).
class QuickViewSpec {
  const QuickViewSpec({
    required this.labelKey,
    required this.icon,
    required this.route,
    required this.accent,
    required this.accentFill,
  });

  /// [AppTranslations] key of the card's title.
  final String labelKey;
  final List<List<dynamic>> icon;
  final String route;

  /// Icon colour.
  final Color accent;

  /// Soft circle behind the icon.
  final Color accentFill;
}

const Map<HomeQuickView, QuickViewSpec> quickViewSpecs = {
  HomeQuickView.drafts: QuickViewSpec(
    labelKey: 'home_drafts',
    icon: HugeIcons.strokeRoundedSent,
    route: '/home/drafts',
    accent: Color(0xFF3B82F6),
    accentFill: Color(0xFFDBEAFE),
  ),
  HomeQuickView.groups: QuickViewSpec(
    labelKey: 'home_groups',
    icon: HugeIcons.strokeRoundedUserGroup,
    route: '/home/groups',
    accent: Color(0xFF16A34A),
    accentFill: Color(0xFFDCFCE7),
  ),
  HomeQuickView.flock: QuickViewSpec(
    labelKey: 'chat_filter_webhooks',
    icon: HugeIcons.strokeRoundedWebhook,
    route: '/home/flock',
    accent: Color(0xFF9333EA),
    accentFill: Color(0xFFF3E8FF),
  ),
  HomeQuickView.localShare: QuickViewSpec(
    labelKey: 'chat_filter_local_share',
    icon: HugeIcons.strokeRoundedWifi01,
    route: '/local-share',
    accent: Color(0xFF0D9488),
    accentFill: Color(0xFFCCFBF1),
  ),
};

/// Stored order and hidden set applied to [HomeQuickView.values]: a view the
/// stored order has never heard of (added by a newer build) keeps its default
/// place after the known ones, and shows until the user turns it off.
List<HomeQuickView> orderQuickViews(List<String> order) {
  int rank(HomeQuickView v) {
    final i = order.indexOf(v.name);
    return i < 0 ? order.length + v.index : i;
  }

  return [...HomeQuickView.values]..sort((a, b) => rank(a).compareTo(rank(b)));
}
