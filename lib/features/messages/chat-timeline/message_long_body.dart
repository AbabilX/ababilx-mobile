import 'package:flutter/material.dart';

import 'long_message_screen.dart';
import 'message_bubble.dart';

/// Signal never lets a bubble grow without a limit. A body past
/// `SignalServiceMessageLimits.MAX_INLINE_BODY_SIZE_BYTES` is split when it is
/// sent (`MessageUtil.getSplitMessage`); the bubble carries the head of it and
/// a "Read More" span that opens the whole thing full screen
/// (`LongMessageFragment`).
///
/// We cannot split at send time — the body is stored whole and, in a DM, is
/// ciphertext the server cannot even see to split — so the same cap is applied
/// when the bubble is drawn. It buys more than a tidy list: the long-press
/// overlay lifts the bubble out of the list and scales it down until the
/// reaction bar and the action menu both fit, so an unbounded bubble becomes an
/// unreadable sliver, which is exactly what a 900-line message did.
class MessageLongBody {
  const MessageLongBody._();

  /// A little under Signal's 2 KB inline body — ours is measured in characters
  /// rather than bytes because nothing downstream depends on the byte count.
  static const maxCharacters = 900;

  /// A short body can still be tall: an ASCII table, a stack trace, a wall of
  /// single-word lines. Line count catches what length alone misses.
  static const maxLines = 14;

  /// Height the collapsed body is clipped to. Deliberately not a multiple of
  /// the line height — a body cut mid-line reads as "there is more", where a
  /// clean cut reads as the end of the message.
  static const collapsedHeight = 264.0;

  static bool isLong(String plain) =>
      plain.length > maxCharacters ||
      // Lines, not line breaks: a body of `maxLines` rows holds one fewer
      // newline than that.
      '\n'.allMatches(plain).length + 1 >= maxLines;
}

/// Fades the last few lines of a clipped body out into the bubble fill, so the
/// cut looks deliberate instead of broken.
class CollapsedBodyFade extends StatelessWidget {
  const CollapsedBodyFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black, Colors.black, Colors.transparent],
      stops: [0, 0.84, 1],
    ).createShader(rect),
    child: child,
  );
}

/// Signal's "Read More". It opens the message full screen rather than growing
/// the bubble in place: an expanded bubble would put the long-press overlay
/// back where it started.
class ReadMoreRow extends StatelessWidget {
  const ReadMoreRow({
    super.key,
    required this.body,
    required this.colors,
    required this.editedAt,
  });

  final String? body;
  final SignalBubbleColors colors;
  final String? editedAt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LongMessageScreen(body: body, editedAt: editedAt),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          'Read more',
          style: TextStyle(
            color: colors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
