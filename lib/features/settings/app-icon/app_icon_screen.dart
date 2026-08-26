import 'package:flutter/material.dart';

import '../../../core/router/root_back.dart';
import 'app_icon.dart';

/// Settings → App icon.
///
/// Picking an icon takes effect immediately; the launcher decides when to
/// redraw, which on some devices is a beat later than the tap. The note at the
/// bottom says so, because an icon that has not changed yet otherwise reads as
/// a failed setting.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  String _selected = 'default';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppIcon.current().then((id) {
      if (mounted) setState(() => _selected = id);
    });
  }

  Future<void> _choose(AppIconOption option) async {
    if (_busy || option.id == _selected) return;
    setState(() {
      _busy = true;
      _selected = option.id;
    });
    final ok = await AppIcon.select(option.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not change the app icon')),
      );
      final current = await AppIcon.current();
      if (mounted) setState(() => _selected = current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGoHome(context),
        ),
        title: const Text('App icon'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: appIconOptions.length,
            itemBuilder: (_, index) {
              final option = appIconOptions[index];
              return _IconTile(
                option: option,
                selected: option.id == _selected,
                onTap: () => _choose(option),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Your launcher redraws the icon on its own schedule, so it may '
            'take a moment. A home-screen shortcut created for the old icon '
            'may need to be added again.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: option.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icon/icon_foreground.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            option.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
