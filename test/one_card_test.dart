import 'package:flutter_test/flutter_test.dart';
import 'package:literature_game/games/one_card/engine.dart';
import 'package:literature_game/games/one_card/models.dart';
import 'package:literature_game/shared/card_model.dart';

OcState _readyGame({int players = 3, int seed = 42}) {
  var s = OneCardEngine.newLobby(
    gameId: 'g1',
    hostId: 'p1',
    hostName: 'P1',
    seed: seed,
  );
  for (var i = 2; i <= players; i++) {
    s = OneCardEngine.addPlayer(s, OcPlayer(id: 'p$i', name: 'P$i'));
  }
  return s;
}

void main() {
  group('One Card engine', () {
    test('startGame deals 5 to each (3+ players) and reveals top', () {
      var s = _readyGame(players: 3);
      final res = OneCardEngine.startGame(s);
      expect(res.ok, true);
      s = res.next!;
      expect(s.phase, OcPhase.playing);
      expect(s.discard.length, 1);
      for (final p in s.players) {
        expect(s.handFor(p.id).length, 5);
      }
    });

    test('startGame deals 7 to each in a 2-player game', () {
      var s = _readyGame(players: 2);
      final res = OneCardEngine.startGame(s);
      expect(res.ok, true);
      s = res.next!;
      for (final p in s.players) {
        expect(s.handFor(p.id).length, 7);
      }
    });

    test('cannot play out of turn', () {
      var s = _readyGame(players: 3);
      s = OneCardEngine.startGame(s).next!;
      // Find a card in p2's hand and try to play.
      final p2Hand = s.handFor('p2');
      final res = OneCardEngine.play(
        s: s,
        playerId: 'p2',
        card: p2Hand.first,
      );
      expect(res.ok, false);
      expect(res.error, contains('your turn'));
    });

    test('drawing absorbs pending attack', () {
      // Build a synthetic state with a pending attack.
      var s = _readyGame(players: 2);
      s = OneCardEngine.startGame(s).next!;
      s = s.copyWith(pendingAttack: 3);
      final myId = s.currentPlayer.id;
      final before = s.handFor(myId).length;
      final res = OneCardEngine.draw(s: s, playerId: myId);
      expect(res.ok, true);
      expect(res.next!.pendingAttack, 0);
      expect(res.next!.handFor(myId).length, before + 3);
    });

    test('seven is wild — playable on any suit when no attack', () {
      var s = _readyGame(players: 2);
      s = OneCardEngine.startGame(s).next!;
      // Synthesize a 7 in current player's hand and a top discard with a
      // different suit/rank.
      final myId = s.currentPlayer.id;
      final seven = const PlayingCard(Suit.spades, Rank.seven);
      final hand = [seven.id, ...(s.hands[myId]!).where((id) => id != seven.id)];
      // Force a non-spade non-7 top card.
      final topDifferent = const PlayingCard(Suit.hearts, Rank.four);
      final s2 = s.copyWith(
        hands: {...s.hands, myId: hand},
        discard: [topDifferent.id],
        pendingAttack: 0,
      );
      final res = OneCardEngine.play(
        s: s2,
        playerId: myId,
        card: seven,
        declaredSuitForSeven: Suit.diamonds,
      );
      expect(res.ok, true);
      expect(res.next!.declaredSuit, 'diamonds');
    });

    test('three shields a pending attack', () {
      var s = _readyGame(players: 2);
      s = OneCardEngine.startGame(s).next!;
      final myId = s.currentPlayer.id;
      final three = const PlayingCard(Suit.spades, Rank.three);
      final hand = [three.id, ...(s.hands[myId]!).where((id) => id != three.id)];
      final s2 = s.copyWith(
        hands: {...s.hands, myId: hand},
        pendingAttack: 5,
      );
      final res = OneCardEngine.play(
        s: s2,
        playerId: myId,
        card: three,
      );
      expect(res.ok, true);
      expect(res.next!.pendingAttack, 0);
    });

    test('king grants extra turn (same player keeps the turn)', () {
      var s = _readyGame(players: 2);
      s = OneCardEngine.startGame(s).next!;
      final myId = s.currentPlayer.id;
      final top = s.topDiscard;
      // Synthesize a king matching top suit.
      final king = PlayingCard(top.suit, Rank.king);
      final hand = [king.id, ...(s.hands[myId]!).where((id) => id != king.id)];
      final res = OneCardEngine.play(
        s: s.copyWith(hands: {...s.hands, myId: hand}),
        playerId: myId,
        card: king,
      );
      expect(res.ok, true);
      expect(res.next!.currentPlayer.id, myId);
    });
  });
}
