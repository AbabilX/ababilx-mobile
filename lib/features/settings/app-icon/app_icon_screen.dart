import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';

import 'app_icon.dart';
import '../../../shared/widgets/app_toast.dart';

/// Settings → App icon.
///
/// Mirrors the reference app's safe selection flow: preview first, then confirm
/// before Android swaps the enabled launcher alias.
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
      showAppToast(context, 'Could not change the app icon', isError: true);
      final current = await AppIcon.current();
      if (mounted) setState(() => _selected = current);
    }
  }

  Future<void> _confirmChoice(AppIconOption option) async {
    if (_busy || option.id == _selected) return;
    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: _AppIconMark(option: option, size: 64),
        title: Text('Change app icon to ${option.label}?'),
        content: const Text(
          'Your Android launcher may take a moment to show the new icon.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (shouldChange == true && mounted) await _choose(option);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const Text('App icon'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
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
                onTap: () => _confirmChoice(option),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Calendar, Calculator and Notes look like other apps, so AbabilX '
            'is less obvious on the home screen. Your launcher redraws the '
            'icon on its own schedule, so it may take a moment. A home-screen '
            'shortcut created for the old icon may need to be added again.',
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
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: colors.onSurface, width: 3)
                  : null,
            ),
            padding: EdgeInsets.all(selected ? 5 : 0),
            child: _AppIconMark(option: option, size: selected ? 58 : 68),
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

class _AppIconMark extends StatelessWidget {
  const _AppIconMark({required this.option, required this.size});

  final AppIconOption option;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: option.background, shape: BoxShape.circle),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      option.previewAsset ?? 'assets/icon/icon_foreground.png',
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}
