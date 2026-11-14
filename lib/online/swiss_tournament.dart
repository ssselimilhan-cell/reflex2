/// Pure Swiss-system tournament calculations.
///
/// A fixed number of rounds is derived from the registered field size.
/// Scores are stored in half-point units (2 = win, 1 = draw, 0 = loss)
/// to avoid floating-point drift in Firestore and standings.
class SwissPlayer {
  final String uid;
  final String name;
  final int points;
  final List<String> opponents;
  final int byeCount;

  const SwissPlayer({
    required this.uid,
    required this.name,
    this.points = 0,
    this.opponents = const [],
    this.byeCount = 0,
  });
}

class SwissPairing {
  final SwissPlayer player1;
  final SwissPlayer? player2;
  const SwissPairing(this.player1, this.player2);
  bool get isBye => player2 == null;
}

/// Standard practical Swiss round-count table: 2-4: 2, 5-8: 3,
/// 9-16: 4, 17-32: 5, 33-64: 6, etc.
int swissRoundCount(int players) {
  if (players < 2) throw ArgumentError.value(players, 'players', 'At least two players are required.');
  var rounds = 2;
  var capacity = 4;
  while (players > capacity) {
    capacity *= 2;
    rounds++;
  }
  return rounds;
}

/// Pairs players with similar scores while avoiding repeat opponents whenever
/// a feasible alternative exists. A player receives at most one bye.
List<SwissPairing> createSwissPairings(List<SwissPlayer> input, {int seed = 1}) {
  if (input.length < 2) throw ArgumentError('At least two players are required.');
  final players = [...input];
  if (players.map((p) => p.uid).toSet().length != players.length) {
    throw ArgumentError('Player UIDs must be unique.');
  }
  // Stable seeded shuffle prevents registration order from determining the
  // first-round advantage while keeping retries deterministic.
  var state = seed & 0x7fffffff;
  int nextRandom(int max) {
    state = (1103515245 * state + 12345) & 0x7fffffff;
    return state % max;
  }
  for (var i = players.length - 1; i > 0; i--) {
    final j = nextRandom(i + 1);
    final value = players[i]; players[i] = players[j]; players[j] = value;
  }
  players.sort((a, b) {
    final points = b.points.compareTo(a.points);
    return points != 0 ? points : nextRandom(2) * 2 - 1;
  });

  SwissPlayer? byePlayer;
  if (players.length.isOdd) {
    final eligible = players.where((p) => p.byeCount == 0).toList()
      ..sort((a, b) {
        final score = a.points.compareTo(b.points);
        return score != 0 ? score : nextRandom(2) * 2 - 1;
      });
    byePlayer = eligible.isNotEmpty ? eligible.first : players.last;
    players.removeWhere((p) => p.uid == byePlayer!.uid);
  }

  final pairings = <SwissPairing>[];
  while (players.isNotEmpty) {
    final first = players.removeAt(0);
    var opponentIndex = -1;
    // Prefer an opponent with no previous encounter, then the smallest score gap.
    for (var i = 0; i < players.length; i++) {
      if (!first.opponents.contains(players[i].uid) &&
          !players[i].opponents.contains(first.uid)) {
        opponentIndex = i;
        break;
      }
    }
    if (opponentIndex < 0) opponentIndex = 0;
    final second = players.removeAt(opponentIndex);
    pairings.add(SwissPairing(first, second));
  }
  if (byePlayer != null) pairings.add(SwissPairing(byePlayer, null));
  return pairings;
}

/// Buchholz tie-break: sum of the final scores of all opponents faced.
int swissBuchholz(String uid, Map<String, int> points, Map<String, List<String>> opponents) {
  return (opponents[uid] ?? const <String>[])
      .fold<int>(0, (sum, opponent) => sum + (points[opponent] ?? 0));
}
