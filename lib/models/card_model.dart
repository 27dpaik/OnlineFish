enum Suit { spades, hearts, diamonds, clubs, joker }

extension SuitX on Suit {
  String get symbol {
    switch (this) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.joker:
        return 'JK';
    }
  }

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

enum Rank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
  jokerSmall,
  jokerBig,
}

extension RankX on Rank {
  String get short {
    switch (this) {
      case Rank.two:
        return '2';
      case Rank.three:
        return '3';
      case Rank.four:
        return '4';
      case Rank.five:
        return '5';
      case Rank.six:
        return '6';
      case Rank.seven:
        return '7';
      case Rank.eight:
        return '8';
      case Rank.nine:
        return '9';
      case Rank.ten:
        return '10';
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      case Rank.ace:
        return 'A';
      case Rank.jokerSmall:
        return 'jk';
      case Rank.jokerBig:
        return 'JK';
    }
  }
}

class PlayingCard {
  final Suit suit;
  final Rank rank;

  const PlayingCard(this.suit, this.rank);

  /// Stable string id used as a map key and across the wire.
  /// Examples: "S2", "HK", "DA", "C8", "J0" (small joker), "J1" (big joker).
  String get id {
    if (suit == Suit.joker) {
      return rank == Rank.jokerSmall ? 'J0' : 'J1';
    }
    final s = suit.name[0].toUpperCase();
    return '$s${rank.short}';
  }

  static PlayingCard fromId(String id) {
    if (id == 'J0') return const PlayingCard(Suit.joker, Rank.jokerSmall);
    if (id == 'J1') return const PlayingCard(Suit.joker, Rank.jokerBig);
    final suitChar = id[0];
    final rankStr = id.substring(1);
    final suit = switch (suitChar) {
      'S' => Suit.spades,
      'H' => Suit.hearts,
      'D' => Suit.diamonds,
      'C' => Suit.clubs,
      _ => throw ArgumentError('Bad suit: $suitChar'),
    };
    final rank = Rank.values.firstWhere((r) => r.short == rankStr,
        orElse: () => throw ArgumentError('Bad rank: $rankStr'));
    return PlayingCard(suit, rank);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => id;
}

/// The 9 half-suites of Literature / Fish:
///   - Lower (2-7) of each suit              → 4 half-suites
///   - Upper (9, 10, J, Q, K, A) of each suit → 4 half-suites
///   - All four 8s + both jokers              → 1 half-suite ("Eights & Jokers")
class HalfSuite {
  final String id;
  final String name;
  final List<PlayingCard> cards;

  const HalfSuite({required this.id, required this.name, required this.cards});

  bool contains(PlayingCard c) => cards.contains(c);
}

class HalfSuites {
  static final List<HalfSuite> all = _build();

  static List<HalfSuite> _build() {
    final out = <HalfSuite>[];
    const suitOrder = [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs];
    const lowerRanks = [
      Rank.two,
      Rank.three,
      Rank.four,
      Rank.five,
      Rank.six,
      Rank.seven,
    ];
    const upperRanks = [
      Rank.nine,
      Rank.ten,
      Rank.jack,
      Rank.queen,
      Rank.king,
      Rank.ace,
    ];
    for (final s in suitOrder) {
      out.add(HalfSuite(
        id: 'low_${s.name}',
        name: 'Lower ${_suitWord(s)} (2–7)',
        cards: lowerRanks.map((r) => PlayingCard(s, r)).toList(),
      ));
    }
    for (final s in suitOrder) {
      out.add(HalfSuite(
        id: 'up_${s.name}',
        name: 'Upper ${_suitWord(s)} (9–A)',
        cards: upperRanks.map((r) => PlayingCard(s, r)).toList(),
      ));
    }
    out.add(HalfSuite(
      id: 'eights_jokers',
      name: 'Eights & Jokers',
      cards: [
        for (final s in suitOrder) PlayingCard(s, Rank.eight),
        const PlayingCard(Suit.joker, Rank.jokerSmall),
        const PlayingCard(Suit.joker, Rank.jokerBig),
      ],
    ));
    return out;
  }

  static String _suitWord(Suit s) {
    switch (s) {
      case Suit.spades:
        return 'Spades';
      case Suit.hearts:
        return 'Hearts';
      case Suit.diamonds:
        return 'Diamonds';
      case Suit.clubs:
        return 'Clubs';
      case Suit.joker:
        return 'Jokers';
    }
  }

  static HalfSuite forCard(PlayingCard c) =>
      all.firstWhere((h) => h.contains(c));

  static HalfSuite byId(String id) => all.firstWhere((h) => h.id == id);
}
