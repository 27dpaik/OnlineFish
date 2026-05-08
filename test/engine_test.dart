import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/games/literature/engine.dart';
import 'package:literature_game/games/literature/half_suite.dart';
import 'package:literature_game/games/literature/models.dart' show LitGameState, LitPlayer, LitPhase;
import 'package:literature_game/shared/card_model.dart';

LitGameState _seatedLobby({int seed = 42}) {
  var s = LiteratureEngine.newLobby(
    gameId: 'g1',
    hostId: 'p1',
    hostName: 'P1',
    seed: seed,
  );
  for (var i = 2; i <= 6; i++) {
    s = LiteratureEngine.addPlayer(s, LitPlayer(id: 'p$i', name: 'P$i'));
  }
  final seatIds = ['A1', 'A2', 'A3', 'B1', 'B2', 'B3'];
  for (var i = 0; i < 6; i++) {
    s = LiteratureEngine.sitPlayer(s, 'p${i + 1}', seatIds[i]).next!;
  }
  return s;
}

void main() {
  group('Deck', () {
    test('standard has 54 unique cards', () {
      final d = Decks.standard54();
      expect(d.length, 54);
      expect(d.toSet().length, 54);
    });
  });

  group('HalfSuites', () {
    test('there are exactly 9 half-suites with 6 cards each, covering all 54',
        () {
      final all = HalfSuites.all;
      expect(all.length, 9);
      final set = <PlayingCard>{};
      for (final hs in all) {
        expect(hs.cards.length, 6);
        set.addAll(hs.cards);
      }
      expect(set.length, 54);
    });

    test('eights & jokers includes all four 8s and both jokers', () {
      final hs = HalfSuites.byId('eights_jokers');
      expect(hs.cards.where((c) => c.rank == Rank.eight).length, 4);
      expect(hs.cards.where((c) => c.suit == Suit.joker).length, 2);
    });
  });

  group('Literature engine', () {
    test('startGame deals 9 cards to each seat', () {
      var s = _seatedLobby();
      final res = LiteratureEngine.startGame(s);
      expect(res.ok, true);
      s = res.next!;
      expect(s.phase, LitPhase.playing);
      for (final seat in s.seats) {
        expect(s.handFor(seat.id).length, 9);
      }
    });

    test('cannot ask for a card if you have no card in that half-suite', () {
      var s = _seatedLobby();
      s = LiteratureEngine.startGame(s).next!;
      final a1Hand = s.handFor('A1').toSet();
      PlayingCard? bad;
      for (final hs in HalfSuites.all) {
        final overlap = hs.cards.where(a1Hand.contains).toList();
        if (overlap.isEmpty) {
          bad = hs.cards.first;
          break;
        }
      }
      if (bad == null) return;
      final res = LiteratureEngine.ask(
        s: s,
        askerSeatId: 'A1',
        targetSeatId: 'B1',
        card: bad,
      );
      expect(res.ok, false);
    });

    test('successful ask transfers card and asker keeps turn', () {
      var s = _seatedLobby();
      s = LiteratureEngine.startGame(s).next!;
      final b1Hand = s.handFor('B1');
      final a1Hand = s.handFor('A1').toSet();
      PlayingCard? target;
      for (final c in b1Hand) {
        final hs = HalfSuites.forCard(c);
        if (hs.cards.any((x) => x != c && a1Hand.contains(x))) {
          target = c;
          break;
        }
      }
      if (target == null) return;
      final res = LiteratureEngine.ask(
        s: s,
        askerSeatId: 'A1',
        targetSeatId: 'B1',
        card: target,
      );
      expect(res.ok, true);
      final next = res.next!;
      expect(next.handFor('A1'), contains(target));
      expect(next.handFor('B1'), isNot(contains(target)));
      expect(next.currentSeatId, 'A1');
    });

    test('PlayingCard.fromId roundtrips for all 54 cards', () {
      for (final c in Decks.standard54()) {
        expect(PlayingCard.fromId(c.id), c);
      }
    });
  });
}
