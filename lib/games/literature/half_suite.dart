import '../../shared/card_model.dart';

/// The 9 half-suites of Literature / Fish.
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
