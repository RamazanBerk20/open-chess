import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/features/menu/main_menu.dart';
import 'package:open_chess/src/rust/frb_generated.dart';
import 'package:open_chess/src/state/json_store.dart';
import 'package:open_chess/src/state/locale_resolution.dart';
import 'package:open_chess/src/state/settings.dart';
import 'package:open_chess/src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await preloadSettings(); // seed persisted settings before first frame
  runApp(const ProviderScope(child: OpenChessApp()));
}

/// App-wide messenger, so store problems found anywhere can be reported.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
final _navigatorKey = GlobalKey<NavigatorState>(); // a context with l10n

class OpenChessApp extends ConsumerStatefulWidget {
  const OpenChessApp({super.key});

  @override
  ConsumerState<OpenChessApp> createState() => _OpenChessAppState();
}

class _OpenChessAppState extends ConsumerState<OpenChessApp> {
  int _reported = 0;

  @override
  void initState() {
    super.initState();
    storeCorruptions.addListener(_report);
    storeWriteFailures.addListener(_reportWriteFailure);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    storeCorruptions.removeListener(_report);
    storeWriteFailures.removeListener(_reportWriteFailure);
    super.dispose();
  }

  bool _writeFailureShown = false;

  /// A save failed (disk full / read-only): tell the user once per session.
  void _reportWriteFailure() {
    final messenger = appMessengerKey.currentState;
    final ctx = _navigatorKey.currentContext;
    if (_writeFailureShown || messenger == null || ctx == null) return;
    _writeFailureShown = true;
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(ctx).settingsSaveFailed)),
    );
  }

  /// An unreadable data file was kept as a `.corrupt` backup: say where.
  void _report() {
    final all = storeCorruptions.value;
    final messenger = appMessengerKey.currentState;
    final ctx = _navigatorKey.currentContext;
    if (messenger == null || ctx == null) return;
    final t = AppLocalizations.of(ctx);
    for (final path in all.skip(_reported)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.storeCorrupt(path)),
          duration: const Duration(seconds: 10),
        ),
      );
    }
    _reported = all.length;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return MaterialApp(
      scaffoldMessengerKey: appMessengerKey,
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: s.materialThemeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: s.localeCode == null ? null : Locale(s.localeCode!),
      localeListResolutionCallback: resolveAppLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Apply an explicit text-size override (1.0 = follow the OS).
      builder: (context, child) {
        if (s.textScale == 1.0 || child == null) {
          return child ?? const SizedBox();
        }
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(s.textScale)),
          child: child,
        );
      },
      home: const MainMenu(),
    );
  }
}
