class Rank {
  final String nameKey;
  final String emoji;
  final int minWins;
  const Rank(this.nameKey, this.emoji, this.minWins);
}

/// Toplam online galibiyet sayısına göre rütbeler.
const List<Rank> kRanks = [
  Rank('rank_bronze', '🥉', 0),
  Rank('rank_silver', '🥈', 10),
  Rank('rank_gold', '🥇', 30),
  Rank('rank_diamond', '💎', 75),
  Rank('rank_legend', '🏆', 150),
];

Rank rankFor(int wins) {
  var r = kRanks.first;
  for (final x in kRanks) {
    if (wins >= x.minWins) r = x;
  }
  return r;
}

/// Sonraki rütbe; en üst rütbedeyse null.
Rank? nextRankFor(int wins) {
  for (final x in kRanks) {
    if (x.minWins > wins) return x;
  }
  return null;
}
