import 'package:flutter/widgets.dart';

import 'package:gsu_fit/l10n/app_localizations.dart';

export 'package:gsu_fit/l10n/app_localizations.dart';

/// The only UI language for now. Adding English means adding
/// lib/l10n/app_en.arb and choosing the locale here (or from the device).
const Locale appLocale = Locale('tr');

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
