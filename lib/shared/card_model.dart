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
  bool get isBlack => this == Suit.spades || this == Suit.clubs;
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
  jokerSmall, // black joker
  jokerBig,   // colored / red joker
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

  bool get isJoker => suit == Suit.joker;
  bool get isBlackJoker => rank == Rank.jokerSmall;
  bool get isColoredJoker => rank == Rank.jokerBig;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => id;
}

class Decks {
  /// Standard 54-card deck: 52 + 2 jokers, in canonical order.
  static List<PlayingCard> standard54() {
    final cards = <PlayingCard>[];
    for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]) {
      for (final r in [
        Rank.two,
        Rank.three,
        Rank.four,
        Rank.five,
        Rank.six,
        Rank.seven,
        Rank.eight,
        Rank.nine,
        Rank.ten,
        Rank.jack,
        Rank.queen,
        Rank.king,
        Rank.ace,
      ]) {
        cards.add(PlayingCard(s, r));
      }
    }
    cards.add(const PlayingCard(Suit.joker, Rank.jokerSmall));
    cards.add(const PlayingCard(Suit.joker, Rank.jokerBig));
    assert(cards.length == 54);
    return cards;
  }
}
