/// Signal's own measurements for the long-press overlay, in logical pixels
/// (Android dp and Flutter lp are the same unit).
///
/// Sources, for anyone checking the numbers against the reference checkout:
/// `reaction_scrubber_width` 320, `conversation_reaction_scrub_horizontal_margin`
/// 16, the scrubber background is `?attr/actionBarSize` tall with a 30dp
/// corner, `signal_context_menu` has `minWidth` 200 and an 18dp corner, and its
/// rows are a 24dp icon with 16dp side padding and 13dp above and below.
class SignalMenuMetrics {
  const SignalMenuMetrics._();

  static const barWidth = 320.0;
  static const barHeight = 56.0;
  static const barRadius = 30.0;
  static const barTopPadding = 32.0;

  /// Gap Signal leaves between the bubble and the bar it floats above.
  static const barOffset = 48.0;

  /// The one padding used between every pair of overlay pieces.
  static const menuPadding = 12.0;
  static const horizontalMargin = 16.0;

  static const menuMinWidth = 200.0;
  static const menuRadius = 18.0;
  static const menuRowHeight = 50.0;
  static const menuIconSize = 24.0;
  static const menuRowPadding = 16.0;
  static const menuIconGap = 16.0;

  /// Scrubbing: an emoji under the finger grows to 1.5 and lifts 25
  /// (`conversation_reaction_scrub_vertical_translation`). The finger must
  /// leave a 40 deadzone around where it landed
  /// (`conversation_reaction_touch_deadzone_size`) before anything is picked,
  /// and the scrub band runs from the bar down to 30 below that point
  /// (`conversation_reaction_scrub_deadzone_distance_from_touch_bottom`).
  static const emojiGrowScale = 1.5;
  static const emojiLift = 25.0;
  static const scrubDeadzone = 40.0;
  static const scrubBandBelowTouch = 30.0;

  /// The pinch a message takes under the finger — `LONG_PRESS_SCALE_FACTOR`.
  static const pressScale = 0.95;

  /// `reaction_scrubber_reveal_duration` / `_offset`, and
  /// `reaction_scrubber_emoji_reveal_duration_start_delay_factor`: each piece
  /// takes 200, the strip starts 100 in, each emoji 10 after the last.
  static const revealDuration = Duration(milliseconds: 200);
  static const revealOffset = Duration(milliseconds: 100);
  static const emojiStagger = Duration(milliseconds: 10);

  /// The whole reveal: the last of the seven slots finishing.
  static const revealTotal = Duration(milliseconds: 100 + 6 * 10 + 200);

  /// ViewPropertyAnimator's default, which is what `shrinkBubble` runs on.
  static const pressDuration = Duration(milliseconds: 300);
  static const hideDuration = Duration(milliseconds: 150);
  static const emojiRiseFrom = 25.0;
}
