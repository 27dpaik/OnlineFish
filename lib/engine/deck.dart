import 'dart:math';

import '../models/card_model.dart';

class Deck {
  /// Standard 54-card deck: 52 + 2 jokers, in canonical order.
  static List<PlayingCard> standard() {
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

  /// Deterministic shuffle into 6 hands of 9 cards each (seat order: A1, A2,
  /// A3, B1, B2, B3).
  static Map<String, List<String>> dealToSeats({
    required List<String> seatOrder,
    required int seed,
  }) {
    assert(seatOrder.length == 6);
    final cards = standard();
    final rng = Random(seed);
    cards.shuffle(rng);
    final hands = <String, List<String>>{};
    for (var i = 0; i < 6; i++) {
      hands[seatOrder[i]] =
          cards.sublist(i * 9, (i + 1) * 9).map((c) => c.id).toList()..sort();
    }
    return hands;
  }
}
