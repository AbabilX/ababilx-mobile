import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_translations.dart';

/// One introduction per installation; signing out does not replay it.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;
  static const preferenceKey = 'messaging_onboarding_v1_seen';

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var seen = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      seen = preferences.getBool(OnboardingGate.preferenceKey) ?? false;
    } catch (_) {
      // Unavailable preferences must not prevent sign-in.
    }
    if (mounted) setState(() => _seen = seen);
  }

  Future<void> _continue() async {
    setState(() => _seen = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(OnboardingGate.preferenceKey, true);
    } catch (_) {
      // Continue for this launch even if the flag cannot be persisted.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_seen!) return widget.child;
    return _OnboardingScreen(onContinue: _continue);
  }
}

class _OnboardingScreen extends ConsumerWidget {
  const _OnboardingScreen({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    String t(String key) => AppTranslations.translate(context, ref, key);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/onboarding_connections_v1.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.56),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.surface.withValues(alpha: 0),
                              colors.surface.withValues(alpha: 0.96),
                              colors.surface,
                            ],
                            stops: const [0, 0.28, 1],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              children: [
                                Text(
                                  t('onboarding_title'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  t('onboarding_body'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: onContinue,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 18,
                                      ),
                                    ),
                                    child: Text(t('onboarding_start')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
