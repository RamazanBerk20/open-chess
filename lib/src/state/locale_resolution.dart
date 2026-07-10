import 'package:flutter/widgets.dart';

/// Select a supported system language, with English as a deterministic fallback.
///
/// Desktop sessions can expose an unsupported POSIX locale such as `C` while
/// still having a normal display language configured. Falling back to the first
/// generated localization would otherwise make the default depend on file order.
Locale resolveAppLocale(
  List<Locale>? platformLocales,
  Iterable<Locale> supportedLocales,
) {
  for (final platformLocale in platformLocales ?? const <Locale>[]) {
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == platformLocale.languageCode) {
        return supportedLocale;
      }
    }
  }
  return const Locale('en');
}
