import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../policy/widgets/policy_gate_overlay.dart';
import '../chat-people/find_people_tab.dart';

class FindPeopleScreen extends ConsumerWidget {
  const FindPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: AppBar(
            leading: const AppBarBackButton(),
            title: Text(
              AppTranslations.translate(context, ref, 'chat_find_people_screen'),
            ),
          ),
          body: const FindPeopleTab(),
        ),
        const PolicyGateOverlay(),
      ],
    );
  }
}
