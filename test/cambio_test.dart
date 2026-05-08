import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/games/cambio/engine.dart';
import 'package:literature_game/games/cambio/models.dart';
import 'package:literature_game/shared/card_model.dart';

CambioState _readyGame({int players = 3, int seed = 42}) {
  var s = CambioEngine.newLobby(
    gameId: 'g1',
    hostId: 'p1',
    hostName: 'P1',
    seed: seed,
  );
  for (var i = 2; i <= players; i++) {
    s = CambioEngine.addPlayer(s, CambioPlayer(id: 'p$i', name: 'P$i'));
  }
  return s;
}

void main() {
  group('Cambio engine', () {
    test('startGame deals 4 cards to each player', () {
      var s = _readyGame(players: 3);
      final res = CambioEngine.startGame(s);
      expect(res.ok, true);
      s = res.next!;
      expect(s.phase, CambioPhase.initialPeek);
      for (final p in s.players) {
        expect(s.hands[p.id]!.length, 4);
      }
      expect(s.discard.length, 1);
    });

    test('initial peek phase advances when all done', () {
      var s = _readyGame(players: 2);
      s = CambioEngine.startGame(s).next!;
      expect(s.phase, CambioPhase.initialPeek);
      s = CambioEngine.finishInitialPeek(s, 'p1').next!;
      expect(s.phase, CambioPhase.initialPeek);
      s = CambioEngine.finishInitialPeek(s, 'p2').next!;
      expect(s.phase, CambioPhase.playing);
    });

    test('correct stick removes the card', () {
      var s = _readyGame(players: 2);
      s = CambioEngine.startGame(s).next!;
      // Force initial peek to be done.
      s = s.copyWith(
          phase: CambioPhase.playing,
          initialPeekDone: {'p1', 'p2'});
      // Set discard top to a known card and put a matching card in p1's hand.
      final discardTop = const PlayingCard(Suit.spades, Rank.five);
      final matching = const PlayingCard(Suit.hearts, Rank.five);
      final s2 = s.copyWith(
        discard: [discardTop.id],
        hands: {
          ...s.hands,
          'p1': [matching.id, 'C2', 'D2', 'H2'],
        },
      );
      final res = CambioEngine.stick(
        s: s2,
        stickerId: 'p1',
        ownerPlayerId: 'p1',
        position: 0,
      );
      expect(res.ok, true);
      expect(res.next!.hands['p1']!.length, 3);
    });

    test('wrong stick yields a penalty card', () {
      var s = _readyGame(players: 2);
      s = CambioEngine.startGame(s).next!;
      s = s.copyWith(
          phase: CambioPhase.playing,
          initialPeekDone: {'p1', 'p2'});
      final discardTop = const PlayingCard(Suit.spades, Rank.five);
      final notMatching = const PlayingCard(Suit.hearts, Rank.four);
      final s2 = s.copyWith(
        discard: [discardTop.id],
        hands: {
          ...s.hands,
          'p1': [notMatching.id, 'C2', 'D2', 'H2'],
        },
      );
      final before = s2.hands['p1']!.length;
      final res = CambioEngine.stick(
        s: s2,
        stickerId: 'p1',
        ownerPlayerId: 'p1',
        position: 0,
      );
      expect(res.ok, true);
      expect(res.next!.hands['p1']!.length, before + 1);
    });

    test('calling cambio enters final round', () {
      var s = _readyGame(players: 3);
      s = CambioEngine.startGame(s).next!;
      s = CambioEngine.finishInitialPeek(s, 'p1').next!;
      s = CambioEngine.finishInitialPeek(s, 'p2').next!;
      s = CambioEngine.finishInitialPeek(s, 'p3').next!;
      expect(s.phase, CambioPhase.playing);
      final res = CambioEngine.callCambio(s, 'p1');
      expect(res.ok, true);
      expect(res.next!.phase, CambioPhase.finalRound);
      expect(res.next!.cambioCallerId, 'p1');
      expect(res.next!.finalRoundRemaining, 2); // 3 players - 1
    });

    test('discarding a 7 sets a peek-own pending power', () {
      var s = _readyGame(players: 2);
      s = CambioEngine.startGame(s).next!;
      s = s.copyWith(
          phase: CambioPhase.playing,
          initialPeekDone: {'p1', 'p2'});
      final seven = const PlayingCard(Suit.spades, Rank.seven);
      s = s.copyWith(drawn: DrawnCard(cardId: seven.id, playerId: 'p1'));
      final res = CambioEngine.discardDrawn(s: s, playerId: 'p1');
      expect(res.ok, true);
      expect(res.next!.pending?.type, PendingPowerType.peekOwn);
    });
  });
}
