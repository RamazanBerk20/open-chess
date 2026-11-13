import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:open_chess/src/rust/api/game.dart';
import 'package:open_chess/src/state/difficulty.dart';
import 'package:open_chess/src/state/fen_repair.dart';
import 'package:open_chess/src/state/game_import.dart';
import 'package:open_chess/src/state/l10n_labels.dart';
import 'package:open_chess/src/state/lan_profile.dart';
import 'package:open_chess/src/state/pgn.dart';
import 'package:open_chess/src/state/saved_games.dart';
import 'package:open_chess/src/state/update_service.dart';

void main() {
  group('PGN import parsing', () {
    test('strips tags, comments, variations, NAGs and the result', () {
      final g = tokenizePgn('''
[Event "x"]
[FEN "8/8/8/8/8/8/8/K6k w - - 0 1"]
[Variant "Atomic"]

1. e4 {best} e5 (1... c5 2. Nf3) 2. Nf3?! \$1 Nc6 ; comment
3. Bb5 a6 1-0
''');
      expect(g.tags['Variant'], 'Atomic');
      expect(g.tags['FEN'], '8/8/8/8/8/8/8/K6k w - - 0 1');
      expect(g.sans, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6']);
    });

    test('parses SAN shapes', () {
      final p = parseSan('exd8=Q+')!;
      expect(p.piece, PieceKind.pawn);
      expect(p.fromFile, 4);
      expect(p.to, 59);
      expect(p.promotion, PieceKind.queen);
      expect(parseSan('Nbd7')!.fromFile, 1);
      expect(parseSan('R1e2')!.fromRank, 0);
      expect(parseSan('O-O-O')!.castle, 'Q');
      expect(parseSan('N@e4')!.drop, isTrue);
      expect(parseSan('zz9'), isNull);
    });

    test('rejects empty and oversized input before touching the engine', () {
      expect(
        () => importGame('   '),
        throwsA(
          isA<ImportError>().having(
            (e) => e.kind,
            'kind',
            ImportErrorKind.empty,
          ),
        ),
      );
      expect(
        () => importGame('e4 ' * (maxImportChars ~/ 2)),
        throwsA(
          isA<ImportError>().having(
            (e) => e.kind,
            'kind',
            ImportErrorKind.tooLarge,
          ),
        ),
      );
    });

    test('detects a bare FEN', () {
      expect(looksLikeFen(standardStartFen), isTrue);
      expect(looksLikeFen('1. e4 e5'), isFalse);
    });
  });

  group('hostile PGN never hangs or throws', () {
    test('stray closers and unterminated openers', () {
      expect(tokenizePgn('1. e4 } e5').sans, ['e4', 'e5']);
      expect(tokenizePgn('1. e4 ) e5').sans, ['e4', 'e5']);
      expect(tokenizePgn('1. e4 {unterminated e5').sans, ['e4']);
      expect(tokenizePgn('1. e4 (1. d4 d5').sans, ['e4']);
    });

    test('deep nesting, huge single-character line, NUL bytes', () {
      expect(tokenizePgn('1. e4 ${'(' * 100000} d4 ${')' * 100000} e5').sans, [
        'e4',
        'e5',
      ]);
      final big = 'x' * maxImportChars;
      expect(tokenizePgn(big).sans, hasLength(1));
      expect(tokenizePgn('}' * maxImportChars).sans, isEmpty);
      expect(tokenizePgn('1. e4 \u0000 e5\u0000\u0000}').sans, isNotEmpty);
      expect(() => importGame('1. e4 } e5\u0000'), throwsA(isA<ImportError>()));
      expect(() => importGame('}' * 1000), throwsA(isA<ImportError>()));
    });
  });

  group('stale en passant repair', () {
    test('drops an en passant square with no pawn behind it', () {
      expect(
        stripStaleEnPassant(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e6 0 1',
        ),
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
    });

    test('keeps a real one and a missing one', () {
      expect(
        stripStaleEnPassant(
          'rnbqkbnr/pppp1ppp/8/4p3/8/8/PPPPPPPP/RNBQKBNR w KQkq e6 0 2',
        ),
        isNull,
      );
      expect(stripStaleEnPassant(standardStartFen), isNull);
    });
  });

  group('stale castling repair', () {
    test('drops rights whose rook is gone', () {
      expect(
        stripStaleCastling('r3k3/8/8/8/8/8/8/4K2R w KQkq - 0 1'),
        'r3k3/8/8/8/8/8/8/4K2R w Kq - 0 1',
      );
    });

    test('keeps a consistent FEN unchanged', () {
      expect(stripStaleCastling(standardStartFen), isNull);
      expect(stripStaleCastling('4k3/8/8/8/8/8/8/4K3 w - - 0 1'), isNull);
    });

    test('handles file letters (Shredder/X-FEN)', () {
      expect(
        stripStaleCastling('4k3/8/8/8/8/8/8/1R2K3 w BH - 0 1'),
        '4k3/8/8/8/8/8/8/1R2K3 w B - 0 1',
      );
    });
  });

  group('PGN export', () {
    test('uses the non-board result and variant tags', () {
      final pgn = buildPgn(
        sanMoves: const ['e4'],
        status: GameOutcome.ongoing,
        overlayResult: LanResultCode.youResigned,
        youAreWhite: true,
        variant: GameVariant.atomic,
        date: pgnDate(DateTime(2026, 7, 3)),
      );
      expect(pgn, contains('[Result "0-1"]'));
      expect(pgn, contains('[Termination "resignation"]'));
      expect(pgn, contains('[Variant "Atomic"]'));
      expect(pgn, contains('[Date "2026.07.03"]'));
      expect(pgn.trim(), endsWith('0-1'));
    });

    test('Chess960 always carries its start position', () {
      final pgn = buildPgn(
        sanMoves: const [],
        status: GameOutcome.ongoing,
        variant: GameVariant.chess960,
        startFen: standardStartFen,
      );
      expect(pgn, contains('[FEN "$standardStartFen"]'));
    });
  });

  test('update asset is chosen per OS; desktop never gets the APK', () {
    const assets = [
      ('open-chess-1.2.0-android.apk', 'apk'),
      ('open-chess-1.2.0-x86_64.AppImage', 'appimage'),
      ('open-chess-1.2.0-setup.exe', 'exe'),
    ];
    expect(pickUpdateAsset(assets, 'android'), 'apk');
    expect(pickUpdateAsset(assets, 'linux'), 'appimage');
    expect(pickUpdateAsset(assets, 'windows'), 'exe');
    expect(pickUpdateAsset(const [('a.apk', 'apk')], 'linux'), isNull);
    expect(pickUpdateAsset(assets, 'macos'), isNull);
  });

  test('saved games keep custom difficulty and per-ply clocks', () {
    final custom = Difficulty.normal.copyWith(name: 'Custom', maxDepth: 9);
    final g = SavedGame(
      id: '1',
      name: 'c',
      moves: const ['e2e4', 'e7e5'],
      createdAt: '',
      vsAi: true,
      difficultyName: 'Custom',
      difficultyParams: custom.toJson(),
      clockHistory: const [(300000, 300000), (298000, 300000)],
    );
    final back = SavedGame.fromJson(g.toJson());
    expect(Difficulty.fromJson(back.difficultyParams!).maxDepth, 9);
    expect(back.clockHistory, const [(300000, 300000), (298000, 300000)]);
    expect(back.copyWith(name: 'x').clockHistory, back.clockHistory);
  });

  test('remote avatars: only small JPEGs are decoded', () {
    Uint8List jpeg(int side) => Uint8List.fromList(
      image.encodeJpg(image.Image(width: side, height: side), quality: 10),
    );
    expect(remoteAvatarCheap(jpeg(96)), isTrue);
    expect(remoteAvatarCheap(jpeg(512)), isFalse);
    final png = Uint8List.fromList(
      image.encodePng(image.Image(width: 8, height: 8)),
    );
    expect(remoteAvatarCheap(png), isFalse);
  });
}
