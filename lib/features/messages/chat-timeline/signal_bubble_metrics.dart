import 'package:flutter/painting.dart';

import '../chat_utils.dart';

/// Signal's own conversation-item measurements, in logical pixels (Android dp
/// and Flutter lp are the same unit).
///
/// Sources, for anyone checking them against the reference checkout:
/// `message_corner_radius` 18, `message_corner_collapse_radius` 4,
/// `message_bubble_horizontal_padding` 12, `message_bubble_top_padding` 7,
/// `message_bubble_bottom_padding` 7, `message_bubble_edge_margin` 32,
/// `conversation_vertical_message_spacing_default` 8 /
/// `..._collapse` 1, `conversation_group_left_gutter` 52,
/// `conversation_individual_left_gutter` 16,
/// `conversation_individual_received_left_gutter` 8,
/// `conversation_item_avatar_size` 28, `conversation_item_body_text_size` 16,
/// `conversation_item_date_text_size` 12.
class SignalBubbleMetrics {
  const SignalBubbleMetrics._();

  static const bigRadius = 18.0;
  static const smallRadius = 4.0;

  static const horizontalPadding = 12.0;
  static const topPadding = 7.0;
  static const bottomPadding = 7.0;

  /// Distance the far edge of a bubble keeps from the opposite screen edge —
  /// this is what stops a long message spanning the full width.
  static const edgeMargin = 32.0;

  static const spacingDefault = 8.0;
  static const spacingCollapsed = 1.0;

  static const listSideGutter = 16.0;
  static const receivedSideGutter = 8.0;

  /// Left inset an incoming bubble carries in a group, leaving room for the
  /// avatar that sits under the *last* message of the cluster.
  static const groupLeftGutter = 52.0;

  static const avatarSize = 28.0;
  static const bodyTextSize = 16.0;
  static const footerTextSize = 12.0;

  /// Media inside a bubble (`media_bubble_max_width` 240,
  /// `media_bubble_max_height` 420, `media_bubble_min_width_solo` 150,
  /// `media_bubble_min_width_with_content` 240, `media_bubble_min_height` 100,
  /// `media_bubble_default_dimens` 210).
  ///
  /// Timeline thumbnails use a stable default frame because attachments do
  /// not carry dimensions. Captions widen that frame before bytes arrive;
  /// albums use their predetermined cells and galleries keep original ratios.
  /// A caption-less solo photo/video fits inside [mediaMaxWidth] ×
  /// [mediaMaxHeight] keeping aspect ([soloMediaSize]); so does one with
  /// a caption's outer cap. [mediaMaxHeight] is a ceiling, not a size to
  /// always reach.
  static const mediaMaxWidth = 240.0;
  static const mediaMaxHeight = 420.0;
  static const mediaMinWidthSolo = 150.0;
  static const mediaMinWidthWithCaption = 240.0;
  static const mediaMinHeight = 100.0;

  /// Stable solo thumbnail height and default width, including after download.
  static const mediaDefaultSize = 210.0;

  /// Quote block (`quote_corner_radius_large` 10, `..._bottom` 4,
  /// `quote_thumb_size` 60).
  static const quoteRadius = 10.0;
  static const quoteInnerRadius = 4.0;
  static const quoteThumbSize = 60.0;
  static const quoteBarWidth = 4.0;

  /// Swipe-to-reply: the drag passes at 64 and cannot travel beyond 96.
  static const swipeTriggerDx = 64.0;
  static const swipeMaxDx = 96.0;
  static const replyIconSize = 38.0;
}

/// Corner radii for one bubble, matching `V2ConversationItemShape`.
///
/// A cluster keeps its outer corners round and collapses the ones facing the
/// neighbouring bubble on the sender's own side — the right for your messages,
/// the left for theirs — which is what makes a run read as one block.
BorderRadius signalBubbleRadius({
  required MessageClusterPosition position,
  required bool isOwn,
}) {
  const big = Radius.circular(SignalBubbleMetrics.bigRadius);
  const small = Radius.circular(SignalBubbleMetrics.smallRadius);

  return switch (position) {
    MessageClusterPosition.single => const BorderRadius.all(big),
    MessageClusterPosition.start => BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomRight: isOwn ? small : big,
      bottomLeft: isOwn ? big : small,
    ),
    MessageClusterPosition.end => BorderRadius.only(
      topLeft: isOwn ? big : small,
      topRight: isOwn ? small : big,
      bottomRight: big,
      bottomLeft: big,
    ),
    MessageClusterPosition.middle => BorderRadius.only(
      topLeft: isOwn ? big : small,
      topRight: isOwn ? small : big,
      bottomRight: isOwn ? small : big,
      bottomLeft: isOwn ? big : small,
    ),
  };
}

/// Gap above a row. Signal collapses it to 1 inside a cluster and keeps 8
/// between separate messages.
double signalBubbleTopSpacing(MessageClusterPosition position) =>
    switch (position) {
      MessageClusterPosition.single ||
      MessageClusterPosition.start => SignalBubbleMetrics.spacingDefault,
      MessageClusterPosition.middle ||
      MessageClusterPosition.end => SignalBubbleMetrics.spacingCollapsed,
    };
