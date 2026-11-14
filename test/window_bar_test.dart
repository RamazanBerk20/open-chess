import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_chess/l10n/app_localizations.dart';
import 'package:open_chess/src/rust/api/four.dart';
import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/widgets/bar_status.dart';
import 'package:open_chess/src/widgets/window_chrome.dart';

Widget _app(PreferredSizeWidget bar) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => WindowFrame(child: child!),
  home: Scaffold(appBar: bar),
);

FourPlayerPanel _seat(
  FourPlayer p, [
  FourPlayerStatus s = FourPlayerStatus.active,
]) => FourPlayerPanel(player: p, status: s, score: 0, inCheck: false);

void main() {
  final calls = <String>[];

  setUp(() {
    desktopChrome = true;
    windowState.value = const WindowState();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('open_chess/window'), (
          call,
        ) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() => desktopChrome = false);

  testWidgets('menu: wordmark only, window buttons labelled', (tester) async {
    await tester.pumpWidget(
      _app(const WindowAppBar(title: Text('Open Chess'))),
    );
    expect(find.text('Open Chess'), findsOneWidget);
    expect(find.byTooltip('Minimise'), findsOneWidget);
    expect(find.byTooltip('Maximise'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byType(TwoPlayerBarStatus), findsNothing);
    expect(tester.getSize(find.byType(AppBar)).height, kWindowBarHeight);
  });

  testWidgets('buttons go through the window channel', (tester) async {
    await tester.pumpWidget(_app(const WindowAppBar(title: Text('x'))));
    await tester.tap(find.byTooltip('Minimise'));
    await tester.tap(find.byTooltip('Maximise'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(calls, ['minimize', 'toggleMaximize', 'close']);
  });

  testWidgets('keyboard reaches the window buttons', (tester) async {
    await tester.pumpWidget(_app(const WindowAppBar(title: Text('x'))));
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['close']);
  });

  testWidgets('maximised: restore button, no resize edges', (tester) async {
    await tester.pumpWidget(_app(const WindowAppBar(title: Text('x'))));
    bool hasEdge() => tester
        .widgetList<MouseRegion>(find.byType(MouseRegion))
        .any((m) => m.cursor == SystemMouseCursors.resizeUpLeft);
    expect(hasEdge(), isTrue);
    expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);

    windowState.value = const WindowState(maximized: true, framed: false);
    await tester.pump();
    expect(find.byTooltip('Restore'), findsOneWidget);
    expect(find.byTooltip('Maximise'), findsNothing);
    expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);
    expect(hasEdge(), isFalse);
  });

  testWidgets('two-player timed game: clocks, move number, side to move', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const WindowAppBar(
          title: Text('Game'),
          center: TwoPlayerBarStatus(
            sideToMove: PieceColor.black,
            moveNumber: 12,
            over: false,
            whiteMs: 300000,
            blackMs: 187000,
          ),
        ),
      ),
    );
    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('3:07'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.bySemanticsLabel('Black to move, Move 12'), findsOneWidget);
    // Only the side to move sits on a filled face.
    final filled = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).color != null,
        );
    expect(filled, hasLength(1));
    handle.dispose();
  });

  testWidgets('two-player untimed game shows no clocks', (tester) async {
    await tester.pumpWidget(
      _app(
        const WindowAppBar(
          title: Text('Game'),
          center: TwoPlayerBarStatus(
            sideToMove: PieceColor.white,
            moveNumber: 1,
            over: false,
          ),
        ),
      ),
    );
    expect(find.textContaining(':'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('four-player game: one pip per seat, turn ringed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        WindowAppBar(
          title: const Text('Four'),
          center: FourPlayerBarStatus(
            players: [
              _seat(FourPlayer.red),
              _seat(FourPlayer.blue),
              _seat(FourPlayer.yellow, FourPlayerStatus.checkmated),
              _seat(FourPlayer.green),
            ],
            turn: FourPlayer.blue,
            over: false,
            semanticsLabel: 'Blue to move',
          ),
        ),
      ),
    );
    for (final p in FourPlayer.values) {
      expect(find.byKey(ValueKey(p)), findsOneWidget);
    }
    final ringed = tester.widget<Container>(
      find.byKey(const ValueKey(FourPlayer.blue)),
    );
    final idle = tester.widget<Container>(
      find.byKey(const ValueKey(FourPlayer.red)),
    );
    expect(ringed.decoration, isNotNull);
    expect(idle.decoration, isNull);
    expect(find.bySemanticsLabel('Blue to move'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('off desktop: the plain app bar, no window buttons', (
    tester,
  ) async {
    desktopChrome = false;
    await tester.pumpWidget(
      _app(const WindowAppBar(title: Text('Open Chess'))),
    );
    expect(find.text('Open Chess'), findsOneWidget);
    expect(find.byType(WindowButtons), findsNothing);
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });
}
