import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';

/// Home copy helper: translate [key], optionally substitute `{n}`.
String homeText(BuildContext context, WidgetRef ref, String key, [int? n]) {
  final text = AppTranslations.translate(context, ref, key);
  return n == null ? text : text.replaceAll('{n}', '$n');
}
