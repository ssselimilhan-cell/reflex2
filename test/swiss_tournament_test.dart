import 'package:flutter_test/flutter_test.dart';
import 'package:stres_kart/online/swiss_tournament.dart';

void main() {
  group('Swiss tournament rules', () {
    test('round count scales with registered player count', () {
      expect(swissRoundCount(2), 2);
      expect(swissRoundCount(4), 2);
      expect(swissRoundCount(5), 3);
      expect(swissRoundCount(8), 3);
      expect(swissRoundCount(9), 4);
      expect(swissRoundCount(16), 4);
      expect(swissRoundCount(17), 5);
      expect(swissRoundCount(32), 5);
      expect(swissRoundCount(33), 6);
      expect(swissRoundCount(64), 6);
    });

    test('odd field creates exactly one bye and each player appears once', () {
      final players = List.generate(7, (i) => SwissPlayer(uid: 'p$i', name: 'P$i'));
      final pairings = createSwissPairings(players, seed: 42);
      expect(pairings.where((p) => p.isBye).length, 1);
      final ids = pairings.expand((p) => [p.player1.uid, if (p.player2 != null) p.player2!.uid]).toList();
      expect(ids.toSet().length, 7);
      expect(ids.length, 7);
    });

    test('pairing avoids rematches when alternatives exist', () {
      final players = [
        const SwissPlayer(uid: 'a', name: 'A', points: 4, opponents: ['b']),
        const SwissPlayer(uid: 'b', name: 'B', points: 4, opponents: ['a']),
        const SwissPlayer(uid: 'c', name: 'C', points: 4),
        const SwissPlayer(uid: 'd', name: 'D', points: 4),
      ];
      final pairings = createSwissPairings(players, seed: 9);
      for (final pairing in pairings) {
        if (pairing.player2 != null) {
          expect(pairing.player1.opponents.contains(pairing.player2!.uid), isFalse);
          expect(pairing.player2!.opponents.contains(pairing.player1.uid), isFalse);
        }
      }
    });

    test('Buchholz sums opponents scores in half-point units', () {
      expect(swissBuchholz('a', {'b': 4, 'c': 3}, {'a': ['b', 'c']}), 7);
    });
  });
}
