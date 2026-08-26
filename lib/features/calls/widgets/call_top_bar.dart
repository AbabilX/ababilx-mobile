import 'package:flutter/material.dart';

/// Every piece of text on a call screen sits on top of a photo, so it all
/// carries the same soft drop shadow Signal uses rather than relying on the
/// scrim alone.
const List<Shadow> callTextShadow = [
  Shadow(color: Color(0x40000000), blurRadius: 4),
];

/// The bar across the top of a call.
///
/// Signal draws it as a 240dp black→transparent gradient rather than a solid
/// app bar: the controls stay readable over a bright photo without cutting a
/// hard edge across the picture. The gradient is decorative and must never eat
/// touches meant for the video underneath, hence [IgnorePointer] on it.
class CallTopBar extends StatelessWidget {
  const CallTopBar({
    super.key,
    required this.onMinimize,
    this.title,
    this.subtitle,
    this.minimizeIcon = Icons.keyboard_arrow_down_rounded,
    this.trailing,
  });

  final VoidCallback onMinimize;
  final String? title;
  final String? subtitle;
  final IconData minimizeIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: onMinimize,
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      icon: Icon(minimizeIcon, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  shadows: callTextShadow,
                                ),
                              ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                  shadows: callTextShadow,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ?trailing,
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
