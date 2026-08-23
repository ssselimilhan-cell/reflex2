enum Suit { spades, hearts, diamonds, clubs }

/// rank: 1 = As, 2-10 normal, 11 = Vale, 12 = Kız, 13 = Papaz
class PlayingCard {
  final Suit suit;
  final int rank;

  const PlayingCard(this.suit, this.rank);

  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return rank.toString();
    }
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  /// Bir kartın merkez yığın üzerindeki bir kartın üstüne
  /// kapatılıp kapatılamayacağını kontrol eder.
  /// Kural: bir üst ya da bir alt değer, K-A arası da geçişli (wrap) sayılır.
  bool canCoverOnTopOf(PlayingCard other) {
    final diff = (rank - other.rank).abs();
    return diff == 1 || diff == 12; // 12 -> K(13) ile A(1) arası wrap
  }

  /// Firestore'da saklamak için kısa metin kodu, örn: "S7" (Maça 7), "H1" (Kupa As).
  String toCode() {
    final suitLetter = switch (suit) {
      Suit.spades => 'S',
      Suit.hearts => 'H',
      Suit.diamonds => 'D',
      Suit.clubs => 'C',
    };
    return '$suitLetter$rank';
  }

  static PlayingCard fromCode(String code) {
    final suitLetter = code[0];
    final rank = int.parse(code.substring(1));
    final suit = switch (suitLetter) {
      'S' => Suit.spades,
      'H' => Suit.hearts,
      'D' => Suit.diamonds,
      'C' => Suit.clubs,
      _ => throw ArgumentError('Bilinmeyen suit kodu: $suitLetter'),
    };
    return PlayingCard(suit, rank);
  }

  @override
  String toString() => '$rankLabel$suitSymbol';

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);
}

List<PlayingCard> buildStandardDeck() {
  final deck = <PlayingCard>[];
  for (final suit in Suit.values) {
    for (var rank = 1; rank <= 13; rank++) {
      deck.add(PlayingCard(suit, rank));
    }
  }
  return deck;
}
