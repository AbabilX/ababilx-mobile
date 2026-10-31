import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A picture or video with its caption under it, where the MEDIA decides the
/// bubble's width and the caption wraps to it — the reference app's
/// arrangement.
///
/// In a plain Column the caption lays out against the bubble's cap, so a
/// portrait photo (narrow, because its height hits the ceiling) under a line
/// of text left the bubble as wide as the text with bare fill beside the
/// photo. `IntrinsicWidth` cannot answer it either: an album grid is a
/// LayoutBuilder and refuses intrinsics. So, like [QuotedBubbleLayout], the
/// measuring is done here: media first, then the caption held to its width.
class MediaCaptionLayout extends MultiChildRenderObjectWidget {
  MediaCaptionLayout({
    super.key,
    required Widget media,
    required Widget caption,
  }) : super(children: [media, caption]);

  @override
  RenderMediaCaption createRenderObject(BuildContext context) =>
      RenderMediaCaption();
}

class _MediaCaptionParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMediaCaption extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MediaCaptionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MediaCaptionParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MediaCaptionParentData) {
      child.parentData = _MediaCaptionParentData();
    }
  }

  @override
  void performLayout() {
    final media = firstChild!;
    final caption = childAfter(media)!;
    final free = BoxConstraints(maxWidth: constraints.maxWidth);

    media.layout(free, parentUsesSize: true);
    // Nothing drawable (every attachment timed or expired) leaves no width to
    // follow; the caption then takes its own, as any text bubble does.
    if (media.size.width > 0) {
      final width = constraints.constrainWidth(media.size.width);
      caption.layout(
        BoxConstraints.tightFor(width: width),
        parentUsesSize: true,
      );
    } else {
      caption.layout(free, parentUsesSize: true);
    }
    final width = constraints.constrainWidth(
      media.size.width > 0 ? media.size.width : caption.size.width,
    );

    (media.parentData! as _MediaCaptionParentData).offset = Offset.zero;
    (caption.parentData! as _MediaCaptionParentData).offset = Offset(
      0,
      media.size.height,
    );
    size = constraints.constrain(
      Size(width, media.size.height + caption.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
