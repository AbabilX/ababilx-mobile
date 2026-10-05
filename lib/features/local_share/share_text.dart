import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_translations.dart';

/// A Local Share string in the app's language, `{name}` filled in.
String lsText(WidgetRef ref, String key, {String name = ''}) =>
    AppTranslations.of(
      ref.watch(appLanguageProvider),
      key,
    ).replaceAll('{name}', name);
