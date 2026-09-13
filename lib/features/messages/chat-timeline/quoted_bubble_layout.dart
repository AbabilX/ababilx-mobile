import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The width a quote is allowed to ask a bubble for, on its own.
///
/// A quote wraps to two lines and ellipsises, so it fits any width; left to its
/// natural one, a long quoted line dragged the whole bubble out to the width
/// cap and a two-word reply sat under 70% of the screen. Past this, a quote
/// wraps instead of widening the bubble.
const double _quoteAskWidth = 224.0;

/// Puts the quote block above the rest of a bubble and makes the two exactly as
/// wide as each other.
///
/// A plain Column cannot do it. `CrossAxisAlignment.stretch` needs a width to
/// stretch to, and the only one available is the bubble's cap — so every quoted
/// message would draw a full-width bubble. Sizing the quote to its own content
/// instead is what leaves it narrower than the text underneath, which is the
/// mismatch in the report. `IntrinsicWidth` would answer both, but it queries
/// intrinsics through the whole message body, and an album grid or a link
/// preview card is a LayoutBuilder, which refuses to be measured that way.
///
/// So the measuring is done here, in one layout pass each: the content is laid
/// out to find the width it wants, the quote may raise that (never past
/// [_quoteAskWidth]), and both are then given the result.
class QuotedBubbleLayout extends MultiChildRenderObjectWidget {
  QuotedBubbleLayout({
    super.key,
    required Widget quote,
    required Widget content,
  }) : super(children: [quote, content]);

  @override
  RenderQuotedBubble createRenderObject(BuildContext context) =>
      RenderQuotedBubble();
}

class _QuotedBubbleParentData extends ContainerBoxParentData<RenderBox> {}

class RenderQuotedBubble extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _QuotedBubbleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _QuotedBubbleParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _QuotedBubbleParentData) {
      child.parentData = _QuotedBubbleParentData();
    }
  }

  @override
  void performLayout() {
    final quote = firstChild!;
    final content = childAfter(quote)!;
    final free = BoxConstraints(maxWidth: constraints.maxWidth);

    // What each half would take if nothing else were here. The quote's answer
    // is only a request: it is capped, so a long quote never decides the
    // bubble's width on its own.
    quote.layout(free, parentUsesSize: true);
    content.layout(free, parentUsesSize: true);
    final width = constraints.constrainWidth(
      math.max(content.size.width, math.min(quote.size.width, _quoteAskWidth)),
    );

    // Re-laying out at the settled width is what makes the two line up — and
    // what keeps the footer on its own side, since the content column aligns
    // itself once it has a width to align within.
    final tight = BoxConstraints.tightFor(width: width);
    if (content.size.width != width) {
      content.layout(tight, parentUsesSize: true);
    }
    quote.layout(tight, parentUsesSize: true);

    _dataOf(quote).offset = Offset.zero;
    _dataOf(content).offset = Offset(0, quote.size.height);
    size = constraints.constrain(
      Size(width, quote.size.height + content.size.height),
    );
  }

  _QuotedBubbleParentData _dataOf(RenderBox child) =>
      child.parentData! as _QuotedBubbleParentData;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
