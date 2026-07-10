import 'dart:math';

import 'package:open_chess/src/state/four_lan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidFourLanSeatAssignment', () {
    test('allows a host and any remaining AI seats', () {
      expect(isValidFourLanSeatAssignment(const [-1, -2, -2, -2], 0), isTrue);
    });

    test('allows a joined player alongside host-run AI', () {
      expect(isValidFourLanSeatAssignment(const [-1, 0, -2, -2], 1), isTrue);
    });

    test('requires each connected human exactly once', () {
      expect(isValidFourLanSeatAssignment(const [-1, -2, -2, -2], 1), isFalse);
      expect(isValidFourLanSeatAssignment(const [-1, 0, 0, -2], 1), isFalse);
      expect(isValidFourLanSeatAssignment(const [-1, 0, 1, 2], 2), isFalse);
    });

    test('rejects invalid owner values and malformed assignments', () {
      expect(isValidFourLanSeatAssignment(const [-1, 0, -2, 3], 1), isFalse);
      expect(isValidFourLanSeatAssignment(const [-1, -2, -2], 0), isFalse);
    });
  });

  group('isValidFourLanAiDifficulties', () {
    test('allows an independently selected preset for every AI color', () {
      expect(
        isValidFourLanAiDifficulties(
          const [-1, -2, -2, -2],
          const [-1, 0, 3, 5],
        ),
        isTrue,
      );
    });

    test('requires the human sentinel and bounded AI preset codes', () {
      expect(
        isValidFourLanAiDifficulties(
          const [-1, 0, -2, -2],
          const [2, -1, 2, 2],
        ),
        isFalse,
      );
      expect(
        isValidFourLanAiDifficulties(
          const [-1, 0, -2, -2],
          const [-1, -1, 6, 2],
        ),
        isFalse,
      );
      expect(
        isValidFourLanAiDifficulties(const [-1, -2, -2, -2], const [-1, 2, 2]),
        isFalse,
      );
    });
  });

  group('randomizeFourLanSeatAssignment', () {
    test(
      'default assignment includes every current human before shuffling',
      () {
        final assignment = defaultFourLanSeatAssignment(2);

        expect(assignment.seatOwners, const [-1, 0, 1, -2]);
        expect(assignment.aiDifficulties, const [-1, -1, -1, 2]);
        expect(isValidFourLanSeatAssignment(assignment.seatOwners, 2), isTrue);
        expect(
          isValidFourLanAiDifficulties(
            assignment.seatOwners,
            assignment.aiDifficulties,
          ),
          isTrue,
        );
      },
    );

    test('moves owner and AI difficulty pairs together', () {
      const owners = [-1, 0, -2, -2];
      const difficulties = [-1, -1, 1, 4];

      final randomized = randomizeFourLanSeatAssignment(
        owners,
        difficulties,
        joinerCount: 1,
        random: Random(2026),
      );

      final before = [
        for (var seat = 0; seat < 4; seat++)
          '${owners[seat]}:${difficulties[seat]}',
      ]..sort();
      final after = [
        for (var seat = 0; seat < 4; seat++)
          '${randomized.seatOwners[seat]}:${randomized.aiDifficulties[seat]}',
      ]..sort();

      expect(after, before);
      expect(
        List.generate(
          4,
          (seat) => randomized.seatOwners[seat] != owners[seat],
        ).any((changed) => changed),
        isTrue,
      );
      expect(owners, const [-1, 0, -2, -2]);
      expect(difficulties, const [-1, -1, 1, 4]);
      expect(isValidFourLanSeatAssignment(randomized.seatOwners, 1), isTrue);
      expect(
        isValidFourLanAiDifficulties(
          randomized.seatOwners,
          randomized.aiDifficulties,
        ),
        isTrue,
      );
    });

    test('rejects malformed parallel assignments', () {
      expect(
        () => randomizeFourLanSeatAssignment(
          const [-1, -2],
          const [-1, 2],
          joinerCount: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
