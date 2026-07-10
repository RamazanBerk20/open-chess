import 'package:open_chess/src/state/locale_resolution.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supported = <Locale>[Locale('ar'), Locale('en'), Locale('tr')];

  test('uses the matching Turkish system locale', () {
    expect(
      resolveAppLocale(const [Locale('tr', 'TR')], supported),
      const Locale('tr'),
    );
  });

  test(
    'uses English instead of generated locale order for an unknown locale',
    () {
      expect(
        resolveAppLocale(const [Locale('C')], supported),
        const Locale('en'),
      );
    },
  );
}
